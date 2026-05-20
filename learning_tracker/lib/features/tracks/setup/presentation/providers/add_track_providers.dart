import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';

/// Provider for [TrackCreationService] used by AddTrackFlow.
final trackCreationServiceProvider = Provider<TrackCreationService>((ref) {
  final db = ref.watch(userDatabaseProvider);
  final activationService = ref.watch(curriculumActivationServiceProvider);
  final wizardService = ref.watch(learningProcessWizardServiceProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);
  final gateway = ref.watch(firestoreGatewayProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  final stageRepository = ref.watch(globalStageRepositoryProvider);

  return TrackCreationService(
    database: db,
    activationService: activationService,
    wizardService: wizardService,
    goalRepository: goalRepo,
    stageRepository: stageRepository,
    gateway: gateway,
    analytics: analytics,
  );
});
