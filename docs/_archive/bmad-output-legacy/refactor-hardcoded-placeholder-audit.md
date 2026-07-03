# Hardcoded-Placeholder Audit

**Date:** 2026-05-20
**Auditor:** sub-agent
**Trigger:** Owner request after discovering `"+12% vs last week"` was a literal string in `app_en.arb`
**Methodology:** ARB scan + grep sweep + provider/widget cross-check

---

## Summary

- CRITICAL: 1
- HIGH: 5
- MEDIUM: 3
- LOW: 2
- Total flagged: 11
- Verdict: The `"+12% vs last week"` string was an isolated incident — it was already fixed in commit `3c7710f2` before this audit. The pattern does NOT recur in `app_en.arb`. However, the sweep uncovered a cluster of unlocalized strings in two recently-added screens (`streak_history_screen.dart`, `learning_screen.dart`) and a rendered onboarding illustration with hardcoded demo values (`"Level 4"`, `0.6` progress fill, `"7 DAY STREAK"`). The tutoring `_StubAuditLogReadRepository` is also shipped in production and silently returns no data for a user-visible audit log screen.

---

## CRITICAL findings

### C-1 — Tutor audit log stub silently returns empty list in production
- **File:** `learning_tracker/lib/features/tutoring/presentation/providers/audit_log_providers.dart:24–31`
- **Literal:** `Future<List<TutorAuditLogEntry>> fetchEntries(String grantId) async => const [];`
- **Consumer:** `learning_tracker/lib/features/tutoring/presentation/screens/tutor_audit_log_screen.dart:112`
- **Why it's a placeholder:** The `_StubAuditLogReadRepository` is the live production provider (`tutorAuditLogReadRepositoryProvider`). No guard (kReleaseMode or feature flag) separates it from production. When a parent or tutor navigates to the audit log screen, they see the empty-state view — every tutor action silently disappears. The write side (`_StubAuditLogWriteRepository`) is also a no-op, meaning audit entries are never written. The TODO explicitly confirms this: `"TODO(data-layer): Replace stub with a real Firestore implementation"`.
- **Recommended fix:** The stub is acceptable as a placeholder during development, but the audit-log screen itself should either be gated behind a feature flag or show a clear "Not yet available" notice rather than an empty list (which users could interpret as "no history" rather than "not implemented"). Longer term, wire the Firestore read repository before shipping tutor mode to users.

---

## HIGH findings

### H-1 — `chartSevenDayStreak` badge always shows "7 DAY STREAK!" regardless of actual streak
- **File:** `learning_tracker/lib/l10n/app_en.arb:679` — `"chartSevenDayStreak": "7 DAY STREAK!"`
- **Consumer:** `learning_tracker/lib/features/progress/presentation/screens/progress_charts_screen.dart:142`
- **Why it's a placeholder:** The badge is a fixed decorative label on the "Learning Journey" section header. No streak count is computed or injected — the screen never calls `dashboardStreakProvider` or any streak provider. A user with a 1-day streak sees the same "7 DAY STREAK!" badge as a user with a 30-day streak. This is semantically dishonest: the badge implies the displayed streak calendar represents exactly a 7-day streak, which is arbitrary.
- **Recommended fix:** Either (a) remove the numeric claim — change to a neutral label like "STREAK CALENDAR" — or (b) compute the actual current streak count and render `l10n.statDayStreak` with the value. Option (a) is lower risk and avoids needing a provider in this screen.

### H-2 — Intro rewards page shows fake "Level 4" scholar progress bar
- **File:** `learning_tracker/lib/features/onboarding/presentation/widgets/intro_rewards_page.dart:318,326,351`
- **Literals:** `'Scholar Level'`, `'Level 4'`, `width: c.maxWidth * 0.6` (60% fill, hardcoded)
- **Consumer:** `learning_tracker/lib/features/onboarding/presentation/screens/app_intro_screen.dart:468`
- **Why it's a placeholder:** This card is shown on the live onboarding intro screen ("Earn While You Learn" page). It presents a progress bar at 60% filled and the text "Level 4" — demo values, not the user's real level or progress. A brand-new user signing up sees "Level 4 / 60%" which is fabricated. The strings are also not localized (hardcoded English).
- **Recommended fix:** This is an illustration — it should be visually obvious that it is a decorative mock-up. Either (a) remove the "Level 4" label and replace with a generic label like "Scholar Progress" plus a decorative fill, or (b) style it as an obvious illustration (e.g., add a "EXAMPLE" watermark overlay). The values should not look like the user's actual progress on their first encounter with the app.

