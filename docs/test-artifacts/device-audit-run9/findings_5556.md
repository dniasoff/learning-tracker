# Device Audit — run-9 — emulator-5556 (lt_api29_pixel3, Android 10 / API 29)

**Slice:** Learning + Content Browsing, with mandatory re-test of the run-8 P0 (Learn-surface OOM).
**Seed:** offline account, adult profile "LearnQA", one self-paced track (משניות, all 6 sedarim, 1+7 days chazara).
**Artifacts:** screenshots in `/tmp/device_e2e/5556/` (not checked in; referenced here by filename).

## Bottom line

**The run-8 P0 is NOT fixed.** Entering the Learn pillar (via Dashboard's "Start Learning" button, or directly via the LEARN tab) still kills the entire emulator process within 1–2 seconds, reproduced twice with full logcat evidence. "Part A" of the prior fix (commit `121d289b`) patched the progress/lifetime-aggregate call sites but left a second, independent eager-load-all-9-curricula call site untouched (`contentIndexProvider`), which both the Learn screen and the Hebrew text reader unconditionally depend on. As a direct consequence, Content Hierarchy, Content Search, and the Learning/TextDisplay reader — the majority of this audit's assigned slice — are **unreachable** via any live navigation path in the shipped app on this device.

A new P1 dark-mode contrast defect was also found and is documented below, alongside a positive regression check (the run-8 aggregation-rollup P2 is now fixed).

## Screens audited

| # | Screen | Theme | Result |
|---|--------|-------|--------|
| 1 | Onboarding intro ("Your Daily Torah Plan") | Light | PASS |
| 2 | Sign-in ("Get Started", offline banner) | Light | PASS |
| 3 | Create Account (offline path) | Light | PASS |
| 4 | Profile setup (name, Adult Mode, nikud/calendar/terms) | Light | PASS |
| 5 | "What brings you here?" | Light | PASS |
| 6 | Add-Track wizard steps 1–7 (curriculum → program → scope → days → chazara → pace → prior-learning) | Light | PASS |
| 7 | "Track Ready!" screen | Light | PASS |
| 8 | Dashboard (header, stat cards, STATS bar, Today's Missions) | Light + Dark | PASS (light); dark: see F2 (white stat cards unaffected, contrast fine) |
| 9 | Dashboard scrolled (Start Learning, חזרה card, URGENT card, Active Tracks) | Light + Dark | ISSUES — see F4 (חזרה duplicate, pre-existing) |
| 10 | **LEARN tab / "Start Learning"** | Light | **P0 CRASH — see F1** |
| 11 | Progress tab | Light + Dark | ISSUES (dark) — see F2 |
| 12 | Lifetime Knowledge detail screen | Light + Dark | PASS — rollup fixed, see F3 |
| 13 | Settings (Device/Profile/Calendar/Backup sections) | Light + Dark | ISSUES (dark) — see F2 |
| 14 | Add Lifetime Learning → scope selection: seder → masechta → perek → leaf (4 hierarchy levels) | Light | PASS — safe substitute for the blocked Content Hierarchy screen |
| 15 | Mark 3 leaves as lifetime-learned + Save confirmation | Light | PASS |
| 16 | Dashboard / Progress / Lifetime Knowledge rollup after marking 3 items | Light + Dark | PASS — see F3 |
| 17 | System Settings → Display → Dark theme toggle | N/A (OS) | Needed to actually enable dark mode — see Notes |
| 18 | Lifetime Knowledge → "Add items I learned previously" card | Dark | ISSUES (minor) — see F5 |
| — | **Learning/TextDisplay reader (Hebrew text, nikud, font size, prev/next, Mark Complete)** | — | **UNREACHABLE — blocked by F1** |
| — | **Content Hierarchy screen (dedicated `ContentHierarchyScreen`)** | — | **UNREACHABLE — blocked by F1** |
| — | **Content Search screen** | — | **UNREACHABLE — only reachable from Content Hierarchy, itself unreachable** |

---

## F1 — P0 (CONFIRMED, cross-references run-8) — Learn pillar still OOM-kills the whole emulator process

**Screen:** Dashboard "Start Learning" button / LEARN tab. **Theme:** Light (see note below on dark).

Tapping "Start Learning" from the post-onboarding "Track Ready!" screen, and separately tapping the "LEARN" tab from the Dashboard, **both** killed the entire emulator guest — not just the app process — within 1–2 seconds. `adb devices` stopped listing `emulator-5556` and the underlying `qemu-system-x86_64 -port 5556` process vanished from `ps aux` on the host entirely. Reproduced **2/2**. Host RAM was never under pressure (47–93 GB free throughout the session), ruling out host contention as the cause.

Captured a live `adb logcat` stream through the second repro. In the ~1 second between tapping LEARN and the guest dying, the log shows Riverpod sequentially materializing full content for 8 of the 9 curricula (mishnayos already warm from onboarding, so no reload needed for it):

```
curriculumContentProvider(CurriculumId.chumash) updated
curriculumContentProvider(CurriculumId.nach) updated
curriculumContentProvider(CurriculumId.tanach) updated
curriculumContentProvider(CurriculumId.bavli) updated
curriculumContentProvider(CurriculumId.yerushalmi) updated
curriculumContentProvider(CurriculumId.mishnehTorah) updated
curriculumContentProvider(CurriculumId.mishnaBerurah) updated
curriculumContentProvider(CurriculumId.mussar) updated
```
...followed immediately by the log stream simply stopping mid-frame (last line is an unrelated system `ipwf` warning) — no Dart exception, no ANR, no tombstone, exactly matching run-8's description.

**Root cause (read-only inspection, no code changed):**
- `learning_tracker/lib/core/content/content_index.dart:106-117` — `contentIndexProvider` (`@Riverpod(keepAlive: true)`) loops over `CurriculumId.all` and `await`s `curriculumContentProvider(c).future` for **every** curriculum, permanently caching all ~70,033 `ContentItem`s across all 9 curricula. This is the exact eager-load-everything pattern run-8 identified as the OOM trigger.
- `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:42` — `LearningScreen.build()` (the LEARN tab) unconditionally does `ref.watch(contentIndexProvider)` on every build, for daf-grouping purposes.
- `learning_tracker/lib/features/content_browsing/presentation/screens/text_display_screen.dart:80` — the Hebrew text reader **independently** does the same `ref.watch(contentIndexProvider)`, so even if Learn's crash were fixed, opening any individual text/mishnah would trigger the identical OOM.

Commit `121d289b` ("fix(progress): R8 OOM — stop force-loading all 9 curricula in progress aggregates", "Part A") only reordered `computeItemsLearnedSummary`/`computeLifetimeViewSummary` in `items_learned_providers.dart` / `lifetime_knowledge_providers.dart` — a **different** call site than `contentIndexProvider`. That fix is real and correct for what it covers (see F3), but it did not touch the Learn-tab/TextDisplay dependency, so the P0 remains live via this second path.

**Impact — this is why almost none of this audit's assigned "Learning" screens could be walked:**
- Learning/TextDisplay reader (Hebrew text, nikud toggle, font size, prev/next nav, Mark Complete) — unreachable; its own code path also crashes.
- Content Hierarchy screen — unreachable. Its only two live entry points are (a) the LEARN tab's "Browse all curricula" section, which never renders because the LEARN screen crashes before building it, and (b) the Dashboard's Active Track Card fallback, which only fires when there is **no** task due today — this profile always had 3 tasks due, so the card instead routes to the crashing TextDisplay screen (`active_track_card.dart:196`, "prefer the current-focus text when there is one").
- Content Search screen — unreachable, since it's only linked from within the Content Hierarchy screen.

**Substitute coverage used instead:** Settings → "Add Lifetime Learning" reaches `scope_selection_screen.dart`, which renders the identical curriculum → seder → masechta → perek → leaf hierarchy (safe, because it only loads the ONE curriculum being browsed, not all 9). I walked all 4 levels for משניות (`24_scope_mishnayos_light.png` → `27_scope_perek1_light.png`) and used it to mark 3 leaves as lifetime-learned as a substitute for "Mark Complete" (see F3). This is a legitimate app screen and gives partial content-browsing confidence, but it is **not** a substitute for verifying the actual Learn/TextDisplay/Content-Hierarchy/Search screens.

**Screenshots:** `14_dashboard.png` (Start Learning button, pre-crash) → `15_CRASH_after_start_learning.png` (empty — screencap failed, guest already gone) → `16_after_reboot_relaunch.png` (Dashboard after emulator relaunch, data survived). Live capture: `/tmp/device_e2e/5556/logcat_stream.txt`.

**Note on dark mode:** both crash repros happened before dark mode was successfully enabled on this device (see Notes below on the uimode friction). Given the root cause is a memory/data-loading issue with no rendering component, it is highly likely to reproduce identically in dark theme, but I did not re-trigger the crash a third time to explicitly confirm this, to avoid burning more of the session on repeated ~2-minute emulator relaunches once the mechanism was already confirmed twice with full log evidence.

---

## F2 — P1 (CONFIRMED) — Systemic dark-mode contrast failure: card titles render near-invisible on white/cream cards

**Screens:** Progress tab, Settings tab. **Theme:** Dark only (not present in light).

Once dark mode was actually active (device dark theme toggle — see Notes), several list-row/summary cards kept a **white or cream background** while their **title/primary-label text** rendered in the dark-theme's light/pale color — producing near-invisible, low-contrast text. The **subtitle/body text on the same cards** renders in a normal, theme-invariant medium gray and stays perfectly readable, so this isn't a wholesale card failure — it's specifically the title/label text color that's wrong for a card that stayed light.

Confirmed instances:
- **Progress tab** (`41_progress_dark.png`): "Recent Activity", "Siyumim & Milestones", and "Lifetime Knowledge" nav-card titles are washed-out pale lavender-white on white cards (subtitles like "Completions, trends, and more" are fine). Zoomed crop: `41_crop_recent_activity.png`.
- **Progress tab, Active Tracks card:** the track name "משניות" is similarly washed out; "Track progress: 0% Lifetime: 0%" beneath it is fine. Crop: `41_crop_track_name.png`.
- **Settings tab** (`45_settings_dark_retry.png`): the profile card's "LearnQA" name is washed out (crop: `45_crop_profile_card.png`); inside the שבת MODE card's white body, "No location set" is washed out (crop: `45_crop_shabbat_buttons.png`) and the "Detect"/"Choose city" button labels and "I am in Israel" label appear in the same washed-out style in the full screenshot.

For contrast, **other** cards in the same screens correctly inverted to a dark background with fully-readable light text — e.g. Settings' "App Permissions" row, and every card on the Lifetime Knowledge detail screen (`46_lifetime_knowledge_dark.png`, `47_scope_selection_dark.png` — both fully legible, good example of the theme done right). So this is a specific, recurring subset of the card/text-style combination (likely a shared "cream/white summary card" widget whose title `Text` pulls a theme-aware — i.e., dark-mode — color while its own container background stays hardcoded light), not a global dark-mode failure, but it recurs across at least two main tabs plus Settings, which makes it a real P1: a user in dark mode cannot read several primary card headings and a couple of button labels throughout the app.

---

## F3 — Confirmed FIXED (positive finding) — run-8's Lifetime Knowledge rollup contradiction no longer reproduces

Run-8 (device 5562) found: Lifetime Knowledge header showed `0 פריטים נלמדו` while a row directly beneath showed a nonzero count — two contradictory numbers on one screen, and Dashboard/Progress stayed at 0.

Here, after marking 3 leaves (משנה א/ב/ג of Berakhot 1) as lifetime-learned via Settings → Add Lifetime Learning → Save (`28_selected_3_light.png`, `29_after_save_light.png`, confirmation toast "Marked 3 lifetime selections."):
- Dashboard immediately showed "📚 3 items in lifetime" and "3 / 70,033 sections — 9 curricula" (`31_dashboard_after_marks_light.png`).
- Progress tab showed "3" in the Lifetime stat bubble (`32_progress_light.png`).
- Lifetime Knowledge detail screen showed a consistent `3 פריטים נלמדו` header matching the `3 of 4192` per-curriculum row underneath — no contradiction (`33_lifetime_knowledge_light.png`, and dark-mode `46_lifetime_knowledge_dark.png`).

All three surfaces agree, in both themes. This matches the intent of the separate "R8 P2 — bulk marks now roll up" fix (commit `2273d9d9`) and appears solid.

---

## F4 — P3 (pre-existing, still present, not re-triaging) — Dashboard חזרה card shows "חזרה" twice

Exactly as run-8 documented for this device: the review-summary card on the Dashboard shows the word "חזרה" stacked twice (small eyebrow label + large title, both reading "חזרה") next to the "0" count, looking like a placeholder duplicate. Still present post the theme migration, in light (`20_dashboard_scrolled3_light.png`). Not re-scoring; run-8 already logged this as an accepted P3.

---

## F5 — P3 (minor, low confidence) — "Add items I learned previously" card on the Lifetime Knowledge screen doesn't respond to taps (dark mode)

On the Progress → Lifetime Knowledge screen, the bottom card "Add items I learned previously / Lifetime Marking — counts toward Lifetime Knowledge" (`46_lifetime_knowledge_dark.png`) did not navigate anywhere after 3 tap attempts at different points within its bounds (card center, icon region). The UI dump shows it as a plain `android.view.View` rather than a `Button`-flagged node. By contrast, the identically-worded "Add Lifetime Learning" entry point reached from the **Settings** screen navigated correctly to the same scope-selection flow every time, including immediately before this (in light mode). I did not have time to re-check whether this specific card is tappable in light mode or whether this is theme-related, an automation timing artifact, or a genuine dead/duplicate tap target — flagging at low confidence for follow-up rather than as a hard-confirmed defect.

---

## F6 — Environment note (not scored as an app defect) — a third, unexplained full-VM death during benign navigation

After the two P0 repros (F1) were captured and dark mode was enabled, the emulator guest for port 5556 vanished from `adb devices`/`ps aux` a **third** time while doing nothing riskier than tapping the DASHBOARD tab and scrolling — no Learn/TextDisplay involvement. Host RAM was never under pressure (`free -h` showed 47GB+ available at the time). This rules out host contention. It's either a delayed knock-on effect of the earlier OOM-related guest instability, or general qemu/swiftshader software-rendering fragility on this AVD image — run-8 attributed similar unexplained crashes on other devices to "host GPU/SwiftShader instability" rather than the app. Noting it because a real user experiencing spontaneous app death during ordinary navigation is a serious concern regardless of attribution, but I'm not scoring it as a confirmed app-side P0/P1 given the lack of reproducibility and the benign action that preceded it.

---

## Notes / things I could not cover, and why

- **Learning/TextDisplay reader, Content Hierarchy screen, Content Search screen**: entirely blocked by F1 (see above) — this is most of the assigned slice. I substituted the scope-selection hierarchy (Settings → Add Lifetime Learning) for partial curriculum→masechta→perek→leaf coverage, and used it to mark 3 units complete and verify Dashboard/Progress rollup, per the mission's fallback guidance.
- **Dark mode required going through the OS Settings app**, not `adb shell cmd uimode night yes` / `settings put secure ui_night_mode 2` — both reported success (`settings get secure ui_night_mode` returned `2`) but `dumpsys uimode` kept reporting `mNightMode=1 (no), mNightModeLocked=true` and the app never re-themed. Only tapping the actual "Dark theme" toggle in `Settings → Display` (via `am start -a android.settings.DISPLAY_SETTINGS`) took effect. Worth updating the shared driver notes for future audits on this AVD image (`user`/production build — `adb root` is denied here too, consistent with the existing memory note, contrary to what I'd expect for a locally-built AVD).
- **3 total full-emulator deaths this session** (2 explained by F1, 1 unexplained per F6) — each required a ~30–60s relaunch of the AVD from the host (`emulator -avd lt_api29_pixel3 -port 5556 ...`); app data survived every time (disk-backed userdata image), so no re-seed was ever needed after the initial `pm clear`.
- I did not get a second, explicit dark-mode repro of the F1 crash (see note under F1) — a deliberate time/stability trade-off given the mechanism was already confirmed twice with full logcat+code evidence in light mode.
- Minor, not filed as a formal finding: the breadcrumb bar on the scope-selection hierarchy screen (`27_scope_perek1_light.png`: "משניות › זרעים › ברכות › פרק א") renders left-to-right (root on the left, current level on the right) even though the labels are Hebrew — the reverse of what RTL breadcrumbs conventionally do. This may well be an intentional "always-LTR structural path" design choice (common even in RTL apps, similar to file paths), so flagging only as a "possibly by design" observation, not a finding.
