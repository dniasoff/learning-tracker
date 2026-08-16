# Exhaustive Test-and-Fix Plan — every screen, every button

**Created:** 2026-05-29 · **Owner:** Daniel · **Driver:** Claude (on-device via ADB + automated suites)
**Mandate:** Test *absolutely everything* and **fix as we go**. 2 days is the **floor**, not the cap — the bar is completeness, looped until a clean pass.

---

## 1. Objective & principles

1. **Automation-first.** Every behaviour we verify gets a *repeatable* test so it is checked forever, not once. The end state is "Daniel never hand-tests again."
2. **Fix-as-you-go.** Each confirmed defect is fixed in the same pass and gets a regression test before we move on. No deferral, no TODOs (per `feedback_fix_dont_defer`).
3. **Real-device truth.** Beyond in-process tests, I drive the physical phone over ADB (`reference_phone_testing_adb`) to confirm screens actually render and respond — the layer that catches what widget tests mock away.
4. **Risk-ranked.** Effort front-loads where coverage is lowest and bugs have been surfacing.
5. **Loop until dry.** Re-run the full suite + sweep after each fix wave until two consecutive waves find nothing new.

---

## 2. Baseline (measured 2026-05-29)

| Metric | Value |
|---|---|
| Line coverage | **58.5%** (31,207 / 53,389) across 684 files |
| Files with **0** coverage | **78** |
| Routed screens (`@RoutePage`) | 48 · 61 screen files · 34 dialogs/sheets |
| Inventoried surfaces / buttons / states | 208 / 776 / — |
| User flows mapped | 177 |
| Coverage gaps identified | 235 |
| Risk areas identified | 159 |
| Cloud Functions | 27 — **0 server-side tests** |
| `integration_test/` | 1 stub ("app launches") — **on-device E2E layer empty** |
| Golden baselines for real screens | **0** (all `skipGolden:true`); no dark-theme goldens |
| he-locale/RTL screen coverage | 1 screen (Siyumim) of ~48 |

**Coverage by feature (risk order — lowest first):**

| Area | Cov% | Area | Cov% |
|---|---|---|---|
| tutoring | **16.7%** | onboarding | 41.1% |
| sync | 22.1% | settings | 43.9% |
| tracks | 29.4% | sacred_time | 49.6% |
| gamification | 35.9% | scheduler | 58.2% |
| account | 35.9% | learning / notifications / content | ~63% |
| profiles | 38.8% | dashboard / progress | ~73% · core 74.9% |

> Low coverage ≠ "less code"; it is *where bugs hide*. The tutoring/sync/tracks cluster is exactly where the recent manual-testing bugs surfaced.

---

## 3. Test architecture — 7 layers

| L | Layer | Tool | What it proves |
|---|---|---|---|
| **L0** | Static | `make ci` (dart analyze --fatal-infos, format, custom layering lints DNI-386/387) | Compiles, no layering/lint violations |
| **L1** | Unit/widget | `flutter test` + `mocktail`, `drift_memory`, `firestore_fake` | Each screen renders in every state; each button does the right thing |
| **L2** | Acceptance | `test/story_acceptance/epic_*` | Story-level behaviour per epic (extend + un-skip) |
| **L3** | On-device integration | `integration_test/` run via `flutter test integration_test/ -d <device>` | End-to-end flows on the real phone, real Drift, emulator/real Firebase |
| **L4** | ADB black-box sweep | my `adb` screenshot+tap harness | Every route opens, every button responds, no crash/overflow/dead-end — visual truth |
| **L5** | Backend | `firebase-functions-test` + `@firebase/rules-unit-testing` + emulator | All 27 CFs' auth/state-transition branches; every Firestore rules path enforced |
| **L6** | Visual / i18n / a11y | golden baselines (existing `golden_runner`) + `he` locale + `Directionality.rtl` + semantics | No visual regressions; Hebrew/RTL correct; hardcoded-English strings caught |

**Coverage matrix dimensions** (every screen is a row; we assert the cells that apply):
`renders · loading · empty · error · populated · offline · child · adult · tutor · parent-mode · en · he-RTL · dark-theme`

A live matrix lives at `docs/planning/test-coverage-matrix.md` (generated in Phase 0), one row per routed screen, cells ticked as tests land.

---

## 4. Phase 0 — Tooling & harness setup (foundation, ~½ day)

Build the rigs the rest depends on. Each is itself committed + smoke-tested.

