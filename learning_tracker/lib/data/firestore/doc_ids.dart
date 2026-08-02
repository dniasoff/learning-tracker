/// Deterministic Firestore document-id formulas — extracted verbatim.
///
/// **Story 2.2 (Epic 2, Migration Phase 0).** Every doc-id derivation that
/// today lives scattered across `lib/core/sync/firestore_gateway_impl.dart`
/// (its `.doc(...)` call sites) is reproduced **byte-for-byte** here, in one
/// standalone module, so that a future native write mints the *exact* same
/// document id the live gateway mints today — no duplicate remote docs, no
/// orphaned history (MCF-3, MCF-3-continuity; AD-5, AD-13).
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
/// **AD-25 carve-out.** Track-scoped child collections
/// (`stage_definitions`, `study_day_configs`) embed the *per-device*
/// `track_id` in their current Firestore doc-id — a value that does not
/// match across two devices for the same track. AD-25 mandates re-keying
/// those formulas onto the single canonical stable track key
/// (`curriculum_id`) via a one-time re-key + backfill, but that migration is
/// **Story 2.3's** job, not this one. This module deliberately keeps the
/// CURRENT (pre-rekey) formula for those two collections — each is marked
/// with a **Story 2.3 follow-up** note below — so today's byte-for-byte AC
/// holds. Every
/// other formula in this file, including `goals`, reproduces the live
/// gateway output exactly with no carve-out (see the note on [goalDocId]
/// for why `goals` is NOT one of the two AD-25 reformulated collections
/// despite being named as a "track-scoped child" in AD-25's binding list).
///
/// Source of truth for every formula below:
///   `lib/core/sync/firestore_gateway_impl.dart` — see the doc comment on
///   each function for the exact line-anchored call site it mirrors.
library;

import 'dart:convert' show utf8;

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

  /// `stage_definitions/{trackId}_{stageOrder}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushStageDefinition`
  /// (`firestore_gateway_impl.dart:1152-1176`) **exactly, including its
  /// `ArgumentError` guard** for byte-for-byte parity on the invalid path
  /// too.
  ///
  /// **Story 2.3 follow-up:** AD-25 re-keys this to the canonical stable
  /// track key — `{curriculum_id}_{stageOrder}` — retiring the per-device
  /// `track_id`
  /// component via a one-time re-key + backfill of historical
  /// `{perDeviceTrackId}_*` docs. AD-13's byte-for-byte rule is explicitly
  /// superseded for this collection (AD-25); this module intentionally
  /// keeps the CURRENT (pre-rekey) formula below, which is what Story 2.2
  /// is scoped to reproduce. Do not "fix" this ahead of Story 2.3 — doing
  /// so here without the accompanying backfill would silently orphan every
  /// existing user's stage-definition history.
  static String stageDefinitionDocId(Map<String, dynamic> data) {
    final trackId = data['track_id']?.toString() ?? '';
    final stageOrder = data['stage_order']?.toString() ?? '';
    if (trackId.isEmpty || stageOrder.isEmpty) {
      throw ArgumentError(
        'stageDefinitionDocId requires non-empty track_id and stage_order',
      );
    }
    return '${trackId}_$stageOrder';
  }

  // ── study_day_configs ────────────────────────────────────────────────

  /// `study_day_configs/{curriculumId}_{dayOfWeek}_{trackId}` doc-id
  /// formula.
  ///
  /// Mirrors `FirestoreGatewayImpl.pushStudyDayConfig`
  /// (`firestore_gateway_impl.dart:1180-1204`) **exactly, including its
  /// `ArgumentError` guard**.
  ///
  /// **Story 2.3 follow-up:** AD-25 re-keys this to the canonical stable
  /// track key — dropping the per-device `track_id` component in favor of
  /// `curriculum_id` — via the same one-time re-key + backfill as
  /// [stageDefinitionDocId]. See that function's doc comment for the full
  /// rationale; this module intentionally keeps the CURRENT (pre-rekey)
  /// formula below.
  static String studyDayConfigDocId(Map<String, dynamic> data) {
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final dayOfWeek = data['day_of_week']?.toString() ?? '';
    final trackId = data['track_id']?.toString() ?? '';
    if (curriculumId.isEmpty || dayOfWeek.isEmpty || trackId.isEmpty) {
      throw ArgumentError(
        'studyDayConfigDocId requires non-empty curriculum_id, day_of_week, '
        'and track_id',
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

  // ── learner_profiles ─────────────────────────────────────────────────

  /// `learner_profiles/{profileId}` doc-id formula.
  ///
  /// Mirrors `FirestoreGatewayImpl._learnerProfileDoc`
  /// (`firestore_gateway_impl.dart:1283-1291`): the path-derived local
  /// autoincrement `profileId`, stringified — NOT a natural key drawn from
  /// the payload.
  ///
  /// **Distinct from the AD-25 carve-out above.** This collection is NOT
  /// one of AD-25's track-scoped children (`stage_definitions`,
  /// `study_day_configs`) — it is unaffected by AD-25. It IS, however,
  /// separately scheduled to change under **AD-24** in Story 2.3: the
  /// `learner_profiles` doc-id becomes a profile-scoped stable ULID minted
  /// per profile, replacing this device-local-integer formula, because
  /// keying it by the account uid would collide every child of an account
  /// onto one document (AD-5). Story 2.2 keeps today's formula unchanged;
  /// Story 2.3 replaces it under a different AD (AD-24, not AD-25) and a
  /// different justification (profile-collision, not track-cross-device
  /// mismatch) than the two collections above.
  static String learnerProfileDocId(int profileId) => profileId.toString();
}
