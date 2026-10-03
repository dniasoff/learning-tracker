// DNI-490 (Story 1.28) AC-3 / AC-6 — tests for the gated production backend
// release (tool/firebase_backend_release.mjs).
//
// Run: node --test tool/firebase_backend_release.test.mjs
//
// The release runs against a fake firebase-tools runner, so every failure
// path (list, delete, verification, deploy) is simulated without touching a
// project; the REAL .github/workflows/deploy-play-store.yml is checked
// against the wiring contract (backend after the CI gate, app after the
// backend, no other deploy or delete).

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  DEPLOY_TARGETS,
  RELEASE_WORKFLOW,
  RETIRED_CALLABLES,
  ReleaseError,
  deleteArgs,
  deployArgs,
  parseFunctionsList,
  runBackendRelease,
  validateReleaseWorkflow,
} from './firebase_backend_release.mjs';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PROJECT = 'demo-release';

const listed = (...ids) => ({
  status: 0,
  stdout: JSON.stringify({ status: 'success', result: ids.map((id) => ({ id, region: 'us-central1' })) }),
  stderr: '',
});
const ok = { status: 0, stdout: '', stderr: '' };
const fail = (stderr) => ({ status: 1, stdout: '', stderr });

/**
 * A scripted firebase-tools: each command kind answers from its queue, and
 * every invocation is recorded.
 */
function fakeFirebase({ lists = [], del = ok, deploy = ok } = {}) {
  const calls = [];
  const queue = [...lists];
  const run = (args) => {
    calls.push(args);
    if (args[0] === 'functions:list') return queue.shift() ?? fail('unexpected list');
    if (args[0] === 'functions:delete') return del;
    if (args[0] === 'deploy') return deploy;
    return fail(`unexpected ${args[0]}`);
  };
  return { run, calls, kinds: () => calls.map((c) => c[0]) };
}

test('the four retired callables are exactly the AC-3 names', () => {
  assert.deepEqual([...RETIRED_CALLABLES], [
    'tutorResetCompletion',
    'tutorBulkPriorCompletions',
    'deleteBulkMarkedCompletions',
    'tutorUpsertBookmark',
  ]);
});

test('the delete and deploy commands are the AC-3 / AC-6 commands verbatim', () => {
  assert.equal(
    deleteArgs(PROJECT).join(' '),
    'functions:delete tutorResetCompletion tutorBulkPriorCompletions ' +
      'deleteBulkMarkedCompletions tutorUpsertBookmark --force --project demo-release',
  );
  assert.equal(DEPLOY_TARGETS, 'firestore:rules,firestore:indexes,functions');
  assert.equal(
    deployArgs(PROJECT).join(' '),
    'deploy --only firestore:rules,firestore:indexes,functions --project demo-release',
  );
});

test('happy path: list, delete the four, verify absent, deploy once', () => {
  const fb = fakeFirebase({
    lists: [listed('inviteTutor', ...RETIRED_CALLABLES), listed('inviteTutor')],
  });
  const steps = runBackendRelease({ run: fb.run, project: PROJECT });
  assert.deepEqual(fb.kinds(), ['functions:list', 'functions:delete', 'functions:list', 'deploy']);
  assert.deepEqual(fb.calls[1], deleteArgs(PROJECT));
  assert.deepEqual(fb.calls[3], deployArgs(PROJECT));
  assert.deepEqual(steps.map((s) => s.step), ['list-before', 'undeploy', 'verify-undeploy', 'deploy']);
});

test('a partial earlier delete still runs the exact four-name command', () => {
  const fb = fakeFirebase({ lists: [listed('tutorUpsertBookmark'), listed()] });
  runBackendRelease({ run: fb.run, project: PROJECT });
  assert.deepEqual(fb.calls[1], deleteArgs(PROJECT));
  assert.equal(fb.kinds().filter((k) => k === 'deploy').length, 1);
});

test('nothing left to delete (a re-run): skip the delete, still verify, deploy once', () => {
  const fb = fakeFirebase({ lists: [listed('inviteTutor'), listed('inviteTutor')] });
  runBackendRelease({ run: fb.run, project: PROJECT });
  assert.deepEqual(fb.kinds(), ['functions:list', 'functions:list', 'deploy']);
});

test('AC-3: a failed functions:list stops before any delete or deploy', () => {
  const fb = fakeFirebase({ lists: [fail('HTTP Error: 403, permission denied')] });
  assert.throws(
    () => runBackendRelease({ run: fb.run, project: PROJECT }),
    (e) => e instanceof ReleaseError && e.step === 'list-before' && /403/.test(e.message),
  );
  assert.deepEqual(fb.kinds(), ['functions:list']);
});

test('AC-3: an unreadable list is a failure, never "nothing deployed"', () => {
  for (const bad of [
    { status: 0, stdout: 'No functions found', stderr: '' },
    { status: 0, stdout: '{"status":"error","error":"boom"}', stderr: '' },
    { status: 0, stdout: '{"status":"success","result":{}}', stderr: '' },
    { status: 0, stdout: '{"status":"success","result":[{"name":"x"}]}', stderr: '' },
    { status: 0, stdout: '{not json', stderr: '' },
  ]) {
    const fb = fakeFirebase({ lists: [bad] });
    assert.throws(() => runBackendRelease({ run: fb.run, project: PROJECT }), ReleaseError, bad.stdout);
    assert.deepEqual(fb.kinds(), ['functions:list'], bad.stdout);
  }
});

