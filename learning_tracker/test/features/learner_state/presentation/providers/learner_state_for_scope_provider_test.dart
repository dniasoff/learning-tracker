// Mirror test for
// `lib/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart`
// (AG-5), Story 4.2a (DNI-523, ruling B10): a tutor reads N learners from
// different parents at once, each gated on its own active grant; a revoked
// or permission-denied scope clears its state; rows stay warm only while
// watched.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/learner_state/fake_tutor_scope_grant_source.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _tutor = 'tutor-uid';
const _parentA = 'parent-a';
const _parentB = 'parent-b';

class _MockApp extends Mock implements FirebaseApp {}

class _MockAuth extends Mock implements FirebaseAuth {}

/// Three learners from two parents: A has two children, B has one.
final _a1 = LearnerScope(ownerUid: _parentA, profileId: ulidA);
final _a2 = LearnerScope(ownerUid: _parentA, profileId: ulidB);
final _b1 = LearnerScope(ownerUid: _parentB, profileId: ulidC);
final _scopes = [_a1, _a2, _b1];

LearnerState _state(int hour) =>
    LearnerState.empty(DateTime.utc(2026, 9, 1, hour));

FirebaseException _permissionDenied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

Matcher _deniedFor(LearnerScope scope, TutorScopeDenialReason reason) =>
    isA<AsyncError<LearnerState>>()
        .having((e) => e.hasValue, 'hasValue (cleared)', isFalse)
        .having(
          (e) => e.error,
          'error',
          TutorScopeAccessDeniedException(scope, reason),
        );

/// Listens to each scope's row (a "visible" roster row) and returns the
/// subscriptions by scope.
Map<LearnerScope, ProviderSubscription<AsyncValue<LearnerState>>> _watchRows(
  ProviderContainer container,
  Iterable<LearnerScope> scopes,
) => {
  for (final scope in scopes)
    scope: container.listen(learnerStateForScopeProvider(scope), (_, _) {}),
};

