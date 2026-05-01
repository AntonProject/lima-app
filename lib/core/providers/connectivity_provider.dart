import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Debug offline toggle ─────────────────────────────────────────────────────

/// Flip this to `true` in the UI (e.g. debug drawer) to simulate offline mode
/// regardless of the real network state.
final debugOfflineProvider = StateProvider<bool>((ref) => false);

// ─── Raw connectivity stream ──────────────────────────────────────────────────

final _connectivityResultProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// ─── isOfflineProvider ────────────────────────────────────────────────────────

/// Returns `true` when the device has no usable network connection.
///
/// Offline if:
///   • [debugOfflineProvider] is `true`, OR
///   • The connectivity stream reports only [ConnectivityResult.none]
///     (or only [ConnectivityResult.none] and/or [ConnectivityResult.unknown]).
///
/// Returns `false` while the stream is loading or in error state so that the
/// app does not block unnecessarily on startup.
final isOfflineProvider = Provider<bool>((ref) {
  final debugOffline = ref.watch(debugOfflineProvider);
  if (debugOffline) return true;

  final connectivityAsync = ref.watch(_connectivityResultProvider);

  return connectivityAsync.when(
    loading: () => false,
    error: (_, _) => false,
    data: (results) {
      if (results.isEmpty) return false;
      // Offline only when every reported result is none (or unknown).
      return results.every(
        (r) =>
            r == ConnectivityResult.none ||
            r == ConnectivityResult.bluetooth, // bluetooth ≠ internet
      );
    },
  );
});

final offlineBannerPulseProvider = StateProvider<int>((ref) => 0);

void pulseOfflineBanner(dynamic ref) {
  final notifier = ref.read(offlineBannerPulseProvider.notifier);
  notifier.state = notifier.state + 1;
}
