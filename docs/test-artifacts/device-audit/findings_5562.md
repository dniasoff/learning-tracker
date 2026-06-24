# RTL / Hebrew Audit — emulator-5562 (api36 TABLET, Android 16)

Auditor: sonnet agent  
Date: 2026-06-23  
Locale: Hebrew (iw-IL) set via `adb cmd locale set-app-locales`; in-app toggle set to עברי.  
Device: emulator-5562 — Pixel Tablet profile, 2560×1600, Android 16 (API 36).

---

## Screens audited

| # | Screen | Screenshot | RTL OK? | Notes |
|---|--------|-----------|---------|-------|
| 1 | Profile Picker (Hebrew) | 13_launch_with_system_hebrew.png | Partial | Card chevrons on wrong side |
| 2 | Dashboard (Hebrew) | 14_hebrew_dashboard.png | Yes | Layout correct |
| 3 | LEARN tab (Hebrew) | 15_hebrew_learn_tab.png | Partial | Row chevrons wrong side; streak icon wrong side |
| 4 | PROGRESS tab (Hebrew) | 16_hebrew_progress_tab.png | Partial | Row chevrons wrong side |
| 5 | SETTINGS root (Hebrew) | 17_–_20_settings_*.png | Partial | Chevrons + language segment order |
| 6 | Settings → Manage Tracks | 21_manage_tracks_hebrew.png | Partial | FAB bottom-left; track card issues |
| 7 | Settings → Manage Profiles | 22_manage_profiles_hebrew.png | Partial | FAB bottom-left |
| 8 | Add Track — Step 1 (Select Curriculum) | 24_add_track_step1_hebrew.png | Partial | Row chevrons wrong side |
| 9 | Add Track — Step 2 (Join a Program?) | 25_add_track_step2_hebrew.png | No | English subtitle leakage |

---

## Findings

### [P0] Settings (Hebrew) — Language toggle is a no-op; requires out-of-band system locale change
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/06_after_switching_to_hebrew.png
- What: Tapping "Hebrew" in the Settings language segmented control saves the preference (the toggle stays highlighted on next launch) but the UI does **not** re-render in Hebrew. The entire app continues in English/LTR after navigating away, force-stopping, and relaunching. The UI only switched after separately setting the per-app locale via `adb cmd locale set-app-locales com.jcom.torah.learning_tracker --locales iw-IL`. A real user on a production device cannot do this. The in-app toggle is effectively a no-op for the actual locale switch.
- Repro: Settings → scroll to language row → tap "Hebrew" → navigate away or force-stop/relaunch → UI remains English.
- Suspected: The app stores the preference but never calls the Flutter/Android locale-change API (`AppCompatDelegate.setApplicationLocales()` or equivalent `LocaleNotifier` rebuild) in response to the toggle. The locale must be re-applied at runtime, not just persisted for next read.

---

### [P1] LEARN / PROGRESS / SETTINGS / Manage Tracks / Add Track wizard — Navigation chevron on wrong side in RTL
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/15_hebrew_learn_tab.png (representative; same on all list screens)
- What: Every tappable drill-down row across the entire app shows a "‹" chevron anchored to the **LEFT edge** of the row. In RTL the leading/start edge is RIGHT; a drill-down indicator must sit on the RIGHT and point LEFT (←). At LEFT it reads as a "back" affordance. Affected screens: LEARN task rows, PROGRESS sub-section rows, SETTINGS rows (הרשאות אפליקציה, ניהול מסלולים, ניהול פרופילים), Add Track wizard curriculum cards (step 1).
- Repro: Hebrew mode → any list screen with tappable rows.
- Suspected: Row widget uses `Icon(Icons.chevron_left)` positioned without RTL mirroring. Should use `Icons.arrow_forward_ios` (auto-mirrors) or explicitly flip placement under `Directionality.rtl`.

---

### [P1] Add Track wizard Step 2 — English subtitle text leaking into Hebrew UI
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/25_add_track_step2_hebrew.png
- What: Two program option cards on step 2 "להצטרף לתכנית?" display untranslated English descriptions:
  - "משנה יומית" subtitle: **"Two mishnayos per day, no built-in review."**
  - "פרק יומי" subtitle: **"One Mishnah perek per day."**
  All surrounding UI (card titles, badges "לוח יומי", divider "או בחרו חופש", CTA "בקצב אישי") is correctly in Hebrew. Only these two subtitle strings fall through to English.
- Repro: Hebrew mode → Settings → Manage Tracks → הוסף מסלול → select any curriculum → Step 2.
- Suspected: These subtitle ARB keys are defined in `app_en.arb` but missing from `app_he.arb`, causing a silent fallback to English.

---

