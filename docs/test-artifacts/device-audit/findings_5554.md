# Device Audit — emulator-5554 (Pixel 2 API 28, Android 9, 1080×1920)

Auditor: Sonnet 4.6 subagent  
Date: 2026-06-23  
App version: v1.0.65 (1)  
Path: First-run offline onboarding → Dashboard → all 4 tabs → Settings full scroll

---

## Screens audited

| Screen | Result | Notes |
|--------|--------|-------|
| Splash / loading | PASS | "Preparing your path…" + progress bar render correctly |
| Intro carousel page 1 — "Your Daily Torah Plan" | PASS | Title, body, progress bar, CTA all render; no overflow |
| Intro carousel page 2 — "Never Forget a משנה" | PASS | Decorative chips ("Review…" / "…yos") are intentional per source; Hebrew renders |
| Intro carousel page 3 — "Earn While You Learn" | PASS | Badge collection / Mystery Prizes chips, "Get Started" CTA all render |
| Sign-in screen (offline) | PASS | Warning badge swaps to "Local account only…"; Google sign-in correctly hidden offline |
| Register / Create Account screen (offline) | PASS | Offline explanation wraps cleanly; "Create Offline Account" CTA prominent; "Retry connection" present |
| Profile creation — "What should we call you?" | PASS | All controls render; "Create Profile" correctly disabled until name typed |
| "What brings you here?" onboarding step | PASS | Two option cards render cleanly; no overflow |
| Post-onboarding Dashboard (pre-shell) | ISSUE — P1-A | After "Skip for now", user lands in pre-shell screen with NO bottom nav |
| Dashboard (AppShell) | PASS | Empty state centred; bottom nav present |
| LEARN tab | PASS | Centred empty state; "No active tracks" + "Add Track" CTA |
| PROGRESS tab | PASS | Centred empty state; "No progress yet" |
| SETTINGS — top (account card) | ISSUE — P2-A | Offline email address truncated with ellipsis |
| SETTINGS — Shabbat Mode section | PASS | Hebrew "שבת" renders; long description wraps correctly |
| SETTINGS — Profile section | PASS | Manage Tracks, Manage Profiles, Calendar Preference all render |
| SETTINGS — Nikud / Hebrew Terms | PASS | Toggle pairs render without overflow |
| SETTINGS — Backup & Sync card | PASS | "Upgrade to Cloud" button renders; subtitle wraps |
| SETTINGS — bottom (Send Diagnostic Logs, version) | PASS | All text renders; no overflow |

---

## Findings

### [P1-A] Post-onboarding Dashboard — Bottom navigation bar absent after "Skip for now"

- **Device:** emulator-5554 (API 28, Pixel 2, 1080×1920)
- **Screenshot:** /tmp/device_e2e/5554/30_dashboard_dismissed.png
- **What:** After completing offline onboarding (Create Offline Account → name profile → "What brings you here?" → "Skip for now") and then tapping "Dismiss" on the "Get started" CTA, the user is left on a screen showing only an "I'm a tutor" button and a large blank area. The bottom navigation bar (DASHBOARD / LEARN / PROGRESS / SETTINGS) is completely absent. The only escape is tapping the gear icon in the app bar, which navigates into the AppShell where the nav bar does appear.
- **Repro:** launch(clear=True) → offline → 3 carousel swipes → "Get Started" → "Register Here" → "Create Offline Account" → type name → "Create Profile" → "Skip for now" → "Dismiss"
- **Suspected:** The "What brings you here?" → "Skip for now" navigation pushes `DashboardRoute()` directly rather than replacing with `AppShellRoute()`. The pre-shell Dashboard screen is not wrapped in the AutoTabsScaffold, so the bottom nav builder never fires. Check the wizard route transition in `app_router.dart` and `wizard_steps.dart`.

---

### [P2-A] Settings — offline email address truncated in account card

