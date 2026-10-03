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
    this.activatedAt,
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
  /// **Only three values exist — `deleted` is gone.** Drift's `TrackState`
  /// had a fourth member, `deleted`, as a soft-delete tombstone. Since
  /// DNI-476 (AD-38) "Remove track" is the governed `ended_at` tombstone on
  /// this document (written through `LearningCommands.removeTrack`, cleared
  /// again by re-add), not a state value and never a delete; a removed
  /// track reads as absent ([FirestoreCurriculumTrackRepository.getTrack]
  /// returns `null`).
  final String state;

  /// When the track was first activated — **display only** (the "Started"
  /// row of the track info card, DNI-484 / R16). AD-35: it is never an
  /// engine, planner or projection anchor (the tracking start is
  /// `profile_programs.tracking_start_date`). Optional: a document without
  /// it decodes, and the display omits the row.
  final DateTime? activatedAt;

  /// True when [state] is the known `'active'` value.
  bool get isActive => state == CurriculumTrackState.active.storageKey;

  /// Encodes this track for a Firestore write.
  ///
  /// `profile_id` / `track_id` are deliberately NOT included, even though
  /// both are in the rules `.hasOnly()` whitelist and the OLD (pre-rewrite)
  /// `FirestoreGatewayImpl.pushTrack`/`TrackCodec.encode` wrote them: the
  /// document already lives at `.../learner_profiles/{profileId}/
  /// curriculum_tracks/{curriculumId}`, so profile identity is carried by
  /// the path (same reasoning as `persisted entity`/`StageDefinition`'s
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
  /// The R16 retired fields (`state_changed_at`, `purged`, `purged_at`,
  /// `pace_reset_date`, `last_reorder_at`, the `progress_*` /
  /// `*_progress` passthroughs, `synced_at`) are neither encoded nor
  /// decoded (DNI-484).
  Map<String, dynamic> toFirestore() => {
    'curriculum_id': curriculumId.storageKey,
    'state': state,
    if (activatedAt != null)
      'activated_at': FirestoreCodec.encodeDateTime(activatedAt),
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
/// [FormatException] for a missing `state` — both are caller-visible decode
/// failures by design (mirrors `stageDefinitionFromFirestore`/
/// `curriculumScopeFromFirestore`), surfaced via `resilientQueryStream`'s
/// per-document error handling (skips just that document) rather than
/// silently defaulted. `state`'s VALUE is not validated against
/// [CurriculumTrackState] — see that field's doc comment. `activated_at` is
/// optional (display only), and the R16 retired keys are ignored if an old
/// document still carries them.
CurriculumTrackEntity curriculumTrackFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final state = data['state'] as String?;
  if (state == null || state.isEmpty) {
    throw FormatException('curriculum_tracks document missing state: $data');
  }

  return CurriculumTrackEntity(
    curriculumId: curriculumId,
    state: state,
    activatedAt: FirestoreCodec.parseDateTime(data['activated_at']),
  );
}