1. **Coverage matrix generator** — script that lists all `@RoutePage` screens + dialogs and emits the matrix skeleton; re-runnable to track progress.
2. **Build out `integration_test/`** — replace the stub with a harness: app boot with seeded Drift DB + Firebase emulator (auth+firestore), helpers to log in as child/adult/tutor and deep-link to any route. (L3 backbone.)
3. **Firebase emulator + backend test harness** — add the `emulators` block to `firebase.json`; wire `@firebase/rules-unit-testing` (Firestore rules) and `firebase-functions-test` (CF unit) under `functions/test/`. This is the single biggest hole (27 CFs, 0 tests). (L5 backbone.)
4. **ADB sweep harness** — a scripted "open every route → screenshot → tap each tappable → screenshot → assert no crash/red-screen/overflow" loop I drive, with a per-screen pass/fail log. Pull route list from `app_router.dart`. (L4 backbone.)
5. **Golden baseline rig** — un-skip `golden_runner`, generate first-time baselines for every routed screen in {en, he-RTL} × {light, dark}. (L6 backbone.)
6. **Un-skip & repair the test net** — `epic_15_multi_profile` is fully `@Skip`'d; turn it on and make it green. Audit other skipped groups.

**Exit:** all five rigs run green on a trivial case; matrix skeleton committed.

---

## 5. Phases 1–8 — risk-ranked test-and-fix waves

Each wave = **inventory the gaps (below) → write L1 widget tests for every screen/state → add/extend L2 acceptance → L3 flow test → L4 on-device sweep → fix every defect found + regression test → re-run.** Cited gaps are from the 2026-05-29 surface inventory.

