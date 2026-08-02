import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

/// Domain model for one append-only `learning_ledger/{ulid}` entry
/// (`docs/firestore-rewrite-map.md`, `firestore.rules` `match
/// /learning_ledger/{entryId}`).
///
/// **Firestore-shaped — there is no Drift equivalent to port from.**
/// `LearningLedgerRepository` (the Drift-era interface,
/// `lib/features/learning/domain/repositories/learning_ledger_repository.dart`)
/// returns the raw generated Drift row type (`LearningLedgerData`) in its
/// public surface; it never had its own domain model. This is that model,
/// built directly against the Firestore shape rather than adapted from the
/// Drift one:
///
/// - **No autoincrement `id`.** The Drift row's `IntColumn id => integer()
///   .autoIncrement()()` is a per-device SQLite counter with no cross-device
///   meaning; [ulid] is this entry's only identity, and IS the Firestore
///   doc-id (`DocIds.learningLedgerDocId`).
/// - **No `trackId`.** The Drift table carries a nullable `trackId` FK
///   (`ON DELETE SET NULL`) purely as a Drift-cascade workaround. Firestore
///   has no cascade-delete to work around, and AD-25 retired per-device
///   track ids from every synced payload (MCF-11) — writing one here would
///   trip `tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart` as a
///   brand-new site. [curriculumId] is kept (see below); the FK is not.
/// - **`markedBy` is a learner-profile ULID `String`, not a Drift `int`.**
///   The Drift column stores the local autoincrement id of the profile that
///   performed the marking (relevant when a parent marks on behalf of a
///   child profile in the same account). AD-24 makes the learner-profile
///   ULID (`learner_profiles/{profileId}`) the sole cross-device identity
///   for a profile, so that is what this field carries.
/// - **No `createdAt`.** The Drift column just stamped local insertion wall
///   time (`currentDateAndTime`) — redundant here: [ulid] already encodes
///   its own creation instant to millisecond resolution (it is a ULID), and
///   `FirestoreLearningLedgerRepository` orders/paginates by the doc-id
///   (`FieldPath.documentId()`) for exactly that reason. Dropping it also
///   sidesteps a real correctness trap: a field the repository itself
///   stamped with the current wall-clock time on every call would silently break the
///   append-only "byte-identical replay" idempotency rule
///   (`firestore.rules`, SR-1) the moment a caller retries the same logical
///   write — see the repository's class doc comment for the corresponding
///   "do not stamp the current wall-clock time on retry" logic.
///
/// **[source] is new — added after the initial build, additively.** No
/// Drift column carried it (`CompletionSource` is a B1 write-time policy
/// discriminator, not a persisted `LearningLedger` column) but a downstream
/// consumer needs it: the bulk-mark-deletion Cloud Function must retract
/// only the lifetime ledger entries a bulk-mark created, never a `live`
/// entry that happens to share the same `(curriculumId, unitIdentifier)`
/// from a different track years earlier — and because
/// [completionNumber] means that collision is real and structurally
/// possible, there is no other field on this entry a deletion sweep could
/// safely key on. See [LearningLedgerEntryFirestoreCodec.toFirestore] for
/// the encoding and [learningLedgerEntryFromFirestore] for why a
/// missing/unrecognised value decodes as [CompletionSource.live] rather
/// than throwing — the fail-safe direction here is "never deletable",
/// not "best guess".
///
/// **`curriculumId` is deliberately KEPT despite the "no FK to tracks or
/// curricula" invariant.** `docs/firestore-rewrite-map.md` ("RESOLVED:
/// prior-import tier tracking...") states the ledger "deliberately has no
/// foreign keys to tracks or curricula so entries survive their deletion" —
/// that is about the Drift table's `.references(...)` cascade declarations,
/// not about the data itself. [curriculumId] is a plain [CurriculumId]
/// enum-vocabulary classification field (exactly like every other model in
/// this codebase), never a live reference to a `curriculum_tracks` document
/// — it stays meaningful and decodable after that document (or the whole
/// curriculum's tracks/stages/etc.) is deleted, which is the entire point
/// of the invariant.
class LearningLedgerEntry {
  const LearningLedgerEntry({
    required this.ulid,
    required this.curriculumId,
    required this.entryScope,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    required this.completedAt,
    required this.completionNumber,
    required this.markedBy,
    required this.isManual,
    required this.source,
  });

  /// This entry's identity — also its Firestore doc-id
  /// (`DocIds.learningLedgerDocId`, keyed off this same value).
  final String ulid;

  final CurriculumId curriculumId;

  /// Scope of the ledger entry: `'seder'` | `'masechta'` | `'sefer'`. Plain
  /// `String`, matching every other call site in the codebase — no enum
  /// exists for this field (see `CompletionDetectionService.unitScopeFor`).
  final String entryScope;

  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;

