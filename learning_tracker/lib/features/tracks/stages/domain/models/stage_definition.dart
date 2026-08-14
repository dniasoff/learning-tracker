import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

part 'stage_definition.freezed.dart';

/// Domain model for a stage definition.
///
/// Represents a learning stage (e.g., Learn, Chazara 1) within a curriculum,
/// with ordering and scheduling configuration per D3.
///
/// Three schedule types are supported:
/// - [ScheduleType.delay]: item due X days after previous stage completion
/// - [ScheduleType.weekly]: review on specific days of the week
/// - [ScheduleType.rolling]: always review the last N items
///
/// ### ScheduleSpec
/// Use `.schedule` (via the [StageDefinitionScheduleSpec] extension) to get
/// the strongly-typed sealed [ScheduleSpec] that encapsulates the quartet
/// fields. The raw fields exist only for Drift-column mapping (W3.27 will
/// collapse them into a single JSON column).
@freezed
abstract class StageDefinition with _$StageDefinition {
  const factory StageDefinition({
    required CurriculumId curriculumId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    required bool isDefault,
    @Default(ScheduleType.delay) ScheduleType scheduleType,
    List<int>? daysOfWeek,
    int? rollingWindowSize,
  }) = _StageDefinition;
}

/// Extension that surfaces [ScheduleSpec] on [StageDefinition] without
/// requiring Freezed code-gen to be re-run (W4.10).
///
/// Until W3.27 collapses the quartet into a single JSON column, consumers
/// should use [schedule] instead of accessing the raw fields directly.
extension StageDefinitionScheduleSpec on StageDefinition {
  /// Returns the strongly-typed [ScheduleSpec] encapsulating the schedule
  /// quartet fields ([scheduleType], [delayDays], [daysOfWeek], [rollingWindowSize]).
  ScheduleSpec get schedule => ScheduleSpec.fromParts(
    scheduleTypeKey: scheduleType.storageKey,
    delayDays: delayDays,
    daysOfWeek: daysOfWeek,
    rollingWindowSize: rollingWindowSize,
  );
}

/// Firestore document codec for `stage_definitions/{curriculumId}_
/// {stageOrder}` (`docs/firestore-rewrite-map.md`, `firestore.rules`
/// `match /stage_definitions/{stageId}`).
///
/// New writes use the flat schedule fields (`schedule_type`, `delay_days`,
/// `days_of_week`, `rolling_window_size`) rather than the old sync engine's
/// single JSON-string `schedule` blob (`StageDefinitionCodec`, W3.27) —
/// Firestore documents are already structured; nesting a JSON string inside
/// a field is a Drift-single-column-era artifact this rewrite does not
/// need to perpetuate. Per the app's greenfield/no-back-compat premise,
/// [stageDefinitionFromFirestore] does NOT also parse that legacy blob
/// shape — a document missing `schedule_type` fails to decode (a clean,
/// explicit throw) rather than silently guessing at its meaning.
///
/// Deliberately omits `track_id` from the write shape — AD-25 retires the
/// per-device track id for this collection; `curriculum_id` is the sole
/// canonical stable track key. Writing the Drift-local `int` `track_id`
/// from a repository would also trip the MCF-11 autoincrement-id-in-payload
/// ratchet (`tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart`) as
/// a brand-new site outside `lib/core/sync/merge/`.
extension StageDefinitionFirestoreCodec on StageDefinition {
  /// Encodes this stage for a Firestore write.
  Map<String, dynamic> toFirestore({required DateTime updatedAt}) {
    final spec = schedule;
    return {
      'curriculum_id': curriculumId.storageKey,
      'stage_order': stageOrder,
      'stage_name': stageName,
      'schedule_type': spec.storageKey,
      'delay_days': spec.delayDays,
      if (spec.daysOfWeek != null) 'days_of_week': spec.daysOfWeek,
      if (spec.rollingWindowSize != null)
        'rolling_window_size': spec.rollingWindowSize,
      'is_default': isDefault,
      'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
    };
  }
}

/// Decodes a `stage_definitions/{curriculumId}_{stageOrder}` document into
/// a [StageDefinition]. See [StageDefinitionFirestoreCodec] for the write
/// side and why this does not also handle the legacy JSON-string `schedule`
/// blob shape.
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` and
/// [FormatException] for a missing/invalid `schedule_type` — both are
/// caller-visible decode failures by design (e.g. surfaced via
/// `resilientQueryStream`'s per-document error handling, which skips just
/// that document rather than the whole result), never silently defaulted.
StageDefinition stageDefinitionFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final scheduleTypeKey = data['schedule_type'] as String?;
  if (scheduleTypeKey == null) {
    throw FormatException(
      'stage_definitions document missing schedule_type: $data',
    );
  }

  return StageDefinition(
    curriculumId: curriculumId,
    stageOrder: FirestoreCodec.parseInt(data['stage_order']) ?? 0,
    stageName: data['stage_name'] as String? ?? '',
    delayDays: FirestoreCodec.parseInt(data['delay_days']) ?? 0,
    isDefault: FirestoreCodec.parseBool(data['is_default']) ?? false,
    scheduleType: ScheduleType.fromStorageKey(scheduleTypeKey),
    daysOfWeek: (data['days_of_week'] as List?)?.cast<int>(),
    rollingWindowSize: FirestoreCodec.parseInt(data['rolling_window_size']),
  );
}
