import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/config/env_config.dart';

/// Tracks actual reachability of the API host.
///
/// `connectivity_plus` reports the available transport (for example Wi-Fi),
/// but on iOS Simulator it can temporarily emit `none` while the simulator
/// still has working internet. The app needs the API reachability as its
/// source of truth, so every transport event is followed by a DNS probe to
/// the current environment host.
class ConnectivityStatusNotifier extends StateNotifier<bool> {
  ConnectivityStatusNotifier() : super(false) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(refresh());
    });
    _probeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refresh());
    });
    unawaited(refresh());
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _probeTimer;
  Future<void>? _inFlightProbe;

  Future<void> refresh() {
    final running = _inFlightProbe;
    if (running != null) return running;

    final probe = _refreshFromApiReachability();
    _inFlightProbe = probe;
    return probe.whenComplete(() {
      if (identical(_inFlightProbe, probe)) {
        _inFlightProbe = null;
      }
    });
  }

  Future<void> _refreshFromApiReachability() async {
    try {
      final result = await InternetAddress.lookup(
        EnvConfig.connectivityHost,
      ).timeout(const Duration(seconds: 5));
      state = !(result.isNotEmpty && result.first.rawAddress.isNotEmpty);
    } catch (_) {
      state = true;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _probeTimer?.cancel();
    super.dispose();
  }
}

/// `true` only when the current API environment cannot be reached.
final isOfflineProvider =
    StateNotifierProvider<ConnectivityStatusNotifier, bool>(
      (ref) => ConnectivityStatusNotifier(),
    );

final offlineBannerPulseProvider = StateProvider<int>((ref) => 0);

void pulseOfflineBanner(dynamic ref) {
  final notifier = ref.read(offlineBannerPulseProvider.notifier);
  notifier.state = notifier.state + 1;
}
