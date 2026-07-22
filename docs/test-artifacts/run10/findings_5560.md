# Run-10 — emulator-5560 (API 34, Android 14): Settings, parent mode, privacy/PIN boundary

**Verdict: the PIN boundary was BROKEN. One P0, confirmed and reproduced twice**
(initial discovery + a clean cold-start repro).
Attribution guest-side only, clear-before/check-after every scenario — guest-clean every
time, zero app crashes. Light mode only per assignment (device booted dark; forced light
via `cmd uimode night no`).

> Filed by the coordinator on the auditor's behalf — its harness returns findings as text
> rather than writing files. Content is the auditor's, verbatim in substance.
> Screenshots were session-local under the scratchpad and are not checked in.

**STATUS: FIXED** — see `e45449ee`. Details at the end.

## P0 — Parent Mode re-entry skips the PIN after any profile-switch round trip

A child who has watched a parent unlock Parent Mode once this app session can return to
full admin controls with **zero PIN prompt**, any time later that session — even after the
UI has reverted to a plain `CHILD MODE` badge implying no active elevation.

### Repro (clean, from a cold `am force-stop` + relaunch)

1. Cold launch → "Who is learning?" → select **JuniorQA** (child). Dashboard correct:
   `CHILD MODE` badge, full 4-tab nav.
2. Settings → **Parental Controls → Parent Mode**. Tile correctly shows a lock icon and
   the subtitle "Switch to admin (PIN-guarded)". Tap → "Enter Parent PIN" appears.
3. Enter correct PIN `2580` → elevates correctly. Header reads `PARENT MODE`, lands on
   Parent Settings (Manage Tracks / Manage Goals / Point Settings / Adjust Points /
   Reward Configuration / Pending Prizes / Add Lifetime Learning).
