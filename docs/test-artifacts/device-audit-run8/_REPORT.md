# On-Device Audit — Run 8 Report

## Scope

- **Run:** 8 — first native-Linux / KVM 6-device fleet run (prior runs used the older cross-platform harness).
- **Devices (6, real emulator processes):** Android 9 / API 28 (Pixel 2), Android 10 / API 29 (Pixel 3), Android 12 / API 31 (Pixel 5), Android 13 / API 33 (Pixel 6), Android 14 / API 34 (Pixel 7), Android 16 / API 36 (tablet).
- **API spread:** 28 → 36, phone + tablet form factors.
- **Seed:** credential-less **offline account** recipe (network cut, `pm clear`, "Create Offline Account", Adult-Mode profile, one משניות self-paced track, 1+7-day chazara, ~21/week pace) on every device.
- **Build under test:** current `dev` HEAD **`f8b42240`** (app version v1.0.65 (1)).
- **Verification:** P0/P1 findings ran through an independent adversarial-verify pass; verdicts applied below (FALSE_POSITIVE findings dropped from the confirmed set).

---

## Executive Summary

**Gate verdict: FAIL** — for the on-device experience.
One **CONFIRMED P0** crashes the whole app when entering the Learn surface — the primary "do today's learning" pillar — so the core flow is unreachable on at least the memory-constrained device. That alone fails the gate regardless of the P2/P3 tail.

- **Seed:** 6/6 devices seeded profile+track cleanly on the offline recipe; app data survived every emulator-process restart (disk-backed AVDs).
- **Coverage:** 140 screens audited across the fleet (19/9/27/40/27/18).
- **Findings after verify (23 raw → 2 dropped → 21):** P0 = 1, P1 = 0, P2 = 8 (1 of which is environment-flagged, not an app defect), P3 = 12.
- **Dropped by verify:** 2 × P1 FALSE_POSITIVE — "missing Mark Complete buttons" (screenshots proved the button rendered; auditor tapped it) and the 5560 "Learn crash" (re-attributed to host software-GPU / SwiftShader instability, not app code).

**Top real issues:**
1. **P0 (CONFIRMED, API 29):** entering Learn eager-loads all 9 curricula (~70k sections) on a 512 MB heap → whole process dies in 1–3 s.
2. **P2 cross-device:** bulk-mark / prior-learning completions don't roll up into aggregates — Lifetime Knowledge header reads 0 next to a non-zero row (5562); Recent Activity reads 0 under "All Time" (5560).
3. **P2 RTL/i18n cluster (5564):** "Hebrew Terms" toggle vanishes in Hebrew UI; disclosure chevrons unmirrored on Learn + Notification screens.
4. **P2 (5562):** irreversible "Upgrade to Cloud" gives zero feedback when tapped offline.
5. **P2 (5558):** Add-Track wizard step 7 CTA truncates to "Mark Complet…".

---

## Confirmed Findings (post-verify)

Verify-verdict column: `CONFIRMED` = independently re-reproduced; `—` = not selected for adversarial verify (stands as filed); `env-flagged` = auditor/verify attributes to host emulator instability, not the app. The two FALSE_POSITIVE findings are excluded (listed under "Dropped" below).

### P0
| Sev | Device (API) | Screen | Issue | Verify |
|-----|--------------|--------|-------|--------|
| P0 | 5556 (API 29) | LEARN tab / "Start Learning" / post-completion Dashboard reload | Entering Learn synchronously loads `curriculumContentProvider` for **all 9** curricula (~70,033 sections), not just the active track; on the 512 MB Dalvik heap the qemu/app process is silently killed within 1–3 s (no Dart exception / ANR / tombstone). Learning pillar unreachable via its normal entry point. | **CONFIRMED** (fresh 1/1 repro; whole emulator died) |

