# Run-10 — emulator-5554 (API 28, Android 9): onboarding, account, Parent PIN

**Verdict: no app defects found.** 18 screens audited, light mode only.
**The offline-account path works end to end — confirmed twice.**
Attribution: guest-side only, clear-before/check-after every scenario — **guest-clean
every time, zero app crashes all session**.

> Filed by the coordinator on the auditor's behalf — its harness returns findings as
> text rather than writing files. Content is the auditor's, verbatim in substance.
> Screenshots at `/tmp/device_e2e/5554/` (not checked in).

## Seed

Fresh `pm clear` → offline account → child profile `QAKid` (Parent PIN `2580`) → adult
profile `QAAdult` → one self-paced משניות track.

## What was verified

**Offline account (the explicitly-required path).** Create Account online, then with the
network cut → **"Create Offline Account" is revealed**. The network gating is confirmed
working *as designed*, not as a regression. The full path completed end to end twice:
once redone from the account picker after an environment interruption, once as a clean
delete-and-restart at session end.

**Parent PIN — the security-critical surface.** Verified precisely:
- set PIN → confirm-mismatch → Clear → re-enter → success (all correct);
- 5 wrong attempts each show "Incorrect PIN"; the **6th triggers lockout exactly at
  `maxFailedAttempts = 5`**, matching `pin_service.dart`;
- **lockout is enforced even for the CORRECT PIN via a different gated action** (Add
  Profile) — i.e. the lockout is on the guard, not on one screen. This is the property
  that actually matters;
- countdown ticks 15 → 14 min; expiry tested by deliberately advancing the system clock
  ~19 min (then automatic date/time re-enabled); correct PIN accepted afterwards;
- PIN-gated profile switch QAKid → QAAdult works.

**Add-track wizard.** Full 7 steps (curriculum → program → scope → study days → chazara
pace → target pace → mark-prior-learning) → "Track 'משניות' created"; Dashboard and Manage
Tracks both correct. Second entry: duplicate-curriculum warning icon, system-back steps
back one step preserving selection, Exit-confirmation dialog, Exit leaves no duplicate track.

**Account lifecycle.** Settings sweep → "Who is learning?" picker → account-picker
swipe-to-dismiss → "Delete account?" → Cancel restores → Delete Forever → clean return to
a fresh Get-Started screen with the correct offline banner.

## Deliberate-check — not a finding

"STEP X OF 6" vs "OF 7" is **intentional**: `computeWizardStepTotal()` in
`add_track_flow_screen.dart` excludes the program step from the total only while no
curriculum is selected, and its doc comment says so. Verified in code *before* considering
it a defect — the right order of operations.

## Reconfirmed pre-existing P3s (already logged run-8/run-9, not re-scored)

- **Chevron direction inconsistency in the LTR shell**: wizard step 3 (scope) renders row
  chevrons pointing right; step 7 (Mark Prior Learning) renders the same style pointing
  left — same wizard, same session, same device. **Third occurrence across runs.**
- Settings footer still reads "Torah Study Tracker" (old Firebase project id) vs
  "Learning Tracker" branding elsewhere; its 3-icon row still has no a11y label.
- Faint grey decorative-rectangle sliver peeks from behind the Sign In / Create Account
  card's top-right corner in light mode.
- Intro carousel slide 2 chips ("Review…" / "…yos") clip mid-word at this screen size.

## ENVIRONMENT event — not an app defect, not scored

Mid-wizard (right after tapping the משניות curriculum row), the foreground activity was
kicked to the home screen. Attribution came back guest-clean; logcat showed at the exact
timestamp `ActivityManager: Force stopping com.jcom.torah.learning_tracker … installPackageLI`
/ `Killing … stop` / `Force stopping … pkg removed`, and `dumpsys package` `lastUpdateTime`
matched the interruption second exactly.

**Cause confirmed: the coordinator's APK deployment to all six devices at ~19:05.** Not a
crash/ANR/OOM-kill; app data survived intact (offline account + QAKid + PIN all present
after relaunch), consistent with a `-r` reinstall rather than a wipe. The 5564 auditor
independently diagnosed the same event by the same route.

## Explicitly not covered

- Run-9's P2 "reconnect banner leaks into nested add-another-account flow" — needs a
  second cloud account, out of scope for an offline-only session.
- Run-9's low-confidence P3 "first tap after sign-out doesn't register" — the only
  sign-out-equivalent exercised was terminal account deletion, a different code path.

Neither is claimed fixed nor reconfirmed. They were simply not exercised.

## Housekeeping

Dark mode was on at boot (AVD default); switched to light via `cmd uimode night no` before
any testing. Network (wifi+data) cut for the offline test and restored after. Device left
stable on the fresh Get-Started screen.
