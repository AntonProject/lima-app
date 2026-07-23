import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/theme/app_theme.dart';
import 'package:lima/features/home/screens/home_screen.dart';
import 'package:lima/features/home/providers/home_repository_provider.dart';
import 'package:lima/features/plan/providers/my_plan_provider.dart';
import 'package:lima/features/visits/screens/visits_hub_screen.dart';
import 'package:lima/features/visits/providers/visits_hub_provider.dart';
import '../providers/splash_bootstrap_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // Cold-start with empty DB needs more time to fetch orgs + drugs + visits.
  static const Duration _firstRunBudget = Duration(seconds: 60);
  // Warm start only awaits the home layer (visits/plans); the rest loads in the
  // background, so the splash can clear in ~5–10s. This is the safety deadline.
  static const Duration _warmBudget = Duration(seconds: 12);

  double _progress = 0.0;
  String _step = '';
  bool _canRetry = false;
  bool _loading = false;
  bool _navigated = false;
  int _dotCount = 0;
  Timer? _dotsTimer;
  // After this long the "almost done, please wait" reassurance replaces the
  // animated phase line for the remaining few seconds of a slow load.
  static const Duration _almostDoneAfter = Duration(seconds: 10);
  bool _almostDone = false;
  Timer? _almostDoneTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('[SPLASH] initState');
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
    _almostDoneTimer = Timer(_almostDoneAfter, () {
      if (!mounted || _navigated) return;
      setState(() => _almostDone = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[SPLASH] postFrameCallback');
      _load();
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _almostDoneTimer?.cancel();
    super.dispose();
  }

  void _safeGo(String route) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(route);
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    debugPrint('[SPLASH] _load started');
    try {
      if (mounted) {
        setState(() {
          _canRetry = false;
        });
      }

      debugPrint('[SPLASH] step 1: init DB');
      setState(() {
        _step = 'splashInitDb';
        _progress = 0.1;
      });
      final bootstrap = ref.read(splashBootstrapRepositoryProvider);
      await bootstrap.initializeDatabase();
      debugPrint('[SPLASH] db.init() done');
      await Future.delayed(const Duration(milliseconds: 300));

      // ── Auth check ────────────────────────────────────────────────────────────
      final hasToken = bootstrap.hasApiToken;
      final savedCreds = await bootstrap.loadCredentials();
      final hasOfflineSession =
          savedCreds != null &&
          await bootstrap.hasOfflineSessionFor(savedCreds.login);
      final isOnline = await bootstrap.hasRealInternet();

      if (!hasToken) {
        if (!isOnline) {
          if (hasOfflineSession) {
            debugPrint(
              '[SPLASH] offline + no token + owned local data -> offline mode',
            );
            setState(() {
              _step = 'splashOfflineMode';
              _progress = 0.9;
            });
            final loaded = await ref
                .read(authProvider.notifier)
                .loginOfflineWithCache();
            if (!loaded) {
              if (!mounted) return;
              _safeGo('/login');
              _loading = false;
              return;
            }
            unawaited(_startPlanPreload());
            await Future.delayed(const Duration(milliseconds: 250));
            if (!mounted) return;
            debugPrint('[SPLASH] navigating to /home (offline)');
            _safeGo('/home');
            _loading = false;
            return;
          }
          // No internet, no data, no token — show login screen
          debugPrint('[SPLASH] offline + no token + no data -> require login');
          if (!mounted) return;
          setState(() {
            _step = 'splashNoInternet';
            _progress = 0.9;
          });
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          _safeGo('/login');
          _loading = false;
          return;
        }

        // Online but no token — try silent re-auth with saved credentials
        setState(() {
          _step = 'splashRestoringSession';
          _progress = 0.2;
        });
        final reauthed = await _trySilentReauth();
        if (!reauthed) {
          if (hasOfflineSession) {
            debugPrint(
              '[SPLASH] reauth failed, owned local data exists -> offline mode',
            );
            setState(() {
              _step = 'splashOfflineMode';
              _progress = 0.9;
            });
            final loaded = await ref
                .read(authProvider.notifier)
                .loginOfflineWithCache();
            if (!loaded) {
              if (!mounted) return;
              _safeGo('/login');
              _loading = false;
              return;
            }
            unawaited(_startPlanPreload());
            await Future.delayed(const Duration(milliseconds: 250));
            if (!mounted) return;
            debugPrint('[SPLASH] navigating to /home (offline fallback)');
            _safeGo('/home');
            _loading = false;
            return;
          }
          debugPrint('[SPLASH] no token, no saved creds -> require login');
          if (!mounted) return;
          setState(() {
            _step = 'splashAuthRequired';
            _progress = 0.9;
          });
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          _safeGo('/login');
          _loading = false;
          return;
        }
        debugPrint('[SPLASH] silent reauth succeeded');
      }

      // ── Parallel sync with HARD budget ──────────────────────────────────────
      // Whatever happens — network hang, slow API, partial failure — the
      // splash MUST yield to /home within the budget. Anything still running
      // continues in the background. First run (empty DB) gets a longer
      // budget + full refresh so essential data is actually present on home.
      final isFirstRun = !(await bootstrap.hasLocalOrganizations());
      final budget = isFirstRun ? _firstRunBudget : _warmBudget;
      debugPrint(
        '[SPLASH] step 2: parallel sync (firstRun=$isFirstRun, budget=${budget.inSeconds}s)',
      );
      setState(() {
        _step = isFirstRun ? 'splashLoadingData' : 'splashUpdatingData';
        _progress = 0.35;
      });
      final syncNotifier = ref.read(syncProvider.notifier);
      // Kick off doctors concurrently — fire-and-forget, never awaited here.
      syncNotifier.syncDoctorsInBackground();
      final currentYearPlan = _startPlanPreload();

      final budgetTimer = Stopwatch()..start();
      // Animate progress bar from 0.35 → 0.9 over the budget so the user sees
      // motion even when the per-step messages don't change.
      Timer.periodic(const Duration(milliseconds: 500), (t) {
        if (!mounted || _navigated) {
          t.cancel();
          return;
        }
        final elapsed = budgetTimer.elapsedMilliseconds / budget.inMilliseconds;
        final clamped = elapsed.clamp(0.0, 1.0);
        setState(() {
          _progress = 0.35 + (clamped * 0.55);
        });
      });

      final syncFuture = syncNotifier
          .syncLayeredFromRemote(
            pushPendingFirst: true,
            skipDoctors: true,
            fullRefresh: isFirstRun,
            // Warm start: only the home layer (visits/plans) is awaited here;
            // the org directory + drug catalogue keep loading in the background
            // so the splash clears fast. First run loads everything up front.
            homeOnly: !isFirstRun,
          )
          .catchError((Object e) {
            debugPrint('[SPLASH] sync error: $e');
          });
      final deadline = Future<void>.delayed(budget);
      // Warm start clears quickly (home layer only); first run keeps a small
      // floor so the user sees progress and essential data has time to land.
      final minDelay = Future<void>.delayed(
        isFirstRun
            ? const Duration(seconds: 4)
            : const Duration(milliseconds: 1200),
      );
      // Wait for (sync OR deadline) AND the minimum floor.
      await Future.wait<void>([
        Future.any<void>([syncFuture, deadline]),
        minDelay,
      ]);

      // Best-effort prewarm with its own 5s cap — never block past the budget.
      try {
        await Future.wait([
          HomeScreen.preload(ref.read(homeRepositoryProvider)),
          VisitsHubScreen.preload(
            ref.read(organisationsDirectoryRepositoryProvider),
          ),
          currentYearPlan,
        ]).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[SPLASH] preload skipped: $e');
      }
      unawaited(ref.read(syncProvider.notifier).refreshUnsyncedCount());
    } catch (e, st) {
      debugPrint('[SPLASH] ERROR: $e');
      debugPrint('[SPLASH] STACK: $st');
      final bootstrap = ref.read(splashBootstrapRepositoryProvider);
      final savedCreds = await bootstrap.loadCredentials();
      final hasOfflineSession =
          savedCreds != null &&
          await bootstrap.hasOfflineSessionFor(savedCreds.login);
      if (hasOfflineSession) {
        debugPrint(
          '[SPLASH] sync failed, but owned local data exists -> continue offline',
        );
        final loaded = await ref
            .read(authProvider.notifier)
            .loginOfflineWithCache();
        if (!loaded) {
          if (!mounted) return;
          _safeGo('/login');
          _loading = false;
          return;
        }
        unawaited(_startPlanPreload());
        _trySilentReauthBackground();
        if (!mounted) return;
        _safeGo('/home');
        _loading = false;
        return;
      }
      if (!mounted) return;
      setState(() {
        _step = 'splashSyncError';
        _progress = 0.0;
        _canRetry = true;
      });
      _loading = false;
      return;
    }

    debugPrint('[SPLASH] before final setState');
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('[SPLASH] navigating to /home');
    if (!mounted) return;
    // Doctors are already running in background (kicked off above in parallel
    // with the critical sync). Just navigate.
    _safeGo('/home');
    debugPrint('[SPLASH] DONE');
    _loading = false;
  }

  /// Attempts silent re-auth. Returns true if token was obtained successfully.
  Future<bool> _trySilentReauth() async {
    try {
      return await ref.read(authProvider.notifier).silentReauth();
    } catch (_) {
      return false;
    }
  }

  /// Fire-and-forget background reauth (used when going offline with local data).
  void _trySilentReauthBackground() {
    ref.read(authProvider.notifier).silentReauth().ignore();
  }

  Future<void> _startPlanPreload() {
    final currentYear = DateTime.now().year;
    final currentYearLoad = ref
        .read(myPlanProvider(currentYear).notifier)
        .load();

    // The current year is awaited by the splash preload budget. Adjacent
    // years are useful when the user switches the year chips, but must never
    // delay navigation to the home screen.
    for (final year in [currentYear - 1, currentYear + 1]) {
      unawaited(ref.read(myPlanProvider(year).notifier).load());
    }
    return currentYearLoad;
  }

  Future<void> _exitToLogin() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    _safeGo('/login');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[SPLASH] build called');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: IconButton(
                onPressed: _exitToLogin,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: context.l10n.t('logout'),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/lima_logo_1.png',
                    width: 160,
                    height: 160,
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: 180,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final baseStyle = TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      );
                      if (_canRetry) {
                        return Text(
                          _step.isEmpty ? '' : context.l10n.t(_step),
                          style: baseStyle,
                          textAlign: TextAlign.center,
                        );
                      }
                      // Slow load: after ~10s swap the animated phase line for a
                      // reassuring "almost done, please wait" message.
                      if (_almostDone && _loading) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            context.l10n.t('splashAlmostDone'),
                            style: baseStyle,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      // Rebuild on sync progress so the dots keep animating,
                      // but show the localized phase text (_step) rather than
                      // syncProvider.message: the latter is set inside the
                      // notifier without a BuildContext and is Russian-only.
                      ref.watch(syncProvider);
                      final stepText = _step.isEmpty
                          ? ''
                          : context.l10n.t(_step);
                      final base = stepText.replaceFirst(
                        RegExp(r'[.…]+\s*$'),
                        '',
                      );
                      // Reserve space for 3 dots so the centered text doesn't
                      // shift left/right as dots animate. Hidden dots are
                      // rendered transparent.
                      final visible = _loading ? _dotCount : 0;
                      return RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: baseStyle,
                          children: [
                            TextSpan(text: base),
                            TextSpan(
                              text: '.',
                              style: TextStyle(
                                color: visible >= 1
                                    ? baseStyle.color
                                    : Colors.transparent,
                              ),
                            ),
                            TextSpan(
                              text: '.',
                              style: TextStyle(
                                color: visible >= 2
                                    ? baseStyle.color
                                    : Colors.transparent,
                              ),
                            ),
                            TextSpan(
                              text: '.',
                              style: TextStyle(
                                color: visible >= 3
                                    ? baseStyle.color
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_canRetry) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(context.l10n.t('retry')),
                    ),
                  ],
                ],
              ),
            ),
            // Always-visible brand thank-you anchored to the bottom.
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: Text(
                context.l10n.t('splashThankYou'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
