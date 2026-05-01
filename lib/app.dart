import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/providers/auth_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class LimaApp extends ConsumerWidget {
  const LimaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(appLocaleProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      final becameAuthenticated =
          prev?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated;
      if (!becameAuthenticated) return;
      unawaited(ref.read(syncProvider.notifier).reconcileInBackground());
    });

    ref.listen<bool>(isOfflineProvider, (prev, next) {
      if (prev == true && next == false) {
        unawaited(ref.read(syncProvider.notifier).reconcileInBackground());
      }
    });

    return MaterialApp.router(
      title: 'LIMA',
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
