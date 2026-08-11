import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

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

/// Provider for BulkPriorCompletionService used during onboarding.
final bulkPriorCompletionServiceProvider = Provider<BulkPriorCompletionService>(
  (ref) {
    final contentRepo = ref.watch(contentRepositoryProvider);
    final completionRepo = ref.watch(completionRepositoryProvider);
    final bookmarkRepo = ref.watch(bookmarkRepositoryProvider);
    final analytics = ref.watch(analyticsServiceProvider);
    // B6: inject StageDefinitionRepository so execute() can enumerate all
    // configured stages and write completion records for learn + every chazara.
    final stageRepo = FirestoreStageDefinitionRepositoryAdapter(ref: ref);
    // Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
    // owner decision 1): route the bulk-mark write through
    // CompletionOrchestrator so achievement (siyum) detection still fires —
    // CompletionRepositoryImpl no longer does that itself. See
    // BulkPriorCompletionService's `_orchestrator` field doc comment.
    final orchestrator = ref.watch(completionOrchestratorProvider);
    return BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
      analytics: analytics,
      stageRepository: stageRepo,
      orchestrator: orchestrator,
    );
  },
);

/// Provider for LearningProcessWizardService used during onboarding.
final learningProcessWizardServiceProvider =
    Provider<LearningProcessWizardService>((ref) {
      final db = ref.watch(userDatabaseProvider);
      return LearningProcessWizardService(
        stageDao: db.stageDao,
        learningProgramRepo: ref.read(learningProgramRepositoryProvider),
        profileProgramDao: db.profileProgramDao,
      );
    });
