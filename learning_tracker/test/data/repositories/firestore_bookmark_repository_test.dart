/// Unit tests for `lib/data/repositories/firestore_bookmark_repository.dart`
/// — the REFERENCE Firestore repository (Epic B). Covers: doc-id
/// correctness, model round-trip, the stream emitting on change, and the
/// advance/initialize natural-order paths. See the class doc comment's
/// "Known, deliberate gap" section for what [advanceBookmark]/
/// [initializeBookmark] deliberately do NOT cover (a custom `learning_order`
/// override — that repository does not exist yet).
///
/// **What these tests cannot see** (report this honestly, do not paper over
/// it): `fake_cloud_firestore`'s rules companion cannot evaluate
/// `resource.data`/`request.resource`, so the `bookmarks` rules'
/// `.hasOnly()` field whitelist and the `sefaria_ref`/`curriculum_id` size
/// caps are NOT exercised here — a permissive fake is used throughout
/// (`createFakeFirestore()` default, `strictRules: false`), matching
/// `test/helpers/firestore_fake.dart`'s own documented limitation. The
/// resubscribe-with-backoff behavior [watchBookmark] delegates to is
/// covered directly and exhaustively in
/// `test/data/firestore/resilient_doc_stream_test.dart` — `fake_cloud_firestore`
/// cannot be made to raise a stream-level error on demand, so a live
/// "listener actually errors and recovers" path is not (and cannot be)
/// exercised at this repository-integration layer.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_bookmark_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/firestore_fake.dart';
import '../../mocks/mock_repositories.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

