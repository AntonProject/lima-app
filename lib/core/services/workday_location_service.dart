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

  Future<WorkdayCoordinates> currentOrFallback() async {
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
