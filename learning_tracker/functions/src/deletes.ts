import * as admin from "firebase-admin";
import { auth, logger } from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { db, CALL_OPTS, buildAccessId } from "./shared";

// ══════════════════════════════════════════════════════════════════════════════
// Account & learner-data deletion
// ══════════════════════════════════════════════════════════════════════════════
//
// onUserDeleted cascades Firestore cleanup when a Firebase Auth account is
// removed. The three callables below let a signed-in client delete its own
// data (one learner profile, one curriculum track, or the whole account)
// ahead of the Auth-account deletion that ultimately triggers the cascade.

/**
 * Triggered when a Firebase Auth user is deleted.
 *
 * Cascades two sets of operations:
 *
 *   1. USER DATA: Deletes all Firestore data under `users/{uid}` using
 *      Admin SDK recursiveDelete (existing behaviour).
 *
 *   2. W6.23 — PARENT GRANTS: If the user was a parent, all active/pending
 *      tutor grants they issued are revoked. Child profiles are already
 *      deleted by step 1 (under `users/{uid}/learner_profiles/`).
 *
 *   3. W6.24 — TUTOR GRANTS: If the user was a tutor, all active grants
 *      where they are the tutor are transitioned to `revoked_by_tutor` with
 *      a sentinel note that the account was deleted. The tutor_name_snapshot
 *      on audit log entries is preserved (already captured at write-time —
 *      no action needed here).
 */
export const onUserDeleted = auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const now = admin.firestore.Timestamp.now();
  logger.info(`onUserDeleted: starting cascade for uid=${uid}`);

  // ── Step 1: Delete all user data ──────────────────────────────────────────
  await db.recursiveDelete(db.collection("users").doc(uid));
  logger.info(`onUserDeleted: user data deleted for uid=${uid}`);

  // ── Step 2 (W6.23): Revoke all grants where this user is the parent ────────
  const parentGrantsSnap = await db
    .collection("tutor_grants")
    .where("parent_uid", "==", uid)
    .where("state", "in", ["pending", "active"])
    .get();

  const parentGrantBatch = db.batch();
  for (const grantDoc of parentGrantsSnap.docs) {
    parentGrantBatch.update(grantDoc.ref, {
      state: "revoked_by_parent",
      revoked_at: now,
      updated_at: now,
      _delete_cascade: true, // sentinel: revoked because parent account deleted
    });
    // AUD-firebase-06: mirror Step 3 — hasActiveTutorAccess() in
    // firestore.rules grants a tutor read access purely by the existence of
    // a tutor_active_access doc, so every code path that ends an active
    // grant must also delete it. Only an 'active' grant ever had one
    // written (by acceptTutorInvite); a still-'pending' grant has
    // tutor_uid == null and no access doc — the delete is a safe no-op in
    // that case regardless, but skip building a nonsense doc-id for it.
    const grant = grantDoc.data();
    if (grant.tutor_uid) {
      const accessId = buildAccessId(
        String(grant.tutor_uid),
        uid,
        String(grant.child_profile_id ?? "")
      );
      parentGrantBatch.delete(db.collection("tutor_active_access").doc(accessId));
    }
  }
  if (parentGrantsSnap.size > 0) {
    await parentGrantBatch.commit();
    logger.info(
      `onUserDeleted: revoked ${parentGrantsSnap.size} parent grants for uid=${uid}`
    );
  }

  // ── Step 3 (W6.24): Resign all grants where this user is the tutor ─────────
  // The tutor_name_snapshot on existing audit entries is already captured at
  // write-time and persists independently (FR-7.2 requirement satisfied).
  const tutorGrantsSnap = await db
    .collection("tutor_grants")
    .where("tutor_uid", "==", uid)
    .where("state", "==", "active")
    .get();

  const tutorGrantBatch = db.batch();
  for (const grantDoc of tutorGrantsSnap.docs) {
    tutorGrantBatch.update(grantDoc.ref, {
      state: "revoked_by_tutor",
      revoked_at: now,
      updated_at: now,
      _delete_cascade: true, // sentinel: resigned because tutor account deleted
    });
    // V2-R3 C2: also delete the tutor_active_access lookup doc so the
    // tutor immediately loses subcollection read access.
    const grant = grantDoc.data();
    const accessId = buildAccessId(
      uid,
      String(grant.parent_uid ?? ""),
      String(grant.child_profile_id ?? "")
    );
    tutorGrantBatch.delete(db.collection("tutor_active_access").doc(accessId));
  }
  if (tutorGrantsSnap.size > 0) {
    await tutorGrantBatch.commit();
    logger.info(
      `onUserDeleted: resigned ${tutorGrantsSnap.size} tutor grants for uid=${uid}`
    );
  }

  logger.info(`onUserDeleted: cascade complete for uid=${uid}`);
});