- **Device:** emulator-5554 (API 28, Pixel 2, 1080×1920)
- **Screenshot:** /tmp/device_e2e/5554/38_settings_top.png
- **What:** The auto-generated offline email (`offline_50553323b394@offline.local`) is rendered in the Settings account card and truncated: `offline_50553323b394@offline.l…`. This is an internal implementation detail that users should never see. The `offlineAccountLabel` l10n key ("Offline account") exists and is used correctly in the account picker (`account_picker_screen.dart:336`) but is not used here.
- **Repro:** Complete offline onboarding → tap gear icon or SETTINGS tab → view account card
- **Suspected:** Settings account card renders `authState.email` directly. For local-born accounts, substitute `l10n.offlineAccountLabel` instead. See `lib/features/account/presentation/widgets/no_backup_badge.dart` and the settings account card widget for the fix point.

---

## False positives / non-findings

- **Carousel page 2 chips "Review…" / "…yos"**: Intentional. `introMishnaReviewChip = 'Review…'` is the designed l10n value (`app_localizations_en.dart:480`), and `'…yos'` is hardcoded decorative text (`intro_mishna_page.dart:71`) representing the end of "Mishnayos".
- **Dashboard empty state CTA**: The centred "Get started / Add a learning track" with "I'm a tutor" button is the correct onboarding CTA state — PASS.
- **Upgrade-to-cloud MaterialBanner**: Appeared correctly once network came back online for the local-born account. Expected behaviour per `app_shell.dart:157-190`.

---

## Offline account creation — replayable recipe

```
1.  d.launch(clear=True)
2.  d.shell('svc wifi disable') ; d.shell('svc data disable')
3.  # Wait ~2 s for offline state to register, then relaunch if needed
    d.launch(clear=True) ; time.sleep(4)
4.  3× d.shell('input swipe 700 1200 100 1200 300') with time.sleep(1.5) between
5.  d.tap_text('Get Started')
6.  d.tap_text('Register Here')
    # Screen now shows: "Create Offline Account" button + "Retry connection"
7.  d.tap_text('Create Offline Account')
    # Screen: "What should we call you?"
8.  d.shell('input tap 540 330')          # focus name field
    time.sleep(0.5)
    d.shell('input text AuditKid')
    d.shell('input keyevent 4')           # dismiss keyboard
9.  d.shell('input swipe 500 1600 500 600 500') ; time.sleep(1.5)
10. d.tap_text('Create Profile')
11. d.tap_contains('Skip for now')
    # Now in pre-shell Dashboard — bottom nav ABSENT (see P1-A)
12. d.tap_desc('Settings')               # gear in app bar → enters AppShell
13. d.shell('svc wifi enable') ; d.shell('svc data enable')
```

---

## Top 3 issues

1. **[P1-A]** Bottom nav absent after offline onboarding "Skip for now" + "Dismiss" — user is navigation-trapped in the pre-shell Dashboard. Only escape is the Settings gear icon.
2. **[P2-A]** Raw offline email (`offline_xxxxx@offline.local`) displayed and truncated in Settings account card — should show `offlineAccountLabel` ("Offline account") instead.
3. No P0 found. No crashes, no RenderFlex overflows, no raw l10n keys visible in any screen on this small (1080×1920) device.

---

## P1-A repro confirmed — follow-up investigation (2026-06-23)

**Status: CONFIRMED. Trigger isolated, root cause identified, persistence confirmed.**

### Minimal reproducing tap-sequence

```
pm clear com.torahstudytracker.app
svc wifi disable && svc data disable
d.launch()                              # carousel appears
3× swipe-left carousel
tap "Get Started"
tap "Register Here"
tap "Create Offline Account"            # profile creation screen
tap name field (y≈330), type name, keyevent 4
scroll down, tap "Create Profile"       # "What brings you here?" appears
tap "Skip for now"                      # <-- TRIGGER: lands on EmptyLoginScreen
```

The "Dismiss" tap afterward is irrelevant — the trap is already active after "Skip for now".

### Exact trigger

Tapping **"Skip for now"** on the "What brings you here?" screen (`_ScreenPhase.intentChooser`) calls `_navigateToDashboardSkipped()` in `onboarding_screen.dart:274`, which unconditionally routes to `EmptyLoginRoute` (`onboarding_screen.dart:283`). The comment there says this is intentional for "zero-profile accounts", but a profile was already successfully created in the prior step — the function does not check whether a profile exists before choosing the route.

