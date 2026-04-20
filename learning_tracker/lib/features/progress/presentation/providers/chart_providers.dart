import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

/// Provider for the ChartDataService, scoped to the active profile.
final chartDataServiceProvider = Provider<ChartDataService>((ref) {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return ChartDataService(database, profileId: profileId);
});