/**
 * Callable: delete a single learner profile and all its subcollections.
 *
 * Uses Admin SDK recursiveDelete so the client never needs to enumerate or
 * read subcollection documents — zero client reads, one server-side call.
 *
 * Expects: { profileId: string } (ULID)
 * Returns: { success: true }
 */
export const deleteLearnerProfile = onCall(CALL_OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const profileId = request.data?.profileId;
  if (typeof profileId !== "string" || !profileId) {
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  }

  const profileRef = db
    .collection("users")
    .doc(uid)
    .collection("learner_profiles")
    .doc(profileId);

  logger.info(`deleteLearnerProfile: uid=${uid} profileId=${profileId}`);
  await db.recursiveDelete(profileRef);
  logger.info(`deleteLearnerProfile: complete uid=${uid} profileId=${profileId}`);

  return { success: true };
});

// Sibling collections that hold track-scoped config, keyed by a `curriculum_id`
// field. They live under the *profile*, not under the track document, so
// recursiveDelete(trackRef) never touches them — each must be swept
// separately. Field name verified against firestore.rules `.hasOnly()`
// whitelists (goals, stage_definitions, study_day_configs, learning_order)
// and, for curriculum_scopes (which has no rules whitelist — open payload),
// against the `curriculum_id` fixtures in
// functions/test/firestore_rules.test.mjs (PAYLOADS.curriculum_scopes /
// the Path 21 + PHASE E test blocks).
const TRACK_SCOPED_QUERIED_COLLECTIONS = [
  "goals",
  "stage_definitions",
  "study_day_configs",
  "curriculum_scopes",
  "learning_order",
] as const;

// profile_programs is NOT keyed by a curriculum_id *field* — its doc-id IS
// the curriculumId (see firestore.rules `match /profile_programs/{curriculumId}`
// and the `programId: string, // profile_programs doc-id (curriculum_id)`
// comment in tutor_writes.ts). A direct doc delete, not a query.
const PROFILE_PROGRAMS_COLLECTION = "profile_programs";

/**
 * Callable: delete a single curriculum track document from Firestore, plus
 * every track-scoped sibling collection under the profile.
 *
 * H2 fix (V3-W1): W3.22 removed trackType from curriculum_tracks; the doc-id
 * is now just curriculumId (matching the client pushTrack fix in H1).
 * The trackType parameter is no longer required or accepted.
 *
 * Deliberately NOT swept — append-only history that must survive a track
 * delete (FR5 / E24), plus data that isn't in Firestore at all:
 *   completions, learning_ledger, streak_events, points_ledger, preferences,
 *   daily_plans (device-local only).
 *
 * Uses a single shared `bulkWriter()` (not hand-chunked WriteBatches, which
 * cap at 500 ops) across the track's recursiveDelete and every sibling sweep,
 * so a track with many config docs can't silently exceed a batch limit.
 *
 * Idempotent: every operation is a delete-if-exists (queries only match
 * surviving docs; Firestore .delete() on an already-gone doc is a no-op), so
 * re-running after a partial failure converges without double-deleting or
 * erroring.
 *
 * Partial failure: every collection is swept independently — one failing
 * does not stop the others, to make maximum forward progress before
 * reporting. If anything failed, the call throws HttpsError("internal")
 * *after* attempting everything, rather than silently returning
 * `{ success: true }` for a partial sweep. A silent partial success would
 * leave orphaned config docs with no future retry trigger; throwing routes
 * into the client's existing error-handling path, and retrying is safe
 * because the whole operation is idempotent.
 *
 * Expects: { profileId: string, curriculumId: string } (profileId is ULID)
 * Returns: { success: true, deleted: Record<string, number> }
 */
