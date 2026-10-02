/// Firestore [LearnerSettingsReader]: the AD-37 settings projection of
/// `users/{ownerUid}/learner_profiles/{profileId}` (DNI-470 AC-7).
///
/// Only the settings keys are read ([LearnerSettings.fromProfileDoc] is a
/// projection; ordinary profile fields are ignored). A missing profile doc
/// or settings that do not decode (no valid IANA `time_zone`) is an error
/// event, so the lock readers fail closed (AD-36) rather than fall back to
/// the device's zone or location. A dead listener resubscribes with backoff
/// (AD-9). The `{uid}` path segment is [LearnerScope.ownerUid] (ruling B10).
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';

/// The profile doc of a [LearnerScope] does not exist.
final class LearnerProfileMissingException implements Exception {
  /// Creates the exception for [profileId].
  const LearnerProfileMissingException(this.profileId);

  /// The missing profile.
  final String profileId;

  @override
  String toString() =>
      'LearnerProfileMissingException: learner_profiles/$profileId';
}

/// Watches a profile doc's learner settings.
final class FirestoreLearnerSettingsReader implements LearnerSettingsReader {
  /// Creates the reader over an account-scoped [firestore] handle.
  FirestoreLearnerSettingsReader({
    required FirebaseFirestore firestore,
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    this.random,
    this.onListenerError,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// AD-9 resubscribe backoff base.
  final Duration backoffBase;

  /// AD-9 resubscribe backoff cap.
  final Duration backoffCap;

  /// Jitter source (tests pin it).
  final math.Random? random;

  /// Called for each stream-level listener failure.
  final void Function(Object error, StackTrace stackTrace)? onListenerError;

  @override
  Stream<LearnerSettings> watch(LearnerScope scope) =>
      resilientDocStream<LearnerSettings>(
        openStream: () => _firestore
            .collection('users')
            .doc(scope.ownerUid)
            .collection('learner_profiles')
            .doc(scope.profileId)
            .snapshots(),
        decode: (snapshot) {
          final data = snapshot.data();
          if (data == null) {
            throw LearnerProfileMissingException(scope.profileId);
          }
          return LearnerSettings.fromProfileDoc(
            scope.profileId,
            fromFirestoreMap(data),
          );
        },
        backoffBase: backoffBase,
        backoffCap: backoffCap,
        random: random,
        onError: onListenerError,
      );
}
