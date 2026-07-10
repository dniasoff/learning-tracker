export const meta = {
  name: 'audit-fix-wave-engine',
  description: 'Autonomous delivery engine for one wave of the 2026-07-03 standards-audit fixes: cluster -> build (sonnet, worktree) -> adversarial review (opus) -> bounce -> serialized merge -> loop until dry -> reconcile -> closing gate (opus) -> dev fast-forward boundary.',
  whenToUse: 'Dispatched once per wave by the delivery orchestrator with args {wave, manifest, ...}. Never resume a killed run - relaunch fresh over the remainder.',
  phases: [
    { title: 'Build', detail: 'sonnet builders in isolated worktrees, red-first, never commit red' },
    { title: 'Review', detail: 'adversarial opus review re-runs gates, verifies every AC', model: 'opus' },
    { title: 'Fix', detail: 'sonnet bounce passes applying reviewer findings' },
    { title: 'Merge', detail: 'serialized merge lane: rebase, cheap gates, merge --no-ff, ledger, cleanup' },
    { title: 'Reconcile', detail: 'ledger residue reconciliation' },
    { title: 'Gate', detail: 'opus wave closing gate: full suite + ledger + 10% AC sampling', model: 'opus' },
    { title: 'Boundary', detail: 'dev fast-forward, pushes, worktree prune, Linear mirror' },
  ],
}

// ---------- args (defensive: may arrive stringified) ----------
const cfg = (typeof args === 'string') ? JSON.parse(args) : args
if (!cfg || typeof cfg.wave !== 'number' || !Array.isArray(cfg.manifest) || cfg.manifest.length === 0) {
  throw new Error('engine args invalid or empty: need {wave:number, manifest:[...]} - refusing to run on an empty work list')
}
const WAVE = cfg.wave
const EXCLUDE = new Set(cfg.excludeOverlapFiles || [])
const CUSTOM_LINT = !!cfg.customLintInGates
const FINAL_WAVE = !!cfg.finalWave
const PUSH_EVERY = cfg.pushEvery || 3
const CHUNK = cfg.chunkSize || 8
const LINEAR_TEAM = cfg.linearTeam || 'DNI'
const MAXP = cfg.maxParallel || 0
const PREBUILT = Array.isArray(cfg.preBuilt) ? cfg.preBuilt : []
const PREAPPROVED = {}
for (const pa of (Array.isArray(cfg.preApproved) ? cfg.preApproved : [])) { if (pa && pa.tipSha) PREAPPROVED[pa.tipSha] = pa }

const REPO = '/home/daniel/repos/learning-tracker'
const BRANCH = 'audit-fix/2026-07-03'
const AUDIT = 'docs/audits/standards-audit-2026-07-03'
const LEDGER = AUDIT + '/delivery/ledger.json'
const KILLLOG = AUDIT + '/delivery/kill-log-addendum.md'
const BASE = '4018a91c'
const SEV = { P0: 0, P1: 1, P2: 2, P3: 3 }

// ---------- in-memory state (ledger file is updated by the serialized merge lane) ----------
const F = {}
for (const m of cfg.manifest) F[m.id] = { m: m, state: 'todo', note: '' }
let mergedCount = 0
let mergeIndex = 0
let consecFail = 0
let quotaDead = false
const outcomes = { merged: [], refuted: [], blocked: [] }

// slot semaphore: at most MAXP agents in flight, slots hand over directly (always full while work remains)
let semActive = 0
const semWait = []
function semRelease() { const w = semWait.shift(); if (w) { w() } else { semActive-- } }
async function ga(prompt, opts, priority) {
  if (quotaDead) return null
  if (MAXP > 0) {
    if (semActive >= MAXP) { await new Promise(function (res) { if (priority) { semWait.unshift(res) } else { semWait.push(res) } }) } else { semActive++ }
    if (quotaDead) { semRelease(); return null }
  }
  let r = null
  try { r = await agent(prompt, opts) }
  catch (e) { r = null; log('agent threw (treated as failure, not fatal): ' + String(e && e.message || e).slice(0, 120)) }
  finally { if (MAXP > 0) semRelease() }
  if (r === null || r === undefined) {
    consecFail++
    if (consecFail >= 5 && !quotaDead) { quotaDead = true; log('GUARD tripped: 5 consecutive agent failures - no new launches; finishing bookkeeping') }
    return null
  }
  consecFail = 0
  return r
}

// ---------- serialized merge lane ----------
let mergeChain = Promise.resolve()
function serialized(fn) {
  const run = mergeChain.then(fn, fn)
  mergeChain = run.then(function () {}, function () {})
  return run
}

// ---------- clustering: union-find over evidence files ----------
function cluster(ids) {
  const parent = {}
  function find(x) { while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x] } return x }
  function union(a, b) { const ra = find(a), rb = find(b); if (ra !== rb) parent[ra] = rb }
  for (const id of ids) parent[id] = id
  const byFile = {}
  for (const id of ids) {
    for (const f of (F[id].m.files || [])) {
      if (EXCLUDE.has(f)) continue
      if (byFile[f]) union(id, byFile[f]); else byFile[f] = id
    }
  }
  const groups = {}
  for (const id of ids) { const r = find(id); (groups[r] = groups[r] || []).push(id) }
  const comps = Object.values(groups).map(function (g) {
    g.sort(function (a, b) { return (SEV[F[a].m.severity] - SEV[F[b].m.severity]) || (a < b ? -1 : 1) })
    const files = new Set()
    for (const id of g) for (const f of (F[id].m.files || [])) files.add(f)
    return { ids: g, files: Array.from(files), sev: SEV[F[g[0]].m.severity] }
  })
  comps.sort(function (a, b) { return (a.sev - b.sev) || (b.ids.length - a.ids.length) })
  return comps
}

