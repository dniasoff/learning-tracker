/// Deterministic Firestore document-id formulas — extracted verbatim, then
/// re-keyed exactly where AD-25/AD-24 mandate it (Story 2.3).
///
/// **Story 2.2 (Epic 2, Migration Phase 0)** reproduced every doc-id
/// derivation that lives scattered across
/// `lib/core/sync/firestore_gateway_impl.dart` (its `.doc(...)` call sites)
/// **byte-for-byte** here, in one standalone module, so that a future native
/// write mints the *exact* same document id the live gateway mints today —
/// no duplicate remote docs, no orphaned history (MCF-3, MCF-3-continuity;
/// AD-5, AD-13).
///
/// **This is Phase-0 additive scaffolding only.** Nothing in `lib/` imports
/// this module yet — no call site is rewired, no cutover happens in Phase 0.
/// It exists purely so the formulas are pinned by a golden test ahead of any
/// later story that reads from here.
///
/// **No `cloud_firestore` import — by design (binding AC).** This file is a
/// pure string-formula module: every function takes a plain
/// `Map<String, dynamic>` (or primitive) and returns a plain `String`/
/// `String?`. It must never import `package:cloud_firestore/cloud_firestore.dart`
/// so it cannot trip the Story 2.6 Firebase-confinement `make audit` grep
/// (today scoped to `lib/core/sync/` and `lib/core/auth/`) before that grep
/// is deliberately widened to allow `lib/data/firestore/**` (AD-28).
///
/// **AD-25 re-key (Story 2.3) — track-scoped children.**
/// [stageDefinitionDocId] and [studyDayConfigDocId] no longer embed the
/// *per-device* `track_id` that made them impossible to reproduce
/// byte-for-byte across two devices for the same track. Both are now
/// re-expressed against the single canonical stable track key,
/// `curriculum_id` (consistent with `curriculum_tracks/{curriculum_id}`) —
/// no track ULID is used as the track key. **This deliberately BREAKS AD-13
/// byte-for-byte continuity for these two collections — AD-25 explicitly
/// supersedes AD-13 here.** Every historical cloud doc was written as
/// `{oldPerDeviceTrackId}_{…}` and will NOT match the new formula's output
/// for the same logical row. That is intended and owner-ratified, not a
/// defect: it requires the mandatory Phase-5 one-time doc-id re-key +
/// backfill of every historical `{perDeviceTrackId}_*` doc to the
/// `curriculum_id`-keyed form (Phase 3 Wave A per AD-25, atomic across both
/// collections). This module does not perform that backfill — it only
/// defines the target formula new writes must land on — and, by
/// construction, retires the `resolveLocalTrackId` remap
/// (`local_track_id_resolver.dart`, MCF-4) for these two collections: there
/// is no per-device id left for it to resolve. `goals` is untouched by this
/// re-key: unlike the two collections above, its doc-id formula
/// ([goalDocId]) never embedded `track_id` in the first place — see that
/// function's doc comment for why. The pre-rekey shape is not discarded:
/// [legacyStageDefinitionDocId] and [legacyStudyDayConfigDocId] keep it
/// byte-for-byte, explicitly named as legacy and never for new writes, so
/// the Phase-5 backfill (and its verifier) can locate and confirm existing
/// `{perDeviceTrackId}_*` documents from this module alone — mirroring
/// exactly how [learnerProfileDocId] is kept below for the AD-24 re-key.
///
/// **AD-24 re-key (Story 2.3) — profile-scoped ULID.** [mintProfileUlid]
/// and [learnerProfileUlidDocId] give `learner_profiles` a profile-scoped
/// stable ULID doc-id, distinct from the path uid
/// (`users/{uid}/learner_profiles/{profileUlid}`) and never the
/// account/Firebase uid — an account owns *many* profiles, so keying every
/// profile doc-id by the shared uid would collide every child of that
/// account onto one document. [learnerProfileDocId] — the path-derived
/// local-autoincrement-`profileId` legacy formula — is left byte-for-byte
/// unchanged: it still matches today's live (not-yet-rewired) gateway
/// exactly, and Phase 0 performs no cutover, so both formulas intentionally
/// coexist here until the same kind of Phase-5 backfill mints + persists a
/// stable ULID for every pre-existing profile and re-keys its historical
/// doc.
///
/// **AD-5 ULID standardization (Story 2.3).** Every ULID this module mints
/// routes through the single in-repo generator, `newUlid`
/// (`lib/core/time/ulid.dart`) — no alternate generator, no new pub.dev
/// package.
///
/// Source of truth for every formula below:
///   `lib/core/sync/firestore_gateway_impl.dart` — see the doc comment on
///   each function for the exact line-anchored call site it mirrors.
library;

