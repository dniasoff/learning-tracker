import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _ActiveProfile extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

const _uid = 'lifetime-knowledge-providers-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

Future<ProviderContainer> _container(
  FakeFirebaseFirestore firestore,
  ContentRepository repo,
) async {
  final handles = AccountFirebaseHandles(
    app: _MockFirebaseApp(),
    firestore: firestore,
    auth: _MockFirebaseAuth(),
    uid: _uid,
  );
  final container = ProviderContainer(
    overrides: [
      activeAccountFirebaseProvider.overrideWith((ref) async => handles),
      activeProfileIdProvider.overrideWith(() => _ActiveProfile()),
      contentRepositoryProvider.overrideWithValue(repo),
    ],
  );
  container.read(activeProfileDocIdProvider.notifier).set(_profileId);
  return container;
}

/// R8 Part B — minimal controllable [ContentRepository] fixture also
/// implementing [LifetimeUnionLeafSource], so
/// `lifetimeTotalsAcrossAllCurriculaProvider` takes its real (bounded)
/// content-loading branch instead of the `_safeLoadLeaves` fallback.
class _FakeLeafRepo implements ContentRepository, LifetimeUnionLeafSource {
  _FakeLeafRepo(this._leaves);

  final Map<CurriculumId, List<ContentItem>> _leaves;

  @override
  Future<List<ContentItem>> loadLeavesTransient(CurriculumId c) async =>
      _leaves[c] ?? const <ContentItem>[];

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId c) async =>
      _leaves[c] ?? const <ContentItem>[];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId c) =>
      throw UnimplementedError();

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) => throw UnimplementedError();

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) => throw UnimplementedError();

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) => throw UnimplementedError();

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) => throw UnimplementedError();
}

/// Builds a leaf [ContentItem] for [curriculumId] with [sefariaRef], using a
/// fixed `level1` — sufficient for tests that only need direct-completion
/// matching (no ledger scope marks).
ContentItem _fakeLeaf(String curriculumId, String sefariaRef) => ContentItem(
  curriculumId: curriculumId,
  level1: 'L1',
  displayNameHe: '',
  displayNameEn: sefariaRef,
  sefariaRef: sefariaRef,
  sortOrder: 0,
  isLeaf: true,
);