// ---------- prompt builders (no backticks anywhere) ----------
const DOCTRINE = [
  'Doctrine (binding):',
  '- The register finding is canonical for WHAT; docs/coding-standards.md (rev 2026-07-02) is canonical for HOW. A fix that violates the standards it serves is wrong.',
  '- Red-first for behavioral findings: write the regression test FIRST, run it, capture the failing output, then fix, then show it pass. For hygiene/mechanical findings the AC-named checker (grep/lint/test) plays that role.',
  '- TQ-7 is law: never weaken or delete a test to go green. Assertion removals need a comment: weaken-ok: <reason>. Test-file deletions need the reason in the commit message.',
  '- Honesty: no fabricated test data standing in for behavior; no stub fixes that satisfy a grep without fixing the defect. If a finding is wrong or already fixed, outcome=refuted with evidence - never manufacture a change.',
  '- Scope discipline: fix ONLY your assigned findings. Adjacent defects you notice go in your notes as candidate follow-ups, never drive-by fixes.',
  '- NEVER COMMIT RED. Judge gates by exit codes.',
  '- Commits: conventional, one logical fix per commit, subject references the AUD id, body carries verification evidence (command + output tail), trailer line: Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>',
].join('\n')

const GATES = [
  'Gate commands (run from the right directory, judge by exit code):',
  '- cd learning_tracker && make audit',
  '- cd learning_tracker && flutter analyze   (zero issues required)',
  '- cd learning_tracker && dart format <your changed dirs/files>   (write mode is fine on YOUR changes)',
  '- cd learning_tracker && flutter test <targeted paths: your new/changed tests + tests of touched areas>',
  '- repo root: make arb-parity   (required whenever .arb files or user-facing strings changed)',
  '- If you changed codegen-adjacent files (@riverpod, @freezed, @JsonSerializable, *.g.dart neighbors): cd learning_tracker && dart run build_runner build --delete-conflicting-outputs, then git diff --exit-code on generated files (commit regenerated files with your change).',
  '- If your findings touch firestore.rules or learning_tracker/functions/: the firestore rules test suite (learning_tracker/functions/test/firestore_rules.test.mjs, runner per functions/package.json, needs the firebase emulator) is part of YOUR gate set. If the emulator cannot start, outcome=blocked with the exact command + error - never a silent skip.',
  (CUSTOM_LINT ? '- cd learning_tracker && dart run custom_lint   (repaired in Wave 0 - now a required gate)' : '- custom_lint is known-broken this wave (AUD-guardrails-03) and NOT in the gate set.'),
  'Memory discipline (HARD RULE): this machine has only 15GB RAM shared by several concurrent agents. Run gate commands strictly SEQUENTIALLY (never two flutter/dart processes at once), always pass --concurrency=2 to flutter test, and never run the full test suite when targeted paths suffice.',
  'Worktree environment note: fresh worktrees LACK gitignored local artifacts. Before judging any gate, set up: (1) copy learning_tracker/lib/firebase_options.dart from the main checkout at ' + REPO + '; (2) FAST PATH for generated code: copy every *.g.dart and *.freezed.dart under learning_tracker/lib and learning_tracker/test from the main checkout (same base commit, so they are current), then flutter pub get; run full build_runner ONLY if flutter analyze still reports missing generated symbols; (3) if tests need assets/db/content.db.gz, copy it from the main checkout or regenerate via dart run tool/prepare_asset.dart. These env gaps are NEVER defects, findings, or bounce reasons.',
].join('\n')

function builderPrompt(comp, cid, dispatchIds) {
  const lines = [
    'You are a BUILDER (sonnet) for the standards-audit delivery engine. Work item ' + cid + ' (wave ' + WAVE + '). You are inside an ISOLATED GIT WORKTREE of ' + REPO + ' - verify with pwd and git rev-parse --show-toplevel, and record your pwd as worktreePath.',
    'Worktree rules: do NOT create named branches, do NOT push, do NOT touch the main checkout. Commit on your current worktree HEAD (its temp branch is fine). Your commits are collected by SHA.',
    '',
    'Your findings (fix in this order; each has a JSON file with evidence, why, recommendation, and acceptance_criteria - Read every one fully before touching code):',
  ]
  for (const id of dispatchIds) {
    const m = F[id].m
    lines.push('- ' + id + ' [' + m.severity + ', ' + m.normArea + '] -> ' + m.jsonPath)
  }
  lines.push('')
  lines.push('Per finding: (1) re-verify the evidence against the code as it stands (register was verified at commit ' + BASE + ' and the tree has not drifted, but confirm); if the finding is wrong or already fixed, outcome=refuted with concrete evidence and NO code change. (2) red-first where behavioral. (3) implement the recommendation conforming to docs/coding-standards.md. (4) self-check every acceptance criterion. (5) run the gates, then commit (one logical fix per commit).')
  lines.push('')
  lines.push(DOCTRINE)
  lines.push('')
  lines.push(GATES)
  lines.push('')
  lines.push('If you are running low on context or the item is too large: STOP CLEANLY after your last green commit and mark the findings you did not reach as outcome=deferred (they will be re-dispatched). Never rush a finding to fake completion.')
  lines.push('Your final message is machine-consumed. Return exactly the structured fields: status (fixed = all dispatched findings terminal-good, partial = some deferred/blocked, refuted-all, blocked), tipSha (git rev-parse HEAD after your last commit; base HEAD if no commits), worktreePath (your pwd), perFinding (one entry per dispatched finding: outcome fixed|refuted|blocked|deferred + short note; refuted notes carry the evidence), testsAdded (paths), gateResults (short PASS/FAIL strings per gate, n/a where not applicable), notes. Self-assessment is NOT the gate - an independent reviewer re-runs everything.')
  return lines.join('\n')
}

