/// Story acceptance tests for I-4 — Curriculum overlap deduplication
/// (Tanach ⊇ Chumash + Nach).
///
/// Verifies:
///   A. The [kCurriculumSupersets] registry is correct.
///   B. [subsetsOf] returns the right sets.
///   C. Chumash completions are visible in Tanach completed-refs union.
///   D. Nach completions are visible in Tanach completed-refs union.
///   E. A ref completed in BOTH a Chumash track and a Tanach track is not
///      double-counted (set union semantics).
///   F. Other curricula (Mishnayos, Bavli, etc.) are unaffected by the
///      superset logic.
@Tags(['epic_28', 'story_i4'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../helpers/drift_memory.dart' show seedCompletion, seedTrack;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserDatabase _openDb() => UserDatabase(NativeDatabase.memory());

/// Insert a minimal account + learner profile and return the profile id.
Future<int> _insertProfile(UserDatabase db) async {
  final now = DateTime.utc(2026, 1, 1);
  // Seed account first to satisfy FK on learner_profiles.account_id.
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'tester@example.com',
          tier: 'localBorn',
          displayName: 'Tester',
          createdAt: now,
          updatedAt: now,
        ),
      );
  final p = await db
      .into(db.learnerProfiles)
      .insertReturning(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Tester',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );
  return p.id;
}

/// Insert a single completion row.
Future<void> _insertCompletion(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required String curriculumId,
  required String sefariaRef,
  int stageId = 1,
}) async {
  await seedCompletion(
    db,
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: DateTime.utc(2026, 1, 1),
      points: const Value(0),
    ),
  );
}

/// Fetches the union of completed sefariaRefs for [curriculum] plus all
/// its subset curricula, via the completion-event union primitive only
/// (`getCompletionsByCurriculumAndProfile`).
///
/// AUD-t-story-acceptance-12: this does NOT reproduce the ledger-based
/// subset union that [lifetimeDataProvider] additionally performs — the
/// "P0 (composite-credit) fix" at lines 226-246 of
/// `lifetime_knowledge_providers.dart` that bridges a lifetime-ledger mark
/// made in a subset curriculum's own UI (no `completion_events` row at
/// all) into its superset. A ledger-only subset mark is invisible to this
/// helper. Group I-4-G below drives the REAL [lifetimeDataProvider]
/// end-to-end — including that ledger union — so this helper's narrower
/// scope does not leave the ledger path unguarded.
Future<Set<String>> _completedRefsWithSubsets(
  UserDatabase db,
  int profileId,
  CurriculumId curriculum,
) async {
  final direct = await db.completionDao.getCompletionsByCurriculumAndProfile(
    curriculum.storageKey,
    profileId,
  );
  var refs = direct.map((c) => c.sefariaRef).toSet();

  for (final subset in subsetsOf(curriculum)) {
    final subCompletions = await db.completionDao
        .getCompletionsByCurriculumAndProfile(subset.storageKey, profileId);
    refs = refs.union(subCompletions.map((c) => c.sefariaRef).toSet());
  }
  return refs;
}

