import 'dart:convert';
import 'dart:io';

import 'package:lima/core/db/local_database.dart';
import 'package:lima/core/network/remote_api_service.dart';
import 'package:lima/core/utils/swallowed.dart';

class PendingMutationFailure {
  final String type;
  final int? id;
  final String message;

  const PendingMutationFailure({
    required this.type,
    required this.message,
    this.id,
  });

  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'error': message};
}

class PendingMutationSyncResult {
  final List<PendingMutationFailure> failures;

  const PendingMutationSyncResult({this.failures = const []});

  bool get hasFailures => failures.isNotEmpty;
}

/// Flushes local mutation queues that are independent from visit submission.
///
/// The service deliberately does not own [SyncState]. It returns typed queue
/// failures so the application layer can combine them with visit-push results
/// and publish one diagnostic report.
class PendingMutationSyncService {
  final LocalDatabase _db;
  final RemoteApiService _remoteApi;
  final bool Function() _isOffline;

  const PendingMutationSyncService({
    required LocalDatabase db,
    required RemoteApiService remoteApi,
    required bool Function() isOffline,
  }) : _db = db,
       _remoteApi = remoteApi,
       _isOffline = isOffline;

  Future<PendingMutationSyncResult> sync() async {
    if (_isOffline()) return const PendingMutationSyncResult();

    final failures = <PendingMutationFailure>[];
    await _runStage(failures, 'favorites_read', () => _syncFavorites(failures));
    await _runStage(failures, 'feedback_read', () => _syncFeedback(failures));
    await _runStage(failures, 'doctors_read', () => _syncDoctors(failures));
    await _runStage(
      failures,
      'organization_updates_read',
      () => _syncOrganizationUpdates(failures),
    );
    await _runStage(
      failures,
      'organizations_read',
      () => _syncOrganizations(failures),
    );
    return PendingMutationSyncResult(failures: failures);
  }

  Future<void> _runStage(
    List<PendingMutationFailure> failures,
    String type,
    Future<void> Function() stage,
  ) async {
    try {
      await stage();
    } catch (error) {
      _addFailure(failures, type, error);
    }
  }

