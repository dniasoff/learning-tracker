import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockContentRepository extends Mock implements ContentRepository {}

const _currId = 'mishnayos';

void main() {
  late AppDatabase db;
  late _MockSyncEngine mockSyncEngine;
  late _MockContentRepository mockContentRepo;

  setUp(() {
    db = createTestDatabase();
    mockSyncEngine = _MockSyncEngine();
    mockContentRepo = _MockContentRepository();
    when(() => mockSyncEngine.pushLedgerEntry(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  List<ContentItem> createLeafItems(String seder, String masechta, int count) {
    return List.generate(
      count,
      (i) => ContentItem(
        curriculumId: _currId,
        level1: seder,
        level2: masechta,
        level3: 'Perek ${i + 1}',
        displayNameHe: 'משנה ${i + 1}',
        displayNameEn: 'Mishna ${i + 1}',
        sefariaRef: 'Mishnah_${masechta}_${i + 1}',
        sortOrder: i,
        isLeaf: true,
      ),
    );
  }

  Future<void> insertStage(int stageOrder) async {
    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        curriculumId: _currId,
        stageOrder: stageOrder,
        stageName: 'Stage $stageOrder',
        delayDays: 0,
      ),
    );
  }

  Future<void> insertCompletion(
    String sefariaRef,
    int stageId, {
    int profileId = 1,
    String trackType = 'personal',
  }) async {
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        profileId: Value(profileId),
        curriculumId: _currId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        completedAt: DateTime.utc(2026, 3, 1),
      ),
    );
  }

  CompletionDetectionService createService() {
    final ledgerRepo = LearningLedgerRepositoryImpl(
      database: db,
      syncEngine: mockSyncEngine,
      activeProfileId: 1,
      activeProfileMode: 'adult',
    );
    return CompletionDetectionService(
      database: db,
      contentRepository: mockContentRepo,
      ledgerRepository: ledgerRepo,
    );
  }

  group('CompletionDetectionService', () {
    test(
      'creates ledger entry when all leaves complete for masechta',
      () async {
        final leaves = createLeafItems('Zeraim', 'Berakhot', 2);

        when(
          () => mockContentRepo.getContentByRef(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => leaves.first);

        when(
          () => mockContentRepo.filterByLevel(
            curriculumId: CurriculumId.mishnayos,
            level1: 'Zeraim',
            level2: 'Berakhot',
          ),
        ).thenAnswer((_) async => leaves);

        when(
          () => mockContentRepo.filterByLevel(
            curriculumId: CurriculumId.mishnayos,
            level1: 'Zeraim',
            level2: null,
          ),
        ).thenAnswer((_) async => leaves);

        await insertStage(1);

        for (final leaf in leaves) {
          await insertCompletion(leaf.sefariaRef, 1);
        }

        final service = createService();
        await service.checkAndRecordCompletions(
          curriculumId: _currId,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
          profileId: 1,
          markedBy: 1,
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries.length, greaterThanOrEqualTo(1));
        expect(
          entries.any(
            (e) => e.unitType == 'masechta' && e.unitIdentifier == 'Berakhot',
          ),
          isTrue,
        );
      },
    );

    test('does NOT create entry when some leaves are incomplete', () async {
      final leaves = createLeafItems('Zeraim', 'Berakhot', 3);

      when(
        () => mockContentRepo.getContentByRef(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => leaves.first);

      when(
        () => mockContentRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Zeraim',
          level2: 'Berakhot',
        ),
      ).thenAnswer((_) async => leaves);

      when(
        () => mockContentRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Zeraim',
          level2: null,
        ),
      ).thenAnswer((_) async => leaves);

      await insertStage(1);

      // Only 2 of 3 leaves complete
      await insertCompletion(leaves[0].sefariaRef, 1);
      await insertCompletion(leaves[1].sefariaRef, 1);

      final service = createService();
      await service.checkAndRecordCompletions(
        curriculumId: _currId,
        sefariaRef: leaves.first.sefariaRef,
        trackType: 'personal',
        profileId: 1,
        markedBy: 1,
      );

      final entries = await db.learningLedgerDao.getEntriesByProfile(1);
      expect(entries, isEmpty);
    });

    test('does NOT create entry when not all stages complete', () async {
      final leaves = createLeafItems('Zeraim', 'Berakhot', 2);

      when(
        () => mockContentRepo.getContentByRef(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => leaves.first);

      when(
        () => mockContentRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Zeraim',
          level2: 'Berakhot',
        ),
      ).thenAnswer((_) async => leaves);

      when(
        () => mockContentRepo.filterByLevel(
          curriculumId: CurriculumId.mishnayos,
          level1: 'Zeraim',
          level2: null,
        ),
      ).thenAnswer((_) async => leaves);

      await insertStage(1);
      await insertStage(2);

      // All leaves for stage 1 only
      for (final leaf in leaves) {
        await insertCompletion(leaf.sefariaRef, 1);
      }

      final service = createService();
      await service.checkAndRecordCompletions(
        curriculumId: _currId,
        sefariaRef: leaves.first.sefariaRef,
        trackType: 'personal',
        profileId: 1,
        markedBy: 1,
      );

      final entries = await db.learningLedgerDao.getEntriesByProfile(1);
      expect(entries, isEmpty);
    });
  });
}
