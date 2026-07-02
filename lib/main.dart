import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/network/api_client.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/local_notifications_service.dart';

void main() async {
  debugPrint('[MAIN] start');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[MAIN] binding done');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  debugPrint('[MAIN] prefs done');
  final apiClient = ApiClient(prefs);
  await apiClient.init();
  debugPrint('[MAIN] api client ready');
  await BackgroundSyncService.initialize();
  debugPrint('[MAIN] background sync initialized');
  await LocalNotificationsService.instance.init();
  debugPrint('[MAIN] local notifications initialized');

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(apiClient),
      ],
      child: const LimaApp(),
    ),
  );
  debugPrint('[MAIN] runApp done');
}
