import { logger, pubsub } from "firebase-functions/v1";

// ══════════════════════════════════════════════════════════════════════════════
// Billing kill-switch — hard spend cap for a hobby-budget project
// ══════════════════════════════════════════════════════════════════════════════
//
// A GCP budget only ALERTS; it cannot stop spend. This function is the actual
// cap: when the budget reports spend at or above 100% of the configured amount,
// it UNLINKS the billing account from the project, which halts all billable
// services.
//
// ⚠️ FIRING THIS TAKES THE APP DOWN. Cloud Functions stop, Firestore becomes
// inaccessible, and the app stays down until a human re-links billing in the
// Cloud console. That is the intended trade for a hobby project: a dead app is
// preferable to an unbounded invoice. Do not "improve" this into something that
// merely warns — a warning is what the budget already does.
//
// Wiring (created out-of-band, not by this repo's deploy):
//   budget  "learning-tracker hobby cap"  £5/month, scoped to this project,
//           thresholds 50% / 90% / 100%
//   topic   projects/torah-study-tracker/topics/billing-kill-switch
//
// The runtime service account must hold Billing Account Administrator on the
// billing account (to unlink) — without it this function logs an error and the
// cap silently does nothing, so verify the grant after any SA change.
//
// No new npm dependency: Node 22 has global fetch, and the runtime service
// account's access token comes from the metadata server.

/** Shape of the Cloud Billing budget notification payload (schemaVersion 1.0). */
interface BudgetNotification {
  budgetDisplayName?: string;
  alertThresholdExceeded?: number;
  costAmount?: number;
  budgetAmount?: number;
  currencyCode?: string;
}

const METADATA_TOKEN_URL =
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token";

async function accessToken(): Promise<string> {
  const res = await fetch(METADATA_TOKEN_URL, {
    headers: { "Metadata-Flavor": "Google" },
  });
  if (!res.ok) {
    throw new Error(`metadata token fetch failed: ${res.status}`);
  }
  const body = (await res.json()) as { access_token?: string };
  if (!body.access_token) throw new Error("metadata token response had no access_token");
  return body.access_token;
}

/**
 * Reads the project's current billing linkage. Returns the billing account
 * resource name, or "" when billing is already disabled.
 */
async function currentBillingAccount(projectId: string, token: string): Promise<string> {
  const res = await fetch(
    `https://cloudbilling.googleapis.com/v1/projects/${projectId}/billingInfo`,
    { headers: { Authorization: `Bearer ${token}` } },
  );
  if (!res.ok) {
    throw new Error(`billingInfo read failed: ${res.status} ${await res.text()}`);
  }
  const body = (await res.json()) as { billingAccountName?: string };
  return body.billingAccountName ?? "";
}

/** Unlinks the billing account. This is the irreversible-by-machine step. */
async function disableBilling(projectId: string, token: string): Promise<void> {
  const res = await fetch(
    `https://cloudbilling.googleapis.com/v1/projects/${projectId}/billingInfo`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ billingAccountName: "" }),
    },
  );
  if (!res.ok) {
    throw new Error(`disable billing failed: ${res.status} ${await res.text()}`);
  }
}

export const billingKillSwitch = pubsub
  .topic("billing-kill-switch")
  .onPublish(async (message) => {
    let payload: BudgetNotification;
    try {
      payload = (message.json ?? {}) as BudgetNotification;
    } catch (err) {
      logger.error("billing kill-switch: unparseable budget payload", err);
      return;
    }

    const cost = payload.costAmount ?? 0;
    const budget = payload.budgetAmount ?? 0;

    logger.info("billing kill-switch: budget notification", {
      budget: payload.budgetDisplayName,
      cost,
      budgetAmount: budget,
      currency: payload.currencyCode,
      thresholdExceeded: payload.alertThresholdExceeded,
    });

    // Only the 100% threshold arms the switch. The 50% and 90% notifications
    // are informational and MUST NOT disable billing.
    if (budget <= 0 || cost < budget) {
      logger.info("billing kill-switch: under budget, taking no action");
      return;
    }

    const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
    if (!projectId) {
      logger.error("billing kill-switch: project id unavailable; cannot act");
      return;
    }

    try {
      const token = await accessToken();
      const linked = await currentBillingAccount(projectId, token);
      if (!linked) {
        logger.warn("billing kill-switch: billing already disabled; nothing to do");
        return;
      }

      logger.error(
        "billing kill-switch: SPEND CAP REACHED — DISABLING BILLING. " +
          "The app will stop serving until billing is re-linked manually.",
        { projectId, linked, cost, budget, currency: payload.currencyCode },
      );

      await disableBilling(projectId, token);

      logger.error("billing kill-switch: billing DISABLED for " + projectId);
    } catch (err) {
      // Deliberately not rethrown: a retry storm cannot help, and the operator
      // needs the error visible in logs rather than buried in retry noise.
      logger.error("billing kill-switch: FAILED to disable billing", err);
    }
  });
