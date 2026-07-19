// AUD-guardrails-14 — regression tests for the deploy-play-store.yml CI gate.
//
// Run: node --test tool/check_deploy_ci_gate.test.mjs
//
// Exercises the pure `evaluateGate` decision function against constructed
// GitHub `workflow_runs` payloads (no network) so the gate's blocking logic
// is deterministically, continuously checked — not just demonstrated once
// by hand. A separate live dry run (see commit message) additionally
// exercises the real network path (`fetchWorkflowRuns` + `main`) against the
// actual public repo, for both a missing-CI SHA and an in-progress-CI SHA.

import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateGate } from './check_deploy_ci_gate.mjs';

const SHA = 'deadbeef00000000000000000000000000000001';
const OTHER_SHA = 'cafef00d00000000000000000000000000000002';

test('blocks when no run at all exists for the deploying SHA (missing CI run)', () => {
  const result = evaluateGate([], SHA);
  assert.equal(result.ok, false);
  assert.match(result.reason, /no ci\.yml run found/);
});

test('blocks when only OTHER shas have runs (never confuses SHAs)', () => {
  const runs = [
    { head_sha: OTHER_SHA, status: 'completed', conclusion: 'success' },
  ];
  const result = evaluateGate(runs, SHA);
  assert.equal(result.ok, false);
  assert.match(result.reason, /no ci\.yml run found/);
});

test('blocks when the run for the SHA is still in progress (failing/missing CI run per AC2)', () => {
  const runs = [
    { head_sha: SHA, status: 'in_progress', conclusion: null },
  ];
  const result = evaluateGate(runs, SHA);
  assert.equal(result.ok, false);
  assert.match(result.reason, /in_progress\/pending/);
});

test('blocks when the run for the SHA completed but failed', () => {
  const runs = [
    { head_sha: SHA, status: 'completed', conclusion: 'failure' },
  ];
  const result = evaluateGate(runs, SHA);
  assert.equal(result.ok, false);
  assert.match(result.reason, /completed\/failure/);
});

test('blocks when the run for the SHA was cancelled', () => {
  const runs = [
    { head_sha: SHA, status: 'completed', conclusion: 'cancelled' },
  ];
  const result = evaluateGate(runs, SHA);
  assert.equal(result.ok, false);
});

test('opens the gate when the SHA has a completed, successful run', () => {
  const runs = [
    { head_sha: SHA, status: 'completed', conclusion: 'success' },
  ];
  const result = evaluateGate(runs, SHA);
  assert.deepEqual(result, { ok: true });
});

test('opens the gate on a re-run: an earlier failure plus a later success both present', () => {
  const runs = [
    { head_sha: SHA, status: 'completed', conclusion: 'failure' },
    { head_sha: SHA, status: 'completed', conclusion: 'success' },
  ];
  const result = evaluateGate(runs, SHA);
  assert.deepEqual(result, { ok: true });
});

test('does not let a successful run for a different SHA open the gate for this SHA', () => {
  const runs = [
    { head_sha: OTHER_SHA, status: 'completed', conclusion: 'success' },
    { head_sha: SHA, status: 'completed', conclusion: 'failure' },
  ];
  const result = evaluateGate(runs, SHA);
  assert.equal(result.ok, false);
});
