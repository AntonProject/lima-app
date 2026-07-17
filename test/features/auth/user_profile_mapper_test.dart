import 'package:flutter_test/flutter_test.dart';
import 'package:lima/features/auth/domain/mappers/user_profile_mapper.dart';

void main() {
  test('maps region and company fields from the API profile', () {
    final user = UserProfileMapper.fromApi({
      'id': 992,
      'fio': 'Anton Dev',
      'role': 'МП',
      'region': {'id': 1, 'name_ru': 'г. Ташкент'},
      'company': {'id': 2, 'name': 'LIMA'},
      'phone_number': '+998000000000',
      'visits_count': 15,
      'sales_amount': 1200.5,
      'doctors_count': 4,
    });

    expect(user.id, 992);
    expect(user.fullName, 'Anton Dev');
    expect(user.role, 'mp');
    expect(user.city, 'г. Ташкент');
    expect(user.regionId, 1);
    expect(user.company, 'LIMA');
    expect(user.companyId, 2);
    expect(user.phone, '+998000000000');
    expect(user.visitsCount, 15);
    expect(user.salesAmount, 1200.5);
    expect(user.doctorsCount, 4);
  });

  test('normalizes administrator and regional-manager role variants', () {
    expect(
      UserProfileMapper.fromApi({
        'name': 'Admin',
        'role': 'administrator',
      }).role,
      'admin',
    );
    expect(
      UserProfileMapper.fromApi({
        'name': 'RM',
        'role': 'Региональный менеджер',
      }).role,
      'rm',
    );
  });
}
