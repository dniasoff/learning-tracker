#!/usr/bin/env node
// AUD-guardrails-14 — Gate deploy-play-store.yml on a passing CI run for the
// exact SHA being deployed (Rule 0 / AG-11, bypassable gates).
//
// Before AUD-guardrails-14, deploy-play-store.yml had no `needs:`/
// `workflow_run:` dependency on ci.yml and no step checking the target SHA's
// check-run status — a maintainer who tagged a commit that never went
// through review/CI (emergency hotfix, stale local branch, wrong SHA), or
// whose ci.yml run was still red/in-progress, could ship straight to Google
// Play production. This script is that missing check.
//
// Usage (invoked as a step in the `gate-ci-status` job of
// .github/workflows/deploy-play-store.yml, run BEFORE the `deploy` job via
// `needs:`):
//
//   node tool/check_deploy_ci_gate.mjs
//
// Reads the SHA/repo to gate from the standard GitHub Actions default env
// vars (GITHUB_SHA, GITHUB_REPOSITORY) — both present on every run,
// including workflow_dispatch (where GITHUB_SHA is the SHA of the dispatched
// ref) and push:tags (where GITHUB_SHA is the commit the tag points to), so
// this always checks the exact SHA being deployed regardless of trigger.
// GITHUB_TOKEN (map from `secrets.GITHUB_TOKEN` in the workflow step) is
// optional against this public repo but keeps the call authenticated
// (higher rate limit; also required if the repo ever goes private).
//
// Overridable via flags for local/manual dry runs against any repo/SHA:
//   node tool/check_deploy_ci_gate.mjs --sha <sha> --repo <owner/repo> [--workflow ci.yml]
//
// Queries GET /repos/{repo}/actions/workflows/{workflow}/runs?head_sha={sha}
// (https://docs.github.com/en/rest/actions/workflow-runs) and requires at
// least one run for that EXACT head_sha with status=completed AND
// conclusion=success. Any other outcome — no runs at all, only in-progress/
// queued runs, or only failed/cancelled runs — fails the gate. A network/API
// error also fails the gate (fail-closed: a check that can't be evaluated
// must never be silently treated as passing — that would just relocate the
// bypass the finding names, not close it).

const DEFAULT_WORKFLOW_FILE = 'ci.yml';

/**
 * Pure decision function — exported for unit testing without any network
 * access. Given the `workflow_runs` array as returned by the GitHub REST API
 * (already scoped to one workflow file) and the target SHA, decides whether
 * the deploy gate should open.
 *
 * @param {Array<{head_sha: string, status: string, conclusion: string|null}>} runs
 * @param {string} sha
 * @returns {{ok: true} | {ok: false, reason: string}}
 */
export function evaluateGate(runs, sha) {
  const matching = (runs ?? []).filter((run) => run.head_sha === sha);

  if (matching.length === 0) {
    return {
      ok: false,
      reason: `no ${DEFAULT_WORKFLOW_FILE} run found for SHA ${sha} — the deploying commit has never been through CI`,
    };
  }

  const succeeded = matching.some(
    (run) => run.status === 'completed' && run.conclusion === 'success',
  );
  if (succeeded) {
    return { ok: true };
  }

  const statuses = matching
    .map((run) => `${run.status}/${run.conclusion ?? 'pending'}`)
    .join(', ');
  return {
    ok: false,
    reason: `SHA ${sha} has ${matching.length} ${DEFAULT_WORKFLOW_FILE} run(s), none completed successfully (${statuses})`,
  };
}

async function fetchWorkflowRuns({ repo, workflow, sha, token }) {
  const url = `https://api.github.com/repos/${repo}/actions/workflows/${workflow}/runs?head_sha=${encodeURIComponent(sha)}&per_page=50`;
  const headers = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(url, { headers });
  if (!res.ok) {
    const body = await res.text().catch(() => '<unreadable body>');
    throw new Error(
      `GitHub API request failed: HTTP ${res.status} for ${url}\n${body}`,
    );
  }
  const json = await res.json();
  return json.workflow_runs ?? [];
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--sha') out.sha = argv[++i];
    else if (arg === '--repo') out.repo = argv[++i];
    else if (arg === '--workflow') out.workflow = argv[++i];
  }
  return out;
}

export async function main() {
  const flags = parseArgs(process.argv.slice(2));
  const sha = flags.sha ?? process.env.GITHUB_SHA;
  const repo = flags.repo ?? process.env.GITHUB_REPOSITORY;
  const workflow = flags.workflow ?? DEFAULT_WORKFLOW_FILE;
  const token = process.env.GITHUB_TOKEN;

  if (!sha || !repo) {
    console.error(
      '::error::check_deploy_ci_gate: missing --sha/--repo (or GITHUB_SHA/GITHUB_REPOSITORY env vars).',
    );
    process.exitCode = 1;
    return;
  }

  let runs;
  try {
    runs = await fetchWorkflowRuns({ repo, workflow, sha, token });
  } catch (err) {
    console.error(
      `::error::check_deploy_ci_gate: could not query ${workflow} status for SHA ${sha} — failing closed (blocking deploy) rather than assume green. ${err.message}`,
    );
    process.exitCode = 1;
    return;
  }

  const result = evaluateGate(runs, sha);
  if (!result.ok) {
    console.error(
      `::error::check_deploy_ci_gate: BLOCKED — ${result.reason}. Deploys must gate on a green ${workflow} run for the exact SHA being deployed (AUD-guardrails-14 / AG-11). Push the SHA to a branch ci.yml covers (main/dev/dev/**) and wait for it to go green before tagging/dispatching a deploy.`,
    );
    process.exitCode = 1;
    return;
  }

  console.log(
    `check_deploy_ci_gate: OK — SHA ${sha} has a completed, successful ${workflow} run. Deploy gate open.`,
  );
}

// Only auto-run when executed directly (`node tool/check_deploy_ci_gate.mjs`),
// not when imported by the test file.
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err) => {
    console.error('::error::check_deploy_ci_gate: unexpected failure:', err);
    process.exitCode = 1;
  });
}
