import 'package:geolocator/geolocator.dart';

class WorkdayCoordinates {
  final double latitude;
  final double longitude;

  const WorkdayCoordinates({required this.latitude, required this.longitude});

  const WorkdayCoordinates.fallback() : latitude = 0, longitude = 0;
}

/// Obtains a best-effort position for the workday check-in/checkout API.
///
/// The backend contract accepts `0,0` when location is unavailable. Keeping
/// that fallback here means the UI stays responsive after the five-second
/// acquisition budget, a declined permission, or unavailable services.
class WorkdayLocationService {
  const WorkdayLocationService();

  /// Total budget for the whole lookup. Only the position request used to be
  /// bounded, so a permission prompt that never returns left the workday action
  /// in progress forever and every further tap was ignored as a duplicate.
  static const _budget = Duration(seconds: 10);

  Future<WorkdayCoordinates> currentOrFallback() async {
    try {
      return await _resolve().timeout(_budget);
    } catch (_) {
      return const WorkdayCoordinates.fallback();
    }
  }

  Future<WorkdayCoordinates> _resolve() async {
    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) return const WorkdayCoordinates.fallback();

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const WorkdayCoordinates.fallback();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 5));
      return WorkdayCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return const WorkdayCoordinates.fallback();
    }
  }
}
