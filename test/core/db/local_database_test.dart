import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/db/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _priceListRow({
  required int id,
  required String name,
  double price = 1000,
  int? currentStockId,
  int? bindingDrugId,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'manufacturer': 'TEMUR MED',
  'price': price,
  'serial_number': 'S-$id',
  'expiry_date': '2027-09-17',
  'main_stock': 10,
  'stock': 10,
  'remains_stock': 10,
  'current_stock_id': currentStockId ?? id * 10,
  'binding_drug_id': bindingDrugId ?? id,
  'updated_at': '2026-09-17T00:00:00.000',
};

Map<String, dynamic> _orderVisitRow(List<Map<String, dynamic>> lines) {
  final payload = <String, dynamic>{
    'organization_id': 5,
    'organization_name': '"INTERFARMED"',
    'visit_type': 1,
    'status': 'pending',
    'drugs': lines,
    'items': lines,
  };
  return <String, dynamic>{
    'org_id': 5,
    'org_name': '"INTERFARMED"',
    'visit_type': 'order',
    'status': 'pending',
    'created_at': '2026-09-17T00:00:00.000',
    'updated_at': '2026-09-17T00:00:00.000',
    'raw_json': jsonEncode(payload),
  };
}

Map<String, dynamic> _orderLine({
  required int drugId,
  required int incomeDetailingId,
  required String drugName,
}) => <String, dynamic>{
  'income_detailing_id': incomeDetailingId,
  'drug_id': drugId,
  'drug_name': drugName,
  'package': 10,
  'quantity': 10,
  'sale_price': 120000,
};

void main() {
  final db = LocalDatabase();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await db.initForTesting(inMemoryDatabasePath);
  });

  Future<List<Map<String, Object?>>> drugsById() =>
      db.db.query('drugs', orderBy: 'id');

  Future<Map<String, Object?>> firstVisit() async =>
      (await db.db.query('visits', orderBy: 'id')).first;

  Future<List<dynamic>> visitLines(Map<String, Object?> visit) async {
    final decoded = jsonDecode(visit['raw_json'] as String) as Map;
    return decoded['drugs'] as List<dynamic>;
  }

  group('replaceOrderPriceList', () {
    test('drops products the new snapshot no longer offers', () async {
      await db.replaceOrderPriceList([
        _priceListRow(id: 1, name: 'ЭССЕНИКС'),
        _priceListRow(id: 2, name: 'гепатопротем'),
      ]);

      final replaced = await db.replaceOrderPriceList([
        _priceListRow(id: 1, name: 'ЭССЕНИКС', price: 120000),
      ]);

      expect(replaced, isTrue);
      final rows = await drugsById();
      expect(rows.first['price'], 120000);
      // Still in the catalogue for knowledge screens, but not orderable.
      expect(rows.last['price'], 0);
      expect(rows.last['current_stock_id'], isNull);
      final orderable = await db.getDrugs();
      expect(orderable.map((row) => row['id']), [1]);
    });

    test(
      'stores the list price flag and clears it with the old list',
      () async {
        await db.replaceOrderPriceList([
          {..._priceListRow(id: 1, name: 'ЭССЕНИКС'), 'has_list_price': 1},
          _priceListRow(id: 2, name: 'гепатопротем'),
        ]);
        await db.upsertDrugs([
          {'id': 1, 'name': 'ЭССЕНИКС', 'manufacturer': 'M'},
        ]);

        var rows = await drugsById();
        expect(rows.first['has_list_price'], 1);
        expect(rows.last['has_list_price'], 0);

        await db.replaceOrderPriceList([
          _priceListRow(id: 2, name: 'гепатопротем'),
        ]);

        rows = await drugsById();
        expect(rows.first['has_list_price'], 0);
      },
    );

    test(
      'merges instead of wiping when the snapshot looks truncated',
      () async {
        await db.replaceOrderPriceList([
          _priceListRow(id: 1, name: 'ЭССЕНИКС'),
          _priceListRow(id: 2, name: 'гепатопротем'),
          _priceListRow(id: 3, name: 'метокс'),
          _priceListRow(id: 4, name: 'цефтриаксон'),
        ]);

        final replaced = await db.replaceOrderPriceList([
          _priceListRow(id: 1, name: 'ЭССЕНИКС', price: 999),
        ]);

        expect(replaced, isFalse);
        final orderable = await db.getDrugs();
        expect(orderable.length, 4);
        expect(orderable.first['price'], 999);
      },
    );

    test('replaces when nothing is orderable yet', () async {
      final replaced = await db.replaceOrderPriceList([
        _priceListRow(id: 1, name: 'ЭССЕНИКС'),
      ]);

      expect(replaced, isTrue);
      expect(await db.getDrugs(), hasLength(1));
    });

    test('ignores an empty response', () async {
      await db.replaceOrderPriceList([_priceListRow(id: 1, name: 'ЭССЕНИКС')]);

      expect(await db.replaceOrderPriceList(const []), isFalse);
      expect(await db.getDrugs(), hasLength(1));
    });
  });

  group('repairParkedPharmacyOrderStockIds', () {
    test('re-resolves the stock id and re-queues the order', () async {
      await db.replaceOrderPriceList([
        _priceListRow(id: 11, name: 'ЭССЕНИКС', currentStockId: 999),
      ]);
      final visitId = await db.insertVisit(
        _orderVisitRow([
          _orderLine(drugId: 11, incomeDetailingId: 2666, drugName: 'ЭССЕНИКС'),
        ]),
      );
      await db.markVisitPushFailedPermanently(visitId);

      expect(await db.repairParkedPharmacyOrderStockIds(), 1);

      final visit = await firstVisit();
      expect(visit['sync_failed'], 0);
      final lines = await visitLines(visit);
      expect((lines.single as Map)['income_detailing_id'], 999);
      expect((lines.single as Map)['drug_id'], 11);
      // The legacy alias has to stay in step with the repaired lines.
      final decoded = jsonDecode(visit['raw_json'] as String) as Map;
      expect(decoded['items'], decoded['drugs']);
    });

    test('recovers the binding id by name when the id changed', () async {
      await db.replaceOrderPriceList([
        _priceListRow(
          id: 77,
          name: 'метокс',
          currentStockId: 555,
          bindingDrugId: 77,
        ),
      ]);
      final visitId = await db.insertVisit(
        _orderVisitRow([
          _orderLine(drugId: 2666, incomeDetailingId: 2666, drugName: 'метокс'),
        ]),
      );
      await db.markVisitPushFailedPermanently(visitId);

      expect(await db.repairParkedPharmacyOrderStockIds(), 1);

      final lines = await visitLines(await firstVisit());
      expect((lines.single as Map)['drug_id'], 77);
      expect((lines.single as Map)['income_detailing_id'], 555);
    });

    test('leaves the order parked when one product is gone', () async {
      await db.replaceOrderPriceList([
        _priceListRow(id: 11, name: 'ЭССЕНИКС', currentStockId: 999),
      ]);
      final visitId = await db.insertVisit(
        _orderVisitRow([
          _orderLine(drugId: 11, incomeDetailingId: 2666, drugName: 'ЭССЕНИКС'),
          _orderLine(drugId: 42, incomeDetailingId: 4242, drugName: 'снятый'),
        ]),
      );
      await db.markVisitPushFailedPermanently(visitId);

      expect(await db.repairParkedPharmacyOrderStockIds(), 0);

      final visit = await firstVisit();
      expect(visit['sync_failed'], 1);
      final lines = await visitLines(visit);
      expect((lines.first as Map)['income_detailing_id'], 2666);
    });

    test('does not touch orders that are still queued', () async {
      await db.replaceOrderPriceList([
        _priceListRow(id: 11, name: 'ЭССЕНИКС', currentStockId: 999),
      ]);
      await db.insertVisit(
        _orderVisitRow([
          _orderLine(drugId: 11, incomeDetailingId: 2666, drugName: 'ЭССЕНИКС'),
        ]),
      );

      expect(await db.repairParkedPharmacyOrderStockIds(), 0);

      final lines = await visitLines(await firstVisit());
      expect((lines.single as Map)['income_detailing_id'], 2666);
    });

    test(
      'leaves a parked order alone when its ids are already current',
      () async {
        await db.replaceOrderPriceList([
          _priceListRow(id: 11, name: 'ЭССЕНИКС', currentStockId: 999),
        ]);
        final visitId = await db.insertVisit(
          _orderVisitRow([
            _orderLine(
              drugId: 11,
              incomeDetailingId: 999,
              drugName: 'ЭССЕНИКС',
            ),
          ]),
        );
        await db.markVisitPushFailedPermanently(visitId);

        expect(await db.repairParkedPharmacyOrderStockIds(), 0);
        expect((await firstVisit())['sync_failed'], 1);
      },
    );
  });

  test(
    'schema v25 assigns legacy user rows and adds plan retry columns',
    () async {
      final path =
          '${Directory.systemTemp.path}/lima_v25_${DateTime.now().microsecondsSinceEpoch}.db';
      addTearDown(() async {
        if (db.db.isOpen) await db.db.close();
        await databaseFactory.deleteDatabase(path);
      });

      await db.initForTesting(path);
      await db.setCurrentUserOwner(userId: 7, login: 'legacy', role: 'mp');
      await db.insertVisit(
        _orderVisitRow([
          _orderLine(drugId: 11, incomeDetailingId: 111, drugName: 'ЭССЕНИКС'),
        ]),
      );
      await db.enqueuePendingPlan(
        localPlanId: 1,
        orgId: 5,
        orgType: 'lpu',
        doctorIds: const [3],
        visitFormatId: 1,
        visitDate: DateTime(2026, 9, 17),
      );

      for (final table in const [
        'visits',
        'planned_visits',
        'pending_plans',
        'pending_organizations',
      ]) {
        await db.db.execute('ALTER TABLE $table DROP COLUMN owner_user_id');
      }
      for (final column in const [
        'attempts',
        'last_error',
        'status',
        'next_retry_at',
        'parked_at',
        'http_status',
      ]) {
        await db.db.execute('ALTER TABLE pending_plans DROP COLUMN $column');
      }
      await db.db.execute('PRAGMA user_version = 24');
      await db.db.close();

      await db.initForTesting(path);

      final planColumns = await db.db.rawQuery(
        'PRAGMA table_info(pending_plans)',
      );
      expect(
        planColumns.map((row) => row['name']),
        containsAll([
          'owner_user_id',
          'attempts',
          'last_error',
          'status',
          'next_retry_at',
          'parked_at',
          'http_status',
        ]),
      );
      expect((await db.getVisits()).single['owner_user_id'], 7);
      expect((await db.getPendingPlans()).single['owner_user_id'], 7);
    },
  );
}
