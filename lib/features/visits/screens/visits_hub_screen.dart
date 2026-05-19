import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/db/local_database.dart';
import 'package:lima/shell/nav_bar_layout.dart';

class VisitsHubScreen extends ConsumerStatefulWidget {
  const VisitsHubScreen({super.key});

  /// Loads LPU + pharmacy lists from the local DB into the static cache so
  /// the screen renders instantly on first navigation. Safe to call multiple
  /// times — re-reads to pick up server-side updates.
  static Future<void> preload(LocalDatabase db) async {
    try {
      final rows = await Future.wait([
        db.getOrganisations(type: 'lpu'),
        db.getOrganisations(type: 'pharmacy'),
      ]).timeout(const Duration(seconds: 8));
      _VisitsHubScreenState._cachedLpuRows = rows[0]
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _VisitsHubScreenState._cachedPharmacyRows = rows[1]
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      // Best-effort prewarm — UI will retry via its own _load() on init.
    }
  }

  @override
  ConsumerState<VisitsHubScreen> createState() => _VisitsHubScreenState();
}

class _VisitsHubScreenState extends ConsumerState<VisitsHubScreen> {
  static List<Map<String, dynamic>>? _cachedLpuRows;
  static List<Map<String, dynamic>>? _cachedPharmacyRows;

