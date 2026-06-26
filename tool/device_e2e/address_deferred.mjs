export const meta = {
  name: 'address-deferred-items',
  description: 'Carefully address the 4 deferred audit items (RTL segmented #10, dead route #20, cold-start bootstrap #1, breadcrumb threading #3): investigate, fix only if safe+verified, else return a plan',
  phases: [{ title: 'Address', detail: '4 parallel agents, one per deferred item, distinct devices + files' }],
}

const REPO = '/home/daniel/repos/learning-tracker';
const LIB = REPO + '/learning_tracker/lib';
const DEVE2E = REPO + '/tool/device_e2e';
const PKG = 'com.jcom.torah.learning_tracker';

function drive(serial, port) {
  return [
    `## Device driver (ONLY serial ${serial}; never adb connect / no other serial / no journey_01)`,
    `\`\`\`python`,
    `import sys, time; sys.path.insert(0, "${DEVE2E}")`,
    `from driver import Device`,
    `d = Device("${serial}", artifact_dir="/tmp/device_e2e/${port}")`,
    `\`\`\``,
    `API: d.launch(clear=False), d.screenshot("name"), d.find/wait/present(text=/desc=/hint=/contains=), d.tap_text/tap_desc/tap_contains, d.tap_xy(x,y), d.back(), d.type_into(hint=,text=), d.shell(cmd), d._dump(). Settle 1.5s before screenshot, then Read the PNG. ANR -> tap "Wait", sleep 8, retry.`,
  ].join('\n');
}

const RULES = [
  `## Rules`,
  `- SURGICAL minimal changes; match surrounding style; respect layering lints (DNI-386/387).`,
  `- Edit ONLY your assigned files. Do NOT commit/build-apk/deploy.`,
  `- After editing: \`dart analyze <files>\` (env: \`export PATH="/home/daniel/flutter/bin:$PATH"; export LD_LIBRARY_PATH="$HOME/.local/lib/sqliteshim:$LD_LIBRARY_PATH"\` from learning_tracker/). Must be clean.`,
  `- These are the RISKY/CONTESTED items. If a SAFE, contained, verified fix is NOT achievable, do NOT force it — set verdict="deferred-with-plan" and explain precisely.`,
].join('\n');

const SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['item', 'verdict', 'applied', 'filesChanged', 'summary', 'analyzeClean'],
  properties: {
    item: { type: 'string' },
    verdict: { type: 'string', enum: ['fixed', 'rejected', 'deferred-with-plan'] },
    applied: { type: 'boolean' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    onDevice: { type: 'string' },
    recommendation: { type: 'string' },
    analyzeClean: { type: 'boolean' },
  },
};

const item10 = [
  `You are resolving DEFERRED item #10 (RTL segmented controls) for the Learning Tracker app. This was REJECTED in run-2 (Flutter SegmentedButton mirrors via Directionality) but CONFIRMED in run-3 (default/selected option on the wrong visual side in RTL). Resolve the contradiction WITH ON-DEVICE EVIDENCE, then fix ONLY if genuinely wrong, and ONLY with a Directionality-AWARE change (must not affect LTR).`,
  drive('emulator-5562', '5562'),
  RULES,
  `Assigned files: ${LIB}/features/settings/presentation/screens/settings_screen.dart (the _HebrewDateTile segmented control ~lines 367-370 and _NikudTile ~476-479, plus any sibling segmented controls in Settings).`,
  ``,
  `STEPS:`,
  `1. Read settings_screen.dart around those segmented controls — note each control's options list ORDER and which is the default/selected.`,
  `2. On emulator-5562: set Hebrew (\`d.shell("cmd locale set-app-locales ${PKG} --locales he")\`, try "iw" if no-op), force-stop, relaunch. Enter the adult profile -> Settings. Screenshot the segmented controls. Read the PNGs.`,
  `3. JUDGE: in RTL, is any control's selected/default segment on a DIFFERENT side than its sibling controls, or clearly violating RTL convention (primary/first option should be on the RIGHT/leading edge in RTL)? Compare the controls to each other. (Note: SegmentedButton DOES auto-mirror; a segment on the left can simply be the selected index — that alone is NOT a bug. The bug is only if controls are INCONSISTENT with each other or the first/primary option lands on the trailing edge.)`,
  `4. If genuinely wrong: apply a DIRECTION-AWARE fix — reverse the affected control's options list ONLY under RTL, e.g. build the segments and use \`Directionality.of(context) == TextDirection.rtl ? segments.reversed.toList() : segments\` (keep \`selected\` correct). Then re-verify on-device IN HEBREW (now consistent/correct) AND reason that LTR is unchanged (you can also switch back to en and screenshot to confirm LTR is unaffected). Reset locale to en at the end.`,
  `5. If NOT genuinely wrong (consistent + correct, run-2 was right): verdict="rejected" with the screenshot evidence.`,
  `RETURN the schema object (item="#10 RTL segmented").`,
].join('\n');

