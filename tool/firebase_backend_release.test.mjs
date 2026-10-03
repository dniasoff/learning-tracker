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
  indexListArgs,
  indexPruneArgs,
  parseFunctionsList,
  parseIndexSpec,
  readRetiredCollections,
  runBackendRelease as runRelease,
  unsafePrunes,
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

// DNI-491: synthetic retired collections and a declared index set for the
// fake runs (the real ones are checked against R14 and the real file below).
const RETIRED = ['old_events', 'old_order'];
const index = (collectionGroup, fieldPath = 'curriculum_id') => ({
  collectionGroup,
  queryScope: 'COLLECTION',
  fields: [{ fieldPath, order: 'ASCENDING' }],
});
const DECLARED = { indexes: [index('goals'), index('track_old_order')], fieldOverrides: [] };
const indexesListed = (indexes, fieldOverrides = []) => ({
  status: 0,
  stdout: JSON.stringify({ status: 'success', result: { indexes, fieldOverrides } }),
  stderr: '',
});
const CLEAN = indexesListed(DECLARED.indexes);

const runBackendRelease = (opts) =>
  runRelease({ declaredIndexes: DECLARED, retiredCollections: RETIRED, ...opts });

/**
 * A scripted firebase-tools: each command kind answers from its queue, and
 * every invocation is recorded. The index prune (`deploy --only
 * firestore:indexes --force`) is reported as kind `prune`.
 */
