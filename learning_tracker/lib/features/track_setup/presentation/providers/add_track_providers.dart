import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_creation_service.dart';

/// Provider for [TrackCreationService] used by AddTrackFlow.
final trackCreationServiceProvider = Provider<TrackCreationService>((ref) {
  final db = ref.watch(userDatabaseProvider);
  final activationService = ref.watch(curriculumActivationServiceProvider);
  final wizardService = ref.watch(learningProcessWizardServiceProvider);
  final goalRepo = ref.watch(goalRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  return TrackCreationService(
    database: db,
    activationService: activationService,
    wizardService: wizardService,
    goalRepository: goalRepo,
    syncEngine: syncEngine,
    analytics: analytics,
  );
});