const item20 = [
  `You are resolving DEFERRED item #20: the CurriculumSettings route is registered but never navigated to from any UI (dead route). Decide: WIRE it (add a sensible entry point) if it's a complete, useful screen that simply lost its entry — OR recommend removal if it's a stub/obsolete. Do NOT expose an unfinished screen.`,
  RULES,
  `Assigned files (only touch what you actually change): ${LIB}/features/settings/presentation/screens/curriculum_settings_screen.dart (read it), its route registration in ${LIB}/core/navigation/app_router.dart (read), and a candidate entry point ${LIB}/features/progress/presentation/screens/curriculum_progress_screen.dart (the run-3 suggestion) OR a Settings list tile.`,
  ``,
  `STEPS:`,
  `1. Read curriculum_settings_screen.dart fully. Is it a COMPLETE, functional screen (real controls, saves state) or a stub/placeholder/obsolete? Check git blame/history context if helpful (\`git log --oneline -- <file>\`).`,
  `2. Grep the whole repo for CurriculumSettingsRoute / CurriculumSettings to confirm it's truly never pushed.`,
  `3. DECISION:`,
  `   - If COMPLETE + clearly belongs (e.g. it manages which curricula are enabled, which is a real settings need): WIRE a single, sensible, low-risk entry point — prefer a Settings list tile in the curriculum/settings area, or an AppBar action on Curriculum Progress. Make it minimal and consistent with how other settings rows navigate. analyze clean.`,
  `   - If it's a STUB / superseded / risky to expose: do NOT wire it. verdict="deferred-with-plan", recommend either removing the route+screen (list the references) or completing it — whichever the evidence supports.`,
  `RETURN the schema object (item="#20 dead CurriculumSettings route"). No device needed.`,
].join('\n');

const item1 = [
  `You are resolving DEFERRED item #1: cold start blocks the UI for 15+ seconds after pm clear (first-run content-DB seed extraction + init runs before runApp, so the user stares at a frozen splash). HIGH BLAST RADIUS — a wrong change breaks app launch entirely. Be extremely careful and VERIFY ON-DEVICE that the app still launches.`,
  drive('emulator-5560', '5560'),
  RULES,
  `Assigned files: ${LIB}/main.dart and anything under ${LIB}/app/bootstrap/ (read bootstrap.dart etc.). Do NOT touch other features.`,
  ``,
  `STEPS:`,
  `1. Read main.dart + the bootstrap flow. Identify exactly what runs BEFORE runApp() and what is slow on first run (Firebase init? content-DB seed extraction/copy? provider warmup?).`,
  `2. Measure the current cold start on emulator-5560: \`d.shell("pm clear ${PKG}")\`, then time launch -> first interactive frame (poll uiautomator for the first real screen). Record seconds.`,
  `3. Assess feasibility of a SAFE change: can runApp() be called EARLY with a proper loading/splash widget while the slow first-run work (seed extraction) completes asynchronously behind a loading gate, WITHOUT reordering anything the app depends on (Firebase, DB open, providers)? Many apps already have a gate (e.g. an AsyncValue/bootstrap provider the root widget watches). Look for an existing splash/loading mechanism to reuse.`,
  `4. If a contained, safe change is feasible: apply it. Then VERIFY on-device: pm clear -> launch -> the app must reach the normal first-run UI correctly (no crash, no stuck splash, data works). Re-measure the time-to-first-interactive (ideally the heavy seed no longer blocks the first frame). Screenshot the launch sequence.`,
  `5. If it is genuinely a larger refactor with real risk of breaking launch (e.g. the app cannot function until the DB is seeded and there's no loading-gate pattern to hook into): do NOT apply. verdict="deferred-with-plan" with the measured timing, the exact blocking call(s), and a concrete safe approach. (It is FINE to defer this one — a broken launch is far worse than a slow first run.)`,
  `RETURN the schema object (item="#1 cold-start splash"). Include the measured before/after seconds in onDevice.`,
].join('\n');

