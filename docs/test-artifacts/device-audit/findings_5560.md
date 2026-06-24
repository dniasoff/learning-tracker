# Device Audit — emulator-5560 (Pixel 7 API 34, Android 14)
Run date: 2026-06-23
Auditor: calibration agent (emulator-5560 partition)
App version: v1.0.65 (1)

---

## Screens audited

| # | Screen | Result |
|---|--------|--------|
| 1 | Profile Picker ("Who is learning?") | PASS |
| 2 | Dashboard — empty state (Daniel, no tracks) | PASS (by-design empty state) |
| 3 | LEARN tab — empty state | PASS (by-design empty state) |
| 4 | PROGRESS tab — empty state | PASS (by-design empty state) |
| 5 | SETTINGS tab root | PASS |
| 6 | Settings → Manage Tracks (empty) | PASS |
| 7 | Settings → Manage Profiles | PASS (minor — see F-04) |
| 8 | Add Track wizard — Step 1: Select Curriculum | PASS |
| 9 | Add Track wizard — Step 2: Join a Program? | PASS |
| 10 | Add Track wizard — Step 3: Select Sedarim | ISSUES — see F-01, F-02 |
| 11 | Add Track wizard — Step 4: Study Days | PASS (שבת=ON is intentional per code) |
| 12 | Add Track wizard — Step 5: חזרה schedule | PASS |
| 13 | Add Track wizard — Step 6: Pace / Deadline | PASS |
| 14 | Add Track wizard — Step 7: Mark Prior Learning | PASS |
| 15 | Dashboard — populated (with track + completions) | PASS |
| 16 | LEARN tab — populated (Daily Tasks list + Browse) | PASS |
| 17 | Learning detail screen (text + Mark complete) | PASS |
| 18 | PROGRESS tab — populated | PASS |
| 19 | Progress → Recent Activity | PASS |
| 20 | Content Browse — Curriculum / Seder / Masechta hierarchy | PASS |
| 21 | Content Browse — Text Display (browse path, read-only) | ISSUES — see F-05 |
| 22 | Content Search | ISSUES — see F-06 |
| 23 | Settings → Manage Tracks — populated track card | ISSUES — see F-07 |
| 24 | Track Detail screen | PASS |
| 25 | Track Detail → Edit Goal | PASS |
| 26 | Track Detail → Study Days | PASS |
| 27 | Settings (bottom) — Backup & Sync | ISSUES — see F-08 |
| 28 | PinKid child dashboard (no tracks) | PASS |
| 29 | Child Settings — PARENTAL CONTROLS section | PASS |
| 30 | PIN entry dialog (Enter Parent PIN) | PASS |
| 31 | PIN creation flow (Set Parent PIN) | ISSUES — see F-09 |
| 32 | Parent Settings hub (Gamification) | PASS |
| 33 | Parent Settings → Point Configuration (empty) | PASS |
| 34 | Parent Settings → Reward Configuration | PASS |
| 35 | RedeemKid child dashboard (no tracks) | PASS |
| 36 | Progress → Lifetime Knowledge | PASS |
| 37 | Progress → Siyumim & Milestones | PASS |

---

## Findings

### [P2] Wizard Step 3 — טהרות subtitle reads "Core section focus" (placeholder text)
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: /tmp/device_e2e/5560/12c_wizard_step3_scrolled2.png
- What: Five of six sedarim have proper descriptive subtitles (e.g., "Seeds & Agriculture", "Festivals & Sabbaths"). The sixth, טהרות, shows "Core section focus" — generic placeholder copy, not a real description. Expected subtitle: "Ritual Purity" or equivalent.
- Repro: Add Track → משניות → Self-paced → scroll to bottom of seder list.
- Suspected: Curriculum seed data for Seder Taharos has a placeholder description string. Check Firestore seed or local asset.

### [P3] Wizard step count changes from 6→7 after curriculum selection
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: /tmp/device_e2e/5560/09_wizard_step0_back.png (Step 1 of 6) vs 10_wizard_step2_program.png (Step 2 of 7)
- What: Step 1 header reads "STEP 1 OF 6". After selecting משניות the next screen reads "STEP 2 OF 7". Total steps change mid-wizard from 6 to 7, which is confusing.
- Repro: Open Add Track wizard. Note "STEP 1 OF 6". Select any curriculum. Observe "STEP 2 OF 7".
- Suspected: Step count is computed lazily after curriculum selection; consider computing upfront or adjusting copy.

### [P3] Manage Profiles — avatar shows generic icon instead of initials
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: /tmp/device_e2e/5560/07_manage_profiles.png
- What: Profile list tiles in Manage Profiles show a generic blue person silhouette. Profile Picker correctly renders coloured circles with initials.
- Repro: Launch → Daniel → SETTINGS → Manage Profiles.
- Suspected: Profile list tile uses default CircleAvatar without the initials logic.