export const deleteCurriculumTrack = onCall(CALL_OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { profileId, curriculumId } = request.data ?? {};
  if (typeof profileId !== "string" || !profileId) {
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  }
  if (typeof curriculumId !== "string" || !curriculumId) {
    throw new HttpsError("invalid-argument", "curriculumId must be a non-empty string");
  }

  // H1/H2 fix: doc-id = curriculumId only (W3.22 removed trackType).
  const docId = curriculumId;
  const profileRef = db
    .collection("users").doc(uid)
    .collection("learner_profiles").doc(profileId);
  const trackRef = profileRef.collection("curriculum_tracks").doc(docId);

  const deleted: Record<string, number> = {};
  const failures: string[] = [];
  const bulkWriter = db.bulkWriter();

  // ── Sibling collections queried by `curriculum_id` field ──────────────────
  const sweepPromises = TRACK_SCOPED_QUERIED_COLLECTIONS.map(async (collectionName) => {
    let successCount = 0;
    try {
      const snap = await profileRef
        .collection(collectionName)
        .where("curriculum_id", "==", docId)
        .get();
      for (const doc of snap.docs) {
        // Fire-and-forget: bulkWriter batches/throttles internally and
        // resolves each op's promise once committed. We don't await these
        // individually (that would block batch accumulation) — `.close()`
        // below guarantees every one of these has settled before we read
        // successCount/failures.
        bulkWriter.delete(doc.ref).then(
          () => { successCount++; },
          (err) => { failures.push(`${collectionName}/${doc.id}: ${err}`); },
        );
      }
    } catch (err) {
      failures.push(`${collectionName} (query): ${err}`);
      logger.error(`deleteCurriculumTrack: query failed for ${collectionName}`, err);
    }
    // Assigned via closure after bulkWriter.close() has resolved (see below);
    // reading successCount here would race the in-flight deletes.
    return () => { deleted[collectionName] = successCount; };
  });

  // ── profile_programs: direct doc-id lookup, not a query ───────────────────
  const programRef = profileRef.collection(PROFILE_PROGRAMS_COLLECTION).doc(docId);
  const programPromise = (async () => {
    let successCount = 0;
    try {
      const programSnap = await programRef.get();
      if (programSnap.exists) {
        bulkWriter.delete(programRef).then(
          () => { successCount++; },
          (err) => { failures.push(`${PROFILE_PROGRAMS_COLLECTION}/${docId}: ${err}`); },
        );
      }
    } catch (err) {
      failures.push(`${PROFILE_PROGRAMS_COLLECTION} (read): ${err}`);
      logger.error(`deleteCurriculumTrack: read failed for ${PROFILE_PROGRAMS_COLLECTION}`, err);
    }
    return () => { deleted[PROFILE_PROGRAMS_COLLECTION] = successCount; };
  })();

  // ── The track document itself (+ any future subcollection under it) ──────
  const trackPromise = (async () => {
    let trackExisted = false;
    try {
      trackExisted = (await trackRef.get()).exists;
    } catch (err) {
      failures.push(`curriculum_tracks (read): ${err}`);
    }
    try {
      // recursiveDelete shares our bulkWriter so its throttling coordinates
      // with the sibling-collection deletes above.
      await db.recursiveDelete(trackRef, bulkWriter);
      return () => { deleted["curriculum_tracks"] = trackExisted ? 1 : 0; };
    } catch (err) {
      failures.push(`curriculum_tracks (recursiveDelete): ${err}`);
      logger.error(`deleteCurriculumTrack: recursiveDelete failed for track`, err);
      return () => { deleted["curriculum_tracks"] = 0; };
    }
  })();

  const finalizers = await Promise.all([...sweepPromises, programPromise, trackPromise]);
  // Drain the bulkWriter: resolves once every enqueued delete (including
  // retries) has settled, so the per-doc .then/.catch trackers above have
  // all fired by the time we read their results below. close() itself never
  // rejects — per-op failures are only visible via those trackers.
  await bulkWriter.close();
  for (const finalize of finalizers) finalize();

  logger.info(
    `deleteCurriculumTrack: uid=${uid} profileId=${profileId} doc=${docId} ` +
      `deleted=${JSON.stringify(deleted)}` +
      (failures.length ? ` failures=${JSON.stringify(failures)}` : ""),
  );

  if (failures.length > 0) {
    throw new HttpsError(
      "internal",
      `deleteCurriculumTrack: partial failure sweeping ${failures.length} operation(s) ` +
        `for profileId=${profileId} curriculumId=${docId}. Safe to retry (idempotent).`,
    );
  }

  return { success: true, deleted };
});

