// Mirror test for `lib/data/repositories/firestore_tutor_scope_grant_source.dart`
// (AG-5), Story 4.2a (DNI-523): the live per-scope grant listener.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_tutor_scope_grant_source.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/learner_state_fixtures.dart';

const _tutor = 'tutor-uid';
const _parentA = 'parent-a';
const _parentB = 'parent-b';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

Future<void> _seedGrant(
  FakeFirebaseFirestore db,
  String id, {
  String tutorUid = _tutor,
  String parentUid = _parentA,
  String profileId = profileUlid,
  String state = 'active',
}) => db.collection(kTutorGrantsCollection).doc(id).set({
  'tutor_uid': tutorUid,
  'parent_uid': parentUid,
  'child_profile_id': profileId,
  'state': state,
  'tutor_email': 'tutor@test.com',
});

/// Collects every event [stream] emits until the test ends.
List<Object> _collect(Stream<TutorScopeGrantVerdict> stream) {
  final events = <Object>[];
  final sub = stream.listen(events.add, onError: (Object e) => events.add(e));
  addTearDown(sub.cancel);
  return events;
}

void main() {
  final scopeA = LearnerScope(ownerUid: _parentA, profileId: profileUlid);
  final scopeB = LearnerScope(ownerUid: _parentB, profileId: ulidA);

  group('watch (fake Firestore)', () {
    late FakeFirebaseFirestore db;
    late FirestoreTutorScopeGrantSource source;

    setUp(() {
      db = FakeFirebaseFirestore();
      source = FirestoreTutorScopeGrantSource(firestore: db, tutorUid: _tutor);
    });

    test('an active grant grants; a revoke re-emits grantNotActive at once; '
        'a deleted grant is noGrant', () async {
      await _seedGrant(db, 'g-a');
      final events = _collect(source.watch(scopeA));
      await pumpEventQueue();
      expect(events, [const TutorScopeGranted('g-a')]);

      await db.collection(kTutorGrantsCollection).doc('g-a').update({
        'state': 'revoked_by_parent',
      });
      await pumpEventQueue();
      expect(
        events.last,
        const TutorScopeDenied(TutorScopeDenialReason.grantNotActive),
      );

      await db.collection(kTutorGrantsCollection).doc('g-a').delete();
      await pumpEventQueue();
      expect(
        events.last,
        const TutorScopeDenied(TutorScopeDenialReason.noGrant),
      );
    });

    test(
      'grants of other tutors, owners or profiles never authorize',
      () async {
        await _seedGrant(db, 'other-tutor', tutorUid: 'someone-else');
        await _seedGrant(db, 'other-owner', parentUid: _parentB);
        await _seedGrant(db, 'other-profile', profileId: ulidB);
        final events = _collect(source.watch(scopeA));
        await pumpEventQueue();
        expect(events, [
          const TutorScopeDenied(TutorScopeDenialReason.noGrant),
        ]);
      },
    );

    test('scopes from two parents are judged independently', () async {
      await _seedGrant(db, 'g-a');
      await _seedGrant(db, 'g-b', parentUid: _parentB, profileId: ulidA);
      final a = _collect(source.watch(scopeA));
      final b = _collect(source.watch(scopeB));
      await pumpEventQueue();
      expect(a, [const TutorScopeGranted('g-a')]);
      expect(b, [const TutorScopeGranted('g-b')]);

      await db.collection(kTutorGrantsCollection).doc('g-b').update({
        'state': 'revoked_by_tutor',
      });
      await pumpEventQueue();
      expect(a, [const TutorScopeGranted('g-a')]);
      expect(
        b.last,
        const TutorScopeDenied(TutorScopeDenialReason.grantNotActive),
      );
    });
  });

  group('watch (listener failures)', () {
    late _MockFirestore firestore;
    late _MockQuery query;
    late List<Stream<QuerySnapshot<Map<String, dynamic>>> Function()> scripts;

    setUp(() {
      firestore = _MockFirestore();
      final collection = _MockCollection();
      query = _MockQuery();
      scripts = [];
      when(
        () => firestore.collection(kTutorGrantsCollection),
      ).thenReturn(collection);
      when(
        () => collection.where('tutor_uid', isEqualTo: _tutor),
      ).thenReturn(query);
      when(
        () => query.where('parent_uid', isEqualTo: _parentA),
      ).thenReturn(query);
      when(
        () => query.where('child_profile_id', isEqualTo: profileUlid),
      ).thenReturn(query);
      var call = 0;
      when(() => query.snapshots()).thenAnswer((_) {
        final script =
            scripts[call < scripts.length ? call : scripts.length - 1];
        call++;
        return script();
      });
    });

    FirestoreTutorScopeGrantSource source() => FirestoreTutorScopeGrantSource(
      firestore: firestore,
      tutorUid: _tutor,
      backoffBase: Duration.zero,
      backoffCap: Duration.zero,
    );

    // The mocked chain answers only the exact three equality filters, so
    // these also pin the query shape (tutor_uid, parent_uid, child_profile_id).
    test(
      'permission-denied is a permissionDenied verdict, not an error',
      () async {
        scripts.add(
          () => Stream.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
        );
        final events = _collect(source().watch(scopeA));
        await pumpEventQueue();
        expect(
          events.first,
          const TutorScopeDenied(TutorScopeDenialReason.permissionDenied),
        );
      },
    );

    test(
      'any other failure is an error event and the listener resubscribes',
      () async {
        scripts
          ..add(
            () => Stream.error(
              FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
            ),
          )
          ..add(() => const Stream.empty());
        final events = _collect(source().watch(scopeA));
        await pumpEventQueue();
        expect(
          events.first,
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        );
        verify(() => query.snapshots()).called(greaterThanOrEqualTo(2));
      },
    );
  });

  group('isLearnerScopeAccessDenied', () {
    test('recognizes permission-denied and the seam exception only', () {
      expect(
        isLearnerScopeAccessDenied(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        isTrue,
      );
      expect(
        isLearnerScopeAccessDenied(
          TutorScopeAccessDeniedException(
            scopeA,
            TutorScopeDenialReason.noGrant,
          ),
        ),
        isTrue,
      );
      expect(
        isLearnerScopeAccessDenied(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
        isFalse,
      );
      expect(isLearnerScopeAccessDenied(StateError('x')), isFalse);
    });
  });
}
