/// Logic tests for [CompletionWriter].
///
/// Covers:
///  - Three-tier credit policy: engagement / achievement / lifetime
///  - Bulk-mark sentinel date (DateTime.utc(2000,1,1)) writes to DB but must
///    NOT appear in date-range queries used for streak / recent-activity
///  - Dedup / idempotency: single commit, commitBatch
///  - Points assignment carried through to persisted rows and outbox payload
///  - priorMarkOnly flag: written for bulk-prior commands; cleared on B8 upgrade
///  - Tombstone resurrection: re-marking a purged row enqueues a new outbox row
///  - commitBatch de-duplication within a single call
///  - Tutor write-block: TutorPermissions.canMarkLiveCompletion is always false;
///    MarkLiveCompletionUseCase throws for tutor sessions
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

// ── helpers ───────────────────────────────────────────────────────────────────

UserDatabase _db() => UserDatabase(NativeDatabase.memory());

/// Seeds a minimal account + learner profile.  Returns the profileId.
Future<int> _seedProfile(UserDatabase db) async {
  final now = DateTime.utc(2026, 5, 1);
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test',
          createdAt: now,
          updatedAt: now,
        ),
      );
  return db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test',
          mode: 'child',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<int> _seedTrack(UserDatabase db, int profileId) => db
    .into(db.curriculumTracks)
    .insert(
      CurriculumTracksCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        stateChangedAt: DateTime.utc(2026, 5, 1),
        activatedAt: DateTime.utc(2026, 5, 1),
      ),
    );

/// Builds a [CompletionCommand] with sensible defaults; only override what
/// the individual test needs.
CompletionCommand _cmd({
  required int profileId,
  required int trackId,
  String curriculumId = 'mishnayos',
  String sefariaRef = 'Berakhot 1',
  int stageId = 1,
  String trackType = 'personal',
  DateTime? completedAt,
  int points = 10,
  bool priorMarkOnly = false,
}) => CompletionCommand(
  profileId: profileId,
  curriculumId: curriculumId,
  sefariaRef: sefariaRef,
  stageId: stageId,
  trackType: trackType,
  trackId: trackId,
  completedAt: completedAt ?? DateTime.utc(2026, 5, 15, 12),
  points: points,
  priorMarkOnly: priorMarkOnly,
);

/// The bulk-prior sentinel date as used by the production service.
final _sentinel = kBulkPriorSentinelDate; // DateTime.utc(2000,1,1)

/// A "live" completion date — well within any reasonable recent-activity window.
final _liveDate = DateTime.utc(2026, 5, 15, 10);