function reviewerPrompt(cid, tipSha, dispatchIds, buildJson) {
  const lines = [
    'You are the ADVERSARIAL REVIEWER (opus) for work item ' + cid + ' (wave ' + WAVE + ') of the standards-audit delivery engine. The builder is sonnet; you are not the implementer. The builder green is a CLAIM, not a fact.',
    'You are in an isolated worktree of ' + REPO + '. Check out the work detached: git checkout --detach ' + tipSha + '  (allowed even though another worktree holds it). The integration branch ref is ' + BRANCH + '; compute the diff with: git diff $(git merge-base HEAD ' + BRANCH + ')..HEAD and read the commit messages (git log with patches).',
    '',
    'Findings under review (Read each JSON in full - the acceptance_criteria are the per-finding definition of done):',
  ]
  for (const id of dispatchIds) lines.push('- ' + id + ' -> ' + F[id].m.jsonPath)
  lines.push('')
  lines.push('BUILDER CLAIM (JSON): ' + buildJson)
  lines.push('')
  lines.push('Environment setup FIRST (never a bounce reason): fresh worktrees lack gitignored artifacts - copy learning_tracker/lib/firebase_options.dart from the main checkout at ' + REPO + ', regenerate assets/db/content.db.gz via dart run tool/prepare_asset.dart if tests need it, and run flutter pub get + dart run build_runner build --delete-conflicting-outputs for .g.dart/.freezed.dart files. Only judge the diff and gates AFTER env setup; an env gap in YOUR worktree is not a defect in the build under review. Memory discipline: 15GB RAM shared machine - run gates sequentially and pass --concurrency=2 to flutter test.')
  lines.push('Your job, in order:')
  lines.push('1. RE-RUN the gates yourself in this worktree - make audit, flutter analyze, the targeted tests (builder testsAdded + touched areas), make arb-parity if strings/.arb changed' + (CUSTOM_LINT ? ', dart run custom_lint' : '') + ', rules tests if firestore.rules/functions touched. Judge by exit codes.')
  lines.push('2. Verify EVERY acceptance criterion of every claimed-fixed finding INDIVIDUALLY, against the actual tree, with evidence (file:line or command output). An AC you cannot verify = bounce.')
  lines.push('3. Hunt fake-done: tests that assert the mock instead of behavior; fixes that satisfy the audit grep but not the defect; orphan/dead code introduced; missing red-first regression test where the finding is behavioral (commit body should show the red run).')
  lines.push('4. Hunt TQ-7 violations: weakened/deleted assertions or tests (diff test files for removed expects; deletions need weaken-ok tags or commit-message justification you CONCUR with).')
  lines.push('5. Hunt standards violations introduced by the fix itself - cite rule IDs from docs/coding-standards.md.')
  lines.push('6. Hunt scope creep: changes beyond the assigned findings (trivial same-line formatting excepted).')
  lines.push('7. Builder-refuted findings: check the refutation evidence; concur or bounce. refutedIds in your return = findings you CONFIRM are register-wrong/already-fixed (builder made no code change for them, or a provable no-op).')
  lines.push('Verdict rules: approve ONLY if gates are green by YOUR runs AND every AC of every fixed finding is verified AND no TQ-7/fake-done/scope findings. Otherwise bounce with precise, actionable findings (max 10, most severe first). Do not modify any code yourself.')
  lines.push('Return structured fields: verdict (approve|bounce), refutedIds, findings (bounce reasons; empty on approve), acVerified (one short string per verified AC: "<AUD-id> AC<n> OK: <evidence>"), gatesReRun (short PASS/FAIL strings), notes.')
  return lines.join('\n')
}

function fixerPrompt(cid, tipSha, findings) {
  const lines = [
    'You are a FIX-BOUNCE agent (sonnet) for work item ' + cid + ' (wave ' + WAVE + '). An adversarial reviewer bounced the build. You are in an isolated worktree of ' + REPO + '.',
    'Steps: git checkout --detach ' + tipSha + ' then apply ONLY the reviewer findings below - no other changes. Re-run the gates. Commit green (conventional message, evidence in body, trailer Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>). Do NOT create named branches or push. Record pwd as worktreePath and git rev-parse HEAD as tipSha.',
    '',
    'REVIEWER FINDINGS TO ADDRESS:',
  ]
  for (const f of findings) lines.push('- ' + f)
  lines.push('')
  lines.push(DOCTRINE)
  lines.push('')
  lines.push(GATES)
  lines.push('Return structured fields: tipSha, worktreePath, addressed (one line per finding: what you did), gateResults, notes. If a reviewer finding is wrong, say so in addressed with evidence instead of making a bad change.')
  return lines.join('\n')
}

function conflictFixerPrompt(cid, tipSha, mergeBase, conflictFiles) {
  return [
    'You are a REBASE-CONFLICT resolver (sonnet) for work item ' + cid + '. The merge lane failed to rebase ' + tipSha + ' onto current ' + BRANCH + '. You are in a fresh isolated worktree already based on current ' + BRANCH + '.',
    'Reapply the work: git log ' + mergeBase + '..' + tipSha + ' --reverse --format=%H gives the commits; cherry-pick each in order, resolving conflicts faithfully to BOTH the incoming fix intent and the current base (conflict files: ' + conflictFiles.join(', ') + '). Then re-run the gates (make audit, flutter analyze, targeted tests). Commit resolution state must be green.',
    'Do not create named branches or push. Return structured fields: tipSha (new HEAD), worktreePath, addressed, gateResults, notes.',
    DOCTRINE,
  ].join('\n')
}