### Phase 1 — Tutoring (16.7% → target ≥85%) — *highest risk, most recent bugs*
- Widget tests for **all 11 tutoring screens** (Invite, Accept, Decline, ManageTutors, ManageGrants, AuditLog, PinSetup, PinEntryGate, PinReset, + `showTutorPinVerificationDialog`) — currently *zero*.
- `AcceptInviteScreen` 6-step state machine; offline stub-grant fallback; deep-link auth re-entry.
- `incomingTutorGrantsProvider` offline union (CF ∪ mirror, dedup, account-switch) — the fix I just shipped; lock it with a test.
- `TutorGrant` aggregate: all 7 `_buildState` branches + guard methods; use-case precondition errors (accept-non-pending, etc.).
- Enter/exit talmid: cached-mirror fast path, pull success/permissionDenied/error/timeout, listener attach/detach, DEC-21 dual-role leak.
- **Invariants to pin (L5):** `canMarkLiveCompletion` always false across VO + use case + rules + CF; `verifyTutorGrant`'s 5 rejection branches; `tutorBulkPriorCompletions` live-forward block; `acceptTutorInvite` email-match + single-use token + transactional access-doc write.
- Audit log date format → locale-aware `DateFormat.yMMMd` (memory'd rule); localize hardcoded `TALMID PROFILES`.
- E2E (L3): invite → accept → enter → edit → revoke, full round-trip.

### Phase 2 — Sync & offline-first (22.1% / offline area)
- `OfflineTopBanner` (cloud-born+offline vs local vs online), `SyncStatusIndicator` **7 states** — both untested.
- Connectivity-adaptive `app_shell` (loading/error → online default).
- Every screen renders offline (Drift-first); no network-gated UI hangs. Grep-confirmed blocking calls each get an offline test.
- Backup&Sync card states incl. the "Connecting…/LOCAL ONLY" cloud-born path.
- Tutor write CFs fail gracefully offline while cached talmidim still show.

### Phase 3 — Tracks & track-setup wizard (29.4%, ~1,500 dark lines)
- `AddTrackFlow` live screen has **zero** tests (the existing flow tests target a *different* controller — false confidence). Cover: program-aware step-skip, resume-from-prefs + stale-program-bleed guard, exit-confirm, replace-existing dialog, `_finishFlow` TutorWriteException/error+retry.
- `EditTrackScreen`, `ChazaraInlineSetup` (min1/max5), `ScopeStepContent` (auto-skip single child DNI-202), `SelfPacedGoalStep` (pace vs deadline), `StartingPositionStep` (±30 offset, **back-date → overdue catch-up** per project rule), `StudyDays`, per-track + whole-curriculum reorder (race guards + amnesty), `TrackDetail` program vs self-paced.
- Chazara conditional rendering (Rule 8) — no-chazara tracks must show *no* chazara UI (memory'd regression).

### Phase 4 — Gamification & profiles (35.9% / 38.8%)
- Gamification: **zero** widget tests — `GamificationScreen`, `ChildRedemptionScreen` (affordable/unaffordable/confirm/insufficient), `ParentPendingRedemptionsScreen` (approve/decline/double-tap guard), `RewardConfigurationScreen` (validation), points/levels/streak, parent adjust.
- Profiles: un-skipped `epic_15` (CRUD, max-10, cascade delete, dup-name); `showAddProfileDialog`; `ProfilePickerScreen` states + sign-out-section logic; `ParentSettingsScreen` tutor-permission tile matrix; the account-only header sheet I just built.
- Completion credit policy (engagement/achievement/lifetime; sentinel-date bulk doesn't leak into streak).

### Phase 5 — Account, onboarding, navigation/guards (35.9% / 41.1%)
- Sign-in/signup/account-picker: every state (idle/submitting/error/online/offline/registry-match variants), 15s watchdog, 5-account cap, Google-collides-local → upgrade.
- Onboarding phase router (child vs adult vs skip vs join-to-tutor; resume-from-prefs).
- **Guards (L3 via router):** AuthGuard accounts-exist vs none; signed-out-but-onboarded passthrough; guard ordering on `/`; RestoreGuard redirect; ProfileGuard no-profiles→shell (the path I changed); PinGuard scopes; no lockout/dead-ends.

### Phase 6 — Settings, scheduler/progress, notifications/sacred-time, dashboard, learning
- Settings: `_AccountActionsSheet` row-visibility matrix (adult-cloud/adult-local/child/child-elevated/tutor); child-mode parental controls; tutored-session gating; `_PendingInvitesSection`.
- Scheduler: section filter (today/overdue/review), grouped view expand/skip; `StudyDayConfigScreen` (no test file). Localize hardcoded strings.
- Notifications/sacred: `CityPickerScreen`, `SacredTimeSettingsCard`, `LocationService`, `CitiesRepository` — all **zero** tests; Shabbos-mode lock.
- Dashboard: initial-sync gate (`…` vs `0`), AllCaughtUp swap, mission-tile→scheduler section, carousel, child/tutor/parent variants, chazara gating.
- Learning/reader: mark-complete tap → commit + advance; tutor live-mark block (UI + `TutorWriteForbiddenException`); already-completed state; child celebration; offline reader message.

### Phase 7 — Backend (CFs + rules) — L5 deep pass
- Executable test for **each of 27 CFs**: auth checks, state transitions, error branches (via `firebase-functions-test`).
- **Every Firestore rules path** under the emulator (`rules-unit-testing`) — the fake-Firestore-doesn't-enforce-rules gap that caused a real sign-in lockout (`project_firestore_rules_deploy`).
- Indexes match queries.

### Phase 8 — Visual / i18n / a11y / data-integrity — L6 + invariants
- Golden baselines for all routed screens × {en, he-RTL} × {light, dark}.
- RTL correctness + sweep for hardcoded-English strings (scheduler, tracks, learning, dashboard banner, tutoring header — many flagged).
- Semantics/a11y on interactive elements.
- Data integrity (L1/unit): `DriftMergeStore.remoteIsNewer` ±5s boundary; tombstone-resurrection on pull; FK-guard merger skips; **migrations v26→v28** (untested); multi-account DB threading.

---

## 6. Fix-as-you-go loop (per defect)

```
find (test fails / sweep shows wrong UI / on-device repro)
  → confirm it's real (read the code, reproduce on device)
  → fix (smallest correct change; offline-first; respect layering & product rules)
  → add/adjust the regression test so it now passes and would catch the regression
  → re-run make ci + the affected suite
  → log it in docs/planning/test-fix-bug-log.md (one line: symptom → cause → fix → test)
```

Bugs are committed in small, described commits on `dev` (no feature branches, per `feedback_no_feature_branches`).

---

## 7. Definition of done (exit criteria)

- `make ci` green; **line coverage ≥ 85% overall**, and **no feature below 75%**.
- Every routed screen has L1 tests for: renders + every applicable {loading/empty/error/offline} state + each role variant it supports.
- Every interactive element on every screen has a test asserting its effect (or is provably dead and deleted).
- All 177 mapped flows have an L2 or L3 test.
- All 27 CFs and all Firestore rules paths have L5 tests under the emulator.
- Golden baselines exist for every routed screen in en+he, light+dark; RTL sweep clean; no hardcoded-English in localized surfaces.
- L4 ADB sweep: every route opens, every button responds, zero crashes/overflows/dead-ends on the physical device.
- Two consecutive full passes find **zero** new defects.
- `test-coverage-matrix.md` fully ticked; `test-fix-bug-log.md` complete.

---

## 8. Sequencing & estimate (2 days = floor)

| Block | Phases | Rough effort |
|---|---|---|
| Foundation | Phase 0 (5 rigs + un-skip) | ~0.5 day |
| High-risk core | Phases 1–3 (tutoring, sync/offline, tracks) | ~1 day |
| Breadth | Phases 4–6 (gamification/profiles, account/nav, settings/dashboard/learning/scheduler/notifications) | ~1 day |
| Backend & visual | Phases 7–8 (CFs+rules, golden/i18n/a11y, data-integrity) | ~0.5–1 day |
| Loop-until-dry | re-runs + tail-end fixes | open-ended |

Phases run as background workflows where they fan out (e.g. "write widget tests for these 11 screens" → one agent per screen, adversarially reviewed), with me synthesizing, fixing, and verifying on-device between waves. Progress is visible in the coverage matrix and bug log after every wave.

---

## 9. Tracking artifacts (created as we go)
- `docs/planning/test-coverage-matrix.md` — live screen×dimension grid.
- `docs/planning/test-fix-bug-log.md` — every bug found→fixed→regression-tested.
- Coverage % re-measured (`flutter test --coverage`) at the end of each block.