// ── test suite ────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late CompletionWriter writer;
  late int profileId;
  late int trackId;

  setUp(() async {
    db = _db();
    profileId = await _seedProfile(db);
    trackId = await _seedTrack(db, profileId);
    writer = CompletionWriter(db);
  });

  tearDown(() => db.close());

  // ══════════════════════════════════════════════════════════════════════════
  // 1. Single commit — happy path
  // ══════════════════════════════════════════════════════════════════════════

  group('commit — single write', () {
    test('inserts one completion_events row and one outbox row', () async {
      final result = await writer.commit(
        _cmd(profileId: profileId, trackId: trackId),
      );

      expect(result.isNew, isTrue);
      expect(result.completion.sefariaRef, 'Berakhot 1');
      expect(result.completion.profileId, profileId);

      final events = await db.select(db.completionEvents).get();
      expect(events, hasLength(1));
      expect(events.first.sefariaRef, 'Berakhot 1');
      expect(events.first.purgedAt, isNull);

      final outbox = await db.select(db.outbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.first.entityKind, OutboxEntityKind.completion);
    });

    test('persists the points value from the command', () async {
      await writer.commit(
        _cmd(profileId: profileId, trackId: trackId, points: 42),
      );

      final events = await db.select(db.completionEvents).get();
      expect(events.first.points, 42);

      final outbox = await db.select(db.outbox).get();
      final payload = jsonDecode(outbox.first.payload) as Map<String, dynamic>;
      expect(payload['points'], 42);
    });

    test(
      'outbox payload uses snake_case keys and UTC ISO-8601 completed_at',
      () async {
        final ts = DateTime.utc(2026, 5, 15, 14, 30);
        await writer.commit(
          _cmd(profileId: profileId, trackId: trackId, completedAt: ts),
        );

        final outbox = await db.select(db.outbox).get();
        final payload =
            jsonDecode(outbox.first.payload) as Map<String, dynamic>;

        expect(payload['profile_id'], profileId);
        expect(payload['curriculum_id'], 'mishnayos');
        expect(payload['sefaria_ref'], 'Berakhot 1');
        expect(payload['stage_id'], 1);
        expect(payload['track_type'], 'personal');
        expect(payload['completed_at'], '2026-05-15T14:30:00.000Z');
      },
    );

    test('persists the completedAt timestamp exactly', () async {
      final ts = DateTime.utc(2026, 5, 15, 8, 0);
      await writer.commit(
        _cmd(profileId: profileId, trackId: trackId, completedAt: ts),
      );

      final events = await db.select(db.completionEvents).get();
      expect(
        events.first.eventTimestamp.millisecondsSinceEpoch,
        ts.millisecondsSinceEpoch,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. Idempotency — single commit
  // ══════════════════════════════════════════════════════════════════════════

  group('commit — idempotency', () {
    test(
      'second commit on same key returns isNew=false and no new rows',
      () async {
        final first = await writer.commit(
          _cmd(profileId: profileId, trackId: trackId),
        );
        final second = await writer.commit(
          _cmd(profileId: profileId, trackId: trackId),
        );

        expect(first.isNew, isTrue);
        expect(second.isNew, isFalse);
        expect(second.completion.id, first.completion.id);

        expect(await db.select(db.completionEvents).get(), hasLength(1));
        expect(await db.select(db.outbox).get(), hasLength(1));
      },
    );

    test('different sefariaRef produces a second distinct row', () async {
      await writer.commit(
        _cmd(profileId: profileId, trackId: trackId, sefariaRef: 'Berakhot 1'),
      );
      final r2 = await writer.commit(
        _cmd(profileId: profileId, trackId: trackId, sefariaRef: 'Berakhot 2'),
      );

      expect(r2.isNew, isTrue);
      expect(await db.select(db.completionEvents).get(), hasLength(2));
      expect(await db.select(db.outbox).get(), hasLength(2));
    });

    test(
      'same sefariaRef but different curriculumId produces two distinct rows '
      '(per-curriculum isolation)',
      () async {
        // Seed a second track under a different curriculum.
        final track2 = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                stateChangedAt: DateTime.utc(2026, 5, 1),
                activatedAt: DateTime.utc(2026, 5, 1),
              ),
            );

        await writer.commit(
          _cmd(
            profileId: profileId,
            trackId: trackId,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 1',
          ),
        );
        final r2 = await writer.commit(
          _cmd(
            profileId: profileId,
            trackId: track2,
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot 1',
          ),
        );

        expect(r2.isNew, isTrue);
        final events = await db.select(db.completionEvents).get();
        expect(events, hasLength(2));
        expect(
          events.map((e) => e.curriculumId).toSet(),
          containsAll(['mishnayos', 'bavli']),
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Bulk-mark sentinel — completions stored but excluded from recent window
  // ══════════════════════════════════════════════════════════════════════════

  group('bulk-mark sentinel date', () {
    test('sentinel completion is persisted in completion_events', () async {
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );

      final events = await db.select(db.completionEvents).get();
      expect(events, hasLength(1));
      expect(
        events.first.eventTimestamp.millisecondsSinceEpoch,
        _sentinel.millisecondsSinceEpoch,
        reason: 'Sentinel timestamp must be stored verbatim',
      );
    });

    test('sentinel completion does NOT appear in a date-range query for today '
        '(streak / recent-activity window)', () async {
      // Write a sentinel completion.
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1',
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );
      // Write a real (live) completion.
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 2',
          completedAt: _liveDate,
        ),
      );

      // Query completions in a "today" window — must NOT include the sentinel.
      final todayStart = DateTime.utc(2026, 5, 1);
      final todayEnd = DateTime.utc(2026, 5, 31, 23, 59);
      final recent = await db.completionDao.getCompletionsByDateRangeAndProfile(
        todayStart,
        todayEnd,
        profileId,
      );

      final refs = recent.map((c) => c.sefariaRef).toSet();
      expect(
        refs,
        isNot(contains('Berakhot 1')),
        reason:
            'Sentinel completion (year 2000) must not appear in streak/recent window',
      );
      expect(
        refs,
        contains('Berakhot 2'),
        reason: 'Live completion must appear in date-range query',
      );
    });

    test('sentinel completedAt does NOT satisfy hasCompletionsInDateRange for '
        'any modern date window', () async {
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );

      // No completions in 2026 window.
      final has = await db.completionDao.hasCompletionsInDateRangeByProfile(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 12, 31),
        profileId,
      );
      expect(
        has,
        isFalse,
        reason:
            'Sentinel (year 2000) must not register as activity in a 2026 window',
      );
    });

    test('sentinel completion appears in the year-2000 window '
        '(confirms it was actually stored)', () async {
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );

      final has = await db.completionDao.hasCompletionsInDateRangeByProfile(
        DateTime.utc(1999, 12, 31),
        DateTime.utc(2000, 1, 2),
        profileId,
      );
      expect(
        has,
        isTrue,
        reason: 'Sentinel completion must be retrievable from its own era',
      );
    });

    test(
      'points are stored as 0 for bulk-prior commands (no engagement credit)',
      () async {
        // The bulk-prior path passes points=0 per product rules (no gamification
        // for prior marks — engagement tier suppressed).
        await writer.commit(
          _cmd(
            profileId: profileId,
            trackId: trackId,
            completedAt: _sentinel,
            points: 0,
            priorMarkOnly: true,
          ),
        );

        final events = await db.select(db.completionEvents).get();
        expect(
          events.first.points,
          0,
          reason: 'Prior-mark completions store 0 points',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. priorMarkOnly flag — storage + B8 upgrade
  // ══════════════════════════════════════════════════════════════════════════

  group('priorMarkOnly flag and B8 upgrade', () {
    test(
      'commit with priorMarkOnly=true inserts a prior_completion_imports row',
      () async {
        await writer.commit(
          _cmd(
            profileId: profileId,
            trackId: trackId,
            completedAt: _sentinel,
            priorMarkOnly: true,
          ),
        );

        final imports = await db.select(db.priorCompletionImports).get();
        expect(imports, hasLength(1));
        expect(imports.first.sefariaRef, 'Berakhot 1');
        expect(imports.first.profileId, profileId);
      },
    );

    test('commit with priorMarkOnly=false does NOT insert a '
        'prior_completion_imports row', () async {
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _liveDate,
          priorMarkOnly: false,
        ),
      );

      final imports = await db.select(db.priorCompletionImports).get();
      expect(
        imports,
        isEmpty,
        reason: 'Live completions must not be marked as prior imports',
      );
    });

    test('B8: real-learning commit on top of a prior-mark removes the '
        'prior_completion_imports record (upgrade)', () async {
      // 1. Prior-mark.
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );
      expect(await db.select(db.priorCompletionImports).get(), hasLength(1));

      // 2. Real-learning write hits the same natural key.
      final result = await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _liveDate,
          priorMarkOnly: false,
        ),
      );

      // The import record must be gone after the upgrade.
      final importsAfter = await db.select(db.priorCompletionImports).get();
      expect(
        importsAfter,
        isEmpty,
        reason:
            'B8: prior_completion_imports record must be removed when real '
            'learning upgrades the row',
      );

      // The row itself survives and is returned as isNew=false.
      expect(result.isNew, isFalse);
      expect(result.completion.sefariaRef, 'Berakhot 1');

      // The completion_events timestamp is updated to the real-learning date.
      final event = await (db.select(
        db.completionEvents,
      )..where((t) => t.sefariaRef.equals('Berakhot 1'))).getSingle();
      expect(
        event.eventTimestamp.millisecondsSinceEpoch,
        _liveDate.millisecondsSinceEpoch,
        reason:
            'B8: eventTimestamp must be updated to the real-learning timestamp',
      );
    });

    test('B8 upgrade enqueues a second outbox row so Firestore receives the '
        'real-learning timestamp', () async {
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _liveDate,
          priorMarkOnly: false,
        ),
      );

      // Should have exactly 2 outbox rows: the original sentinel push + the
      // upgrade push.
      final outbox = await db.select(db.outbox).get();
      expect(
        outbox,
        hasLength(2),
        reason:
            'B8 upgrade must enqueue a new outbox row for the real-learning push',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Tombstone resurrection (H1 fix)
  // ══════════════════════════════════════════════════════════════════════════

  group('tombstone resurrection', () {
    test('re-marking a tombstoned row clears purgedAt, updates timestamp, '
        'enqueues outbox, and returns isNew=true', () async {
      // 1. Write original completion.
      await writer.commit(_cmd(profileId: profileId, trackId: trackId));

      // 2. Manually tombstone the row (simulates expungePriorCompletions).
      final now = DateTime.utc(2026, 5, 16);
      await (db.update(db.completionEvents)
            ..where((t) => t.sefariaRef.equals('Berakhot 1')))
          .write(CompletionEventsCompanion(purgedAt: Value(now)));

      // Confirm tombstoned.
      final before = await db.select(db.completionEvents).get();
      expect(before.first.purgedAt, isNotNull);

      // 3. Re-mark via the writer.
      final resurrected = await writer.commit(
        _cmd(profileId: profileId, trackId: trackId, completedAt: _liveDate),
      );

      expect(
        resurrected.isNew,
        isTrue,
        reason: 'Resurrection must return isNew=true',
      );

      // Row must be active again.
      final after = await db.select(db.completionEvents).get();
      expect(after, hasLength(1));
      expect(after.first.purgedAt, isNull, reason: 'purgedAt must be cleared');
      expect(
        after.first.eventTimestamp.millisecondsSinceEpoch,
        _liveDate.millisecondsSinceEpoch,
        reason: 'Timestamp must be updated to the re-mark instant',
      );

      // Both original write + resurrection enqueue an outbox row.
      final outbox = await db.select(db.outbox).get();
      expect(
        outbox,
        hasLength(2),
        reason: 'Resurrection must enqueue a new outbox row',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. commitBatch
  // ══════════════════════════════════════════════════════════════════════════

  group('commitBatch', () {
    test('empty list returns empty results without touching the DB', () async {
      final results = await writer.commitBatch([]);
      expect(results, isEmpty);
      expect(await db.select(db.completionEvents).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
    });

    test('single command in batch inserts one row + one outbox row', () async {
      final results = await writer.commitBatch([
        _cmd(profileId: profileId, trackId: trackId),
      ]);

      expect(results, hasLength(1));
      expect(results.first.isNew, isTrue);
      expect(await db.select(db.completionEvents).get(), hasLength(1));
      expect(await db.select(db.outbox).get(), hasLength(1));
    });

    test('N distinct commands produce N rows in one transaction', () async {
      final cmds = List.generate(
        5,
        (i) => _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot ${i + 1}',
        ),
      );
      final results = await writer.commitBatch(cmds);

      expect(results, hasLength(5));
      expect(results.every((r) => r.isNew), isTrue);
      expect(await db.select(db.completionEvents).get(), hasLength(5));
      expect(await db.select(db.outbox).get(), hasLength(5));
    });

    test('duplicate commands within the same batch are de-duplicated: '
        'one row per natural key, isNew=true for both result slots', () async {
      final cmd = _cmd(profileId: profileId, trackId: trackId);
      final results = await writer.commitBatch([cmd, cmd]);

      expect(results, hasLength(2));
      expect(results[0].isNew, isTrue);
      expect(results[1].isNew, isTrue);
      // Same completion row returned for both.
      expect(results[0].completion.id, results[1].completion.id);

      // Only one DB row.
      expect(await db.select(db.completionEvents).get(), hasLength(1));
      expect(await db.select(db.outbox).get(), hasLength(1));
    });

    test(
      'batch over pre-existing rows returns isNew=false and no new outbox rows',
      () async {
        // Pre-insert via single commit.
        await writer.commit(_cmd(profileId: profileId, trackId: trackId));
        final outboxBefore = await db.select(db.outbox).get();
        expect(outboxBefore, hasLength(1));

        // Re-run the same command as a batch.
        final results = await writer.commitBatch([
          _cmd(profileId: profileId, trackId: trackId),
        ]);

        expect(results.first.isNew, isFalse);
        // Outbox count must not increase.
        expect(await db.select(db.outbox).get(), hasLength(1));
      },
    );

    test('batch with a mix of new and pre-existing commands: new ones get '
        'isNew=true, pre-existing get isNew=false', () async {
      // Pre-insert sefariaRef A.
      await writer.commit(
        _cmd(profileId: profileId, trackId: trackId, sefariaRef: 'Berakhot 1'),
      );

      final results = await writer.commitBatch([
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1',
        ), // pre-existing
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 2',
        ), // new
      ]);

      expect(results[0].isNew, isFalse);
      expect(results[1].isNew, isTrue);
      expect(await db.select(db.completionEvents).get(), hasLength(2));
    });

    test('priorMarkOnly=true in batch writes prior_completion_imports rows '
        'for new commands only', () async {
      final cmds = [
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1',
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 2',
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      ];

      await writer.commitBatch(cmds);

      final imports = await db.select(db.priorCompletionImports).get();
      expect(imports, hasLength(2));
      expect(
        imports.map((i) => i.sefariaRef).toSet(),
        containsAll(['Berakhot 1', 'Berakhot 2']),
      );
    });

    test('batch points are stored correctly per command', () async {
      await writer.commitBatch([
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 1',
          points: 5,
        ),
        _cmd(
          profileId: profileId,
          trackId: trackId,
          sefariaRef: 'Berakhot 2',
          points: 20,
        ),
      ]);

      final events = await (db.select(
        db.completionEvents,
      )..orderBy([(t) => OrderingTerm.asc(t.sefariaRef)])).get();
      expect(events[0].points, 5);
      expect(events[1].points, 20);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 7. Three-tier credit policy (CompletionSource / BatchPlan semantics)
  // ══════════════════════════════════════════════════════════════════════════

  group('three-tier credit policy (CompletionSource)', () {
    test('CompletionSource.live.creditsEngagement is true', () {
      expect(CompletionSource.live.creditsEngagement, isTrue);
    });

    test('CompletionSource.live.creditsAchievement is true', () {
      expect(CompletionSource.live.creditsAchievement, isTrue);
    });

    test('CompletionSource.live.creditsLifetime is true', () {
      expect(CompletionSource.live.creditsLifetime, isTrue);
    });

    test('CompletionSource.bulkInTrack.creditsEngagement is false', () {
      expect(
        CompletionSource.bulkInTrack.creditsEngagement,
        isFalse,
        reason: 'BulkInTrack must NOT credit engagement (no streak/points)',
      );
    });

    test('CompletionSource.bulkInTrack.creditsAchievement is true', () {
      expect(
        CompletionSource.bulkInTrack.creditsAchievement,
        isTrue,
        reason: 'BulkInTrack MUST credit achievement (siyumim earn)',
      );
    });

    test('CompletionSource.bulkInTrack.creditsLifetime is true', () {
      expect(CompletionSource.bulkInTrack.creditsLifetime, isTrue);
    });

    test('CompletionSource.lifetimeOnly.creditsEngagement is false', () {
      expect(CompletionSource.lifetimeOnly.creditsEngagement, isFalse);
    });

    test('CompletionSource.lifetimeOnly.creditsAchievement is false', () {
      expect(
        CompletionSource.lifetimeOnly.creditsAchievement,
        isFalse,
        reason: 'LifetimeOnly must NOT credit achievement (no siyumim)',
      );
    });

    test('CompletionSource.lifetimeOnly.creditsLifetime is true', () {
      expect(
        CompletionSource.lifetimeOnly.creditsLifetime,
        isTrue,
        reason: 'Every source must credit lifetime',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 8. Sentinel completions in completions_view
  // ══════════════════════════════════════════════════════════════════════════

  group(
    'completions_view: sentinel rows only appear for active (non-purged)',
    () {
      test('sentinel completion appears in completions_view before expunge; '
          'disappears (from view) after purgedAt is set', () async {
        await writer.commit(
          _cmd(
            profileId: profileId,
            trackId: trackId,
            completedAt: _sentinel,
            priorMarkOnly: true,
          ),
        );

        // Should appear in completions_view (purgedAt IS NULL).
        final before = await db.completionDao.getCompletionsByProfile(
          profileId,
        );
        expect(before, hasLength(1));
        expect(
          before.first.completedAt.millisecondsSinceEpoch,
          _sentinel.millisecondsSinceEpoch,
        );

        // Manually tombstone.
        await (db.update(
          db.completionEvents,
        )..where((t) => t.sefariaRef.equals('Berakhot 1'))).write(
          CompletionEventsCompanion(purgedAt: Value(DateTime.utc(2026, 5, 16))),
        );

        // Must NOT appear in completions_view after tombstone.
        final after = await db.completionDao.getCompletionsByProfile(profileId);
        expect(
          after,
          isEmpty,
          reason: 'Tombstoned sentinel must be excluded from completions_view',
        );
      });
    },
  );

  // ══════════════════════════════════════════════════════════════════════════
  // 9. Tutor write-block invariant
  // ══════════════════════════════════════════════════════════════════════════

  group('tutor write-block', () {
    test('TutorPermissions.canMarkLiveCompletion is always false', () {
      expect(const TutorPermissions().canMarkLiveCompletion, isFalse);
      expect(TutorPermissions.defaults().canMarkLiveCompletion, isFalse);
      expect(TutorPermissions.readOnly().canMarkLiveCompletion, isFalse);
      // copyWith has no canMarkLiveCompletion param — must remain false.
      expect(
        const TutorPermissions()
            .copyWith(canEditGoals: true)
            .canMarkLiveCompletion,
        isFalse,
      );
    });

    test('MarkLiveCompletionUseCase throws TutorWriteForbiddenException and '
        'never calls the delegate for a tutor session', () async {
      var ran = false;
      final tutorSession = ResolvedSession.forTutor(
        selection: const TutoredProfileSelection(
          profileId: '1',
          ownerUid: 'parent-1',
          grantId: 'grant-1',
          permissions: TutorPermissions(),
        ),
      );
      final useCase = MarkLiveCompletionUseCase<void>(session: tutorSession);

      await expectLater(
        () => useCase.call(() async {
          ran = true;
        }),
        throwsA(isA<TutorWriteForbiddenException>()),
      );
      expect(
        ran,
        isFalse,
        reason: 'Tutor session must never reach the completion delegate',
      );
    });

    test('owner session is allowed through the use case', () async {
      final ownerSession = ResolvedSession.forOwner(
        selection: const OwnProfileSelection(
          profileId: '1',
          ownerUid: 'owner-1',
        ),
        isChildMode: false,
      );
      final useCase = MarkLiveCompletionUseCase<int>(session: ownerSession);

      final result = await useCase.call(() async => 99);
      expect(result, 99);
    });

    test(
      'child (own-profile) session is allowed through the use case',
      () async {
        final childSession = ResolvedSession.forOwner(
          selection: const OwnProfileSelection(
            profileId: '1',
            ownerUid: 'child-1',
          ),
          isChildMode: true,
        );
        final useCase = MarkLiveCompletionUseCase<String>(
          session: childSession,
        );

        final result = await useCase.call(() async => 'allowed');
        expect(result, 'allowed');
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 10. Outbox entity key format
  // ══════════════════════════════════════════════════════════════════════════

  group('outbox entity key', () {
    test(
      'entity key format is profileId:sefariaRef:stageId:trackType:curriculumId',
      () async {
        await writer.commit(_cmd(profileId: profileId, trackId: trackId));

        final outbox = await db.select(db.outbox).get();
        expect(
          outbox.first.entityKey,
          '$profileId:Berakhot 1:1:personal:mishnayos',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 11. commitBatch — B8 upgrade path
  // ══════════════════════════════════════════════════════════════════════════

  group('commitBatch B8 upgrade', () {
    test('batch real-learning command over a prior-mark removes the import row '
        'and enqueues an upgrade outbox row', () async {
      // 1. Prior-mark via single commit.
      await writer.commit(
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _sentinel,
          priorMarkOnly: true,
        ),
      );
      expect(await db.select(db.priorCompletionImports).get(), hasLength(1));

      // 2. Real-learning batch hits the same key.
      await writer.commitBatch([
        _cmd(
          profileId: profileId,
          trackId: trackId,
          completedAt: _liveDate,
          priorMarkOnly: false,
        ),
      ]);

      // Import record must be removed.
      expect(
        await db.select(db.priorCompletionImports).get(),
        isEmpty,
        reason: 'B8: batch upgrade must remove prior_completion_imports row',
      );

      // Two outbox rows: original sentinel push + upgrade push.
      expect(await db.select(db.outbox).get(), hasLength(2));
    });
  });
}
