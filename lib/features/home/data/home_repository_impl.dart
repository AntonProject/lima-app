import '../../offline/domain/entities/sync_data_change.dart';
import '../../visits/data/visits_repository.dart';
import '../domain/entities/recent_visit.dart';
import '../domain/repositories/home_repository.dart';
import 'recent_visit_mapper.dart';

class HomeRepositoryImpl implements HomeRepository {
  final VisitsRepositoryImpl _visitsRepository;

  const HomeRepositoryImpl(this._visitsRepository);

  @override
  Stream<SyncDataChange> get changes => _visitsRepository.changes;

  @override
  Future<int?> getCurrentUserId() => _visitsRepository.getCurrentUserId();

  @override
  Future<List<RecentVisit>> getRecentVisits() async {
    final visits = await _visitsRepository.getVisitModels().timeout(
      const Duration(seconds: 6),
      onTimeout: () => const [],
    );
    return RecentVisitMapper.fromLocalVisits(visits);
  }
}
