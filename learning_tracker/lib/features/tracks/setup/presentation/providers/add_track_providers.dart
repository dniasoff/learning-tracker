import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';

/// Provider for [TrackCreationService] used by AddTrackFlow.
final trackCreationServiceProvider = Provider<TrackCreationService>((ref) {
  final db = ref.watch(userDatabaseProvider);
  final activationService = ref.watch(curriculumActivationServiceProvider);
  final wizardService = ref.watch(learningProcessWizardServiceProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);
  // Phase 1 — gateway is still needed for the server-side delete
  // `removeProfileProgramAssignment`; bookmarks and study_day_configs route
  // through syncWriteFacadeProvider (tutored-router-aware); enqueueProfileProgram
  // remains on the outbox-only facade (S3 parity CF: tutorSetProfileProgram).
  final gateway = ref.watch(firestoreGatewayProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  final outboxOnlyFacade = ref.watch(outboxSyncWriteFacadeProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  final stageRepository = ref.watch(globalStageRepositoryProvider);

  return TrackCreationService(
    database: db,
    activationService: activationService,
    wizardService: wizardService,
    goalRepository: goalRepo,
    stageRepository: stageRepository,
    gateway: gateway,
    syncFacade: syncFacade,
    outboxOnlyFacade: outboxOnlyFacade,
    analytics: analytics,
  );
});
