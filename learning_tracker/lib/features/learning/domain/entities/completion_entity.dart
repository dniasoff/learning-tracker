import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

/// Domain model for one `completions/{completionId}` document
/// (`docs/firestore-rewrite-map.md`, `firestore.rules` `match
/// /completions/{completionId}`).
///
/// **Firestore-shaped — not a port of the Drift-era `Completion` class**
/// (`lib/core/database/daos/completion_dao.dart`). That class carries an
/// autoincrement `id` (a per-device SQLite counter with no cross-device
/// meaning), an `int profileId` (redundant — the profile is already the
/// path segment above this subcollection, same reasoning
/// `LearningLedgerEntry` gives for omitting it), and an `int trackId` (AD-25
/// retired the per-device track id; `curriculumId` is the sole canonical
/// stable track key — writing `track_id` here would trip
/// `tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart`). None of the
/// three survive here.
///
/// **`stageId` is expected to hold a `stage_order` value, not a Drift
/// row id.** Mirrors the AD-25 re-key `stage_definitions` already went
/// through (`{curriculumId}_{stageOrder}` doc-ids) — a real Firestore stage
/// has no integer row id (see `kFirestoreUnmappedStageId`'s doc comment in
/// `stage_definition.dart`). The field keeps the name `stageId` only
/// because that is what `firestore.rules`, `doc_ids.dart`, and every
/// existing production document already call it — renaming the wire field
/// would be an unrelated schema change.
///
/// **`source` is new** — `docs/firestore-rewrite-map.md`'s "RESOLVED:
/// prior-import tier tracking" section. Replaces the entire Drift
/// `PriorCompletionImports` apparatus (a correlated `EXISTS` subquery behind
/// 8 `CompletionDao.getCompletionsByTier` call sites) with a plain field.
/// Only [CompletionSource.live] and [CompletionSource.bulkInTrack] are
/// valid here — [CompletionSource.lifetimeOnly] writes **only** a
/// `learning_ledger` entry and must never reach this collection (enforced
/// by [FirestoreCompletionRepository.recordCompletion] /
/// `recordCompletionsBatch`, not by this model — a model has no way to
/// throw during construction of a `const` object without losing the
/// `const` constructor other entities in this codebase keep).
///
/// **A completion, once created, is never updated.** `firestore.rules`
/// permits `update` only as a byte-identical replay (SR-1); there is no
/// `copyWith` here because there is nothing this entity is ever legitimately
/// asked to change after creation — see
/// `FirestoreCompletionRepository.recordCompletion`'s class-level doc
/// comment for the idempotent-retry implications.
class CompletionEntity {
  const CompletionEntity({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    required this.source,
    required this.completedAt,
    this.points = 0,
  });

  final CurriculumId curriculumId;
  final String sefariaRef;

  /// A `stage_order` ordinal (1..10), NOT a Drift row id — see the class
  /// doc comment.
  final int stageId;

  /// `'personal'` in v1 — plain `String`, matching every other track-type
  /// field in this codebase (no enum exists for it; see
  /// `LearningLedgerEntry.trackType`'s doc comment for the same note).
  final String trackType;

  /// [CompletionSource.live] or [CompletionSource.bulkInTrack] only — see
  /// the class doc comment.
  final CompletionSource source;

  /// The real completion moment (UTC). `firestore.rules` compares this
  /// against `request.time`, so it MUST round-trip as a real Firestore
  /// `timestamp` — see [CompletionEntityFirestoreCodec.toFirestore]'s doc
  /// comment.
  final DateTime completedAt;

  /// Gamification points awarded. `firestore.rules` validates `0 <= points
  /// <= 100` *when the field is present* — always written here (defaulting
  /// to `0`, matching the Drift column's default) rather than omitted.
  final int points;
}

/// Firestore document codec for `completions/{completionId}`. Self-contained
/// (no `cloud_firestore` import — mirrors `StageDefinitionFirestoreCodec` /
/// `LearningLedgerEntryFirestoreCodec`; "entity owns its codec" per
/// `docs/firestore-rewrite-map.md`'s AD-23 constraint note).
///
/// **`completed_at` is a raw [DateTime], NOT
/// `FirestoreCodec.encodeDateTime`'s ISO-8601 `String`.** This is the
/// single highest-stakes line in this whole rewrite surface:
/// `firestore.rules`' `completions` create rule compares
/// `request.resource.data.completed_at <= request.time`, and a Firestore
/// rules comparison between a `string` and a `timestamp` evaluates to
/// **deny** — not an error, a silent reject of every single completion
/// write in production. A raw [DateTime] here is auto-converted to a real
/// `timestamp` by the `cloud_firestore` SDK on write (confirmed against
/// `fake_cloud_firestore`'s own write-time transform, which mirrors the
/// real SDK). See [FirestoreCompletionRepository]'s class doc comment for
/// the matching read-side `Timestamp` → UTC `DateTime` normalization this
/// requires (`Timestamp.toDate()` returns LOCAL time).
///
/// **No `profile_id`, no `track_id` in the payload** — see the class doc
/// comment.
extension CompletionEntityFirestoreCodec on CompletionEntity {
  Map<String, dynamic> toFirestore() => {
    'curriculum_id': curriculumId.storageKey,
    'sefaria_ref': sefariaRef,
    'stage_id': stageId,
    'track_type': trackType,
    'source': source.name,
    'completed_at': completedAt.toUtc(),
    'points': points,
  };
}

/// Decodes a `completions/{completionId}` document into a [CompletionEntity].
///
/// [data]'s `completed_at` must already be a [DateTime] by the time it
/// reaches here — see [FirestoreCompletionRepository]'s class doc comment
/// for why the repository, not this function, converts a real Firestore
/// `Timestamp` object back into one first. [FirestoreCodec.parseDateTime]
/// still handles either shape (its `raw is DateTime` branch), so this
/// function itself needs no `cloud_firestore` import.
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` or `source`,
/// and [FormatException] for any other missing required field or a
/// `source == 'lifetimeOnly'` document (which should never exist in this
/// collection — see the class doc comment) — all caller-visible decode
/// failures by design, surfaced via `resilientQueryStream`'s per-document
/// error handling (skips just that document) or
/// [FirestoreCompletionRepository]'s one-shot-read leniency, never silently
/// defaulted. Mirrors `learningLedgerEntryFromFirestore`'s error-shape split
/// exactly.
CompletionEntity completionEntityFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final sourceRaw = data['source'] as String?;
  CompletionSource? source;
  for (final candidate in CompletionSource.values) {
    if (candidate.name == sourceRaw) {
      source = candidate;
      break;
    }
  }
  if (source == null) {
    throw ArgumentError('Unknown completion source: $sourceRaw');
  }
  if (source == CompletionSource.lifetimeOnly) {
    throw FormatException(
      'completions document has source=lifetimeOnly, which must never be '
      'written to this collection (lifetimeOnly writes only a '
      'learning_ledger entry): $data',
    );
  }

  final sefariaRef = data['sefaria_ref'] as String?;
  final stageId = FirestoreCodec.parseInt(data['stage_id']);
  final trackType = data['track_type'] as String?;
  final completedAt = FirestoreCodec.parseDateTime(data['completed_at']);
  if (sefariaRef == null ||
      stageId == null ||
      trackType == null ||
      completedAt == null) {
    throw FormatException(
      'completions document missing a required field: $data',
    );
  }

  return CompletionEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: trackType,
    source: source,
    completedAt: completedAt,
    points: FirestoreCodec.parseInt(data['points']) ?? 0,
  );
}
