import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/providers/auth_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/form_dictionaries_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/background_sync_service.dart';
import 'core/theme/app_theme.dart';

class LimaApp extends ConsumerStatefulWidget {
  const LimaApp({super.key});

  @override
  ConsumerState<LimaApp> createState() => _LimaAppState();
}

class _LimaAppState extends ConsumerState<LimaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resumeForegroundSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) return;

    if (state == AppLifecycleState.resumed) {
      _resumeForegroundSync();
      return;
    }

    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    unawaited(BackgroundSyncService.scheduleSyncNow());
  }

  void _resumeForegroundSync() {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) return;
    unawaited(ref.read(syncProvider.notifier).reconcileInBackground());
    unawaited(ref.read(formDictionariesProvider).prefetchAll());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      final becameAuthenticated =
          prev?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated;
      if (!becameAuthenticated) return;
      _resumeForegroundSync();
    });

    ref.listen<bool>(isOfflineProvider, (prev, next) {
      if (prev == true && next == false) {
        unawaited(ref.read(syncProvider.notifier).reconcileInBackground());
      }
    });

    return MaterialApp.router(
      title: 'LIMA CRM',
      theme: AppTheme.light,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
        Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Latn'),
        Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
