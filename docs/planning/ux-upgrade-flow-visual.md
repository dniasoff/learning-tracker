# Upgrade Flow — Visual Design & Open Questions Resolution

**Status:** Final (Story 20.2 deliverable)
**Date:** 2026-04-11
**Supersedes / supplements:** `upgrade-flow-ux-spec-2026-04-10.md` §10
**Author:** Implementation support, following the analyst spec from 2026-04-10

This document completes the remaining design work for the local → cloud upgrade flow. The analyst spec from 2026-04-10 delivered the flow / copy / state machine. What's left — and what's resolved here — is:

1. Per-screen visual layout (wireframe level, pre-handoff)
2. Component inventory against the existing design system
3. Final answers to the 9 open questions in §10 of the analyst spec

This is *not* a pixel-polish deliverable. A visual designer still needs a pass for typography, spacing tokens, and motion curves before production handoff. What's here is enough to unblock engineering (20.9) and to give the visual designer a non-moving target when they pick it up.

---

## 1. Wireframe Inventory

Each step of the analyst spec gets a numbered wireframe. I describe them in text because the engineering handoff lives in the implementation (`upgrade_to_cloud_screen.dart`), not in Figma. A visual designer taking this over should translate each step into a Figma frame, one per bullet, in the order listed.

### W-01 — Intro screen (§5.1)

```
┌──────────────────────────────────────────────┐
│  ← Back                           Settings → │
├──────────────────────────────────────────────┤
│                                              │
│           [cloud-up icon, 64dp]              │
│                                              │
│         Back up your account                 │
│                                              │
│  Your offline account becomes a cloud        │
│  account. Same email, same password.         │
│  Your data syncs to all your devices.        │
│                                              │
│  This is one-way — you can't switch back     │
│  to offline-only after upgrading.            │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Get Started                   │  │
│  └────────────────────────────────────────┘  │
│                                              │
│           Not now (small text)               │
│                                              │
└──────────────────────────────────────────────┘
```

Components:
- `Scaffold` + `AppBar(title: "Upgrade to Cloud")`
- Centered hero icon (`Icons.cloud_upload` 64dp, `primary`)
- `Text` heading (headlineSmall)
- Two `Text` paragraphs (bodyMedium)
- `FilledButton` primary action
- `TextButton` secondary "Not now"

### W-02 — Confirm password (§5.2)

```
┌──────────────────────────────────────────────┐
│  ← Back                 Step 1 of 3    [?]   │
├──────────────────────────────────────────────┤
│                                              │
│   We need to re-authenticate you before      │
│   sending anything to the cloud.             │
│                                              │
│   [Email field — read-only, pre-filled]      │
│   yoni@example.com                           │
│                                              │
│   [Password field]                           │
│   ••••••••                       [eye icon]  │
│                                              │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Continue                      │  │
│  └────────────────────────────────────────┘  │
│                                              │
│   Forgot password?                           │
│                                              │
└──────────────────────────────────────────────┘
```

Components:
- `TextFormField` email, `enabled: false`, filled appearance
- `TextFormField` password with suffix eye toggle
- Step indicator in app bar (Text, labelSmall)
- `TextButton` "Forgot password?" — routes to §7.7 dead-end screen

### W-03 — Checking for existing account (§5.3)

```
┌──────────────────────────────────────────────┐
│                                              │
│          [spinning progress, 48dp]           │
│                                              │
│         Checking for existing account…       │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

One-line implementation in Dart: a `Center(child: CircularProgressIndicator())` + Text below. Maximum duration 10s before falling back to error (§7.2).

### W-04 — Confirm promotion (§5.4)

```
┌──────────────────────────────────────────────┐
│  ← Back                Step 2 of 3           │
├──────────────────────────────────────────────┤
│                                              │
│   Ready to back up                           │
│                                              │
│   ┌─────────────────────────────────────┐    │
│   │ 📦 What will be backed up           │    │
│   │                                     │    │
│   │   • 3 profiles                      │    │
│   │   • 127 completions                 │    │
│   │   • 14-day streak                   │    │
│   │   • Your settings and preferences   │    │
│   │                                     │    │
│   └─────────────────────────────────────┘    │
│                                              │
│   After this, you'll be able to sign in      │
│   on any device with yoni@example.com.       │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Back up now                   │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

