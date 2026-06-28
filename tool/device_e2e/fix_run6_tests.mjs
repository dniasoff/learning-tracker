export const meta = {
  name: 'fix-run6-stale-tests',
  description: 'Green the 12 tests broken by run-6 fixes — verify each is an intended behavior change (update test) vs a real regression (fix prod + flag)',
  phases: [{ title: 'FixTests', detail: 'parallel agents per failing test file/cluster' }],
}

const REPO = '/home/daniel/repos/learning-tracker';

const COMMON = [
  `## Context: run-6 fixes changed behavior intentionally; some tests assert old behavior.`,
  `Intended run-6 changes (match tests to these — do NOT revert prod unless a genuine regression):`,
  `- Reward Configuration: an inline rewards summary/list (_InlineRewardsSection) now shows existing rewards ON the primary screen (was only in the overflow "Manage Rewards" sheet). The Manage-Rewards sheet + edit/delete/toggle STILL EXIST and must still work — but tests that open the sheet to find a reward may now find it inline, or the widget tree/finders changed. Also: duplicate-named reward save now has a validation guard. And the reward created/updated body copy changed (removed "under Achievements" claim).`,
  `- ContentSearch: search now matches an item's OWN LEAF segment name only (not the full ancestor path), so ancestor path words no longer flood all descendants. A test asserting "matches by English display name" using a full-path/ancestor word may now (correctly) NOT match — verify the test's intent: if it asserted the OLD flooding behavior, update it to the new leaf-only semantics; if it tests a legit own-name match that now breaks, that's a REGRESSION — fix prod.`,
  `- Search hint: searchFieldHint now wraps the curriculum-name placeholder in Unicode LTR-isolate marks U+2066(\\u2066)…U+2069(\\u2069). A test asserting the exact hint string ("חיפוש …") must account for the isolate chars (use contains / strip the isolates, or assert the visible substring).`,
  `- Tutoring accept/decline: raw Firebase gRPC error codes (e.g. "UNAVAILABLE") are now mapped to a FRIENDLY localized message instead of shown raw. Tests asserting the raw failure message is rendered should assert the friendly message now. (Verify a non-gRPC/explicit failure message still surfaces if intended.)`,
  ``,
  `## Rules`,
  `- Work in ${REPO}. Edit ONLY your assigned file(s). Prefer updating the TEST to the intended behavior; touch prod ONLY for a genuine regression (and flag it). Do NOT git commit / reset / checkout.`,
  `- Toolchain (from learning_tracker/): \`export PATH="/home/daniel/flutter/bin:$PATH"; mkdir -p ~/.local/lib/sqliteshim; ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0.8.6 ~/.local/lib/sqliteshim/libsqlite3.so; export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"\`.`,
  `- VERIFY: \`flutter test <your file(s)>\` until All tests passed. Run \`dart analyze\` on anything you edit.`,
].join('\n');

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['file', 'green', 'changedProd', 'summary'],
  properties: {
    file: { type: 'string' }, green: { type: 'boolean' }, changedProd: { type: 'boolean' },
    filesChanged: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' }, regressionFound: { type: 'string' },
  },
};

const FILES = [
  { f: 'features/gamification/presentation/screens/reward_configuration_screen_l1_test.dart', why: '4 tests (confirm-delete cancel/confirm → deleteMilestone; edit reward icon selected; manage sheet delete → Delete Reward dialog). Reward screen now has an inline rewards section; finders/structure changed. Verify edit/delete/toggle STILL work, then fix the finders.' },
  { f: 'e2e/journeys/gamification_p1_test.dart', why: 'E2E-605/606/607/608 (edit via Manage Rewards sheet; delete; toggle enabled/disabled; tutor restricted controls). The inline rewards section changed the tree. Verify reward management still works; update finders to reach edit/delete/toggle (inline or via sheet).' },
  { f: 'features/content_browsing/data/repositories/content_repository_impl_logic_test.dart', why: '"matches by English display name" — search now matches the item OWN LEAF name, not full ancestor path. Verify the test intent: update to leaf-only semantics if it asserted ancestor-path/flooding matching; if it tests a legit own-name match that broke, fix prod (regression).' },
  { f: 'features/content_browsing/presentation/screens/content_search_screen_test.dart', why: 'R4-4 "Hebrew search hint shows חיפוש not Search" — searchFieldHint now wraps the placeholder in U+2066…U+2069 isolates, so the exact string changed. Update the assertion to match (contains the visible Hebrew, strip isolates).' },
  { f: 'features/tutoring/accept_invite_screen_l1_test.dart', why: '"accepting → error (TutorGrantFailure) renders error heading and the failure message" — raw gRPC codes now map to a friendly message. Update the expected message to the friendly one (verify the heading still shows).' },
  { f: 'features/tutoring/decline_invite_screen_l1_test.dart', why: '"TutorGrantFailure path shows error heading and failure message" — same friendly-error mapping as accept. Update expected message.' },
];

phase('FixTests');
function prompt(e) {
  return [
    `You are a senior Flutter test engineer. Make the failing test(s) in \`test/${e.f}\` GREEN.`,
    COMMON, ``, `## Your file: test/${e.f}`, `## Failing test(s) + cause: ${e.why}`,
    `Read the failing test(s) + the production code, decide intended-change vs regression, fix accordingly, then \`flutter test test/${e.f}\` until all pass.`,
    `RETURN schema: file="${e.f}", green, changedProd, filesChanged, summary, regressionFound (describe a real bug if found, else "").`,
  ].join('\n');
}

const results = (await parallel(FILES.map(e =>
  () => agent(prompt(e), { label: `t:${e.f.split('/').pop()}`, phase: 'FixTests', schema: SCHEMA, model: 'sonnet' })
))).filter(Boolean);
const green = results.filter(r => r.green);
const regressions = results.filter(r => r.regressionFound && r.regressionFound.trim());
log(`Done: ${green.length}/${results.length} green; ${regressions.length} regressions flagged`);
return {
  green: green.map(r => r.file),
  notGreen: results.filter(r => !r.green).map(r => ({ file: r.file, summary: r.summary })),
  prodChanges: results.filter(r => r.changedProd).map(r => ({ file: r.file, files: r.filesChanged, summary: r.summary })),
  regressions: regressions.map(r => ({ file: r.file, regression: r.regressionFound })),
};