### [P2] Content Browse — browse text display has no "Mark complete" button
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: /tmp/device_e2e/5560/35_content_perek_alef.png (daily task) vs 35b_text_display_scrolled.png (browse path)
- What: When reaching a mishnah text via the daily-tasks path, "Mark complete" and "Next daily task" buttons appear at the bottom. When reaching the same mishnah via Browse Content (LEARN → Browse → curriculum → seder → masechta → perek), neither button appears — it is purely read-only. A user browsing ahead to preview content cannot mark it complete from browse. This may be intentional but is worth flagging as a UX gap: there is no affordance to mark something complete from the browse tree.
- Repro: LEARN → Browse → משניות → זרעים → ברכות → פרק א → observe no Mark Complete button.
- Suspected: The content display widget has two rendering modes (task mode vs. browse mode); browse mode intentionally omits the completion action. If intentional, consider whether a "Mark as learned" secondary action is desired here.

### [P2] Content Search — no results for English transliteration with no guidance
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: /tmp/device_e2e/5560/36b_content_search_typed.png
- What: Searching "berachot" returns "No results for 'berachot'" with no message indicating that Hebrew input is required. The search appears to match only Hebrew text. A user unfamiliar with Hebrew keyboard input gets a dead end with no guidance.
- Repro: LEARN → Browse → meshniots → tap Search icon → type "berachot" → observe "No results".
- Suspected: Search indexes only Hebrew text and does not support transliteration matching. An empty-results state should explain "Search in Hebrew (e.g., ברכות)" or the search should include transliteration mapping.

### [P3] Manage Tracks track card — accessibility label prefixes "0," before track name
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: (visible in label dump for screen 37_manage_tracks_populated)
- What: The track card's content-desc reads "0, משניות\nCompletion (with חזרה)\n0%". The "0," prefix is the ProgressBar widget's accessibility value (progress=0) prepended to the semantic label. Screen reader users would hear "0, Mishnayos, Completion..." which is confusing. Visual display is likely fine.
- Repro: Settings → Manage Tracks → observe track card accessibility label.
- Suspected: The ProgressBar widget merges its value semantics with the card's label. Override the semantic label on the ProgressBar to exclude the raw value, or wrap with a Semantics widget.

### [P2] Settings — Backup & Sync shows prominent "29 queued" warning on test device
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshot: /tmp/device_e2e/5560/42_settings_bottom_small.png
- What: The Backup & Sync row is visually highlighted in dark blue with text "Sync paused — 29 queued. Some changes are waiting to sync. We'll retry automatically." This is presumably a test-device artifact (network/auth issue), but the prominence of the warning (full-width coloured banner) is worth noting: in production this will be visible to real users any time sync is paused.
- Repro: Settings → scroll to bottom → observe Backup & Sync row.
- Suspected: Device-local sync issue. The visual treatment (dark banner) is a deliberate warning state — verify it dismisses once sync succeeds. Consider whether the error state needs a retry button for users who want manual resolution.

### [P1] PIN creation flow — "Set Parent PIN" loops after confirm; does not navigate to Parent hub
- Device: emulator-5560 (api34 pixel7, Android 14)
- Screenshots: /tmp/device_e2e/5560/p1_05_immediately_after_confirm_small.png (immediately after confirm), p1_07_after_back_small.png (back button fails), p1_13_relaunch_parental_flow_small.png (PIN persisted after relaunch)
- What (verified 2026-06-23): After entering the 4-digit confirm digit the screen immediately resets to "Set Parent PIN" step 1 with empty dots. Confirmed with immediate screenshot (400ms) — no animation delay. App bar badge changes to **"PARENT MODE"** (PIN was saved and session activated). The **PIN does persist** — force-stop + relaunch + re-enter child Settings shows the ENTER/verify flow, not SETUP.
- Recovery: **Back button** (both in-app ← and Android KEYCODE_BACK) — does NOT escape; re-shows Set PIN step 1. **Bottom nav tabs** — not visible on this route, tapping their coordinates does nothing. **PARENT MODE app bar badge** — DOES escape: opens the profile switcher bottom sheet, from which the user can dismiss and land back on Set PIN (still stuck), or switch profiles. No direct path to the Parent Settings hub from within the loop.
- **Verdict: CONFIRMED real trap.** The user cannot reach the Parent Settings hub after first-time PIN creation without force-killing the app. The PIN is saved correctly, but the post-confirm navigation is broken. Only escape is force-stop or switching to another profile, then re-entering the child's Parental Controls (which now shows the ENTER-PIN verify flow and works correctly).
- Repro: Any child profile with no PIN set → Settings → scroll → tap PARENTAL CONTROLS → enter 4 digits → enter same 4 digits to confirm → observe loop.
- Suspected: The PIN confirmation `onSuccess` callback calls `Navigator.pop()` once (returning to the confirm sub-step widget, which reinitialises to step 1) rather than `Navigator.popUntil` back to the Settings route or `pushReplacement` to Parent Settings. Check the PIN creation flow's `onConfirmSuccess` handler.

