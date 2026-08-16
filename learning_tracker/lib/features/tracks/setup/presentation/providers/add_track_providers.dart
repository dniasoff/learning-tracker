import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_scope_write_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/study_day_write_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';

/// Provider for [TrackCreationService] used by AddTrackFlow.
final trackCreationServiceProvider = Provider<TrackCreationService>((ref) {
  final activationService = ref.watch(curriculumActivationServiceProvider);
  final wizardService = ref.watch(learningProcessWizardServiceProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);

  return TrackCreationService(
    activationService: activationService,
    wizardService: wizardService,
    goalRepository: goalRepo,
    trackRepository: FirestoreCurriculumTrackRepositoryAdapter(ref: ref),
    studyDayRepository: FirestoreStudyDayWriteRepositoryAdapter(ref: ref),
    scopeRepository: FirestoreCurriculumScopeWriteRepositoryAdapter(ref: ref),
    profileProgramRepository: FirestoreProfileProgramRepositoryAdapter(
      ref: ref,
    ),
    bookmarkRepository: bookmarkRepository,
    analytics: analytics,
  );
});
