import { onCall, HttpsError } from "firebase-functions/v2/https";

import { CALL_OPTS } from "./shared";
import {
  decodeGovernedActionWire,
  isGovernedEntity,
  runGoverned,
  writeWithChangeLog,
} from "./write_with_change_log";

// ══════════════════════════════════════════════════════════════════════════════
// ownerOversizedGovernedWrite — the online implementation of the Story 1.8
// `OversizedGovernedWritePort` (sub-tracks AD-38 Batching, AD-54 budget).
// ══════════════════════════════════════════════════════════════════════════════
//
// An owner batch carries at most 10 governed docs (the Rules access-call
// budget). An entity write over that budget — a long reorder, an order reset —
// goes online through this owner-only callable, which wraps writeWithChangeLog
// (Admin SDK, no Rules budget): one transaction, one change_log entry per
// entity, field-level merges, idempotent on the client entry ULIDs.
//
// There is deliberately no tutor route here: tutors write through the tutor
// callables. A caller who is not the profile owner — including an active
// tutor, or an owner naming another user's path in `ownerUid` — is rejected.
//
// Request (owner intent/patch shape, decoded by decodeGovernedActionWire):
//   {
//     profileId: string,
//     actorRole?: 'parent' | 'child',          // owner role, accepted as asserted
//     actionId?: ULID,                         // defaults to entries[0].id
//     revertsActionId?: ULID,                  // undo actions only; parent actor only
//     entries: [{
//       id: ULID,                              // the change_log entry id
//       entity: 'mainTrackOrder' | …,          // AD-38 governed entity
//       entityId: string,                      // curriculumId for mainTrack*
//       docs: [{ collection, docId, fields, mode?: 'create'|'upsert'|'update' }],
//     }],
//   }
// Field values use AD-52 storage names; `ended_at: true` tombstones a doc.
// Returns writeWithChangeLog's result ({ success, action_id, change_ids, at, … }).

export const ownerOversizedGovernedWrite = onCall(CALL_OPTS, (request) => {
  const first = (request.data?.entries ?? [])[0];
  const entity = isGovernedEntity(first?.entity) ? first.entity : "unknown";
  return runGoverned(entity, async () => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");
    // Owner-only, checked before anything else: naming another user's path
    // or presenting a tutor grant is a permission failure, not a shape error.
    const { ownerUid, grantId } = (request.data ?? {}) as { ownerUid?: unknown; grantId?: unknown };
    if ((ownerUid !== undefined && ownerUid !== uid) || grantId !== undefined) {
      throw new HttpsError("permission-denied", "Only the profile owner may call this function");
    }
    const wire = decodeGovernedActionWire(request.data);
    return writeWithChangeLog(request.auth, {
      ownerUid: uid,
      profileId: wire.profileId,
      actorRole: wire.actorRole,
      actionId: wire.actionId,
      revertsActionId: wire.revertsActionId,
      callerPolicy: "owner-only",
      entries: wire.entries,
    });
  });
});
