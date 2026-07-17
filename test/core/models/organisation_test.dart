import 'package:flutter_test/flutter_test.dart';
import 'package:lima/core/models/models.dart';

void main() {
  group('Organisation.fromJson', () {
    test('parses a full row from the local SQLite organisations table', () {
      final org = Organisation.fromJson({
        'id': 10,
        'name': 'ARZON DORIXONA',
        'address': 'ул. Катартал 38',
        'type': 'pharmacy',
        'type_id': 1,
        'city': 'Ташкент',
        'region_id': 1,
        'region_name': 'г. Ташкент',
        'district': 'Чиланзарский район',
        'inn': '305089312',
        'phone': '+998901234567',
        'latitude': 41.123,
        'longitude': 69.456,
        'is_favorite': 1,
        'visited': 0,
      });

      expect(org.id, 10);
      expect(org.name, 'ARZON DORIXONA');
      expect(org.type, OrgType.pharmacy);
      expect(org.isPharmacy, true);
      expect(org.isLpu, false);
      expect(org.regionId, 1);
      expect(org.district, 'Чиланзарский район');
      expect(org.inn, '305089312');
      expect(org.latitude, 41.123);
      expect(org.longitude, 69.456);
      expect(org.isFavorite, true);
      expect(org.visited, false);
    });

    test('type: recognizes lpu, pharmacy and distributor from free-text '
        'values (Russian and English)', () {
      expect(
        Organisation.fromJson({'id': 1, 'type': 'pharmacy'}).type,
        OrgType.pharmacy,
      );
      expect(
        Organisation.fromJson({'id': 1, 'type': 'аптека'}).type,
        OrgType.pharmacy,
      );
      expect(
        Organisation.fromJson({'id': 1, 'type': 'distributor'}).type,
        OrgType.distributor,
      );
      expect(
        Organisation.fromJson({'id': 1, 'type': 'дистрибьютор'}).type,
        OrgType.distributor,
      );
      expect(
        Organisation.fromJson({'id': 1, 'type': 'lpu'}).type,
        OrgType.lpu,
      );
    });

    test('unrecognized/missing type defaults to lpu', () {
      expect(Organisation.fromJson({'id': 1}).type, OrgType.lpu);
      expect(
        Organisation.fromJson({'id': 1, 'type': 'unknown'}).type,
        OrgType.lpu,
      );
    });

    test('falls back to type_name when type is absent', () {
      final org = Organisation.fromJson({
        'id': 1,
        'type_name': 'Аптека',
      });
      expect(org.type, OrgType.pharmacy);
    });

    test('is_favorite/visited/is_budget: interprets bool, int and string '
        'forms the same way (mixed sources: API JSON vs SQLite)', () {
      for (final rawValue in [true, 1, '1', 'true']) {
        final org = Organisation.fromJson({'id': 1, 'is_favorite': rawValue});
        expect(org.isFavorite, true, reason: 'failed for $rawValue');
      }
      for (final rawValue in [false, 0, '0', null]) {
        final org = Organisation.fromJson({'id': 1, 'is_favorite': rawValue});
        expect(org.isFavorite, false, reason: 'failed for $rawValue');
      }
    });

    test('missing id defaults to 0 rather than throwing', () {
      final org = Organisation.fromJson({'name': 'Без ID'});
      expect(org.id, 0);
    });

    test('missing name/address default to empty string rather than '
        'throwing', () {
      final org = Organisation.fromJson({'id': 1});
      expect(org.name, '');
      expect(org.address, '');
    });

    test('blank/"null"-string optional fields normalize to null', () {
      final org = Organisation.fromJson({
        'id': 1,
        'phone': '',
        'inn': 'null',
        'city': '   ',
      });

      expect(org.phone, isNull);
      expect(org.inn, isNull);
      expect(org.city, isNull);
    });

    test('latitude/longitude accept both numeric and string forms', () {
      final fromNum = Organisation.fromJson({
        'id': 1,
        'latitude': 41.1,
        'longitude': 69.2,
      });
      final fromString = Organisation.fromJson({
        'id': 1,
        'latitude': '41.1',
        'longitude': '69.2',
      });

      expect(fromNum.latitude, 41.1);
      expect(fromString.latitude, 41.1);
      expect(fromNum.longitude, 69.2);
      expect(fromString.longitude, 69.2);
    });

    test('rawJsonMap decodes raw_json for server fields not normalized '
        'into named columns', () {
      final org = Organisation.fromJson({
        'id': 1,
        'raw_json': '{"working_with_us": true, "phone_1": "998901234567"}',
      });

      expect(org.rawJsonMap['working_with_us'], true);
      expect(org.rawJsonMap['phone_1'], '998901234567');
    });

    test('rawJsonMap returns empty map when raw_json is missing or invalid '
        'JSON, instead of throwing', () {
      expect(Organisation.fromJson({'id': 1}).rawJsonMap, isEmpty);
      expect(
        Organisation.fromJson({'id': 1, 'raw_json': 'not json'}).rawJsonMap,
        isEmpty,
      );
    });

    test('toJson round-trips through fromJson without loss', () {
      final original = Organisation.fromJson({
        'id': 10,
        'name': 'ARZON DORIXONA',
        'address': 'ул. Катартал 38',
        'type': 'pharmacy',
        'region_id': 1,
        'district': 'Чиланзарский район',
        'inn': '305089312',
        'latitude': 41.123,
        'longitude': 69.456,
        'is_favorite': 1,
      });

      final roundTripped = Organisation.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.address, original.address);
      expect(roundTripped.type, original.type);
      expect(roundTripped.regionId, original.regionId);
      expect(roundTripped.district, original.district);
      expect(roundTripped.inn, original.inn);
      expect(roundTripped.latitude, original.latitude);
      expect(roundTripped.longitude, original.longitude);
      expect(roundTripped.isFavorite, original.isFavorite);
    });
  });
}