  bool _isLpu = true;
  String _query = '';
  bool _allRegions = false;
  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _lpuCache = [];
  List<Map<String, dynamic>> _pharmacyCache = [];
  Map<int, double> _nearbyDistances = {};
  bool _nearbyMode = false;
  bool _localCacheLoaded = false;
  bool _isFindingNearby = false;
  Position? _lastNearbyPosition;
  String? _lastResetToken;
  int _loadGeneration = 0;
  StreamSubscription<Set<String>>? _dbChangesSub;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrateLocalCache();
    _dbChangesSub = ref.read(localDatabaseProvider).changes.listen((tables) {
      if (!mounted || !tables.contains('organisations')) return;
      _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _dbChangesSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final resetToken = GoRouterState.of(context).uri.queryParameters['reset'];
    if (resetToken == null || resetToken == _lastResetToken) return;
    _lastResetToken = resetToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetToDefault();
    });
  }

  void _resetToDefault() {
    setState(() {
      _isLpu = true;
      _query = '';
      _allRegions = false;
      _nearbyMode = false;
      _nearbyDistances = {};
      _lastNearbyPosition = null;
      _orgs = _localCacheLoaded ? _buildOrgList() : [];
    });
    _searchCtrl.clear();
    if (!_localCacheLoaded) _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final db = ref.read(localDatabaseProvider);
    final rows =
        await Future.wait([
          db.getOrganisations(type: 'lpu'),
          db.getOrganisations(type: 'pharmacy'),
        ]).timeout(
          const Duration(seconds: 6),
          onTimeout: () => const <List<Map<String, dynamic>>>[
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
          ],
        );
    final lpu = rows[0];
    final pharmacies = rows[1];
    if (!mounted || generation != _loadGeneration) return;
    final lpuRows = _cloneRows(lpu);
    final pharmacyRows = _cloneRows(pharmacies);
    _cachedLpuRows = _cloneRows(lpuRows);
    _cachedPharmacyRows = _cloneRows(pharmacyRows);
    setState(() {
      _lpuCache = lpuRows;
      _pharmacyCache = pharmacyRows;
      _localCacheLoaded = true;
      _orgs = _buildOrgList();
    });
  }

  void _hydrateLocalCache() {
    final lpuRows = _cachedLpuRows;
    final pharmacyRows = _cachedPharmacyRows;
    if (lpuRows == null || pharmacyRows == null) return;
    if (lpuRows.isEmpty && pharmacyRows.isEmpty) return;
    _lpuCache = _cloneRows(lpuRows);
    _pharmacyCache = _cloneRows(pharmacyRows);
    _localCacheLoaded = true;
    _orgs = _buildOrgList();
  }

  static List<Map<String, dynamic>> _cloneRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  List<Map<String, dynamic>> _buildOrgList() {
    final user = ref.read(authProvider).user;
    final query = _query.trim().toLowerCase();
    var orgs = (_isLpu ? _lpuCache : _pharmacyCache)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (query.isNotEmpty) {
      orgs = orgs.where((o) {
        final haystack = [
          o['name'],
          o['address'],
          o['city'],
        ].whereType<Object>().join(' ').toLowerCase();
        return haystack.contains(query);
      }).toList();
    }
    if (!_allRegions) {
      orgs = orgs.where((o) => _belongsToUserRegion(o, user)).toList();
    }
    orgs.sort((a, b) {
      final aId = (a['id'] as num?)?.toInt() ?? 0;
      final bId = (b['id'] as num?)?.toInt() ?? 0;
      final ad = _nearbyMode ? _nearbyDistances[aId] : null;
      final bd = _nearbyMode ? _nearbyDistances[bId] : null;
      if (ad != null || bd != null) {
        return (ad ?? double.infinity).compareTo(bd ?? double.infinity);
      }
      final an = (a['name']?.toString() ?? '').toLowerCase();
      final bn = (b['name']?.toString() ?? '').toLowerCase();
      return an.compareTo(bn);
    });
    if (_nearbyMode && _nearbyDistances.isNotEmpty) {
      orgs.removeWhere(
        (o) => !_nearbyDistances.containsKey((o['id'] as num?)?.toInt() ?? 0),
      );
    }
    for (final org in orgs) {
      final id = (org['id'] as num?)?.toInt() ?? 0;
      final distance = _nearbyDistances[id];
      if (distance != null) org['distance_m'] = distance;
    }
    return orgs;
  }

  void _onTabChange(bool isLpu) {
    if (_isLpu == isLpu) return;
    setState(() {
      _isLpu = isLpu;
      _nearbyMode = false;
      _nearbyDistances = {};
      _lastNearbyPosition = null;
      _orgs = _buildOrgList();
    });
    if (!_localCacheLoaded) _load();
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 150) return;

    if (velocity < 0 && _isLpu) {
      _onTabChange(false);
    } else if (velocity > 0 && !_isLpu) {
      _onTabChange(true);
    }
  }

  void _onQueryChange(String q) {
    setState(() {
      _query = q;
      if (!_nearbyMode) _orgs = _buildOrgList();
    });
    final pos = _lastNearbyPosition;
    if (_nearbyMode && pos != null) {
      _loadNearbyForPosition(pos);
    }
  }

  void _toggleAllRegions(bool value) {
    setState(() {
      _allRegions = value;
      if (!_nearbyMode) _orgs = _buildOrgList();
    });
    final pos = _lastNearbyPosition;
    if (_nearbyMode && pos != null) {
      _loadNearbyForPosition(pos);
    }
  }

  Future<Position?> _requestCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Геолокация недоступна')));
      }
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешите геолокацию в настройках приложения'),
          ),
        );
      }
      await Geolocator.openAppSettings();
      return null;
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
  }

  Future<void> _findNearby() async {
    if (_isFindingNearby) return;
    setState(() => _isFindingNearby = true);
    try {
      final pos = await _requestCurrentPosition();
      if (pos == null) return;
      await _loadNearbyForPosition(pos);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка загрузки данных')));
    } finally {
      if (mounted) setState(() => _isFindingNearby = false);
    }
  }

  Future<void> _loadNearbyForPosition(Position pos) async {
    if (!_localCacheLoaded) {
      await _load();
      if (!mounted) return;
    }
    final user = ref.read(authProvider).user;
    final query = _query.trim().toLowerCase();
    var rows = (_isLpu ? _lpuCache : _pharmacyCache)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (query.isNotEmpty) {
      rows = rows.where((o) {
        final haystack = [
          o['name'],
          o['address'],
          o['city'],
        ].whereType<Object>().join(' ').toLowerCase();
        return haystack.contains(query);
      }).toList();
    }
    final filteredRows = !_allRegions
        ? rows.where((o) => _belongsToUserRegion(o, user)).toList()
        : rows;

    final map = <int, double>{};
    final orgs = <Map<String, dynamic>>[];
    for (final row in filteredRows) {
      final id = row['id'] as int? ?? 0;
      final lat = (row['latitude'] as num?)?.toDouble();
      final lon = (row['longitude'] as num?)?.toDouble();
      final item = Map<String, dynamic>.from(row);
      if (lat != null && lon != null) {
        final distance = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          lat,
          lon,
        );
        map[id] = distance;
        item['distance_m'] = distance;
      }
      orgs.add(item);
    }
    orgs.sort((a, b) {
      final aId = a['id'] as int? ?? 0;
      final bId = b['id'] as int? ?? 0;
      final ad = map[aId] ?? double.infinity;
      final bd = map[bId] ?? double.infinity;
      return ad.compareTo(bd);
    });

    if (!mounted) return;
    setState(() {
      _lastNearbyPosition = pos;
      _nearbyMode = map.isNotEmpty;
      _nearbyDistances = map;
      _orgs = orgs;
    });
    if (map.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нет координат для сортировки рядом, показан общий список',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleHorizontalSwipe,
            child: Column(
              children: [
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    boxShadow: shadowSm,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppUi.screenHorizontal,
                    MediaQuery.of(context).padding.top + 12,
                    AppUi.screenHorizontal,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.t('search'),
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SegmentedTypeSelector(
                        isLpu: _isLpu,
                        onChanged: _onTabChange,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _searchCtrl,
                        onChanged: _onQueryChange,
                        decoration: InputDecoration(
                          hintText: _isLpu
                              ? context.l10n.t('searchLpu')
                              : context.l10n.t('searchPharmacy'),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.hintText,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.hintText,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() => _query = '');
                                    _searchCtrl.clear();
                                    final pos = _lastNearbyPosition;
                                    if (_nearbyMode && pos != null) {
                                      _loadNearbyForPosition(pos);
                                    } else {
                                      _load();
                                    }
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          _toggleAllRegions(!_allRegions);
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _allRegions,
                                onChanged: (v) {
                                  _toggleAllRegions(v ?? false);
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.t('searchAllRegions'),
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: !_localCacheLoaded
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _orgs.isEmpty
                      ? EmptyState(
                          icon: (!_nearbyMode && _query.isEmpty)
                              ? LucideIcons.mapPin
                              : Icons.search_off_rounded,
                          title: (!_nearbyMode && _query.isEmpty)
                              ? context.l10n.t('findNearbyHint')
                              : context.l10n.t('nothingFound'),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            AppUi.screenHorizontal,
                            12,
                            AppUi.screenHorizontal,
                            LimaNavBarLayout.scrollBottomPadding(context) + 24,
                          ),
                          itemCount: _orgs.length,
                          itemBuilder: (_, i) {
                            final org = _orgs[i];
                            return OrgCard(
                              name: org['name'] as String,
                              address: org['address'] as String,
                              isPharmacy: !_isLpu,
                              distanceMeters: _nearbyMode
                                  ? _nearbyDistances[org['id'] as int? ?? 0]
                                  : null,
                              onTap: () {
                                if (_isLpu) {
                                  context.push(
                                    Uri(
                                      path: '/visits/lpu/detail/${org['id']}',
                                      queryParameters: {
                                        'name': org['name'] as String,
                                        'address': org['address'] as String,
                                      },
                                    ).toString(),
                                  );
                                } else {
                                  context.push(
                                    Uri(
                                      path:
                                          '/visits/pharmacy/detail/${org['id']}',
                                      queryParameters: {
                                        'name': org['name'] as String,
                                      },
                                    ).toString(),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Floating actions
          Positioned(
            left: AppUi.screenHorizontal,
            right: AppUi.screenHorizontal,
            bottom: LimaNavBarLayout.totalBarHeight(context) - 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTapScale(
                  onTap: _isFindingNearby ? null : _findNearby,
                  pressedScale: 0.97,
                  child: Container(
                    height: AppUi.buttonHeight,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(AppUi.cardRadius),
                      border: Border.all(color: AppColors.primary),
                      boxShadow: shadowMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isFindingNearby)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          const Icon(
                            LucideIcons.mapPin,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _isFindingNearby
                              ? context.l10n.t('searching')
                              : context.l10n.t('findNearby'),
                          style: GoogleFonts.manrope(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _belongsToUserRegion(Map<String, dynamic> org, UserModel? user) {
    final userRegionId = user?.regionId;
    final orgRegionId = _orgRegionId(org);
    if (userRegionId != null && orgRegionId != null) {
      return userRegionId == orgRegionId;
    }
    return _sameRegion(org['city']?.toString(), user?.city);
  }

  int? _orgRegionId(Map<String, dynamic> org) {
    final direct = org['region_id'];
    if (direct is num) return direct.toInt();
    if (direct is String) return int.tryParse(direct);
    final raw = org['raw_json'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final rawRegion = map['region_id'] ?? map['regionId'];
      if (rawRegion is num) return rawRegion.toInt();
      if (rawRegion is String) return int.tryParse(rawRegion);
      final region = map['region'];
      if (region is Map) {
        final id = region['id'] ?? region['region_id'];
        if (id is num) return id.toInt();
        if (id is String) return int.tryParse(id);
      }
    } catch (_) {}
    return null;
  }

  bool _sameRegion(String? orgCity, String? userCity) {
    final a = _normalizeRegion(orgCity);
    final b = _normalizeRegion(userCity);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }

  String _normalizeRegion(String? value) {
    if (value == null) return '';
    final v = value
        .toLowerCase()
        .replaceAll('г.', '')
        .replaceAll('город', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return v;
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTypeSelector extends StatelessWidget {
  final bool isLpu;
  final ValueChanged<bool> onChanged;

  const _SegmentedTypeSelector({required this.isLpu, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = (constraints.maxWidth - 8) / 2;
        return Container(
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: isLpu ? 0 : segmentWidth,
                top: 0,
                width: segmentWidth,
                height: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: shadowSm,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _TabBtn(
                      label: context.l10n.t('lpu'),
                      active: isLpu,
                      onTap: () => onChanged(true),
                    ),
                  ),
                  Expanded(
                    child: _TabBtn(
                      label: context.l10n.t('pharmacies'),
                      active: !isLpu,
                      onTap: () => onChanged(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