### P2
| Sev | Device (API) | Screen | Issue | Verify |
|-----|--------------|--------|-------|--------|
| P2 | 5562 (API 33) | Lifetime Knowledge / Dashboard / Add Lifetime Learning / track detail | "Mark as Previously Learned" write succeeds (items-remaining decrements 4192→4191) but does **not** roll up: Lifetime Knowledge header shows `0 פריטים נלמדו` while the row directly beneath shows `1 of 4192` — two contradictory counts on one screen; Dashboard/Progress/Add-Lifetime all stay 0. **[cross-device w/ 5560]** | — |
| P2 | 5560 (API 34) | Progress → Recent Activity ("All Time") | After bulk-marking 3 mishnayot, Lifetime Knowledge correctly shows 3, but Recent Activity shows `0 Active days` / empty-state even on "All Time" — contradicting its own subtitle "Counts track learning (live + bulk-mark)". **[cross-device w/ 5562]** | — |
| P2 | 5564 (API 36, tablet) | Settings → Profile (Hebrew UI) | "Hebrew Terms" toggle row (header+desc+switch) **disappears entirely** when the app UI is Hebrew; setting still functions but a Hebrew-UI user has no control to change it. **[RTL cluster]** | — |
| P2 | 5564 (API 36, tablet) | Learn tab (Daily Tasks + עיון) & Notification Settings (Hebrew/RTL) | Disclosure chevron **repositioned but not flipped** for RTL — sits on the left edge yet still points right (">"); correctly mirrored elsewhere (Settings/Manage Tracks/Progress), so it's an isolated duplicate list-row widget. **[RTL cluster]** | — |
| P2 | 5562 (API 33) | Settings → Backup & Sync → Upgrade to Cloud | Irreversible one-way "Upgrade to Cloud" tapped offline produces **no feedback** — no toast, inline error, or offline banner (Sign-In/Register screens do show them); button stays tappable. Account correctly stayed LOCAL-ONLY, but user can't tell anything happened. | — |
| P2 | 5558 (API 31) | Add-Track Wizard Step 7 of 7 | Secondary CTA renders "**Mark Complet…**" (ellipsis clips "Completed") — fixed-width button not sized for the string; the equivalent Track-Detail screen shows the full title. | — |
| P2 | 5556 (API 29) | Learning/TextDisplay (revisit completed unit) | Revisiting an already-completed mishnah shows an identical layout to an unstudied one — no checkmark/"Completed" badge/color change; the Mark-Complete button vanishes but nothing replaces it. | — |
| P2 | 5558 (API 31) | Dashboard "Start Learning" / LEARN tab | Emulator process crashed ~3× this session, 2 coinciding with entering Learn; data survived. Auditor flagged as **possibly host GPU/SwiftShader instability**, not confirmed app defect. Overlaps the 5560 crash that verify ruled FALSE_POSITIVE (environment). | **env-flagged** |

### P3
| Sev | Device (API) | Screen | Issue | Verify |
|-----|--------------|--------|-------|--------|
| P3 | 5554 (API 28) | Settings → About footer | Row of 3 outline icons (triangle/chat/star) has empty a11y labels (screen reader announces nothing); two tapped produced no reaction. | — |
| P3 | 5554 (API 28) | Settings → About footer | App names itself "Torah Study Tracker" (old Firebase project id) vs "Learning Tracker" branding everywhere else. | — |
| P3 | 5554 (API 28) | Add-Track wizard Step 7 vs 1 & 3 (LTR) | Drill-in chevron direction/side inconsistent between near-identical list rows in one wizard. **[chevron cluster]** | — |
| P3 | 5558 (API 31) | Add-Track wizard Step 1 vs 7 (RTL) | Same wizard-step-7 chevron inconsistency observed in Hebrew RTL chrome. **[chevron cluster]** | — |
| P3 | 5556 (API 29) | Dashboard → Today's Missions | חזרה summary card shows the word "חזרה" twice stacked (eyebrow + title) — looks like a placeholder duplicate vs the adjacent URGENT/Missed card. | — |
| P3 | 5558 (API 31) | Add-Track wizard Step 4 (Study Days) | שבת row renders in washed-out grey vs the other 6 days; switch is verified enabled/clickable/checked — purely visual, and full-contrast on the dedicated Track-Settings screen. | — |
| P3 | 5558 (API 31) | Track Detail → Edit Goal → Pace | Entering pace = 0 correctly disables Update but with no inline reason; the projection card still computes a nonsensical ~14,672-day estimate instead of an error state. | — |
| P3 | 5560 (API 34) | Add Profile → Set/Confirm Parent PIN keypad | Keypad silently drops taps at normal typing speed (~0.3–0.4 s apart) → false "PINs do not match"; isolated to this keypad's hit-testing. | — |
| P3 | 5562 (API 33) | Settings → Backup & Sync → Upgrade to Cloud | No empty-field validation either — tapping with both fields empty gives no error/shake; other forms (Send invite, Save Reward) grey out until valid. Compounds the offline-silent-failure P2. | — |
| P3 | 5562 (API 33) | Mark Prior Completions "Done!" screen | Ungrammatical/confusing copy "Marked 1 items as completed (3 records)" — should be "1 item"; the "(3 records)" parenthetical (1 completion + 2 auto chazara reviews) is unexplained. | — |
| P3 | 5562 (API 33) | Settings → App Permissions | Location grant resolves to a wordless grey circled-X (no text/retry) when the emulator has no GPS fix — dead-end icon with no fallback to "Choose city". | — |
| P3 | 5562 (API 33) | Settings → Notification Settings | Per-notification sub-toggles render fully enabled/blue even while device-level notifications are blocked — no dimming/warning tying them to the blocked OS permission. | — |

### Cross-device vs device-specific
- **Cross-device / cross-cutting themes** (same defect class on multiple APIs):
  - **Learn-surface crash** — 5556 (API 29, CONFIRMED app-side), 5558 (API 31, env-flagged), 5560 (API 34, verify → FALSE_POSITIVE / host GPU). Verdicts split: confirmed as an app-side eager-load trigger on the low-memory device, attributed to host software-rendering on the higher-spec one.
  - **Aggregation rollup gap** — bulk-mark/prior-learning completions not reflected in aggregates: 5562 (Lifetime Knowledge) + 5560 (Recent Activity).
  - **Chevron direction/mirroring** — wizard step-7 inconsistency on 5554 (LTR) + 5558 (RTL); separate RTL non-mirroring on 5564 (Learn/Notification screens).
