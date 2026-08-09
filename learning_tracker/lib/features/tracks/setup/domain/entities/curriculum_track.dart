import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Domain entity for one curriculum track's lifecycle state.
///
/// **New for the Firestore rewrite** (`docs/firestore-rewrite-map.md`) — no
/// non-Drift domain model existed for `curriculum_tracks` before this file.
/// This entity is the merge point of TWO Drift DAOs
/// (`lib/core/database/daos/track_dao.dart`,
/// `lib/core/database/daos/active_curriculum_dao.dart`): in Firestore there
/// is one document per (profile, curriculum) and `state` is just a field on
/// it, so the "is this curriculum active" query `ActiveCurriculumDao` used
/// to run against a separate concept collapses into reading this same
/// document — see `FirestoreCurriculumTrackRepository`'s class doc comment
/// for the full absorption story.
///
/// One track per (profile, curriculum) since W3.22 (no `trackType`), so
/// [curriculumId] alone is the natural key (`DocIds.curriculumTrackDocId`).
class CurriculumTrackEntity {
  const CurriculumTrackEntity({
    required this.curriculumId,
    required this.state,
    required this.stateChangedAt,
    required this.activatedAt,
    this.paceResetDate,
    this.lastReorderAt,
    this.progressSchemaVersion,
    this.progressComputedAt,
    this.progressModel,
    this.programProgress,
    this.selfPacedProgress,
    this.syncedAt,
  });

  final CurriculumId curriculumId;

  /// Lifecycle state. Kept as a raw `String`, not a strict enum — same
  /// reasoning `TrackDao`'s own `state` column doc comment gives: the value
  /// must stay tolerant of a state string this build doesn't (yet)
  /// recognise, since `firestore.rules`' `curriculum_tracks` `.hasOnly()`
  /// gates only the KEY set, not the value of `state`. Use
  /// [CurriculumTrackState.fromStorageKey] / [isActive] for typed access to
  /// the known values this repository itself ever writes.
  ///
  /// **Only three values are reachable through this repository — not
  /// four.** Drift's `TrackState` had a fourth member, `deleted`, used as a
  /// soft-delete tombstone (`TrackDao.deleteTrackAndData`) because SQLite
  /// deletion needed to propagate to other devices through the (now
  /// deleted) LWW sync engine. In Firestore, deletion is a Cloud Function
  /// (`deleteCurriculumTrack`, `functions/src/deletes.ts`) that
  /// **hard-deletes** the document via `recursiveDelete` — there is no
  /// client-writable path to a `state == 'deleted'` document at all
  /// (`firestore.rules`: `allow delete: if false` — only the Admin SDK, which
  /// bypasses rules, can remove this document). A purged track's signal is
  /// therefore the document's ABSENCE ([FirestoreCurriculumTrackRepository
  /// .getTrack] returning `null`), not a tombstone value. This is a
  /// deliberate decision, not an oversight — see
  /// `docs/firestore-rewrite-map.md` ("RESOLVED: prior-import tier
  /// tracking...") for the parallel reasoning applied to completions.
  final String state;

  /// LWW timestamp for [state] in the old sync engine (`TrackCodec`'s
  /// `FB-2` comment). Kept as an ordinary client timestamp here, NOT
  /// force-overwritten with `FieldValue.serverTimestamp()` the way the old
  /// `FirestoreGatewayImpl.pushTrack` did it — that override existed only to
  /// protect a *cross-device merge* comparison, and the merge engine doing
  /// that comparison is a deleted concept (`docs/firestore-rewrite-map.md`,
  /// "Deleted concepts" — "one writer per account"). Every other repository
  /// in this rewrite (`FirestoreGoalRepository`, `FirestoreStageDefinition
  /// Repository`, etc.) already writes its own LWW-shaped timestamp as a
  /// plain client `DateTime`; this one is not a special case.
  final DateTime stateChangedAt;

  final DateTime activatedAt;

  /// Date the pace baseline was last reset (Reset Pace recovery action).
  /// `null` if never reset. Once set, this repository's [resetPace] only
  /// ever moves it forward — nothing clears it back to `null` (mirrors
  /// `TrackDao.resetPace`), so unlike e.g. `ProfileProgramEntity
  /// .trackingStartDate` there is no `FieldValue.delete()` field-clearing
  /// case to handle on this field.
  final DateTime? paceResetDate;
  final DateTime? lastReorderAt;

