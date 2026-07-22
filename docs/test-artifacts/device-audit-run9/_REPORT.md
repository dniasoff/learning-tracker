# On-Device Audit — Run 9 Report

## Scope

- **Run:** 9 — exhaustive native-emulator fleet run; **first on-device test of the new brightness-aware palette / dark theme**.
- **Devices (6, real emulator processes, native Linux + KVM):** API 28 (Pixel 2, Android 9), API 29 (Pixel 3, Android 10), API 31 (Pixel 5, Android 12), API 33 (Pixel 6, Android 13), API 34 (Pixel 7, Android 14), API 36 (tablet 2560×1600, Android 16). 5 phone + 1 tablet, API 28 → 36.
- **Themes:** light **and** dark on every device (dark toggled via `cmd uimode night yes` / Display settings).
- **Locales:** English device locale on 5 devices (Hebrew present as curriculum/domain content); **device-locale Hebrew / RTL on the API 36 tablet (5564)** — see Residual Risk for the honest limits of RTL coverage.
- **Seed:** credential-less **offline account** recipe on all 6 devices (airplane mode → `pm clear` → Create Offline Account → profile → 7-step Add-Track wizard → populated Dashboard). 6/6 seeded profile+track successfully.
- **Build under test:** current `dev`, app **v1.0.66 (1)** — includes the theme migration `5f1e71f5` ("brightness-aware royal-blue design system", 140 files / 1330 call sites), the hero-fill follow-up `a68c97d5`, and all landed reassurance fixes. (Branch HEAD advanced to `06bbec35` during the run; no app-code changes to the audited surfaces.)
- **Verification:** all P0/P1 findings ran through an independent adversarial-verify pass (code inspection + live re-drive where the device survived). Verdicts applied below; `FALSE_POSITIVE` / `BY_DESIGN` / `ENVIRONMENT` findings are dropped from the confirmed set and listed separately.

---

## Executive Summary

**Gate verdict: FAIL** — driven entirely by dark mode. Light mode alone would be **CONCERNS**.

- **Seed/coverage:** 6/6 devices seeded profile+track offline; **151 screens** audited (36/18/22/26/26/23); app data survived every emulator-process death on every device.
- **Findings after verify (38 raw → 4 dropped → 34):** **P0 = 0, P1 = 10, P2 = 10, P3 = 14.** All 10 P1s are dark-mode legibility defects.
- **Dropped:** run-8 Learn "OOM" P0 → **ENVIRONMENT**; 5558 "Study Days switch dead" P1 → **FALSE_POSITIVE** (re-drive toggled it fine; auditor tapped a merged-semantics node centre); 5562 "Dashboard crash" P1 → **ENVIRONMENT** (its Crashlytics "proof" was benign `FlutterError` telemetry); 5562 "chrome never dark" P1 → **BY_DESIGN** (top bar only; see below).
- **Run-8 P0 (Learn OOM, API 29): NOT resolved, and NOT confirmed either.** The eager-load code path is verifiably **unpatched** — `content_index.dart:106-117` still materialises all 9 curricula (~70k items, keepAlive) and `learning_screen.dart:42` / `text_display_screen.dart:80` still watch it; R8 Part A/B never touched it. But on re-drive the Learn tab and reader **rendered cleanly once** (RSS ~370-410 MB) and the one fatal repro coincided with a fleet-wide host SwiftShader `RenderThread` segfault storm. Verdict: unproven residual risk, must be re-tested on `-gpu host` or real hardware before it can be closed.
- **Top issues:** (1) **cross-device, 6/6 devices** — hardcoded `Colors.white` card/sheet surfaces paired with dark-theme light ink → near-invisible text on Dashboard, Progress, Settings, Track Detail, Manage Tracks, Account sheet, Parent Settings; (2) bottom nav bar hardcoded `Colors.white` (`app_shell.dart:358`) missed by the palette migration — light bar on every dark screen, 3 devices; (3) hero fills washed out in dark (`blueMedium/blueLight/blueMid` missed by `a68c97d5`) with white numerals at **1.70:1** contrast; (4) "Upgrade to Cloud" CTA at **1.03:1** in dark; (5) data-correctness tail — siyum dates stamped `Jan 1, 2000`, "Track progress" reported as 0.1% vs 3% on different screens.

