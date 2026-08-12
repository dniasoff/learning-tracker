import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_bookmark_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_order_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

const _uid = 'bookmark-uid';
const _profileId = 'bookmark-profile-ulid';
const _ref1 = 'Mishnah Berachot 1:1';
const _ref2 = 'Mishnah Berachot 1:2';
const _ref3 = 'Mishnah Berachot 1:3';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late FakeFirebaseFirestore firestore;
  late MockContentRepository contentRepository;
  late FirestoreLearningOrderRepository learningOrderRepository;
  late FirestoreBookmarkRepository repository;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    contentRepository = MockContentRepository();
    learningOrderRepository = FirestoreLearningOrderRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    repository = FirestoreBookmarkRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
      contentRepository: contentRepository,
      learningOrderRepository: learningOrderRepository,
    );

    when(() => contentRepository.getContentForCurriculum(any())).thenAnswer(
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

  group('Bookmark creation and initialization', () {
    test('initializeBookmark uses the first item in sort order', () async {
      final bookmark = await repository.initializeBookmark(
        curriculumId: CurriculumId.mishnayos,
      );

      expect(bookmark.sefariaRef, _ref1);
      expect(bookmark.curriculumId, CurriculumId.mishnayos);
      expect(bookmark.updatedAt.isUtc, isTrue);
    });
  });

  group('Bookmark advancement', () {
    test('advanceBookmark moves to the next item in sort order', () async {
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
    });

    test('advanceBookmark follows a saved custom learning order', () async {
      await learningOrderRepository.saveOrder(CurriculumId.mishnayos, [
        const LearningOrderItem(
          sefariaRef: _ref3,
          displayNameHe: '',
          displayNameEn: 'B 1:3',
          userSortOrder: 0,
        ),
        const LearningOrderItem(
          sefariaRef: _ref1,
          displayNameHe: '',
          displayNameEn: 'B 1:1',
          userSortOrder: 1,
        ),
        const LearningOrderItem(
          sefariaRef: _ref2,
          displayNameHe: '',
          displayNameEn: 'B 1:2',
          userSortOrder: 2,
        ),
      ]);
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
      expect(updated?.sefariaRef, _ref1);
    });

    test('advanceBookmark keeps the bookmark at the last item', () async {
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
      expect(updated?.sefariaRef, _ref3);
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

      final completions = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('completions')
          .get();
      expect(completions.docs, isEmpty);
    });
  });

  group('Firestore document ID', () {
    test('firestoreId is the curriculum storage key', () async {
      final bookmark = await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: _ref1,
      );
      final bookmark2 = await repository.setBookmark(
        curriculumId: CurriculumId.bavli,
        sefariaRef: _ref1,
      );

      expect(bookmark.firestoreId, 'mishnayos');
      expect(bookmark2.firestoreId, 'bavli');
    });
  });

  group('Conflict resolution', () {
    test(
      'remote newer bookmark wins',
      () async {},
      skip:
          'The landed Firestore bookmark repository has no mergeRemoteBookmark '
          'API; this Drift sync-conflict mechanic has no equivalent to test.',
    );
    test(
      'local newer bookmark wins',
      () async {},
      skip:
          'The landed Firestore bookmark repository has no mergeRemoteBookmark '
          'API; this Drift sync-conflict mechanic has no equivalent to test.',
    );
  });

  group('FirestoreBookmarkRepositoryAdapter', () {
    AccountFirebaseHandles handles(FakeFirebaseFirestore fake) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: fake,
        auth: MockFirebaseAuthHandle(),
        uid: _uid,
      );
    }

    FirestoreBookmarkRepositoryAdapter buildAdapter(
      ProviderContainer providerContainer,
      ContentRepository content, {
      ContentIndex? contentIndex,
    }) {
      final adapterProvider = Provider<FirestoreBookmarkRepositoryAdapter>(
        (ref) => FirestoreBookmarkRepositoryAdapter(
          ref: ref,
          contentRepository: content,
          contentIndex: contentIndex,
        ),
      );
      return providerContainer.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      test('getBookmark returns null instead of throwing', () async {
        final providerContainer = ProviderContainer();
        addTearDown(providerContainer.dispose);
        final adapter = buildAdapter(providerContainer, contentRepository);

        expect(
          await adapter.getBookmark(curriculumId: CurriculumId.mishnayos),
          isNull,
        );
      });

      test('setBookmark throws BookmarkRepositoryNotReadyException', () async {
        final providerContainer = ProviderContainer();
        addTearDown(providerContainer.dispose);
        final adapter = buildAdapter(providerContainer, contentRepository);

        expect(
          () => adapter.setBookmark(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: _ref1,
          ),
          throwsA(isA<BookmarkRepositoryNotReadyException>()),
        );
      });

      test('initializeBookmark throws when not ready', () async {
        final providerContainer = ProviderContainer();
        addTearDown(providerContainer.dispose);
        final adapter = buildAdapter(providerContainer, contentRepository);

        expect(
          () =>
              adapter.initializeBookmark(curriculumId: CurriculumId.mishnayos),
          throwsA(isA<BookmarkRepositoryNotReadyException>()),
        );
      });

      test('advanceBookmark throws when not ready', () async {
        final providerContainer = ProviderContainer();
        addTearDown(providerContainer.dispose);
        final adapter = buildAdapter(providerContainer, contentRepository);

        expect(
          () => adapter.advanceBookmark(
            curriculumId: CurriculumId.mishnayos,
            completedSefariaRef: _ref1,
          ),
          throwsA(isA<BookmarkRepositoryNotReadyException>()),
        );
      });
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore readyFirestore;
      late ProviderContainer providerContainer;
      late FirestoreBookmarkRepositoryAdapter adapter;

      setUp(() {
        readyFirestore = createFakeFirestore(authenticatedUid: _uid);
        providerContainer = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(readyFirestore),
            ),
          ],
        );
        providerContainer
            .read(activeProfileDocIdProvider.notifier)
            .set(_profileId);
        adapter = buildAdapter(providerContainer, contentRepository);
      });

      tearDown(() => providerContainer.dispose());

      test(
        'initializeBookmark writes a reachable Firestore document',
        () async {
          final bookmark = await adapter.initializeBookmark(
            curriculumId: CurriculumId.mishnayos,
          );
          expect(bookmark.sefariaRef, _ref1);

          final doc = await readyFirestore
              .collection('users')
              .doc(_uid)
              .collection('learner_profiles')
              .doc(_profileId)
              .collection('bookmarks')
              .doc('mishnayos')
              .get();
          expect(doc.exists, isTrue);
        },
      );

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

      test('advanceBookmark moves to the next content item', () async {
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

      test('initializeBookmark uses the injected ContentIndex', () async {
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
          providerContainer,
          contentRepository,
          contentIndex: contentIndex,
        );

        final bookmark = await indexedAdapter.initializeBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(bookmark.sefariaRef, _ref1);
        verifyNever(() => contentRepository.getContentForCurriculum(any()));
      });
    });

    group('tutored session (tutor acting inside a talmid context)', () {
      late FakeFirebaseFirestore tutorFirestore;
      late ProviderContainer providerContainer;
      late FirestoreBookmarkRepositoryAdapter adapter;

      Future<Object?> tutorOwnSefariaRef() async {
        final snapshot = await tutorFirestore
            .collection('users')
            .doc(_uid)
            .collection('learner_profiles')
            .doc(_profileId)
            .collection('bookmarks')
            .doc('mishnayos')
            .get();
        return snapshot.data()?['sefaria_ref'];
      }

      setUp(() async {
        tutorFirestore = createFakeFirestore(authenticatedUid: _uid);
        providerContainer = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(tutorFirestore),
            ),
          ],
        );
        providerContainer
            .read(activeProfileDocIdProvider.notifier)
            .set(_profileId);
        adapter = buildAdapter(providerContainer, contentRepository);
        await adapter.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: _ref1,
        );
        providerContainer
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(
              const TutoredProfileSelection(
                profileId: 'talmid-profile-ulid',
                ownerUid: 'parent-uid',
                grantId: 'grant-1',
                permissions: TutorPermissions(),
              ),
            );
      });

      tearDown(() => providerContainer.dispose());

      test('tutored writes never rewrite the tutor bookmark', () async {
        try {
          await adapter.advanceBookmark(
            curriculumId: CurriculumId.mishnayos,
            completedSefariaRef: _ref1,
          );
        } on BookmarkRepositoryNotReadyException {
          // Expected refusal.
        }
        expect(await tutorOwnSefariaRef(), _ref1);
      });

      test('tutored advanceBookmark throws not-ready', () async {
        await expectLater(
          adapter.advanceBookmark(
            curriculumId: CurriculumId.mishnayos,
            completedSefariaRef: _ref1,
          ),
          throwsA(isA<BookmarkRepositoryNotReadyException>()),
        );
      });

      test('tutored setBookmark never rewrites the tutor bookmark', () async {
        try {
          await adapter.setBookmark(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: _ref3,
          );
        } on BookmarkRepositoryNotReadyException {
          // Expected refusal.
        }
        expect(await tutorOwnSefariaRef(), _ref1);
      });

      test('tutored initializeBookmark throws not-ready', () async {
        await expectLater(
          adapter.initializeBookmark(curriculumId: CurriculumId.mishnayos),
          throwsA(isA<BookmarkRepositoryNotReadyException>()),
        );
      });

      test('tutored getBookmark returns null', () async {
        expect(
          await adapter.getBookmark(curriculumId: CurriculumId.mishnayos),
          isNull,
        );
      });
    });
  });
}
