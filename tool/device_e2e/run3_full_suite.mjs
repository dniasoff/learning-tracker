import { runFullSuite } from './_full_suite_lib.mjs';

export const meta = {
  name: 'device-e2e-full-suite-run3',
  description: 'Comprehensive 3-device parallel on-device E2E re-audit: seed each device, walk every screen across 16 feature areas (EN + Hebrew/RTL), adversarially verify every finding, synthesize a gate report',
  phases: [
    { title: 'Seed', detail: 'populate each device (offline account, profiles, track, completions, parent PIN, reward) + audit onboarding/wizard' },
    { title: 'Audit', detail: '3 parallel device-chains walk every screen in their area partition' },
    { title: 'Verify', detail: 'adversarially verify each candidate finding against code + screenshot' },
    { title: 'Synthesize', detail: 'consolidate verified findings into a gate report' },
  ],
}

return await runFullSuite({
  runNum: 3,
  reportIntro: `Run: comprehensive 3-device parallel on-device E2E re-audit (run 3 — fresh validation pass) of the Learning Tracker Android app. Build = current dev HEAD (all 32 fixes from runs 1+2 included; this run validates them).`,
  phase, agent, parallel, log,
});
