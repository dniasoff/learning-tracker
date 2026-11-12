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
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import {
  DEPLOY_TARGETS,
  PRODUCTION_PROJECT,
  RELEASE_WORKFLOW,
  RETIRED_CALLABLES,
  ReleaseError,
  deleteArgs,
  deployArgs,
  failedDeployFunctionNames,
  parseFunctionsList,
  retryFunctionDeployArgs,
  runBackendRelease,
  validateReleaseWorkflow,
  writeProjectEnvironmentFile,
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
  const deployQueue = Array.isArray(deploy) ? [...deploy] : null;
  const run = (args) => {
    calls.push(args);
    if (args[0] === 'functions:list') return queue.shift() ?? fail('unexpected list');
    if (args[0] === 'functions:delete') return del;
    if (args[0] === 'deploy') return deployQueue ? deployQueue.shift() ?? ok : deploy;
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
  assert.equal(
    deployArgs(PROJECT, ['alpha', 'translatePhrases', 'beta']).join(' '),
    'deploy --only firestore:rules,firestore:indexes,functions:alpha,functions:beta --project demo-release',
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

test('phrase translation disabled deploys every built export except translatePhrases', () => {
  const exports = ['inviteTutor', 'translatePhrases', 'dailySummary'];
  const fb = fakeFirebase({ lists: [listed(...RETIRED_CALLABLES), listed()] });
  runBackendRelease({
    run: fb.run,
    project: PROJECT,
    phraseTranslationEnabled: false,
    deployFunctionNames: exports,
  });
  assert.deepEqual(fb.calls.at(-1), [
    'deploy',
    '--only',
    'firestore:rules,firestore:indexes,functions:inviteTutor,functions:dailySummary',
    '--project',
    PROJECT,
  ]);
});

test('enabled phrase translation retains the original all-functions deploy', () => {
  const fb = fakeFirebase({ lists: [listed(), listed()] });
  runBackendRelease({
    run: fb.run,
    project: PROJECT,
    phraseTranslationEnabled: true,
    deployFunctionNames: ['inviteTutor', 'translatePhrases'],
  });
  assert.deepEqual(fb.calls.at(-1), deployArgs(PROJECT));
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

test('AC-6: a non-function deploy failure fails the release without retrying', () => {
  const fb = fakeFirebase({ lists: [listed(), listed()], deploy: fail('rules compile error') });
  assert.throws(
    () => runBackendRelease({ run: fb.run, project: PROJECT }),
    (e) => e.step === 'deploy' && /rules compile error/.test(e.message),
  );
  assert.equal(fb.kinds().filter((k) => k === 'deploy').length, 1);
});

test('Cloud Run service errors map to exported function names', () => {
  assert.deepEqual(
    failedDeployFunctionNames(
      'Could not create or update Cloud Run service tutorrecordlearning.\nCould not create or update Cloud Run service listmyschools.',
      ['tutorRecordLearning', 'listMySchools', 'getLearningGroup'],
    ),
    { names: ['tutorRecordLearning', 'listMySchools'], unknown: [] },
  );
  assert.deepEqual(
    failedDeployFunctionNames('Could not create or update Cloud Run service mystery-function.', ['listMySchools']),
    { names: [], unknown: ['mystery-function'] },
  );
});

test('a partial Cloud Run failure retries only its mapped functions', () => {
  const first = fail('Could not create or update Cloud Run service tutorrecordlearning.\nCould not create or update Cloud Run service listmyschools.');
  const fb = fakeFirebase({ lists: [listed(), listed()], deploy: [first, ok] });
  const steps = runBackendRelease({
    run: fb.run,
    project: PROJECT,
    deployFunctionNames: ['tutorRecordLearning', 'listMySchools', 'getLearningGroup'],
  });
  assert.deepEqual(fb.calls.slice(-2), [
    deployArgs(PROJECT),
    retryFunctionDeployArgs(PROJECT, ['tutorRecordLearning', 'listMySchools']),
  ]);
  assert.deepEqual(steps.slice(-2).map(({ step }) => step), ['deploy', 'deploy-retry-1']);
});

test('function deploy retries reparse failures and stop after two retries', () => {
  const fb = fakeFirebase({
    lists: [listed(), listed()],
    deploy: [
      fail('Could not create or update Cloud Run service tutorrecordlearning.'),
      fail('Could not create or update Cloud Run service listmyschools.'),
      fail('Could not create or update Cloud Run service listmyschools.'),
    ],
  });
  assert.throws(() => runBackendRelease({
    run: fb.run,
    project: PROJECT,
    deployFunctionNames: ['tutorRecordLearning', 'listMySchools'],
  }), (error) => error.step === 'deploy');
  assert.deepEqual(fb.calls.slice(-3), [
    deployArgs(PROJECT),
    retryFunctionDeployArgs(PROJECT, ['tutorRecordLearning']),
    retryFunctionDeployArgs(PROJECT, ['listMySchools']),
  ]);
});

test('unknown Cloud Run services are not retried', () => {
  const fb = fakeFirebase({
    lists: [listed(), listed()],
    deploy: fail('Could not create or update Cloud Run service unrecognized-function.'),
  });
  assert.throws(() => runBackendRelease({
    run: fb.run,
    project: PROJECT,
    deployFunctionNames: ['listMySchools'],
  }), (error) => error.step === 'deploy');
  assert.equal(fb.calls.filter((args) => args[0] === 'deploy').length, 1);
});

test('project env file configures translation without touching emulator .env.local', () => {
  const root = mkdtempSync(join(tmpdir(), 'firebase-release-env-'));
  const functionsDir = join(root, 'functions');
  mkdirSync(functionsDir);
  const localEnv = join(functionsDir, '.env.local');
  const localEnvContents = `LOCAL_TEST_VALUE=preserve${String.fromCharCode(10)}`;
  writeFileSync(localEnv, localEnvContents);
  try {
    const path = writeProjectEnvironmentFile(functionsDir, PRODUCTION_PROJECT, false);
    assert.equal(path, join(functionsDir, '.env.torah-study-tracker'));
    assert.equal(readFileSync(path, 'utf8'), 'PHRASE_TRANSLATION_ENABLED=false\n');
    assert.equal(readFileSync(localEnv, 'utf8'), localEnvContents);
    writeProjectEnvironmentFile(functionsDir, PRODUCTION_PROJECT, true);
    assert.equal(readFileSync(path, 'utf8'), 'PHRASE_TRANSLATION_ENABLED=true\n');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
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
    needs: [gate-ci-status, perf-gate]
    runs-on: ubuntu-latest
    steps:
      # Comments may mention firebase deploy and functions:delete.
      - env:
          PHRASE_TRANSLATION_ENABLED: \${{ vars.PHRASE_TRANSLATION_ENABLED }}
        run: node tool/firebase_backend_release.mjs --mode deploy --project torah-study-tracker
  perf-gate:
    needs: gate-ci-status
    runs-on: ubuntu-latest
    steps:
      - run: flutter test --tags perf test/benchmark/learner_state_engine_benchmark_test.dart
  deploy:
    needs: [gate-ci-status, backend-deploy, perf-gate]
    runs-on: ubuntu-latest
    steps:
      - run: flutter build appbundle
`;

test('the workflow contract accepts the gated order', () => {
  assert.deepEqual(validateReleaseWorkflow(GOOD), []);
});

test('the workflow contract rejects an app release that does not wait for the backend', () => {
  const bad = GOOD.replace('needs: [gate-ci-status, backend-deploy, perf-gate]', 'needs: [gate-ci-status, perf-gate]');
  assert.match(validateReleaseWorkflow(bad).join('\n'), /must need `backend-deploy`/);
});

test('AC-5: the workflow contract requires the perf gate before the app release', () => {
  const noNeed = GOOD.replace('needs: [gate-ci-status, backend-deploy, perf-gate]', 'needs: [gate-ci-status, backend-deploy]');
  assert.match(validateReleaseWorkflow(noNeed).join('\n'), /must need `perf-gate`/);
  const soft = GOOD.replace('  perf-gate:\n', '  perf-gate:\n    continue-on-error: true\n');
  assert.match(validateReleaseWorkflow(soft).join('\n'), /`perf-gate` must fail closed/);
  const other = GOOD.replace('test/benchmark/learner_state_engine_benchmark_test.dart', 'test/other_test.dart');
  assert.match(validateReleaseWorkflow(other).join('\n'), /must run test\/benchmark/);
});

test('the workflow contract rejects a backend job that skips the CI gate', () => {
  const bad = GOOD.replace('    needs: [gate-ci-status, perf-gate]\n', '    needs: [perf-gate]\n');
  assert.match(validateReleaseWorkflow(bad).join('\n'), /`backend-deploy` must need `gate-ci-status`/);
});

test('fyh.324: the backend cutover waits for the perf gate', () => {
  // A red perf gate skips the app; the backend must not release without it.
  const single = GOOD.replace('    needs: [gate-ci-status, perf-gate]\n', '    needs: gate-ci-status\n');
  assert.match(validateReleaseWorkflow(single).join('\n'), /`backend-deploy` must need `perf-gate`/);
  const block = GOOD.replace('    needs: [gate-ci-status, perf-gate]\n', '    needs:\n      - gate-ci-status\n      - perf-gate\n');
  assert.deepEqual(validateReleaseWorkflow(block), []);
  // An `if: always()` (or any job-level if) would run it after a red perf gate.
  const always = GOOD.replace('  backend-deploy:\n', '  backend-deploy:\n    if: always()\n');
  assert.match(validateReleaseWorkflow(always).join('\n'), /`backend-deploy` must not be conditional/);
  const softPerf = GOOD.replace('  perf-gate:\n', '  perf-gate:\n    if: ${{ !cancelled() }}\n');
  assert.match(validateReleaseWorkflow(softPerf).join('\n'), /`perf-gate` must not be conditional/);
  const ungatedPerf = GOOD.replace('  perf-gate:\n    needs: gate-ci-status\n', '  perf-gate:\n');
  assert.match(validateReleaseWorkflow(ungatedPerf).join('\n'), /`perf-gate` must need `gate-ci-status`/);
  const softCi = GOOD.replace('  gate-ci-status:\n', '  gate-ci-status:\n    continue-on-error: true\n');
  assert.match(validateReleaseWorkflow(softCi).join('\n'), /`gate-ci-status` must fail closed/);
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