---

## Confirmed Findings (post-verify)

Verify column: `CONFIRMED` = independently re-verified (screenshots + source/root cause, live re-drive where possible); `—` = not selected for adversarial verify, stands as filed. `[X-DEV]` marks a defect class reproduced on more than one device.

### P0
None after verify. (The one raw P0 — run-8 Learn OOM on API 29 — was re-attributed to environment; see Dropped and Residual Risk.)

### P1 — all dark-mode legibility

| Sev | Device (API) | Theme | Screen | Issue | Verify |
|-----|--------------|-------|--------|-------|--------|
| P1 | 5558 (31) | dark | Track Detail, Dashboard, Settings, Manage Tracks, wizard steps 1/4/7 | **[X-DEV — white-surface cluster]** Card containers keep hardcoded `Colors.white` while their text uses theme-aware ink that correctly flips light → washed-out/illegible. Worst case Track Detail: *every* card incl. the whole action list. Wizard shows the inverse (light `ColoredBox(0xFFF4F5F7)` at `add_track_flow_screen.dart:740` + near-white headings). Root cause: `track_detail_screen.dart:386,633`, `track_info_card.dart:164`, `learning_track_card.dart:93`, `user_profile_header_card.dart:252`, `progress_tier_counter_row.dart:180`. Counter-proof that theming works: Edit Goal / Study Days / Delete dialog are fully compliant. | **CONFIRMED** |
| P1 | 5562 (33) | dark | Settings root, App Permissions, Notification Settings, Account bottom sheet | **[X-DEV — white-surface cluster]** ≥5 independent widgets hardcode white: `sacred_time_settings_card.dart:77`, `user_profile_header_card.dart:252/287`, `permission_prompt_screen.dart:224`, `device_notification_toggle.dart` Card, `account_actions_sheet.dart:96`. "Switch account"/"Add account"/"Device notifications" render near-invisible; destructive rows stay legible only because red/orange happens to contrast on white. All five files were touched by `5f1e71f5` — a real migration gap, no dark-mode test guards them. | **CONFIRMED** |
| P1 | 5560 (34) | dark | Progress tab, Parent Settings hub, Reward Configuration, Recent Activity | **[X-DEV — white-surface cluster]** Two mirror-image variants: white card + theme-aware light title (`progress_screen.dart:159-198`, `user_profile_header_card.dart:251-306`), **and** theme-aware dark card + hardcoded `Colors.black` / `0xFF1A1F2F` text (`reward_configuration_screen.dart:346-374`, `recent_activity_screen.dart:320,498`). Subtitles stay legible; only headings/stat numerals vanish. | **CONFIRMED** |
| P1 | 5556 (29) | dark | Progress tab, Settings tab (incl. Shabbos-mode card body) | **[X-DEV — white-surface cluster]** `_LensTile` / `_PerTrackRow` (`progress_screen.dart:159,341`) and `sacred_time_settings_card.dart:77` hardcode white; titles inherit `brandInk` = `0xFFEAEEF5` in dark. Sibling cards using `colorScheme.surface` invert correctly, isolating the differentiator to the literal. | **CONFIRMED** |
| P1 | 5554 (28) | dark | Settings account card + its "Account" bottom sheet | **[X-DEV — white-surface cluster]** Measured **~1.07:1** contrast on "Switch account" (darkest glyph `RGB(234,238,245)` on pure white). `account_actions_sheet.dart:96` `Material(color: Colors.white)`; `user_profile_header_card.dart:252` kept `Colors.white` while `5f1e71f5` migrated its border/shadow on adjacent lines. The *other* Account sheet (`profile_switcher_sheet.dart:65`, `brandCreamCard`) is correct — two implementations, one migrated. | **CONFIRMED** |
| P1 | 5564 (36, tablet) | dark | Dashboard stat cards, Settings profile card, Manage Tracks track card | **[X-DEV — white-surface cluster]** `stat_card.dart:75`, `learning_track_card.dart:93`, `user_profile_header_card.dart:252/287` — all `Colors.white`, all touched-but-missed by `5f1e71f5`. Existing guard `aud_core_widgets_03_no_color_literals_test.dart` only greps `Color(0x…)` hex, so a named `Colors.white` slips through CI. | **CONFIRMED** |
| P1 | 5554 (28) · 5564 (36) · [5562 (33) same claim → BY_DESIGN] | dark | Global scaffold — bottom navigation bar | **[X-DEV]** Bottom nav `DecoratedBox` hardcodes `Colors.white` (`app_shell.dart:358`) while its *siblings* in the same diff hunk (`navBarShadow`, `navSelectedBlue`, `navUnselectedText`) were all migrated to brightness-aware tokens by `5f1e71f5` — so the dark-resolved pale-pastel selected pill and grey text now sit on a stubbornly white bar. **Scope note:** the accompanying *top* app bar is **excluded** — it is deliberately pinned light (`app_shell.dart:291-297`, "Bug 7", commit `5f182dd3`) and test-enforced (`app_shell_test.dart` ~L1210). Fixing the top bar would reintroduce a prior dark-on-dark regression. | **CONFIRMED** (bottom nav only) |
| P1 | 5564 (36, tablet) | dark | Dashboard "סטטיסטיקה" hero card | **[X-DEV — hero-fill cluster]** Card lightens from `rgb(50,82,180)` → `rgb(185,198,235)` in dark: `blueMedium/blueLight/blueMid` were **missed by `a68c97d5`**, which pinned 17 sibling hero tokens. Compounded by hardcoded `Colors.white` numerals (`dashboard_level_points_card.dart:81-101`) → **1.70:1** for "היום"/"איחור" (AA needs 4.5:1), while the theme-aware `goldTrophy` numeral reads 8.33:1 — three numerals, inconsistent, two unreadable. | **CONFIRMED** |
| P1 | 5562 (33) | dark | Settings → Backup & Sync → "Upgrade to Cloud" CTA | `backup_sync_section.dart` (3 call sites): `5f1e71f5` migrated `backgroundColor` to the brightness-aware `peachMid` (dark = `0xFF332613`) but left `foregroundColor: const Color(0xFF2C2A26)` hardcoded → **1.03:1** in dark (10.07:1 in light). The monetization/backup CTA is effectively invisible. `peachMid` is absent from the 82-case `app_palette_test.dart` contrast roles. | **CONFIRMED** |
| P1 | 5554 (28) | dark | Settings tab account card (name text) | White-on-white account name `AuthQA` — both text and card sampled at ~`RGB(255,255,255)`. Same root cause as the 5554 sheet row above; kept separate because it is a distinct surface (`_SettingsProfileSurface`). | **CONFIRMED** |

