# learning_tracker/tool

Build, codegen, seed, and `make audit` check scripts for the Flutter app. Most
files here are `check_*.dart` audit checks (see [Enforcement — `make audit`
and CI](../../docs/coding-standards.md#enforcement--make-audit-and-ci) for the
full list) or one-off `*.dart` seed/build utilities. Subdirectories
(`data/`, `text_extract/`, `curate_curricula/`, `hebcal_fetch/`,
`sefaria_fetch/`, `seed/`) carry their own `README.md` where non-obvious.

## Retention rule: `*.workflow.js` device-test scripts

An on-device test round (driving a real phone over ADB, per
[on-device-exhaustive-test-plan-2026-05-31.md](../../docs/planning/on-device-exhaustive-test-plan-2026-05-31.md))
is sometimes captured as a committed `<round>_<slug>.workflow.js` script (a
Claude Code agent-workflow definition) so the round can be re-dispatched
without re-typing the driving prompt.

These scripts are **round-scoped, not reusable regression harnesses**: they
hardcode one tester's device IP, throwaway test-account PINs, and reference
specific already-numbered bugs (`FIX#N`) from the round that produced them.
Once a round's fixes have landed (a `fix(runN...)`/`fix(runN-cycleM...)`
commit referencing the same `FIX#N`) and been re-verified (typically by the
*next* round's setup+verify pass touching the same area), the round's
`*.workflow.js` file has no further value — keeping it invites a reader to
wonder whether it's a deliberately-kept regression script or uncleaned
debris. So:

- **While a round is active or unverified:** keep its `*.workflow.js` file(s).
- **Once every `FIX#N` it references has a landed, re-verified fix commit:**
  delete the file(s) in the same commit/PR that lands the last such fix (or,
  if that already happened, in a standalone hygiene commit). Do not archive
  them "just in case" — the driving prompts are reconstructable from the plan
  doc above, and stale device IPs/PINs make them misleading if left in place.
- **If a round produced a durable, non-round-specific reusable harness**
  instead of a one-off sweep, it belongs under `tool/device_e2e/` (repo-root
  `tool/`, see its [README](../../tool/device_e2e/README.md)) as a proper
  driver/journey, not as a `*.workflow.js` file here.

Applied: the `run2_*`/`run3_*.workflow.js` scripts that prompted this rule
(`run2_test_sweep`, `run2_tutoring_gamification`, `run2_tutoring_retest`,
`run3_cycle3_single`, `run3_test_cycle`, `run3_tutor_extensive`) have been
removed — every `FIX#N` they reference (FIX#7, FIX#8, FIX#9) has a landed fix
commit (`6cdd919f`, `7519a8bd`, `5f182dd3`, `9bfbbade`, `25170b17`,
`afa2b71a`), and `run3_cycle3_single.workflow.js`/later rounds' own
setup+verify passes re-tested the same areas, so nothing here still serves as
a live regression script.
