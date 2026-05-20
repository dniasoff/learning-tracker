import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/drift_memory.dart' show seedCompletion;
import '../../../../helpers/test_database.dart';

/// Counts SELECT statements that touch `completions_view`.
///
/// Used by the N+1 regression test to assert that
/// [CompletionDetectionService] no longer issues one query per leaf.
class _CompletionsViewQueryCounter extends QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('completions_view')) {
      count++;
    }
    return super.runSelect(executor, statement, args);
  }
}

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

class _MockContentRepository extends Mock implements ContentRepository {}

const _currId = 'mishnayos';

void main() {
  late UserDatabase db;
  late _MockFirestoreGateway mockGateway;
  late _MockContentRepository mockContentRepo;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    mockGateway = _MockFirestoreGateway();
    mockContentRepo = _MockContentRepository();
    when(
      () => mockGateway.pushLedgerEntry(
        profileId: any(named: 'profileId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: _currId,
            stateChangedAt: DateTime.now(),
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;
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
        profileId: 1,
        curriculumId: _currId,
        trackId: trackId,
        stageOrder: stageOrder,
        stageName: 'Stage $stageOrder',
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );
  }

  Future<void> insertCompletion(
    String sefariaRef,
    int stageId, {
    int profileId = 1,
    String trackType = 'personal',
  }) async {
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: _currId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        trackId: Value(trackId),
        eventTimestamp: DateTime.utc(2026, 3, 1),
      ),
    );
  }

  CompletionDetectionService createService() {
    final ledgerRepo = LearningLedgerRepositoryImpl(
      database: db,
      firestoreGateway: mockGateway,
      activeProfileId: 1,
      activeProfileMode: ProfileMode.adult,
    );
    final stageRepo = StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      pushSettings: null,
    );
    return CompletionDetectionService(
      database: db,
      contentRepository: mockContentRepo,
      ledgerRepository: ledgerRepo,
      stageRepository: stageRepo,
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
            (e) => e.entryScope == 'masechta' && e.unitIdentifier == 'Berakhot',
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

    test(
      'issues constant-bounded queries regardless of leaf count (N+1 regression)',
      () async {
        // 10 leaves all completed at stage 1.  The pre-fix code issued one
        // `getCompletionsForContentAndProfile` DAO call per leaf inside
        // `_checkUnitCompletion` (so 10× per scope, 20× total once
        // masechta + seder scopes are both checked).  After the fix, each
        // scope issues a single `getCompletionsByCurriculumAndProfile`
        // bulk query — total queries against `completions_view` from the
        // detection service should stay ≤ 2 no matter how many leaves
        // exist.
        const leafCount = 10;
        final leaves = createLeafItems('Zeraim', 'Berakhot', leafCount);

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

        // Re-open the database with a query-counting interceptor wrapped
        // around the live in-memory executor.  We close the setUp-created
        // db first so the new instance owns the only handle for the rest
        // of the test.
        await db.close();
        final counter = _CompletionsViewQueryCounter();
        db = UserDatabase(NativeDatabase.memory().interceptWith(counter));
        await seedProfile(db);
        final trackRow = await db
            .into(db.curriculumTracks)
            .insertReturning(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: _currId,
                stateChangedAt: DateTime.now(),
                activatedAt: DateTime.now(),
              ),
            );
        trackId = trackRow.id;
        await insertStage(1);
        for (final leaf in leaves) {
          await insertCompletion(leaf.sefariaRef, 1);
        }

        // Reset the counter so we only measure queries issued by the
        // detection service itself, not the setUp seed inserts.
        counter.count = 0;

        final service = createService();
        await service.checkAndRecordCompletions(
          curriculumId: _currId,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
          profileId: 1,
          markedBy: 1,
        );

        // The detection service calls `_checkUnitCompletion` twice
        // (masechta + seder).  Each call now issues exactly one bulk
        // `completions_view` query — so ≤ 2 total.  Any regression that
        // brings back the per-leaf loop would push this to 20 (10× per
        // scope) or more.
        expect(
          counter.count,
          lessThanOrEqualTo(2),
          reason:
              'Expected ≤ 2 completions_view SELECTs (one per unit-completion '
              'check), got ${counter.count}.  This likely means a per-leaf '
              'loop has been reintroduced.',
        );

        // Sanity check: a siyum ledger row was actually produced.
        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(
          entries.any(
            (e) => e.entryScope == 'masechta' && e.unitIdentifier == 'Berakhot',
          ),
          isTrue,
          reason: 'Expected a masechta-level siyum ledger entry.',
        );
      },
    );

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