### P2

| Sev | Device (API) | Theme | Screen | Issue | Verify |
|-----|--------------|-------|--------|-------|--------|
| P2 | 5554 (28) | dark | Dashboard STATS hero card | **[X-DEV — hero-fill cluster]** Deep navy in light → washed light-lavender in dark (sampled `175,190,232`), while the LEARN tab's sibling achievement card correctly stays deep (`28,66,181`). Same missed `blueMedium/blueLight/blueMid` tokens as the 5564 P1. | — |
| P2 | 5560 (34) | both | Progress → Siyumim & Milestones | Sections bulk-marked today (2026-07-22) via "Mark Prior Learning" record their siyum date as **`Jan 1, 2000`**, and Timeline groups them under "Jan 2000". Sentinel/placeholder date reaching a celebratory user-facing surface. | — |
| P2 | 5560 (34) | both | Progress summary vs Curriculum Progress vs Track Detail | Same track, same-named metric, **two values**: "Track progress: 0.1%" on Progress tab + Track Detail, but **3%** under the identical label "Track progress" on Curriculum Progress — which appears to be mislabelling the "Completion (with חזרה)" value. ~30× discrepancy; identical in light and dark, so a data/label bug not a theming artifact. | — |
| P2 | 5554 (28) | light+dark | Settings → Add account → Create Account / Log In | The "You're online — back up your account" reconnect banner (correct on Dashboard/Learn/Settings) also renders inside the nested *add-another-account* flow, where its CTA refers to the currently-active account and would divert the user out of the flow. | — |
| P2 | 5554 (28) | dark | Add Profile dialog | Child Mode / Adult Mode selector cards stay hardcoded white inside a correctly-dark dialog; unselected "Child Mode" label is light-grey-on-off-white. Same white-surface family. | — |
| P2 | 5562 (33) | light | Settings → Manage Tracks → Track Detail | Status-bar icons (clock/gear/warning/airplane/battery) render **white on the screen's near-white background** — illegible. Scoped to this one route (Edit Track from the same place is fine); looks like a `SystemUiOverlayStyle` brightness mismatch. | — |
| P2 | 5562 (33) | dark | Settings → App Permissions (after cold app start) | Shows the not-granted "Allow" state for Notifications although `dumpsys` confirms `POST_NOTIFICATIONS granted=true`; tapping Allow (an OS no-op) corrects the display. Permission state isn't re-evaluated on first load after an abnormal restart. | — |
| P2 | 5564 (36, tablet) | light | Add-Track wizard step 4 (ימי לימוד) | Day-toggle thumb sits at the **identical position** in on and off states (only track saturation changes) — likely a physical `Alignment.centerLeft` instead of `AlignmentDirectional.centerStart`, so it never mirrors for RTL. The native switch elsewhere (Settings "אני בישראל") mirrors correctly. | — |
| P2 | 5564 (36, tablet) | dark | Manage Tracks — per-track progress bar | A **0%** bar renders almost fully filled dark in dark mode (thin light sliver at one edge) vs correctly empty in light — tells the user the opposite of the truth for a brand-new track. | — |
| P2 | 5564 (36, tablet) | light | Add-Track wizard step 7 (סימון לימוד קודם) | **[X-DEV — chevron cluster]** Step-7 rows and its breadcrumb use un-mirrored right-pointing `›` while every other drill-in row/breadcrumb in the RTL app correctly uses `‹`. The recent chevron-mirroring fix missed this widget. | — |

