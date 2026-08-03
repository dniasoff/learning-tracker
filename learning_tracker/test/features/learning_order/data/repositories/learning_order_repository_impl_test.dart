/// AUD-tracks-15 (SM-8): LearningOrderRepositoryImpl no longer takes a
/// ContentRepository dependency — getOrder accepts the already-resolved
/// `List<ContentItem>` directly, so every test below constructs the repo
/// with only an in-memory database and passes the fixture items straight
/// into the getOrder calls (no ContentRepository fake required).
library;

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart'
    show ParentControlException;
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart'
    show seedProfile, seedProfileZero, seedTrack;
import '../../../../helpers/firestore_fake.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

ContentItem _makeItem(String ref, {int sortOrder = 0}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: ref,
    displayNameHe: '$ref-he',
    displayNameEn: '$ref-en',
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: false,
  );
}

/// A [TrackDao] whose [stampReorderAt] always throws, simulating a crash /
/// DB failure during the reorder-amnesty stamp write. Used to prove the
/// stamp write and the order-mutation write(s) are atomic (AUD-tracks-16).
class _ThrowingStampTrackDao extends TrackDao {
  _ThrowingStampTrackDao(super.db);

  @override
  Future<void> stampReorderAt(int trackId, {DateTime? at}) async {
    throw Exception(
      'simulated crash during reorder-amnesty stamp (AUD-tracks-16)',
    );
  }
}

/// [UserDatabase] wired with [_ThrowingStampTrackDao] so any call to
/// `trackDao.stampReorderAt` throws — the fault-injection seam matches the
/// established `_ThrowingDaoUserDatabase` pattern used elsewhere in this
/// test suite (see auth_state_init_exception_guard_test.dart).
class _ThrowingStampUserDatabase extends UserDatabase {
  _ThrowingStampUserDatabase(super.e);

  @override
  late final TrackDao trackDao = _ThrowingStampTrackDao(this);
}