const item3 = [
  `You are resolving DEFERRED item #3: a חומש (Chumash) text's breadcrumb shows the wrong curriculum root ('תורה' instead of 'חומש') because ContentIndex._byRef collides on sefariaRef across curricula (last-write-wins). A clean fix needs the breadcrumb to resolve the RIGHT curriculum's ContentItem. The earlier attempt added an optional preferredCurriculum to ContentIndex.lookup but did NOT thread it through the providers (reverted). HIGH BLAST RADIUS if the family provider signature changes for all callers.`,
  drive('emulator-5554', '5554'),
  RULES,
  `Assigned files: ${LIB}/core/content/content_index.dart, ${LIB}/core/labels/curriculum_label_providers.dart, and ${LIB}/features/content_browsing/presentation/screens/text_display_screen.dart. (You MAY add an OPTIONAL curriculum param threaded through these; keep all existing callers working unchanged.)`,
  ``,
  `STEPS:`,
  `1. Read content_index.dart (lookup + _byRef), curriculum_label_providers.dart (renderedDisplayForRef/renderedParentForRef/_findContentItem at ~183), and how text_display_screen.dart obtains the breadcrumb (renderedDisplayForRefProvider(sefariaRef) ~line 55) and whether it has the curriculum (task.curriculumId).`,
  `2. Count ALL callers of renderedDisplayForRefProvider / renderedParentForRefProvider across the repo (grep). Determine whether each caller has a curriculum available.`,
  `3. CHOOSE the SAFEST correct fix:`,
  `   - PREFERRED if feasible: add a curriculum-aware index + an OPTIONAL \`preferredCurriculum\` threaded ONLY where the curriculum is known: add it to ContentIndex.lookup (optional), to _findContentItem (optional), and to the providers as an OPTIONAL extra family arg with a default that preserves current behavior — OR add a SEPARATE optional-arg provider variant used only by TextDisplay — so existing 1-arg callers are untouched. Then have text_display_screen pass its known curriculum. The key constraint: do NOT break existing callers; prefer additive/optional over signature-changing.`,
  `   - If that's not cleanly possible without breaking many callers: verdict="deferred-with-plan" with the caller inventory + the recommended approach.`,
  `4. If you applied a fix, VERIFY on-device (emulator-5554): browse Chumash content (LEARN -> Browse -> חומש/Chumash -> drill to a text -> open it) and confirm the TextDisplay breadcrumb header now shows the חומש root, not תורה. (Browsing is read-only; no track needed. If 5554 has no data, create a quick Chumash track or just use Browse.) Screenshot.`,
  `RETURN the schema object (item="#3 breadcrumb curriculum collision").`,
].join('\n');

phase('Address');
const items = [
  { k: '10', p: item10 }, { k: '20', p: item20 }, { k: '1', p: item1 }, { k: '3', p: item3 },
];
const results = (await parallel(items.map(it =>
  () => agent(it.p, { label: `deferred:#${it.k}`, phase: 'Address', schema: SCHEMA, model: 'sonnet' })
))).filter(Boolean);

log(`Done: ${results.map(r => `#${r.item}=${r.verdict}`).join(' | ')}`);
return {
  results: results.map(r => ({
    item: r.item, verdict: r.verdict, applied: r.applied, files: r.filesChanged,
    analyzeClean: r.analyzeClean, summary: r.summary, onDevice: r.onDevice, recommendation: r.recommendation,
  })),
};
