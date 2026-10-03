import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/before_tracking_recorder.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// Provider for CurriculumImportService used during onboarding.
final curriculumImportServiceProvider = Provider<CurriculumImportService>((
  ref,
) {
  final activationService = ref.watch(curriculumActivationServiceProvider);
  return CurriculumImportService(activationService: activationService);
});

/// Provider for GoalRepository used during onboarding goal setup.
///
/// **Firestore-backed** via [FirestoreGoalRepositoryAdapter] (wired
/// Phase 3, T-20). The Drift-backed [GoalRepositoryImpl] is
/// deprecated and will be removed in Phase 4.
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return FirestoreGoalRepositoryAdapter(ref: ref);
});

/// Records "learnt before tracking" for the active learner (Story 1.11,
/// DNI-473): onboarding / Add-track bulk mark captures `before_tracking`
/// learning events through [learningCommandsProvider] (R10: the retired
/// `2000-01-01` sentinel completions). In a tutored session those are the
/// tutor callables and the bookmark co-write is skipped (DNI-486).
final beforeTrackingRecorderProvider = Provider<BeforeTrackingRecorder>((ref) {
  return BeforeTrackingRecorder(
    contentRepository: ref.watch(contentRepositoryProvider),
    commands: () => ref.read(learningCommandsProvider.future),
    // A tutor never writes the talmid's bookmark: it is owner-only by the
    // Firestore rules (DNI-486). The capture alone is the tutor's write.
    ownsBookmark: () => ref.read(activeTutoredProfileSelectionProvider) == null,
    events: () async {
      final scope = await ref.read(activeLearnerScopeProvider.future);
      final repository = await ref.read(learningEventRepositoryProvider.future);
      if (scope == null || repository == null) return null;
      final ready = await repository
          .watchAll(scope)
          .firstWhere((r) => r is CompleteReadReady<LearningEvent>);
      return (ready as CompleteReadReady<LearningEvent>).items;
    },
  );
});

/// Provider for LearningProcessWizardService used during onboarding.
final learningProcessWizardServiceProvider =
    Provider<LearningProcessWizardService>((ref) {
      return LearningProcessWizardService(
        stageRepository: FirestoreStageDefinitionRepositoryAdapter(ref: ref),
        learningProgramRepo: ref.read(learningProgramRepositoryProvider),
        profileProgramRepository: FirestoreProfileProgramRepositoryAdapter(
          ref: ref,
        ),
      );
    });
