// DNI-471 (story 1.9) AC-7 / AD-54 — the gated backend deploy step.
//
// AD-54: `firebase deploy --only firestore:rules,firestore:indexes,functions`
// is a gated CI step that must pass before the app release that depends on
// it. AD-49: nothing reaches production before the cutover release (DNI-490),
// so in this story the gate runs in DRY-RUN mode only — it validates the
// deploy inputs and prints the exact command it would run, and REFUSES
// `--mode deploy`. DNI-490 owns flipping it to a real deploy (rulings B5).
//
// Wiring (ci.yml job `backend-deploy-gate`):
//   needs: [firestore-rules, functions]  — the emulator rules suite (+ TQ-9)
//                                          and the Cloud Functions suite
//   The job is a normal (blocking) ci.yml job, so a ci.yml run is green only
//   when it passes; deploy-play-store.yml's gate-ci-status
//   (tool/check_deploy_ci_gate.mjs) requires a green ci.yml run for the
//   released SHA, so every app release depends on this gate.
//
// Run:
//   node tool/check_backend_deploy_gate.mjs --mode dry-run   (CI)
//   node --test tool/check_backend_deploy_gate.test.mjs      (its own tests)

import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEPLOY_COMMAND =
  'firebase deploy --only firestore:rules,firestore:indexes,functions';
export const GATE_JOB = 'backend-deploy-gate';
export const REQUIRED_NEEDS = ['firestore-rules', 'functions'];

/**
 * Returns the raw text block of a top-level ci.yml job (2-space indented key
 * under `jobs:`), or null when the job is absent. Line-based on purpose: the
 * repo root has no YAML dependency and ci.yml's layout is fixed by convention.
 */
export function extractJob(workflowText, jobName) {
  const lines = workflowText.split('\n');
  const start = lines.findIndex((l) => l === `  ${jobName}:`);
  if (start < 0) return null;
  const out = [];
  for (let i = start + 1; i < lines.length; i++) {
    const l = lines[i];
    // Next top-level job (or a top-level key) ends the block; comments
    // between jobs belong to neither.
    if (/^ {2}[A-Za-z0-9_-]+:\s*$/.test(l) || /^[A-Za-z]/.test(l)) break;
    out.push(l);
  }
  return out.join('\n');
}

/** Parses `needs: [a, b]` or a `needs:` list from a job block. */
export function jobNeeds(jobText) {
  const inline = jobText.match(/^ {4}needs:\s*\[([^\]]*)\]/m);
  if (inline) {
    return inline[1].split(',').map((s) => s.trim()).filter(Boolean);
  }
  const single = jobText.match(/^ {4}needs:\s*([A-Za-z0-9_-]+)\s*$/m);
  if (single) return [single[1]];
  const block = jobText.match(/^ {4}needs:\s*\n((?: {6}- .*\n?)+)/m);
  if (block) {
    return block[1]
      .split('\n')
      .map((l) => l.replace(/^ {6}- /, '').trim())
      .filter(Boolean);
  }
  return [];
}

/**
 * Contract for the gate job in ci.yml. Returns a list of violations (empty =
 * OK). Asserts what AC-7 needs and what AD-49 forbids in this story.
 */
