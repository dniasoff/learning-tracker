import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_progress_providers.g.dart';

/// Singleton [TrackProgressService] provider. The service is pure over the
/// active learner's `LearnerState` (DNI-474); callers pass the state in.
@riverpod
TrackProgressService trackProgressService(Ref ref) =>
    const TrackProgressService();