  /// `'personal'` in v1 — plain `String`, matching the Drift column and
  /// every other call site (no enum exists for this field either).
  final String trackType;

  /// The real completion moment, or the sentinel `kBulkPriorSentinelDate`
  /// (`lib/core/learning/completion_constants.dart`) for a non-live source.
  /// That policy decision (which `CompletionSource` credits engagement)
  /// belongs to the caller — this Firestore-shaped model just carries
  /// whatever value it is given.
  final DateTime completedAt;

  /// The nth lifetime completion of this `(curriculumId, unitIdentifier)`
  /// pair. This is the actual "lifetime learning statistics" feature the
  /// owner flagged as potentially very important
  /// (`docs/firestore-rewrite-map.md`) — do not weaken it.
  final int completionNumber;

  /// The learner-profile ULID (`learner_profiles/{profileId}`, AD-24) of
  /// who marked this entry.
  final String markedBy;

  final bool isManual;

  /// Which write-time policy tier produced this entry — `live` |
  /// `bulkInTrack` | `lifetimeOnly` (`CompletionSource`). Deterministic
  /// provenance, supplied by the caller (never derived from anything that
  /// varies between a write and its retry, e.g. wall-clock time or
  /// existing Firestore state) so it stays byte-identical across a retry
  /// of the same logical write — required for the append-only "identical
  /// replay only" update rule (SR-1) to keep accepting it. See the class
  /// doc comment's "[source] is new" section for why this exists.
  final CompletionSource source;
}

/// One row for [FirestoreLearningLedgerRepository.recordCompletionsBatch] —
/// the Firestore-shaped replacement for the Drift-era `LedgerManualBatchItem`
/// (`learning_ledger_repository.dart`). Same field-level changes as
/// [LearningLedgerEntry]: no `trackId`, `markedBy` is a profile ULID
/// `String`.
class LedgerEntryDraft {
  const LedgerEntryDraft({
    required this.curriculumId,
    required this.entryScope,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    required this.markedBy,
    required this.isManual,
    this.ulid,
  });

  final CurriculumId curriculumId;
  final String entryScope;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;
  final String markedBy;
  final bool isManual;

  /// Optional pre-minted ulid. Pass the SAME value across a retry of this
  /// exact draft so a duplicate call at least collapses onto the same
  /// doc-id — see
  /// `FirestoreLearningLedgerRepository.recordCompletionsBatch`'s class doc
  /// comment for why this alone does not make a whole-batch retry fully
  /// safe. Omit to have the repository mint one.
  final String? ulid;
}

/// Firestore document codec for `learning_ledger/{ulid}`
/// (`docs/firestore-rewrite-map.md`, `firestore.rules` `match
/// /learning_ledger/{entryId}`). Self-contained — deliberately does NOT
/// route through the old sync-engine `LearningLedgerCodec`
/// (`lib/core/sync/codec/learning_ledger_codec.dart`): that codec embeds
/// `profile_id` (redundant — the profile is already the path segment above
/// this subcollection) and `track_id` (retired, see the class doc comment),
/// and the whole `lib/core/sync/codec/` module is itself marked for
/// deletion once the sync engine goes (`docs/firestore-rewrite-map.md`,
/// "Deleted concepts"). Mirrors the self-contained
/// `StageDefinitionFirestoreCodec` / `stageDefinitionFromFirestore` pattern
/// (`lib/features/tracks/stages/domain/models/stage_definition.dart`)
/// instead.
///
/// **`completed_at` is a raw [DateTime], NOT
/// `FirestoreCodec.encodeDateTime`'s ISO-8601 `String`.** This is the one
/// deliberate divergence from the `StageDefinitionFirestoreCodec`/
/// `BookmarkEntity.toFirestore` pattern (both of which DO use
/// `FirestoreCodec.encodeDateTime` for their own date field) — and it
/// matters: `firestore.rules`' `learning_ledger` create rule (SR-3)
/// requires `completed_at is timestamp`, and a plain Dart `String` value
/// is type `string` in Firestore's eyes, not `timestamp` — writing a
/// String here would make every [FirestoreLearningLedgerRepository.
/// recordCompletion] call fail rules validation in production (verified:
/// `fake_cloud_firestore` auto-converts a raw [DateTime] document field
/// into a real `Timestamp` on write — see `mock_document_reference.dart`'s
/// `timestampFromDateTime` transform — which is also standard `cloud_firestore`
/// SDK behavior; a `String` gets no such conversion and stays a `string`).
/// `bookmarks`/`stage_definitions` have no such `is timestamp` guard on
/// their date field, so the String form is harmless there — it is NOT
/// harmless here. See [FirestoreLearningLedgerRepository]'s class doc
/// comment for the matching read-side handling this requires (the SDK
/// hands a `Timestamp` OBJECT back on read, which [FirestoreCodec.
/// parseDateTime] — deliberately free of any `cloud_firestore` import —
/// cannot decode on its own).
///
/// **`source` is written via [CompletionSource.name]** (`'live'` /
/// `'bulkInTrack'` / `'lifetimeOnly'`) — the Dart enum's own member name,
/// not a hand-rolled storage key. `CompletionSource`'s three member names
/// already ARE that exact camelCase vocabulary (unlike e.g. `CurriculumId`,
/// whose `storageKey` deliberately diverges from its Dart enum name into
/// snake_case), so `.name` is the single source of truth here — no second
/// mapping to keep in sync or typo. `learning_ledger`'s create rule has no
/// `.hasOnly()` field whitelist (verified against `firestore.rules`), so
/// adding this key needs no rules change.
extension LearningLedgerEntryFirestoreCodec on LearningLedgerEntry {
  /// Encodes this entry for a Firestore write. [ulid] IS included (unlike
  /// [StageDefinition.id], which is Drift-only and omitted) — it is this
  /// entry's real, permanent identity, not a device-local artifact.
  Map<String, dynamic> toFirestore() => {
    'ulid': ulid,
    'curriculum_id': curriculumId.storageKey,
    'entry_scope': entryScope,
    'unit_identifier': unitIdentifier,
    'unit_display_name_he': unitDisplayNameHe,
    'unit_display_name_en': unitDisplayNameEn,
    'track_type': trackType,
    'completed_at': completedAt.toUtc(),
    'completion_number': completionNumber,
    'marked_by': markedBy,
    'is_manual': isManual,
    'source': source.name,
  };
}

