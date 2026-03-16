import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tutor_dashboard_providers.g.dart';

@riverpod
TutorDashboardAggregator tutorDashboardAggregator(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return TutorDashboardAggregator(db);
}

@riverpod
Future<TutorDashboardData> tutorDashboardData(Ref ref) async {
  final aggregator = ref.watch(tutorDashboardAggregatorProvider);
  final now = ref.watch(clockProvider);
  final allTasks = await ref.watch(allDailyTasksProvider.future);
  return aggregator.compute(now: now, allTasks: allTasks);
}