function fakeFirebase({ lists = [], del = ok, deploy = ok, indexLists = [CLEAN], prune = ok } = {}) {
  const calls = [];
  const queue = [...lists];
  const indexQueue = [...indexLists];
  const isPrune = (args) => args[0] === 'deploy' && args.includes('--force');
  const run = (args) => {
    calls.push(args);
    if (args[0] === 'functions:list') return queue.shift() ?? fail('unexpected list');
    if (args[0] === 'functions:delete') return del;
    if (isPrune(args)) return prune;
    if (args[0] === 'deploy') return deploy;
    if (args[0] === 'firestore:indexes') return indexQueue.shift() ?? fail('unexpected index list');
    return fail(`unexpected ${args[0]}`);
  };
  return { run, calls, kinds: () => calls.map((c) => (isPrune(c) ? 'prune' : c[0])) };
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
  assert.deepEqual(fb.kinds(), ['functions:list', 'functions:delete', 'functions:list', 'deploy', 'firestore:indexes']);
  assert.deepEqual(fb.calls[1], deleteArgs(PROJECT));
  assert.deepEqual(fb.calls[3], deployArgs(PROJECT));
  assert.deepEqual(fb.calls[4], indexListArgs(PROJECT));
  assert.deepEqual(steps.map((s) => s.step), ['list-before', 'undeploy', 'verify-undeploy', 'deploy', 'list-indexes']);
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
  assert.deepEqual(fb.kinds(), ['functions:list', 'functions:list', 'deploy', 'firestore:indexes']);
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

// ── DNI-491 (Story 1.29) AC-5 — the retired indexes leave production ────────
//
// A non-interactive `firebase deploy --only ...firestore:indexes...` never
// deletes an index the file dropped, so after the deploy the release lists
// the deployed indexes and, when a retired collection's index is still
// there, prunes with `deploy --only firestore:indexes --force` — but only
// when nothing else undeclared would go — and verifies it is gone.

test('AC-5: the prune and index-list commands', () => {
  assert.equal(indexListArgs(PROJECT).join(' '), 'firestore:indexes --json --project demo-release');
  assert.equal(
    indexPruneArgs(PROJECT).join(' '),
    'deploy --only firestore:indexes --force --project demo-release',
  );
});

test('AC-5: a retired index still deployed is pruned after the deploy, then verified gone', () => {
  const fb = fakeFirebase({
    lists: [listed(), listed()],
    indexLists: [
      // A stale shape of a declared group goes too: the file is that group's intended set.
      indexesListed([...DECLARED.indexes, index('old_events', '__name__'), index('old_order'), index('goals', 'stale')]),
      CLEAN,
    ],
  });
  const steps = runBackendRelease({ run: fb.run, project: PROJECT });
  assert.deepEqual(fb.kinds(), [
    'functions:list', 'functions:list', 'deploy', 'firestore:indexes', 'prune', 'firestore:indexes',
  ]);
  assert.deepEqual(fb.calls[4], indexPruneArgs(PROJECT));
  assert.deepEqual(steps.map((s) => s.step).slice(3), ['list-indexes', 'prune-indexes', 'verify-indexes']);
  assert.equal(fb.kinds().filter((k) => k === 'deploy').length, 1, 'the AD-54 deploy still runs once');
});

test('AC-5: no retired index deployed (a re-run) skips the prune', () => {
  const fb = fakeFirebase({ lists: [listed(), listed()], indexLists: [CLEAN] });
  runBackendRelease({ run: fb.run, project: PROJECT });
  assert.ok(!fb.kinds().includes('prune'));
});

test('AC-5: the prune never deletes an index or field override nobody declared', () => {
  for (const [label, deployed, needle] of [
    ['unknown group', indexesListed([index('old_events'), index('hand_made')]), 'index on hand_made'],
    [
      'undeclared field override',
      indexesListed([index('old_events')], [{ collectionGroup: 'goals', fieldPath: 'title', indexes: [] }]),
      'field override goals/title',
    ],
  ]) {
    const fb = fakeFirebase({ lists: [listed(), listed()], indexLists: [deployed] });
    assert.throws(
      () => runBackendRelease({ run: fb.run, project: PROJECT }),
      (e) => e.step === 'prune-indexes' && e.message.includes(needle),
      label,
    );
    assert.ok(!fb.kinds().includes('prune'), label);
  }
});

test('AC-5: a failed prune, a retired index left after it, or an unreadable index list fails the release', () => {
  const live = indexesListed([...DECLARED.indexes, index('old_order')]);
  const cases = [
    [{ indexLists: [live], prune: fail('index delete denied') }, 'prune-indexes'],
    [{ indexLists: [live, live] }, 'verify-indexes'],
    [{ indexLists: [live, fail('network')] }, 'verify-indexes'],
    [{ indexLists: [fail('HTTP Error: 403')] }, 'list-indexes'],
    [{ indexLists: [{ status: 0, stdout: '{"status":"success","result":{}}', stderr: '' }] }, 'list-indexes'],
  ];
  for (const [opts, step] of cases) {
    const fb = fakeFirebase({ lists: [listed(), listed()], ...opts });
    assert.throws(
      () => runBackendRelease({ run: fb.run, project: PROJECT }),
      (e) => e instanceof ReleaseError && e.step === step,
      step,
    );
  }
});

test('AC-5: a declared retired index, or missing index inputs, stop the release before any call', () => {
  for (const opts of [
    { declaredIndexes: { indexes: [index('old_events')] } },
    { declaredIndexes: { indexes: 'x' } },
    { retiredCollections: [] },
  ]) {
    const fb = fakeFirebase();
    assert.throws(
      () => runBackendRelease({ run: fb.run, project: PROJECT, ...opts }),
      (e) => e.step === 'args',
    );
    assert.deepEqual(fb.calls, []);
  }
});

test('parseIndexSpec reads the --json envelope and the bare spec', () => {
  const spec = { indexes: [index('goals')], fieldOverrides: [] };
  assert.deepEqual(parseIndexSpec(JSON.stringify({ status: 'success', result: spec })).indexes, spec.indexes);
  assert.deepEqual(parseIndexSpec(JSON.stringify(spec)).fieldOverrides, []);
  assert.throws(() => parseIndexSpec('{"status":"error","error":"x"}'));
  assert.throws(() => parseIndexSpec('{"status":"success","result":{"indexes":[{"fields":[]}]}}'));
  assert.deepEqual(unsafePrunes(parseIndexSpec(JSON.stringify(spec)), spec, RETIRED), []);
});

test('the real inputs: R14 names five retired collections and firestore.indexes.json declares none', () => {
  const projectDir = join(repoRoot, 'learning_tracker');
  const retired = readRetiredCollections(projectDir);
  assert.equal(retired.length, 5);
  const declared = JSON.parse(readFileSync(join(projectDir, 'firestore.indexes.json'), 'utf8'));
  assert.deepEqual(declared.indexes.filter((i) => retired.includes(i.collectionGroup)), []);
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
