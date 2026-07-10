import * as admin from "firebase-admin";
import { logger, pubsub } from "firebase-functions/v1";

import { db } from "./shared";

// ══════════════════════════════════════════════════════════════════════════════
// W3.42 — Tutor audit-log purge (scheduled, 12-month retention)
// ══════════════════════════════════════════════════════════════════════════════
//
// Scheduled: daily at 02:00 UTC.
//
// Retention policy (from tutor-mode-brief.md §W3.42):
//   Audit log entries are retained for 12 months after the grant's terminal
//   event (revoked_at or declined_at). After that window they are purged.
//
// Algorithm:
//   1. Query tutor_grants where state ∈ {declined, rescinded, revoked_by_parent,
//      revoked_by_tutor, expired} AND revoked_at/declined_at ≤ cutoff.
//   2. For each matching grant, recursively delete the audit_log sub-collection.
//   3. The grant document itself is NOT deleted (audit trail of the relationship).
//
// Uses a Firestore batch for audit_log entries; recursive delete for safety.
// Runs in pages of 100 grants to stay within memory limits.

const AUDIT_LOG_RETENTION_MONTHS = 12;
const PURGE_BATCH_SIZE = 100;

/** Terminal grant states whose audit logs are eligible for retention purge. */
const TERMINAL_STATES = [
  "declined",
  "rescinded",
  "revoked_by_parent",
  "revoked_by_tutor",
  "expired",
];

export const purgeExpiredAuditLogs = pubsub
  .schedule("0 2 * * *") // daily at 02:00 UTC
  .timeZone("UTC")
  .onRun(async (_context) => {
    const cutoff = new Date();
    cutoff.setMonth(cutoff.getMonth() - AUDIT_LOG_RETENTION_MONTHS);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

    logger.info(
      `purgeExpiredAuditLogs: running purge for grants terminated before ${cutoff.toISOString()}`
    );

    let totalGrantsProcessed = 0;
    let totalEntriesPurged = 0;

    for (const state of TERMINAL_STATES) {
      // Query grants in this terminal state whose revoked_at/declined_at
      // field predates the cutoff. We query on `updated_at` as the canonical
      // "last state change" timestamp, which is set on every state transition.
      // This avoids needing a separate composite index per terminal-event field.
      const snapshot = await db
        .collection("tutor_grants")
        .where("state", "==", state)
        .where("updated_at", "<=", cutoffTs)
        .limit(PURGE_BATCH_SIZE)
        .get();

      for (const grantDoc of snapshot.docs) {
        const grantId = grantDoc.id;
        const auditLogRef = db
          .collection("tutor_grants")
          .doc(grantId)
          .collection("audit_log");

        // Delete all audit_log entries for this grant.
        // Using recursiveDelete rather than manual batching — simpler and
        // handles large audit logs without memory pressure.
        await db.recursiveDelete(auditLogRef);

        totalEntriesPurged++;
        totalGrantsProcessed++;

        logger.info(
          `purgeExpiredAuditLogs: purged audit_log for grant=${grantId} state=${state}`
        );
      }
    }

    logger.info(
      `purgeExpiredAuditLogs: complete — grants=${totalGrantsProcessed} ` +
        `entries-batches=${totalEntriesPurged}`
    );
  });