/// Decodes a `learning_ledger/{ulid}` document into a [LearningLedgerEntry].
///
/// [data]'s `completed_at` must already be a [DateTime] by the time it
/// reaches here — see [FirestoreLearningLedgerRepository]'s class doc
/// comment for why the repository, not this function, is responsible for
/// converting a real Firestore `Timestamp` object back into one first.
/// [FirestoreCodec.parseDateTime] still handles it either way (its `raw is
/// DateTime` branch), so this function itself needs no `cloud_firestore`
/// import.
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` and
/// [FormatException] for any other missing required field — both are
/// caller-visible decode failures by design, surfaced via
/// `resilientQueryStream`'s per-document error handling (skips just that
/// document) or `FirestoreLearningLedgerRepository`'s one-shot-read
/// leniency, never silently defaulted. Mirrors
/// `stageDefinitionFromFirestore`'s error-shape split exactly.
///
/// **`source` is the one exception to "never silently defaulted" — by
/// design, not oversight.** A document with no `source` key (written
/// before this field existed) or an unrecognised value decodes as
/// [CompletionSource.live] rather than throwing — see [_parseSource].
/// [CompletionSource.live] is the fail-SAFE default for this specific
/// field: it is the one value a bulk-mark-deletion sweep (`source ==
/// 'bulkInTrack'`) can never match, so an entry with unknown provenance is
/// never mistakenly treated as safe to delete. Throwing instead (like every
/// other field here) would be the wrong kind of strict — it would make a
/// pre-existing, perfectly valid entry invisible from every read
/// ([_decodeAll] skips a document whose decode throws) purely because it
/// predates this field, which is worse than decoding it into the
/// safe-by-construction default.
LearningLedgerEntry learningLedgerEntryFromFirestore(
  Map<String, dynamic> data,
) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final ulid = data['ulid'] as String?;
  final completedAt = FirestoreCodec.parseDateTime(data['completed_at']);
  final markedBy = data['marked_by'] as String?;
  if (ulid == null || completedAt == null || markedBy == null) {
    throw FormatException(
      'learning_ledger document missing a required field: $data',
    );
  }

  return LearningLedgerEntry(
    ulid: ulid,
    curriculumId: curriculumId,
    entryScope: data['entry_scope'] as String? ?? '',
    unitIdentifier: data['unit_identifier'] as String? ?? '',
    unitDisplayNameHe: data['unit_display_name_he'] as String? ?? '',
    unitDisplayNameEn: data['unit_display_name_en'] as String? ?? '',
    trackType: data['track_type'] as String? ?? '',
    completedAt: completedAt,
    completionNumber: FirestoreCodec.parseInt(data['completion_number']) ?? 1,
    markedBy: markedBy,
    isManual: FirestoreCodec.parseBool(data['is_manual']) ?? false,
    source: _parseSource(data['source']),
  );
}

/// Parses `source`, defaulting to [CompletionSource.live] when [raw] is
/// missing or does not match any [CompletionSource.name] — see
/// [learningLedgerEntryFromFirestore]'s doc comment for why this field
/// alone defaults instead of throwing.
CompletionSource _parseSource(Object? raw) {
  if (raw is String) {
    for (final value in CompletionSource.values) {
      if (value.name == raw) return value;
    }
  }
  return CompletionSource.live;
}