void main() {
  group('lifetimeDataProvider', () {
    test('is a family provider keyed by curriculumId', () {
      // Verify provider identity: calling with different args gives different
      // provider instances.
      const arg1 = CurriculumId.mishnayos;
      const arg2 = CurriculumId.bavli;

      final p1 = lifetimeDataProvider(arg1);
      final p2 = lifetimeDataProvider(arg2);

      // Different curriculum → different provider.
      expect(p1, isNot(equals(p2)));
      // Same args → same provider.
      expect(lifetimeDataProvider(arg1), equals(p1));
    });

    test('all nine CurriculumId values can be used as family args', () {
      // Smoke-test that every curriculum resolves to a distinct provider so
      // the family covers the full set without runtime errors.
      final providers = CurriculumId.values.map(lifetimeDataProvider).toList();

      expect(providers.length, CurriculumId.values.length);
      // All provider instances must be distinct (they are auto-dispose family).
      final unique = providers.toSet();
      expect(unique.length, providers.length);
    });
  });

  group('lifetimeSummariesProvider', () {
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
            lifetimeSummariesProvider.overrideWith(
              (ref) => Future.value([fakeSummary]),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(lifetimeSummariesProvider.future);

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
          lifetimeDataProvider(CurriculumId.chumash).overrideWith(
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
        lifetimeDataProvider(CurriculumId.chumash).future,
      );

      expect(result, isNotNull);
      expect(result!.curriculumId, CurriculumId.chumash);
      expect(result.learnedLeafCount, 5);
    });

    test('null result represents missing curriculum asset', () async {
      final container = ProviderContainer(
        overrides: [
          lifetimeDataProvider(
            CurriculumId.yerushalmi,
          ).overrideWith((ref) => Future.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        lifetimeDataProvider(CurriculumId.yerushalmi).future,
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
      final aliasP = globalLifetimeCurriculaProvider;
      final newP = lifetimeSummariesProvider;

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
    test('DAO: same sefariaRef under two curricula produces two completion_events '
        'rows but deduplicates to ONE distinct ref in a Set-union', () async {
      const sharedRef = 'Berakhot 1a';
      final ts = DateTime.utc(2026, 5, 19, 10);
      final firestore = createFakeFirestore(authenticatedUid: _uid);

      // Insert completion for sharedRef under mishnayos.
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos,
        sefariaRef: sharedRef,
        completedAt: ts,
      );

      // Insert completion for the SAME sharedRef under bavli.
      // Different curriculumId → different row (unique key includes curriculumId).
      await seedCompletion(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: CurriculumId.bavli,
        sefariaRef: sharedRef,
        completedAt: ts,
      );

      // Two rows exist — one per curriculum.
      final allRows = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('completions')
          .get();
      expect(
        allRows.docs,
        hasLength(2),
        reason:
            'Two distinct rows must exist — one per curriculum for the same sefariaRef',
      );

      // ── Simulate what lifetimeTotalsAcrossAllCurriculaProvider does ────────
      //   Each curriculum's provider queries per-curriculum, yielding a Set of
      //   sefariaRefs. The totals provider unions those sets.
      final repository = FirestoreCompletionRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      final mishCompletions = await repository.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      final bavliCompletions = await repository.getCompletionsForCurriculum(
        CurriculumId.bavli,
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
    // real completions (seeded on [db]) + a controllable fake content repo
    // whose leaves share a sefariaRef across two curricula. R8 Part B: the
    // provider no longer reads an injectable lifetimeSummariesProvider — it
    // computes learned/total refs itself from ContentRepository + completions
    // + ledger, so the fixture must go through those real seams instead. ────

    test('provider: same sefariaRef in two curriculum summaries counts ONCE in '
        'lifetimeTotalsAcrossAllCurriculaProvider', () async {
      // 'Berakhot 1a' is a leaf in BOTH mishnayos and bavli — exactly what
      // happens after v22 when the same ref is completed under both.
      const sharedRef = 'Berakhot 1a';
      const exclusiveMishRef = 'Berakhot 2a';
      const exclusiveBavliRef = 'Shabbat 2a';

      final leaves = {
        CurriculumId.mishnayos: [
          _fakeLeaf('mishnayos', sharedRef),
          _fakeLeaf('mishnayos', exclusiveMishRef),
          _fakeLeaf('mishnayos', 'Berakhot 3a'),
        ],
        CurriculumId.bavli: [
          _fakeLeaf('bavli', sharedRef),
          _fakeLeaf('bavli', exclusiveBavliRef),
          _fakeLeaf('bavli', 'Shabbat 3a'),
        ],
      };

      final firestore = createFakeFirestore(authenticatedUid: _uid);
      final ts = DateTime.utc(2026, 5, 19, 10);
      for (final ref in [sharedRef, exclusiveMishRef]) {
        await seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: ref,
          completedAt: ts,
        );
      }
      for (final ref in [sharedRef, exclusiveBavliRef]) {
        await seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.bavli,
          sefariaRef: ref,
          completedAt: ts,
        );
      }

      final container = await _container(firestore, _FakeLeafRepo(leaves));
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider.future,
      );

      // Naive (wrong) sum would be 2 + 2 = 4; correct union = 3 distinct refs.
      expect(
        totals.learnedSections,
        3,
        reason:
            'learnedSections must be the cardinality of the UNION of all '
            'learned refs ({Berakhot 1a, Berakhot 2a, Shabbat 2a} = 3), '
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
            'totalSections is union of all leaf refs '
            '({Berakhot 1a, Berakhot 2a, Berakhot 3a, Shabbat 2a, Shabbat 3a} = 5)',
      );
    });
  });

  group('lifetimeTotalsAcrossAllCurriculaProvider — deduplication', () {
    // R8 Part B: the provider computes learned/total refs itself from
    // ContentRepository + real completions (it no longer reads an
    // injectable lifetimeSummariesProvider) — each test below seeds real
    // completion events against a controllable fake content repo instead of
    // injecting fake summaries directly.
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = createFakeFirestore(authenticatedUid: _uid);
    });

    Future<void> seedLive(String curriculumId, String sefariaRef) =>
        seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.values.firstWhere(
            (c) => c.storageKey == curriculumId,
          ),
          sefariaRef: sefariaRef,
          completedAt: DateTime.utc(2026, 5, 1),
        );

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

        final leaves = {
          CurriculumId.chumash: chumashAll
              .map((r) => _fakeLeaf('chumash', r))
              .toList(),
          CurriculumId.tanach: tanachAll
              .map((r) => _fakeLeaf('tanach', r))
              .toList(),
        };
        for (final r in chumashLearned) {
          await seedLive('chumash', r);
        }
        for (final r in tanachLearned) {
          await seedLive('tanach', r);
        }

        final container = await _container(firestore, _FakeLeafRepo(leaves));
        addTearDown(container.dispose);

        final totals = await container.read(
          lifetimeTotalsAcrossAllCurriculaProvider.future,
        );

        // Union of all leaf refs: {ref_A, ref_B, ref_C, ref_D, ref_E} = 5
        expect(
          totals.totalSections,
          5,
          reason:
              'Chumash sections are a subset of Tanach; union must not double-count them',
        );
        // Union of learned refs: {ref_A, ref_B, ref_D} = 3
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

      final leaves = {
        CurriculumId.mishnayos: mishAll
            .map((r) => _fakeLeaf('mishnayos', r))
            .toList(),
        CurriculumId.bavli: bavliAll.map((r) => _fakeLeaf('bavli', r)).toList(),
      };
      for (final r in mishLearned) {
        await seedLive('mishnayos', r);
      }
      for (final r in bavliLearned) {
        await seedLive('bavli', r);
      }

      final container = await _container(firestore, _FakeLeafRepo(leaves));
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider.future,
      );

      expect(totals.totalSections, mishAll.length + bavliAll.length);
      expect(totals.learnedSections, mishLearned.length + bavliLearned.length);
    });

    test('empty summaries list returns zeros', () async {
      final container = await _container(firestore, _FakeLeafRepo(const {}));
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider.future,
      );

      expect(totals.totalSections, 0);
      expect(totals.learnedSections, 0);
      expect(totals.percentage, 0.0);
    });

    test('single curriculum with no refs carries through correctly', () async {
      final leaves = {
        CurriculumId.mishnayos: [
          'x',
          'y',
          'z',
        ].map((r) => _fakeLeaf('mishnayos', r)).toList(),
      };
      await seedLive('mishnayos', 'x');

      final container = await _container(firestore, _FakeLeafRepo(leaves));
      addTearDown(container.dispose);

      final totals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider.future,
      );

      expect(totals.totalSections, 3);
      expect(totals.learnedSections, 1);
      expect(totals.percentage, closeTo(1 / 3, 0.001));
    });
  });

  // D9: the lifetime chain (dashboard lifetime card) must recompute on a
  // completion commit, not only on the Progress-hub pull-to-refresh.
  group('D9 — lifetime chain reactivity to completionCommitted', () {
    test(
      'completionsByProfileForLifetimeProvider rebuilds after a commit',
      () async {
        final firestore = createFakeFirestore(authenticatedUid: _uid);
        final container = await _container(firestore, _FakeLeafRepo(const {}));
        addTearDown(container.dispose);

        // Keep the provider alive (mirrors the mounted dashboard).
        final sub = container.listen(
          completionsByProfileForLifetimeProvider,
          (_, __) {},
        );
        addTearDown(sub.close);

        final before = (await container.read(
          completionsByProfileForLifetimeProvider.future,
        )).values.fold<int>(0, (a, l) => a + l.length);
        expect(before, 0);

        // A new completion lands AND a commit is signalled.
        await seedCompletion(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'Berakhot 2a',
          completedAt: DateTime.utc(2026, 5, 31, 10),
        );
        container.read(completionCommittedProvider.notifier).increment();

        // D9: the provider re-queries on commit — without the completionCommitted
        // watch it would stay cached at zero until a pull-to-refresh.
        await container.read(completionsByProfileForLifetimeProvider.future);
        final after = container
            .read(completionsByProfileForLifetimeProvider)
            .value!
            .values
            .fold<int>(0, (a, l) => a + l.length);
        expect(
          after,
          1,
          reason: 'lifetime completions must reflect the new commit (D9)',
        );
      },
    );
  });
}
