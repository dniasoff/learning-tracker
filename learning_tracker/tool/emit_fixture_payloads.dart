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

import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/codec/completion_event_codec.dart';
import 'package:learning_tracker/core/sync/codec/goal_codec.dart';
import 'package:learning_tracker/core/sync/codec/learning_ledger_codec.dart';
import 'package:learning_tracker/core/sync/codec/learning_order_codec.dart';
import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/codec/study_day_config_codec.dart';

void main() {
  final past = DateTime.utc(2020, 1, 1);

  // completions — codec encode() shape (what the outbox processor writes).
  final completions = const CompletionEventCodec().encode(
    CompletionEventRow(
      curriculumId: 'c1',
      sefariaRef: 'Berakhot.2a',
      stageId: 1,
      trackType: 'primary',
      eventTimestamp: past,
      points: 10,
    ),
  );

  // bookmarks — minimal codec encode() shape (curriculum_id, sefaria_ref,
  // updated_at). The rules hasOnly also allows profile_id, content_item_id,
  // stage_id — kept out of the fixture to reflect the actual write path.
  final bookmarks = const BookmarkCodec().encode(
    BookmarkRow(curriculumId: 'c1', sefariaRef: 'Berakhot.2a', updatedAt: past),
  );

  // settings — open bag; minimal codec encode() shape.
  final settings = const SettingsCodec().encode(
    SettingsRow(curriculumId: 'c1', updatedAt: past),
  );

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
  final stageDefinitions = const StageDefinitionCodec().encode(
    StageDefinitionRow(
      curriculumId: 'c1',
      trackId: 1,
      stageOrder: 1,
      stageName: 'Stage 1',
      schedule: '{"type":"delay","delay_days":7}',
      isDefault: true,
      updatedAt: past,
    ),
  );

  // study_day_configs — codec encode() shape.
  final studyDayConfigs = const StudyDayConfigCodec().encode(
    StudyDayConfigRow(
      profileId: 5,
      curriculumId: 'c1',
      trackId: 1,
      dayOfWeek: 1,
      dayType: 'study',
      updatedAt: past,
    ),
  );
  // Cast profile_id to string to match test constant '5'.
  final studyDayConfigsOut = {
    ...studyDayConfigs,
    'profile_id': '${studyDayConfigs["profile_id"]}',
  };

  // goals — GoalCodec.encode() shape (the widest valid set for hasOnly).
  // Note: GoalRow.profileId is int; the test constant is string '5'. We emit
  // the string form to match the path segment.
  final goalEncoded = const GoalCodec().encode(
    GoalRow(
      firestoreId: 'g1',
      profileId: 5,
      curriculumId: 'c1',
      updatedAt: past,
      createdAt: past,
      paceValue: 2,
      pacePeriod: 'daily',
      targetDate: DateTime.utc(2025, 12, 31),
    ),
  );
  // Augment with additional LocalDataUploadService fields (description, id,
  // goal_type, date_type, target_percent, track_id) which also need to pass
  // the hasOnly() whitelist. Override profile_id to string '5'.
  final goals = {
    'id': 'g1',
    ...goalEncoded,
    'profile_id': '5',
    'track_id': '1',
    'description': 'Finish Berakhot',
    'target_percent': 80,
    'date_type': 'fixed',
    'goal_type': 'completion',
  };

  // learning_order — codec encode() shape.
  final learningOrder = const LearningOrderCodec().encode(
    LearningOrderRow(
      curriculumId: 'c1',
      sefariaRef: 'Berakhot.2a',
      userSortOrder: 1,
      updatedAt: past,
    ),
  );

  // profile_programs — LocalDataUploadService shape (enqueueProfileProgram).
  // The codec encode() also produces the same keys so either is fine.
  final profilePrograms = const ProfileProgramCodec().encode(
    ProfileProgramRow(
      profileId: 5,
      curriculumId: 'c1',
      programId: 1,
      trackingStartDate: past,
      trackingStartRef: 'Berakhot.2a',
    ),
  );
  // Override profile_id to string '5' to match path segment constant.
  final profileProgramsOut = {
    ...profilePrograms,
    'profile_id': '${profilePrograms["profile_id"]}',
    'program_id': profilePrograms['program_id'],
  };

  // learning_ledger — LocalDataUploadService enqueueLedgerEntry map literal.
  // The codec encode() shape is the PULL shape (sefaria_ref, entry_type,
  // points) and differs from the PUSH shape. No hasOnly rule exists for this
  // collection so either is valid, but we use the push shape as it is more
  // representative.
  final learningLedger = const LearningLedgerCodec().encode(
    LearningLedgerRow(
      ulid: 'ULID0001',
      profileId: 5,
      curriculumId: 'c1',
      sefariaRef: 'Berakhot.2a',
      entryType: 'completion',
      points: 10,
      createdAt: past,
    ),
  );
  // Augment with the LocalDataUploadService push-shape fields.
  final learningLedgerOut = {
    'ulid': 'ULID0001',
    'profile_id': '5',
    'curriculum_id': 'c1',
    'entry_scope': 'unit',
    'unit_identifier': 'Berakhot.2a',
    'unit_display_name_he': 'ברכות ב',
    'unit_display_name_en': 'Berakhot 2',
    'track_type': 'primary',
    'track_id': '1',
    'completed_at': past.toIso8601String(),
    'completion_number': 1,
    'marked_by': 'self',
    'is_manual': false,
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

  // Unused: learningLedger (codec shape); use learningLedgerOut instead.
  // The local binding prevents the `unused_local_variable` analyzer warning.
  // ignore: unused_local_variable
  final droppedCodecShape = learningLedger;

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
  };

  print(const JsonEncoder.withIndent('  ').convert(payloads));
}