test('AC-3: a failed delete stops before the deploy', () => {
  const fb = fakeFirebase({
    lists: [listed(...RETIRED_CALLABLES)],
    del: fail('Failed to delete function tutorUpsertBookmark'),
  });
  assert.throws(
    () => runBackendRelease({ run: fb.run, project: PROJECT }),
    (e) => e.step === 'undeploy',
  );
  assert.deepEqual(fb.kinds(), ['functions:list', 'functions:delete']);
});

test('AC-3: a callable still deployed after the delete stops before the deploy', () => {
  const fb = fakeFirebase({
    lists: [listed(...RETIRED_CALLABLES), listed('deleteBulkMarkedCompletions')],
  });
  assert.throws(
    () => runBackendRelease({ run: fb.run, project: PROJECT }),
    (e) => e.step === 'verify-undeploy' && /deleteBulkMarkedCompletions/.test(e.message),
  );
  assert.ok(!fb.kinds().includes('deploy'));
});

test('AC-3: a verification list that cannot be read stops before the deploy', () => {
  const fb = fakeFirebase({ lists: [listed(...RETIRED_CALLABLES), fail('network')] });
  assert.throws(
    () => runBackendRelease({ run: fb.run, project: PROJECT }),
    (e) => e.step === 'verify-undeploy',
  );
  assert.ok(!fb.kinds().includes('deploy'));
});

test('AC-6: a failed deploy fails the release and is not retried', () => {
  const fb = fakeFirebase({ lists: [listed(), listed()], deploy: fail('rules compile error') });
  assert.throws(
    () => runBackendRelease({ run: fb.run, project: PROJECT }),
    (e) => e.step === 'deploy' && /rules compile error/.test(e.message),
  );
  assert.equal(fb.kinds().filter((k) => k === 'deploy').length, 1);
});

test('parseFunctionsList reads ids and tolerates a log line before the JSON', () => {
  assert.deepEqual(
    parseFunctionsList(`i  functions: listing\n${listed('a', 'b').stdout}`),
    ['a', 'b'],
  );
  assert.deepEqual(parseFunctionsList(listed().stdout), []);
});

// ── Workflow contract (AC-3 / AC-6) ─────────────────────────────────────────

const GOOD = `name: Deploy
jobs:
  gate-ci-status:
    runs-on: ubuntu-latest
    steps:
      - run: node tool/check_deploy_ci_gate.mjs
  backend-deploy:
    needs: gate-ci-status
    runs-on: ubuntu-latest
    steps:
      # Comments may mention firebase deploy and functions:delete.
      - run: node tool/firebase_backend_release.mjs --mode deploy --project torah-study-tracker
  deploy:
    needs: [gate-ci-status, backend-deploy]
    runs-on: ubuntu-latest
    steps:
      - run: flutter build appbundle
`;

test('the workflow contract accepts the gated order', () => {
  assert.deepEqual(validateReleaseWorkflow(GOOD), []);
});

test('the workflow contract rejects an app release that does not wait for the backend', () => {
  const bad = GOOD.replace('needs: [gate-ci-status, backend-deploy]', 'needs: gate-ci-status');
  assert.match(validateReleaseWorkflow(bad).join('\n'), /must need `backend-deploy`/);
});

test('the workflow contract rejects a backend job that skips the CI gate', () => {
  const bad = GOOD.replace('    needs: gate-ci-status\n    runs-on: ubuntu-latest\n    steps:\n      # Comments', '    runs-on: ubuntu-latest\n    steps:\n      # Comments');
  assert.match(validateReleaseWorkflow(bad).join('\n'), /must need `gate-ci-status`/);
});

test('the workflow contract rejects a soft or conditional backend job', () => {
  const soft = GOOD.replace('  backend-deploy:\n', '  backend-deploy:\n    continue-on-error: true\n');
  assert.match(validateReleaseWorkflow(soft).join('\n'), /fail closed/);
  const cond = GOOD.replace('  backend-deploy:\n', "  backend-deploy:\n    if: github.ref == 'x'\n");
  assert.match(validateReleaseWorkflow(cond).join('\n'), /must not be conditional/);
});

test('the workflow contract rejects a dry-run, a second deploy or a direct delete', () => {
  const dry = GOOD.replace('--mode deploy', '--mode dry-run');
  assert.match(validateReleaseWorkflow(dry).join('\n'), /exactly once/);
  const twice = GOOD.replace(
    '      - run: flutter build appbundle',
    '      - run: firebase deploy --only functions\n      - run: flutter build appbundle',
  );
  assert.match(validateReleaseWorkflow(twice).join('\n'), /must not call `firebase deploy`/);
  const del = GOOD.replace(
    '      - run: flutter build appbundle',
    '      - run: firebase functions:delete x --force\n      - run: flutter build appbundle',
  );
  assert.match(validateReleaseWorkflow(del).join('\n'), /functions:delete/);
});

test('the REAL deploy-play-store.yml satisfies the release contract', () => {
  const text = readFileSync(join(repoRoot, RELEASE_WORKFLOW), 'utf8');
  assert.deepEqual(validateReleaseWorkflow(text), []);
});

test('ci.yml runs these tests in its backend-deploy-gate job', () => {
  const ci = readFileSync(join(repoRoot, '.github/workflows/ci.yml'), 'utf8');
  assert.match(ci, /node --test tool\/firebase_backend_release\.test\.mjs/);
});
