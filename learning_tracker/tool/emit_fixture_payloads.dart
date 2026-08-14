/// Emits canonical per-collection write-payload fixtures to stdout as JSON.
///
/// Run from learning_tracker/:
///   PATH=/home/daniel/flutter/bin:$PATH dart run tool/emit_fixture_payloads.dart \
///     > functions/test/fixtures/write_payloads.json
///
/// Re-run whenever a codec's encode() changes so the emulator test fixtures
/// stay in sync with the live write shapes.
///
/// Design:
///   - For collections with a codec, we call codec.encode() on a representative
///     model instance. This is the pull/read shape (what Firestore returns).
///   - For collections where the push shape differs (learning_ledger, goals,
///     bookmarks, curriculum_tracks, profile_programs, learning_order), we use
///     the LocalDataUploadService map literal shape (the actual write shape).
///   - Timestamps are encoded as ISO-8601 strings. The .mjs test suite
///     converts them back via convertTimestamps().
///   - The fixture PROFILE value is "5" (string) matching PROFILE = '5' in the
///     test suite, which mirrors the Firestore subcollection path segment.
// ignore_for_file: avoid_print
library;

import 'dart:convert';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

void main() {
  final past = DateTime.utc(2020, 1, 1);

  // completions — codec encode() shape (what the outbox processor writes).
  final completions = {
    ...CompletionEntity(
      curriculumId: CurriculumId.mishnayos,
      sefariaRef: 'Berakhot.2a',
      stageId: 1,
      trackType: 'personal',
      source: CompletionSource.live,
      completedAt: past,
      points: 10,
    ).toFirestore(),
    // CompletionEntity.toFirestore() uses a DateTime for the Firestore SDK;
    // this CLI serializes the same payload as JSON for the emulator fixture.
    'completed_at': past.toIso8601String(),
  };

  // bookmarks — minimal codec encode() shape (curriculum_id, sefaria_ref,
  // updated_at). The rules hasOnly also allows profile_id, content_item_id,
  // stage_id — kept out of the fixture to reflect the actual write path.
  final bookmarks = BookmarkEntity(
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: 'Berakhot.2a',
    updatedAt: past,
  ).toFirestore();

  // settings — open bag; minimal codec encode() shape.
  final settings = <String, dynamic>{
    'curriculum_id': CurriculumId.mishnayos.storageKey,
    'updated_at': past.toIso8601String(),
  };

  // curriculum_tracks — LocalDataUploadService shape (includes profile_id,
  // track_id which the codec's encode() omits but the live write includes).
  // Note: profile_id and track_id are written as strings (path segment
  // values) to match the PROFILE = '5' test constant.
  final curriculumTracks = <String, dynamic>{
    'profile_id': '5',
    'track_id': '1',
    'curriculum_id': 'c1',
    'state': 'active',
    'state_changed_at': past.toIso8601String(),
    'activated_at': past.toIso8601String(),
  };

  // stage_definitions — codec encode() shape.
  final stageDefinitions = const StageDefinition(
    curriculumId: CurriculumId.mishnayos,
    stageOrder: 1,
    stageName: 'Stage 1',
    delayDays: 7,
    isDefault: true,
    scheduleType: ScheduleType.delay,
  ).toFirestore(updatedAt: past);

  // study_day_configs — codec encode() shape.
  final studyDayConfigsOut = const StudyDayConfigEntry(
    dayOfWeek: 1,
    dayType: DayType.study,
  ).toFirestore(
    curriculumId: CurriculumId.mishnayos,
    updatedAt: past,
  );

  // goals — GoalCodec.encode() shape (the widest valid set for hasOnly).
  // Note: GoalRow.profileId is int; the test constant is string '5'. We emit
  // the string form to match the path segment.
  final goal = GoalEntity(
    curriculumId: CurriculumId.mishnayos,
    updatedAt: past,
    createdAt: past,
    paceValue: 2,
    pacePeriod: 'daily',
    targetDate: DateTime.utc(2025, 12, 31),
    description: 'Finish Berakhot',
    targetPercent: 80,
    dateType: 'fixed',
    goalType: 'completion',
  );
  // The current repository injects the stable entity identity as `id` before
  // writing; preserve that current write shape in the fixture.
  final goals = {
    'id': goal.firestoreId,
    ...goal.toFirestore(),
  };

  // learning_order — codec encode() shape.
  final learningOrder = <String, dynamic>{
    'curriculum_id': CurriculumId.mishnayos.storageKey,
    'sefaria_ref': 'Berakhot.2a',
    'user_sort_order': 1,
    'updated_at': past.toIso8601String(),
  };

  // profile_programs — LocalDataUploadService shape (enqueueProfileProgram).
  // The codec encode() also produces the same keys so either is fine.
  final profileProgramsOut = ProfileProgramEntity(
    curriculumId: CurriculumId.mishnayos,
    programId: 1,
    trackingStartDate: past,
    trackingStartRef: 'Berakhot.2a',
    updatedAt: past,
  ).toFirestore(profileId: '5');

  // learning_ledger — LocalDataUploadService enqueueLedgerEntry map literal.
  // The codec encode() shape is the PULL shape (sefaria_ref, entry_type,
  // points) and differs from the PUSH shape. No hasOnly rule exists for this
  // collection so either is valid, but we use the push shape as it is more
  // representative.
  final learningLedgerOut = {
    ...LearningLedgerEntry(
      ulid: 'ULID0001',
      curriculumId: CurriculumId.mishnayos,
      entryScope: 'unit',
      unitIdentifier: 'Berakhot.2a',
      unitDisplayNameHe: 'ברכות ב',
      unitDisplayNameEn: 'Berakhot 2',
      trackType: 'personal',
      completedAt: past,
      completionNumber: 1,
      markedBy: '5',
      isManual: false,
      source: CompletionSource.live,
    ).toFirestore(),
    'completed_at': past.toIso8601String(),
  };

  // import_metadata — direct map (no codec; written by FirestoreGatewayImpl).
  final importMetadata = <String, dynamic>{
    'profile_id': '5',
    'curriculum_id': 'c1',
    'item_count': 50,
    'imported_at': past.toIso8601String(),
  };

  // streak_events — LocalDataUploadService enqueueStreakPayload shape.
  final streakEvents = <String, dynamic>{
    'ulid': 'ULID0002',
    'profile_id': '5',
    'event_type': 'study',
    'study_date': past.toIso8601String(),
    'created_at': past.toIso8601String(),
  };

  // points_ledger — PointsBalanceDao._ledgerPayload push shape (no codec;
  // AUD-firebase-05). Doc-id = ulid.
  final pointsLedgerEntry = <String, dynamic>{
    'ulid': 'ULID0003',
    'profile_id': '5',
    'entry_kind': 'redemption_debit',
    'delta': -50,
    'note': 'Redeemed: Extra screen time',
    'redemption_ulid': 'ULID0004',
    'created_at': past.toIso8601String(),
  };

  // reward_redemptions — PointsBalanceDao._pushRedemption push shape (no
  // codec; AUD-firebase-05). Doc-id = ulid. Unlike the append-only
  // collections above, this is an LWW state-machine doc — `status`
  // transitions pending_fulfilment -> fulfilled/declined via `update`.
  final rewardRedemptions = <String, dynamic>{
    'ulid': 'ULID0004',
    'profile_id': '5',
    'reward_title': 'Extra screen time',
    'icon_index': 2,
    'points_cost': 50,
    'status': 'pending_fulfilment',
    'created_at': past.toIso8601String(),
    'updated_at': past.toIso8601String(),
  };

  final payloads = <String, dynamic>{
    '_comment':
        'Canonical per-collection write-payload fixtures derived from Dart '
        'codec encode() outputs and LocalDataUploadService map literals. '
        'ISO-8601 timestamp strings are converted to Firestore Timestamp '
        'objects at test runtime by convertTimestamps(). '
        'Re-generate with: dart run tool/emit_fixture_payloads.dart '
        '> functions/test/fixtures/write_payloads.json',
    'completions': completions,
    'bookmarks': bookmarks,
    'settings': settings,
    'curriculum_tracks': curriculumTracks,
    'stage_definitions': stageDefinitions,
    'study_day_configs': studyDayConfigsOut,
    'goals': goals,
    'learning_order': learningOrder,
    'profile_programs': profileProgramsOut,
    'learning_ledger': learningLedgerOut,
    'import_metadata': importMetadata,
    'streak_events': streakEvents,
    'points_ledger': pointsLedgerEntry,
    'reward_redemptions': rewardRedemptions,
  };

  print(const JsonEncoder.withIndent('  ').convert(payloads));
}