### P3

| Sev | Device (API) | Theme | Screen | Issue | Verify |
|-----|--------------|-------|--------|-------|--------|
| P3 | 5558 (31) | light | Track Detail → Edit Goal (Pace) | Pace = 0 produces "Projected completion … in ~29,344 days" (~80 yrs) with no inline validation message. Submit *is* correctly disabled, so cosmetic/UX only. (Run-8 logged the same class at ~14,672 days — unfixed.) | — |
| P3 | 5558 (31) | light | Add-Track wizard step 1/3 vs step 7 | **[X-DEV — chevron cluster]** Right-pointing chevron for drill-in on steps 1/3 vs left-pointing for the identical action on step 7. | — |
| P3 | 5554 (28) | light | Add-Track wizard step 1 vs step 7 | **[X-DEV — chevron cluster]** Same step-1/step-7 row-layout + chevron inconsistency in the LTR shell. | — |
| P3 | 5560 (34) | light | Add-Track wizard step 7 breadcrumb | **[X-DEV — chevron cluster]** Onboarding breadcrumb renders `משניות > זרעים` LTR with an un-mirrored `>`, whereas Daily Tasks / Task Detail breadcrumbs for the same curriculum mirror correctly — suggests a manually-ordered `Row` rather than one bidi-aware `Text`. | — |
| P3 | 5558 (31) | light | Track Detail → Delete Track | Deletion executes immediately from the first dialog's red "Delete and wipe history" option — no secondary irreversibility confirmation. Arguably sufficient as-is; filed as a suggestion. | — |
| P3 | 5556 (29) | light | Dashboard (scrolled) | חזרה review card shows the word חזרה duplicated (eyebrow + title) next to a 0 count. Pre-existing, accepted in run-8, **still present** after the theme migration. | — |
| P3 | 5556 (29) | dark | Progress → Lifetime Knowledge → "Add items I learned previously" | 3 taps in-bounds produced no navigation; UI dump shows a plain `android.view.View`, not a Button node. The same destination reached from Settings worked in light minutes earlier. **Low confidence** — not isolated between theme / timing / genuine dead target. | — |
| P3 | 5554 (28) | light | Account Picker, immediately after Sign Out | First tap on the "Offline account" row did not register (unchanged after 2.5 s); second tap at the same coordinates worked; a later cycle worked first-time. **Low confidence / possibly transient.** | — |
| P3 | 5554 (28) | light | Intro carousel slide 2 ("Never Forget a Mishnah") | Two decorative chips clip mid-word — "Review…" / "…yos" — on the smallest device in the fleet. Decorative only, but on a first-impression screen. | — |
| P3 | 5554 (28) | light+dark | Sign In / Register / Upgrade to Cloud / Create Account cards | Decorative rectangle peeks from behind each auth card's top-right corner; a faint grey sliver in light, a **bright white wedge** against all-dark surroundings in dark (sampled `233,234,242`) — another hardcoded-light survivor. | — |
| P3 | 5562 (33) | light | Settings → Shabbos Mode → "Detect" | Offline, Detect spins then silently reverts with no toast/inline error. Plausibly acceptable (needs connectivity/GPS) but flagged for intent confirmation rather than assumed. | — |
| P3 | 5562 (33) | light | Settings footer | Three unlabeled glyphs (triangle / speech-bubble / star) below the version string are inert on tap and carry no content-description. | — |
| P3 | 5562 (33) | light | Dashboard / Settings, offline | No persistent "offline" banner inside the app (only the "No Backup" pill), although pre-auth screens do show explicit offline messaging. Possibly by design for an offline-first app; flagged for confirmation. | — |
| P3 | 5564 (36, tablet) | light | Onboarding auth card / "What brings you here?" / wizard step 6 | Large unused whitespace on the 2560 px canvas — narrow phone-width layouts not reflowed for tablet. Possibly by design; worth a design sign-off. | — |

