/// Unit tests for [FirestoreStudyDayConfigRepositoryAdapter]
/// (`lib/features/scheduler/data/repositories/
/// study_day_config_repository_impl.dart`) — the Firestore adapter over
/// [FirestoreStudyDayConfigRepository]. There was never a Drift-era
/// `StudyDayConfigRepository` domain interface to adapt (see the class doc
/// comment), so this file exercises the adapter's own method surface
/// directly. Mirrors `bookmark_repository_impl_test.dart`'s
/// `FirestoreBookmarkRepositoryAdapter` group structure (the reference
/// pattern): a "not ready" group (no active account/profile) and a "ready"
/// group (active account/profile, backed by `fake_cloud_firestore`).
///
/// **What these tests cannot see**: `firestore_study_day_config_repository_
/// test.dart` already documents `fake_cloud_firestore`'s general
/// limitations (no composite-index enforcement, no `resource.data` rules
/// evaluation). This file only proves the adapter DELEGATES correctly
/// (including its not-ready fallback values) — it does not re-prove the
/// underlying repository's own Firestore behavior.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/scheduler/data/repositories/study_day_config_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:mocktail/mocktail.dart';

import 'not_ready_expectations.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  group('FirestoreStudyDayConfigRepositoryAdapter', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    // Constructing the adapter requires a Ref (Riverpod's Ref is sealed —
    // it can only come from inside a provider callback), so tests obtain
    // one the same way production does: read a throwaway Provider that
    // builds the adapter from the container's ref. Mirrors
    // FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreStudyDayConfigRepositoryAdapter buildAdapter(
      ProviderContainer container,
    ) {
      final adapterProvider =
          Provider<FirestoreStudyDayConfigRepositoryAdapter>(
            (ref) => FirestoreStudyDayConfigRepositoryAdapter(ref: ref),
          );
      return container.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      // Hoisted: every test in this group needs the same bare container (no
      // account/profile overrides — that IS the not-ready condition), so
      // repeating it per test was pure setup noise.
      late FirestoreStudyDayConfigRepositoryAdapter notReadyAdapter;

      setUp(() {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        notReadyAdapter = buildAdapter(container);
      });

      test(
        'getConfigsForCurriculum returns an empty list instead of throwing',
        () async {
          await expectEmptyListWhenNotReady(
            () =>
                notReadyAdapter.getConfigsForCurriculum(CurriculumId.mishnayos),
            describe: 'StudyDayConfigRepository.getConfigsForCurriculum',
          );
        },
      );

      test('watchConfigsForCurriculum emits a single empty list', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        final result = await adapter
            .watchConfigsForCurriculum(CurriculumId.mishnayos)
            .first;

        expect(result, isEmpty);
      });

      test(
        'setDayConfig throws StudyDayConfigRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.setDayConfig(
              curriculumId: CurriculumId.mishnayos,
              dayOfWeek: 1,
              dayType: DayType.study,
            ),
            throwsA(isA<StudyDayConfigRepositoryNotReadyException>()),
          );
        },
      );

      test('replaceAllForCurriculum throws '
          'StudyDayConfigRepositoryNotReadyException', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(
          () => adapter.replaceAllForCurriculum(
            curriculumId: CurriculumId.mishnayos,
            studyDays: const {1: DayType.study},
          ),
          throwsA(isA<StudyDayConfigRepositoryNotReadyException>()),
        );
      });

      test(
        'initializeDefaults throws StudyDayConfigRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.initializeDefaults(CurriculumId.mishnayos),
            throwsA(isA<StudyDayConfigRepositoryNotReadyException>()),
          );
        },
      );
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreStudyDayConfigRepositoryAdapter adapter;

      setUp(() {
        firestore = FakeFirebaseFirestore();
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
        adapter = buildAdapter(container);
      });

      tearDown(() => container.dispose());

      test(
        'initializeDefaults delegates to FirestoreStudyDayConfigRepository '
        'and seeds all 7 days reachable at the expected Firestore path',
        () async {
          await adapter.initializeDefaults(CurriculumId.mishnayos);

          final configs = await adapter.getConfigsForCurriculum(
            CurriculumId.mishnayos,
          );
          expect(configs, hasLength(7));

          final doc = await firestore
              .collection('users')
              .doc(uid)
              .collection('learner_profiles')
              .doc(profileDocId)
              .collection('study_day_configs')
              .doc('mishnayos_1')
              .get();
          expect(doc.exists, isTrue);
        },
      );

      test('setDayConfig then getConfigsForCurriculum round-trips through '
          'Firestore', () async {
        await adapter.setDayConfig(
          curriculumId: CurriculumId.mishnayos,
          dayOfWeek: 3,
          dayType: DayType.review,
        );

        final configs = await adapter.getConfigsForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(configs, hasLength(1));
        expect(configs.single.dayOfWeek, 3);
        expect(configs.single.dayType, DayType.review);
      });

      test('replaceAllForCurriculum deletes days absent from the new set and '
          'upserts the rest', () async {
        await adapter.initializeDefaults(CurriculumId.mishnayos);

        await adapter.replaceAllForCurriculum(
          curriculumId: CurriculumId.mishnayos,
          studyDays: const {1: DayType.study, 2: DayType.review},
        );

        final configs = await adapter.getConfigsForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(configs, hasLength(2));
        expect(configs.map((c) => c.dayOfWeek), [1, 2]);
      });

      test('watchConfigsForCurriculum forwards the resolved repository\'s '
          'stream', () async {
        await adapter.setDayConfig(
          curriculumId: CurriculumId.mishnayos,
          dayOfWeek: 5,
          dayType: DayType.study,
        );

        final result = await adapter
            .watchConfigsForCurriculum(CurriculumId.mishnayos)
            .first;

        expect(result, hasLength(1));
        expect(result.single.dayOfWeek, 5);
      });
    });
  });
}