/**
 * Callable: delete bulk-marked-prior completions for a set of items in one
 * curriculum track, plus the `learning_ledger` entries that retract their
 * lifetime "learnt" status.
 *
 * Owner decision (`docs/firestore-rewrite-map.md`, "RESOLVED: prior-import
 * tier tracking...", 2026-08-02): *"app is able to delete just bulk marked
 * learning linked to a track which will remove their global learnt status
 * as well — deleting is only possible for bulk marked track learning and
 * that's it."*
 *
 * ## Why the `source` field, and why absence means "leave it alone"
 *
 * `completions` and `learning_ledger` documents carry `source: 'live' |
 * 'bulkInTrack' | 'lifetimeOnly'` (mirrors `CompletionSource`,
 * `lib/features/learning/domain/entities/completion_source.dart`), written
 * by `FirestoreCompletionRepository` / the ledger-write path. Both sweeps
 * below filter on `source == 'bulkInTrack'` and nothing else identifies a
 * row as eligible:
 *   - A `live` completion is PERMANENT — there is no undo for genuinely
 *     learned material. This is the load-bearing safety property.
 *   - A `lifetimeOnly` ledger entry is a standalone historical import, never
 *     tied to a track the user bulk-marked — it must never be touched here.
 *   - A document with NO `source` field at all (a legacy row predating this
 *     field) is deliberately left alone: `where('source', '==',
 *     'bulkInTrack')` simply never matches it. Absence means "don't touch",
 *     never "assume bulk".
 *
 * ## Completions sweep — exact, per-item
 *
 * Queries `completions` by `curriculum_id` + `source == 'bulkInTrack'`
 * (equality-only, no composite index needed), then deletes only the docs
 * whose `sefaria_ref` is in the caller-supplied [sefariaRefs] list. Bulk-mark
 * writes one completion per (item × stage), so an item with several stages
 * has several completion docs sharing that `sefaria_ref` — all of them are
 * deleted, retracting every stage's credit for that item, matching the
 * granularity of the Drift-era `BulkPriorCompletionService.
 * expungePriorCompletions` (per single item, all its stage rows).
 *
 * ## Ledger sweep — scoped by [unitIdentifiers], a REQUIRED caller-supplied list
 *
 * `learning_ledger` entries are unit-scoped (`entry_scope` +
 * `unit_identifier`, e.g. one whole masechta), written only when an entire
 * unit is detected complete (a siyum) — they carry no `sefaria_ref` or
 * `stage_id`, so this Cloud Function has no way to derive, from
 * [sefariaRefs] alone, which unit(s) they belong to. That mapping lives in
 * the curriculum's content hierarchy, a ~87K-row bundled Flutter asset this
 * Cloud Function cannot read — so the CLIENT (which has that hierarchy)
 * resolves it and passes the result as [unitIdentifiers].
 *
 * [unitIdentifiers] is REQUIRED and MUST be non-empty — there is no
 * "delete every bulkInTrack entry for the curriculum" fallback. An earlier
 * version of this function queried `learning_ledger` by `curriculum_id` +
 * `source` alone, with no per-unit narrowing: un-ticking a single daf of one
 * masechta out of a whole bulk-marked Shas (~63 masechtos) would have
 * deleted all ~63 lifetime ledger records, not just the one whose unit was
 * actually affected. That is exactly the catastrophic-over-deletion class
 * this whole function exists to prevent, reached by a different route — so
 * a missing/empty [unitIdentifiers] is rejected with `invalid-argument`
 * BEFORE either sweep runs (nothing is deleted), rather than silently
 * falling back to the wide, dangerous match.
 *
 * Residual imprecision that is INTENTIONALLY not solved here: un-ticking one
 * daf of a multi-daf masechta still retracts that whole masechta's ledger
 * entry, even though other daffim of the same masechta remain ticked. That
 * is correct, not a bug — the unit genuinely is no longer fully complete, so
 * its "I finished this masechta" record should go. The client is expected to
 * pass the [unitIdentifiers] of every unit that [sefariaRefs] touches, and
 * only those units' `bulkInTrack` ledger entries are deleted.
 *
 * Idempotent: every operation is delete-if-exists; re-running after a
 * partial failure converges without erroring (mirrors [deleteCurriculumTrack]).
 *
* Expects: { profileId: string (ULID), curriculumId: string, sefariaRefs: string[],
*            unitIdentifiers: string[] }
 * Returns: { success: true, deleted: Record<string, number> }
 */
