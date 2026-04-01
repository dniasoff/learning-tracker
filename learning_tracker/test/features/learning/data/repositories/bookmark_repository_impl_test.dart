import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

class MockContentRepository extends Mock implements ContentRepository {}

const _ref1 = 'Mishnah Berachot 1:1';
const _ref2 = 'Mishnah Berachot 1:2';
const _ref3 = 'Mishnah Berachot 1:3';

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase database;
  late MockSyncEngine mockSyncEngine;
  late MockContentRepository mockContentRepository;
  late BookmarkRepositoryImpl repository;

  setUp(() async {
    database = createTestDatabase();
    mockSyncEngine = MockSyncEngine();
    mockContentRepository = MockContentRepository();

    repository = BookmarkRepositoryImpl(
      database: database,
      syncEngine: mockSyncEngine,
      contentRepository: mockContentRepository,
    );

    when(
      () => mockSyncEngine.pushBookmark(any()),
    ).thenAnswer((_) async => Future.value());

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
          trackType: TrackType.personal,
        );

        expect(bookmark.sefariaRef, _ref1);
        expect(bookmark.curriculumId, CurriculumId.mishnayos);
        expect(bookmark.trackType, TrackType.personal);
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
          trackType: TrackType.personal,
          sefariaRef: _ref1,
        );

        await repository.advanceBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
          completedSefariaRef: _ref1,
        );

        final updated = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        expect(updated?.sefariaRef, _ref2);
      },
    );

    test(
      'advanceBookmark follows custom learning order when one exists',
      () async {
        // Custom order: ref3, ref1, ref2
        await database.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: _ref3,
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: _ref1,
            userSortOrder: 1,
          ),
        );
        await database.learningOrderDao.insertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: _ref2,
            userSortOrder: 2,
          ),
        );

        // Start at ref3 (first in custom order)
        await repository.setBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
          sefariaRef: _ref3,
        );

        await repository.advanceBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
          completedSefariaRef: _ref3,
        );

        final updated = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        expect(updated?.sefariaRef, _ref1); // Next in custom order
      },
    );

    test('advanceBookmark keeps bookmark at last item (no overflow)', () async {
      await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
        sefariaRef: _ref3,
      );

      await repository.advanceBookmark(
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
        completedSefariaRef: _ref3,
      );

      final updated = await repository.getBookmark(
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
      );
      expect(updated?.sefariaRef, _ref3); // Unchanged — already at last item
    });
  });

  group('Manual bookmark operations', () {
    test('setBookmark updates sefariaRef and stores a UTC timestamp', () async {
      final before = DateTime.now().toUtc();

      final bookmark = await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
        sefariaRef: _ref2,
      );

      expect(bookmark.sefariaRef, _ref2);
      expect(bookmark.updatedAt.isUtc, isTrue);
      expect(bookmark.updatedAt.isAfter(before), isTrue);

      // No completions should be created
      final completions = await database.completionDao
          .getCompletionsByCurriculum(CurriculumId.mishnayos.storageKey);
      expect(completions, isEmpty);
    });
  });

  group('Firestore document ID', () {
    test('firestoreId follows {curriculumId}_{trackType} pattern', () async {
      final bookmark = await repository.setBookmark(
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
        sefariaRef: _ref1,
      );
      expect(bookmark.firestoreId, 'mishnayos_personal');

      final bookmark2 = await repository.setBookmark(
        curriculumId: CurriculumId.bavli,
        trackType: TrackType.school,
        sefariaRef: _ref1,
      );
      expect(bookmark2.firestoreId, 'bavli_school');
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
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: TrackType.personal.storageKey,
            sefariaRef: _ref1,
            updatedAt: localTime,
          ),
        );

        // Remote at ref2 — just now
        final remoteTime = DateTime.now().toUtc();
        await repository.mergeRemoteBookmark({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'track_type': TrackType.personal.storageKey,
          'content_item_id': _ref2,
          'updated_at': remoteTime.toIso8601String(),
        });

        final result = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
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
          trackType: TrackType.personal,
          sefariaRef: _ref2,
        );

        // Remote at ref3 — 1 hour old
        final olderRemoteTime = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );
        await repository.mergeRemoteBookmark({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'track_type': TrackType.personal.storageKey,
          'content_item_id': _ref3,
          'updated_at': olderRemoteTime.toIso8601String(),
        });

        final result = await repository.getBookmark(
          curriculumId: CurriculumId.mishnayos,
          trackType: TrackType.personal,
        );
        expect(result?.sefariaRef, _ref2); // Local won
      },
    );
  });
}
