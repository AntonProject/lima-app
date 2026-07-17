import 'package:sqflite/sqflite.dart';

import '../db/local_database.dart';
import '../network/remote_api_service.dart';

typedef DoctorDirectoryProgress =
    Future<void> Function({
      required int loaded,
      required int cursor,
      required int? expectedTotal,
    });

/// Owns the long-running doctor directory repair flow.
///
/// The sync notifier still decides when this service should run and how its
/// progress is presented. This service owns the cursor, relations bootstrap,
/// batch size and completion check so those details are not duplicated across
/// launch, manual and background sync paths.
class DoctorDirectorySyncService {
  static const bootstrapMetaKey = 'doctor_directory_bootstrap_v1_done';
  static const expectedTotalMetaKey = 'doctor_directory_expected_total';
  static const cursorMetaKey = 'doctor_directory_sync_id';

  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final bool Function() _isOffline;
  final int? Function() _currentRegionId;
  final DoctorDirectoryProgress _onProgress;

  const DoctorDirectorySyncService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
    required bool Function() isOffline,
    required int? Function() currentRegionId,
    required DoctorDirectoryProgress onProgress,
  }) : _db = db,
       _remoteApi = remoteApi,
       _isOffline = isOffline,
       _currentRegionId = currentRegionId,
       _onProgress = onProgress;

  Future<bool> needsRepair({
    required int localLpuCount,
    required int localDoctorCount,
  }) async {
    if (localLpuCount == 0) return false;

    final bootstrapped = await _isBootstrapped();
    var expectedTotal = await _expectedTotal();
    if (expectedTotal == null && !_isOffline()) {
      try {
        final remoteTotal = await _remoteApi.getDoctorsDictionaryTotal();
        if (remoteTotal != null && remoteTotal > 0) {
          expectedTotal = remoteTotal;
          await _setExpectedTotal(remoteTotal);
        }
      } catch (_) {
        // A failed count probe must not block using the local directory.
      }
    }

    if (expectedTotal != null &&
        expectedTotal > 0 &&
        localDoctorCount < expectedTotal) {
      return true;
    }
    if (!bootstrapped && expectedTotal == null) return true;
    if (!bootstrapped && localDoctorCount <= 5000) return true;
    if (localDoctorCount == 0) return true;
    if (_currentRegionId() != null && localDoctorCount < 100) return true;
    return await _doctorLinksCount() == 0;
  }

  Future<bool> isBootstrapped() => _isBootstrapped();

  Future<void> markBootstrapped() => _markBootstrapped();

  Future<int> repair() async {
    final localDoctorCount = await _doctorCount();
    if (!await needsRepair(
      localLpuCount: await _lpuCount(),
      localDoctorCount: localDoctorCount,
    )) {
      return 0;
    }

    final relations = await _remoteApi.getDoctorOrganisationRelations(
      syncId: 0,
    );
    if (relations.isNotEmpty) {
      await _db.upsertDoctorOrganisationLinks(relations);
    }

    // Always refresh the server total. A cached total must not prevent loading
    // doctors added after the previous repair.
    final freshTotal = await _remoteApi.getDoctorsDictionaryTotal();
    final expectedTotal = freshTotal != null && freshTotal > 0
        ? freshTotal
        : await _expectedTotal();
    if (expectedTotal != null && expectedTotal > 0) {
      await _setExpectedTotal(expectedTotal);
    }

    var cursor = await _cursor();
    if (expectedTotal != null &&
        expectedTotal > 0 &&
        cursor >= expectedTotal &&
        localDoctorCount < expectedTotal) {
      cursor = 0;
      await _setCursor(0);
    }

    var fetchedCount = 0;
    await _remoteApi.getDoctorsSyncBatched(
      syncId: cursor,
      batchSize: 1000,
      collectRows: false,
      onBatch: (pageDoctors, loaded, nextCursor) async {
        fetchedCount = loaded;
        if (pageDoctors.isNotEmpty) {
          await _db.upsertDoctors(pageDoctors);
        }
        await _setCursor(nextCursor);
        await _onProgress(
          loaded: loaded,
          cursor: nextCursor,
          expectedTotal: expectedTotal,
        );
      },
    );

    final afterDoctors = await _doctorCount();
    final latestExpectedTotal = await _expectedTotal();
    final latestCursor = await _cursor();
    final hasExpectedDoctors =
        latestExpectedTotal == null ||
        latestExpectedTotal <= 0 ||
        afterDoctors >= latestExpectedTotal ||
        latestCursor >= latestExpectedTotal;
    if (hasExpectedDoctors &&
        afterDoctors > 0 &&
        await _doctorLinksCount() > 0) {
      await _markBootstrapped();
    }
    return fetchedCount;
  }

  Future<bool> _isBootstrapped() async {
    return await _db.getSyncMeta(bootstrapMetaKey) == '1';
  }

  Future<void> _markBootstrapped() async {
    await _db.setSyncMeta(bootstrapMetaKey, '1');
  }

  Future<int?> _expectedTotal() async {
    return int.tryParse(await _db.getSyncMeta(expectedTotalMetaKey) ?? '');
  }

  Future<void> _setExpectedTotal(int total) async {
    if (total > 0) {
      await _db.setSyncMeta(expectedTotalMetaKey, '$total');
    }
  }

  Future<int> _cursor() async {
    return int.tryParse(await _db.getSyncMeta(cursorMetaKey) ?? '') ?? 0;
  }

  Future<void> _setCursor(int cursor) async {
    if (cursor >= 0) {
      await _db.setSyncMeta(cursorMetaKey, '$cursor');
    }
  }

  Future<int> _doctorCount() async {
    final rows = await _db.db.rawQuery('SELECT COUNT(*) AS c FROM doctors');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> _lpuCount() async {
    final rows = await _db.db.rawQuery(
      "SELECT COUNT(*) AS c FROM organisations WHERE type = 'lpu'",
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> _doctorLinksCount() async {
    final rows = await _db.db.rawQuery(
      'SELECT COUNT(*) AS c FROM doctor_organisations',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
