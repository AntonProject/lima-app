import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lima/core/i18n/app_i18n.dart';
import 'package:lima/core/network/api_client.dart';

const _localeCodeKey = 'app_locale_code';

class AppLocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;
  String _localeCode = 'ru';

  AppLocaleNotifier(this._ref) : super(const Locale('ru')) {
    final prefs = _ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_localeCodeKey);
    final parsed = _fromCode(saved);
    if (parsed != null) {
      state = parsed;
      _localeCode = saved ?? _toCode(parsed);
    }
    // Keep the context-free translator in sync for services/providers.
    AppI18n.global = AppI18n(state);
  }

  String get localeCode => _localeCode;

  Future<void> setLocale(String code) async {
    final next = _fromCode(code);
    if (next == null) return;
    _localeCode = code;
    if (next != state) {
      state = next;
    }
    AppI18n.global = AppI18n(next);
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_localeCodeKey, code);
  }

  static String _toCode(Locale locale) {
    if (locale.languageCode == 'uz' && locale.scriptCode == 'Cyrl') {
      return 'uz_cyrl';
    }
    if (locale.languageCode == 'uz') return 'uz_latn';
    return locale.languageCode;
  }

  static Locale? _fromCode(String? code) {
    switch (code) {
      case 'ru':
        return const Locale('ru');
      case 'en':
        return const Locale('en');
      case 'uz_latn':
      case 'uz':
        return const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Latn');
      case 'uz_cyrl':
        return const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl');
      default:
        return null;
    }
  }
}

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>((
  ref,
) {
  return AppLocaleNotifier(ref);
});

final appLocaleCodeProvider = Provider<String>((ref) {
  return ref.watch(appLocaleProvider.notifier).localeCode;
});
