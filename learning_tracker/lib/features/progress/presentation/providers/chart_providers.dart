import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

/// The [ChartDataService]: pure over the active learner's `LearnerState`
/// (DNI-474); the recent-activity providers pass the state in.
final chartDataServiceProvider = Provider<ChartDataService>(
  (ref) => const ChartDataService(),
);
