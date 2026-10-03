/// Firestore [TutorScopeGrantSource] (Story 4.2a, DNI-523, ruling B10).
///
/// Listens to the signed-in tutor's `tutor_grants` documents for one
/// [LearnerScope] — an equality-only query on `tutor_uid`, `parent_uid` and
/// `child_profile_id`, which Firestore serves from single-field indexes (no
/// new composite index) and which the `tutor_grants` read rule accepts
/// because it pins `tutor_uid` to the caller. Each snapshot is judged by
/// [evaluateTutorScopeGrants], so a revoke (the grant's `state` leaving
/// `active`) re-emits a [TutorScopeDenied] at once.
///
/// The listener self-heals through [resilientQueryStream]. A
/// `permission-denied` failure becomes a
/// [TutorScopeDenialReason.permissionDenied] verdict, not an error.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';

/// The `tutor_grants` top-level collection.
const String kTutorGrantsCollection = 'tutor_grants';

/// Whether [error] means the reader has no (or no longer has) access to a
/// learner scope: a Firestore `permission-denied`, or a
/// [TutorScopeAccessDeniedException] already raised by the read seam.
bool isLearnerScopeAccessDenied(Object error) =>
    error is TutorScopeAccessDeniedException ||
    (error is FirebaseException && error.code == 'permission-denied');

/// [TutorScopeGrantSource] over the signed-in tutor's Firestore handle.
final class FirestoreTutorScopeGrantSource implements TutorScopeGrantSource {
  /// Creates the source for the signed-in [tutorUid] (the live Auth uid of
  /// [firestore]'s app — the uid `tutor_grants.tutor_uid` holds).
  FirestoreTutorScopeGrantSource({
    required FirebaseFirestore firestore,
    required this.tutorUid,
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    this.random,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// The signed-in tutor's uid.
  final String tutorUid;

  /// Resubscribe backoff after a listener failure.
  final Duration backoffBase;

  /// Resubscribe backoff cap.
  final Duration backoffCap;

  /// Jitter source (tests pin it).
  final math.Random? random;

  /// The grants query for [scope].
  Query<Map<String, dynamic>> queryFor(LearnerScope scope) => _firestore
      .collection(kTutorGrantsCollection)
      .where('tutor_uid', isEqualTo: tutorUid)
      .where('parent_uid', isEqualTo: scope.ownerUid)
      .where('child_profile_id', isEqualTo: scope.profileId);

  @override
  Stream<TutorScopeGrantVerdict> watch(LearnerScope scope) =>
      resilientQueryStream<TutorGrantRecord>(
            openStream: () => queryFor(scope).snapshots(),
            decode: (doc) => (id: doc.id, data: doc.data()),
            backoffBase: backoffBase,
            backoffCap: backoffCap,
            random: random,
          )
          .map<TutorScopeGrantVerdict>(
            (grants) => evaluateTutorScopeGrants(
              tutorUid: tutorUid,
              scope: scope,
              grants: grants,
            ),
          )
          .transform(
            StreamTransformer<
              TutorScopeGrantVerdict,
              TutorScopeGrantVerdict
            >.fromHandlers(
              handleError: (error, stackTrace, sink) {
                if (isLearnerScopeAccessDenied(error)) {
                  sink.add(
                    const TutorScopeDenied(
                      TutorScopeDenialReason.permissionDenied,
                    ),
                  );
                } else {
                  sink.addError(error, stackTrace);
                }
              },
            ),
          );
}
