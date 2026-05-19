import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Raw connectivity stream ──────────────────────────────────────────────────

final _connectivityResultProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

// ─── isOfflineProvider ────────────────────────────────────────────────────────

/// Returns `true` when the device has no usable network connection.
///
/// Offline if:
///   • The connectivity stream reports only [ConnectivityResult.none]
///     (or only [ConnectivityResult.none] and/or [ConnectivityResult.bluetooth]).
///
/// Returns `false` while the stream is loading or in error state so that the
/// app does not block unnecessarily on startup.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(_connectivityResultProvider);

  return connectivityAsync.when(
    loading: () => false,
    error: (_, _) => false,
    data: (results) {
      if (results.isEmpty) return false;
      // Offline only when every reported result is none or bluetooth.
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
