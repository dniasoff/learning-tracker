/// Unit tests for `lib/data/firestore/repository_providers.dart` — the
/// Riverpod layer that resolves the Firestore repositories under
/// `lib/data/repositories/` from the active account + active learner
/// profile.
///
/// Deliberately does not re-test [AccountFirebase]/
/// `activeAccountFirebaseProvider`'s own resolution behavior (already
/// covered by `test/data/firestore/account_firebase_test.dart` and
/// `active_account_providers_test.dart`). Every test that needs an "active
/// account" here overrides [activeAccountFirebaseProvider] directly with a
/// synthetic [AccountFirebaseHandles] built over a fresh
/// `FakeFirebaseFirestore` — the same "construct the handle bundle
/// directly, mock only what nothing under test calls" approach used for
/// repository tests.
///
/// [FirestoreGoalRepository] is used as the representative profile-scoped
/// repository for the full null-branch matrix (no account/no profile,
/// account-only, profile-only, both, and — since T-35's hoist,
/// `docs/planning/firestore-cutover-log.md` — a tutored session active on
/// top of both) rather than repeating all five cases 11 times — every
/// profile-scoped provider shares the exact same
/// [_watchActiveAccountAndProfile] gate, so this is the one place that gate
/// itself is exhaustively covered. The "every other profile-scoped
/// provider resolves" group then spot-checks the remaining repositories
/// with a single both-active / both-inactive pair, to catch a
/// copy-paste/wiring mistake in an individual provider without
/// re-deriving the shared logic each time.
///
/// TQ-6: no wall clock, no shared mutable global state between tests —
/// every test builds its own [ProviderContainer] and `FakeFirebaseFirestore`,
/// order-independent under `--test-randomize-ordering-seed=random`.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firestore_fixtures.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

const _uid = 'uid-1';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FB1';
const _otherProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FB2';

