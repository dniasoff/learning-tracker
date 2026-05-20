import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../../../../helpers/drift_memory.dart' as db_helper;

void main() {
  group('lifetimeDataProvider', () {
    test('is a family provider keyed by profileId and curriculumId', () {
      // Verify provider identity: calling with different args gives different
      // provider instances.
      const arg1 = (profileId: 1, curriculumId: CurriculumId.mishnayos);
      const arg2 = (profileId: 1, curriculumId: CurriculumId.bavli);
      const arg3 = (profileId: 2, curriculumId: CurriculumId.mishnayos);

      final p1 = lifetimeDataProvider(arg1);
      final p2 = lifetimeDataProvider(arg2);
      final p3 = lifetimeDataProvider(arg3);

      // Different curriculum → different provider.
      expect(p1, isNot(equals(p2)));
      // Different profileId → different provider.
      expect(p1, isNot(equals(p3)));
      // Same args → same provider.
      expect(lifetimeDataProvider(arg1), equals(p1));
    });

    test('all nine CurriculumId values can be used as family args', () {
      // Smoke-test that every curriculum resolves to a distinct provider so
      // the family covers the full set without runtime errors.
      final providers = CurriculumId.values
          .map((c) => lifetimeDataProvider((profileId: 1, curriculumId: c)))
          .toList();

      expect(providers.length, CurriculumId.values.length);
      // All provider instances must be distinct (they are auto-dispose family).
      final unique = providers.toSet();
      expect(unique.length, providers.length);
    });
  });

  group('lifetimeSummariesProvider', () {
    test('is a family provider keyed by profileId', () {
      final p1 = lifetimeSummariesProvider(1);
      final p2 = lifetimeSummariesProvider(2);

      expect(p1, isNot(equals(p2)));
      expect(lifetimeSummariesProvider(1), equals(p1));
    });

    test(
      'overrides return expected summaries without hitting database',
      () async {
        const fakeSummary = CurriculumLifetimeSummary(
          curriculumId: CurriculumId.mishnayos,
          learnedLeafCount: 10,
          totalLeafCount: 100,
          percentage: 0.1,
          tree: [],
        );

        final container = ProviderContainer(
          overrides: [
            lifetimeSummariesProvider(
              42,
            ).overrideWith((ref) => Future.value([fakeSummary])),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          lifetimeSummariesProvider(42).future,
        );

        expect(result, hasLength(1));
        expect(result.first.curriculumId, CurriculumId.mishnayos);
        expect(result.first.learnedLeafCount, 10);
        expect(result.first.percentage, 0.1);
      },
    );
  });

  group('lifetimeDataProvider override', () {
    test('single-curriculum override returns only that curriculum', () async {
      final container = ProviderContainer(
        overrides: [
          lifetimeDataProvider((
            profileId: 1,
            curriculumId: CurriculumId.chumash,
          )).overrideWith(
            (ref) => Future.value(
              const CurriculumLifetimeSummary(
                curriculumId: CurriculumId.chumash,
                learnedLeafCount: 5,
                totalLeafCount: 50,
                percentage: 0.1,
                tree: [],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        lifetimeDataProvider((
          profileId: 1,
          curriculumId: CurriculumId.chumash,
        )).future,
      );

      expect(result, isNotNull);
      expect(result!.curriculumId, CurriculumId.chumash);
      expect(result.learnedLeafCount, 5);
    });

    test('null result represents missing curriculum asset', () async {
      final container = ProviderContainer(
        overrides: [
          lifetimeDataProvider((
            profileId: 1,
            curriculumId: CurriculumId.yerushalmi,
          )).overrideWith((ref) => Future.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        lifetimeDataProvider((
          profileId: 1,
          curriculumId: CurriculumId.yerushalmi,
        )).future,
      );

      expect(result, isNull);
    });
  });

  group('CurriculumLifetimeSummary', () {
    test('percentage clamping semantics', () {
      const summary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mussar,
        learnedLeafCount: 0,
        totalLeafCount: 10,
        percentage: 0.0,
        tree: [],
      );

      expect(summary.percentage, 0.0);
      expect(summary.learnedLeafCount, 0);
      expect(summary.totalLeafCount, 10);
    });

    test('full completion percentage', () {
      const summary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mishnehTorah,
        learnedLeafCount: 200,
        totalLeafCount: 200,
        percentage: 1.0,
        tree: [],
      );

      expect(summary.percentage, 1.0);
    });
  });

  group('LifetimeTotals', () {
    test('percentage returns ratio', () {
      const totals = LifetimeTotals(
        learnedSections: 25,
        totalSections: 100,
        totalCurricula: 9,
      );

      expect(totals.percentage, closeTo(0.25, 0.001));
    });

    test('percentage is 0 when totalSections is 0', () {
      const totals = LifetimeTotals(
        learnedSections: 0,
        totalSections: 0,
        totalCurricula: 9,
      );

      expect(totals.percentage, 0.0);
    });
  });

  group('globalLifetimeCurriculaProvider alias', () {
    test('is the same provider object as lifetimeSummariesProvider', () {
      // The deprecated alias must forward to the same underlying family.
      // ignore: deprecated_member_use
      final aliasP = globalLifetimeCurriculaProvider(1);
      final newP = lifetimeSummariesProvider(1);

      expect(aliasP, equals(newP));
    });
  });

  // ---------------------------------------------------------------------------
  // B9 regression guard — per-curriculum deduplication
  //
  // After the v22 schema change the same sefariaRef can have a
  // completion_events row under MULTIPLE curriculumIds (e.g. 'mishnayos' AND
  // 'bavli'). The DAO query getCompletionsByCurriculumAndProfile is scoped per
  // curriculum, so each CurriculumLifetimeSummary independently lists that ref
  // in its learnedLeafRefs. lifetimeTotalsAcrossAllCurriculaProvider must union
  // those sets — not sum their lengths — so the ref is counted ONCE.
  // ---------------------------------------------------------------------------

  group('B9 regression — per-curriculum completions do not double-count', () {
    // ── DAO-level: verify the raw DB produces two rows for the same sefariaRef
    // under different curricula, and that a Set-union deduplicates them. ──────

    late UserDatabase db;

    setUp(() async {
      db = db_helper.inMemoryDb();
      await db_helper.seedProfile(db); // inserts profileId = 1
    });

    tearDown(() => db.close());

    test('DAO: same sefariaRef under two curricula produces two completion_events '
        'rows but deduplicates to ONE distinct ref in a Set-union', () async {
      const profileId = 1;
      const sharedRef = 'Berakhot 1a';
      final ts = DateTime.utc(2026, 5, 19, 10);

      // Insert completion for sharedRef under mishnayos.
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: sharedRef,
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: ts,
        ),
      );

      // Insert completion for the SAME sharedRef under bavli.
      // Different curriculumId → different row (unique key includes curriculumId).
      await db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: CurriculumId.bavli.storageKey,
          sefariaRef: sharedRef,
          stageId: 1,
          trackType: 'personal',
          eventTimestamp: ts,
          // Use a distinct trackId so the event differs if needed.
          trackId: Value(const Value<int?>(null)),
        ),
      );

      // Two rows exist — one per curriculum.
      final allRows = await db.select(db.completionEvents).get();
      expect(
        allRows,
        hasLength(2),
        reason:
            'Two distinct rows must exist — one per curriculum for the same sefariaRef',
      );

      // ── Simulate what lifetimeTotalsAcrossAllCurriculaProvider does ────────
      //   Each curriculum's provider queries per-curriculum, yielding a Set of
      //   sefariaRefs. The totals provider unions those sets.
      final mishCompletions = await db.completionDao
          .getCompletionsByCurriculumAndProfile(
            CurriculumId.mishnayos.storageKey,
            profileId,
          );
      final bavliCompletions = await db.completionDao
          .getCompletionsByCurriculumAndProfile(
            CurriculumId.bavli.storageKey,
            profileId,
          );

      final mishRefs = mishCompletions.map((c) => c.sefariaRef).toSet();
      final bavliRefs = bavliCompletions.map((c) => c.sefariaRef).toSet();

      // Each per-curriculum set correctly sees exactly one ref.
      expect(mishRefs, equals({sharedRef}));
      expect(bavliRefs, equals({sharedRef}));

      // The union — exactly what lifetimeTotalsAcrossAllCurriculaProvider
      // produces via Set.addAll — counts the shared ref ONCE, not twice.
      final unionRefs = <String>{};
      unionRefs.addAll(mishRefs);
      unionRefs.addAll(bavliRefs);

      expect(
        unionRefs.length,
        1,
        reason:
            'Set-union of per-curriculum learnedLeafRefs must count Berakhot 1a '
            'exactly once even though it has a completion_events row under each '
            'curriculum (regression guard for B9 / v22 per-curriculum schema)',
      );
    });

    // ── Provider-level: drive lifetimeTotalsAcrossAllCurriculaProvider with
    // two fake summaries whose learnedLeafRefs share the same sefariaRef. ─────

    test('provider: same sefariaRef in two curriculum summaries counts ONCE in '
        'lifetimeTotalsAcrossAllCurriculaProvider', () async {
      // Build two CurriculumLifetimeSummary objects where 'Berakhot 1a'
      // appears in BOTH learnedLeafRefs — exactly what happens after v22
      // when the same ref is completed under mishnayos AND bavli.
      const sharedRef = 'Berakhot 1a';
      const exclusiveMishRef = 'Berakhot 2a';
      const exclusiveBavliRef = 'Shabbat 2a';

      const mishSummary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.mishnayos,
        learnedLeafCount: 2,
        totalLeafCount: 3,
        percentage: 2 / 3,
        tree: [],
        learnedLeafRefs: {sharedRef, exclusiveMishRef},
        allLeafRefs: {sharedRef, exclusiveMishRef, 'Berakhot 3a'},
      );

      const bavliSummary = CurriculumLifetimeSummary(
        curriculumId: CurriculumId.bavli,
        learnedLeafCount: 2,
        totalLeafCount: 3,
        percentage: 2 / 3,
        tree: [],
        learnedLeafRefs: {sharedRef, exclusiveBavliRef},
        allLeafRefs: {sharedRef, exclusiveBavliRef, 'Shabbat 3a'},
      );

      final container = ProviderContainer(
        overrides: [
          lifetimeSummariesProvider(
            10,
          ).overrideWith((ref) => Future.value([mishSummary, bavliSummary])),
        ],
      );
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider(10).future,
      );

      // Naive (wrong) sum would be 2 + 2 = 4; correct union = 3 distinct refs.
      expect(
        totals.learnedSections,
        3,
        reason:
            'learnedSections must be the cardinality of the UNION of all '
            'learnedLeafRefs ({Berakhot 1a, Berakhot 2a, Shabbat 2a} = 3), '
            'not the naive sum (4) — regression guard for B9',
      );
      expect(
        totals.learnedSections,
        isNot(equals(4)),
        reason: 'Naive per-curriculum sum (4) would indicate double-counting',
      );

      // Denominator must also be deduplicated: union of allLeafRefs = 5 distinct.
      expect(
        totals.totalSections,
        5,
        reason:
            'totalSections is union of allLeafRefs '
            '({Berakhot 1a, Berakhot 2a, Berakhot 3a, Shabbat 2a, Shabbat 3a} = 5)',
      );
    });
  });

  group('lifetimeTotalsAcrossAllCurriculaProvider — deduplication', () {
    // Helpers for constructing fake summaries with explicit ref sets.
    CurriculumLifetimeSummary fakeSummary({
      required CurriculumId id,
      required Set<String> allRefs,
      required Set<String> learnedRefs,
    }) {
      return CurriculumLifetimeSummary(
        curriculumId: id,
        learnedLeafCount: learnedRefs.length,
        totalLeafCount: allRefs.length,
        percentage: allRefs.isEmpty ? 0.0 : learnedRefs.length / allRefs.length,
        tree: const [],
        allLeafRefs: allRefs,
        learnedLeafRefs: learnedRefs,
      );
    }

    test(
      'Chumash + Tanach overlap: totals equal Tanach alone, not the naive sum',
      () async {
        // Tanach contains all Chumash sections plus additional Nach sections.
        // Chumash sections: ref_A, ref_B, ref_C (3 sections, 2 learned).
        // Tanach sections: ref_A, ref_B, ref_C (Chumash) + ref_D, ref_E (Nach).
        //   Total distinct sections = 5; learned distinct = ref_A + ref_B + ref_D = 3.
        //
        // Naive sum would be: learnedTotal = 2+3=5, sectionTotal = 3+5=8 — WRONG.
        // Correct union: learnedDistinct = 3, allDistinct = 5.

        const chumashAll = {'ref_A', 'ref_B', 'ref_C'};
        const chumashLearned = {'ref_A', 'ref_B'};
        const tanachAll = {'ref_A', 'ref_B', 'ref_C', 'ref_D', 'ref_E'};
        const tanachLearned = {'ref_A', 'ref_B', 'ref_D'};

        final chumashSummary = fakeSummary(
          id: CurriculumId.chumash,
          allRefs: chumashAll,
          learnedRefs: chumashLearned,
        );
        final tanachSummary = fakeSummary(
          id: CurriculumId.tanach,
          allRefs: tanachAll,
          learnedRefs: tanachLearned,
        );

        final container = ProviderContainer(
          overrides: [
            lifetimeSummariesProvider(1).overrideWith(
              (ref) => Future.value([chumashSummary, tanachSummary]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final totals = await container.read(
          lifetimeTotalsAcrossAllCurriculaProvider(1).future,
        );

        // Union of allLeafRefs: {ref_A, ref_B, ref_C, ref_D, ref_E} = 5
        expect(
          totals.totalSections,
          5,
          reason:
              'Chumash sections are a subset of Tanach; union must not double-count them',
        );
        // Union of learnedLeafRefs: {ref_A, ref_B, ref_D} = 3
        expect(
          totals.learnedSections,
          3,
          reason:
              'Learned union should count each distinct ref once, not once per curriculum',
        );
        // Verify the naive sum would have been wrong (regression guard).
        expect(
          totals.totalSections,
          isNot(equals(chumashAll.length + tanachAll.length)),
        );
        expect(
          totals.learnedSections,
          isNot(equals(chumashLearned.length + tanachLearned.length)),
        );
      },
    );

    test('non-overlapping curricula: totals equal the naive sum', () async {
      // When curricula are disjoint the union equals the sum.
      const mishAll = {'m_A', 'm_B'};
      const mishLearned = {'m_A'};
      const bavliAll = {'b_1', 'b_2', 'b_3'};
      const bavliLearned = {'b_1', 'b_2'};

      final mishSummary = fakeSummary(
        id: CurriculumId.mishnayos,
        allRefs: mishAll,
        learnedRefs: mishLearned,
      );
      final bavliSummary = fakeSummary(
        id: CurriculumId.bavli,
        allRefs: bavliAll,
        learnedRefs: bavliLearned,
      );

      final container = ProviderContainer(
        overrides: [
          lifetimeSummariesProvider(
            2,
          ).overrideWith((ref) => Future.value([mishSummary, bavliSummary])),
        ],
      );
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider(2).future,
      );

      expect(totals.totalSections, mishAll.length + bavliAll.length);
      expect(totals.learnedSections, mishLearned.length + bavliLearned.length);
    });

    test('empty summaries list returns zeros', () async {
      final container = ProviderContainer(
        overrides: [
          lifetimeSummariesProvider(3).overrideWith((ref) => Future.value([])),
        ],
      );
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider(3).future,
      );

      expect(totals.totalSections, 0);
      expect(totals.learnedSections, 0);
      expect(totals.percentage, 0.0);
    });

    test('single curriculum with no refs carries through correctly', () async {
      final summary = fakeSummary(
        id: CurriculumId.mishnayos,
        allRefs: {'x', 'y', 'z'},
        learnedRefs: {'x'},
      );

      final container = ProviderContainer(
        overrides: [
          lifetimeSummariesProvider(
            4,
          ).overrideWith((ref) => Future.value([summary])),
        ],
      );
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider(4).future,
      );

      expect(totals.totalSections, 3);
      expect(totals.learnedSections, 1);
      expect(totals.percentage, closeTo(1 / 3, 0.001));
    });
  });
}
