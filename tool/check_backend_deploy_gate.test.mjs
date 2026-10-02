// DNI-471 AC-7 — tests for the gated backend deploy step.
//
// Run: node --test tool/check_backend_deploy_gate.test.mjs
//
// Checks the pure contract functions against constructed workflows, and the
// REAL .github/workflows/ci.yml + learning_tracker/firebase.json against the
// contract, so a later edit that un-gates the job, makes it non-blocking or
// adds a production deploy fails CI.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  decide,
  extractJob,
  jobNeeds,
  validateDeployTargets,
  validateWorkflow,
} from './check_backend_deploy_gate.mjs';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const GOOD = `name: CI
jobs:
  firestore-rules:
    runs-on: ubuntu-latest
    steps:
      - run: make test-rules
  functions:
    runs-on: ubuntu-latest
    steps:
      - run: make test-functions
  backend-deploy-gate:
    needs: [firestore-rules, functions]
    runs-on: ubuntu-latest
    env:
      BACKEND_DEPLOY_MODE: dry-run
    steps:
      # Would run firebase deploy at cutover — comments are ignored.
      - run: node tool/check_backend_deploy_gate.mjs --mode "$BACKEND_DEPLOY_MODE"
  arb-parity:
    runs-on: ubuntu-latest
`;

test('extractJob returns only the named job block', () => {
  const job = extractJob(GOOD, 'backend-deploy-gate');
  assert.match(job, /needs: \[firestore-rules, functions\]/);
  assert.doesNotMatch(job, /arb-parity/);
  assert.equal(extractJob(GOOD, 'missing'), null);
});

test('jobNeeds parses inline, single and list forms', () => {
  assert.deepEqual(jobNeeds('    needs: [a, b]\n'), ['a', 'b']);
  assert.deepEqual(jobNeeds('    needs: a\n'), ['a']);
  assert.deepEqual(jobNeeds('    needs:\n      - a\n      - b\n    runs-on: x\n'), ['a', 'b']);
  assert.deepEqual(jobNeeds('    runs-on: x\n'), []);
});

test('a gate that needs rules + functions, dry-run only, passes', () => {
  assert.deepEqual(validateWorkflow(GOOD), []);
});

test('missing gate job fails', () => {
  assert.match(validateWorkflow(GOOD.replace('backend-deploy-gate:', 'other-job:')).join(), /no `backend-deploy-gate` job/);
});

test('a gate that does not need the rules or functions jobs fails', () => {
  const errs = validateWorkflow(GOOD.replace('needs: [firestore-rules, functions]', 'needs: [functions]')).join('\n');
  assert.match(errs, /must need `firestore-rules`/);
});

test('a non-blocking or conditional gate fails', () => {
  const nonBlocking = GOOD.replace('    runs-on: ubuntu-latest\n    env:', '    runs-on: ubuntu-latest\n    continue-on-error: true\n    env:');
  assert.match(validateWorkflow(nonBlocking).join(), /must be blocking/);
  const conditional = GOOD.replace('    runs-on: ubuntu-latest\n    env:', "    runs-on: ubuntu-latest\n    if: github.ref == 'refs/heads/main'\n    env:");
  assert.match(validateWorkflow(conditional).join(), /must not be conditional/);
});

test('a production deploy, a secret or a non-dry-run mode fails (AD-49)', () => {
  const deploys = GOOD.replace(
    '      - run: node tool/check_backend_deploy_gate.mjs',
    '      - run: firebase deploy --only firestore:rules --token x\n      - run: node tool/check_backend_deploy_gate.mjs',
  );
  assert.match(validateWorkflow(deploys).join(), /must not invoke `firebase deploy`/);
  const secret = GOOD.replace('BACKEND_DEPLOY_MODE: dry-run', 'BACKEND_DEPLOY_MODE: dry-run\n      FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}');
  assert.match(validateWorkflow(secret).join(), /must not reference any secret/);
  const mode = GOOD.replace('BACKEND_DEPLOY_MODE: dry-run', 'BACKEND_DEPLOY_MODE: deploy');
  assert.match(validateWorkflow(mode).join(), /must pin BACKEND_DEPLOY_MODE: dry-run/);
});

test('decide: dry-run prints the gated command; deploy and unknown modes are refused', () => {
  const dry = decide('dry-run');
  assert.equal(dry.ok, true);
  assert.match(dry.message, /firebase deploy --only firestore:rules,firestore:indexes,functions/);
  assert.equal(decide('deploy').ok, false);
  assert.match(decide('deploy').message, /DNI-490/);
  assert.equal(decide(undefined).ok, false);
});

test('the real ci.yml satisfies the gate contract', () => {
  const ci = readFileSync(join(repoRoot, '.github/workflows/ci.yml'), 'utf8');
  assert.deepEqual(validateWorkflow(ci), []);
});

test('the real firebase.json declares rules, indexes and functions deploy inputs', () => {
  // The functions entry point exists only after `npm run build`; the CI job
  // builds first. Here, only the build-output error is tolerated.
  const errs = validateDeployTargets(join(repoRoot, 'learning_tracker'))
    .filter((e) => !/not built/.test(e));
  assert.deepEqual(errs, []);
});
