/// Unit tests for `test/helpers/writer_reader_agreement.dart` — the
/// writer/reader path-agreement helper itself (Phase 1 step B2).
///
/// Two groups:
/// - [activateAccountAndProfile] resolves the two seams it touches so a
///   `firestoreXRepositoryProvider` genuinely becomes ready.
/// - [expectWriterReaderAgree] PASSES for a correctly-wired collection and
///   FAILS for a deliberately mis-wired one — the "also required" proof
///   from the B2 brief. `goals` is used as the worked example: it is
///   currently a single-scheme collection (only
///   `firestoreGoalRepositoryProvider` and the
///   [FirestoreGoalRepositoryAdapter] built on it exist — see
///   `lib/data/repositories/firestore_goal_repository.dart`'s class doc
///   comment), unlike the bookmarks/learning-order pair the helper was
///   extracted from, so a green run here proves the helper generalizes
///   rather than merely replaying its own precedent.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/goal_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/writer_reader_agreement.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  group('activateAccountAndProfile', () {
    test('resolves firestoreGoalRepositoryProvider — both seams (active '
        'account + active profile) are wired', () async {
      final rig = activateAccountAndProfile();
      addTearDown(rig.container.dispose);

      final repo = await rig.container.read(
        firestoreGoalRepositoryProvider.future,
      );

      expect(
        repo,
        isNotNull,
        reason:
            'A profile-scoped FutureProvider resolving to null means '
            '"no active account/profile" (repository_providers.dart\'s '
            'own convention) — activateAccountAndProfile must leave '
            'neither unset.',
      );
    });

    test('a second call builds an independent rig — no shared state leaks '
        'between tests or between two rigs in the same test', () async {
      final rigA = activateAccountAndProfile(
        uid: 'uid-a',
        profileId: 'profile-a',
      );
      addTearDown(rigA.container.dispose);
      final rigB = activateAccountAndProfile(
        uid: 'uid-b',
        profileId: 'profile-b',
      );
      addTearDown(rigB.container.dispose);

      final repoA = await rigA.container.read(
        firestoreGoalRepositoryProvider.future,
      );
      await repoA!.createGoal(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 50,
      );

      final repoB = await rigB.container.read(
        firestoreGoalRepositoryProvider.future,
      );
      final goalsSeenByB = await repoB!.getGoals(CurriculumId.mishnayos);

      expect(
        goalsSeenByB,
        isEmpty,
        reason:
            'rigA and rigB are built over entirely separate '
            'FakeFirebaseFirestore instances — a write through one must '
            'never be visible through the other.',
      );
    });
  });

  group('expectWriterReaderAgree', () {
    test('PASSES when writer and reader resolve the same production path '
        '(goals, both call shapes: a direct provider read and a Ref-taking '
        'adapter)', () async {
      final rig = activateAccountAndProfile();
      addTearDown(rig.container.dispose);

      final adapterProvider = Provider<FirestoreGoalRepositoryAdapter>(
        (ref) => FirestoreGoalRepositoryAdapter(ref: ref),
      );

      await expectWriterReaderAgree<List<GoalEntity>>(
        firestore: rig.firestore,
        collection: 'goals',
        writerDescription:
            'firestoreGoalRepositoryProvider.createGoal (direct provider '
            'read — shape A)',
        readerDescription:
            'FirestoreGoalRepositoryAdapter.getGoals (Ref-taking '
            'adapter — shape B)',
        write: () async {
          final repo = await rig.container.read(
            firestoreGoalRepositoryProvider.future,
          );
          await repo!.createGoal(
            curriculumId: CurriculumId.mishnayos,
            targetPercent: 75,
          );
        },
        read: () => rig.container
            .read(adapterProvider)
            .getGoals(CurriculumId.mishnayos),
        matches: isNotEmpty,
      );
    });

    test('FAILS when writer and reader resolve different profile paths '
        '(deliberately mis-wired) — proving the helper actually detects '
        'disagreement rather than passing vacuously', () async {
      // The writer's rig: the one legitimate activateAccountAndProfile
      // call for this test (per the helper's "exactly one call" rule for
      // a REAL agreement check). goal is created under 'profile-correct'.
      final rig = activateAccountAndProfile(profileId: 'profile-correct');
      addTearDown(rig.container.dispose);

      // The deliberately mis-wired reader: a SEPARATE container sharing
      // the SAME fake Firestore instance and the SAME uid as the writer,
      // but with its activeProfileDocIdProvider set to a DIFFERENT
      // profile id. This reproduces the exact defect class
      // `docs/firestore-rewrite-map.md` item 10 describes — a reader
      // that resolves a different document tree than the writer — using
      // only production wiring (repository_providers.dart) on both
      // sides. The only thing the test itself chose is which profile id
      // each container's active-profile seam was set to; the resulting
      // Firestore *paths* still come entirely from
      // FirestoreGoalRepository's own path-building code.
      final misWiredContainer = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => AccountFirebaseHandles(
              app: MockFirebaseApp(),
              firestore: rig.firestore,
              auth: MockFirebaseAuthHandle(),
              uid: 'uid-1',
            ),
          ),
        ],
      );
      addTearDown(misWiredContainer.dispose);
      misWiredContainer
          .read(activeProfileDocIdProvider.notifier)
          .set('profile-WRONG');

      await expectLater(
        expectWriterReaderAgree<List<GoalEntity>>(
          firestore: rig.firestore,
          collection: 'goals',
          writerDescription:
              'firestoreGoalRepositoryProvider.createGoal '
              '(profile-correct)',
          readerDescription:
              'firestoreGoalRepositoryProvider.getGoals '
              '(profile-WRONG, deliberately mis-wired)',
          write: () async {
            final repo = await rig.container.read(
              firestoreGoalRepositoryProvider.future,
            );
            await repo!.createGoal(
              curriculumId: CurriculumId.mishnayos,
              targetPercent: 75,
            );
          },
          read: () async {
            final repo = await misWiredContainer.read(
              firestoreGoalRepositoryProvider.future,
            );
            return repo!.getGoals(CurriculumId.mishnayos);
          },
          matches: isNotEmpty,
        ),
        throwsA(isA<TestFailure>()),
        reason:
            'The reader resolved a different profile document tree than '
            'the writer, so it must observe no goals — the assertion '
            'inside expectWriterReaderAgree must itself fail (a '
            'TestFailure), not silently pass.',
      );
    });
  });
}
