import * as admin from "firebase-admin";
import { logger } from "firebase-functions/v1";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import { db } from "./shared";

// ══════════════════════════════════════════════════════════════════════════════
// onChangeLogCreated — parent push when a tutor changes the goal or the main
// track (sub-tracks Story 4.7 / DNI-515; AD-39, AD-54, prd-deviations #9).
// ══════════════════════════════════════════════════════════════════════════════
//
// Bound to users/{ownerUid}/learner_profiles/{profileId}/change_log/{entryId}.
// For a created entry it:
//
//   1. pushes only when `actor.role == "tutor"` and the entity is one of
//      PUSH_ELIGIBLE_ENTITIES (goal and the main track's identity, order,
//      program and study days). Stages, scope, learner settings, sub-tracks
//      and every parent or child entry stay silent — they still appear in the
//      Change history, which this trigger never edits (AC-3);
//   2. sends at most one push per `action_id`: only the push-eligible entry
//      with the smallest id among the entries sharing its action id sends
//      (writeWithChangeLog commits all of them in one transaction, so every
//      sibling exists when the trigger fires). A delivery receipt at
//      users/{ownerUid}/learner_profiles/{profileId}/push_receipts/{actionId}
//      makes repeated and concurrent deliveries of the event send once
//      (AC-2). The receipt holds ids (the action, entry and delivered
//      install ids), the entity, counts and times only — no
//      learner data — and goes with the profile/account recursive deletes;
//   3. reads tokens from the OWNING account only — the uid in the change_log
//      path — never from the tutor's account, even when the tutor also owns a
//      family account (AC-8);
//   4. sends DATA-ONLY FCM messages. The app decides whether to show them:
//      a device that has dropped back to child role suppresses the message
//      even when its token removal has not synced yet (AC-5). The app renders
//      the localized copy from `kind`, `tutor_name` and `learner_name` (AC-1);
//   5. prunes a token only when FCM reports it unregistered or invalid, and
//      only if the install still holds that same token; transient errors keep
//      it (AC-7). An install whose send failed transiently is retried: the
//      receipt records the installs already delivered (or pruned), releases
//      its claim and the binding throws, so the retry-enabled trigger runs
//      again and sends only to the installs still owed the push. After
//      MAX_DELIVERY_ATTEMPTS the receipt is finalized with the failure count;
//   6. logs structured `{entity, code}` lines only — never a uid, profile id,
//      token, tutor or learner name (AD-54).
//
// The function ships through the gated backend deploy: `firebase deploy
// --only functions` deploys every export of index.ts (AC-9, ruling B5).

/** prd-deviations #9: the only entities whose tutor edits notify the parent. */
export const PUSH_ELIGIBLE_ENTITIES: ReadonlySet<string> = new Set([
  "goal",
  "mainTrack",
  "mainTrackOrder",
  "mainTrackProgram",
  "mainTrackStudyDays",
]);

/** Per-profile delivery receipts, keyed by action id (Admin-only; rules deny). */
export const PUSH_RECEIPTS_COLLECTION = "push_receipts";

/** Wire value of the data payload's `type`. */
export const PUSH_TYPE_TUTOR_CHANGE = "tutor_change";

/**
 * How long a claimed-but-unfinished delivery blocks another attempt. A
 * duplicate delivery inside the lease skips; a retry after a crashed attempt
 * (lease expired) sends.
 */
export const DELIVERY_LEASE_MS = 120_000;

/**
 * Deliveries of one action that may end with transient per-install failures
 * before the receipt is finalized anyway (the platform retries a failed
 * event with backoff; this bounds it well inside its retry window).
 */
export const MAX_DELIVERY_ATTEMPTS = 5;

/** Thrown by the binding so the platform retries a transiently failed send. */
export class PushRetryableError extends Error {
  readonly code = "retryable_send_failure";
  constructor() {
    super("parent push has installs still owed the message");
    this.name = "PushRetryableError";
  }
}

/** FCM error codes that mean the token can never deliver again. */
const DEAD_TOKEN_CODES: ReadonlySet<string> = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/** The change kinds the app has copy for (`parentPushKind*` ARB keys). */
export type PushKind =
  | "deadline"
  | "pace"
  | "mainTrack"
  | "mainTrackOrder"
  | "mainTrackProgram"
  | "mainTrackStudyDays";

/** Minimal FCM surface the trigger uses — swapped for a fake in tests. */
export interface PushMessaging {
  sendEach(messages: admin.messaging.Message[]): Promise<admin.messaging.BatchResponse>;
}

let messagingOverride: PushMessaging | null = null;

/** Test seam: route sends through [fake]; `null` restores the Admin SDK. */
export function setPushMessagingForTests(fake: PushMessaging | null): void {
  messagingOverride = fake;
}

function messaging(): PushMessaging {
  return messagingOverride ?? admin.messaging();
}

/** True when a change_log entry by [role] on [entity] should notify the parent. */
export function isPushEligible(role: unknown, entity: unknown): boolean {
  return role === "tutor" && typeof entity === "string" && PUSH_ELIGIBLE_ENTITIES.has(entity);
}

