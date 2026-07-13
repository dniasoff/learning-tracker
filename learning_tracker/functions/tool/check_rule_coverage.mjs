#!/usr/bin/env node
// TQ-9 — fail the job on any never-evaluated firestore.rules expression.
//
// Usage (run from learning_tracker/, while the Firestore emulator started by
// `firebase emulators:exec` for the demo-rules project is still up — see
// `make test-rules`, which chains this after the test run in the same
// emulators:exec shell):
//
//   node functions/tool/check_rule_coverage.mjs
//
// Fetches the emulator's rule-coverage report
// (http://127.0.0.1:8080/emulator/v1/projects/demo-rules:ruleCoverage.html —
// the same HTML the Firebase docs point developers at for manual coverage
// review: https://firebase.google.com/docs/rules/unit-tests#eval_coverage)
// and cross-references EVERY `allow <op>: if <condition>` line in
// firestore.rules against the set of source lines the emulator recorded an
// evaluation for.
//
// The report's `data.report` array contains an entry for every statically-
// known expression position in the rules file, REGARDLESS of whether it was
// ever reached — an unreached expression still gets an entry, but with
// `values: []` (this is exactly what the emulator's own coverage-HTML
// tooltip renders as "Expression never evaluated"; see `buildValueString`
// in the fetched report's inline script). So a line counts as covered only
// if some entry at that line has a NON-EMPTY `values` array; this check
// verified against a deliberately-unreachable scratch rule during
// development (a whole `match` block no test ever addresses) — its `allow`
// line's only report entries had `values: []` and were correctly flagged.
//
// This is a real, mechanically-checkable proxy for "this rule branch was
// never exercised by any test" — exactly the dead/unreachable-branch risk
// TQ-9 exists to catch (SR-5's revoked-access branch was undetectably dead
// until AUD-docs-02 added a test for it; this check makes a future
// regression of that kind fail CI instead of silently accumulating). Known
// limitation: coverage is at LINE granularity, so a short-circuited operand
// on the same line as an already-covered operand (e.g. the right side of an
// `||` whose left side is always true in every test) will not be flagged —
// true sub-expression branch coverage would need a rules-language parser,
// out of scope here.

import { readFileSync } from 'node:fs';

const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const PROJECT_ID = process.argv[2] ?? 'demo-rules';
const RULES_PATH = process.argv[3] ?? 'firestore.rules';

async function fetchCoverageHtml() {
  const url = `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}:ruleCoverage.html`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(
      `Failed to fetch rule coverage report from ${url}: HTTP ${res.status}`,
    );
  }
  return res.text();
}

// Extracts the `const data = {...}` object literal embedded in the coverage
// HTML and parses it as JSON (the emulator emits it as strict JSON — double
// -quoted keys/strings, no trailing commas — so JSON.parse works directly).
function parseCoverageData(html) {
  const marker = 'const data = ';
  const start = html.indexOf(marker);
  if (start === -1) {
    throw new Error("Coverage HTML did not contain 'const data = ' — format may have changed.");
  }
  const objStart = start + marker.length;
  const end = html.indexOf('\n\nconst REPORT_LIMIT_SIZE', objStart);
  if (end === -1) {
    throw new Error('Could not find end of the coverage data object literal.');
  }
  const jsonSlice = html.slice(objStart, end).trim().replace(/;$/, '');
  return JSON.parse(jsonSlice);
}

// Recursively walks the report tree (top-level entries and their nested
// `children`) and returns the set of lines that had at least one entry with
// a NON-EMPTY `values` array. The Firestore emulator emits a report entry
// for every statically-known expression position regardless of whether it
// was ever reached — an unreached expression still gets an entry, but with
// `values: []` (this is exactly what the emulator's own coverage-HTML
// tooltip renders as "Expression never evaluated", see buildValueString in
// the fetched report). So a line is only "covered" if some entry at that
// line actually recorded an evaluation outcome; a line whose only entries
// have `values: []` is NOT covered, even though the position is present in
// the report.
function collectCoveredLines(report) {
  const covered = new Set();
  const walk = (nodes) => {
    for (const node of nodes ?? []) {
      const line = node.sourcePosition?.line;
      if (line != null && (node.values?.length ?? 0) > 0) covered.add(line);
      if (node.children?.length) walk(node.children);
    }
  };
  walk(report);
  return covered;
}

// Finds every `allow <op>[, <op>...]: if <condition>` line in the rules
// source. Bare `allow ...: if false;` / `if true;` lines are excluded — a
// constant-condition rule has no meaningful branch coverage to report.
function findAllowConditionLines(rulesSource) {
  const lines = rulesSource.split('\n');
  const results = [];
  lines.forEach((text, idx) => {
    const trimmed = text.trim();
    const match = trimmed.match(/^allow\s+[\w,\s]+:\s*if\s+(.+);\s*$/);
    if (!match) return;
    const condition = match[1].trim();
    if (condition === 'true' || condition === 'false') return;
    results.push({ line: idx + 1, text: trimmed });
  });
  return results;
}

async function main() {
  const html = await fetchCoverageHtml();
  const data = parseCoverageData(html);
  const coveredLines = collectCoveredLines(data.report ?? []);
  const rulesSource = readFileSync(RULES_PATH, 'utf8');
  const allowLines = findAllowConditionLines(rulesSource);

  const uncovered = allowLines.filter((entry) => !coveredLines.has(entry.line));

  if (uncovered.length > 0) {
    console.error(
      `TQ-9: ${uncovered.length} never-evaluated rule expression(s) in ${RULES_PATH}:`,
    );
    for (const entry of uncovered) {
      console.error(`  line ${entry.line}: ${entry.text}`);
    }
    console.error(
      '\nEvery `allow ...: if <condition>` branch must be exercised by at least one ' +
        'test in functions/test/firestore_rules.test.mjs. Add a test that reaches the ' +
        'branch above, or remove the dead rule.',
    );
    process.exitCode = 1;
    return;
  }

  console.log(
    `TQ-9: rule coverage OK — all ${allowLines.length} conditional allow rule(s) in ` +
      `${RULES_PATH} were evaluated at least once.`,
  );
}

main().catch((err) => {
  console.error('TQ-9 rule-coverage check failed:', err.message);
  process.exitCode = 1;
});