  Future<void> _syncFavorites(List<PendingMutationFailure> failures) async {
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _db.getPendingFavorites();
    } catch (error) {
      _addFailure(failures, 'favorites_read', error);
      return;
    }

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final entityType = row['entity_type']?.toString();
      final entityId = (row['entity_id'] as num?)?.toInt();
      if (id == null || entityId == null) {
        _addFailure(
          failures,
          'favorite_parse',
          StateError('Invalid row'),
          id: id,
        );
        continue;
      }
      final add = row['action'] == 'add';
      try {
        if (entityType == 'doctor') {
          if (add) {
            await _remoteApi.addDoctorToFavorites(entityId);
          } else {
            await _remoteApi.removeDoctorFromFavorites(entityId);
          }
        } else {
          if (add) {
            await _remoteApi.addOrganizationToFavorites(entityId);
          } else {
            await _remoteApi.removeOrganizationFromFavorites(entityId);
          }
        }
        await _db.deletePendingFavorite(id);
      } catch (error) {
        await _db.recordPendingFavoriteFailure(id);
        _addFailure(failures, 'favorite', error, id: id);
      }
    }
  }

  Future<void> _syncFeedback(List<PendingMutationFailure> failures) async {
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _db.getPendingFeedback();
    } catch (error) {
      _addFailure(failures, 'feedback_read', error);
      return;
    }

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      if (id == null) {
        _addFailure(failures, 'feedback_parse', StateError('Invalid row'));
        continue;
      }
      try {
        final rawPaths = row['photo_paths'] as String? ?? '[]';
        final decoded = jsonDecode(rawPaths);
        final photoPaths = decoded is List
            ? decoded.map((path) => '$path').toList()
            : const <String>[];
        await _remoteApi.sendFeedback(
          message: row['message'] as String,
          photoPaths: photoPaths,
        );
        await _db.deletePendingFeedback(id);
        for (final path in photoPaths) {
          try {
            File(path).deleteSync();
          } catch (error) {
            logSwallowed(error, 'PendingMutationSyncService.feedback_file');
          }
        }
      } catch (error) {
        await _db.recordPendingFeedbackFailure(id);
        _addFailure(failures, 'feedback', error, id: id);
      }
    }
  }

  Future<void> _syncDoctors(List<PendingMutationFailure> failures) async {
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _db.getPendingDoctors();
    } catch (error) {
      _addFailure(failures, 'doctors_read', error);
      return;
    }

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final tempLocalId = (row['temp_local_id'] as num?)?.toInt();
      final orgId = (row['org_id'] as num?)?.toInt();
      final specializationId = (row['specialization_id'] as num?)?.toInt();
      if (id == null || tempLocalId == null || orgId == null) {
        _addFailure(
          failures,
          'doctor_parse',
          StateError('Invalid row'),
          id: id,
        );
        continue;
      }
      if (specializationId == null) {
        await _db.markPendingDoctorFailed(id);
        _addFailure(
          failures,
          'doctor_validation',
          StateError('specialization_id is missing'),
          id: id,
        );
        continue;
      }
      try {
        final remoteId = await _remoteApi.addDoctor(
          organizationId: orgId,
          fullName: row['full_name'] as String,
          specializationId: specializationId,
          phone: row['phone'] as String?,
          hobby: row['hobby'] as String?,
          interests: row['interests'] as String?,
          birthday: row['birthday'] as String?,
        );
        if (remoteId != null) {
          await _db.replaceDoctorTempId(tempLocalId, remoteId);
          await _db.deletePendingDoctor(id);
        }
      } catch (error) {
        _addFailure(failures, 'doctor', error, id: id);
      }
    }
  }

  Future<void> _syncOrganizationUpdates(
    List<PendingMutationFailure> failures,
  ) async {
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _db.getPendingOrgUpdates();
    } catch (error) {
      _addFailure(failures, 'organization_updates_read', error);
      return;
    }

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final orgId = (row['org_id'] as num?)?.toInt();
      if (id == null || orgId == null) {
        _addFailure(
          failures,
          'organization_update_parse',
          StateError('Invalid row'),
          id: id,
        );
        continue;
      }
      try {
        await _remoteApi.updateOrganization(
          organizationId: orgId,
          name: row['name'] as String,
          address: row['address'] as String,
          phone: row['phone'] as String?,
          city: row['city'] as String?,
          district: row['district'] as String?,
          inn: row['inn'] as String?,
          category: row['category'] as String?,
          responsiblePerson: row['responsible'] as String?,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
        );
        await _db.deletePendingOrgUpdate(id);
      } catch (error) {
        _addFailure(failures, 'organization_update', error, id: id);
      }
    }
  }

  Future<void> _syncOrganizations(List<PendingMutationFailure> failures) async {
    late final List<Map<String, dynamic>> rows;
    try {
      rows = await _db.getPendingOrganizations();
    } catch (error) {
      _addFailure(failures, 'organizations_read', error);
      return;
    }

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final tempLocalId = (row['temp_local_id'] as num?)?.toInt();
      if (id == null || tempLocalId == null) {
        _addFailure(
          failures,
          'organization_parse',
          StateError('Invalid row'),
          id: id,
        );
        continue;
      }
      try {
        final remoteId = await _remoteApi.createOrganization(
          name: row['name'] as String,
          inn: row['inn'] as String,
          typeId: row['type_id'] as int,
          regionId: row['region_id'] as int,
          areaId: (row['area_id'] as num?)?.toInt(),
          phone: row['phone'] as String?,
          phone2: row['phone2'] as String?,
          phone3: row['phone3'] as String?,
          address: row['address'] as String?,
          categoryId: (row['category_id'] as num?)?.toInt(),
          healthCareFacilityTypeId: (row['hcf_type_id'] as num?)?.toInt(),
          revisionStatus: row['revision_status'] as String?,
          responsiblePerson: row['responsible'] as String?,
          latitude: (row['latitude'] as num?)?.toDouble(),
          longitude: (row['longitude'] as num?)?.toDouble(),
        );
        if (remoteId != null) {
          await _db.replaceOrganizationTempId(tempLocalId, remoteId);
        }
        await _db.deletePendingOrganization(id);
      } catch (error) {
        _addFailure(failures, 'organization', error, id: id);
      }
    }
  }

  static void _addFailure(
    List<PendingMutationFailure> failures,
    String type,
    Object error, {
    int? id,
  }) {
    failures.add(
      PendingMutationFailure(
        type: type,
        id: id,
        message: error is RemotePushException ? error.displayMessage : '$error',
      ),
    );
  }
}
