import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:lima/core/auth/credentials_storage.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/models/models.dart';
import 'package:lima/core/network/api_client.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/providers/sync_provider.dart';

const String limaBackgroundSyncTask = 'lima.background.sync';
const String limaBackgroundSyncUniqueName = 'lima.background.sync.now';
const String limaBackgroundSyncPeriodicName = 'lima.background.sync.periodic';
const String limaIOSBackgroundProcessingIdentifier =
    'uz.lima.lima.backgroundSync';

@pragma('vm:entry-point')
void limaBackgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final isSyncTask =
        task == limaBackgroundSyncTask ||
        task == limaIOSBackgroundProcessingIdentifier ||
        task == Workmanager.iOSBackgroundTask;
    if (!isSyncTask) return true;

    final fullRefresh = inputData?['fullRefresh'] == true;
    return BackgroundSyncService.runHeadless(fullRefresh: fullRefresh);
  });
}

class BackgroundSyncService {
  static Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await Workmanager().initialize(limaBackgroundSyncDispatcher);
      await schedulePeriodicSync();
    } catch (e) {
      debugPrint('BackgroundSyncService.initialize failed: $e');
    }
  }

  static Future<void> scheduleSyncNow({bool fullRefresh = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final inputData = <String, dynamic>{
      'fullRefresh': fullRefresh,
      'requestedAt': DateTime.now().toIso8601String(),
    };
    final constraints = Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    );

    try {
      if (Platform.isIOS) {
        // Gives iOS a short "finish current work" window right after suspend.
        await Workmanager().registerOneOffTask(
          limaBackgroundSyncUniqueName,
          limaBackgroundSyncTask,
          inputData: inputData,
          initialDelay: const Duration(seconds: 1),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: constraints,
        );
        // Also schedule BGProcessing for a later system-approved window.
        await Workmanager().registerProcessingTask(
          limaIOSBackgroundProcessingIdentifier,
          limaBackgroundSyncTask,
          inputData: inputData,
          initialDelay: const Duration(minutes: 1),
          constraints: constraints,
        );
        return;
      }

      await Workmanager().registerOneOffTask(
        limaBackgroundSyncUniqueName,
        limaBackgroundSyncTask,
        inputData: inputData,
        initialDelay: const Duration(seconds: 1),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: constraints,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
        tag: limaBackgroundSyncTask,
      );
    } catch (e) {
      debugPrint('BackgroundSyncService.scheduleSyncNow failed: $e');
    }
  }

  static Future<void> schedulePeriodicSync() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final constraints = Constraints(networkType: NetworkType.connected);
    try {
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          limaBackgroundSyncPeriodicName,
          limaBackgroundSyncTask,
          frequency: const Duration(minutes: 15),
          constraints: constraints,
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          tag: limaBackgroundSyncTask,
        );
      } else {
        await Workmanager().registerProcessingTask(
          limaIOSBackgroundProcessingIdentifier,
          limaBackgroundSyncTask,
          initialDelay: const Duration(minutes: 15),
          constraints: constraints,
        );
      }
    } catch (e) {
      debugPrint('BackgroundSyncService.schedulePeriodicSync failed: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> runHeadless({bool fullRefresh = false}) async {
    final startedAt = DateTime.now();
    debugPrint(
      'BackgroundSync: started fullRefresh=$fullRefresh at $startedAt',
    );
    SyncNotifier? sync;
    try {
      final prefs = await SharedPreferences.getInstance();
      final db = LocalDatabase();
      await db.init();

      final api = ApiClient(prefs);
      final remoteApi = RemoteApiService(api);
      final creds = CredentialsStorage();
      final user = await _loadCachedUser(prefs, creds);

      if (!api.hasToken) {
        final saved = await creds.load();
        if (saved == null) {
          debugPrint('BackgroundSync: no credentials, aborting');
          return false;
        }
        final token = await remoteApi.authorize(
          login: saved.login,
          password: saved.password,
        );
        await api.saveToken(token);
      }

      sync = SyncNotifier(
        db,
        remoteApi,
        api,
        () => false,
        () async {
          final saved = await creds.load();
          if (saved == null) return false;
          final token = await remoteApi.authorize(
            login: saved.login,
            password: saved.password,
          );
          await api.saveToken(token);
          return true;
        },
        () => user?.regionId,
        () => user?.companyId,
      );

      try {
        await sync.pushToRemote();
      } catch (e) {
        // Keep loading server data even if an old pending record is rejected.
        debugPrint('BackgroundSync: push error (non-fatal): $e');
      }
      await sync.syncLayeredFromRemote(
        fullRefresh: fullRefresh,
        pushPendingFirst: false,
      );
      final elapsed = DateTime.now().difference(startedAt);
      debugPrint('BackgroundSync: completed in ${elapsed.inSeconds}s');
      return true;
    } catch (e) {
      final elapsed = DateTime.now().difference(startedAt);
      debugPrint(
        'BackgroundSync: failed after ${elapsed.inSeconds}s — $e',
      );
      return false;
    } finally {
      sync?.dispose();
      if (Platform.isIOS) {
        unawaited(schedulePeriodicSync());
        debugPrint('BackgroundSync: iOS periodic task rescheduled');
      }
    }
  }

  static Future<UserModel?> _loadCachedUser(
    SharedPreferences prefs,
    CredentialsStorage creds,
  ) async {
    final saved = await creds.load();
    if (saved == null) return null;
    final raw = prefs.getString('cached_user_profile::${saved.login}');
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