void main() {
  group('with a scripted grant source', () {
    late FakeTutorScopeGrantSource source;
    late ScopedLearnerStateStreams states;
    late ProviderContainer container;

    setUp(() {
      source = FakeTutorScopeGrantSource();
      states = ScopedLearnerStateStreams();
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: tutorScopeReadOverrides(source: source, states: states),
      );
    });

    test('3 scopes from 2 parents: each row reads its own learner', () async {
      final rows = _watchRows(container, _scopes);
      await pumpEventQueue();
      for (final row in rows.values) {
        expect(row.read().isLoading, isTrue, reason: 'no verdict yet');
      }

      for (final scope in _scopes) {
        source.grant(scope, 'g-${scope.profileId}');
      }
      await pumpEventQueue();
      final a1 = _state(1), a2 = _state(2), b1 = _state(3);
      states
        ..emit(_a1, a1)
        ..emit(_a2, a2)
        ..emit(_b1, b1);
      await pumpEventQueue();

      expect(rows[_a1]!.read().value, same(a1));
      expect(rows[_a2]!.read().value, same(a2));
      expect(rows[_b1]!.read().value, same(b1));
      expect(source.watched.toSet(), _scopes.toSet());
    });

    test('a revoke clears only that scope and releases its state', () async {
      final rows = _watchRows(container, _scopes);
      for (final scope in _scopes) {
        source.grant(scope);
      }
      await pumpEventQueue();
      for (final scope in _scopes) {
        states.emit(scope, _state(1));
      }
      await pumpEventQueue();
      expect(rows[_a2]!.read().hasValue, isTrue);

      source.deny(_a2, TutorScopeDenialReason.grantNotActive);
      await pumpEventQueue();

      expect(
        rows[_a2]!.read(),
        _deniedFor(_a2, TutorScopeDenialReason.grantNotActive),
      );
      expect(states.cancels[_a2], 1, reason: 'revoked scope stops listening');
      expect(container.exists(learnerStateProvider(_a2)), isFalse);
      expect(rows[_a1]!.read().hasValue, isTrue);
      expect(rows[_b1]!.read().hasValue, isTrue);
    });

    test(
      'a permission-denied read clears that scope, even after data',
      () async {
        final rows = _watchRows(container, _scopes);
        for (final scope in _scopes) {
          source.grant(scope);
        }
        await pumpEventQueue();
        for (final scope in _scopes) {
          states.emit(scope, _state(1));
        }
        await pumpEventQueue();

        states.fail(_b1, _permissionDenied());
        await pumpEventQueue();

        expect(
          rows[_b1]!.read(),
          _deniedFor(_b1, TutorScopeDenialReason.permissionDenied),
        );
        expect(rows[_a1]!.read().hasValue, isTrue);
        expect(rows[_a2]!.read().hasValue, isTrue);
      },
    );

    test(
      'a grant-listener permission-denied verdict clears the scope',
      () async {
        final rows = _watchRows(container, [_a1]);
        source.grant(_a1);
        await pumpEventQueue();
        states.emit(_a1, _state(1));
        await pumpEventQueue();

        source.deny(_a1, TutorScopeDenialReason.permissionDenied);
        await pumpEventQueue();
        expect(
          rows[_a1]!.read(),
          _deniedFor(_a1, TutorScopeDenialReason.permissionDenied),
        );
      },
    );

    test('a scope with no grant never reads the learner', () async {
      final rows = _watchRows(container, [_b1]);
      source.deny(_b1, TutorScopeDenialReason.noGrant);
      await pumpEventQueue();
      expect(
        rows[_b1]!.read(),
        _deniedFor(_b1, TutorScopeDenialReason.noGrant),
      );
      expect(states.listens[_b1], isNull);
    });

    test('a re-grant restores the read', () async {
      final rows = _watchRows(container, [_a1]);
      source.deny(_a1, TutorScopeDenialReason.grantNotActive);
      await pumpEventQueue();
      source.grant(_a1);
      await pumpEventQueue();
      final state = _state(5);
      states.emit(_a1, state);
      await pumpEventQueue();
      expect(rows[_a1]!.read().value, same(state));
    });

    test(
      'any other grant-listener failure fails closed (no stale value)',
      () async {
        final rows = _watchRows(container, [_a1]);
        source.grant(_a1);
        await pumpEventQueue();
        states.emit(_a1, _state(1));
        await pumpEventQueue();

        source.fail(_a1, StateError('unavailable'));
        await pumpEventQueue();
        expect(
          rows[_a1]!.read(),
          isA<AsyncError<LearnerState>>()
              .having((e) => e.hasValue, 'hasValue', isFalse)
              .having((e) => e.error, 'error', isA<StateError>()),
        );
      },
    );

    test('any other learner-state failure is forwarded as is', () async {
      final rows = _watchRows(container, [_a1]);
      source.grant(_a1);
      await pumpEventQueue();
      states.fail(_a1, StateError('decode'));
      await pumpEventQueue();
      expect(
        rows[_a1]!.read(),
        isA<AsyncError<LearnerState>>().having(
          (e) => e.error,
          'error',
          isA<StateError>(),
        ),
      );
    });

    test(
      'warm only while visible: an unwatched row releases its state',
      () async {
        final rows = _watchRows(container, [_a1, _b1]);
        source
          ..grant(_a1)
          ..grant(_b1);
        await pumpEventQueue();
        states
          ..emit(_a1, _state(1))
          ..emit(_b1, _state(2));
        await pumpEventQueue();

        rows[_a1]!.close();
        await pumpEventQueue();

        expect(container.exists(learnerStateForScopeProvider(_a1)), isFalse);
        expect(container.exists(learnerStateProvider(_a1)), isFalse);
        expect(container.exists(tutorScopeGrantProvider(_a1)), isFalse);
        expect(states.cancels[_a1], 1);
        expect(container.exists(learnerStateProvider(_b1)), isTrue);
        expect(rows[_b1]!.read().hasValue, isTrue);
      },
    );
  });

  test('no signed-in account denies every scope as notSignedIn', () async {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: tutorScopeReadOverrides(
        source: null,
        states: ScopedLearnerStateStreams(),
      ),
    );
    final rows = _watchRows(container, [_a1]);
    await pumpEventQueue();
    expect(
      rows[_a1]!.read(),
      _deniedFor(_a1, TutorScopeDenialReason.notSignedIn),
    );
  });

  group('end to end over Firestore grants (fake Firestore)', () {
    late FakeFirebaseFirestore db;
    late ScopedLearnerStateStreams states;
    late ProviderContainer container;

    Future<void> seedGrant(String id, LearnerScope scope) =>
        db.collection('tutor_grants').doc(id).set({
          'tutor_uid': _tutor,
          'parent_uid': scope.ownerUid,
          'child_profile_id': scope.profileId,
          'state': 'active',
          'tutor_email': 'tutor@test.com',
        });

    setUp(() async {
      db = FakeFirebaseFirestore();
      states = ScopedLearnerStateStreams();
      await seedGrant('g-a1', _a1);
      await seedGrant('g-a2', _a2);
      await seedGrant('g-b1', _b1);
      final handles = AccountFirebaseHandles(
        app: _MockApp(),
        firestore: db,
        auth: _MockAuth(),
        uid: _tutor,
      );
      container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          activeAccountFirebaseProvider.overrideWith((ref) async => handles),
          learnerStateProvider.overrideWith(
            (ref, scope) => states.stream(scope),
          ),
        ],
      );
    });

    test('3 scopes from 2 parents read through; revoking parent B clears '
        'only B', () async {
      final rows = _watchRows(container, _scopes);
      await pumpEventQueue();
      for (final scope in _scopes) {
        states.emit(scope, _state(1));
      }
      await pumpEventQueue();
      for (final scope in _scopes) {
        expect(rows[scope]!.read().hasValue, isTrue, reason: '$scope');
      }

      await db.collection('tutor_grants').doc('g-b1').update({
        'state': 'revoked_by_parent',
      });
      await pumpEventQueue();

      expect(
        rows[_b1]!.read(),
        _deniedFor(_b1, TutorScopeDenialReason.grantNotActive),
      );
      expect(container.exists(learnerStateProvider(_b1)), isFalse);
      expect(rows[_a1]!.read().hasValue, isTrue);
      expect(rows[_a2]!.read().hasValue, isTrue);
    });

    test('a scope the tutor holds no grant for is denied', () async {
      final stranger = LearnerScope(ownerUid: 'parent-c', profileId: ulidD);
      final rows = _watchRows(container, [stranger]);
      await pumpEventQueue();
      expect(
        rows[stranger]!.read(),
        _deniedFor(stranger, TutorScopeDenialReason.noGrant),
      );
      expect(states.listens[stranger], isNull);
    });
  });
}