function mergePrompt(mode, payloadJson) {
  return [
    'You are the SERIALIZED MERGE-LANE tooling agent (sonnet) for the standards-audit delivery engine. You operate the MAIN checkout at ' + REPO + ' (no worktree isolation). You are the ONLY writer to branch ' + BRANCH + ' and to the ledger right now.',
    'PAYLOAD (JSON): ' + payloadJson,
    '',
    'Invariant: when you finish - success or failure - the main checkout MUST be on ' + BRANCH + ' with no MODIFIED/STAGED tracked files and no in-progress rebase/merge. UNTRACKED files are TOLERATED (a concurrent TEA-audit session writes untracked outputs under docs/test-artifacts/ - never touch, delete, or commit them; just note them). Verify at start (branch + no tracked modifications + no rebase/merge in progress; on violation report failed with evidence and touch nothing) and verify again at the end.',
    (mode === 'merge' ? [
      'MODE merge - steps:',
      '1. git checkout --detach <payload.tipSha>; git rebase ' + BRANCH + '. On conflict: git rebase --abort; git checkout ' + BRANCH + '; return status=conflict-bounce with mergeBase (git merge-base <tipSha> ' + BRANCH + ') and the conflicting files.',
      '2. rebasedSha = git rev-parse HEAD. Post-rebase gate policy: ALWAYS run cd learning_tracker && make audit && flutter analyze. Then compute overlap: MB=$(git merge-base <payload.tipSha> ' + BRANCH + '); intersect the path sets of (git diff --name-only $MB <payload.tipSha>) and (git diff --name-only $MB ' + BRANCH + '). If the intersection is EMPTY (file-disjoint rebase: the adversarial reviewer already ran the tests on an equivalent tree, and the wave-closing full make ci is the integration gate), SKIP the test run and record gatePolicy=disjoint-skip in notes. If NON-EMPTY, also run flutter test --concurrency=2 on payload.testsToRun plus suites covering the overlapping files, and record gatePolicy=overlap-tested. Root make arb-parity if payload.touchedStrings. Any red: git checkout ' + BRANCH + '; return status=failed with the failing tail.',
      '3. git checkout ' + BRANCH + '; git merge --no-ff <rebasedSha> -m "fix(audit): <payload.cid> - <N> finding(s): <ids>" with trailer line Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>',
      '4. Ledger update (use jq or python3 on ' + LEDGER + '): for each payload.findingsMerged row set status=merged, commits=[the merged commit SHAs], reviewRounds, acVerified (from payload), notes. For each payload.findingsRefuted: status=skipped-refuted, notes=evidence, and append a dated entry to ' + KILLLOG + ' (create the file with a header if absent). For each payload.findingsBlocked: status=blocked, notes=reason. Validate the ledger still parses (jq) and row count is unchanged. Commit: "ledger(<cid>): <counts>" with the sonnet trailer.',
      '5. Worktree cleanup: for each path in payload.worktreesToRemove run git worktree remove --force <path> (tolerate already-gone). Then delete orphaned auto-created worktree branches: git worktree prune; for each branch matching git branch --list "worktree-*" NOT checked out in any remaining worktree (cross-check git worktree list --porcelain), verify patch-equivalence with git cherry ' + BRANCH + ' <branch> - if EVERY line starts with "-" (all patches already in ' + BRANCH + ') or the branch tip is an ancestor (git merge-base --is-ancestor), delete it with git branch -D <branch> and note it; if any "+" line remains, LEAVE the branch and report it in notes (unmerged work is never force-deleted).',
      '6. If payload.pushNow is true: git push origin ' + BRANCH + ' (report exit).',
    ].join('\n') : [
      'MODE ledger-only - steps (no code merge; the item produced no mergeable diff):',
      '1. Ledger update on ' + LEDGER + ' exactly as in merge mode step 4 (refuted -> skipped-refuted + kill-log addendum; blocked -> blocked with reason). Validate with jq; commit "ledger(<cid>): <counts>" with the sonnet trailer.',
      '2. Worktree cleanup per payload.worktreesToRemove (git worktree remove --force, tolerate already-gone), then the same orphaned worktree-* branch deletion protocol as merge mode step 5 (git worktree prune; patch-equivalence via git cherry ' + BRANCH + ' before -D; leave and report anything with unmerged patches).',
    ].join('\n')),
    'Return structured fields: status (merged|ledger-only|conflict-bounce|failed), mergeSha (empty if none), mergeBase (conflict-bounce only), conflictFiles, pushed, notes (include failing command tails on failed).',
  ].join('\n')
}

const BUILD_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['status', 'tipSha', 'worktreePath', 'perFinding', 'testsAdded', 'gateResults', 'notes'],
  properties: {
    status: { type: 'string', enum: ['fixed', 'partial', 'refuted-all', 'blocked'] },
    tipSha: { type: 'string', maxLength: 64 },
    worktreePath: { type: 'string', maxLength: 300 },
    perFinding: { type: 'array', maxItems: 10, items: { type: 'object', additionalProperties: false, required: ['id', 'outcome', 'note'], properties: { id: { type: 'string', maxLength: 48 }, outcome: { type: 'string', enum: ['fixed', 'refuted', 'blocked', 'deferred'] }, note: { type: 'string', maxLength: 300 } } } },
    testsAdded: { type: 'array', maxItems: 15, items: { type: 'string', maxLength: 200 } },
    gateResults: { type: 'object', additionalProperties: { type: 'string', maxLength: 120 } },
    notes: { type: 'string', maxLength: 500 },
  },
}

const REVIEW_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['verdict', 'refutedIds', 'findings', 'acVerified', 'gatesReRun', 'notes'],
  properties: {
    verdict: { type: 'string', enum: ['approve', 'bounce'] },
    refutedIds: { type: 'array', maxItems: 10, items: { type: 'string', maxLength: 48 } },
    findings: { type: 'array', maxItems: 10, items: { type: 'string', maxLength: 400 } },
    acVerified: { type: 'array', maxItems: 40, items: { type: 'string', maxLength: 170 } },
    gatesReRun: { type: 'object', additionalProperties: { type: 'string', maxLength: 120 } },
    notes: { type: 'string', maxLength: 400 },
  },
}