/// Builds an [AccountFirebaseHandles] bundle over [firestore]. [app]/[auth]
/// are unstubbed mocks — every provider under test only ever reads
/// [AccountFirebaseHandles.firestore]/[AccountFirebaseHandles.uid], never a
/// method on the app or auth handle, so nothing here needs to be stubbed.
AccountFirebaseHandles _handles(
  FakeFirebaseFirestore firestore, {
  String uid = _uid,
}) {
  return AccountFirebaseHandles(
    app: MockFirebaseApp(),
    firestore: firestore,
    auth: MockFirebaseAuthHandle(),
    uid: uid,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('activeProfileDocIdProvider', () {
    test(
      'defaults to null — nothing is active until something calls set()',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(activeProfileDocIdProvider), isNull);
      },
    );

    test('set() updates the state; set(null) clears it again', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(activeProfileDocIdProvider.notifier).set(_profileId);
      expect(container.read(activeProfileDocIdProvider), _profileId);

      container.read(activeProfileDocIdProvider.notifier).set(null);
      expect(container.read(activeProfileDocIdProvider), isNull);
    });
  });

  group('firestoreAccountRepositoryProvider (account-scoped, no profile '
      'needed)', () {
    test('resolves to null when no account is active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = await container.read(
        firestoreAccountRepositoryProvider.future,
      );

      expect(repo, isNull);
    });

    test('resolves a repository scoped to the active account\'s uid once '
        'an account is active', () async {
      final firestore = FakeFirebaseFirestore();
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = await container.read(
        firestoreAccountRepositoryProvider.future,
      );

      expect(repo, isA<FirestoreAccountRepository>());
      await repo!.createAccount(displayName: 'Test User');

      // Proves the provider threaded the SAME uid through: the write
      // landed at exactly `users/{uid}` on the SAME fake instance, not a
      // stray copy or a different path.
      final raw = await firestore.collection('users').doc(_uid).get();
      expect(raw.exists, isTrue);
      expect(raw.data()!['display_name'], 'Test User');
    });
  });

  group('firestoreLearnerProfileRepositoryProvider (account-scoped)', () {
    test('resolves once an account is active, without any active profile '
        'id (this repository manages the profile set itself)', () async {
      final firestore = FakeFirebaseFirestore();
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Deliberately NOT setting activeProfileDocIdProvider.

      final repo = await container.read(
        firestoreLearnerProfileRepositoryProvider.future,
      );

      expect(repo, isA<FirestoreLearnerProfileRepository>());
    });

    test('resolves to null when no account is active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = await container.read(
        firestoreLearnerProfileRepositoryProvider.future,
      );

      expect(repo, isNull);
    });
  });

  group('firestoreGoalRepositoryProvider (representative profile-scoped '
      'provider — full null-branch matrix)', () {
    test('resolves to null with neither account nor profile active', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = await container.read(firestoreGoalRepositoryProvider.future);

      expect(repo, isNull);
    });

    test(
      'resolves to null with an account active but no profile active',
      () async {
        final firestore = FakeFirebaseFirestore();
        final container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => _handles(firestore),
            ),
          ],
        );
        addTearDown(container.dispose);

        final repo = await container.read(
          firestoreGoalRepositoryProvider.future,
        );

        expect(repo, isNull);
      },
    );

    test(
      'resolves to null with a profile active but no account active',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(activeProfileDocIdProvider.notifier).set(_profileId);

        final repo = await container.read(
          firestoreGoalRepositoryProvider.future,
        );

        expect(repo, isNull);
      },
    );

    test('resolves a repository scoped to the active account + active '
        'profile once both are active', () async {
      final firestore = FakeFirebaseFirestore();
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeProfileDocIdProvider.notifier).set(_profileId);

      final repo = await container.read(firestoreGoalRepositoryProvider.future);

      expect(repo, isA<FirestoreGoalRepository>());
      await seedGoal(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.chumash,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027),
      );

      final goals = await repo!.getGoals(CurriculumId.chumash);
      expect(goals, hasLength(1));
      expect(goals.single.curriculumId, CurriculumId.chumash);
    });

    test('switching the active profile id re-resolves to a repository '
        'scoped to the NEW profile — proves the provider is not caching a '
        'stale scope across a container-level override change', () async {
      final firestore = FakeFirebaseFirestore();
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
        ],
      );
      addTearDown(container.dispose);

      await seedGoal(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.chumash,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027),
      );
      await seedGoal(
        firestore,
        uid: _uid,
        profileId: _otherProfileId,
        curriculumId: CurriculumId.nach,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027),
      );

      container.read(activeProfileDocIdProvider.notifier).set(_profileId);
      final first = await container.read(
        firestoreGoalRepositoryProvider.future,
      );
      container.read(activeProfileDocIdProvider.notifier).set(_otherProfileId);
      final second = await container.read(
        firestoreGoalRepositoryProvider.future,
      );

      expect(await first!.getGoals(CurriculumId.chumash), hasLength(1));
      expect(await first.getGoals(CurriculumId.nach), isEmpty);
      expect(await second!.getGoals(CurriculumId.nach), hasLength(1));
      expect(await second.getGoals(CurriculumId.chumash), isEmpty);
    });

    test(
      'a valid tutor grant reads the child through the owner path',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedGoal(
          firestore,
          uid: 'parent-uid',
          profileId: _profileId,
          curriculumId: CurriculumId.chumash,
        );
        await firestore.collection('tutor_grants').doc('grant-1').set({
          'state': 'active',
          'tutor_uid': _uid,
          'parent_uid': 'parent-uid',
          'child_profile_id': _profileId,
        });
        final container = ProviderContainer(
          retry: (_, __) => null,
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => _handles(firestore),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(activeProfileDocIdProvider.notifier).set(_profileId);
        final keepAlive = container.listen(
          firestoreGoalRepositoryProvider,
          (_, __) {},
        );
        addTearDown(keepAlive.close);
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(
              const TutoredProfileSelection(
                profileId: _profileId,
                ownerUid: 'parent-uid',
                grantId: 'grant-1',
                permissions: TutorPermissions(),
              ),
            );

        final repo = await container.read(
          firestoreGoalRepositoryProvider.future,
        );

        expect(repo, isA<FirestoreGoalRepository>());
        final goals = await repo!.getGoals(CurriculumId.chumash);
        expect(goals, hasLength(1));
        expect(goals.single.curriculumId, CurriculumId.chumash);
      },
    );

    test(
      'a tutor selection without its grant throws instead of returning null',
      () async {
        final firestore = FakeFirebaseFirestore();
        final container = ProviderContainer(
          retry: (_, __) => null,
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => _handles(firestore),
            ),
          ],
        );
        addTearDown(container.dispose);
        final keepAlive = container.listen(
          firestoreGoalRepositoryProvider,
          (_, __) {},
        );
        addTearDown(keepAlive.close);
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(
              const TutoredProfileSelection(
                profileId: _profileId,
                ownerUid: 'parent-uid',
                grantId: 'missing-grant',
                permissions: TutorPermissions(),
              ),
            );

        await expectLater(
          container.read(firestoreGoalRepositoryProvider.future),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'non-tutored selection still resolves the signed-in owner path',
      () async {
        final firestore = FakeFirebaseFirestore();
        final container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => _handles(firestore),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(activeProfileDocIdProvider.notifier).set(_profileId);
        expect(
          await container.read(firestoreGoalRepositoryProvider.future),
          isA<FirestoreGoalRepository>(),
        );
      },
    );
  });

  group('every other profile-scoped repository provider', () {
    test(
      'all resolve to null with neither account nor profile active',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          await container.read(firestoreCompletionRepositoryProvider.future),
          isNull,
        );
        expect(
          await container.read(
            firestoreCurriculumScopeRepositoryProvider.future,
          ),
          isNull,
        );
        expect(
          await container.read(
            firestoreCurriculumTrackRepositoryProvider.future,
          ),
          isNull,
        );
        expect(
          await container.read(
            firestoreLearningLedgerRepositoryProvider.future,
          ),
          isNull,
        );
        expect(
          await container.read(
            firestoreTrackLearningOrderRepositoryProvider.future,
          ),
          isNull,
        );
        expect(
          await container.read(
            firestoreProfileProgramRepositoryProvider.future,
          ),
          isNull,
        );
        expect(
          await container.read(
            firestoreStageDefinitionRepositoryProvider.future,
          ),
          isNull,
        );
        expect(
          await container.read(firestoreStreakEventRepositoryProvider.future),
          isNull,
        );
        expect(
          await container.read(
            firestoreStudyDayConfigRepositoryProvider.future,
          ),
          isNull,
        );
      },
    );

    test('all resolve to a correctly-typed repository once an account + '
        'profile are active', () async {
      final firestore = FakeFirebaseFirestore();
      final container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeProfileDocIdProvider.notifier).set(_profileId);

      expect(
        await container.read(firestoreCompletionRepositoryProvider.future),
        isA<FirestoreCompletionRepository>(),
      );
      expect(
        await container.read(firestoreCurriculumScopeRepositoryProvider.future),
        isA<FirestoreCurriculumScopeRepository>(),
      );
      expect(
        await container.read(firestoreCurriculumTrackRepositoryProvider.future),
        isA<FirestoreCurriculumTrackRepository>(),
      );
      expect(
        await container.read(firestoreLearningLedgerRepositoryProvider.future),
        isA<FirestoreLearningLedgerRepository>(),
      );
      expect(
        await container.read(
          firestoreTrackLearningOrderRepositoryProvider.future,
        ),
        isA<FirestoreTrackLearningOrderRepository>(),
      );
      expect(
        await container.read(firestoreProfileProgramRepositoryProvider.future),
        isA<FirestoreProfileProgramRepository>(),
      );
      expect(
        await container.read(firestoreStageDefinitionRepositoryProvider.future),
        isA<FirestoreStageDefinitionRepository>(),
      );
      expect(
        await container.read(firestoreStreakEventRepositoryProvider.future),
        isA<FirestoreStreakEventRepository>(),
      );
      expect(
        await container.read(firestoreStudyDayConfigRepositoryProvider.future),
        isA<FirestoreStudyDayConfigRepository>(),
      );
    });
  });
}
