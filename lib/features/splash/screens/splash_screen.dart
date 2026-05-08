import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lima/core/auth/credentials_storage.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/features/auth/providers/auth_provider.dart';
import 'package:lima/core/providers/sync_provider.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  double _progress = 0.0;
  String _step = '';
  bool _canRetry = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[SPLASH] initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[SPLASH] postFrameCallback');
      _load();
    });
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
        _step = 'Инициализация базы данных...';
        _progress = 0.1;
      });
      final db = ref.read(localDatabaseProvider);
      await db.init();
      debugPrint('[SPLASH] db.init() done');
      await Future.delayed(const Duration(milliseconds: 300));

      // ── Auth check ────────────────────────────────────────────────────────────
      final hasToken = ref.read(apiClientProvider).hasToken;
      final savedCreds = await ref.read(credentialsStorageProvider).load();
      final hasOfflineSession =
          savedCreds != null &&
          await db.hasUsableOfflineSessionForLogin(savedCreds.login);
      final isOnline = await _checkOnline();

      if (!hasToken) {
        if (!isOnline) {
          if (hasOfflineSession) {
            debugPrint(
              '[SPLASH] offline + no token + owned local data -> offline mode',
            );
            setState(() {
              _step = 'Офлайн режим...';
              _progress = 0.9;
            });
            final loaded = await ref
                .read(authProvider.notifier)
                .loginOfflineWithCache();
            if (!loaded) {
              context.go('/login');
              _loading = false;
              return;
            }
            await Future.delayed(const Duration(milliseconds: 250));
            if (!mounted) return;
            debugPrint('[SPLASH] navigating to /home (offline)');
            context.go('/home');
            _loading = false;
            return;
          }
          // No internet, no data, no token — show login screen
          debugPrint('[SPLASH] offline + no token + no data -> require login');
          if (!mounted) return;
          setState(() {
            _step = 'Нет подключения к интернету...';
            _progress = 0.9;
          });
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          context.go('/login');
          _loading = false;
          return;
        }

        // Online but no token — try silent re-auth with saved credentials
        setState(() {
          _step = 'Восстановление сессии...';
          _progress = 0.2;
        });
        final reauthed = await _trySilentReauth();
        if (!reauthed) {
          if (hasOfflineSession) {
            debugPrint(
              '[SPLASH] reauth failed, owned local data exists -> offline mode',
            );
            setState(() {
              _step = 'Офлайн режим...';
              _progress = 0.9;
            });
            final loaded = await ref
                .read(authProvider.notifier)
                .loginOfflineWithCache();
            if (!loaded) {
              context.go('/login');
              _loading = false;
              return;
            }
            await Future.delayed(const Duration(milliseconds: 250));
            if (!mounted) return;
            debugPrint('[SPLASH] navigating to /home (offline fallback)');
            context.go('/home');
            _loading = false;
            return;
          }
          debugPrint('[SPLASH] no token, no saved creds -> require login');
          if (!mounted) return;
          setState(() {
            _step = 'Требуется авторизация...';
            _progress = 0.9;
          });
          await Future.delayed(const Duration(milliseconds: 250));
          if (!mounted) return;
          context.go('/login');
          _loading = false;
          return;
        }
        debugPrint('[SPLASH] silent reauth succeeded');
      }

      // ── Sync ──────────────────────────────────────────────────────────────────
      debugPrint('[SPLASH] step 2: sync (delta-first)');
      setState(() {
        _step = 'Синхронизация данных...';
        _progress = 0.35;
      });
      await ref
          .read(syncProvider.notifier)
          .pullFromRemote(includeDoctors: false, repairDoctors: false)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint('[SPLASH] quick sync timeout -> continue to app');
            },
          );
      debugPrint('[SPLASH] sync done');
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint('[SPLASH] step 3: finalize counters');
      setState(() {
        _step = 'Проверка локальных данных...';
        _progress = 0.75;
      });
      await ref.read(syncProvider.notifier).refreshUnsyncedCount();
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e, st) {
      debugPrint('[SPLASH] ERROR: $e');
      debugPrint('[SPLASH] STACK: $st');
      final db = ref.read(localDatabaseProvider);
      final savedCreds = await ref.read(credentialsStorageProvider).load();
      final hasOfflineSession =
          savedCreds != null &&
          await db.hasUsableOfflineSessionForLogin(savedCreds.login);
      if (hasOfflineSession) {
        debugPrint(
          '[SPLASH] sync failed, but owned local data exists -> continue offline',
        );
        final loaded = await ref
            .read(authProvider.notifier)
            .loginOfflineWithCache();
        if (!loaded) {
          context.go('/login');
          _loading = false;
          return;
        }
        _trySilentReauthBackground();
        if (!mounted) return;
        context.go('/home');
        _loading = false;
        return;
      }
      if (!mounted) return;
      setState(() {
        _step =
            'Ошибка синхронизации. Проверьте интернет и перезапустите приложение.';
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
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('[SPLASH] navigating to /home');
    if (!mounted) return;
    _startBackgroundDoctorSync();
    context.go('/home');
    debugPrint('[SPLASH] DONE');
    _loading = false;
  }

  void _startBackgroundDoctorSync() {
    final sync = ref.read(syncProvider.notifier);
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        await sync.pullFromRemote();
      } catch (_) {
        // Background sync should never block app entry.
      }
    });
  }

  Future<bool> _checkOnline() async {
    try {
      final result = await InternetAddress.lookup(
        'crm.lima.uz',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
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

  Future<void> _exitToLogin() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
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
                tooltip: 'Выйти',
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LIMA',
                    style: GoogleFonts.figtree(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: 240,
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
                  Text(
                    _step,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_canRetry) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Повторить'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
