import '../../../core/db/local_database.dart';
import '../../../core/network/remote_api_service.dart';
import '../domain/entities/my_plan.dart';
import '../domain/repositories/my_plan_repository.dart';
import 'my_plan_mapper.dart';

class MyPlanRepositoryImpl implements MyPlanRepository {
  final RemoteApiService _api;
  final LocalDatabase _db;
  final int userId;

  const MyPlanRepositoryImpl(this._api, this._db, {required this.userId});

  String _cacheKey(int year) => 'my_plan_${userId}_$year';

  @override
  Future<MyPlanProgress?> getCachedPlan(int year) async {
    final cached = await _db.getCachedStat(_cacheKey(year));
    return cached == null ? null : MyPlanMapper.fromJson(cached);
  }

  @override
  Future<MyPlanProgress> refreshPlan(int year) async {
    final json = await _api.getMyPlan(year: year);
    final plan = MyPlanMapper.fromJson(json);
    await _db.setCachedStat(_cacheKey(year), MyPlanMapper.toJson(plan));
    return plan;
  }
}
