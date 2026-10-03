// DNI-490 (Story 1.28) AC-3 / AC-6 — the gated production backend release.
//
// AD-54: `firebase deploy --only firestore:rules,firestore:indexes,functions`
// is a gated CI step that runs once and must pass before the app release that
// depends on it. AD-49: the cutover release also undeploys the callables whose
// source was deleted in Stories 1.16 and 1.26. A callable missing from
// functions/src is NOT evidence that production no longer hosts it, and
// `firebase deploy --only functions` run non-interactively does not delete it.
//
// Order (fail closed at every step; nothing later runs after a failure):
//   1. validate the deploy inputs (firebase.json, rules, indexes, built
//      functions entry) — tool/check_backend_deploy_gate.mjs;
//   2. `firebase functions:list --json` — which retired callables are live;
//   3. `firebase functions:delete <the four> --force` when any of them is live
//      (the exact AC-3 command; firebase-tools deletes the matching ones and
//      only errors when none matches, which step 2 rules out);
//   4. `firebase functions:list --json` again — fail if any of the four is
//      still deployed or the list cannot be read;
//   5. `firebase deploy --only firestore:rules,firestore:indexes,functions`,
//      exactly once, never retried;
//   6. DNI-491 (Story 1.29) AC-5 — `firebase firestore:indexes --json`: which
//      indexes are deployed. Run non-interactively, step 5 creates the
//      declared indexes but NEVER deletes one that the file no longer lists
//      (firebase-tools only logs "run this command with the --force flag"),
//      so the retired collections' indexes would stay in production;
//   7. when an index of a retired collection (R14 in
//      learning_tracker/tool/retired_symbols/R14.json) is still deployed:
//      `firebase deploy --only firestore:indexes --force`, which deletes the
//      deployed indexes and field overrides the file does not declare. It
//      runs only after checking that everything it would delete belongs to a
//      retired collection or to a collection group the file declares (whose
//      declared indexes are the intended set); anything else — an index of an
//      unknown collection group, a field override the file does not declare —
//      stops the release instead of being deleted;
//   8. `firebase firestore:indexes --json` again — fail if an index of a
//      retired collection is still deployed.
//
// Wiring: .github/workflows/deploy-play-store.yml job `backend-deploy` runs
// `node tool/firebase_backend_release.mjs --mode deploy --project
// torah-study-tracker` after `gate-ci-status` (green ci.yml for the release
// SHA); the app `deploy` job `needs` it and the AD-54 `perf-gate` job
// (DNI-490 AC-5). validateReleaseWorkflow() pins that
// wiring and runs in this file's tests (ci.yml backend-deploy-gate job) and in
// the release workflow itself.
//
// Credential (rulings B5, user decision 2026-10-01): the FIREBASE_TOKEN repo
// secret, read by firebase-tools from the environment. A service-account key
// in GOOGLE_APPLICATION_CREDENTIALS is accepted too. Missing both stops the
// run before any production call.
//
// Run:
//   node tool/firebase_backend_release.mjs --mode dry-run --project torah-study-tracker
//   node tool/firebase_backend_release.mjs --mode deploy  --project torah-study-tracker
//   node --test tool/firebase_backend_release.test.mjs

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractJob, jobNeeds, validateDeployTargets } from './check_backend_deploy_gate.mjs';

/** The callables whose source Stories 1.16 and 1.26 deleted (AC-3). */
export const RETIRED_CALLABLES = Object.freeze([
  'tutorResetCompletion',
  'tutorBulkPriorCompletions',
  'deleteBulkMarkedCompletions',
  'tutorUpsertBookmark',
]);

export const DEPLOY_TARGETS = 'firestore:rules,firestore:indexes,functions';
export const INDEX_TARGET = 'firestore:indexes';
export const PRODUCTION_PROJECT = 'torah-study-tracker';

export const RELEASE_WORKFLOW = '.github/workflows/deploy-play-store.yml';
export const BACKEND_JOB = 'backend-deploy';
export const APP_JOB = 'deploy';
export const CI_GATE_JOB = 'gate-ci-status';
export const PERF_GATE_JOB = 'perf-gate';