Components:
- `Card` with `Icon` + `Column` of counts
- Counts come from live DAO queries — not hard-coded copy
- `FilledButton` primary

### W-05 — Promotion in progress (§5.5)

Linear progress bar with three indeterminate states:
- Creating your cloud account
- Uploading your data
- Finishing up

Each state shows for as long as the underlying operation takes. Non-cancellable once "Creating your cloud account" starts (per §7.6).

### W-06 — Success (§5.6)

```
┌──────────────────────────────────────────────┐
│                                              │
│          [green check mark, 96dp]            │
│                                              │
│          You're backed up                    │
│                                              │
│   Your data is now synced across all your    │
│   devices. You can sign in anywhere with     │
│   yoni@example.com.                          │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │          Done                          │  │
│  └────────────────────────────────────────┘  │
│                                              │
└──────────────────────────────────────────────┘
```

### W-07 — Collision screen (§6.1)

The heart of the collision path. This must be *calm* — the user is not in trouble.

```
┌──────────────────────────────────────────────┐
│  ← Back                                      │
├──────────────────────────────────────────────┤
│                                              │
│   [cloud-question icon, 64dp]                │
│                                              │
│   A cloud account already exists for         │
│   yoni@example.com                           │
│                                              │
│   We won't merge anything automatically.     │
│   Choose how you want to handle this:        │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Merge everything up                 │    │
│  │  Your offline progress joins your    │    │
│  │  existing cloud account.             │    │
│  │                              [→]     │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Keep cloud, discard local           │    │
│  │  Your offline data is removed. You   │    │
│  │  sign in to the existing cloud       │    │
│  │  account as-is.                [→]   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  Cancel                              │    │
│  │  Stay offline-only. Nothing changes. │    │
│  │                              [→]     │    │
│  └──────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
```

Each option is a `InkWell`-wrapped `Card` with icon + title + description + trailing arrow. The destructive option ("Keep cloud, discard local") uses the `error` colour for its icon but the card itself stays neutral — we don't want to scare people who actually want that path.

### W-08 — Merge-up preview (§6.2.2)

Renders two columns: "What's local" | "What's in cloud", with counts on each side. Tapping "Continue" triggers the merge. The spec's default for this screen is to fetch live cloud counts (see resolved Q3 below).

### W-09 — Replace-local hard confirm (§6.3.2)

Two stacked warning blocks + a hard checkbox. Design resolution of Q6 is to keep the checkbox (not require typing "DELETE") — see resolved Q6 below.

### W-10 — Forgot password dead-end (§7.7)

Shown when the user can't remember their local password and the upgrade flow can't proceed. See resolved Q7 below for what this screen actually offers.

---

## 2. Component Inventory

All of these already exist in the app's Flutter Material 3 theme. No new components are needed.

| Component           | Material 3 widget                | Used in            |
| ------------------- | -------------------------------- | ------------------ |
| App bar             | `AppBar`                         | W-01, W-02, W-04, W-07 |
| Hero icon           | `Icon(size: 64-96)`              | W-01, W-06, W-07   |
| Heading             | `Text(style: headlineSmall)`     | All                |
| Body paragraph      | `Text(style: bodyMedium)`        | All                |
| Primary action      | `FilledButton`                   | W-01, W-02, W-04, W-06 |
| Secondary action    | `TextButton`                     | W-01, W-07 (Cancel) |
| Destructive action  | `FilledButton.tonal` + error fg  | W-09               |
| Read-only text field| `TextFormField(enabled: false)`  | W-02               |
| Password field      | `TextFormField(obscureText)`     | W-02               |
| Option card         | `InkWell` + `Card`               | W-07               |
| Summary card        | `Card` + `Column`                | W-04, W-08         |
| Progress spinner    | `CircularProgressIndicator`      | W-03               |
| Progress bar        | `LinearProgressIndicator`        | W-05               |
| Hard-confirm check  | `Checkbox` + body text           | W-09               |