/** The app-facing change kind of an eligible entry. */
export function pushKind(entity: string, entityId: unknown, after: unknown): PushKind {
  if (entity !== "goal") return entity as PushKind;
  const goalType =
    after !== null && typeof after === "object" ? (after as Record<string, unknown>)["goal_type"] : undefined;
  if (goalType === "pace") return "pace";
  if (goalType === undefined && typeof entityId === "string" && entityId.endsWith("_pace")) return "pace";
  return "deadline";
}

export interface ChangeLogEvent {
  ownerUid: string;
  profileId: string;
  entryId: string;
  entry: Record<string, unknown>;
}

/** What one trigger invocation did — returned for tests, never logged. */
export type PushOutcome =
  | "ineligible"
  | "not_first_in_action"
  | "already_delivered"
  | "no_tokens"
  | "sent"
  | "retry";

/**
 * The trigger body. Exported so the emulator tests can drive it directly as
 * well as through the deployed binding.
 */
export async function handleChangeLogCreated(ev: ChangeLogEvent): Promise<PushOutcome> {
  const { ownerUid, profileId, entryId, entry } = ev;
  const entity = entry["entity"];
  const actor = entry["actor"] as Record<string, unknown> | undefined;
  if (!isPushEligible(actor?.["role"], entity)) return "ineligible";
  const actionId = entry["action_id"];
  const profileRef = db.collection("users").doc(ownerUid).collection("learner_profiles").doc(profileId);

  // Smallest-id push-eligible entry of the action sends; the rest stay quiet.
  if (typeof actionId === "string" && actionId.length > 0) {
    const siblings = await profileRef.collection("change_log").where("action_id", "==", actionId).get();
    const eligibleIds = siblings.docs
      .filter((d) => isPushEligible(d.get("actor")?.role, d.get("entity")))
      .map((d) => d.id);
    eligibleIds.push(entryId);
    eligibleIds.sort();
    if (eligibleIds[0] !== entryId) return "not_first_in_action";
  }
  const receiptId = typeof actionId === "string" && actionId.length > 0 ? actionId : entryId;

  const receiptRef = profileRef.collection(PUSH_RECEIPTS_COLLECTION).doc(receiptId);
  const claim = await db.runTransaction(async (txn) => {
    const snap = await txn.get(receiptRef);
    const nowMs = Date.now();
    if (snap.exists) {
      if (snap.get("state") === "sent") return null;
      const claimedAt = snap.get("claimed_at") as admin.firestore.Timestamp | undefined;
      if (claimedAt && nowMs - claimedAt.toMillis() < DELIVERY_LEASE_MS) return null;
    }
    const attempt = (snap.exists ? numberOr(snap.get("attempts"), 0) : 0) + 1;
    const done = snap.exists ? stringList(snap.get("done_installs")) : [];
    txn.set(receiptRef, {
      entry_id: entryId,
      entity,
      state: "claimed",
      claimed_at: admin.firestore.Timestamp.fromMillis(nowMs),
      attempts: attempt,
      done_installs: done,
    });
    return { attempt, done: new Set(done) };
  });
  if (claim === null) return "already_delivered";

  try {
    return await deliver(ev, profileRef, receiptRef, receiptId, claim);
  } catch (err) {
    // Release the claim so the platform's retry of this event is not
    // turned away as a duplicate inside the lease.
    await receiptRef
      .update({ state: "retry", claimed_at: admin.firestore.FieldValue.delete() })
      .catch(() => undefined);
    throw err;
  }
}