const FIX_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['tipSha', 'worktreePath', 'addressed', 'gateResults', 'notes'],
  properties: {
    tipSha: { type: 'string', maxLength: 64 },
    worktreePath: { type: 'string', maxLength: 300 },
    addressed: { type: 'array', maxItems: 10, items: { type: 'string', maxLength: 250 } },
    gateResults: { type: 'object', additionalProperties: { type: 'string', maxLength: 120 } },
    notes: { type: 'string', maxLength: 400 },
  },
}

const MERGE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['status', 'mergeSha', 'mergeBase', 'conflictFiles', 'pushed', 'notes'],
  properties: {
    status: { type: 'string', enum: ['merged', 'ledger-only', 'conflict-bounce', 'failed'] },
    mergeSha: { type: 'string', maxLength: 64 },
    mergeBase: { type: 'string', maxLength: 64 },
    conflictFiles: { type: 'array', maxItems: 10, items: { type: 'string', maxLength: 200 } },
    pushed: { type: 'boolean' },
    notes: { type: 'string', maxLength: 400 },
  },
}

// ---------- per-component pipeline ----------
async function runComponent(comp, roundNum, compIdx, preB) {
  const cid = 'w' + WAVE + 'r' + roundNum + 'c' + compIdx
  const dispatchIds = preB ? comp.ids.slice() : comp.ids.slice(0, CHUNK)
  for (const id of dispatchIds) F[id].state = 'building'
  const worktrees = []

  const b = preB ? preB.build : await ga(builderPrompt(comp, cid, dispatchIds), { label: 'build:' + cid, phase: 'Build', model: 'sonnet', isolation: 'worktree', schema: BUILD_SCHEMA })
  if (preB && b) log(cid + ': harvested pre-built ' + (b.tipSha || '').slice(0, 10) + ' for ' + dispatchIds.join(','))
  if (!b) { for (const id of dispatchIds) F[id].state = 'todo'; return }
  if (b.worktreePath) worktrees.push(b.worktreePath)
  const claims = {}
  for (const pf of b.perFinding) claims[pf.id] = pf
  for (const id of dispatchIds) if (!claims[id]) claims[id] = { id: id, outcome: 'deferred', note: 'builder did not report this finding' }

  const fixedIds = dispatchIds.filter(function (id) { return claims[id].outcome === 'fixed' })
  let refuted = dispatchIds.filter(function (id) { return claims[id].outcome === 'refuted' }).map(function (id) { return { id: id, note: claims[id].note } })
  let blocked = dispatchIds.filter(function (id) { return claims[id].outcome === 'blocked' }).map(function (id) { return { id: id, note: claims[id].note } })
  for (const id of dispatchIds) if (claims[id].outcome === 'deferred') F[id].state = 'todo'

  let tip = b.tipSha
  let reviewRounds = 0
  let acVerified = []
  let approved = false

  if (fixedIds.length > 0 && PREAPPROVED[tip]) {
    const pa = PREAPPROVED[tip]
    approved = true
    acVerified = Array.isArray(pa.acVerified) ? pa.acVerified : []
    reviewRounds = 1
    log(cid + ': review HARVESTED from prior run for tip ' + tip.slice(0, 10) + ' (' + (pa.reviewedBy || 'opus') + ', approve) - straight to merge')
  } else if (fixedIds.length > 0) {
    while (true) {
      const rev = await ga(reviewerPrompt(cid, tip, dispatchIds, JSON.stringify({ status: b.status, perFinding: b.perFinding, testsAdded: b.testsAdded, gateResults: b.gateResults })), { label: 'review:' + cid + '-r' + (reviewRounds + 1), phase: 'Review', model: 'opus', isolation: 'worktree', schema: REVIEW_SCHEMA })
      if (!rev) { blocked = blocked.concat(fixedIds.filter(function (id) { return !refuted.some(function (r) { return r.id === id }) }).map(function (id) { return { id: id, note: 'review agent lost (quota)' } })); break }
      reviewRounds++
      for (const rid of rev.refutedIds) {
        if (fixedIds.includes(rid) || dispatchIds.includes(rid)) {
          if (!refuted.some(function (r) { return r.id === rid })) refuted.push({ id: rid, note: 'reviewer-confirmed refutation: ' + (rev.notes || '').slice(0, 150) })
        }
      }
      if (rev.verdict === 'approve') { acVerified = rev.acVerified; approved = true; break }
      if (reviewRounds >= 3) {
        for (const id of fixedIds) if (!refuted.some(function (r) { return r.id === id })) blocked.push({ id: id, note: 'bounce cap (3 review rounds) exceeded; last findings: ' + rev.findings.slice(0, 2).join(' | ').slice(0, 180) })
        break
      }
      const fx = await ga(fixerPrompt(cid, tip, rev.findings), { label: 'fix:' + cid + '-r' + reviewRounds, phase: 'Fix', model: 'sonnet', isolation: 'worktree', schema: FIX_SCHEMA })
      if (!fx) { for (const id of fixedIds) if (!refuted.some(function (r) { return r.id === id })) blocked.push({ id: id, note: 'fixer agent lost (quota) after bounce' }); break }
      tip = fx.tipSha
      if (fx.worktreePath) worktrees.push(fx.worktreePath)
    }
  }

  const mergeIds = approved ? fixedIds.filter(function (id) { return !refuted.some(function (r) { return r.id === id }) }) : []
  const testsToRun = (b.testsAdded || []).slice(0, 15)
  const touchedStrings = Object.keys(b.gateResults || {}).some(function (k) { return k.toLowerCase().indexOf('arb') >= 0 && (b.gateResults[k] || '').indexOf('PASS') >= 0 })

  await serialized(async function () {
    const mode = mergeIds.length > 0 ? 'merge' : 'ledger-only'
    if (mode === 'merge') mergeIndex++
    const myIndex = mergeIndex
    let payload = {
      cid: cid, tipSha: tip,
      findingsMerged: mergeIds.map(function (id) { return { id: id, reviewRounds: reviewRounds, acVerified: acVerified.filter(function (s) { return s.indexOf(id) >= 0 }), note: claims[id].note } }),
      findingsRefuted: refuted, findingsBlocked: blocked,
      worktreesToRemove: worktrees, testsToRun: testsToRun, touchedStrings: touchedStrings,
      pushNow: mode === 'merge' && (myIndex % PUSH_EVERY === 0),
    }
    if (mergeIds.length === 0 && refuted.length === 0 && blocked.length === 0) {
      // nothing terminal this pass (all deferred / quota) - still remove worktrees
      payload.findingsMerged = []; payload.findingsRefuted = []; payload.findingsBlocked = []
    }
    let mg = await ga(mergePrompt(mode, JSON.stringify(payload)), { label: 'merge:' + cid, phase: 'Merge', model: 'sonnet', schema: MERGE_SCHEMA }, true)
    if (mg && mg.status === 'conflict-bounce' && mode === 'merge') {
      const cf = await ga(conflictFixerPrompt(cid, tip, mg.mergeBase, mg.conflictFiles), { label: 'conflict-fix:' + cid, phase: 'Fix', model: 'sonnet', isolation: 'worktree', schema: FIX_SCHEMA }, true)
      if (cf) {
        payload.tipSha = cf.tipSha
        if (cf.worktreePath) payload.worktreesToRemove = payload.worktreesToRemove.concat([cf.worktreePath])
        mg = await ga(mergePrompt('merge', JSON.stringify(payload)), { label: 'merge:' + cid + '-retry', phase: 'Merge', model: 'sonnet', schema: MERGE_SCHEMA }, true)
      }
    }
    if (mg && (mg.status === 'merged' || mg.status === 'ledger-only')) {
      for (const id of mergeIds) { F[id].state = 'merged'; outcomes.merged.push(id); mergedCount++ }
      for (const r of refuted) { F[r.id].state = 'refuted'; outcomes.refuted.push(r.id) }
      for (const bl of blocked) { F[bl.id].state = 'blocked'; F[bl.id].note = bl.note; outcomes.blocked.push(bl.id) }
    } else {
      const why = mg ? ('merge-lane ' + mg.status + ': ' + mg.notes) : 'merge-lane agent lost (quota)'
      for (const id of mergeIds) { F[id].state = 'blocked'; F[id].note = why; outcomes.blocked.push(id) }
      for (const r of refuted) { F[r.id].state = 'refuted'; outcomes.refuted.push(r.id) }
      for (const bl of blocked) { F[bl.id].state = 'blocked'; F[bl.id].note = bl.note; outcomes.blocked.push(bl.id) }
      log('MERGE PROBLEM ' + cid + ': ' + why.slice(0, 200))
    }
  })
}

