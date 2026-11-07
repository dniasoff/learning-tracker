import 'package:learning_tracker/domain/learner_state/learner_settings.dart';

const detectedLocationMaxAge = Duration(hours: 24);

/// Refresh detected fixes after a day; manual city/coordinate choices are
/// never replaced automatically. Missing legacy timestamps are left alone.
bool shouldRefreshDetectedLocation(LearnerSettings settings, DateTime nowUtc) {
  final fixedAt = settings.locationFixedAt;
  return settings.locationSource == 'detected' &&
      fixedAt != null &&
      nowUtc.toUtc().difference(fixedAt.toUtc()) >= detectedLocationMaxAge;
}