### Dropped by verify (not counted above)

| Raw sev | Device (API) | Claim | Verdict | Why |
|---------|--------------|-------|---------|-----|
| ~~P0~~ | 5556 (29) | "Learn pillar still OOM-kills the ENTIRE emulator process (run-8 P0 not fixed)" | **ENVIRONMENT** | Code premise verified: `content_index.dart:106-117` still eager-loads all 9 curricula, watched by `learning_screen.dart:42` + `text_display_screen.dart:80`; R8 Parts A/B never touched it. But re-drive #1 rendered Learn *and* the reader cleanly (RSS ~370-410 MB, `MemAvailable` 764→522 MB); re-drive #2 died with **6 simultaneous host `RenderThread` segfaults** matching ~40+ identical fleet-wide events across all 5 emulators every 1-3 min, and **zero** lowmemorykiller/OOM messages. Same confound run-8 already documented. Not closable as fixed — see Residual Risk. |
| ~~P1~~ | 5558 (31) | "Study Days boolean Switch is completely non-functional in wizard + Edit Track" | **FALSE_POSITIVE** | Re-drive flipped Sunday/Monday instantly in both entry points and both themes; the dedicated Study Days screen then read "5 study days per week" with both marked Review-only — the exact opposite of the claim's persistence evidence. Cause of the mis-report: on the wizard step, Flutter merges the row label into the Switch's semantics node, so the reported node's *centre* is the label, not the control. (Existing widget tests `tracks_studydays_and_content_hierarchy_l1_test.dart` pass.) |
| ~~P1~~ | 5562 (33) | "Reaching Dashboard after a full-scope track crashes the app (Crashlytics fatal proof)" | **ENVIRONMENT** | The six `crash_reported, fatal:true` analytics lines are each immediately followed by a benign Flutter `ListTile background color…` layout diagnostic — one per the 6 sedarim tiles in the *wizard scope step*, on a live PID that kept emitting frame stats for 3+ s. `crashlytics_bootstrap.dart:26-29` routes every `FlutterError` through `recordFlutterFatalError`, so warnings self-report as fatal. Zero `FATAL EXCEPTION` / SIGSEGV / ANR / tombstone in 8000 log lines. Device loss is real; attribution to the Dashboard is not. (The mis-classifying telemetry wiring is itself a separate low-severity nit.) |
| ~~P1~~ | 5562 (33) | "App chrome (top bar + bottom nav) never switches to dark theme" | **BY_DESIGN** (top bar) | The top switcher bar is deliberately wrapped in `Theme(data: AppTheme.lightTheme())` (`app_shell.dart:291-297`, commit `5f182dd3`, "Bug 7") and locked by a passing test asserting `0xFFF1F3FA` under dark ambient. The **bottom-nav half of the same observation is retained** as a P1 above; only the top-bar claim is dropped. Whether permanently-light chrome is still the right product call now that a real dark theme exists is a design question, not a QA defect. |

