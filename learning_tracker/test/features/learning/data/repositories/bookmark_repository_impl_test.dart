import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

const _ref1 = 'Mishnah Berachot 1:1';
const _ref2 = 'Mishnah Berachot 1:2';
const _ref3 = 'Mishnah Berachot 1:3';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase database;
  late MockContentRepository mockContentRepository;
  late BookmarkRepositoryImpl repository;
  late int mishnayosTrackId;

  setUp(() async {
    database = createTestDatabase();
    await seedProfileZero(database);
    // Also seed profile 1 (referenced by learning_order tests).
    await seedProfile(database);
    mockContentRepository = MockContentRepository();

    final mishnayosTrack = await database
        .into(database.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            stateChangedAt: DateTime.utc(2026, 5, 1),
            activatedAt: DateTime.utc(2026, 5, 1),
          ),
        );
    mishnayosTrackId = mishnayosTrack.id;

    await database
        .into(database.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.bavli.storageKey,
            stateChangedAt: DateTime.utc(2026, 5, 1),
            activatedAt: DateTime.utc(2026, 5, 1),
          ),
        );

    repository = BookmarkRepositoryImpl(
      database: database,
      contentRepository: mockContentRepository,
    );

    // Default content order: ref1, ref2, ref3
    when(() => mockContentRepository.getContentForCurriculum(any())).thenAnswer(
      (_) async => [
        const ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: _ref1,
          displayNameEn: 'B 1:1',
          displayNameHe: '',
          isLeaf: true,
          sortOrder: 1,
          level1: 'Zeraim',
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: _ref2,
          displayNameEn: 'B 1:2',
          displayNameHe: '',
          isLeaf: true,
          sortOrder: 2,
          level1: 'Zeraim',
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: _ref3,
          displayNameEn: 'B 1:3',
          displayNameHe: '',
          isLeaf: true,
          sortOrder: 3,
          level1: 'Zeraim',
        ),
      ],
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('Bookmark creation and initialization', () {
    test(
      'initializeBookmark sets sefariaRef to the first item in sort order',
      () async {
        final bookmark = await repository.initializeBookmark(
          curriculumId: CurriculumId.mishnayos,
        );

        expect(bookmark.sefariaRef, _ref1);
        expect(bookmark.curriculumId, CurriculumId.mishnayos);
        expect(bookmark.updatedAt.isUtc, isTrue);
      },
    );
  });

  group('Bookmark advancement', () {
    test(
      'advanceBookmark updates sefariaRef to the next item in sort order',
      () async {
        await repository.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _ref1,
        );

        await repository.advanceBookmark(
          curriculumId: CurriculumId.mishnayos,
          completedSefariaRef: _ref1,
        );

        final updated = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(updated?.sefariaRef, _ref2);
      },
    );

    test(
      'advanceBookmark follows custom learning order when one exists',
      () async {
        // Custom order: ref3, ref1, ref2. `repository` defaults to
        // profileId 0, so fixtures must be seeded under the same profile it
        // reads from (AUD-core-database-02: these rows used to be seeded
        // under profileId 1 and only "worked" because the DAO ignored
        // profileId).
        await database.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: _ref3,
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: _ref1,
            userSortOrder: 1,
          ),
        );
        await database.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: _ref2,
            userSortOrder: 2,
          ),
        );

        // Start at ref3 (first in custom order)
        await repository.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _ref3,
        );

        await repository.advanceBookmark(
          curriculumId: CurriculumId.mishnayos,
          completedSefariaRef: _ref3,
        );

        final updated = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(updated?.sefariaRef, _ref1); // Next in custom order
      },
    );

    test('advanceBookmark keeps bookmark at last item (no overflow)', () async {
      await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: _ref3,
      );

      await repository.advanceBookmark(
        curriculumId: CurriculumId.mishnayos,
        completedSefariaRef: _ref3,
      );

      final updated = await repository.getBookmark(
        curriculumId: CurriculumId.mishnayos,
      );
      expect(updated?.sefariaRef, _ref3); // Unchanged — already at last item
    });
  });

  group('Manual bookmark operations', () {
    test('setBookmark updates sefariaRef and stores a UTC timestamp', () async {
      final before = DateTime.now().toUtc();

      final bookmark = await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: _ref2,
      );

      expect(bookmark.sefariaRef, _ref2);
      expect(bookmark.updatedAt.isUtc, isTrue);
      expect(bookmark.updatedAt.isAfter(before), isTrue);

      // No completions should be created
      final completions = await database.completionDao
          .internalGetCompletionsByCurriculumCrossProfile(
            CurriculumId.mishnayos.storageKey,
            scope: CrossProfileScope.dataExport,
          );
      expect(completions, isEmpty);
    });
  });

  group('Firestore document ID', () {
    test('firestoreId is the curriculum storage key', () async {
      final bookmark = await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: _ref1,
      );
      expect(bookmark.firestoreId, 'mishnayos');

      final bookmark2 = await repository.setBookmark(
        curriculumId: CurriculumId.bavli,
        sefariaRef: _ref1,
      );
      expect(bookmark2.firestoreId, 'bavli');
    });
  });

  group('Conflict resolution', () {
    test(
      'mergeRemoteBookmark: remote wins when it has a newer timestamp',
      () async {
        // Local bookmark at ref1 — 1 hour old
        final localTime = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );
        await database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: mishnayosTrackId,
            sefariaRef: _ref1,
            updatedAt: localTime,
          ),
        );

        // Remote at ref2 — just now
        final remoteTime = DateTime.now().toUtc();
        await repository.mergeRemoteBookmark({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'track_type': 'personal',
          'content_item_id': _ref2,
          'updated_at': remoteTime.toIso8601String(),
        });

        final result = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(result?.sefariaRef, _ref2); // Remote won
      },
    );

    test(
      'mergeRemoteBookmark: local wins when it has a newer timestamp',
      () async {
        // Set local bookmark to ref2 — just now
        await repository.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _ref2,
        );

        // Remote at ref3 — 1 hour old
        final olderRemoteTime = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );
        await repository.mergeRemoteBookmark({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'track_type': 'personal',
          'content_item_id': _ref3,
          'updated_at': olderRemoteTime.toIso8601String(),
        });

        final result = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(result?.sefariaRef, _ref2); // Local won
      },
    );
  });

  group('FirestoreBookmarkRepositoryAdapter', () {
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

    // Constructing FirestoreBookmarkRepositoryAdapter requires a Ref
    // (Riverpod's Ref is sealed — it can only come from inside a provider
    // callback), so tests obtain one the same way production does: read a
    // throwaway Provider that builds the adapter from the container's ref.
    FirestoreBookmarkRepositoryAdapter buildAdapter(
      ProviderContainer container,
      ContentRepository contentRepository, {
      ContentIndex? contentIndex,
    }) {
      final adapterProvider = Provider<FirestoreBookmarkRepositoryAdapter>(
        (ref) => FirestoreBookmarkRepositoryAdapter(
          ref: ref,
          contentRepository: contentRepository,
          contentIndex: contentIndex,
        ),
      );
      return container.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      test('getBookmark returns null instead of throwing', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container, mockContentRepository);

        final result = await adapter.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );

        expect(result, isNull);
      });

      test('setBookmark throws BookmarkRepositoryNotReadyException', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container, mockContentRepository);

        expect(
          () => adapter.setBookmark(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: _ref1,
          ),
          throwsA(isA<BookmarkRepositoryNotReadyException>()),
        );
      });

      test(
        'initializeBookmark throws BookmarkRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container, mockContentRepository);

          expect(
            () => adapter.initializeBookmark(
              curriculumId: CurriculumId.mishnayos,
            ),
            throwsA(isA<BookmarkRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'advanceBookmark throws BookmarkRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container, mockContentRepository);

          expect(
            () => adapter.advanceBookmark(
              curriculumId: CurriculumId.mishnayos,
              completedSefariaRef: _ref1,
            ),
            throwsA(isA<BookmarkRepositoryNotReadyException>()),
          );
        },
      );
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreBookmarkRepositoryAdapter adapter;

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
        adapter = buildAdapter(container, mockContentRepository);
      });

      tearDown(() => container.dispose());

      test('initializeBookmark delegates to FirestoreBookmarkRepository and '
          'writes a doc reachable at the expected Firestore path', () async {
        final bookmark = await adapter.initializeBookmark(
          curriculumId: CurriculumId.mishnayos,
        );

        expect(bookmark.sefariaRef, _ref1);

        final doc = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('bookmarks')
            .doc('mishnayos')
            .get();
        expect(doc.exists, isTrue);
      });

      test(
        'setBookmark then getBookmark round-trips through Firestore',
        () async {
          await adapter.setBookmark(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: _ref2,
          );

          final result = await adapter.getBookmark(
            curriculumId: CurriculumId.mishnayos,
          );

          expect(result?.sefariaRef, _ref2);
        },
      );

      test('advanceBookmark moves the bookmark to the next item in content '
          'order', () async {
        await adapter.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _ref1,
        );

        await adapter.advanceBookmark(
          curriculumId: CurriculumId.mishnayos,
          completedSefariaRef: _ref1,
        );

        final result = await adapter.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(result?.sefariaRef, _ref2);
      });

      test('initializeBookmark forwards the injected ContentIndex instead of '
          'falling back to a curriculum content scan', () async {
        final contentIndex = ContentIndex.fromCurricula({
          CurriculumId.mishnayos: [
            const ContentItem(
              curriculumId: 'mishnayos',
              sefariaRef: _ref1,
              displayNameEn: 'B 1:1',
              displayNameHe: '',
              isLeaf: true,
              sortOrder: 1,
              level1: 'Zeraim',
            ),
            const ContentItem(
              curriculumId: 'mishnayos',
              sefariaRef: _ref2,
              displayNameEn: 'B 1:2',
              displayNameHe: '',
              isLeaf: true,
              sortOrder: 2,
              level1: 'Zeraim',
            ),
          ],
        });
        final indexedAdapter = buildAdapter(
          container,
          mockContentRepository,
          contentIndex: contentIndex,
        );

        final bookmark = await indexedAdapter.initializeBookmark(
          curriculumId: CurriculumId.mishnayos,
        );

        expect(bookmark.sefariaRef, _ref1);
        verifyNever(() => mockContentRepository.getContentForCurriculum(any()));
      });
    });

    // REGRESSION GUARD — a tutor acting inside a talmid's context.
    //
    // `activeProfileDocIdProvider` still holds the TUTOR's own profile ULID
    // during a tutored session (nothing under lib/features/tutoring/ sets it,
    // and there is nothing to set — the tutored mirror row is Drift-only and
    // carries no ULID). So the owner path resolves to
    // users/{tutorUid}/learner_profiles/{tutorOwnUlid}/bookmarks/... — the
    // tutor's OWN document. Writing there overwrites the tutor's personal
    // reading position with the talmid's and never touches the talmid's real
    // bookmark, silently. See TutoredBookmarkWriteUnsupportedException.
    group('tutored session (tutor acting inside a talmid context)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreBookmarkRepositoryAdapter adapter;

      /// Reads `sefaria_ref` straight out of the TUTOR's own bookmark
      /// document — the one that must never be touched by a write issued
      /// while the tutor is inside a talmid's context. Read from Firestore
      /// directly rather than through the adapter, because the adapter
      /// itself refuses to read during a tutored session.
      Future<Object?> tutorOwnSefariaRef() async {
        final snapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('bookmarks')
            .doc('mishnayos')
            .get();
        return snapshot.data()?['sefaria_ref'];
      }

      setUp(() async {
        firestore = FakeFirebaseFirestore();
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        // The tutor's own account + own profile are active, exactly as they
        // are in production when the tutor enters a talmid's context.
        container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
        adapter = buildAdapter(container, mockContentRepository);

        // The tutor's own bookmark, parked on _ref1.
        await adapter.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _ref1,
        );

        // Now enter tutor mode for a talmid, exactly as
        // tutored_children_section.dart does after the PIN gate passes.
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(
              const TutoredProfileSelection(
                profileId: '42', // the talmid's id in the PARENT's account
                ownerUid: 'parent-uid',
                grantId: 'grant-1',
                permissions: TutorPermissions(),
              ),
            );
      });

      tearDown(() => container.dispose());

      test(
        "advanceBookmark never rewrites the TUTOR's own bookmark document",
        () async {
          // Deliberately NOT expressed as `throwsA(...)`: what this test
          // pins is the absence of the write, not the shape of the refusal.
          // Swallowing the refusal here means that with the guard reverted
          // the failure surfaces as the actual corruption — the tutor's
          // bookmark advanced from _ref1 to _ref2 — rather than as a
          // missing-exception message.
          try {
            await adapter.advanceBookmark(
              curriculumId: CurriculumId.mishnayos,
              completedSefariaRef: _ref1,
            );
          } on TutoredBookmarkWriteUnsupportedException {
            // Expected — pinned separately below.
          }

          expect(
            await tutorOwnSefariaRef(),
            _ref1,
            reason:
                "the tutor's own bookmark was silently overwritten by a "
                'write issued during a tutored session (it should still '
                'point at $_ref1)',
          );
        },
      );

      test('advanceBookmark throws '
          'TutoredBookmarkWriteUnsupportedException', () async {
        await expectLater(
          adapter.advanceBookmark(
            curriculumId: CurriculumId.mishnayos,
            completedSefariaRef: _ref1,
          ),
          throwsA(isA<TutoredBookmarkWriteUnsupportedException>()),
        );
      });

      test(
        "setBookmark never rewrites the TUTOR's own bookmark document",
        () async {
          try {
            await adapter.setBookmark(
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: _ref3,
            );
          } on TutoredBookmarkWriteUnsupportedException {
            // Expected.
          }

          expect(await tutorOwnSefariaRef(), _ref1);
        },
      );

      test('initializeBookmark throws '
          'TutoredBookmarkWriteUnsupportedException', () async {
        await expectLater(
          adapter.initializeBookmark(curriculumId: CurriculumId.mishnayos),
          throwsA(isA<TutoredBookmarkWriteUnsupportedException>()),
        );
      });

      test(
        "getBookmark returns null rather than the TUTOR's own bookmark",
        () async {
          final result = await adapter.getBookmark(
            curriculumId: CurriculumId.mishnayos,
          );

          expect(
            result,
            isNull,
            reason:
                "presenting the tutor's own reading position as the talmid's "
                'is the read-side twin of the write corruption',
          );
        },
      );
    });
  });
}