### H-3 — Onboarding intro shows "7 DAY STREAK" as hardcoded badge
- **File:** `learning_tracker/lib/features/onboarding/presentation/widgets/intro_rewards_page.dart:108`
- **Literal:** `'7 DAY STREAK'` (direct string, not even through l10n)
- **Consumer:** `learning_tracker/lib/features/onboarding/presentation/screens/app_intro_screen.dart:325`
- **Why it's a placeholder:** The badge on the illustrated trophy card during onboarding shows "7 DAY STREAK" as a hardcoded literal. Unlike the ARB-backed `chartSevenDayStreak`, this one bypasses l10n entirely — it will not be translated for Hebrew users. It also asserts a specific claim ("7") that is purely decorative.
- **Recommended fix:** Either remove the numeric claim (use a flame icon only, or "STREAK") or add this string to the ARB file so it is at minimum localized. Since it's a decorative illustration, removing the number is the simpler fix.

### H-4 — `streak_history_screen.dart` has no l10n for user-visible labels
- **File:** `learning_tracker/lib/features/progress/presentation/screens/streak_history_screen.dart:44–48, 63, 80, 89, 101, 108, 115`
- **Literals:** `'Last 7 days'`, `'Last 29 days'`, `'All time'`, `'Streak'` (AppBar title), `'CURRENT'`, `'LONGEST'` (stat tile labels)
- **Consumer:** Same file — all rendered directly
- **Why it's a placeholder:** This is a production screen with no l10n wrapper. All display labels are hardcoded English strings that will not adapt for Hebrew users. `'CURRENT'` and `'LONGEST'` are especially visible stat tile headers.
- **Recommended fix:** Add these strings to `app_en.arb` / `app_he.arb` and replace all six literals with `l10n.*` calls. Note that `chartLast7Days` and `chartLast30Days` already exist in ARB for the charts screen — reuse or generalize those keys.

### H-5 — `learning_screen.dart` streak hero card uses hardcoded English labels
- **File:** `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:151, 160, 188, 231`
- **Literals:** `'CURRENT ACHIEVEMENT'`, `'$currentStreak Day Streak'`, `'Personal Best: $maxStreak'`, `'Keep it up! 🚀'`
- **Consumer:** Same file — `_StreakHeroCard` widget rendered in the Learn tab
- **Why it's a placeholder:** The `_StreakHeroCard` is a live production widget visible on the Learn tab. All four user-facing strings are hardcoded English and not in l10n. The emoji in "Keep it up! 🚀" is also RTL-unsafe. `'$currentStreak Day Streak'` is a dynamic-looking string with a live value but the surrounding text is not localized.
- **Recommended fix:** Add `'CURRENT ACHIEVEMENT'`, `'Day Streak'`, `'Personal Best'`, and `'Keep it up!'` to ARB and use l10n interpolation for the count values. Use RTL-safe emoji handling or a conditional display.

---

## MEDIUM findings

### M-1 — `DateTime(2024, 1, 1)` sentinel for "All time" streak view
- **File:** `learning_tracker/lib/features/progress/presentation/screens/streak_history_screen.dart:40`
- **Literal:** `DateTime(2024, 1, 1)`
- **Consumer:** Same file — `_StreakRange.allTime` date window start
- **Why it's a placeholder:** The "All time" view uses 2024-01-01 as its floor. Since the app started in January 2026, this is functionally a non-issue today. However, it is a magic constant with no named reference — a future developer could mistake it for an intentional constraint or copy it incorrectly. The charts screen uses `DateTime(2000, 1, 1)` (the bulk-prior sentinel epoch) for the same purpose, creating an inconsistency.
- **Recommended fix:** Replace with a named constant `kAppLaunchEpoch = DateTime(2026, 1, 1)` or reuse `kBulkPriorSentinelMs` as the absolute floor, consistent with how the charts screen handles it.

### M-2 — `firebase_options.dart` ships with iOS/macOS/Windows/Linux as `UnsupportedError`
- **File:** `learning_tracker/lib/firebase_options.dart:22–45` + TODO at line 56
- **Literal:** `// TODO: Run flutterfire configure to generate real values.`
- **Consumer:** App bootstrap — `DefaultFirebaseOptions.currentPlatform`
- **Why it's a placeholder:** All platforms except Android throw `UnsupportedError`. The TODO comment has been left in place. This is not a user-trust issue (Android is the target platform and has real keys), but it is a code-hygiene placeholder that would cause a silent crash if the app is ever compiled for iOS without updating this file.
- **Recommended fix:** Remove the TODO comment now that Android is configured. Add a code comment stating `iOS/macOS not targeted for v1` to explain the intentional omissions.