export function validateWorkflow(workflowText) {
  const errors = [];
  const job = extractJob(workflowText, GATE_JOB);
  if (job == null) {
    return [`ci.yml has no \`${GATE_JOB}\` job`];
  }
  const needs = jobNeeds(job);
  for (const n of REQUIRED_NEEDS) {
    if (!needs.includes(n)) {
      errors.push(`\`${GATE_JOB}\` must need \`${n}\` (has: ${needs.join(', ') || 'none'})`);
    }
    if (extractJob(workflowText, n) == null) {
      errors.push(`ci.yml has no \`${n}\` job for \`${GATE_JOB}\` to depend on`);
    }
  }
  if (/^ {4}continue-on-error:\s*true/m.test(job)) {
    errors.push(`\`${GATE_JOB}\` must be blocking (no continue-on-error)`);
  }
  if (/^ {4}if:/m.test(job)) {
    errors.push(`\`${GATE_JOB}\` must not be conditional (no job-level if:)`);
  }
  if (!/BACKEND_DEPLOY_MODE:\s*dry-run\b/.test(job)) {
    errors.push(`\`${GATE_JOB}\` must pin BACKEND_DEPLOY_MODE: dry-run (AD-49)`);
  }
  if (/secrets\./.test(job)) {
    errors.push(`\`${GATE_JOB}\` must not reference any secret (no production credential)`);
  }
  if (/firebase\s+deploy/.test(job.replace(/^\s*#.*$/gm, ''))) {
    errors.push(`\`${GATE_JOB}\` must not invoke \`firebase deploy\` directly (dry-run only)`);
  }
  if (!/check_backend_deploy_gate\.mjs\s+--mode\s+"?\$BACKEND_DEPLOY_MODE"?/.test(job)) {
    errors.push(`\`${GATE_JOB}\` must run tool/check_backend_deploy_gate.mjs --mode "$BACKEND_DEPLOY_MODE"`);
  }
  // Nothing else in ci.yml may deploy the backend either.
  const uncommented = workflowText.replace(/^\s*#.*$/gm, '');
  if (/firebase\s+deploy/.test(uncommented)) {
    errors.push('ci.yml must not run `firebase deploy` anywhere (AD-49: no production deploy before cutover)');
  }
  return errors;
}

/**
 * Validates the deploy inputs `firebase deploy --only
 * firestore:rules,firestore:indexes,functions` would read, relative to the
 * Firebase project dir (learning_tracker/).
 */
export function validateDeployTargets(projectDir) {
  const errors = [];
  const configPath = join(projectDir, 'firebase.json');
  if (!existsSync(configPath)) return [`missing ${configPath}`];
  let config;
  try {
    config = JSON.parse(readFileSync(configPath, 'utf8'));
  } catch (e) {
    return [`firebase.json is not valid JSON: ${e.message}`];
  }
  const rules = config.firestore?.rules;
  const indexes = config.firestore?.indexes;
  const functionsSource = config.functions?.source;
  if (!rules) errors.push('firebase.json declares no firestore.rules');
  else if (!existsSync(join(projectDir, rules))) errors.push(`rules file ${rules} not found`);
  if (!indexes) errors.push('firebase.json declares no firestore.indexes');
  else if (!existsSync(join(projectDir, indexes))) errors.push(`indexes file ${indexes} not found`);
  else {
    try {
      const parsed = JSON.parse(readFileSync(join(projectDir, indexes), 'utf8'));
      if (!Array.isArray(parsed.indexes)) errors.push(`${indexes} has no "indexes" array`);
    } catch (e) {
      errors.push(`${indexes} is not valid JSON: ${e.message}`);
    }
  }
  if (!functionsSource) errors.push('firebase.json declares no functions.source');
  else {
    const pkgPath = join(projectDir, functionsSource, 'package.json');
    if (!existsSync(pkgPath)) errors.push(`functions package.json not found at ${pkgPath}`);
    else {
      const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
      if (!pkg.main) errors.push('functions package.json has no "main" entry');
      else if (!existsSync(join(projectDir, functionsSource, pkg.main))) {
        errors.push(`functions entry ${pkg.main} not built — run \`npm run build\` in ${functionsSource}/ first`);
      }
    }
  }
  return errors;
}

/**
 * The gate decision. `deploy` is refused in this story (AD-49 / rulings B5:
 * DNI-490 owns the production deploy); anything but `dry-run` is an error.
 */
export function decide(mode) {
  if (mode === 'dry-run') {
    return { ok: true, message: `DRY-RUN — would run: ${DEPLOY_COMMAND} (production deploy is not enabled before the AD-49 cutover release, DNI-490)` };
  }
  if (mode === 'deploy') {
    return { ok: false, message: 'mode=deploy is refused: the production backend deploy is enabled only by the AD-49 cutover release (DNI-490). This gate is dry-run only.' };
  }
  return { ok: false, message: `unknown mode ${JSON.stringify(mode)} (expected dry-run)` };
}

function main(argv) {
  const modeIdx = argv.indexOf('--mode');
  const mode = modeIdx >= 0 ? argv[modeIdx + 1] : undefined;
  const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

  const decision = decide(mode);
  if (!decision.ok) {
    console.error(`::error::${decision.message}`);
    return 1;
  }
  const errors = [
    ...validateWorkflow(readFileSync(join(repoRoot, '.github/workflows/ci.yml'), 'utf8')),
    ...validateDeployTargets(join(repoRoot, 'learning_tracker')),
  ];
  if (errors.length) {
    for (const e of errors) console.error(`::error::${e}`);
    return 1;
  }
  console.log('Backend deploy gate: rules/indexes/functions deploy inputs validated; gate needs firestore-rules + functions.');
  console.log(decision.message);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
