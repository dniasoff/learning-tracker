import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

/// Provider for the ChartDataService, scoped to the active profile via the
/// Ref-based Firestore adapter it holds.
final chartDataServiceProvider = Provider<ChartDataService>((ref) {
  return ChartDataService(
    repository: FirestoreChartDataRepositoryAdapter(ref: ref),
  );
});
