import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/study_day_write_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';

final trackEditServiceProvider = Provider<TrackEditService>((ref) {
  return TrackEditService(
    wizardService: ref.watch(learningProcessWizardServiceProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
    studyDayRepository: FirestoreStudyDayWriteRepositoryAdapter(ref: ref),
  );
});
