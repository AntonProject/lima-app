import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const legacyPresentationExceptions = {
    'lib/features/auth/screens/login_screen.dart',
    'lib/features/visits/screens/lpu/lpu_doctor_select_screen.dart',
    // These two slices still contain their composition root/raw form state;
    // keep them explicit until their own migration change set lands.
    'lib/features/offline/presentation/view_models/sync_view_model.dart',
    'lib/features/visits/presentation/view_models/add_pharmacy_view_model.dart',
  };

  List<String> discoverPresentationFiles() {
    return Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where((path) => path.endsWith('.dart'))
        .where(
          (path) =>
              path.contains('/presentation/') || path.endsWith('_screen.dart'),
        )
        .where((path) => !legacyPresentationExceptions.contains(path))
        .toList()
      ..sort();
  }

  test(
    'migrated presentation files do not reach infrastructure or raw rows',
    () {
      final presentationFiles = discoverPresentationFiles();
      expect(presentationFiles, isNotEmpty);
      for (final path in presentationFiles) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('core/db/local_database.dart')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('core/network/api_client.dart')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('core/network/remote_api_service.dart')),
          reason: path,
        );
        expect(source, isNot(contains('jsonDecode')), reason: path);
        expect(source, isNot(contains('raw_json')), reason: path);
        expect(source, isNot(contains('Map<String, dynamic>')), reason: path);
        expect(source, isNot(contains("/data/")), reason: path);
      }
    },
  );

  test('domain contracts do not depend on Flutter or infrastructure', () {
    final domainFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains('/domain/') && file.path.endsWith('.dart'),
        );

    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains("package:flutter/")), reason: file.path);
      expect(source, isNot(contains('flutter_riverpod')), reason: file.path);
      expect(source, isNot(contains('core/db/')), reason: file.path);
      expect(source, isNot(contains('core/network/')), reason: file.path);
      expect(source, isNot(contains('sqflite')), reason: file.path);
    }
  });

  test('concrete data repositories use the implementation suffix', () {
    const repositoryFiles = [
      'lib/features/knowledge/data/drugs_repository.dart',
      'lib/features/visits/data/doctors_repository.dart',
      'lib/features/visits/data/organisations_repository.dart',
      'lib/features/visits/data/visits_repository.dart',
      'lib/features/workday/data/workday_repository_impl.dart',
    ];

    for (final path in repositoryFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('class '));
      expect(source, contains('RepositoryImpl'));
      expect(source, isNot(contains('class DrugsRepository ')), reason: path);
      expect(source, isNot(contains('class DoctorsRepository ')), reason: path);
      expect(
        source,
        isNot(contains('class OrganisationsRepository ')),
        reason: path,
      );
      expect(source, isNot(contains('class VisitsRepository ')), reason: path);
    }
  });
}
