import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
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
  // Gateway still needed for server-side delete `removeProfileProgramAssignment`;
  // study-day and profile-program pushes route through syncWriteFacadeProvider
  // (tutored-router-aware). The bookmark write does NOT: it goes through
  // bookmarkRepositoryProvider, the same Firestore-backed, ULID-profile-keyed
  // repository every other bookmark read/write in the app uses — routing it
  // through the outbox/gateway instead wrote to a document nothing reads.
  final gateway = ref.watch(firestoreGatewayProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);

  return TrackCreationService(
    database: db,
    activationService: activationService,
    wizardService: wizardService,
    goalRepository: goalRepo,
    stageRepository: stageRepository,
    bookmarkRepository: bookmarkRepository,
    gateway: gateway,
    syncFacade: syncFacade,
    analytics: analytics,
  );
});