/** `firebase functions:delete <the four> --force` (AC-3, verbatim). */
export function deleteArgs(project) {
  return ['functions:delete', ...RETIRED_CALLABLES, '--force', '--project', project];
}

/** `firebase deploy --only firestore:rules,firestore:indexes,functions`. */
export function deployArgs(project) {
  return ['deploy', '--only', DEPLOY_TARGETS, '--project', project];
}

export function listArgs(project) {
  return ['functions:list', '--json', '--project', project];
}

/** `firebase firestore:indexes --json` — the deployed index spec. */
export function indexListArgs(project) {
  return ['firestore:indexes', '--json', '--project', project];
}

/**
 * `firebase deploy --only firestore:indexes --force` — the only way
 * firebase-tools deletes, non-interactively, an index the file dropped.
 */
export function indexPruneArgs(project) {
  return ['deploy', '--only', INDEX_TARGET, '--force', '--project', project];
}

/**
 * The deployed index spec from `firebase firestore:indexes --json` output
 * (`{"status":"success","result":{"indexes":[...],"fieldOverrides":[...]}}`,
 * or the bare spec). Throws on anything else: an unreadable list is never
 * treated as "no index deployed".
 */
export function parseIndexSpec(stdout) {
  const text = String(stdout ?? '');
  const start = text.indexOf('{');
  if (start < 0) throw new Error('firestore:indexes printed no JSON');
  let parsed;
  try {
    parsed = JSON.parse(text.slice(start));
  } catch (e) {
    throw new Error(`firestore:indexes printed invalid JSON: ${e.message}`);
  }
  if ('status' in (parsed ?? {})) {
    if (parsed.status !== 'success') {
      throw new Error(`firestore:indexes did not succeed: ${JSON.stringify(parsed.error ?? parsed.status)}`);
    }
    parsed = parsed.result;
  }
  return readIndexSpec(parsed, 'firestore:indexes result');
}

/** Validates an index spec ({indexes, fieldOverrides?}) and returns it. */
export function readIndexSpec(spec, label = 'index spec') {
  if (!spec || !Array.isArray(spec.indexes)) {
    throw new Error(`${label} has no "indexes" list`);
  }
  const fieldOverrides = spec.fieldOverrides ?? [];
  if (!Array.isArray(fieldOverrides)) {
    throw new Error(`${label} "fieldOverrides" is not a list`);
  }
  const groupOf = (entry, i, kind) => {
    const g = entry?.collectionGroup;
    if (typeof g !== 'string' || !g) {
      throw new Error(`${label} ${kind} ${i} has no collectionGroup`);
    }
    return g;
  };
  return {
    indexes: spec.indexes.map((x, i) => ({ ...x, collectionGroup: groupOf(x, i, 'index') })),
    fieldOverrides: fieldOverrides.map((x, i) => ({
      ...x,
      collectionGroup: groupOf(x, i, 'field override'),
    })),
  };
}

/**
 * What a `deploy --only firestore:indexes --force` against [deployed] would
 * delete that is NOT safe to delete: an index of a collection group that is
 * neither declared in [declared] nor [retired], or a field override that
 * [declared] does not list (by collection group and field path, the
 * firebase-tools match). Empty = the prune is safe.
 */
export function unsafePrunes(deployed, declared, retired) {
  const declaredGroups = new Set(declared.indexes.map((i) => i.collectionGroup));
  const retiredSet = new Set(retired);
  const overrideKey = (f) => `${f.collectionGroup}/${f.fieldPath}`;
  const declaredOverrides = new Set(declared.fieldOverrides.map(overrideKey));
  return [
    ...deployed.indexes
      .filter((i) => !declaredGroups.has(i.collectionGroup) && !retiredSet.has(i.collectionGroup))
      .map((i) => `index on ${i.collectionGroup}`),
    ...deployed.fieldOverrides
      .filter((f) => !declaredOverrides.has(overrideKey(f)))
      .map((f) => `field override ${overrideKey(f)}`),
  ];
}

