import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const presentationFiles = [
    'lib/features/auth/providers/auth_provider.dart',
    'lib/features/home/screens/home_screen.dart',
    'lib/features/knowledge/screens/knowledge_screen.dart',
    'lib/features/knowledge/screens/drug_detail_screen.dart',
    'lib/features/knowledge/screens/material_viewer_screen.dart',
    'lib/features/visits/screens/pharmacy/pharmacy_order_screen.dart',
    'lib/features/visits/screens/pharmacy/pharmacy_detail_screen.dart',
    'lib/features/visits/screens/new_bron_screen.dart',
    'lib/features/profile/screens/profile_screen.dart',
    'lib/features/profile/screens/fav_doctors_screen.dart',
    'lib/features/profile/screens/fav_pharmacies_screen.dart',
    'lib/features/cart/screens/cart_screen.dart',
    'lib/features/offline/screens/sync_screen.dart',
    'lib/features/splash/screens/splash_screen.dart',
    'lib/features/visits/screens/history_screen.dart',
    'lib/features/visits/dialogs/visit_detail_dialog.dart',
    'lib/features/visits/screens/pharmacy/pharma_circle_screen.dart',
    'lib/features/visits/screens/pharmacy/pharmacy_stock_screen.dart',
    'lib/features/visits/screens/lpu/lpu_detail_screen.dart',
  ];

  test(
    'migrated presentation files do not reach infrastructure or raw rows',
    () {
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
