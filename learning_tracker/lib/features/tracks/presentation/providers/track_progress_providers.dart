import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_progress_providers.g.dart';

/// Singleton [TrackProgressService] provider — the presentation-layer
/// composition root that wires the pure domain service (`features/tracks/
/// domain/services/track_progress_service.dart`, which may not import the
/// data ring — AD-23/AD-28) to the concrete
/// [FirestoreChartDataRepositoryAdapter].
@riverpod
TrackProgressService trackProgressService(Ref ref) {
  final stageRepo = ref.watch(globalStageRepositoryProvider);
  return TrackProgressService(
    repository: FirestoreChartDataRepositoryAdapter(ref: ref),
    stageRepo: stageRepo,
  );
}
