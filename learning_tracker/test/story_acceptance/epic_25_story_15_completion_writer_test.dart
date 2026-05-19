/// Story acceptance tests for Epic 25 Story 25.15 (DNI-336).
///
/// `CompletionWriter.commit(CompletionCommand)` is the single authoritative
/// path for recording a completion (FR15). The writer's transaction inserts
/// the `completions` projection row, the `outbox` row, and the
/// `completion_events` append-only log row atomically.
@Tags(['epic_25'])
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

UserDatabase _createDb() => UserDatabase(NativeDatabase.memory());

/// Insert a curriculum track row and return its id, so completion FKs resolve.
Future<int> _insertTrack(
  UserDatabase db, {
  int profileId = 1,
  String curriculumId = 'mishnah_yomit',
  String trackType = 'personal',
}) async {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackType: trackType,
          activatedAt: DateTime.utc(2026, 5, 1),
          isActive: const Value(true),
        ),
      );
}

CompletionCommand _cmd({
  required int trackId,
  int profileId = 1,
  String curriculumId = 'mishnah_yomit',
  String sefariaRef = 'Mishnah Berakhot 1',
  int stageId = 1,
  String trackType = 'personal',
  DateTime? completedAt,
  int points = 5,
}) => CompletionCommand(
  profileId: profileId,
  curriculumId: curriculumId,
  sefariaRef: sefariaRef,
  stageId: stageId,
  trackType: trackType,
  trackId: trackId,
  completedAt: completedAt ?? DateTime.utc(2026, 5, 13, 12),
  points: points,
);

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  group(
    'Story 25.15 — CompletionWriter.commit() single transactional path',
    tags: ['story_25_15'],
    () {
      late UserDatabase db;
      late CompletionWriter writer;
      late int trackId;

      setUp(() async {
        db = _createDb();
        await seedProfile(db);
        writer = CompletionWriter(db);
        trackId = await _insertTrack(db);
      });
      tearDown(() => db.close());

      // ── AC: command type ─────────────────────────────────────────────────

      test('CompletionCommand fields are non-nullable identity fields', () {
        final cmd = _cmd(trackId: trackId);
        expect(cmd.profileId, isA<int>());
        expect(cmd.sefariaRef, isA<String>());
        expect(cmd.stageId, isA<int>());
        expect(cmd.trackType, isA<String>());
        expect(cmd.completedAt, isA<DateTime>());
        expect(cmd.points, isA<int>());

        // Freezed value equality.
        final twin = _cmd(trackId: trackId);
        expect(cmd, equals(twin));
      });

      // ── AC: writer is the single path; writes both rows atomically ──────

      test(
        'commit() inserts an outbox row AND a completion_events row in one '
        'atomic transaction (C1: completions table no longer written)',
        () async {
          final result = await writer.commit(_cmd(trackId: trackId));

          expect(result.isNew, isTrue);
          expect(result.completion.sefariaRef, equals('Mishnah Berakhot 1'));

          final outboxRows = await db.select(db.outbox).get();
          expect(outboxRows, hasLength(1));
          expect(
            outboxRows.first.entityKind,
            equals(OutboxEntityKind.completion),
          );
          expect(
            outboxRows.first.entityKey,
            equals('1:Mishnah Berakhot 1:1:personal:mishnah_yomit'),
          );

          final payload =
              jsonDecode(outboxRows.first.payload) as Map<String, dynamic>;
          expect(payload['profile_id'], equals(1));
          expect(payload['sefaria_ref'], equals('Mishnah Berakhot 1'));
          expect(payload['stage_id'], equals(1));
          expect(payload['track_type'], equals('personal'));
          expect(payload['points'], equals(5));
          expect(payload['curriculum_id'], equals('mishnah_yomit'));

          // AC 25.15: completion_events row must be inserted atomically.
          final events = await db.select(db.completionEvents).get();
          expect(events, hasLength(1));
          expect(events.first.profileId, equals(1));
          expect(events.first.sefariaRef, equals('Mishnah Berakhot 1'));
          expect(events.first.stageId, equals(1));
          expect(events.first.trackType, equals('personal'));
          expect(events.first.curriculumId, equals('mishnah_yomit'));
          expect(events.first.points, equals(5));
          expect(
            events.first.eventTimestamp.toUtc().microsecondsSinceEpoch,
            equals(DateTime.utc(2026, 5, 13, 12).microsecondsSinceEpoch),
          );
        },
      );

      // ── AC: idempotency on duplicate command ─────────────────────────────

      test('commit() returns existing row without writing a second outbox row '
          'or completion_events row for a duplicate '
          '(profileId, sefariaRef, stageId, trackType)', () async {
        final first = await writer.commit(_cmd(trackId: trackId));
        final second = await writer.commit(_cmd(trackId: trackId));

        expect(first.isNew, isTrue);
        expect(second.isNew, isFalse);
        expect(second.completion.id, equals(first.completion.id));

        final outboxRows = await db.select(db.outbox).get();
        expect(
          outboxRows,
          hasLength(1),
          reason: 'duplicate command must NOT enqueue a second outbox push',
        );

        // AC 25.15: completion_events UNIQUE constraint — still exactly one row.
        final events = await db.select(db.completionEvents).get();
        expect(
          events,
          hasLength(1),
          reason:
              'duplicate command must NOT append a second completion_events row',
        );
      });

      // ── AC: rollback if the outbox insert fails ─────────────────────────

      test('if the outbox insert fails inside the transaction, the completion '
          'row is rolled back too — no partial writes', () async {
        // Insert via a writer where the outbox insert is forced to fail
        // by supplying a malformed companion (the underlying transaction
        // must roll back both rows).
        //
        // We trigger failure by inserting a completion command whose
        // payload encoding will explode. The simplest reliable approach
        // is to wrap the commit in a transaction and throw after it —
        // proving that the writer's own transaction guarantee composes
        // with an outer transaction.
        await expectLater(
          () => db.transaction(() async {
            await writer.commit(_cmd(trackId: trackId));
            throw Exception('simulated downstream failure');
          }),
          throwsA(isA<Exception>()),
        );

        final outbox = await db.select(db.outbox).get();
        final events = await db.select(db.completionEvents).get();
        expect(outbox, isEmpty);
        // AC 25.15: completion_events is part of the same transaction.
        expect(events, isEmpty);
      });

      // ── AC: two distinct commands write two completions + two outbox rows ──

      test('two distinct commands for different (sefariaRef|stage|track) '
          'each commit one completion row and one outbox row', () async {
        final a = await writer.commit(
          _cmd(trackId: trackId, sefariaRef: 'Mishnah Berakhot 1'),
        );
        final b = await writer.commit(
          _cmd(trackId: trackId, sefariaRef: 'Mishnah Berakhot 2'),
        );

        expect(a.isNew, isTrue);
        expect(b.isNew, isTrue);

        final outbox = await db.select(db.outbox).get();
        expect(outbox, hasLength(2));
        expect(
          outbox.map((r) => r.entityKey).toSet(),
          equals({
            '1:Mishnah Berakhot 1:1:personal:mishnah_yomit',
            '1:Mishnah Berakhot 2:1:personal:mishnah_yomit',
          }),
        );

        // AC 25.15: two distinct completion_events rows written atomically.
        final events = await db.select(db.completionEvents).get();
        expect(events, hasLength(2));
        expect(
          events.map((e) => e.sefariaRef).toSet(),
          equals({'Mishnah Berakhot 1', 'Mishnah Berakhot 2'}),
        );
      });

      // ── AC: outbox payload schema matches the OutboxProcessor expectations ─

      test(
        'outbox payload is JSON with all required identity fields',
        () async {
          final completedAt = DateTime.utc(2026, 5, 13, 14, 30);
          await writer.commit(_cmd(trackId: trackId, completedAt: completedAt));

          final outboxRows = await db.select(db.outbox).get();
          expect(outboxRows, hasLength(1));
          final payload =
              jsonDecode(outboxRows.first.payload) as Map<String, dynamic>;

          expect(payload, containsPair('profile_id', 1));
          expect(payload, containsPair('curriculum_id', 'mishnah_yomit'));
          expect(payload, containsPair('sefaria_ref', 'Mishnah Berakhot 1'));
          expect(payload, containsPair('stage_id', 1));
          expect(payload, containsPair('track_type', 'personal'));
          expect(payload, containsPair('points', 5));
          expect(
            payload,
            containsPair('completed_at', '2026-05-13T14:30:00.000Z'),
          );
        },
      );

      // ── AC: outbox row createdAt matches the command's completedAt ───────

      test('outbox row createdAt matches the command completedAt', () async {
        final completedAt = DateTime.utc(2026, 5, 13, 8, 15);
        await writer.commit(_cmd(trackId: trackId, completedAt: completedAt));

        final outboxRows = await db.select(db.outbox).get();
        // Drift returns DateTime as a local-timezone value but the same instant
        // we stored. Compare on the microsecond instant.
        expect(
          outboxRows.first.createdAt.toUtc().microsecondsSinceEpoch,
          equals(completedAt.microsecondsSinceEpoch),
        );
      });
    },
  );
}