- **Device-specific / single-surface:** the two 5562 "Upgrade to Cloud" findings, the 5564 "Hebrew Terms" disappearing toggle, the 5560 PIN keypad, the 5558 CTA truncation, the 5554 About-footer pair, and the remaining P3 polish items.

### Dropped by verify (not counted above)
| Raw sev | Device (API) | Issue | Verdict |
|---------|--------------|-------|---------|
| ~~P1~~ | 5556 (API 29) | "Mark Complete / Next buttons missing on last item (משנה ג)" | **FALSE_POSITIVE** — auditor's own screenshot 11 shows the button present/enabled on משנה ג; the no-button frame was captured *after* they tapped it. Source (`text_display_screen.dart`) collapses the action section for *any* completed item by design. |
| ~~P1~~ | 5560 (API 34) | "Opening curriculum-progress/Learn reliably crashes the app" (attributed to in-app native rendering fault) | **FALSE_POSITIVE (root-cause)** — symptom real, but the whole *VM* died; host `dmesg` shows 199 `RenderThread … segfault` events every 30–90 s across the session, all emulators on `-gpu swiftshader_indirect` (software) vs the project's intended `-gpu host`. Environment/tooling instability, not an app P1. |

---

## Per-Device Coverage

| Device | API | Form | Seeded | Screens audited | Findings (raw) | After verify |
|--------|-----|------|--------|-----------------|----------------|--------------|
| emulator-5554 (Pixel 2) | 28 (Android 9) | phone | profile+track | 19 | 3 | 3 (0 dropped) |
| emulator-5556 (Pixel 3) | 29 (Android 10) | phone | profile+track | 9 | 4 | 3 (1 P1 dropped) |
| emulator-5558 (Pixel 5) | 31 (Android 12) | phone | profile+track | 27 | 5 | 5 (1 env-flagged) |
| emulator-5560 (Pixel 7) | 34 (Android 14) | phone | profile+track | 40 | 3 | 2 (1 P1 dropped) |
| emulator-5562 (Pixel 6) | 33 (Android 13) | phone | profile+track | 27 | 6 | 6 (0 dropped) |
| emulator-5564 (tablet) | 36 (Android 16) | tablet | profile+track | 18 | 2 | 2 (0 dropped) |
| **Total** | 28–36 | 5 phone + 1 tablet | **6/6** | **140** | **23** | **21** |

Coverage note: 5556's low count reflects the Learn-crash P0 blocking the entire Learning pillar (Content hierarchy + search unreachable). 5558/5560 similarly lost the Learn-content screen to the crash/instability but reached deep Tracks/Scheduler and Gamification surfaces respectively. The offline seed and all app data survived every emulator-process death on every device (persistent userdata images), so no re-seed was needed after the first `pm clear`.

---

## Ladder Position — What This Run Proves

This run exercised the **weakest / top rung of the test ladder — real on-device, full-stack, human-flow execution** — the layer with the least prior automated coverage and the highest fidelity to what a user actually sees.

**Now backed by real multi-device evidence (API 28→36, phone + tablet, native KVM):**
- The **offline-account onboarding path** (network-cut → Create Offline Account → Adult profile → 7-step Add-Track wizard → populated Dashboard) works end-to-end on all 6 devices.
- The **Tracks + Scheduler surface** (track management, reorder/reset, Edit Goal pace/deadline/no-deadline, Study Days, Mark-Prior-Learning, delete guardrail) — walked deeply on 5558.
- The full **Gamification + redemption loop** (Point Settings, Adjust Points, Reward Configuration, child Redeem Prizes, Parent Pending/Fulfil) — verified end-to-end on 5560.
- **Hebrew / RTL** rendering and the **device-locale-only** language model — verified on 5562 (functional calendar/terms/nikud toggles) and 5564 (full RTL pass on tablet).
- **Offline resilience** — city DB (~33k cities), diagnostic-log gating, LOCAL-ONLY account integrity — all confirmed to degrade gracefully with zero network.
- Rendering integrity on the **oldest/smallest device** (API 28 Pixel 2) — no genuine RenderFlex/clipping defects found.

**What remains (not yet proven):**
- **CI automation of this rung.** This run was driven manually by per-device agents; there is no automated harness executing these device flows in CI. The environment itself was a confound — the fleet ran on `-gpu swiftshader_indirect` (software) rather than the documented `-gpu host`, producing frequent host-side RenderThread segfaults that muddied crash attribution and cost live emulator instances during verify.
- **The Learn / study-content path** could not be cleanly audited on 3 devices (crash on 5556, instability on 5558/5560); the P0 needs a re-test on the documented hardware-GPU setup (or a real device) to separate the confirmed app-side eager-load trigger from ambient host instability, and Content hierarchy + search remain effectively unaudited this run.
- **Deterministic, low-memory repro** for the P0 should be pinned in an automated device test (constrained heap) so the eager cross-curriculum load regression is caught below this rung in future.
