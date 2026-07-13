import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/drift_memory.dart';
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

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

class _MockContentRepository extends Mock implements ContentRepository {}

const _currId = 'mishnayos';

void main() {
  late UserDatabase db;
  late _MockOutboxFacade mockOutboxFacade;
  late _MockContentRepository mockContentRepo;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    mockOutboxFacade = _MockOutboxFacade();
    mockContentRepo = _MockContentRepository();
    when(
      () => mockOutboxFacade.enqueueLedgerEntry(any()),
    ).thenAnswer((_) async {});
    // AUD-learning-03: the ledger repo now requests a post-commit drain
    // (write-tee) instead of enqueueing through the facade directly.
    when(() => mockOutboxFacade.requestSyncDrain()).thenAnswer((_) async {});

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
      outboxFacade: mockOutboxFacade,
      activeProfileId: 1,
      activeProfileMode: ProfileMode.adult,
    );
    final stageRepo = StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      pushStageDefinitions: null,
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

    test(
      'fires siyum on limud (stage 1) completion alone — chazara not required',
      () async {
        // Regression for: bulk-mark on a chazara-enabled track must still
        // produce siyum entries. Previously the detection service required
        // every stage to be complete; that silently zeroed out siyumim for
        // anyone who bulk-marked an entire masechta during onboarding on
        // a multi-stage (limud + chazara) track. Per docs/hebrew-terms.md
        // §6, siyum = "completing a unit of learning" — chazara is review
        // of already-siyumed material and does NOT gate the siyum.
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

        // All leaves for stage 1 only — stage 2 (chazara) untouched.
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
        expect(
          entries.any(
            (e) => e.entryScope == 'masechta' && e.unitIdentifier == 'Berakhot',
          ),
          isTrue,
          reason:
              'A unit-level siyum must fire when every leaf has a limud '
              '(stage 1) completion, even on a track with chazara stages.',
        );
      },
    );

    test(
      'does NOT fire siyum when some leaves are missing limud completion',
      () async {
        // Sanity: siyum still requires every leaf's limud — partial limud
        // coverage must not fire.
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

        // Only 2 of 3 leaves have limud completion.
        await insertCompletion(leaves[0].sefariaRef, 1);
        await insertCompletion(leaves[1].sefariaRef, 1);

        final service = createService();
        await service.checkAndRecordCompletions(
          curriculumId: _currId,
          sefariaRef: leaves[0].sefariaRef,
          trackType: 'personal',
          profileId: 1,
          markedBy: 1,
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries, isEmpty);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // F2 (W7-A) — Per-curriculum entry-scope strings
  //
  // The detection service must emit curriculum-specific scope strings:
  //   level 2 → 'masechta' (Mishnayos/Bavli/Yerushalmi)
  //          → 'siman'    (Mishna Berurah)
  //          → 'hilchos'  (Mishneh Torah)
  //   level 1 → 'seder'   (Mishnayos/Bavli/Yerushalmi)
  //          → 'chelek'   (Mishna Berurah)
  //          → 'sefer'    (Chumash/Nach/Tanach/Mussar/Mishneh Torah books)
  //
  // The whitelist in journey_providers.dart:_detectMilestones treats the
  // level-2 scopes as unit-level. Without curriculum-aware strings, Chumash
  // (which only has level-1 leaves) and Mishna Berurah (which uses 'siman'
  // not 'masechta') silently never produce unit-level siyumim.
  // ──────────────────────────────────────────────────────────────────────────

  group('F2 — per-curriculum entry-scope strings', () {
    test(
      'Chumash level-1-only curriculum writes scope=sefer at level 1',
      () async {
        // Override setUp scaffolding: the global setUp seeded a Mishnayos
        // track row; for Chumash we need the track row to point at
        // 'chumash'. Replace the track id with a fresh Chumash track.
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: CurriculumId.chumash.storageKey,
                stateChangedAt: DateTime.now(),
                activatedAt: DateTime.now(),
              ),
            );

        // Chumash content: one sefer, two leaves. Crucially, level2 is null
        // — only level-1 detection fires.
        final leaves = <ContentItem>[
          const ContentItem(
            curriculumId: 'chumash',
            level1: 'Bereshit',
            displayNameHe: 'בראשית',
            displayNameEn: 'Bereshit',
            sefariaRef: 'Genesis_1_1',
            sortOrder: 0,
            isLeaf: true,
          ),
          const ContentItem(
            curriculumId: 'chumash',
            level1: 'Bereshit',
            displayNameHe: 'בראשית',
            displayNameEn: 'Bereshit',
            sefariaRef: 'Genesis_1_2',
            sortOrder: 1,
            isLeaf: true,
          ),
        ];

        when(
          () => mockContentRepo.getContentByRef(
            curriculumId: CurriculumId.chumash,
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => leaves.first);

        when(
          () => mockContentRepo.filterByLevel(
            curriculumId: CurriculumId.chumash,
            level1: 'Bereshit',
            level2: null,
          ),
        ).thenAnswer((_) async => leaves);

        // Seed stage definition for Chumash so the service finds it.
        await db.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.chumash.storageKey,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'Learn',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );

        for (final leaf in leaves) {
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.chumash.storageKey,
              sefariaRef: leaf.sefariaRef,
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: DateTime.utc(2026, 3, 1),
            ),
          );
        }

        final service = createService();
        await service.checkAndRecordCompletions(
          curriculumId: CurriculumId.chumash.storageKey,
          sefariaRef: leaves.first.sefariaRef,
          trackType: 'personal',
          profileId: 1,
          markedBy: 1,
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(
          entries
              .where(
                (e) =>
                    e.curriculumId == 'chumash' &&
                    e.entryScope == 'sefer' &&
                    e.unitIdentifier == 'Bereshit',
              )
              .toList(),
          hasLength(1),
          reason:
              'F2: Chumash level-1 detection must write entryScope=sefer so '
              'the journey provider whitelist recognises it as a unit siyum. '
              'Pre-fix, this row had entryScope=seder and was silently ignored.',
        );
      },
    );

    test('Mishna Berurah level-2 detection writes scope=siman', () async {
      // Track row for mishna_berurah.
      final mbTrack = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: CurriculumId.mishnaBerurah.storageKey,
              stateChangedAt: DateTime.now(),
              activatedAt: DateTime.now(),
            ),
          );

      // Mishna Berurah content: chelek 1 → siman 1 → 2 leaves.
      final leaves = <ContentItem>[
        const ContentItem(
          curriculumId: 'mishna_berurah',
          level1: 'Chelek 1',
          level2: 'Siman 1',
          displayNameHe: 'סעיף א',
          displayNameEn: 'Seif 1',
          sefariaRef: 'MB_1_1_1',
          sortOrder: 0,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishna_berurah',
          level1: 'Chelek 1',
          level2: 'Siman 1',
          displayNameHe: 'סעיף ב',
          displayNameEn: 'Seif 2',
          sefariaRef: 'MB_1_1_2',
          sortOrder: 1,
          isLeaf: true,
        ),
      ];

      when(
        () => mockContentRepo.getContentByRef(
          curriculumId: CurriculumId.mishnaBerurah,
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => leaves.first);

      when(
        () => mockContentRepo.filterByLevel(
          curriculumId: CurriculumId.mishnaBerurah,
          level1: 'Chelek 1',
          level2: 'Siman 1',
        ),
      ).thenAnswer((_) async => leaves);

      when(
        () => mockContentRepo.filterByLevel(
          curriculumId: CurriculumId.mishnaBerurah,
          level1: 'Chelek 1',
          level2: null,
        ),
      ).thenAnswer((_) async => leaves);

      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnaBerurah.storageKey,
          trackId: mbTrack.id,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );

      for (final leaf in leaves) {
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnaBerurah.storageKey,
            sefariaRef: leaf.sefariaRef,
            stageId: 1,
            trackType: 'personal',
            trackId: Value(mbTrack.id),
            eventTimestamp: DateTime.utc(2026, 3, 1),
          ),
        );
      }

      final service = createService();
      await service.checkAndRecordCompletions(
        curriculumId: CurriculumId.mishnaBerurah.storageKey,
        sefariaRef: leaves.first.sefariaRef,
        trackType: 'personal',
        profileId: 1,
        markedBy: 1,
      );

      final entries = await db.learningLedgerDao.getEntriesByProfile(1);
      // Level-2 row: scope=siman (NOT 'masechta', which would silently fall
      // outside the journey whitelist).
      expect(
        entries
            .where(
              (e) =>
                  e.curriculumId == 'mishna_berurah' &&
                  e.entryScope == 'siman' &&
                  e.unitIdentifier == 'Siman 1',
            )
            .toList(),
        hasLength(1),
        reason:
            'F2: Mishna Berurah level-2 must write entryScope=siman, not '
            '"masechta". Pre-fix this row used the hardcoded "masechta" '
            "string and the journey provider's siman whitelist still "
            'matched it by accident — but the curriculum-level scope was '
            'wrong, breaking the redesign brief.',
      );
      // Level-1 row: scope=chelek (NOT 'seder' — that was the hardcoded
      // bug).
      expect(
        entries
            .where(
              (e) =>
                  e.curriculumId == 'mishna_berurah' &&
                  e.entryScope == 'chelek' &&
                  e.unitIdentifier == 'Chelek 1',
            )
            .toList(),
        hasLength(1),
        reason:
            'F2: Mishna Berurah level-1 must write entryScope=chelek, not '
            'seder. A chelek covers all simanim within it (in this test '
            'the only siman is complete, so the chelek also fires).',
      );
    });

    // Pure unit tests on the helper — no DB needed.
    group('unitScopeFor helper', () {
      test('level 2', () {
        expect(unitScopeFor(CurriculumId.mishnayos, level: 2), 'masechta');
        expect(unitScopeFor(CurriculumId.bavli, level: 2), 'masechta');
        expect(unitScopeFor(CurriculumId.yerushalmi, level: 2), 'masechta');
        expect(unitScopeFor(CurriculumId.mishnaBerurah, level: 2), 'siman');
        expect(unitScopeFor(CurriculumId.mishnehTorah, level: 2), 'hilchos');
      });

      test('level 1', () {
        expect(unitScopeFor(CurriculumId.mishnayos, level: 1), 'seder');
        expect(unitScopeFor(CurriculumId.bavli, level: 1), 'seder');
        expect(unitScopeFor(CurriculumId.yerushalmi, level: 1), 'seder');
        expect(unitScopeFor(CurriculumId.mishnaBerurah, level: 1), 'chelek');
        expect(unitScopeFor(CurriculumId.chumash, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.nach, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.tanach, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.mussar, level: 1), 'sefer');
        expect(unitScopeFor(CurriculumId.mishnehTorah, level: 1), 'sefer');
      });
    });
  });
}