void main() {
  late UserDatabase database;
  late LearningOrderRepositoryImpl repo;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    await seedProfileZero(database);
    await seedProfile(database); // seeds account(1)+profile(1) for DAO tests
    repo = LearningOrderRepositoryImpl(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('LearningOrderRepositoryImpl', () {
    test(
      'getOrder returns items in sortOrder when no custom rows exist (D7 fallback)',
      () async {
        final items = [
          _makeItem('Shabbat', sortOrder: 2),
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Peah', sortOrder: 1),
        ];

        final order = await repo.getOrder(CurriculumId.mishnayos, items);

        expect(order.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Peah',
          'Shabbat',
        ]);
        expect(order.every((i) => !i.isCustomOrdered), isTrue);
      },
    );

    test(
      'getOrder returns custom order when DAO rows exist, overriding content order',
      () async {
        final items = [
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Shabbat', sortOrder: 1),
        ];

        // Custom order: Shabbat first. `repo` defaults to profileId 0, so
        // fixtures must be seeded under the same profile it reads from
        // (AUD-core-database-02: these rows used to be seeded under
        // profileId 1 and only "worked" because the DAO ignored profileId).
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 1,
          ),
        );

        final order = await repo.getOrder(CurriculumId.mishnayos, items);

        expect(order.map((i) => i.sefariaRef).toList(), [
          'Shabbat',
          'Berakhot',
        ]);
        expect(order.every((i) => i.isCustomOrdered), isTrue);
      },
    );

    test(
      'saveOrder writes correct userSortOrder (position index) for each item',
      () async {
        final itemsToSave = [
          const LearningOrderItem(
            sefariaRef: 'Shabbat',
            displayNameHe: 'שבת',
            displayNameEn: 'Shabbat',
            userSortOrder: 0,
          ),
          const LearningOrderItem(
            sefariaRef: 'Berakhot',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berakhot',
            userSortOrder: 1,
          ),
        ];

        await repo.saveOrder(CurriculumId.mishnayos, itemsToSave);

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 0);
        expect(rows.map((r) => r.sefariaRef).toList(), ['Shabbat', 'Berakhot']);
        expect(rows.map((r) => r.userSortOrder).toList(), [0, 1]);
      },
    );

    test(
      'resetToDefault deletes all rows; subsequent getOrder falls back to natural order',
      () async {
        final items = [
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Shabbat', sortOrder: 1),
        ];

        // Add custom row. `repo` defaults to profileId 0 — see note above.
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );

        await repo.resetToDefault(CurriculumId.mishnayos);

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 0);
        expect(rows, isEmpty);

        final order = await repo.getOrder(CurriculumId.mishnayos, items);
        expect(order.every((i) => !i.isCustomOrdered), isTrue);
        expect(order.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Shabbat',
        ]);
      },
    );
  });

  // AUD-core-database-02: LearningOrderDao.getLearningOrderByCurriculum /
  // deleteAllForCurriculum queried only by curriculumId with no profileId
  // predicate, so one profile's custom order leaked into (and could be
  // silently wiped by) a sibling profile sharing the same curriculum.
  group('AUD-core-database-02 — cross-profile isolation', () {
    test('getOrder(profile 0) excludes rows written for profile 1', () async {
      final items = [
        _makeItem('Berakhot', sortOrder: 0),
        _makeItem('Shabbat', sortOrder: 1),
      ];

      // Seed a custom order row for profile 1 only.
      await database.learningOrderDao.upsertLearningOrder(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'ProfileOneCustom',
          userSortOrder: 0,
        ),
      );

      // `repo` is scoped to profile 0 (default profileId in the outer
      // setUp) and has no custom order rows of its own.
      final order = await repo.getOrder(CurriculumId.mishnayos, items);

      expect(
        order.map((i) => i.sefariaRef),
        isNot(contains('ProfileOneCustom')),
        reason:
            "Profile 0 must never see profile 1's custom learning-order "
            'row (cross-sibling read leak — AUD-core-database-02).',
      );
      expect(
        order.every((i) => !i.isCustomOrdered),
        isTrue,
        reason:
            'Profile 0 has no custom rows of its own, so it must fall '
            "back to natural content order, not profile 1's custom order.",
      );
    });

    test('resetToDefault(profile 0) leaves profile 1 rows intact', () async {
      // Seed profile 1's own custom row.
      await database.learningOrderDao.upsertLearningOrder(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'ProfileOneCustom',
          userSortOrder: 0,
        ),
      );
      // Seed profile 0's own custom row so resetToDefault has something to
      // delete for the profile actually under test.
      await database.learningOrderDao.upsertLearningOrder(
        LearningOrderCompanion.insert(
          profileId: 0,
          curriculumId: 'mishnayos',
          sefariaRef: 'ProfileZeroCustom',
          userSortOrder: 0,
        ),
      );

      // `repo` is scoped to profile 0.
      await repo.resetToDefault(CurriculumId.mishnayos);

      final remaining = await database.learningOrderDao.getAllLearningOrders();
      final profileOneRows = remaining.where((r) => r.profileId == 1);
      final profileZeroRows = remaining.where((r) => r.profileId == 0);

      expect(
        profileOneRows.map((r) => r.sefariaRef),
        contains('ProfileOneCustom'),
        reason:
            "resetToDefault(profile 0) must not silently delete profile 1's "
            'rows (cross-sibling data loss — AUD-core-database-02).',
      );
      expect(
        profileZeroRows,
        isEmpty,
        reason: "Profile 0's own row must be deleted by resetToDefault.",
      );
    });
  });

  // AUD-tracks-16: _stampReorderAt used to run OUTSIDE the transaction that
  // persists the order write in both saveOrder and resetToDefault. A crash
  // or DB error between the two left the order change committed with the
  // reorder-amnesty stamp missing (or vice-versa for resetToDefault's
  // delete). Both writes must now be atomic — a throw from the stamp write
  // must roll back the order write too.
  group(
    'AUD-tracks-16 — reorder-amnesty stamp is atomic with the order write',
    () {
      late UserDatabase faultyDb;
      late LearningOrderRepositoryImpl faultyRepo;

      setUp(() async {
        faultyDb = _ThrowingStampUserDatabase(NativeDatabase.memory());
        await seedProfileZero(faultyDb);
        await seedProfile(faultyDb);
        // _stampReorderAt no-ops silently when no active track exists for the
        // profile — an active track for profileId 0 (repo's default) is
        // required so the throwing stamp is actually reached.
        await seedTrack(faultyDb, profileId: 0);

        // AUD-tracks-15 (SM-8): LearningOrderRepositoryImpl no longer takes
        // a ContentRepository dependency — saveOrder/resetToDefault under
        // test here never touch content, so no fake is needed at all.
        faultyRepo = LearningOrderRepositoryImpl(database: faultyDb);
      });

      tearDown(() async {
        await faultyDb.close();
      });

      test('saveOrder rolls back the learning_order upserts when the '
          'reorder-amnesty stamp throws', () async {
        final itemsToSave = [
          const LearningOrderItem(
            sefariaRef: 'Shabbat',
            displayNameHe: 'שבת',
            displayNameEn: 'Shabbat',
            userSortOrder: 0,
          ),
          const LearningOrderItem(
            sefariaRef: 'Berakhot',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berakhot',
            userSortOrder: 1,
          ),
        ];

        await expectLater(
          () => faultyRepo.saveOrder(CurriculumId.mishnayos, itemsToSave),
          throwsA(isA<Exception>()),
        );

        final rows = await faultyDb.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 0);
        expect(
          rows,
          isEmpty,
          reason:
              'the learning_order upserts must roll back when the '
              'reorder-amnesty stamp write fails — both writes belong to '
              'the same atomic transaction (AUD-tracks-16).',
        );
      });

      test('resetToDefault rolls back the learning_order delete when the '
          'reorder-amnesty stamp throws', () async {
        // Seed an existing custom row directly through the DAO (not through
        // the throwing repo) so resetToDefault has something to delete.
        await faultyDb.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );

        await expectLater(
          () => faultyRepo.resetToDefault(CurriculumId.mishnayos),
          throwsA(isA<Exception>()),
        );

        final rows = await faultyDb.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 0);
        expect(
          rows,
          hasLength(1),
          reason:
              'the learning_order delete must roll back when the '
              'reorder-amnesty stamp write fails — both writes belong to '
              'the same atomic transaction (AUD-tracks-16).',
        );
      });
    },
  );

  // F2: `learningOrderRepositoryProvider` now resolves to
  // FirestoreLearningOrderRepositoryAdapter instead of the Drift-backed
  // LearningOrderRepositoryImpl above. These tests exercise that adapter
  // directly, mirroring the FirestoreBookmarkRepositoryAdapter test group in
  // `bookmark_repository_impl_test.dart`.
  group('FirestoreLearningOrderRepositoryAdapter', () {
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

    // Constructing FirestoreLearningOrderRepositoryAdapter requires a Ref
    // (Riverpod's Ref is sealed — it can only come from inside a provider
    // callback), so tests obtain one the same way production does: read a
    // throwaway Provider that builds the adapter from the container's ref.
    FirestoreLearningOrderRepositoryAdapter buildAdapter(
      ProviderContainer container,
    ) {
      final adapterProvider = Provider<FirestoreLearningOrderRepositoryAdapter>(
        (ref) => FirestoreLearningOrderRepositoryAdapter(ref: ref),
      );
      return container.read(adapterProvider);
    }

    final saveItems = [
      const LearningOrderItem(
        sefariaRef: 'Shabbat',
        displayNameHe: 'שבת',
        displayNameEn: 'Shabbat',
        userSortOrder: 0,
      ),
      const LearningOrderItem(
        sefariaRef: 'Berakhot',
        displayNameHe: 'ברכות',
        displayNameEn: 'Berakhot',
        userSortOrder: 1,
      ),
    ];

    group('not ready (no active account/profile)', () {
      test('getOrder returns [] instead of throwing', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        final order = await adapter.getOrder(CurriculumId.mishnayos, const []);

        expect(order, isEmpty);
      });

      test(
        'saveOrder throws LearningOrderRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.saveOrder(CurriculumId.mishnayos, saveItems),
            throwsA(isA<LearningOrderRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'resetToDefault throws LearningOrderRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.resetToDefault(CurriculumId.mishnayos),
            throwsA(isA<LearningOrderRepositoryNotReadyException>()),
          );
        },
      );

      test('saveOrder throws ParentControlException before the not-ready '
          'repository check, even when not ready', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(
          () => adapter.saveOrder(
            CurriculumId.mishnayos,
            saveItems,
            isChildRestricted: true,
          ),
          throwsA(isA<ParentControlException>()),
        );
      });
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreLearningOrderRepositoryAdapter adapter;

      setUp(() {
        firestore = createFakeFirestore();
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

      test('saveOrder then getOrder round-trips the custom order through '
          'Firestore', () async {
        await adapter.saveOrder(CurriculumId.mishnayos, saveItems);

        final order = await adapter.getOrder(CurriculumId.mishnayos, const []);

        expect(order.map((i) => i.sefariaRef).toList(), [
          'Shabbat',
          'Berakhot',
        ]);
        expect(order.every((i) => i.isCustomOrdered), isTrue);
      });

      test('saveOrder with isChildRestricted throws ParentControlException '
          'without writing anything to Firestore', () async {
        await expectLater(
          () => adapter.saveOrder(
            CurriculumId.mishnayos,
            saveItems,
            isChildRestricted: true,
          ),
          throwsA(isA<ParentControlException>()),
        );

        final rawRepo = FirestoreLearningOrderRepository(
          firestore: firestore,
          uid: uid,
          profileId: profileDocId,
        );
        final refs = await rawRepo.getCustomOrderRefs(CurriculumId.mishnayos);
        expect(refs, isEmpty);
      });

      test('resetToDefault propagates the documented UnimplementedError rather '
          'than swallowing it', () async {
        expect(
          () => adapter.resetToDefault(CurriculumId.mishnayos),
          throwsA(isA<UnimplementedError>()),
        );
      });

      // F2 — the defect this rewire fixes: a custom order saved through
      // `learningOrderRepositoryProvider` (this adapter) must be visible to
      // `FirestoreLearningOrderRepository.getCustomOrderRefs` — the exact
      // read `FirestoreBookmarkRepositoryAdapter`'s bookmark-advance logic
      // uses (`_getNextItemId`/`_getFirstItemId`). Before this fix, the
      // reorder screen wrote to the Drift-backed LearningOrderRepositoryImpl
      // while the bookmark repository read from this Firestore collection —
      // two different document trees that never agreed, so a saved custom
      // order was invisible to bookmark advance for every user.
      test('F2 round-trip: an order saved via the adapter is visible to '
          'FirestoreLearningOrderRepository.getCustomOrderRefs — writer and '
          'reader agree on ONE document path', () async {
        await adapter.saveOrder(CurriculumId.mishnayos, saveItems);

        final rawRepo = FirestoreLearningOrderRepository(
          firestore: firestore,
          uid: uid,
          profileId: profileDocId,
        );
        final refs = await rawRepo.getCustomOrderRefs(CurriculumId.mishnayos);

        expect(
          refs,
          ['Shabbat', 'Berakhot'],
          reason:
              'If the adapter wrote to a different document tree than '
              'getCustomOrderRefs reads (the F2 defect), this would come '
              'back empty even though saveOrder above completed '
              'successfully — silently freezing bookmark advance for '
              'every user with a custom order.',
        );
      });
    });
  });
}
