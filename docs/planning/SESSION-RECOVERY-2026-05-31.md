# Session recovery checklist — 2026-05-31 (shell executor died mid-round-6)

## What happened
While clearing a hung `make ci`, an over-broad `pkill -9 -f "bin/dart"` killed a process the
Claude Code Bash executor depends on. After that, ALL Bash calls (main loop AND sub-agents) return
exit 1 / SIGABRT with no output. File tools (Read/Write/Edit) still work. **Fix: restart the shell /
Claude Code session.** No code is lost — see state below.

## State (safe on disk)
- **Rounds 2–5 (42 fixes) are COMMITTED to `dev`** and were green (`make ci` + `format-check`):
  - `90c7a20e` round-2 Pass A, `aaeab9aa` round-2 Pass B, `39f5f8fc` round-2 doc,
    `15d62a74` round-3, `c78d813c` round-4, `89bded11` round-5.
- **Round-6 (13 fixes) is UNCOMMITTED in the working tree** (analyze-clean per sub-agents):
  files incl. streak_milestone_analytics_observer.dart, scheduler_screen.dart, tutor_pin_entry_gate.dart,
  accept_invite_screen.dart (token→nullable @QueryParam), track_dao.dart (purge WHERE +curriculumId),
  stage_definition_repository_impl.dart, outbox_processor.dart, profile_repository_impl.dart
  ('id'→'profile_id'), completion_repository_impl.dart (dedup +curriculumId), 4 RTL widgets, + tests,
  + ARB keys (dayNameShabbos, statusPendingTapToAccept already added/gen-l10n'd in round-5? NO — those
  were round-5). Round-6 added NO new ARB keys. **build_runner WAS run** for R6-8 (router regen).
- Findings docs: docs/planning/bug-hunt-round{2,3,4,5,6}-findings-2026-05-31.md.

## RESUME STEPS (after shell restart)
1. `cd learning_tracker && git status --short` — confirm round-6 working-tree changes are intact.
2. **Round-6 ci FAILED with exit 2 (a real test failure) on the fresh run BEFORE the shell died — it
   was never diagnosed.** Look at `/tmp/ci_r6_fresh.log` if it survived, else re-run:
   `make ci > /tmp/ci_r6.log 2>&1` and find the `[E]` failure(s).
3. The likely failure class: a round-6 fix changed behavior a PRE-EXISTING test asserted (same pattern
   as rounds 4/5). Candidates: profile_repository round-trip test, completion dedup, accept_invite,
   stage reset, or an RTL widget test. Fix the test/lib, keep root-cause correct.
4. `make ci` green + `make format-check` clean → commit round-6 to `dev`.
5. Then: rebuild APK with all 55 fixes + `adb install -r` to phone (100.72.6.10:33281, was connected),
   unlock (ask owner if secured), and verify high-risk fixed flows on-device (tutoring view, rewards,
   offline delete, Hebrew sacred-time card, reader, day-names, search).

## Lesson
NEVER `pkill -f "bin/dart"` / broad `-f` patterns — they match the executor's own processes. To kill a
specific hung test run, target the `make` PID or `flutter_tester` by exact PID, not `-f bin/dart`.
