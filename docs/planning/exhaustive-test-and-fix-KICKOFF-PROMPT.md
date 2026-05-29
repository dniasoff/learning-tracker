# Testing kickoff prompt

Paste the block below into a Claude Code session at the repo root. Built around the actual testing
needs of this app — not generic orchestration. Run with **Opus + `/effort ultracode`**.
Resumable: the coverage matrix + bug log are the state, so re-pasting continues where it left off.

---

```
GOAL — make manual testing unnecessary. Every screen, button, state, flow, Cloud Function and
Firestore rule gets an automated test AND is verified working on the real phone; every defect found
is fixed in the same pass with a regression test. Loop until two consecutive full passes find nothing
new. 2 days is the floor. Full plan: docs/planning/exhaustive-test-and-fix-plan-2026-05-29.md.

WHAT "DONE" FEELS LIKE
- I can change code and one command tells me if anything broke (make ci stays green).
- ≥85% line coverage overall, no feature below 75% (baseline today: 58.5%; tutoring 16.7%, sync 22%,
  tracks 29% are the worst and where bugs keep surfacing).
- Every routed screen opens on my physical phone, every button responds, nothing crashes/overflows/
  dead-ends — proven by an on-device sweep, not by hand.
- Hebrew/RTL and offline both work on every screen.

THE TESTING TOOLKIT FOR THIS REPO (use exactly these)
- Static:      make ci   (dart analyze --fatal-infos + format + story suite) — run before every commit.
- Coverage:    flutter test --coverage   → coverage/lcov.info  (re-measure after each area).
- Widget/unit: flutter test <path>   with mocktail + test/helpers/{drift_memory,firestore_fake,
               test_database,golden_runner} + test/mocks + test/fixtures.
- Acceptance:  test/story_acceptance/epic_*.dart   (make test-epic-N / make test-story-X.Y). Un-skip
               and fill the @Skip'd groups (epic_15_multi_profile is fully skipped).
- On-device E2E: integration_test/ (today just a stub) run via flutter test integration_test/ -d <dev>.
- ADB sweep:   drive the physical phone — see memory reference_phone_testing_adb (adb connect
               100.72.6.10:<PORT>, screencap, input tap; screen is 1080x2340). ASK me for the current
               port if not connected. JDK 21 required; the debug handshake drops over wireless ADB but
               the APK installs — re-run or drive the installed app.
               KEEPALIVE: as soon as the device is connected, start the background pinger so wireless
               debugging doesn't drop on idle — run it detached:
                 tool/adb-keepalive.sh 100.72.6.10:<PORT> 20 &
               (pings `adb shell true` every 20s and auto-reconnects on drop; stop with pkill -f adb-keepalive.sh).
- Backend:     stand up the Firebase emulator (add `emulators` to firebase.json) + firebase-functions-test
               + @firebase/rules-unit-testing under functions/test/. 27 CFs + all rules paths have ZERO
               server tests today — this is the single biggest hole and caused a real sign-in lockout.
- Codegen:     after touching Drift/Freezed/Riverpod: dart run build_runner build --delete-conflicting-outputs.

TEST EVERY SCREEN ACROSS THESE CELLS (assert the ones that apply)
renders · loading · empty · error · offline · child · adult · tutor · parent-mode · en · he-RTL · dark.

FIRST, BUILD THE RIGS (commit + smoke-test each)
1. docs/planning/test-coverage-matrix.md — one row per @RoutePage screen (read app_router.dart) +
   dialogs; columns = the cells above; tick as tests land. This is the scoreboard.
2. docs/planning/test-fix-bug-log.md — one line per bug: symptom → cause → fix → test.
3. integration_test/ harness — boot with seeded Drift + emulator; helpers to sign in as child/adult/
   tutor and deep-link to any route.
4. firebase.json emulators + functions/test/ backend harness.
5. ADB sweep harness — for each route: open → screenshot → tap each tappable → screenshot → assert no
   crash/red-screen/overflow → write pass/fail into the matrix.
6. Un-skip epic_15 and any other skipped groups; make green.

THEN WORK THE AREAS, WORST-COVERAGE FIRST
1 Tutoring → 2 Sync/offline → 3 Tracks → 4 Gamification+Profiles → 5 Account+Onboarding+Nav/guards →
6 Settings+Scheduler+Notifications+Dashboard+Learning → 7 Backend CFs+rules → 8 Visual/i18n/a11y +
data-integrity/migrations. The plan §5 lists the concrete untested screens/flows per area — work from
that list. Highlights of what's currently UNtested:
- Tutoring: all 11 screens (Invite/Accept/Decline/ManageTutors/ManageGrants/AuditLog/PinSetup/
  PinEntryGate/PinReset + verification dialog); incomingTutorGrants offline union; canMarkLiveCompletion
  invariant across VO+useCase+rules+CF; verifyTutorGrant rejection branches.
- Sync/offline: OfflineTopBanner, SyncStatusIndicator (7 states); every screen must render offline.
- Tracks: AddTrackFlow live screen (existing tests target a different controller — false confidence);
  EditTrack, Chazara setup, scope auto-skip, starting-position back-date→overdue, reorder race guards.
- Gamification: every screen (redemption affordable/unaffordable, approve/decline, reward validation).
- Backend: each of 27 CFs' auth + state-transition + error branches; every rules path under emulator.
- Visual/i18n: 0 golden baselines for real screens; only 1 screen has he/RTL coverage; lots of
  hardcoded-English strings (scheduler, tracks, learning, dashboard banner, 'TALMID PROFILES').

THE LOOP, PER AREA
write L1 widget tests for every applicable cell → extend the epic_* acceptance suite → add one L3
end-to-end flow → run the L4 ADB sweep on the phone → FIX every defect (tests + sweep) + regression
test → log it → make ci + re-measure coverage → tick the matrix. Use background Workflows to fan out
(one agent per screen/CF/rule, then adversarially verify each test asserts behaviour, not just
renders); synthesize, fix, and verify on-device yourself between waves. Don't go >2 waves without
make ci. Report coverage delta + screens ticked + bugs fixed after each wave.

MODELS — HARD RULE: every FIX stays on Opus. Sonnet sub-agents may ONLY write/verify test files; they
must never edit production code (lib/**, functions/src/**) or decide a fix. The Opus orchestrator owns
all synthesis, every diff to production code, and on-device verification. Run the fan-out on Sonnet for
speed/cost: in the workflow pass agent(prompt, { model: 'sonnet' }) for the per-screen/per-CF
test-WRITING agents and the adversarial-verify agents only. If a Sonnet agent surfaces a likely bug, it
REPORTS it back as a finding — the Opus orchestrator reproduces, fixes, and writes the regression test.

RULES (binding — see memory)
- Fix-as-you-go; no TODOs/deferral. Every bug gets a failing→passing regression test.
- Offline-first: Drift-first reads, queued writes, no network-gated UI, no untimed network spinner.
- Work on dev; no feature branches/worktrees; small described commits.
- Layering (DNI-386/387): core↛features, no cross-feature deep imports, Firebase only in core/sync+auth,
  Talker only in core/logging, no .displayName* bypass. make audit when touching imports.
- Localize user-facing strings; locale-aware dates DateFormat.yMMMd(locale); "English" not "Gregorian".
- Product rules: child+adult only (no "parent" type); tutor sees the child's management view; chazara UI
  only when track.chazaraEnabled; no "track type" labels.

START NOW: confirm phone connectivity (ask for the adb port if needed), run flutter test --coverage for
a fresh baseline, build the 6 rigs, then begin Tutoring. Keep going until DONE — 2 days is the floor.
```

---

**Notes:** resumable (matrix + bug log = state); device port changes per session so it will ask;
under `/effort ultracode` it fans out many agents per wave (intended for "test everything"). To run a
single area, replace the "worst-coverage-first" order line with just that area.
```
```