  // ── Decode-only passthrough fields ───────────────────────────────────
  //
  // `progress_schema_version` / `progress_computed_at` / `progress_model` /
  // `program_progress` / `self_paced_progress` are in `firestore.rules`'
  // `curriculum_tracks` `.hasOnly()` whitelist and in `tutor_writes.ts`'
  // `CURRICULUM_TRACK_ALLOWED_FIELDS`, but grepping the whole repo (`lib/`,
  // `functions/src/`) for them finds no producer or consumer anywhere
  // outside those two whitelists — no Drift table, no DAO, no other
  // repository computes or reads a "track progress" shape today. Rather
  // than invent a schema for a feature that does not exist yet, this
  // repository treats them as OPAQUE round-trip fields: decoded so a future
  // progress-writer's data survives a read-modify-write through this
  // repository, but never constructed or written by any method below (a
  // `SetOptions(merge: true)` write that never mentions these keys leaves
  // whatever a future writer already stamped untouched — see
  // `FirestoreProfileProgramRepository`'s class doc comment for the general
  // "merge doesn't clear omitted keys" mechanics this relies on). Whoever
  // builds the real progress-computation feature should replace this
  // passthrough with a typed shape, not extend it in place.
  final int? progressSchemaVersion;
  final DateTime? progressComputedAt;
  final String? progressModel;
  final Map<String, dynamic>? programProgress;
  final Map<String, dynamic>? selfPacedProgress;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` /
  /// the tutor-proxy CF at push time. Decode-only, like
  /// `ProfileProgramEntity.syncedAt`.
  final DateTime? syncedAt;

  /// True when [state] is the known `'active'` value.
  bool get isActive => state == CurriculumTrackState.active.storageKey;

  /// Encodes this track for a Firestore write.
  ///
  /// `profile_id` / `track_id` are deliberately NOT included, even though
  /// both are in the rules `.hasOnly()` whitelist and the OLD (pre-rewrite)
  /// `FirestoreGatewayImpl.pushTrack`/`TrackCodec.encode` wrote them: the
  /// document already lives at `.../learner_profiles/{profileId}/
  /// curriculum_tracks/{curriculumId}`, so profile identity is carried by
  /// the path (same reasoning as `BookmarkEntity`/`StageDefinition`'s
  /// `toFirestore` — unlike `ProfileProgramEntity`, which keeps `profile_id`
  /// only because it is the profile-scoped String ULID with an existing
  /// live writer to stay byte-compatible with; there is no equivalent
  /// live-writer reason here). `track_id` was always the Drift-local
  /// per-device autoincrement id AD-25 retired as this collection's
  /// identity — writing it would also trip the MCF-11
  /// autoincrement-id-in-payload ratchet
  /// (`tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart`) as a
  /// brand-new site.
  ///
  /// Progress passthrough fields are never written — see their field docs
  /// above.
  Map<String, dynamic> toFirestore() => {
    'curriculum_id': curriculumId.storageKey,
    'state': state,
    'state_changed_at': FirestoreCodec.encodeDateTime(stateChangedAt),
    'activated_at': FirestoreCodec.encodeDateTime(activatedAt),
    if (paceResetDate != null)
      'pace_reset_date': FirestoreCodec.encodeDateTime(paceResetDate),
    if (lastReorderAt != null)
      'last_reorder_at': FirestoreCodec.encodeDateTime(lastReorderAt),
  };
}

/// The lifecycle states [FirestoreCurriculumTrackRepository] itself ever
/// writes. See [CurriculumTrackEntity.state]'s doc comment for why the
/// entity's own field stays a tolerant raw `String` rather than this enum,
/// and for why `deleted` — a fourth Drift-era value — has no member here.
enum CurriculumTrackState {
  active('active'),
  retired('retired'),
  archived('archived');

  const CurriculumTrackState(this.storageKey);

  final String storageKey;

  /// Resolves [key] to a known member, or `null` for anything else
  /// (including the retired `'deleted'` value, and any forward-compat
  /// string this build doesn't recognise).
  static CurriculumTrackState? fromStorageKey(String key) {
    for (final v in values) {
      if (v.storageKey == key) return v;
    }
    return null;
  }
}

/// Decodes a `curriculum_tracks/{curriculumId}` document into a
/// [CurriculumTrackEntity].
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` and
/// [FormatException] for a missing `state`/`state_changed_at`/
/// `activated_at` — both are caller-visible decode failures by design
/// (mirrors `stageDefinitionFromFirestore`/`curriculumScopeFromFirestore`),
/// surfaced via `resilientQueryStream`'s per-document error handling (skips
/// just that document) rather than silently defaulted. `state`'s VALUE is
/// not validated against [CurriculumTrackState] — see that field's doc
/// comment.
CurriculumTrackEntity curriculumTrackFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final state = data['state'] as String?;
  final stateChangedAt = FirestoreCodec.parseDateTime(data['state_changed_at']);
  final activatedAt = FirestoreCodec.parseDateTime(data['activated_at']);
  if (state == null ||
      state.isEmpty ||
      stateChangedAt == null ||
      activatedAt == null) {
    throw FormatException(
      'curriculum_tracks document missing state/state_changed_at/'
      'activated_at: $data',
    );
  }

  return CurriculumTrackEntity(
    curriculumId: curriculumId,
    state: state,
    stateChangedAt: stateChangedAt,
    activatedAt: activatedAt,
    paceResetDate: FirestoreCodec.parseDateTime(data['pace_reset_date']),
    lastReorderAt: FirestoreCodec.parseDateTime(data['last_reorder_at']),
    progressSchemaVersion: FirestoreCodec.parseInt(
      data['progress_schema_version'],
    ),
    progressComputedAt: FirestoreCodec.parseDateTime(
      data['progress_computed_at'],
    ),
    progressModel: data['progress_model'] as String?,
    programProgress: (data['program_progress'] as Map?)
        ?.cast<String, dynamic>(),
    selfPacedProgress: (data['self_paced_progress'] as Map?)
        ?.cast<String, dynamic>(),
    syncedAt: FirestoreCodec.parseDateTime(data['synced_at']),
  );
}