// ---------- harvested pre-built components: straight to review->merge, concurrent with the round loop ----------
let prebuiltPromise = Promise.resolve()
if (PREBUILT.length) {
  const valid = PREBUILT.filter(function (pb) { return Array.isArray(pb.ids) && pb.ids.length && pb.ids.every(function (id) { return F[id] }) && pb.build && pb.build.tipSha })
  if (valid.length !== PREBUILT.length) log('WARNING: ' + (PREBUILT.length - valid.length) + ' preBuilt entries invalid/unknown ids - dropped (their findings stay todo)')
  log('Processing ' + valid.length + ' harvested pre-built components (skip build; review -> merge)')
  for (const pb of valid) for (const id of pb.ids) F[id].state = 'building'
  prebuiltPromise = parallel(valid.map(function (pb, i) { return function () {
    return runComponent({ ids: pb.ids.slice(), files: [], sev: 0 }, 0, i + 1, pb).catch(function (e) {
      log('prebuilt c' + (i + 1) + ' crashed (' + String(e).slice(0, 120) + ') - re-queueing its findings')
      for (const id of pb.ids) if (F[id].state === 'building') F[id].state = 'todo'
    })
  } }))
}

// ---------- round loop until dry ----------
let roundNum = 0
let dryRounds = 0
while (!quotaDead) {
  const remaining = Object.keys(F).filter(function (id) { return F[id].state === 'todo' })
  if (remaining.length === 0) {
    await prebuiltPromise
    if (Object.keys(F).filter(function (id) { return F[id].state === 'todo' }).length === 0) break
    continue
  }
  roundNum++
  const comps = cluster(remaining)
  log('Wave ' + WAVE + ' round ' + roundNum + ': ' + remaining.length + ' findings across ' + comps.length + ' file-disjoint components (P0-first)')
  const beforeMerged = mergedCount
  const beforeTerminal = outcomes.merged.length + outcomes.refuted.length + outcomes.blocked.length
  await parallel(comps.map(function (c, i) { return function () {
    return runComponent(c, roundNum, i + 1).catch(function (e) {
      log('component r' + roundNum + 'c' + (i + 1) + ' crashed (' + String(e).slice(0, 140) + ') - re-queueing its unfinished findings')
      for (const id of c.ids) if (F[id].state === 'building') F[id].state = 'todo'
    })
  } }))
  const progressed = (mergedCount > beforeMerged) || ((outcomes.merged.length + outcomes.refuted.length + outcomes.blocked.length) > beforeTerminal)
  if (!progressed) { dryRounds++; if (dryRounds >= 2) { log('NO-PROGRESS CAP: 2 rounds without any terminal outcome - stopping the loop, residue goes to reconcile') ; break } } else dryRounds = 0
}
await prebuiltPromise
await serialized(async function () { return null })

