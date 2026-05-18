import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/services/track_edit_service.dart';

final trackEditServiceProvider = Provider<TrackEditService>((ref) {
  return TrackEditService(
    database: ref.watch(userDatabaseProvider),
    wizardService: ref.watch(learningProcessWizardServiceProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
  );
});
