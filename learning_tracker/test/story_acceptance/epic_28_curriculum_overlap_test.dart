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
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';

import '../helpers/drift_memory.dart' show seedCompletion;

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
          userMode: 'adult',
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

/// Insert a minimal curriculum track and return its id.
Future<int> _insertTrack(
  UserDatabase db,
  int profileId,
  String curriculumId,
) async {
  final now = DateTime.utc(2026, 1, 1);
  final t = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: now,
          activatedAt: now,
        ),
      );
  return t.id;
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
/// its subset curricula — mirrors the logic in [lifetimeDataProvider].
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
      chumashTrackId = await _insertTrack(db, profileId, 'chumash');
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
      nachTrackId = await _insertTrack(db, profileId, 'nach');
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
      chumashTrackId = await _insertTrack(db, profileId, 'chumash');
      tanachTrackId = await _insertTrack(db, profileId, 'tanach');
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
      final trackId = await _insertTrack(db, profileId, 'mishnayos');
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
        final trackId = await _insertTrack(db, profileId, 'chumash');
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
}