4. Profile switcher → **GamifyQA** (adult). Correctly re-prompts ("Enter the PIN to switch
   profiles."). Enter `2580` → GamifyQA dashboard, badge `ADULT MODE`.
5. Switcher → back to **JuniorQA**. Correctly requires no PIN (selecting a child is never
   gated) and the header correctly resets to `CHILD MODE` — **looks fully unelevated**.
6. Settings → **Parent Mode** tile again (still shows the lock icon and "PIN-guarded"
   subtitle — visually promising a gate) → tap.
   **Result: no PIN dialog. Lands directly in full Parent Settings, fully interactive,
   while the header still says `CHILD MODE`.**

Guest logcat clean both times — a pure authorization/logic defect, not a crash.

### Root cause (read in code, confirmed, not guessed)

Two pieces of state that must move together, and didn't:

- **`PinGuard._authenticatedScope`** (`lib/core/navigation/guards/pin_guard.dart:63-70`) —
  the actual gate. Only `lock()` clears it.
- **`parentPinAuthenticatedProfileIdProvider`** — the reactive flag the badge watches
  (`app_shell.dart:166-172`, `settings_screen.dart:617-623`).

`ProfileSwitcherSheet._switchProfile()`
(`lib/features/profiles/presentation/widgets/profile_switcher_sheet.dart:309-327`) cleared
only the second, per its own comment: *"the PIN guard's per-(scope,profile) cache
re-prompts on the new profile automatically since the scope id changes; we only need to
clear the reactive flag."*

That is true when switching to a **different** profile (new scope id ⇒ cache miss — which
is why step 4 correctly re-prompted). It is **false on a round trip back to the same
child**: the scope id (`PinScope.parent(juniorQaId)`) is identical to the cached one, so
`_authenticatedScope == scope` and the guard returns `next(true)`
(`pin_guard.dart:105-108`).

The tile's own comment (`settings_screen.dart:646-650`) states the intended policy — "no
forced re-lock — once in parent mode you stay in it until you explicitly Exit parent mode"
— which is reasonable. But "explicitly Exit" was wired only to `ChildViewBanner.onExit`
calling `pinGuard.lock()`. **Switching profiles was a second, un-wired way to leave parent
mode**: the badge reset (looked exited), the actual gate did not.

### Why P0

Protocol bar: "PIN/privacy bypass" = P0. This is a full bypass in the exact shared-device
scenario that matters — parent unlocks, hands the device back, and the child (who can
switch profiles unaided, since that direction is deliberately un-gated) reaches every
admin surface with one tap: delete tracks/profiles, adjust point balances, reconfigure
rewards. Meanwhile the UI actively tells them they are blocked.

## Explicit answer: was there a way past the parent PIN?

**Yes — the P0 above.** All *first-encounter* PIN paths were solid; the break is
specifically **re-entry after a profile round trip**.

## PIN boundary — everything else tested, no bypass

- Back / Cancel during first entry: dismisses only.
- **Rotation mid-entry**: resets entered digits (mildly annoying, not insecure). Separately,
  the landscape dialog is taller than the viewport — digits 7-9/0, Cancel, Delete and the
  title scroll out of view with **no visible scroll affordance** (**P2**; recoverable by
  scrolling, and it makes entry *harder*, not bypassable).
- Wrong PIN (`1234`, `2599`): rejected, "Incorrect PIN", stays in Child Mode.
- Background mid-entry with 2/4 digits then foreground: process not killed, partial digits
  preserved (expected — same live process), still demanded the remaining correct digits.
- "Switch account" (offline-account chooser in the same sheet): correctly PIN-gated.
- Rapid taps: no drop/duplicate bug. An early "taps not registering" was the auditor's own
  coordinate bug (display-scaled vs raw device px), corrected and re-verified.
- 5-attempt lockout threshold not re-tested here — covered in depth on 5554.

## Other findings

- **P3** — transient blank Settings frame + missing Settings tab for ~1s right after
  selecting a profile; self-corrects. Reproduced twice, guest-clean. Looks like a one-frame
  layout race, not a gating regression.

## Verified correct — deliberately NOT filed as findings

- Notification permission UI ("blocked") matches `dumpsys` (`granted=false`) this run — no
  mismatch (a past run found the opposite-direction mismatch).
- Reward Configuration (existing reward, new-reward form, live preview) — no defects.
- Non-admin Settings tiles **are** reachable from Child Mode's own Settings tab **by
  design** (`app_shell.dart` always renders the Settings tab; only the Parent Mode tile
  carries the PIN gate). Initially suspected as a bypass, checked in code, confirmed
  deliberate.

## Coverage

Settings root + Device/Shabbos/Profile/Parental-Controls/Diagnostics; App Permissions
cross-check; Notification Settings; Parent PIN entry (portrait + landscape); Parent
Settings and one level into Adjust Points + Reward Configuration; profile switcher sheet
(Switch account, profile list, Add/Skip); child↔adult switching both directions.

**Not covered:** PIN lockout threshold (covered on 5554), full CRUD in Manage
Tracks/Goals/Point Settings/Pending Prizes/Add Lifetime Learning, dark mode (per assignment).

## Resolution

Fixed in **`e45449ee`**: `_switchProfile()` now calls `ref.read(routerProvider).pinGuard.lock()`,
which clears the cached scope **and**, via `onSessionLocked` (`router_provider.dart:126`),
the reactive flag — strictly superseding the old clear-only call.

⚠️ **Test-coverage caveat, stated deliberately.** The accompanying
`test/core/navigation/run10_p0_pin_bypass_after_profile_roundtrip_test.dart` pins the
`PinGuard` contract but does **not** guard this defect: reverting the production fix leaves
it 3/3 green (verified, not assumed), because the bug lived in the *caller*. A
**caller-level** regression test — one that fails if `_switchProfile` reverts to clearing
only the reactive flag — is required and tracked as a follow-up. Until it exists, this P0
is fixed but **not yet regression-proofed**.