### M-3 — `app_error_view.dart` "Report this issue" button is a no-op shown to users
- **File:** `learning_tracker/lib/core/widgets/app_error_view.dart:121–126`
- **Literal:** `onPressed: () { /* Bug-report affordance — no-op placeholder until a real reporting flow is wired in a later task. */ }`
- **Consumer:** Same file — shown for `ConflictException` / `InternalException` / unclassified errors via `showBugReport: true` path (line 182)
- **Why it's a placeholder:** The "Report this issue" button is rendered in the live app for real error conditions. When users tap it, nothing happens — the comment says this is a no-op placeholder. This is a broken affordance: users who encounter an internal error and try to report it will silently fail.
- **Recommended fix:** Either (a) remove the button until the reporting flow exists, or (b) route to the existing "Send Logs" flow in Settings (`send_logs_service.dart`) which already exists as a real implementation.

---

## LOW findings

### L-1 — `Child: ${grant.childProfileId}` shown in profile picker for tutored children
- **File:** `learning_tracker/lib/features/profiles/presentation/widgets/tutored_children_section.dart:98–99`
- **Literal:** `'Child: ${grant.childProfileId}'` (internal ID shown as display text)
- **Consumer:** `learning_tracker/lib/features/profiles/presentation/screens/profile_picker_screen.dart:144`
- **Why it's a placeholder:** The TODO in the same file (line 95) explicitly acknowledges this: display names are not yet resolvable cross-uid, so the internal profile UUID is displayed to the user instead of the child's name. This is visible on the profile picker screen.
- **Recommended fix:** As a minimum fix, replace the raw UUID display with a generic label like `l10n.child` or `l10n.profilePickerTutoredChildren` until the cross-uid read is available. The TODO already calls this out.

### L-2 — `permissions_provider.dart` hardcodes `isChildMode: false`
- **File:** `learning_tracker/lib/features/tutoring/presentation/providers/permissions_provider.dart:47`
- **Literal:** `isChildMode: false, // TODO(W6.x): read from profile settings`
- **Consumer:** All tutor permission checks depend on this provider
- **Why it's a placeholder:** Child mode gating is a security-adjacent feature for tutoring. The value is always `false` regardless of the actual profile mode, meaning if a tutor somehow accessed a child-mode profile, the permission system would not reflect that restriction.
- **Recommended fix:** Read the `profileMode` from the active profile state (already tracked in `profileModeProvider` elsewhere) and pass the actual boolean. This is a small one-line wiring fix.

---

## Methodology notes

Grep patterns used:
- ARB literals: searched for `"+12%"`, `"vs last"`, `"last week"`, `"12%"` — none found (the original was already fixed in `3c7710f2`)
- Widget literals: `"'7 DAY STREAK'"`, `"Level 4"`, `"Last 7 days"`, `"Last 29 days"`, `"Personal Best"`, `"CURRENT ACHIEVEMENT"`
- Stub/mock scan: `"stub"`, `"Stub"`, `"TODO"`, `"FIXME"`, `"mock"`, `"placeholder"` in `lib/` excluding `_test.dart`, `.g.dart`
- DateTime magic: `DateTime(20\d\d,` across all `lib/` dart files
- ARB key consumer check: `chartSevenDayStreak`, `chartCumulativeProgressSubtitle` cross-referenced against widget tree consumers
- AppBarTitle hardcoded strings: `AppBarTitle.*'.*'` pattern

False positives encountered (and excluded):
- `"chartLast7Days"` / `"chartLast30Days"` in ARB — these are static UI copy for filter chip labels (the range IS 7 or 30 days by definition), not dynamic values presented as computed
- `DateTime(2024, 1, 1)` in `calendar_position_providers.dart` — used as a data range for querying calendar DB entries (Daf Yomi schedule range), not a user-visible date
- `DateTime(2000, 1, 1)` in `progress_charts_screen.dart` — the documented bulk-prior sentinel epoch, has an explanatory comment
- `DateTime(2032, 12, 31)` — far-future DB query bound for calendar programs, not user-facing
- `dummyVerify()` in `password_hasher.dart` — timing attack mitigation, not displayed to users
- Hardcoded `Duration(days: 7)` in tutor grant TTL code — a policy constant, not a user-facing computed value
- `isChildMode: false` in `permissions_provider.dart` — flagged as LOW but the permissions system is not yet in production (tutoring is pre-launch)
- `"For Child profiles only"` / `"Badge\nCollection"` / `"Mystery\nPrizes"` — flagged via intro page but these are static UI copy in an illustrated onboarding screen; the main issue is the numeric claims ("Level 4", "7 DAY STREAK"), not these labels themselves
- `"Accept a tutor invite"` in `skipped_onboarding_cta_banner.dart` — not localized, but the button IS functional (opens paste-link dialog), so it's a localization gap, not a placeholder value
- `"Are you sure you want to exit? / Your setup progress will be lost."` in `add_track_flow_screen.dart` — static confirmation dialog copy, legitimately static