### Cross-device vs device-specific

- **White-surface / brightness-blind literal cluster — 6/6 devices, ~15 distinct widgets.** The dominant theme of this run. One shared root cause (raw `Colors.white` / `Colors.black` / hex literals surviving the `5f1e71f5` migration, which only rewrote `AppColors.*`/`AppTheme.*` references), two symptom shapes: light card + dark-theme light ink, and dark card + hardcoded dark ink. Named files: `stat_card.dart:75`, `learning_track_card.dart:93`, `user_profile_header_card.dart:252,287`, `account_actions_sheet.dart:96`, `sacred_time_settings_card.dart:77`, `permission_prompt_screen.dart:224`, `device_notification_toggle.dart`, `progress_screen.dart:159,341`, `progress_tier_counter_row.dart:180`, `track_detail_screen.dart:386,633`, `track_info_card.dart:164`, `add_track_flow_screen.dart:740`, `reward_configuration_screen.dart:346-374`, `recent_activity_screen.dart:320,498`, `dashboard_level_points_card.dart:81-101`.
- **Hero-fill cluster — 5554 (P2) + 5564 (P1).** `blueMedium/blueLight/blueMid` missed by `a68c97d5`'s 17-token sweep.
- **Chevron / RTL mirroring cluster — 5554, 5558, 5560 (P3) + 5564 (P2).** Same wizard step-7 widget on 4 devices, in both LTR and RTL shells; run-8 logged it too.
- **Bottom-nav white bar — 5554, 5562, 5564.**
- **Emulator-process death — all 6 devices** (5564 ≥16 times, 5560 10 times, 5562 4, 5558 4). Host load hit ~65 on 24 cores with 5-6 SwiftShader emulators. Classified environment, not app; app data survived 100% of them.
- **Device-specific:** Upgrade-to-Cloud CTA contrast (5562), siyum sentinel date + track-progress mismatch (5560), status-bar overlay style (5562), 0%-bar inversion + day-toggle thumb (5564), reconnect-banner leak + carousel clipping (5554).

---

## Dark Mode — First On-Device Pass of the New Palette

The brightness-aware palette (`5f1e71f5`, +`a68c97d5`) had **zero prior device coverage**; this run is its first. Verdict for the dark surface in isolation: **FAIL**.

**Numbers.** 10 of 10 confirmed P1s are dark-mode-only. Add the dark P2/P3 tail (5554 STATS hero, 5554 Add Profile cards, 5554 auth-corner wedge, 5562 permissions staleness, 5564 progress-bar inversion, 5556 dead tap) and dark accounts for **16 of 34** confirmed findings, on **6/6 devices** and every core screen (Dashboard, Learn, Progress, Settings, Track Detail, Manage Tracks, Parent Settings, Reward Config, Account sheets, the Add-Track wizard).