### Root cause (source)

`learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart:274-283`

```dart
Future<void> _navigateToDashboardSkipped({
  required bool joinedToTutor,
}) async {
  await _clearSavedState();
  await _store.markComplete(skipped: true, joinedToTutor: joinedToTutor);
  if (!mounted) return;
  // WS2.skip/WS2.surface: route to the empty-login surface (zero-profile
  // landing). The existing AppShellRoute is guarded by ProfileGuard which
  // blocks zero-profile accounts — EmptyLoginRoute has no such guard.
  unawaited(context.router.replaceAll([const EmptyLoginRoute()]));
}
```

`EmptyLoginRoute` is a top-level route outside `AppShellRoute`, so `AutoTabsScaffold` and its `bottomNavigationBuilder` never render — hence no nav bar.

### Persistence

**PERSISTENT across force-stop + relaunch.** `markComplete(skipped: true)` at line 278 writes the skipped flag to storage. On relaunch, the router reads this persisted state and routes directly back to `EmptyLoginRoute`, bypassing the normal AppShell. Users are permanently trapped until they tap the gear icon to enter Settings (which navigates into the AppShell), or until `pm clear`.

### Trapped screen node dump

Nodes present on `EmptyLoginScreen` (all of them):
- `'Learning Tracker'` — app bar title
- `'Settings'` — gear icon in app bar (the only escape into AppShell)
- `"I'm a tutor"` — `Key('empty_login_tutor_entry')` button

No sign-in, no register, no navigation tabs — only the tutor entry point.

### Suggested fix

In `_navigateToDashboardSkipped`, check whether a profile exists before routing to `EmptyLoginRoute`. If `_createdProfileId != null` (a profile was just created during this onboarding session), route to `AppShellRoute` instead:

```dart
final hasProfile = _createdProfileId != null ||
    (ref.read(profileListStreamProvider).asData?.value.isNotEmpty ?? false);
unawaited(context.router.replaceAll([
  hasProfile ? const AppShellRoute() : const EmptyLoginRoute(),
]));
```

Screenshot references: `/tmp/device_e2e/5554/58_after_skip_for_now.png` (trap immediately after trigger), `/tmp/device_e2e/5554/60_after_force_stop_relaunch.png` (persistence confirmed).

---

## Re-verify (fixed build)

Date: 2026-06-23  
Build: new fixed build installed on emulator-5554

### RE-VERIFY 1 — Nav-trap fix (was P1-A): PASS

Ran the full offline onboarding recipe from scratch (`d.launch(clear=True)`, network off):  
carousel → "Get Started" → "Register Here" → "Create Offline Account" → type name "FixVerify" → "Create Profile" → **"Skip for now"**

**Result:** Landed directly in the AppShell Dashboard with the bottom navigation bar (DASHBOARD / LEARN / PROGRESS / SETTINGS) fully visible. The EmptyLoginScreen / "I'm a tutor" trap is gone.

- Screenshot (immediately after "Skip for now"): `/tmp/device_e2e/5554/73_after_skip_fixed.png`
- Nodes present: `'Get started'`, `'Add a learning track to begin tracking your progress.'`, `'Add a learning track'`, `'Dismiss'`, `'DASHBOARD'`, `'LEARN'`, `'PROGRESS'`, `'SETTINGS'` — correct AppShell content.

**Persistence also PASS:** `am force-stop` + `d.launch()` (no clear) relaunches into the normal AppShell with bottom nav. The persistent EmptyLoginRoute state is no longer written.

- Screenshot (after force-stop+relaunch): `/tmp/device_e2e/5554/74_persistence_check.png`

---

### RE-VERIFY 2 — Offline email suppression (was P2-A): PASS

Navigated to SETTINGS → account card.

**Result:** The raw `offline_…@offline.local` email string is completely absent. The card shows display name ("FixVerify") and "No Backup" badge only — clean and complete, not empty or broken.

- Screenshot: `/tmp/device_e2e/5554/75_settings_account_card.png`
- Node text: `'F\nFixVerify\nNo Backup'` — no email field present.

---

Both P1-A and P2-A are **closed** on this build.
