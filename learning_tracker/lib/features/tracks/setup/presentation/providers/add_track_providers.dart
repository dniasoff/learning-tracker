import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/add_track_action_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';

/// The governed Add track action writer (DNI-476 AC-5).
final addTrackActionRepositoryProvider = Provider<AddTrackActionRepository>(
  (ref) => FirestoreAddTrackActionRepository(ref: ref),
);

/// Provider for [TrackCreationService] used by AddTrackFlow.
final trackCreationServiceProvider = Provider<TrackCreationService>((ref) {
  return TrackCreationService(
    actionRepository: ref.watch(addTrackActionRepositoryProvider),
    wizardService: ref.watch(learningProcessWizardServiceProvider),
    bookmarkRepository: ref.watch(bookmarkRepositoryProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});