ContentItem _leaf({
  required CurriculumId curriculumId,
  required String sefariaRef,
  required int sortOrder,
}) {
  return ContentItem(
    curriculumId: curriculumId.storageKey,
    level1: 'L1',
    displayNameHe: 'עברית',
    displayNameEn: 'English',
    sefariaRef: sefariaRef,
    sortOrder: sortOrder,
    isLeaf: true,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockContentRepository contentRepository;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    contentRepository = MockContentRepository();
  });

  DocumentReference<Map<String, dynamic>> rawDoc(CurriculumId curriculumId) =>
      firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('bookmarks')
          .doc(curriculumId.storageKey);

  FirestoreBookmarkRepository buildRepo({ContentIndex? contentIndex}) {
    return FirestoreBookmarkRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
      contentRepository: contentRepository,
      contentIndex: contentIndex,
    );
  }

  group('doc-id correctness', () {
    test(
      'setBookmark writes to users/{uid}/learner_profiles/{profileId}/'
      'bookmarks/{curriculumId} — the DocIds.bookmarkDocId formula',
      () async {
        final repo = buildRepo();

        await repo.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'Mishnah_Berakhot.1.1',
        );

        final expectedId = DocIds.bookmarkDocId({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
        });
        expect(expectedId, CurriculumId.mishnayos.storageKey);

        final snapshot = await rawDoc(CurriculumId.mishnayos).get();
        expect(snapshot.exists, isTrue);
      },
    );

    test('two different curricula land on two different documents', () async {
      final repo = buildRepo();

      await repo.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'ref-a',
      );
      await repo.setBookmark(
        curriculumId: CurriculumId.bavli,
        sefariaRef: 'ref-b',
      );

      final a = await repo.getBookmark(curriculumId: CurriculumId.mishnayos);
      final b = await repo.getBookmark(curriculumId: CurriculumId.bavli);
      expect(a!.sefariaRef, 'ref-a');
      expect(b!.sefariaRef, 'ref-b');
    });
  });

  group('model round-trip', () {
    test('getBookmark returns null when no document exists yet', () async {
      final repo = buildRepo();

      final result = await repo.getBookmark(curriculumId: CurriculumId.bavli);

      expect(result, isNull);
    });

    test('setBookmark then getBookmark round-trips curriculumId + '
        'sefariaRef', () async {
      final repo = buildRepo();

      final written = await repo.setBookmark(
        curriculumId: CurriculumId.chumash,
        sefariaRef: 'Genesis.1.1',
      );
      final read = await repo.getBookmark(curriculumId: CurriculumId.chumash);

      expect(read, isNotNull);
      expect(read!.curriculumId, CurriculumId.chumash);
      expect(read.sefariaRef, 'Genesis.1.1');
      expect(read.updatedAt, written.updatedAt);
    });

    test('setBookmark on an existing bookmark overwrites sefariaRef', () async {
      final repo = buildRepo();

      await repo.setBookmark(
        curriculumId: CurriculumId.chumash,
        sefariaRef: 'Genesis.1.1',
      );
      await repo.setBookmark(
        curriculumId: CurriculumId.chumash,
        sefariaRef: 'Genesis.1.2',
      );

      final read = await repo.getBookmark(curriculumId: CurriculumId.chumash);
      expect(read!.sefariaRef, 'Genesis.1.2');
    });

    test('setBookmark merges rather than replacing — a pre-existing field '
        'outside the client whitelist (e.g. a tutor-CF-stamped synced_at) '
        'survives a subsequent owner write', () async {
      final repo = buildRepo();
      await rawDoc(CurriculumId.chumash).set({
        'curriculum_id': CurriculumId.chumash.storageKey,
        'sefaria_ref': 'Genesis.1.1',
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'synced_at': 'server-stamped-value',
      });

      await repo.setBookmark(
        curriculumId: CurriculumId.chumash,
        sefariaRef: 'Genesis.1.2',
      );

      final snapshot = await rawDoc(CurriculumId.chumash).get();
      expect(snapshot.data()!['synced_at'], 'server-stamped-value');
      expect(snapshot.data()!['sefaria_ref'], 'Genesis.1.2');
    });
  });

  group('watchBookmark — stream emits on change', () {
    test(
      'emits null, then the created bookmark, then the updated one',
      () async {
        final repo = buildRepo();

        final events = <String?>[];
        final subscription = repo
            .watchBookmark(curriculumId: CurriculumId.nach)
            .listen((entity) => events.add(entity?.sefariaRef));
        addTearDown(subscription.cancel);

        await pumpEventQueue();
        await repo.setBookmark(
          curriculumId: CurriculumId.nach,
          sefariaRef: 'a',
        );
        await pumpEventQueue();
        await repo.setBookmark(
          curriculumId: CurriculumId.nach,
          sefariaRef: 'b',
        );
        await pumpEventQueue();

        expect(events, [null, 'a', 'b']);
      },
    );
  });

  group('initializeBookmark', () {
    test('points to the first leaf via ContentIndex when provided', () async {
      final index = ContentIndex.fromCurricula({
        CurriculumId.mishnayos: [
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'first',
            sortOrder: 1,
          ),
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'second',
            sortOrder: 2,
          ),
        ],
      });
      final repo = buildRepo(contentIndex: index);

      final result = await repo.initializeBookmark(
        curriculumId: CurriculumId.mishnayos,
      );

      expect(result.sefariaRef, 'first');
    });

    test(
      'falls back to ContentRepository (isLeaf, sorted) when no ContentIndex '
      'is provided',
      () async {
        when(
          () =>
              contentRepository.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _leaf(
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'second',
              sortOrder: 2,
            ),
            _leaf(
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'first',
              sortOrder: 1,
            ),
          ],
        );
        final repo = buildRepo();

        final result = await repo.initializeBookmark(
          curriculumId: CurriculumId.mishnayos,
        );

        expect(result.sefariaRef, 'first');
      },
    );

    test('throws StateError when there is no content at all', () async {
      final index = ContentIndex.fromCurricula(const {});
      final repo = buildRepo(contentIndex: index);

      expect(
        () => repo.initializeBookmark(curriculumId: CurriculumId.mishnayos),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('advanceBookmark', () {
    late ContentIndex index;

    setUp(() {
      index = ContentIndex.fromCurricula({
        CurriculumId.mishnayos: [
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'a',
            sortOrder: 1,
          ),
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'b',
            sortOrder: 2,
          ),
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'c',
            sortOrder: 3,
          ),
        ],
      });
    });

    test('creates a bookmark at the next item when none exists yet', () async {
      final repo = buildRepo(contentIndex: index);

      await repo.advanceBookmark(
        curriculumId: CurriculumId.mishnayos,
        completedSefariaRef: 'a',
      );

      final bookmark = await repo.getBookmark(
        curriculumId: CurriculumId.mishnayos,
      );
      expect(bookmark!.sefariaRef, 'b');
    });

    test(
      'advances when the bookmark currently sits on the completed item',
      () async {
        final repo = buildRepo(contentIndex: index);
        await repo.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'b',
        );

        await repo.advanceBookmark(
          curriculumId: CurriculumId.mishnayos,
          completedSefariaRef: 'b',
        );

        final bookmark = await repo.getBookmark(
          curriculumId: CurriculumId.mishnayos,
        );
        expect(bookmark!.sefariaRef, 'c');
      },
    );

    test('falls back to ContentRepository (isLeaf, sorted) when no '
        'ContentIndex is provided', () async {
      when(
        () => contentRepository.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => [
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'b',
            sortOrder: 2,
          ),
          _leaf(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'a',
            sortOrder: 1,
          ),
        ],
      );
      final repo = buildRepo();

      await repo.advanceBookmark(
        curriculumId: CurriculumId.mishnayos,
        completedSefariaRef: 'a',
      );

      final bookmark = await repo.getBookmark(
        curriculumId: CurriculumId.mishnayos,
      );
      expect(bookmark!.sefariaRef, 'b');
    });

    test('does nothing when the bookmark sits on a DIFFERENT item than the '
        'one just completed', () async {
      final repo = buildRepo(contentIndex: index);
      await repo.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'c',
      );

      await repo.advanceBookmark(
        curriculumId: CurriculumId.mishnayos,
        completedSefariaRef: 'a',
      );

      final bookmark = await repo.getBookmark(
        curriculumId: CurriculumId.mishnayos,
      );
      expect(bookmark!.sefariaRef, 'c');
    });

    test('does nothing when the completed item is the last one', () async {
      final repo = buildRepo(contentIndex: index);
      await repo.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: 'c',
      );

      await repo.advanceBookmark(
        curriculumId: CurriculumId.mishnayos,
        completedSefariaRef: 'c',
      );

      final bookmark = await repo.getBookmark(
        curriculumId: CurriculumId.mishnayos,
      );
      expect(bookmark!.sefariaRef, 'c');
    });
  });
}