**The mechanism is one bug repeated, not a broken theme.** `app_theme.dart` correctly drives `CardThemeData` / `Scaffold` / `Dialog` from the brightness-aware `AppPalette`; Edit Goal, the dedicated Study Days screen, the Delete Track dialog, Lifetime Knowledge detail and the App Permissions row are all fully compliant with good contrast. Every failure is a *local* colour literal bypassing that machinery. Measured worst cases: **1.03:1** (Upgrade-to-Cloud CTA), **1.07:1** (Switch account), **1.70:1** (Dashboard hero numerals) — against a 4.5:1 AA floor.

**Why CI didn't catch it.** Three independent gaps: (a) the migration rewrote `AppColors.*`/`AppTheme.*` symbols, so raw `Colors.white`/`Colors.black` were structurally invisible to it; (b) the audit guard `aud_core_widgets_03_no_color_literals_test.dart` greps only `Color(0x…)` hex, so named `Colors.*` constants pass; (c) the new 82-case `app_palette_test.dart` checks palette *roles* against each other and never sees a background hardcoded at a call site (`peachMid` isn't even a role). No widget/golden test asserts dark-mode appearance for any of the ~15 affected widgets.

**Recommended shape of the fix** (not applied — this is an audit): one sweep replacing raw `Colors.white`/`Colors.black`/hex surface+ink literals with `context.colors.*` tokens across the 15 files listed above; add `blueMedium/blueLight/blueMid` to the `a68c97d5` deep-hero pin list and `peachMid` (+ its paired foreground) to the contrast-role table; widen the literal-grep guard from `Color(0x…)` to `Colors.<name>` in decoration/`Material`/`Card` colour positions. **Explicitly out of scope:** the top switcher bar (`app_shell.dart:291-297`) — leave it pinned light unless "Bug 7" is deliberately revisited.

---

## Per-Device Coverage

| Device | API | Form | Locale | Seeded | Themes | Screens | Findings (raw) | After verify |
|--------|-----|------|--------|--------|--------|---------|----------------|--------------|
| emulator-5554 (Pixel 2) | 28 (Android 9) | phone | en | profile+track | light+dark | 36 | 9 | 9 (0 dropped) |
| emulator-5556 (Pixel 3) | 29 (Android 10) | phone | en | profile+track | light + partial dark | 18 | 4 | 3 (1 P0 → ENVIRONMENT) |
| emulator-5558 (Pixel 5) | 31 (Android 12) | phone | en | profile+track | light+dark | 22 | 5 | 4 (1 P1 → FALSE_POSITIVE) |
| emulator-5560 (Pixel 7) | 34 (Android 14) | phone | en | profile+track | light+dark | 26 | 4 | 4 (0 dropped) |
| emulator-5562 (Pixel 6) | 33 (Android 13) | phone | en | profile+track | light+dark | 26 | 9 | 7 (1 ENVIRONMENT, 1 BY_DESIGN) |
| emulator-5564 (tablet) | 36 (Android 16) | tablet 2560×1600 | **he / RTL** | profile+track | light + partial dark | 23 | 7 | 7 (0 dropped) |
| **Total** | 28–36 | 5 phone + 1 tablet | 5 en + 1 he | **6/6** | — | **151** | **38** | **34** |

**Depth highlights.** 5554: full onboarding incl. both profile modes, 7-step wizard, sign-out/re-entry, account picker, offline↔online gating both directions. 5558: wizard walked **twice** with deliberate variation, reorder-content via real drag-and-drop, Edit Goal in all 3 modes, delete-track guardrail cancelled *and* executed. 5560: **full gamification loop verified end-to-end with correct arithmetic** (points 0→50→0, redeem → pending → fulfil) plus two positive regression confirmations — the **PIN keypad fast-tap fix PASSES** (~50 ms taps, 4 prompts, zero drops; run-8 P3 closed) and **Recent Activity "All Time" now counts bulk-marks correctly** (129 = 126 bulk + 3 live; run-8 P2 closed, header matches per-curriculum row). 5562: settings breadth incl. permissions, city search, Shabbos mode, notification settings, profile management, child mode + PIN, with settings and theme choice surviving a hard crash/restart. 5564: RTL verified as an explicit **PASS** (reader pager arrow direction, back-arrow mirroring, right-to-left progress fill, correct bidi in "1 + 7 ימים"), no raw l10n keys, no tofu, no English leakage.