// ---------- reconcile residue ----------
const residue = Object.keys(F).filter(function (id) { return F[id].state === 'todo' || F[id].state === 'building' })
const residueReason = quotaDead ? 'quota guard tripped mid-wave' : 'no-progress cap / loop end'
const RECON_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['status', 'merged', 'refuted', 'blocked', 'notes'],
  properties: { status: { type: 'string', enum: ['green', 'red'] }, merged: { type: 'integer' }, refuted: { type: 'integer' }, blocked: { type: 'integer' }, notes: { type: 'string', maxLength: 400 } },
}
const recon = await ga([
  'You are the wave-' + WAVE + ' ledger reconciliation agent (sonnet) for the standards-audit delivery engine, operating the main checkout at ' + REPO + ' on branch ' + BRANCH + ' (verify branch first; no modified tracked files except the ledger itself; untracked files from the concurrent TEA session are tolerated - never touch them).',
  'Engine outcome (in-memory truth): merged=' + JSON.stringify(outcomes.merged) + ' refuted=' + JSON.stringify(outcomes.refuted) + ' blocked=' + JSON.stringify(outcomes.blocked) + ' unprocessed=' + JSON.stringify(residue) + ' (unprocessed reason: ' + residueReason + ').',
  'Steps: 1) Read ' + LEDGER + '; every wave-' + WAVE + ' row must be in a terminal state matching the engine outcome. Rows the merge lane already updated should agree - flag any mismatch. 2) Unprocessed ids: set status=blocked, notes="not attempted: ' + residueReason + '". 3) Verify kill-log addendum entries exist for every skipped-refuted row (add missing ones). 4) jq-validate, commit "ledger(wave-' + WAVE + '): reconcile - <counts>" with trailer Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>, and report the final counts for wave-' + WAVE + ' rows.',
  'Return: status (green if ledger consistent), merged, refuted, blocked (final wave-' + WAVE + ' counts from the LEDGER, not from memory), notes.',
].join('\n'), { label: 'reconcile:wave-' + WAVE, phase: 'Reconcile', model: 'sonnet', schema: RECON_SCHEMA }, true)

if (quotaDead) {
  return { wave: WAVE, quotaDead: true, rounds: roundNum, outcomes: outcomes, unprocessed: residue, recon: recon, gate: null, boundary: null, note: 'Quota guard tripped - relaunch a FRESH engine over the remainder (never resumeFromRunId).' }
}

// ---------- closing gate (opus) ----------
const GATE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['verdict', 'reasons', 'gateResults', 'sampledIds', 'notes'],
  properties: {
    verdict: { type: 'string', enum: ['certify', 'fail'] },
    reasons: { type: 'array', maxItems: 8, items: { type: 'string', maxLength: 300 } },
    gateResults: { type: 'object', additionalProperties: { type: 'string', maxLength: 120 } },
    sampledIds: { type: 'array', maxItems: 12, items: { type: 'string', maxLength: 48 } },
    notes: { type: 'string', maxLength: 500 },
  },
}
function gatePrompt(attempt) {
  return [
    'You are the WAVE-' + WAVE + ' CLOSING GATE (opus) for the standards-audit delivery engine' + (attempt > 1 ? ' - RE-CERTIFICATION attempt ' + attempt + ' after repairs' : '') + '. Wave ' + WAVE + ' claims done. You certify it or fail it; a wrong pass poisons everything after it. Operate the main checkout at ' + REPO + ' on ' + BRANCH + ' (verify branch; no modified tracked files; untracked files from the concurrent TEA session under docs/test-artifacts/ are tolerated, not residue - never touch them).',
    'Independently, judging only by exit codes and file evidence:',
    '1. Full gate suite: cd learning_tracker && make audit; flutter analyze; make ci (the learning_tracker ci target ONLY - the root Makefile ci runs a write-mode formatter and is BANNED); root make arb-parity' + (CUSTOM_LINT ? '; cd learning_tracker && dart run custom_lint' : ' (custom_lint still known-broken this wave - not in the set)') + '. If the wave touched codegen-adjacent files (check git log for .g.dart or build_runner mentions since the wave started): dart run build_runner build --delete-conflicting-outputs then git diff --exit-code on generated files.',
    '2. Ledger reconcile: every wave-' + WAVE + ' row in ' + LEDGER + ' must be merged, skipped-refuted, or GENUINELY-blocked. A blocked row is ACCEPTABLE only if its notes describe a real external blocker (missing infra/credential/emulator, a product decision beyond the AC, or a register-vs-reality contradiction) WITH an escalation. A blocked row whose notes contain "not attempted", "no-progress", "loop end", "quota", "merge lane", or any wording meaning the engine simply did not finish the work = FAIL (that work is deliverable and must be delivered, never swept under blocked). Any todo/building row = fail. Report each fail-worthy blocked id in reasons.',
    '3. Sample re-verification: sort merged wave-' + WAVE + ' ids, take every 10th (minimum 3): for each, re-verify its acceptance_criteria against the ACTUAL tree (read the finding JSON under ' + AUDIT + '/delivery/findings/). A merged finding with an unmet AC is fake-done = fail.',
    '4. Residue check: git worktree list shows only the main checkout (report strays); git branch --list shows no unexpected fix/salvage branches.',
    '5. TQ-7 spot check: git diff ' + BASE + '..HEAD -- learning_tracker/test | grep for removed expect( lines; deletions need weaken-ok tags or justified commit messages.',
    'Return: verdict certify|fail, reasons (empty on certify; precise and actionable on fail), gateResults (per-gate PASS/FAIL strings), sampledIds, notes.',
  ].join('\n')
}
let gate = await ga(gatePrompt(1), { label: 'gate:wave-' + WAVE, phase: 'Gate', model: 'opus', effort: 'high', schema: GATE_SCHEMA }, true)
if (gate && gate.verdict === 'fail') {
  log('Wave ' + WAVE + ' gate FAILED: ' + gate.reasons.join(' | ').slice(0, 300) + ' - dispatching one repair cycle')
  const repair = await ga([
    'You are the wave-' + WAVE + ' GATE-REPAIR agent (sonnet), main checkout ' + REPO + ' on ' + BRANCH + '. The closing gate failed with these reasons:',
    gate.reasons.map(function (r) { return '- ' + r }).join('\n'),
    'Fix exactly these problems. TQ-7 is law: NEVER weaken or delete a test to clear a gate - if a reason can only be cleared by weakening a test, do not do it; explain in notes instead. Mechanical fixes (ledger corrections, formatting, missed regeneration, stray worktree/branch cleanup) are yours; behavioral regressions get a proper fix with a regression test. Run the relevant gates after each fix; commit green with evidence in the body and trailer Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>.',
    'Return: status green/red, merged=0 refuted=0 blocked=0 (unused), notes describing what you fixed or could not fix.',
  ].join('\n'), { label: 'gate-repair:wave-' + WAVE, phase: 'Gate', model: 'sonnet', schema: RECON_SCHEMA }, true)
  if (repair) {
    gate = await ga(gatePrompt(2), { label: 'gate:wave-' + WAVE + '-recheck', phase: 'Gate', model: 'opus', effort: 'high', schema: GATE_SCHEMA }, true)
  }
}
if (!gate || gate.verdict !== 'certify') {
  return { wave: WAVE, quotaDead: false, rounds: roundNum, outcomes: outcomes, unprocessed: residue, recon: recon, gate: gate, boundary: null, note: 'Wave gate did not certify - orchestrator escalation required before dev moves.' }
}

