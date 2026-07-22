import '../entities/my_plan.dart';

abstract interface class MyPlanRepository {
  Future<MyPlanProgress?> getCachedPlan(int year);

  Future<MyPlanProgress> refreshPlan(int year);
}
