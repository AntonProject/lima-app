import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../offline/domain/entities/sync_data_change.dart';
import '../domain/repositories/organisations_directory_repository.dart';
import '../presentation/view_models/visits_hub_view_model.dart';
import '../providers/visits_hub_provider.dart';
import 'package:lima/shell/nav_bar_layout.dart';

part '../widgets/visits_hub_widgets.dart';

class VisitsHubScreen extends ConsumerStatefulWidget {
  const VisitsHubScreen({super.key});

  /// Warms the local directory query before the visits tab is opened.
  static Future<void> preload(
    OrganisationsDirectoryRepository repository,
  ) async {
    try {
      await Future.wait([
        repository.getLocalModels(type: 'lpu'),
        repository.getLocalModels(type: 'pharmacy'),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best-effort prewarm — the view model retries from the local database.
    }
  }

  @override
  ConsumerState<VisitsHubScreen> createState() => _VisitsHubScreenState();
}

class _VisitsHubScreenState extends ConsumerState<VisitsHubScreen> {
  String? _lastResetToken;
  StreamSubscription<SyncDataChange>? _dbChangesSub;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dbChangesSub = ref
        .read(organisationsDirectoryRepositoryProvider)
        .changes
        .listen((change) {
          if (!mounted ||
              !change.containsAny(const [SyncDataTable.organisations])) {
            return;
          }
          ref.read(visitsHubViewModelProvider.notifier).onRepositoryChanged();
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(visitsHubViewModelProvider.notifier).load();
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
      _searchCtrl.clear();
      ref.read(visitsHubViewModelProvider.notifier).resetToDefault();
    });
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 150) return;
    final isLpu = ref.read(visitsHubViewModelProvider).isLpu;
    if (velocity < 0 && isLpu) {
      ref.read(visitsHubViewModelProvider.notifier).setTab(false);
    } else if (velocity > 0 && !isLpu) {
      ref.read(visitsHubViewModelProvider.notifier).setTab(true);
    }
  }

  void _onQueryChange(String query) {
    ref.read(visitsHubViewModelProvider.notifier).setQuery(query);
  }

  void _onTabChange(bool isLpu) {
    ref.read(visitsHubViewModelProvider.notifier).setTab(isLpu);
  }

  void _toggleAllRegions(bool value) {
    ref.read(visitsHubViewModelProvider.notifier).setAllRegions(value);
  }

  Future<Position?> _requestCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('geoUnavailable'))),
        );
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
          SnackBar(content: Text(context.l10n.t('enableGeoInSettings'))),
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
    final viewModel = ref.read(visitsHubViewModelProvider.notifier);
    if (ref.read(visitsHubViewModelProvider).isFindingNearby) return;
    viewModel.beginNearbySearch();
    try {
      final pos = await _requestCurrentPosition();
      if (pos == null) return;
      final hasCoordinates = await viewModel.applyNearby(
        NearbyCoordinates(latitude: pos.latitude, longitude: pos.longitude),
      );
      if (!hasCoordinates && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('noCoordsNearby'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t('dataLoadError'))));
    } finally {
      if (mounted) viewModel.endNearbySearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(visitsHubViewModelProvider);
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
                        isLpu: hubState.isLpu,
                        onChanged: _onTabChange,
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _searchCtrl,
                                onChanged: _onQueryChange,
                                decoration: InputDecoration(
                                  hintText: hubState.isLpu
                                      ? context.l10n.t('searchLpu')
                                      : context.l10n.t('searchPharmacy'),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: AppColors.hintText,
                                  ),
                                  suffixIcon: hubState.query.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: AppColors.hintText,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            _onQueryChange('');
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            // Org creation (web parity): "+" opens the add form
                            // for the active tab — ЛПУ or Аптека.
                            const SizedBox(width: 8),
                            AppTapScale(
                              pressedScale: 0.92,
                              onTap: () async {
                                final created = await context.push<bool>(
                                  hubState.isLpu
                                      ? '/visits/lpu/add'
                                      : '/visits/pharmacy/add',
                                );
                                if (created == true && mounted) {
                                  ref
                                      .read(visitsHubViewModelProvider.notifier)
                                      .load();
                                }
                              },
                              child: Container(
                                width: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          _toggleAllRegions(!hubState.allRegions);
                        },
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: hubState.allRegions,
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
                  child: !hubState.localCacheLoaded
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : hubState.organisations.isEmpty
                      ? EmptyState(
                          icon: (!hubState.nearbyMode && hubState.query.isEmpty)
                              ? LucideIcons.mapPin
                              : Icons.search_off_rounded,
                          title:
                              (!hubState.nearbyMode && hubState.query.isEmpty)
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
                          itemCount: hubState.organisations.length,
                          itemBuilder: (_, i) {
                            final org = hubState.organisations[i];
                            return OrgCard(
                              name: org.name,
                              address: org.address,
                              isPharmacy: !hubState.isLpu,
                              distanceMeters: hubState.nearbyMode
                                  ? hubState.nearbyDistances[org.id]
                                  : null,
                              onTap: () {
                                if (hubState.isLpu) {
                                  context.push(
                                    Uri(
                                      path: '/visits/lpu/detail/${org.id}',
                                      queryParameters: {
                                        'name': org.name,
                                        'address': org.address,
                                      },
                                    ).toString(),
                                  );
                                } else {
                                  context.push(
                                    Uri(
                                      path: '/visits/pharmacy/detail/${org.id}',
                                      queryParameters: {'name': org.name},
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
                  onTap: hubState.isFindingNearby ? null : _findNearby,
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
                        if (hubState.isFindingNearby)
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
                          hubState.isFindingNearby
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
}
