import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parent_dashboard_providers.g.dart';

@riverpod
ParentDashboardAggregator parentDashboardAggregator(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  return ParentDashboardAggregator(
    db,
    profileId: profileId,
    stageRepository: stageRepository,
  );
}

@riverpod
Future<ParentDashboardData> parentDashboardData(Ref ref) async {
  final aggregator = ref.watch(parentDashboardAggregatorProvider);
  return aggregator.compute();
}