/** Sends to every install still owed the push, then settles the receipt. */
async function deliver(
  ev: ChangeLogEvent,
  profileRef: admin.firestore.DocumentReference,
  receiptRef: admin.firestore.DocumentReference,
  receiptId: string,
  claim: { attempt: number; done: Set<string> },
): Promise<PushOutcome> {
  const { ownerUid, profileId, entryId, entry } = ev;
  const entity = entry["entity"];
  const actor = entry["actor"] as Record<string, unknown> | undefined;

  // AC-8: the owning account from the path — never the tutor's account.
  const [account, profile] = await Promise.all([
    db.collection("users").doc(ownerUid).get(),
    profileRef.get(),
  ]);
  const tokens = readTokens(account.get("fcm_tokens")).filter((t) => !claim.done.has(t.installId));
  if (tokens.length === 0) {
    await receiptRef.set(
      {
        state: "sent",
        sent_at: admin.firestore.FieldValue.serverTimestamp(),
        claimed_at: admin.firestore.FieldValue.delete(),
        token_count: 0,
        success_count: 0,
      },
      { merge: true },
    );
    return claim.done.size === 0 ? "no_tokens" : "sent";
  }

  const data: Record<string, string> = {
    type: PUSH_TYPE_TUTOR_CHANGE,
    owner_uid: ownerUid,
    profile_id: profileId,
    action_id: receiptId,
    entry_id: entryId,
    kind: pushKind(entity as string, entry["entity_id"], entry["after"]),
    tutor_name: typeof actor?.["display_name"] === "string" ? (actor["display_name"] as string) : "",
    learner_name: stringOr(profile.get("display_name"), ""),
  };
  const messages: admin.messaging.Message[] = tokens.map(({ token }) => ({
    token,
    data,
    // Data-only (no `notification`): the OS never renders it on its own, so
    // the app can suppress it in child role (AC-5). High priority lets the
    // Android background handler run promptly.
    android: { priority: "high" },
    apns: {
      headers: { "apns-push-type": "background", "apns-priority": "5" },
      payload: { aps: { contentAvailable: true } },
    },
  }));

  const response = await messaging().sendEach(messages);
  const deadInstalls: Array<{ installId: string; token: string }> = [];
  const settled: string[] = [];
  let retryable = 0;
  response.responses.forEach((r, i) => {
    if (r.success) {
      settled.push(tokens[i].installId);
      return;
    }
    const code = r.error?.code ?? "unknown";
    if (DEAD_TOKEN_CODES.has(code)) {
      deadInstalls.push(tokens[i]);
      settled.push(tokens[i].installId);
      logger.warn("parent_push_token_pruned", { entity, code });
    } else {
      retryable += 1;
      logger.warn("parent_push_send_failed", { entity, code });
    }
  });
  if (deadInstalls.length > 0) await pruneTokens(ownerUid, deadInstalls);

  const done = [...claim.done, ...settled].sort();
  if (retryable > 0 && claim.attempt < MAX_DELIVERY_ATTEMPTS) {
    // Not finalized: release the claim and let the platform retry the event
    // for the installs still owed the push (the ones in done_installs are
    // never sent twice).
    await receiptRef.update({
      state: "retry",
      claimed_at: admin.firestore.FieldValue.delete(),
      done_installs: done,
      token_count: tokens.length,
      success_count: response.successCount,
    });
    return "retry";
  }
  if (retryable > 0) logger.error("parent_push_gave_up", { entity, code: "max_attempts" });

  await receiptRef.set(
    {
      state: "sent",
      sent_at: admin.firestore.FieldValue.serverTimestamp(),
      claimed_at: admin.firestore.FieldValue.delete(),
      done_installs: done,
      token_count: tokens.length,
      success_count: response.successCount,
      failed_count: retryable,
    },
    { merge: true },
  );
  return "sent";
}

function numberOr(v: unknown, fallback: number): number {
  return typeof v === "number" && Number.isFinite(v) ? v : fallback;
}

function stringList(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
}

function stringOr(v: unknown, fallback: string): string {
  return typeof v === "string" ? v : fallback;
}

/** `fcm_tokens` map → `[{installId, token}]`, skipping malformed entries. */
function readTokens(raw: unknown): Array<{ installId: string; token: string }> {
  if (raw === null || typeof raw !== "object") return [];
  const out: Array<{ installId: string; token: string }> = [];
  for (const [installId, value] of Object.entries(raw as Record<string, unknown>)) {
    if (value === null || typeof value !== "object") continue;
    const token = (value as Record<string, unknown>)["token"];
    if (typeof token === "string" && token.length > 0) out.push({ installId, token });
  }
  return out.sort((a, b) => a.installId.localeCompare(b.installId));
}

/**
 * Deletes `fcm_tokens[installId]` for each dead install — only while the
 * install still holds the token that failed, so a re-registration that raced
 * the send is kept.
 */
async function pruneTokens(
  ownerUid: string,
  dead: Array<{ installId: string; token: string }>,
): Promise<void> {
  const accountRef = db.collection("users").doc(ownerUid);
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(accountRef);
    const current = snap.get("fcm_tokens") as Record<string, { token?: unknown }> | undefined;
    const args: Array<admin.firestore.FieldPath | admin.firestore.FieldValue> = [];
    for (const { installId, token } of dead) {
      if (current?.[installId]?.token !== token) continue;
      args.push(new admin.firestore.FieldPath("fcm_tokens", installId), admin.firestore.FieldValue.delete());
    }
    if (args.length === 0) return;
    const [first, firstValue, ...rest] = args;
    txn.update(accountRef, first as admin.firestore.FieldPath, firstValue, ...rest);
  });
}

export const onChangeLogCreated = onDocumentCreated(
  {
    document: "users/{ownerUid}/learner_profiles/{profileId}/change_log/{entryId}",
    // A thrown error (including PushRetryableError for installs still owed
    // the push) redelivers the event; the receipt keeps redelivery idempotent.
    retry: true,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    try {
      const outcome = await handleChangeLogCreated({
        ownerUid: event.params.ownerUid,
        profileId: event.params.profileId,
        entryId: event.params.entryId,
        entry: snap.data() ?? {},
      });
      if (outcome === "retry") throw new PushRetryableError();
    } catch (err) {
      const code = (err as { code?: unknown })?.code;
      logger.error("parent_push_failed", {
        entity: typeof snap.get("entity") === "string" ? snap.get("entity") : "unknown",
        code: typeof code === "string" || typeof code === "number" ? String(code) : "internal",
      });
      throw err;
    }
  },
);
