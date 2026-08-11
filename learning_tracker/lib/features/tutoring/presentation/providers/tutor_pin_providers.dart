// Tutor PIN Riverpod providers — W6.4-W6.5
//
// Exposes [TutorPinService] and a [tutorPinStateProvider] that tracks
// whether a Tutor PIN has been set for a given profile.

import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_pin_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tutor_pin_providers.g.dart';

/// Singleton [TutorPinService] provider.
///
/// Depends on [pinServiceProvider] for the underlying secure-storage
/// implementation and [analyticsServiceProvider] for telemetry.
@riverpod
TutorPinService tutorPinService(Ref ref) {
  final pinService = ref.watch(pinServiceProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  return TutorPinService(pinService, analytics: analytics);
}

/// Returns `true` when a Tutor PIN has been set for [profileId].
///
/// Used by [TutorPinEntryGate] (W6.5) to decide whether to show the PIN
/// entry widget or to route directly to the PIN setup screen (W6.4).
@riverpod
Future<bool> tutorPinIsSet(Ref ref, String profileId) async {
  final service = ref.watch(tutorPinServiceProvider);
  return service.hasTutorPin(profileId);
}