/**
 * The deployed function ids from `firebase functions:list --json` output
 * (`{"status":"success","result":[{"id":...}, ...]}`). Throws on anything
 * else: a list that cannot be read is never treated as "nothing deployed".
 */
export function parseFunctionsList(stdout) {
  const text = String(stdout ?? '');
  const start = text.indexOf('{');
  if (start < 0) throw new Error('functions:list printed no JSON');
  let parsed;
  try {
    parsed = JSON.parse(text.slice(start));
  } catch (e) {
    throw new Error(`functions:list printed invalid JSON: ${e.message}`);
  }
  if (parsed?.status !== 'success') {
    throw new Error(`functions:list did not succeed: ${JSON.stringify(parsed?.error ?? parsed?.status)}`);
  }
  if (!Array.isArray(parsed.result)) {
    throw new Error('functions:list result is not a list');
  }
  return parsed.result.map((endpoint, i) => {
    const id = endpoint?.id;
    if (typeof id !== 'string' || !id) {
      throw new Error(`functions:list entry ${i} has no function id`);
    }
    return id;
  });
}

export class ReleaseError extends Error {
  constructor(step, message) {
    super(`${step}: ${message}`);
    this.step = step;
  }
}

/**
 * Runs the release against [run] (`(args) => {status, stdout, stderr}`, one
 * firebase-tools invocation). Returns the steps it ran; throws ReleaseError
 * (naming the failed step) on the first failure, before any later step.
 */
export function runBackendRelease({ run, project, declaredIndexes, retiredCollections, log = () => {} }) {
  if (!project) throw new ReleaseError('args', '--project is required');
  let declared;
  try {
    declared = readIndexSpec(declaredIndexes, 'firestore.indexes.json');
  } catch (e) {
    throw new ReleaseError('args', e.message);
  }
  if (!Array.isArray(retiredCollections) || retiredCollections.length === 0) {
    throw new ReleaseError('args', 'the retired collections (R14) are required');
  }
  const retiredDeclared = declared.indexes
    .map((i) => i.collectionGroup)
    .filter((g) => retiredCollections.includes(g));
  if (retiredDeclared.length > 0) {
    throw new ReleaseError('args', `firestore.indexes.json still declares a retired index: ${retiredDeclared.join(', ')}`);
  }
  const steps = [];
  const invoke = (step, args) => {
    steps.push({ step, args });
    log(`$ firebase ${args.join(' ')}`);
    const r = run(args);
    if (!r || r.status !== 0) {
      const why = r?.error?.message ?? (r?.stderr || r?.stdout || '').toString().trim();
      throw new ReleaseError(step, `firebase exited ${r?.status ?? 'without a status'}${why ? ` — ${why}` : ''}`);
    }
    return r;
  };
  const listRetired = (step) => {
    const r = invoke(step, listArgs(project));
    let ids;
    try {
      ids = parseFunctionsList(r.stdout);
    } catch (e) {
      throw new ReleaseError(step, e.message);
    }
    return RETIRED_CALLABLES.filter((name) => ids.includes(name));
  };

  const live = listRetired('list-before');
  if (live.length > 0) {
    log(`Retired callables still deployed: ${live.join(', ')}`);
    invoke('undeploy', deleteArgs(project));
  } else {
    log('None of the retired callables is deployed; nothing to delete.');
  }
  const remaining = listRetired('verify-undeploy');
  if (remaining.length > 0) {
    throw new ReleaseError('verify-undeploy', `still deployed after delete: ${remaining.join(', ')}`);
  }
  log(`Verified absent: ${RETIRED_CALLABLES.join(', ')}`);
  invoke('deploy', deployArgs(project));

  // DNI-491 AC-5: drop the retired collections' indexes in production.
  const listIndexes = (step) => {
    const r = invoke(step, indexListArgs(project));
    try {
      return parseIndexSpec(r.stdout);
    } catch (e) {
      throw new ReleaseError(step, e.message);
    }
  };
  const retiredLive = (spec) => [
    ...new Set(spec.indexes.map((i) => i.collectionGroup).filter((g) => retiredCollections.includes(g))),
  ];
  const deployed = listIndexes('list-indexes');
  const liveIndexes = retiredLive(deployed);
  if (liveIndexes.length === 0) {
    log('No index of a retired collection is deployed; nothing to prune.');
    return steps;
  }
  log(`Indexes of retired collections still deployed: ${liveIndexes.join(', ')}`);
  const unsafe = unsafePrunes(deployed, declared, retiredCollections);
  if (unsafe.length > 0) {
    throw new ReleaseError(
      'prune-indexes',
      `refusing \`firebase ${indexPruneArgs(project).join(' ')}\`: it would also delete ${unsafe.join(', ')}, ` +
        'which firestore.indexes.json does not declare and no retired collection owns. ' +
        'Declare them or delete them by hand, then re-run the release.',
    );
  }
  invoke('prune-indexes', indexPruneArgs(project));
  const leftIndexes = retiredLive(listIndexes('verify-indexes'));
  if (leftIndexes.length > 0) {
    throw new ReleaseError('verify-indexes', `still deployed after the prune: ${leftIndexes.join(', ')}`);
  }
  log(`Verified no index of a retired collection is deployed (${retiredCollections.join(', ')}).`);
  return steps;
}