---

## Screens that look GOOD (no findings)

- **Profile Picker**: Card layout, mode badges, initials avatars, Add Profile, Skip to Settings — clean.
- **Dashboard (populated)**: Greeting, streak badge (LEARN tab), stats row, STATS card with OVERDUE/TODAY DUE circles, Today's Missions, Start Learning CTA, Active tracks carousel — all render correctly with data.
- **LEARN tab (populated)**: "Current Achievement 1 Day Streak" banner, Daily Tasks list with breadcrumb labels, Browse section with curriculum cards — clean.
- **Learning detail screen**: Full Hebrew text right-to-left, "Hebrew Text" chip, "English Translation" chip (Mishnah Bet+), Mark complete + Next daily task — functional and readable.
- **Settings root**: All sections (DEVICE, Shabbat MODE, PROFILE, preferences) — well-spaced and readable.
- **Track Detail**: Started/pace/elapsed stats card, progress card with items remaining and est. finish, action rows — clean.
- **Edit Goal**: Completion target slider, Deadline/Pace/No-deadline segment, pace stepper, per-day/per-week toggle, projected completion — all functional.
- **Study Days (track)**: All 7 days with Study/Review-only toggle, summary count — clean.
- **Content Browse hierarchy**: Curriculum → seder → masechta → perek → text — folder icons, breadcrumb chips, paging arrows — clean.
- **PIN entry dialog**: Modal overlay, 4-dot indicator, numpad with Cancel key — correct and clean.
- **Parent Settings hub**: 7 action rows (Manage Tracks, Goals, Point Config, Adjust Points, Reward Config, Pending Prizes, Add Lifetime Learning) — all visible, clean.
- **Reward Configuration**: Avatar picker, name field with placeholder, points field, live PREVIEW card, Save button — well designed.
- **Point Configuration (empty state)**: Helpful message explaining how to enable — clear.
- **RedeemKid child dashboard**: Correct empty state "Ask a grown-up to add a learning track." — appropriate child-mode copy.
- **Progress → Lifetime Knowledge**: Hebrew stat header, All sources/Track only filter, curriculum row with progress — clean.
- **Progress → Siyumim & Milestones**: Proper empty state with book icon — clean.

---

## Data state after audit

Track: **משניות** (all 6 sedarim, self-paced, 21/week)
Completions: **3 mishnayot** (Berachot 1:1, 1:2, 1:3) — preserved
Streak: **1 day** | Lifetime: **3 / 70,033 sections**
Parent PIN **2580** set on this device for PinKid.

---

## Summary

**37 screens audited. 8 findings total: 0 P0, 1 P1, 3 P2 (content/search/sync), 3 P2 (UX gaps), 3 P3.**

**Top 3 issues:**
1. **[P1] CONFIRMED real trap** — PIN creation confirm loops back to Set PIN step; back/nav tabs do not escape; user cannot reach Parent hub without force-killing. PIN itself saves correctly. Only workaround: force-stop → relaunch → re-enter child Settings → enter existing PIN.
2. **[P2]** Content Search returns no results for English transliteration (e.g., "berachot") with no guidance to use Hebrew input.
3. **[P2]** Browse text display has no "Mark complete" action — a UX gap vs. the daily-task path which shows the same text with completion buttons.

---

## Re-verify (fixed build)

Fixed build installed on emulator-5560. Re-verified 2026-06-23.

| Finding | Original | Result | Screenshot |
|---------|----------|--------|------------|
| F1 — Taharos gloss (P2) | "Core section focus" placeholder | **PASS — FIXED** | /tmp/device_e2e/5560/rv1_taharos_list_small.png |
| F2 — Manage Profiles avatar (P3) | Generic person silhouette | **PASS — FIXED** | /tmp/device_e2e/5560/rv2_manage_profiles_small.png |

**F1 detail:** טהרות row now shows a water-drop icon and subtitle "12 מסכת • Purity & Ritual Law". All 6 sedarim confirmed with proper real subtitles (Seeds & Agriculture / Festivals & Sabbaths / Women & Marriage / Damages & Civil Law / Temple Service & Sacrifices / Purity & Ritual Law).

**F2 detail:** All three profile tiles (R — RedeemKid, P — PinKid, D — Daniel) now render colored initials circles, consistent with the Profile Picker style.