export const deleteBulkMarkedCompletions = onCall(CALL_OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const { profileId, curriculumId, sefariaRefs, unitIdentifiers } = request.data ?? {};
  if (typeof profileId !== "string" || !profileId) {
    throw new HttpsError("invalid-argument", "profileId must be a non-empty string (ULID)");
  }
  if (typeof curriculumId !== "string" || !curriculumId) {
    throw new HttpsError("invalid-argument", "curriculumId must be a non-empty string");
  }
  if (
    !Array.isArray(sefariaRefs) ||
    sefariaRefs.length === 0 ||
    !sefariaRefs.every((ref) => typeof ref === "string" && ref.length > 0)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "sefariaRefs must be a non-empty array of non-empty strings",
    );
  }
  // No fallback here — see the class doc comment's "Ledger sweep" section.
  // A missing/empty unitIdentifiers must fail loudly (recoverable) rather
  // than silently widen the ledger sweep to the whole curriculum
  // (unrecoverable data loss).
  if (
    !Array.isArray(unitIdentifiers) ||
    unitIdentifiers.length === 0 ||
    !unitIdentifiers.every((id) => typeof id === "string" && id.length > 0)
  ) {
    throw new HttpsError(
      "invalid-argument",
      "unitIdentifiers must be a non-empty array of non-empty strings",
    );
  }
  const sefariaRefSet = new Set<string>(sefariaRefs);
  const unitIdentifierSet = new Set<string>(unitIdentifiers);

  const profileRef = db
    .collection("users").doc(uid)
    .collection("learner_profiles").doc(profileId);

  const deleted: Record<string, number> = {};
  const failures: string[] = [];
  const bulkWriter = db.bulkWriter();

  // ── completions: curriculum + source match, then filter to the given items ──
  const completionsPromise = (async () => {
    let successCount = 0;
    try {
      const snap = await profileRef
        .collection("completions")
        .where("curriculum_id", "==", curriculumId)
        .where("source", "==", "bulkInTrack")
        .get();
      for (const doc of snap.docs) {
        const sefariaRef = doc.data().sefaria_ref;
        if (typeof sefariaRef !== "string" || !sefariaRefSet.has(sefariaRef)) continue;
        bulkWriter.delete(doc.ref).then(
          () => { successCount++; },
          (err) => { failures.push(`completions/${doc.id}: ${err}`); },
        );
      }
    } catch (err) {
      failures.push(`completions (query): ${err}`);
      logger.error("deleteBulkMarkedCompletions: query failed for completions", err);
    }
    return () => { deleted["completions"] = successCount; };
  })();

  // ── learning_ledger: curriculum + source match, then filter to the given
  // units — see class doc comment's "Ledger sweep" section. Same
  // query-then-filter shape as the completions sweep above, deliberately:
  // no `where('unit_identifier', 'in', ...)` chunking to reason about, and
  // it reuses the exact pattern already proven safe there. ─────────────────
  const ledgerPromise = (async () => {
    let successCount = 0;
    try {
      const snap = await profileRef
        .collection("learning_ledger")
        .where("curriculum_id", "==", curriculumId)
        .where("source", "==", "bulkInTrack")
        .get();
      for (const doc of snap.docs) {
        const unitIdentifier = doc.data().unit_identifier;
        if (typeof unitIdentifier !== "string" || !unitIdentifierSet.has(unitIdentifier)) continue;
        bulkWriter.delete(doc.ref).then(
          () => { successCount++; },
          (err) => { failures.push(`learning_ledger/${doc.id}: ${err}`); },
        );
      }
    } catch (err) {
      failures.push("learning_ledger (query): " + err);
      logger.error("deleteBulkMarkedCompletions: query failed for learning_ledger", err);
    }
    return () => { deleted["learning_ledger"] = successCount; };
  })();

  const finalizers = await Promise.all([completionsPromise, ledgerPromise]);
  // Drain the bulkWriter before reading counts — see deleteCurriculumTrack's
  // matching comment for why this ordering matters.
  await bulkWriter.close();
  for (const finalize of finalizers) finalize();

  logger.info(
    `deleteBulkMarkedCompletions: uid=${uid} profileId=${profileId} curriculumId=${curriculumId} ` +
      `itemCount=${sefariaRefs.length} unitCount=${unitIdentifiers.length} ` +
      `deleted=${JSON.stringify(deleted)}` +
      (failures.length ? ` failures=${JSON.stringify(failures)}` : ""),
  );

  if (failures.length > 0) {
    throw new HttpsError(
      "internal",
      `deleteBulkMarkedCompletions: partial failure sweeping ${failures.length} operation(s) ` +
        `for profileId=${profileId} curriculumId=${curriculumId}. Safe to retry (idempotent).`,
    );
  }

  return { success: true, deleted };
});

/**
 * Callable: delete all Firestore data for the authenticated user.
 *
 * Call this before deleting the Firebase Auth account. The `onUserDeleted`
 * trigger also runs after Auth deletion as a safety net, but by then the
 * data is already gone (no-op).
 *
 * Expects: {} (identity comes from request.auth.uid)
 * Returns: { success: true }
 */
export const deleteAccountData = onCall(CALL_OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");

  const userDocRef = db.collection("users").doc(uid);
  logger.info(`deleteAccountData: starting for uid=${uid}`);
  await db.recursiveDelete(userDocRef);
  logger.info(`deleteAccountData: complete for uid=${uid}`);
  return { success: true };
});