/** The R14 retired collections from the AD-49 inventory. */
export function readRetiredCollections(projectDir) {
  const r14 = JSON.parse(readFileSync(join(projectDir, 'tool/retired_symbols/R14.json'), 'utf8'));
  return r14.entries.filter((e) => e.kind === 'collection').map((e) => e.symbol);
}

/**
 * Contract for the release workflow (AC-3, AC-6). Returns violations (empty
 * = OK): the backend job runs after the CI gate, blocking and unconditional,
 * through this script in deploy mode; the app job needs it; nothing else in
 * the workflow deploys the backend or deletes functions.
 */
export function validateReleaseWorkflow(text) {
  const errors = [];
  const backend = extractJob(text, BACKEND_JOB);
  const app = extractJob(text, APP_JOB);
  if (extractJob(text, CI_GATE_JOB) == null) errors.push(`no \`${CI_GATE_JOB}\` job`);
  if (backend == null) return [...errors, `no \`${BACKEND_JOB}\` job`];
  if (app == null) return [...errors, `no \`${APP_JOB}\` (app release) job`];
  if (!jobNeeds(backend).includes(CI_GATE_JOB)) {
    errors.push(`\`${BACKEND_JOB}\` must need \`${CI_GATE_JOB}\` (green CI for the release SHA)`);
  }
  if (!jobNeeds(app).includes(BACKEND_JOB)) {
    errors.push(`the app release job \`${APP_JOB}\` must need \`${BACKEND_JOB}\``);
  }
  // AC-5: the AD-54 benchmark gates this release.
  const perf = extractJob(text, PERF_GATE_JOB);
  if (perf == null) {
    errors.push(`no \`${PERF_GATE_JOB}\` job (AD-54 benchmark release gate)`);
  } else {
    if (!jobNeeds(app).includes(PERF_GATE_JOB)) {
      errors.push(`the app release job \`${APP_JOB}\` must need \`${PERF_GATE_JOB}\``);
    }
    if (!/learner_state_engine_benchmark_test\.dart/.test(perf.replace(/^\s*#.*$/gm, ''))) {
      errors.push(`\`${PERF_GATE_JOB}\` must run test/benchmark/learner_state_engine_benchmark_test.dart`);
    }
  }
  for (const [name, job] of [[BACKEND_JOB, backend], [APP_JOB, app], [PERF_GATE_JOB, perf ?? '']]) {
    if (/^ {4}continue-on-error:\s*true/m.test(job) || /^ {8}continue-on-error:\s*true/m.test(job)) {
      errors.push(`\`${name}\` must fail closed (no continue-on-error)`);
    }
    if (/^ {4}if:/m.test(job)) errors.push(`\`${name}\` must not be conditional (no job-level if:)`);
  }
  const code = (s) => s.replace(/^\s*#.*$/gm, '');
  const runs = code(backend).match(/node tool\/firebase_backend_release\.mjs[^\n]*/g) ?? [];
  if (runs.length !== 1 || !/--mode deploy\b/.test(runs[0]) || !runs[0].includes(`--project ${PRODUCTION_PROJECT}`)) {
    errors.push(`\`${BACKEND_JOB}\` must run \`node tool/firebase_backend_release.mjs --mode deploy --project ${PRODUCTION_PROJECT}\` exactly once`);
  }
  const all = code(text);
  if (/firebase\s+deploy\b/.test(all)) {
    errors.push('the workflow must not call `firebase deploy` directly (only through the release script)');
  }
  if (/functions:delete/.test(all)) {
    errors.push('the workflow must not call `firebase functions:delete` directly (only through the release script)');
  }
  return errors;
}

function parseArgs(argv) {
  const get = (flag) => {
    const i = argv.indexOf(flag);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  return { mode: get('--mode'), project: get('--project') };
}

function main(argv) {
  const { mode, project } = parseArgs(argv);
  const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const projectDir = join(repoRoot, 'learning_tracker');
  if (mode !== 'dry-run' && mode !== 'deploy') {
    console.error(`::error::--mode must be dry-run or deploy (got ${JSON.stringify(mode)})`);
    return 2;
  }
  if (!project) {
    console.error('::error::--project is required');
    return 2;
  }
  const errors = [
    ...validateReleaseWorkflow(readFileSync(join(repoRoot, RELEASE_WORKFLOW), 'utf8')).map((e) => `${RELEASE_WORKFLOW}: ${e}`),
    ...validateDeployTargets(projectDir),
  ];
  let declaredIndexes;
  let retiredCollections;
  try {
    declaredIndexes = JSON.parse(readFileSync(join(projectDir, 'firestore.indexes.json'), 'utf8'));
    retiredCollections = readRetiredCollections(projectDir);
    const stillDeclared = readIndexSpec(declaredIndexes, 'firestore.indexes.json').indexes
      .map((i) => i.collectionGroup)
      .filter((g) => retiredCollections.includes(g));
    if (stillDeclared.length) {
      errors.push(`firestore.indexes.json still declares a retired index: ${stillDeclared.join(', ')}`);
    }
  } catch (e) {
    errors.push(`index inputs: ${e.message}`);
  }
  if (errors.length) {
    for (const e of errors) console.error(`::error::${e}`);
    return 1;
  }
  if (mode === 'dry-run') {
    console.log('DRY-RUN — the release would run, in order:');
    console.log(`  firebase ${listArgs(project).join(' ')}`);
    console.log(`  firebase ${deleteArgs(project).join(' ')}   (only if any is deployed)`);
    console.log(`  firebase ${listArgs(project).join(' ')}   (fail if any remains)`);
    console.log(`  firebase ${deployArgs(project).join(' ')}   (once)`);
    console.log(`  firebase ${indexListArgs(project).join(' ')}`);
    console.log(`  firebase ${indexPruneArgs(project).join(' ')}   (only if an index of a retired collection is deployed, and only it or other undeclared indexes of declared groups would go)`);
    console.log(`  firebase ${indexListArgs(project).join(' ')}   (fail if an index of a retired collection remains)`);
    return 0;
  }
  if (!process.env.FIREBASE_TOKEN && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('::error::No production deploy credential: set the FIREBASE_TOKEN repo secret (rulings B5) or GOOGLE_APPLICATION_CREDENTIALS.');
    return 1;
  }
  const run = (args) => spawnSync('firebase', [...args, '--non-interactive'], {
    cwd: projectDir,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    maxBuffer: 64 * 1024 * 1024,
  });
  try {
    runBackendRelease({
      run: (args) => {
        const r = run(args);
        if (r.stdout && !args.includes('--json')) process.stdout.write(r.stdout);
        if (r.stderr) process.stderr.write(r.stderr);
        return r;
      },
      project,
      declaredIndexes,
      retiredCollections,
      log: (m) => console.log(m),
    });
  } catch (e) {
    console.error(`::error::Backend release failed at ${e.message}`);
    return 1;
  }
  console.log(`Backend release done: retired callables absent; ${DEPLOY_TARGETS} deployed once to ${project}; no index of a retired collection deployed.`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