Colour usage follows the existing theme:
- `primary` — all non-destructive accents
- `error` / `errorContainer` — only for the W-09 destructive confirm and the "Keep cloud, discard local" option icon on W-07
- `secondaryContainer` — for the status banner already used in 20.8

No new tokens. No new asset files. A visual designer doing a Figma pass can work entirely from the existing token set.

---

## 3. Open Questions — Resolutions

### Q1 — Firebase minimum password strength vs local-born passwords

**Resolution: Option (a) — enforce Firebase's minimum at local signup.**

`LocalAuthService` already enforces an 8-character minimum (story 20.4). Firebase's default minimum is 6 characters + 1 digit; ours is stricter. So a password that passes `LocalAuthService` validation already satisfies Firebase.

**Follow-up:** `LocalAuthService._validatePassword` should also require at least one digit to fully satisfy Firebase's common rules. Small tweak, no migration impact. Tracked as a follow-up to story 20.4.

**Why:** the 90% case (stay local-only forever) is rare enough that we shouldn't optimize for it at the cost of making upgrade fail. "Your 4-digit password is too weak to back up" at upgrade time is a worse experience than "8+ characters including a digit, please" at signup time.

### Q2 — Email change between local signup and upgrade

**Resolution: Not a v1 feature. Email is immutable on local-born accounts until upgrade.**

Supporting email change on a local-born account would require a second "this email exists locally" check on every edit, plus the confused-identity issue if the user signed up with email A but wants to upgrade under email B. Defer the whole capability.

**Follow-up:** Settings should not expose an email-edit field for local-born users. If the settings screen currently surfaces one, it should be read-only and show a tooltip: "Upgrade to change your email." Check during 20.9 review. (Audit shows no such field currently exists — confirmed.)

### Q3 — Real-time cloud data preview on merge-up screen (§6.2.2)

**Resolution: Static copy in v1. Live fetch is v2.**

The merge-up preview will say "We'll combine your offline data with your cloud account. Here's what's on each side" followed by **local counts only** (those we have locally). Cloud counts are shown as "loaded from cloud" without a number.

**Why:** fetching cloud counts adds a Firestore roundtrip with its own error paths (timeout, partial data, permissions). The calm framing of the collision screen depends on the path being snappy. If cloud counts come back later than the user's tap, we'd have to block the next step or show stale counts — both feel worse than just not showing them.

**Follow-up:** v2 can fetch cloud counts asynchronously and fade them in if they arrive within 2 seconds, else omit.

### Q4 — Post-upgrade telemetry banner

**Resolution: No separate banner. The Done screen (W-06) is enough.**

Adding a toast on top of the Done screen is redundant. The Done screen *is* the "you're synced" message. A banner that appears *after* returning to the main app would be a second congratulatory surface — tempting but noisy, and the user already knows what happened.

**What the system should do:** immediately after Done is dismissed, the `OfflineTopBanner` (story 20.8) stops appearing (because `isCloudBorn` is now true) and the `NoBackupBadge` disappears from the profile area. That's the *passive* signal of success and it's more valuable than an active banner.

### Q5 — Profile match semantics

**Resolution: Match requires `(name, track)` to be identical.**

The spec's current copy says "if any profiles have the same name and track". That's the definition. Both fields must match for a "match" to be declared in the merge preview. Name-only matches are *not* declared as matches; they're treated as "different local profile, different cloud profile".

