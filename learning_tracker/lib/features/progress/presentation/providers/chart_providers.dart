import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

/// Provider for the ChartDataService.
final chartDataServiceProvider = Provider<ChartDataService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return ChartDataService(database);
});