// ---------- boundary: dev fast-forward, pushes, cleanup, Linear mirror ----------
const BOUND_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['status', 'devSha', 'pushedDev', 'branchDeleted', 'worktrees', 'linear', 'diffstat', 'notes'],
  properties: {
    status: { type: 'string', enum: ['green', 'red'] },
    devSha: { type: 'string', maxLength: 64 },
    pushedDev: { type: 'boolean' },
    branchDeleted: { type: 'boolean' },
    worktrees: { type: 'string', maxLength: 200 },
    linear: { type: 'string', maxLength: 300 },
    diffstat: { type: 'string', maxLength: 200 },
    notes: { type: 'string', maxLength: 400 },
  },
}
const blockedDetail = outcomes.blocked.map(function (id) { return id + ': ' + (F[id].note || 'see ledger') }).slice(0, 30)
const boundary = await ga([
  'You are the WAVE-' + WAVE + ' BOUNDARY agent (sonnet) for the standards-audit delivery engine. The closing gate CERTIFIED the wave. Main checkout ' + REPO + ' currently on ' + BRANCH + ' (verify branch; untracked TEA-session files under docs/test-artifacts/ are tolerated - never touch them; abort only on modified tracked files).',
  'Git steps (judge by exit codes):',
  '1. git checkout dev; git merge --ff-only ' + BRANCH + '  (dev must fast-forward; if it cannot, STOP: return red with evidence, and git checkout ' + (FINAL_WAVE ? 'dev' : BRANCH) + ' before returning).',
  '2. git push origin dev; git push origin ' + BRANCH + '.',
  (FINAL_WAVE
    ? '3. FINAL WAVE cleanup: stay on dev; git branch -d ' + BRANCH + ' (merge-checked -d, never -D); git push origin --delete ' + BRANCH + '; verify git branch --list shows no audit-fix/fix/salvage branches; end state = main checkout on dev, clean.'
    : '3. git checkout ' + BRANCH + ' (the engine continues next wave from the work branch - this is REQUIRED; end state = main checkout on ' + BRANCH + ', clean).'),
  '4. git worktree prune; git worktree list - only the main checkout should remain; force-remove any stray engine worktrees (paths under a workflow/worktree temp root) and report them.',
  '5. diffstat: last line of git diff --stat ' + BASE + '..' + (FINAL_WAVE ? 'dev' : BRANCH) + '.',
  'Linear mirror (PO-enabled; NEVER let it block - on any Linear failure, note it and continue): use ToolSearch to load mcp__linear__list_teams and mcp__linear__save_issue. Find team ' + LINEAR_TEAM + '. Create ONE summary issue titled "Standards-audit delivery - Wave ' + WAVE + ' complete (2026-07-03)" with: merged=' + outcomes.merged.length + ' refuted=' + outcomes.refuted.length + ' blocked=' + outcomes.blocked.length + ', the gate verdict, the diffstat, and the merged finding ids. Then one issue per blocked finding (title "AUD blocked: <id>", description = reason) from this list: ' + JSON.stringify(blockedDetail) + '.',
  'Return: status, devSha (dev HEAD after ff), pushedDev, branchDeleted (' + (FINAL_WAVE ? 'true expected' : 'false expected') + '), worktrees (one-line state), linear (what you created or why it failed), diffstat, notes.',
].join('\n'), { label: 'boundary:wave-' + WAVE, phase: 'Boundary', model: 'sonnet', schema: BOUND_SCHEMA }, true)

return { wave: WAVE, quotaDead: false, rounds: roundNum, outcomes: outcomes, unprocessed: residue, recon: recon, gate: gate, boundary: boundary }