### [P1] Manage Tracks + Manage Profiles — Primary FAB anchored to bottom-LEFT in RTL
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/21_manage_tracks_hebrew.png, /tmp/device_e2e/5562/sm/22_manage_profiles_hebrew.png
- What: "הוסף מסלול" FAB (Manage Tracks) and "+" FAB (Manage Profiles) are both at **bottom-LEFT**. In RTL, bottom-LEFT is the trailing corner; the primary action FAB should be at **bottom-RIGHT** (leading corner, equivalent to bottom-right in LTR).
- Repro: Hebrew mode → Settings → Manage Tracks / Manage Profiles.
- Suspected: `Scaffold(floatingActionButtonLocation: FloatingActionButtonLocation.endFloat)` — `endFloat` maps to bottom-right in LTR but the scaffold does not auto-flip for RTL. Needs explicit `startFloat` under RTL or use of `FloatingActionButtonLocation.miniStartFloat`.

---

### [P1] Profile Picker — Horizontal profile carousel card order and chevrons not mirrored for RTL
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/13_launch_with_system_hebrew.png
- What: The profile card row reads left-to-right as **[+ הוספת פרופיל] [Daniel] [PinKid] [RedeemKid] [Loop Test A]** — the same visual order as in English/LTR. In RTL the natural reading start is RIGHT, so Loop Test A (first in the list) should be at the right edge, and the "Add" card should trail at the far left (which it does), but the initial scroll position should open with content on the RIGHT. Each card also has a "‹" chevron at its top-LEFT corner, reinforcing the wrong-side chevron bug (P1 above).
- Repro: Hebrew mode → launch app → Profile Picker.
- Suspected: The profile `ListView` / `PageView` may not have scroll direction reversed under RTL, and the chevron inside each card shares the same root cause as the list-row chevron bug.

---

### [P2] Settings — Language segmented control segment order not mirrored in RTL
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/20_settings_very_bottom.png
- What: The language toggle shows **"עברי" LEFT | "אנגלית" RIGHT**. In RTL the first/primary segment belongs on the RIGHT (leading edge). The two adjacent toggles ("הגייה" and "ניקוד") correctly place their default/first option on the RIGHT; the language toggle is the only inconsistent one.
- Repro: Hebrew mode → Settings → scroll to language/pronunciation/nikud section.
- Suspected: The language `SegmentedButton` item list may be hardcoded `[English, Hebrew]` without reversal when `Directionality.rtl`. Other toggles are either defined in RTL-first order or auto-mirrored.

---

### [P2] Add Track wizard header — progress percentage "14%" left-aligned; step label right-aligned; visual mismatch
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/25_add_track_step2_hebrew.png
- What: Wizard top bar shows "שלב 2 מתוך 7" at RIGHT and "14%" at LEFT. The progress bar below fills RIGHT→LEFT (correct RTL). The "14%" label is visually detached from the filled end of the bar and appears stranded at the trailing corner.
- Repro: Hebrew mode → Add Track → any curriculum → Step 2.
- Suspected: The header `Row` child order should swap under RTL, or `CrossAxisAlignment` anchoring the % label to the bar fill end is not direction-aware.

---

### [P2] LEARN tab streak banner — fire icon at far LEFT (trailing corner) in RTL
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/15_hebrew_learn_tab.png
- What: The blue streak banner has the 🔥 fire icon at the **far LEFT** corner while all text ("הישג נוכחי", "רצף 0 ימים", "שיא אישי: 1") is right-aligned. The icon is the decorative lead element and should be at the RIGHT (leading) corner in RTL, adjacent to the heading text.
- Repro: Hebrew mode → LEARN tab → streak banner.
- Suspected: Banner layout uses `Alignment.topLeft` / `MainAxisAlignment.start` for the icon container without Directionality awareness.

---

### [P3] Manage Tracks — "1 פעיל" count badge far from section heading on tablet width
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/21_manage_tracks_hebrew.png
- What: "1 פעיל" badge sits at top-LEFT while "מסלולים פעילים" heading is at RIGHT. The 2560px tablet width creates a ~2300px gap between them. On phone this would be acceptable; on tablet it makes the badge visually disconnected from its label.
- Repro: Hebrew mode → Settings → Manage Tracks, on wide-screen tablet.
- Suspected: Section header `Row` with `MainAxisAlignment.spaceBetween` — acceptable on phone, needs `MainAxisSize.min` or a capped max-width on tablet.

---

### [P3] Manage Tracks — track card progress bar fill direction appears LTR in RTL context
- Device: emulator-5562 (api36 TABLET, Android 16) — Hebrew/RTL
- Screenshot: /tmp/device_e2e/5562/sm/21_manage_tracks_hebrew.png
- What: Inside the "תלמוד בבלי" track card the "0.2%" label is at the far LEFT and the slim progress bar below appears to originate from the LEFT edge. In RTL the filled portion of a progress bar should originate from the RIGHT. At 0.2% fill it is difficult to confirm definitively, but the label placement at LEFT (trailing) rather than adjacent to the filled RIGHT end is a layout concern.
- Repro: Hebrew mode → Settings → Manage Tracks → תלמוד בבלי card.
- Suspected: `LinearProgressIndicator` fill direction is not wrapped with `Directionality(textDirection: TextDirection.rtl)`, so it fills LTR regardless of app locale.

