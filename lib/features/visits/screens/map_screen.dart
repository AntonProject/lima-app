import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lima/features/visits/providers/visits_hub_provider.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/core/services/app_actions.dart';

class _NearbyOrg {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  const _NearbyOrg({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });
}

class MapScreen extends ConsumerStatefulWidget {
  final bool isPharmacy;
  const MapScreen({super.key, this.isPharmacy = false});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Position? _position;
  bool _loading = true;
  String? _error;
  final MapController _mapController = MapController();
  List<_NearbyOrg> _orgs = [];

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final tDisabled = context.l10n.t('geoUnavailable');
    final tDenied = context.l10n.t('geoAccessDenied');
    final tPermanent = context.l10n.t('geoAccessDeniedPermanent');
    final tFail = context.l10n.t('couldNotGetLocation');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _error = tDisabled;
            _loading = false;
          });
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _error = tDenied;
              _loading = false;
            });
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = tPermanent;
            _loading = false;
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _loadNearbyOrgs(pos);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = tFail;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNearbyOrgs(Position pos) async {
    final repo = ref.read(organisationsDirectoryRepositoryProvider);
    final orgs = await repo.getLocalModels(
      type: widget.isPharmacy ? 'pharmacy' : 'lpu',
    );
    const distance = Distance();
    final mapped = orgs.map((org) {
      final id = org.id;
      final angle = (id % 360) * 3.141592653589793 / 180.0;
      final radius = 0.007 + ((id % 9) * 0.0015);
      final lat = pos.latitude + radius * math.sin(angle);
      final lon = pos.longitude + radius * math.cos(angle);
      final meters = distance(
        LatLng(pos.latitude, pos.longitude),
        LatLng(lat, lon),
      );
      return _NearbyOrg(
        id: id,
        name: org.name,
        address: org.address,
        latitude: lat,
        longitude: lon,
        distanceMeters: meters,
      );
    }).toList()..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    if (!mounted) return;
    setState(() {
      _position = pos;
      _orgs = mapped;
      _loading = false;
    });
  }

  void _showOrgSheet(_NearbyOrg org) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.isPharmacy
                        ? AppColors.iconBgGreen
                        : AppColors.iconBgBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.isPharmacy
                        ? Icons.local_pharmacy_rounded
                        : Icons.medication_rounded,
                    color: widget.isPharmacy
                        ? AppColors.success
                        : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        org.address,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchMapsNavigation(
                      org.latitude,
                      org.longitude,
                      org.name,
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: Text(context.l10n.t('route')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (widget.isPharmacy) {
                        context.push(
                          Uri(
                            path: '/visits/pharmacy/detail/${org.id}',
                            queryParameters: {'name': org.name},
                          ).toString(),
                        );
                      } else {
                        context.push(
                          Uri(
                            path: '/visits/lpu/detail/${org.id}',
                            queryParameters: {
                              'name': org.name,
                              'address': org.address,
                            },
                          ).toString(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.t('open'),
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBg,
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              boxShadow: shadowSm,
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 8,
              16,
              12,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primaryText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isPharmacy
                      ? context.l10n.t('pharmaciesNearby')
                      : context.l10n.t('lpuNearby'),
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.iconBgBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    context.l10n.plural(_orgs.length, 'objects'),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(message: _error!, onRetry: _requestLocation)
                : _buildMap(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final userLat = _position!.latitude;
    final userLon = _position!.longitude;

    final markers = <Marker>[
      // User marker
      Marker(
        point: LatLng(userLat, userLon),
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: shadowMd,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
      ),
      // Org markers
      ..._orgs.map((org) {
        return Marker(
          point: LatLng(org.latitude, org.longitude),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => _showOrgSheet(org),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isPharmacy
                    ? AppColors.success
                    : AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: shadowSm,
              ),
              child: Icon(
                widget.isPharmacy
                    ? Icons.local_pharmacy_rounded
                    : Icons.medication_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        );
      }),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(userLat, userLon),
        initialZoom: 14.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.limapharma.limafield',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 64,
              color: AppColors.hintText,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 15,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                context.l10n.t('retry'),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