import 'dart:convert' show utf8;

import 'package:learning_tracker/core/time/ulid.dart';

/// Deterministic Firestore document-id formulas for every synced collection.
///
/// All members are `static`; this class is never instantiated.
final class DocIds {
  const DocIds._();

  // ── shared building block ─────────────────────────────────────────────

  /// Percent-encodes one natural-key component so it is safe to join into a
  /// canonical composite doc-id.
  ///
  /// Mirrors `FirestoreGatewayImpl._encodeKeyComponent`
  /// (`firestore_gateway_impl.dart:78-96`) **exactly**: only ASCII letters,
  /// digits, `-`, and `~` survive unescaped; every other byte — including
  /// `%` itself, the `_` separator, `/`, `.`, and space — is percent-encoded
  /// as `%XX` (uppercase hex). Because `%` is escaped, the encoding is
  /// injective: an encoded component can never contain a literal `_`, so a
  /// joined multi-component id can always be split back unambiguously.
  static String encodeKeyComponent(String raw) {
    final out = StringBuffer();
    for (final unit in utf8.encode(raw)) {
      final isUnreserved =
          (unit >= 0x30 && unit <= 0x39) || // 0-9
          (unit >= 0x41 && unit <= 0x5A) || // A-Z
          (unit >= 0x61 && unit <= 0x7A) || // a-z
          unit == 0x2D || // -
          unit == 0x7E; // ~
      if (isUnreserved) {
        out.writeCharCode(unit);
      } else {
        out
          ..write('%')
          ..write(unit.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return out.toString();
  }

  // ── completions ──────────────────────────────────────────────────────

  /// The single canonical completion document-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl._completionDocId`
  /// (`firestore_gateway_impl.dart:128-139`) exactly, including the
  /// snake_case-authoritative / camelCase-fallback legacy field-alias
  /// decoding for each of the four natural-key components.
  ///
  /// `profileId_sefariaRef_stageId_curriculumId`, each component
  /// percent-encoded via [encodeKeyComponent] and joined with `_`.
  static String completionDocId(int profileId, Map<String, dynamic> data) {
    final ref = (data['sefaria_ref'] ?? data['sefariaRef']) as String? ?? '';
    final stage = (data['stage_id'] ?? data['stageId'])?.toString() ?? '';
    final curriculumId =
        (data['curriculum_id'] ?? data['curriculumId']) as String? ?? '';
    return [
      encodeKeyComponent(profileId.toString()),
      encodeKeyComponent(ref),
      encodeKeyComponent(stage),
      encodeKeyComponent(curriculumId),
    ].join('_');
  }

  // ── streak_events ────────────────────────────────────────────────────

  /// `streak_events/{ulid}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushStreak`
  /// (`firestore_gateway_impl.dart:299-302`): the outbox payload's `ulid`
  /// field IS the doc id. Returns `null` when the payload carries no
  /// `ulid` — the live gateway falls back to `collection.doc()` (a
  /// server-assigned random id) in that case, which by construction has no
  /// deterministic formula for this pure module to reproduce; callers must
  /// treat `null` as "fall back to a random server-assigned id", exactly as
  /// the gateway does today.
  static String? streakEventDocId(Map<String, dynamic> data) =>
      data['ulid'] as String?;

  // ── settings (legacy) ────────────────────────────────────────────────

  /// `settings/{curriculum_id}` doc-id formula (defaults to `'default'`).
  ///
  /// Mirrors `FirestoreGatewayImpl.pushSettings`
  /// (`firestore_gateway_impl.dart:322-324`).
  static String settingsDocId(Map<String, dynamic> data) =>
      data['curriculum_id']?.toString() ?? 'default';

  // ── curriculum_tracks ────────────────────────────────────────────────

  /// `curriculum_tracks/{curriculum_id}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushTrack`
  /// (`firestore_gateway_impl.dart:346-355`). One track per
  /// (profileId, curriculumId): the curriculum id alone is the doc id
  /// (post-W3.22; no `trackType` component).
  static String curriculumTrackDocId(Map<String, dynamic> data) =>
      data['curriculum_id']?.toString() ?? '';

  // ── learning_order ───────────────────────────────────────────────────

  /// `learning_order/{curriculumId}_{ref}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushLearningOrder`
  /// (`firestore_gateway_impl.dart:377-382`), including the `sefaria_ref`
  /// ?? `ref` legacy-key fallback.
  static String learningOrderDocId(Map<String, dynamic> data) {
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final ref =
        data['sefaria_ref']?.toString() ?? data['ref']?.toString() ?? '';
    return '${curriculumId}_$ref';
  }

  // ── bookmarks ────────────────────────────────────────────────────────

  /// `bookmarks/{curriculum_id}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushBookmark`
  /// (`firestore_gateway_impl.dart:394-401`). One bookmark per curriculum,
  /// so the curriculum id alone is the natural key.
  static String bookmarkDocId(Map<String, dynamic> data) =>
      data['curriculum_id']?.toString() ?? '';

  // ── learning_ledger ──────────────────────────────────────────────────

  /// `learning_ledger/{ulid}` doc-id formula (shared by the single-entry
  /// and batch push paths — both derive the id identically).
  ///
  /// Mirrors `FirestoreGatewayImpl.pushLedgerEntry`
  /// (`firestore_gateway_impl.dart:513-516`) and
  /// `pushLedgerEntriesBatch` (`:535-541`). Returns `null` when the payload
  /// carries no `ulid`, matching the gateway's random-id fallback (see
  /// [streakEventDocId] for the same contract).
  static String? learningLedgerDocId(Map<String, dynamic> data) =>
      data['ulid'] as String?;

  // ── profile_programs ─────────────────────────────────────────────────

  /// `profile_programs/{curriculum_id}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushProfileProgram`
  /// (`firestore_gateway_impl.dart:559-567`).
  static String profileProgramDocId(Map<String, dynamic> data) =>
      data['curriculum_id']?.toString() ?? '';

  // ── goals ────────────────────────────────────────────────────────────

  /// `goals/{id|goal_id|fallback natural key}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushGoal`
  /// (`firestore_gateway_impl.dart:647-668`): prefers the caller-supplied
  /// `id`, then `goal_id`, then falls back to [fallbackGoalDocId] — never
  /// `collection.add()` (AUD-core-sync-24 / FB-4: a random doc-id on retry
  /// would duplicate a goal on every lost-ack outbox retry).
  ///
  /// **Not an AD-25 track-scoped reformulation target.** AD-25's binding
  /// list names `goals` alongside `stage_definitions`/`study_day_configs`
  /// as a "track-scoped child", but unlike those two, `goals`' *doc-id*
  /// formula (this function) never embeds `track_id` today — only the
  /// row's `track_id` *payload field* is subject to the separate
  /// `resolveLocalTrackId` FK-remap at merge time (MCF-4), which is outside
  /// this doc-id-formula module's scope. So `goalDocId` needs no
  /// pre-/post-rekey carve-out; it is reproduced byte-for-byte with no
  /// caveat, same as every non-track-scoped collection.
  static String goalDocId(Map<String, dynamic> data) =>
      data['id']?.toString() ??
      data['goal_id']?.toString() ??
      fallbackGoalDocId(data);

  /// Deterministic fallback goal doc-id for the (unreachable in practice)
  /// case where a caller omits both `id` and `goal_id`.
  ///
  /// Mirrors `FirestoreGatewayImpl._fallbackGoalDocId`
  /// (`firestore_gateway_impl.dart:690-702`) exactly, including the
  /// snake_case/camelCase legacy-alias fallback for each component.
  ///
  /// `curriculum_targetPercent_createdAt`, each component percent-encoded
  /// via [encodeKeyComponent] and joined with `_`.
  static String fallbackGoalDocId(Map<String, dynamic> data) {
    final curriculum = (data['curriculum_id'] ?? data['curriculumId'] ?? '')
        .toString();
    final pct = (data['target_percent'] ?? data['targetPercent'] ?? '')
        .toString();
    final createdAt = (data['created_at'] ?? data['createdAt'] ?? '')
        .toString();
    return [
      encodeKeyComponent(curriculum),
      encodeKeyComponent(pct),
      encodeKeyComponent(createdAt),
    ].join('_');
  }

  // ── import_metadata ──────────────────────────────────────────────────

  /// `import_metadata/{curriculum_id}` doc-id formula (defaults to
  /// `'default'`).
  ///
  /// Mirrors `FirestoreGatewayImpl.pushCurriculumImportMetadata`
  /// (`firestore_gateway_impl.dart:756-763`). Note: the *push* path is a
  /// documented dead path (zero prod callers) per the migration baseline,
  /// but the collection is reused as-is and existing historical documents
  /// still round-trip through this id — reproduced here regardless of the
  /// write path's liveness, per MCF-3-continuity.
  static String importMetadataDocId(Map<String, dynamic> data) =>
      data['curriculum_id']?.toString() ?? 'default';

  // ── stage_definitions ────────────────────────────────────────────────

  /// `stage_definitions/{curriculumId}_{stageOrder}` doc-id formula
  /// (AD-25 re-key — Story 2.3).
  ///
  /// **Re-keyed onto the canonical stable track key.** Before this story,
  /// this formula mirrored `FirestoreGatewayImpl.pushStageDefinition`
  /// (`firestore_gateway_impl.dart:1152-1176`) byte-for-byte, embedding the
  /// *per-device* `track_id`. AD-25 mandates the single canonical stable
  /// track key is `curriculum_id` (consistent with
  /// `curriculum_tracks/{curriculum_id}`) — no track ULID, no per-device id.
  /// This function now derives the doc-id from `curriculum_id` instead,
  /// which by construction retires the `resolveLocalTrackId` FK-remap
  /// (`local_track_id_resolver.dart`, MCF-4) for this collection: there is
  /// no per-device id left to resolve.
  ///
  /// **This deliberately BREAKS byte-for-byte continuity (AD-13) for this
  /// collection — AD-25 explicitly supersedes AD-13 here.** Every historical
  /// cloud doc was written as `{oldPerDeviceTrackId}_{stageOrder}`; it will
  /// NOT match this formula's output for the same logical stage. That is
  /// intended and owner-ratified, not a defect: it requires the mandatory
  /// Phase-5 one-time doc-id re-key + backfill of every historical
  /// `{perDeviceTrackId}_*` doc to this `{curriculumId}_{stageOrder}` form
  /// (Phase 3 Wave A per AD-25) — this module does not perform that
  /// backfill, it only defines the target formula new writes must land on.
  ///
  /// Keeps the live gateway's `ArgumentError` guard shape (now against
  /// `curriculum_id`/`stage_order` instead of `track_id`/`stage_order`).
  static String stageDefinitionDocId(Map<String, dynamic> data) {
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final stageOrder = data['stage_order']?.toString() ?? '';
    if (curriculumId.isEmpty || stageOrder.isEmpty) {
      throw ArgumentError(
        'stageDefinitionDocId requires non-empty curriculum_id and '
        'stage_order',
      );
    }
    return '${curriculumId}_$stageOrder';
  }

  // ── stage_definitions (legacy, pre-AD-25 shape) ──────────────────────

  /// `stage_definitions/{trackId}_{stageOrder}` doc-id formula — the
  /// LEGACY, pre-AD-25 shape the live (not-yet-rewired) gateway still
  /// writes today.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushStageDefinition`
  /// (`firestore_gateway_impl.dart:1152-1176`) byte-for-byte, including its
  /// `ArgumentError` guard — this is exactly [stageDefinitionDocId]'s body
  /// before Story 2.3's AD-25 re-key.
  ///
  /// **Exists only so Phase 5 can find historical documents, not so new
  /// code can mint ids.** It is the pinned record of the old
  /// `{trackId}_{stageOrder}` shape the one-time re-key/backfill (Phase 3
  /// Wave A per AD-25) must locate and verify against before writing the
  /// new [stageDefinitionDocId] shape — kept here so that record survives
  /// even after the live gateway's pre-rekey code path is deleted in
  /// Phase 6. **Must NOT be used for new writes** — new writes always go
  /// through [stageDefinitionDocId].
  static String legacyStageDefinitionDocId(Map<String, dynamic> data) {
    final trackId = data['track_id']?.toString() ?? '';
    final stageOrder = data['stage_order']?.toString() ?? '';
    if (trackId.isEmpty || stageOrder.isEmpty) {
      throw ArgumentError(
        'legacyStageDefinitionDocId requires non-empty track_id and '
        'stage_order',
      );
    }
    return '${trackId}_$stageOrder';
  }

  // ── study_day_configs ────────────────────────────────────────────────

  /// `study_day_configs/{curriculumId}_{dayOfWeek}` doc-id formula
  /// (AD-25 re-key — Story 2.3).
  ///
  /// **Re-keyed onto the canonical stable track key.** Before this story,
  /// this formula mirrored `FirestoreGatewayImpl.pushStudyDayConfig`
  /// (`firestore_gateway_impl.dart:1180-1204`) byte-for-byte:
  /// `{curriculumId}_{dayOfWeek}_{trackId}`, embedding the *per-device*
  /// `track_id` as a third component. AD-25 drops that component entirely —
  /// `curriculum_id` is already present and IS the single canonical stable
  /// track key, so no replacement component is needed. This retires the
  /// `resolveLocalTrackId` FK-remap (`local_track_id_resolver.dart`, MCF-4)
  /// for this collection by construction.
  ///
  /// **This deliberately BREAKS byte-for-byte continuity (AD-13) for this
  /// collection — AD-25 explicitly supersedes AD-13 here.** Every historical
  /// cloud doc was written as
  /// `{curriculumId}_{dayOfWeek}_{oldPerDeviceTrackId}`; it will NOT match
  /// this formula's output. That is intended and owner-ratified, not a
  /// defect: it requires the same mandatory Phase-5 one-time doc-id re-key +
  /// backfill described on [stageDefinitionDocId], atomic across both
  /// re-keyed collections (Phase 3 Wave A per AD-25).
  ///
  /// Keeps the live gateway's `ArgumentError` guard shape, minus the
  /// now-dropped `track_id` requirement.
  static String studyDayConfigDocId(Map<String, dynamic> data) {
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final dayOfWeek = data['day_of_week']?.toString() ?? '';
    if (curriculumId.isEmpty || dayOfWeek.isEmpty) {
      throw ArgumentError(
        'studyDayConfigDocId requires non-empty curriculum_id and '
        'day_of_week',
      );
    }
    return '${curriculumId}_$dayOfWeek';
  }

  // ── study_day_configs (legacy, pre-AD-25 shape) ──────────────────────

  /// `study_day_configs/{curriculumId}_{dayOfWeek}_{trackId}` doc-id
  /// formula — the LEGACY, pre-AD-25 shape the live (not-yet-rewired)
  /// gateway still writes today.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushStudyDayConfig`
  /// (`firestore_gateway_impl.dart:1180-1204`) byte-for-byte, including its
  /// `ArgumentError` guard — this is exactly [studyDayConfigDocId]'s body
  /// before Story 2.3's AD-25 re-key.
  ///
  /// **Exists only so Phase 5 can find historical documents, not so new
  /// code can mint ids.** It is the pinned record of the old
  /// `{curriculumId}_{dayOfWeek}_{trackId}` shape the one-time
  /// re-key/backfill (Phase 3 Wave A per AD-25) must locate and verify
  /// against before writing the new [studyDayConfigDocId] shape — kept
  /// here so that record survives even after the live gateway's pre-rekey
  /// code path is deleted in Phase 6. **Must NOT be used for new writes**
  /// — new writes always go through [studyDayConfigDocId].
  static String legacyStudyDayConfigDocId(Map<String, dynamic> data) {
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final dayOfWeek = data['day_of_week']?.toString() ?? '';
    final trackId = data['track_id']?.toString() ?? '';
    if (curriculumId.isEmpty || dayOfWeek.isEmpty || trackId.isEmpty) {
      throw ArgumentError(
        'legacyStudyDayConfigDocId requires non-empty curriculum_id, '
        'day_of_week, and track_id',
      );
    }
    return '${curriculumId}_${dayOfWeek}_$trackId';
  }

  // ── points_ledger ────────────────────────────────────────────────────

  /// `points_ledger/{ulid}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushPointsLedgerEntry`
  /// (`firestore_gateway_impl.dart:1216-1219`). Returns `null` when the
  /// payload carries no `ulid`, matching the gateway's random-id fallback
  /// (see [streakEventDocId] for the same contract). `UNIQUE(profileId,
  /// ulid)` (MCF-8) depends on this id always being the ledger's own ulid
  /// when present — never a re-derived or re-encoded value.
  static String? pointsLedgerDocId(Map<String, dynamic> data) =>
      data['ulid'] as String?;

  // ── reward_redemptions ───────────────────────────────────────────────

  /// `reward_redemptions/{ulid}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushRewardRedemption`
  /// (`firestore_gateway_impl.dart:1239-1242`). Returns `null` when the
  /// payload carries no `ulid`, matching the gateway's random-id fallback
  /// (see [streakEventDocId] for the same contract).
  static String? rewardRedemptionDocId(Map<String, dynamic> data) =>
      data['ulid'] as String?;

  // ── learner_profiles (legacy, path-derived integer) ─────────────────

  /// `learner_profiles/{profileId}` doc-id formula — the LEGACY,
  /// not-yet-superseded formula that still matches the live gateway exactly.
  ///
  /// Mirrors `FirestoreGatewayImpl._learnerProfileDoc`
  /// (`firestore_gateway_impl.dart:1283-1291`): the path-derived local
  /// autoincrement `profileId`, stringified — NOT a natural key drawn from
  /// the payload.
  ///
  /// **Kept unchanged by Story 2.3, on purpose.** AD-24 mandates the
  /// `learner_profiles` doc-id becomes a profile-scoped stable ULID (see
  /// [mintProfileUlid] / [learnerProfileUlidDocId] below) — keying it by the
  /// account uid, or leaving it on this device-local integer, would collide
  /// every child of an account onto one document once profiles are keyed by
  /// something account-wide (AD-5). Phase 0 performs no cutover: nothing
  /// calls this module yet, so this legacy formula and the new ULID formula
  /// intentionally coexist here until the Phase-5 backfill mints + persists
  /// a stable ULID for every pre-existing profile and re-keys its
  /// historical doc.
  static String learnerProfileDocId(int profileId) => profileId.toString();

  // ── learner_profiles (AD-24 profile-scoped ULID — Story 2.3) ────────

  /// Mints a fresh profile-scoped stable ULID (AD-24).
  ///
  /// Routes through the single in-repo ULID generator, `newUlid`
  /// (`lib/core/time/ulid.dart`), per AD-5's standardization rule — no
  /// alternate generator, no new pub.dev package. Intended to be called
  /// once, at profile-creation time, to produce the value a caller then
  /// persists on the profile's local record (a new stable-id field; adding
  /// that column/migration is out of this Phase-0 scaffolding module's
  /// scope) and reuses forever after as that profile's Firestore doc-id via
  /// [learnerProfileUlidDocId].
  static String mintProfileUlid() => newUlid();

  /// `learner_profiles/{profileUlid}` doc-id formula (AD-24 profile-scoped
  /// ULID — Story 2.3).
  ///
  /// Reads the profile's own persisted stable ULID from the payload's
  /// `profile_ulid` field — mirroring the `data['ulid']`-echo pattern used
  /// by [streakEventDocId]/[learningLedgerDocId]/etc. above — and mints a
  /// fresh one via [mintProfileUlid] only when the payload carries none yet
  /// (the profile-creation-time case). This is a profile-scoped id — NOT
  /// the path-derived local autoincrement `profileId` that
  /// [learnerProfileDocId] uses today, and NOT the account/Firebase uid: an
  /// account owns *many* profiles, so keying every profile doc-id by the
  /// shared uid would collide every child of that account onto one
  /// document. The uid addresses the *path*
  /// (`users/{uid}/learner_profiles/{profileUlid}`); this formula addresses
  /// the *document* — the two must never be conflated (AD-5, AD-24).
  ///
  /// **This deliberately BREAKS byte-for-byte continuity (AD-13) for this
  /// collection too**, exactly like the two AD-25 re-keys above, and needs
  /// the same kind of Phase-5 one-time backfill: minting + persisting a
  /// ULID for every existing profile and re-keying its historical doc from
  /// the old `{profileId}` shape to this one.
  static String learnerProfileUlidDocId(Map<String, dynamic> data) =>
      (data['profile_ulid'] as String?) ?? mintProfileUlid();
}