/// Fixture [ContentRepository] for group I-4-G — serves a fixed set of
/// leaves per [CurriculumId] so [lifetimeDataProvider] (the REAL provider,
/// not a reimplementation) can run end-to-end against an in-memory DB.
class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository(this._leavesByCurriculum);

  final Map<CurriculumId, List<ContentItem>> _leavesByCurriculum;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => _leavesByCurriculum[curriculumId] ?? const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    final leaves = _leavesByCurriculum[curriculumId] ?? const [];
    return CurriculumHierarchyConfig(
      curriculumId: curriculumId.storageKey,
      levelLabels: const ['Level1', 'Level2', 'Level3', 'Level4'],
      totalItems: leaves.length,
    );
  }

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => _leavesByCurriculum[curriculumId] ?? const [];

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── A. Registry shape ────────────────────────────────────────────────────

  group('I-4-A — kCurriculumSupersets registry', () {
    test('chumash maps to {tanach}', () {
      expect(
        kCurriculumSupersets[CurriculumId.chumash],
        equals({CurriculumId.tanach}),
      );
    });

    test('nach maps to {tanach}', () {
      expect(
        kCurriculumSupersets[CurriculumId.nach],
        equals({CurriculumId.tanach}),
      );
    });

    test('no other curricula appear as subset keys', () {
      final keys = kCurriculumSupersets.keys.toSet();
      expect(keys, equals({CurriculumId.chumash, CurriculumId.nach}));
    });
  });

  // ── B. subsetsOf ─────────────────────────────────────────────────────────

  group('I-4-B — subsetsOf()', () {
    test('subsetsOf(tanach) returns {chumash, nach}', () {
      expect(
        subsetsOf(CurriculumId.tanach),
        equals({CurriculumId.chumash, CurriculumId.nach}),
      );
    });

    test('subsetsOf(chumash) is empty', () {
      expect(subsetsOf(CurriculumId.chumash), isEmpty);
    });

    test('subsetsOf(nach) is empty', () {
      expect(subsetsOf(CurriculumId.nach), isEmpty);
    });

    test('subsetsOf(mishnayos) is empty', () {
      expect(subsetsOf(CurriculumId.mishnayos), isEmpty);
    });

    test('subsetsOf(bavli) is empty', () {
      expect(subsetsOf(CurriculumId.bavli), isEmpty);
    });
  });

  // ── C. Chumash completions appear in Tanach union ─────────────────────────

  group('I-4-C — Chumash completions credited to Tanach', () {
    late UserDatabase db;
    late int profileId;
    late int chumashTrackId;

    setUp(() async {
      db = _openDb();
      profileId = await _insertProfile(db);
      chumashTrackId = await seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'chumash',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
    });

    tearDown(() async => db.close());

    test(
      'Bereishit perek completed via Chumash track appears in Tanach refs',
      () async {
        const ref = 'Genesis 1';

        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: chumashTrackId,
          curriculumId: 'chumash',
          sefariaRef: ref,
        );

        final tanachRefs = await _completedRefsWithSubsets(
          db,
          profileId,
          CurriculumId.tanach,
        );

        expect(
          tanachRefs,
          contains(ref),
          reason: 'Chumash completion should be visible in Tanach refs',
        );
      },
    );

    test(
      'Chumash completion does NOT appear in Tanach direct-only fetch',
      () async {
        const ref = 'Genesis 1';

        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: chumashTrackId,
          curriculumId: 'chumash',
          sefariaRef: ref,
        );

        // Direct Tanach fetch (no subset union) should NOT contain the ref
        final directTanach = await db.completionDao
            .getCompletionsByCurriculumAndProfile('tanach', profileId);
        expect(
          directTanach.map((c) => c.sefariaRef),
          isNot(contains(ref)),
          reason:
              'The DB stores chumash completions under chumash curriculumId, '
              'not tanach — the union is a read-time computation only',
        );
      },
    );
  });

  // ── D. Nach completions appear in Tanach union ───────────────────────────

  group('I-4-D — Nach completions credited to Tanach', () {
    late UserDatabase db;
    late int profileId;
    late int nachTrackId;

    setUp(() async {
      db = _openDb();
      profileId = await _insertProfile(db);
      nachTrackId = await seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'nach',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
    });

    tearDown(() async => db.close());

    test(
      'Isaiah perek completed via Nach track appears in Tanach refs',
      () async {
        const ref = 'Isaiah 1';

        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: nachTrackId,
          curriculumId: 'nach',
          sefariaRef: ref,
        );

        final tanachRefs = await _completedRefsWithSubsets(
          db,
          profileId,
          CurriculumId.tanach,
        );

        expect(
          tanachRefs,
          contains(ref),
          reason: 'Nach completion should be visible in Tanach refs',
        );
      },
    );
  });

  // ── E. No double-counting when same ref in both Chumash and Tanach tracks ─

  group('I-4-E — No double-counting when ref in both Chumash and Tanach', () {
    late UserDatabase db;
    late int profileId;
    late int chumashTrackId;
    late int tanachTrackId;

    setUp(() async {
      db = _openDb();
      profileId = await _insertProfile(db);
      chumashTrackId = await seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'chumash',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      tanachTrackId = await seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'tanach',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
    });

    tearDown(() async => db.close());

    test(
      'ref completed via Chumash AND direct Tanach track counts once in union',
      () async {
        const ref = 'Genesis 1';

        // Complete the same ref under both curricula
        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: chumashTrackId,
          curriculumId: 'chumash',
          sefariaRef: ref,
        );
        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: tanachTrackId,
          curriculumId: 'tanach',
          sefariaRef: ref,
        );

        final tanachRefs = await _completedRefsWithSubsets(
          db,
          profileId,
          CurriculumId.tanach,
        );

        // The set contains the ref exactly once (Set semantics)
        expect(tanachRefs.where((r) => r == ref).length, equals(1));
        expect(tanachRefs, contains(ref));
      },
    );

    test(
      'two distinct refs — one from Chumash, one from Tanach — both appear',
      () async {
        const chumashRef = 'Genesis 1';
        const tanachRef = 'Isaiah 1';

        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: chumashTrackId,
          curriculumId: 'chumash',
          sefariaRef: chumashRef,
        );
        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: tanachTrackId,
          curriculumId: 'tanach',
          sefariaRef: tanachRef,
        );

        final tanachRefs = await _completedRefsWithSubsets(
          db,
          profileId,
          CurriculumId.tanach,
        );

        expect(tanachRefs, containsAll([chumashRef, tanachRef]));
        expect(tanachRefs.length, equals(2));
      },
    );
  });

  // ── F. Unrelated curricula are unaffected ─────────────────────────────────

  group('I-4-F — Other curricula unaffected by overlap logic', () {
    late UserDatabase db;
    late int profileId;

    setUp(() async {
      db = _openDb();
      profileId = await _insertProfile(db);
    });

    tearDown(() async => db.close());

    test('subsetsOf(mishnayos) is empty — no cross-crediting', () {
      expect(subsetsOf(CurriculumId.mishnayos), isEmpty);
    });

    test('subsetsOf(mishnaBerurah) is empty', () {
      expect(subsetsOf(CurriculumId.mishnaBerurah), isEmpty);
    });

    test('subsetsOf(yerushalmi) is empty', () {
      expect(subsetsOf(CurriculumId.yerushalmi), isEmpty);
    });

    test('subsetsOf(mishnehTorah) is empty', () {
      expect(subsetsOf(CurriculumId.mishnehTorah), isEmpty);
    });

    test('Mishnayos completion does not pollute Tanach refs', () async {
      final trackId = await seedTrack(
        db,
        profileId: profileId,
        curriculumId: 'mishnayos',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      await _insertCompletion(
        db,
        profileId: profileId,
        trackId: trackId,
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berakhot 1:1',
      );

      final tanachRefs = await _completedRefsWithSubsets(
        db,
        profileId,
        CurriculumId.tanach,
      );

      expect(tanachRefs, isNot(contains('Mishnah Berakhot 1:1')));
    });

    test(
      'Chumash completion is visible in Chumash refs (subset does not lose its own refs)',
      () async {
        final trackId = await seedTrack(
          db,
          profileId: profileId,
          curriculumId: 'chumash',
          activatedAt: DateTime.utc(2026, 1, 1),
        );
        await _insertCompletion(
          db,
          profileId: profileId,
          trackId: trackId,
          curriculumId: 'chumash',
          sefariaRef: 'Genesis 1',
        );

        final chumashRefs = await _completedRefsWithSubsets(
          db,
          profileId,
          CurriculumId.chumash,
        );

        expect(chumashRefs, contains('Genesis 1'));
      },
    );
  });

  // ── G. Real lifetimeDataProvider exercises the ledger-based subset union ──
  //
  // AUD-t-story-acceptance-12: [_completedRefsWithSubsets] above is a local
  // reimplementation that only unions completion-EVENT refs. Production
  // [lifetimeDataProvider] additionally unions each subset's LEDGER-derived
  // learned refs (the "P0 (composite-credit) fix", lines 226-246 of
  // lifetime_knowledge_providers.dart) — a lifetime mark made in a subset
  // curriculum's own UI writes a `learning_ledger` row but NO
  // `completion_events` row, so [_completedRefsWithSubsets] can never see
  // it. This group drives the REAL provider end-to-end (real DB, real
  // ContentRepository fixture) with exactly such a ledger-only subset mark,
  // closing the coverage gap the old docstring implied was already closed.

  group('I-4-G — real lifetimeDataProvider unions ledger-only subset marks '
      '(P0 composite-credit fix)', () {
    late UserDatabase db;
    late int profileId;

    setUp(() async {
      db = _openDb();
      profileId = await _insertProfile(db);
    });

    tearDown(() async => db.close());

    test(
      'a Chumash lifetime-ledger mark with NO completion_events row still '
      'credits the corresponding leaf in Tanach via the real provider',
      () async {
        const sharedRef = 'Genesis 1:1';
        const tanachOnlyRef = 'Isaiah 1:1';

        // The Chumash leaf that will be credited purely via the ledger.
        const chumashLeaf = ContentItem(
          curriculumId: 'chumash',
          level1: 'Chumash',
          level2: 'Genesis',
          level3: '1',
          level4: '1',
          displayNameHe: '',
          displayNameEn: sharedRef,
          sefariaRef: sharedRef,
          sortOrder: 0,
          isLeaf: true,
        );
        // Tanach's own hierarchy carries the SAME sefariaRef for the
        // overlapping leaf, plus one Tanach-only (Nach-side) leaf so the
        // total/learned counts are distinguishable.
        const tanachSharedLeaf = ContentItem(
          curriculumId: 'tanach',
          level1: 'Torah',
          level2: 'Genesis',
          level3: '1',
          level4: '1',
          displayNameHe: '',
          displayNameEn: sharedRef,
          sefariaRef: sharedRef,
          sortOrder: 0,
          isLeaf: true,
        );
        const tanachOnlyLeaf = ContentItem(
          curriculumId: 'tanach',
          level1: 'Neviim',
          level2: 'Isaiah',
          level3: '1',
          level4: '1',
          displayNameHe: '',
          displayNameEn: tanachOnlyRef,
          sefariaRef: tanachOnlyRef,
          sortOrder: 1,
          isLeaf: true,
        );

        final repo = _FakeContentRepository({
          CurriculumId.chumash: [chumashLeaf],
          CurriculumId.tanach: [tanachSharedLeaf, tanachOnlyLeaf],
          CurriculumId.nach: const [],
        });

        // The genuine article: a lifetime-ledger mark against Chumash's
        // OWN level1 ('Chumash') — exactly what the standalone Chumash UI
        // writes — and critically NO completion_events row. If the
        // ledger-based subset union (lines 226-246) is removed or
        // short-circuited, this mark is invisible to Tanach.
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: profileId,
            ulid: Value(newUlid()),
            curriculumId: 'chumash',
            entryScope: 'level1',
            unitIdentifier: 'Chumash',
            unitDisplayNameHe: '',
            unitDisplayNameEn: '',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 1, 1),
            completionNumber: 1,
            markedBy: profileId,
          ),
        );

        // Sanity precondition: no completion_events row exists anywhere —
        // this really is a ledger-only mark.
        final allEvents = await db.select(db.completionEvents).get();
        expect(
          allEvents,
          isEmpty,
          reason:
              'precondition: the mark is ledger-only, no completion_events row',
        );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final summary = await container.read(
          lifetimeDataProvider((
            profileId: profileId,
            curriculumId: CurriculumId.tanach,
          )).future,
        );

        expect(summary, isNotNull);
        expect(
          summary!.learnedLeafRefs,
          contains(sharedRef),
          reason:
              'the Chumash ledger-only mark must propagate to Tanach via '
              'the REAL lifetimeDataProvider ledger-based subset union — '
              'a regression that removes or short-circuits lines 226-246 '
              'of lifetime_knowledge_providers.dart must fail this '
              'assertion',
        );
        expect(
          summary.learnedLeafCount,
          1,
          reason: 'exactly the one credited leaf, not the Nach-side leaf',
        );
        expect(summary.totalLeafCount, 2);
      },
    );
  });
}