**Implementation note:** the merge-up execution path (story 20.9's upload branch) uses the merge rules from 20.12. `(profileId, trackId)` pairs go through `mergeForwardUnion`, so the matching is for UX display purposes only — the merge itself will never lose data either way.

### Q6 — Hard-confirmation checkbox on Option B

**Resolution: Keep the checkbox. Don't require typing.**

Typing "DELETE" is common in destructive admin operations, but it's a step beyond what's needed here. The user:
1. Already chose Option B deliberately from the W-07 screen
2. Already confirmed their password before reaching the collision screen
3. Has the checkbox + a distinct primary button press as their final commit

Three explicit actions to destroy local data is enough friction. Typing "DELETE" would be a fourth and would make the screen feel adversarial. We trust the user more than that.

**Copy for the checkbox:**
> ☐ I understand my offline data will be permanently deleted from this device.

### Q7 — Forgotten local password dead-end

**Resolution: Add a third option on the collision screen — "I don't remember my local password".**

This is a genuine pain point. If the user can't remember their local password, today the flow would be a hard stop. The resolved v1 treatment: on the W-02 "Confirm password" screen, show a "Forgot password?" text link that leads to a screen saying:

> You can't recover a forgotten local password — there's no reset email since this is an offline-only account.
>
> You can still sign in to your existing cloud account if you know that password. Your offline progress on this device will be abandoned.
>
> [Sign in to cloud account instead →]
> [Cancel, try again →]

The "Sign in to cloud account instead" button routes to the existing sign-in screen. The user signs in to the cloud side, and the local-born row on this device gets cleared (same as Option B on the collision screen). The user keeps their cloud history and loses this device's offline history, which was already lost the moment they forgot the password.

**Why:** this is the only non-catastrophic handling of the forgotten-password case. The alternative is "you're stuck forever".

### Q8 — Multi-language number formatting

**Resolution: Out of scope, defer to the existing i18n pipeline.**

Number formatting in the consequence previews (e.g. "3 profiles", "127 completions") should use `intl`'s `NumberFormat` based on the app locale. That's a platform concern, not an upgrade flow concern. The upgrade flow templates will pass raw counts to the i18n layer and let it format them.

### Q9 — PIN / biometric auth persistence through upgrade

**Resolution: Parent PIN and tutor PIN persist. Biometric sign-in is not re-enrolled.**

- **Parent PIN / Tutor PIN** — these are stored locally (via `PinService`) and gate access to parent/tutor modes. They are orthogonal to the cloud-vs-local tier and should persist untouched through the upgrade. No user action needed during the upgrade flow. Verified: `PinService` uses its own SharedPreferences keys and doesn't touch `UserProfiles`
- **Biometric sign-in** — the app doesn't currently have biometric auth enrolled as a sign-in factor (only as a parent/tutor PIN bypass). If a future story adds biometric sign-in for the account itself, that story owns the question of whether biometric enrollment carries over through upgrade

**Follow-up needed:** none in v1.

---

## 4. Handoff to Visual Designer

When a visual designer picks this up, they inherit:

1. **Wireframes W-01 through W-10 above** — as text, needing one Figma frame each in the order listed
2. **Component inventory table in §2** — no new tokens, no new widgets, Material 3 defaults with our existing theme
3. **Nine resolved questions in §3** — no product decisions left hanging
4. **Copy reference in §8 of the analyst spec** — authoritative, do not rewrite without product approval

What they should add:
- Typography tokens (which `TextTheme` variant for each text block)
- Spacing tokens (paddings, margins) aligned with the rest of the app
- Motion — specifically, the transition between steps (§9 state machine of the analyst spec gives the graph)
- Dark-mode review (all colour choices in §2 are theme-aware so this should be mechanical)
- Accessibility review — contrast ratios, screen-reader announcements. The acknowledgement checkbox and collision options in particular need careful labelling

What engineering (story 20.9) can start on **now**, pre-visual-design:
- Everything in this doc. The current `upgrade_to_cloud_screen.dart` already covers W-01, W-02, W-03, W-05, W-06, and W-07 in rough form. W-04, W-08, W-09, W-10 are the remaining pieces. Visual design can land incrementally via the normal refinement loop.

---

## 5. Success Criteria

This story (20.2) is done when:

- [x] Every screen from the analyst spec has a wireframe in §1
- [x] Every wireframe maps to existing components in §2 — no new design-system work blocked
- [x] Every open question from §10 of the analyst spec has a resolution in §3
- [x] The engineering implementation (20.9) can proceed without waiting for a visual pass

Not in scope:
- Figma frames (visual designer)
- Motion specs (visual designer)
- Dark-mode pixel review (visual designer)
- Copy rewrite (already done in the analyst spec)
