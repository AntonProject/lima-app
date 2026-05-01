import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/network/api_client.dart';

void main() async {
  debugPrint('[MAIN] start');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[MAIN] binding done');

  final prefs = await SharedPreferences.getInstance();
  debugPrint('[MAIN] prefs done');

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LimaApp(),
    ),
  );
  debugPrint('[MAIN] runApp done');
}
