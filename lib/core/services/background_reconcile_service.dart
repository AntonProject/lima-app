import 'package:lima/core/network/api_client.dart';

/// Applies the network/auth gate before a silent launch delta reconcile.
class BackgroundReconcileService {
  final ApiClient _apiClient;
  final bool Function() _isOffline;
  final Future<bool> Function() _hasRealInternet;
  final Future<bool> Function() _silentReauth;

  const BackgroundReconcileService({
    required ApiClient apiClient,
    required bool Function() isOffline,
    required Future<bool> Function() hasRealInternet,
    required Future<bool> Function() silentReauth,
  }) : _apiClient = apiClient,
       _isOffline = isOffline,
       _hasRealInternet = hasRealInternet,
       _silentReauth = silentReauth;

  Future<void> run({required Future<void> Function() syncLaunchDelta}) async {
    if (_isOffline()) return;
    // Connectivity can report a transport while the API host is unreachable.
    if (!await _hasRealInternet()) return;
    if (!_apiClient.hasToken && !await _silentReauth()) return;
    await syncLaunchDelta();
  }
}
