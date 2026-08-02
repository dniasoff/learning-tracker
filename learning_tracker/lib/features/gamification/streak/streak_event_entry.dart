import 'package:learning_tracker/core/codec/firestore_codec.dart';

/// Domain model for one append-only `streak_events/{ulid}` document
/// (`docs/firestore-rewrite-map.md`, `firestore.rules` `match
/// /streak_events/{streakEventId}`).
///
/// **Distinct from [StreakLogEvent]** (`streak_log_event.dart`), which is
/// the Drift-DAO-adjacent value type `StreakEventLog.append` consumes — it
/// carries a Drift-local `int profileId` and has no [ulid]. This type is
/// Firestore-shaped instead:
///
/// - **No `profileId` field.** The profile is already the path segment
///   above this subcollection (`users/{uid}/learner_profiles/{profileId}/
///   streak_events/{ulid}`) — repeating it inside the document would be
///   pure redundancy, and [StreakEventEntry] carries no Drift-local `int`
///   to repeat regardless.
/// - **[ulid] is new** — this entry's identity, and IS the Firestore doc-id
///   (`DocIds.streakEventDocId`).
///
/// **Natural-key dedup is NOT automatic here — a real behavior change from
/// Drift, flagged, not silently dropped.** The Drift `StreakEvents` table
/// declares `UNIQUE (profileId, dayUtc, eventType)` and
/// `StreakEventLog.append` inserts with `InsertMode.insertOrIgnore`, so two
/// calls for the same logical day-event collapse to one row automatically.
/// `DocIds.streakEventDocId` — the pinned, golden-tested doc-id formula —
/// keys this collection by [ulid] alone, not by `(dayUtc, eventType)`, so
/// the Firestore doc-id only makes a RETRY of the *same* call idempotent
/// (the caller reuses the same [ulid]); it does **not** collapse two
/// independently-triggered events for the same day the way the Drift UNIQUE
/// index did. A caller that needs "already logged today?" semantics must
/// check first — see [FirestoreStreakEventRepository.getEventsForDay].
class StreakEventEntry {
  const StreakEventEntry({
    required this.ulid,
    required this.eventType,
    required this.dayUtc,
    required this.eventTimestamp,
    this.clientDeviceId,
  });

  /// This entry's identity — also its Firestore doc-id
  /// (`DocIds.streakEventDocId`, keyed off this same value).
  final String ulid;

  /// `'completion'` | `'day_boundary'` | `'manual_adjust'`. Plain `String`,
  /// matching the Drift column and [StreakLogEvent] — no enum exists for
  /// this field.
  final String eventType;

  /// UTC date this event belongs to, normalised to midnight — the
  /// dedup-relevant natural-key component (see the class doc comment for
  /// why the Firestore doc-id no longer enforces that dedup automatically).
  final DateTime dayUtc;

  /// UTC timestamp of the real-world moment the event occurred. Used for
  /// ordering inside a single day.
  final DateTime eventTimestamp;

  /// Optional device hint for diagnostics. No security bearing.
  final String? clientDeviceId;
}

/// Firestore document codec for `streak_events/{ulid}`. Self-contained —
/// deliberately does NOT route through the old sync-engine
/// `StreakEventCodec` (`lib/core/sync/codec/streak_event_codec.dart`): that
/// codec embeds `profile_id` (redundant here — see the class doc comment
/// above) and targets the pre-ULID-doc-id `study_date`/`created_at` field
/// names, and the whole `lib/core/sync/codec/` module is itself marked for
/// deletion once the sync engine goes (`docs/firestore-rewrite-map.md`,
/// "Deleted concepts"). Mirrors the self-contained
/// `StageDefinitionFirestoreCodec` / `stageDefinitionFromFirestore` pattern
/// instead.
extension StreakEventEntryFirestoreCodec on StreakEventEntry {
  Map<String, dynamic> toFirestore() => {
    'ulid': ulid,
    'event_type': eventType,
    'day_utc': FirestoreCodec.encodeDateTime(dayUtc),
    'event_timestamp': FirestoreCodec.encodeDateTime(eventTimestamp),
    if (clientDeviceId != null) 'client_device_id': clientDeviceId,
  };
}

/// Decodes a `streak_events/{ulid}` document into a [StreakEventEntry].
///
/// Throws [FormatException] for a missing required field — a
/// caller-visible decode failure by design, surfaced via
/// `resilientQueryStream`'s per-document error handling (skips just that
/// document) or `FirestoreStreakEventRepository`'s one-shot-read leniency,
/// never silently defaulted.
StreakEventEntry streakEventEntryFromFirestore(Map<String, dynamic> data) {
  final ulid = data['ulid'] as String?;
  final eventType = data['event_type'] as String?;
  final dayUtc = FirestoreCodec.parseDateTime(data['day_utc']);
  final eventTimestamp = FirestoreCodec.parseDateTime(data['event_timestamp']);
  if (ulid == null ||
      eventType == null ||
      dayUtc == null ||
      eventTimestamp == null) {
    throw FormatException(
      'streak_events document missing a required field: $data',
    );
  }

  return StreakEventEntry(
    ulid: ulid,
    eventType: eventType,
    dayUtc: dayUtc,
    eventTimestamp: eventTimestamp,
    clientDeviceId: data['client_device_id'] as String?,
  );
}