---

## Residual Risk

Stated honestly — this run is broad, not complete.

1. **Run-8 P0 is unresolved and unproven in both directions.** The unbounded eager load in `contentIndexProvider` is real, unpatched, and costs ~150-250 MB per activation on 512 MB-2 GB-class devices — non-trivial headroom, but it did not tip over in a clean re-drive. It **cannot be closed** on this run's evidence. Required: re-test Learn / TextDisplay / Content Hierarchy / Search on `-gpu host` or real hardware, plus a constrained-heap automated device test to pin the regression below this rung.
2. **The Learn pillar is still effectively unaudited on API 29.** Learn tab, text reader, Content Hierarchy and Content Search were never reached in either theme on 5556; Learn/reader/Progress in **dark** were never captured on 5564 either. That is the single largest coverage hole, and it is the same hole run-8 left.
3. **Crash attribution is confounded fleet-wide.** 5-6 SwiftShader emulators on a 24-core host produced continuous `RenderThread` segfaults (~every 1-3 min) and >35 process deaths this session. Two claimed app crashes dissolved on inspection; a third unexplained full-VM death on 5556 during benign navigation was never explained. We cannot currently distinguish a genuine app-side memory/render fault from host noise on this fleet — the documented `-gpu host` configuration must be restored before crash findings from emulators are trustworthy.
4. **Dark-mode coverage is inferential in places.** The white-surface and chrome defects were directly screenshotted on 3-6 unrelated screens per device; screens sharing the same scaffold that were *not* captured in dark (Learn, reader, Progress on 5564; the intro carousel and pre-onboarding auth screens on 5554) almost certainly inherit them, but that is inference. Assume the confirmed count is a **floor**, not a ceiling.
5. **RTL/Hebrew rests on one device.** Only 5564 ran a Hebrew device locale, and it was the least stable machine in the fleet (16 re-seeds). The other five ran English chrome with Hebrew content only, so app-level `Directionality` behaviour outside 5564 is untested — most "correct RTL" seen elsewhere was automatic Unicode bidi.
6. **Flows deliberately not executed:** Delete Account; Google Sign-Up/Sign-In; completing Upgrade to Cloud end-to-end (one-way + destructive to the offline state); actual delivery of a scheduled notification (no offline clock-advance); Firebase-side verification of "Send Diagnostic Logs".
7. **Not reached for time / crash recovery:** Adjust Points and Manage Goals under Parent Settings; the Decline path for a pending prize; multiple simultaneous rewards; the profile-picker dropdown on 5564; "Add another track" from Manage Tracks on 5564.
8. **Two low-confidence P3s are unisolated** (5556 dead tap in dark, 5554 first-tap-after-sign-out) — each observed once and not reproduced; do not treat either as characterised.
9. **Open product question:** no post-creation editor for the חזרה (spaced-repetition) cadence was found anywhere — it is configurable only at wizard step 5. The brief implied a distinct "Scheduler" screen; none exists under Track Detail. Needs a product answer, not a bug fix.
10. **Two by-design calls worth a product review, not a fix:** permanently-light top chrome now that a real dark theme exists, and `crashlytics_bootstrap.dart` classifying every `FlutterError` — including benign layout warnings — as `fatal: true`, which actively corrupts crash telemetry and misled this audit.
11. **This rung is still manual.** No CI harness executes these device flows; all 151 screens were driven by per-device agents. Every finding above is a one-shot observation, not a repeatable check.

---

*Artifacts: per-device screenshots live on local disk under `/tmp/device_e2e/<port>/` and are not committed. Only `findings_5556.md` was written to this directory during the run — the other five device agents were blocked from writing report files by harness policy and returned their findings as text, which is aggregated here.*
