# Manual Smoke Checklist (W7.25)

**For:** Daniel Niasoff  
**Date:** 2026-05-20  
**Branch:** dev  
**Prerequisite:** `flutter run` on a physical device or emulator with the app built from `dev` branch.

These tests CANNOT be verified programmatically — they require a running app.

---

## Checklist (14 items)

### 1. App launch & locale detection

- [ ] **1a** — Launch app. Confirm UI appears in English (on an EN locale device).  
- [ ] **1b** — Launch app on a HE locale device or emulator. Confirm UI appears in Hebrew with RTL layout. Navigation back arrows flip; text aligns right.

---

### 2. Onboarding — single device (own learning)

- [ ] **2a** — Fresh install or sign out. Go through "track my own learning" onboarding. Confirm sign-up flow completes and lands on dashboard.
- [ ] **2b** — Add a Daf Yomi track with **start date = today**. Confirm 0 overdue tasks, 1 "today" task visible on dashboard.
- [ ] **2c** _(B3 visual)_ — Delete the Daf Yomi track. Add a new Daf Yomi track with **start date = today−5** (5 days back). Confirm ~5 overdue tasks appear on the dashboard. Each overdue task should be dated in the past and show the overdue indicator.

---

### 3. Onboarding — "joining to tutor" branch

- [ ] **3a** — On a second device (or simulator), sign up with the "joining to tutor" branch. Confirm it reaches the Tutor PIN setup screen.
- [ ] **3b** — Complete Tutor PIN setup. Confirm the app lands on near-empty dashboard with appropriate CTAs (no tracks).

---

### 4. Single-device: mark complete (live) + streak

- [ ] **4a** — With an adult profile and a Mishnayos track, mark a lesson complete via the dashboard. Confirm: streak counter increments, gamification points awarded, task moves to "completed today".
- [ ] **4b** — Bulk-mark prior completions during AddTrack wizard ("I already learned this"). Confirm: no streak increment after bulk-mark, but siyum notification fires if a masechta was completed.

---

### 5. Two-device sync — own children

- [ ] **5a** — On device A, mark a lesson complete. On device B (same account), pull-to-refresh or relaunch. Confirm the completion appears on device B.
- [ ] **5b** — On device B, add a new track. Confirm it appears on device A after sync.

---

### 6. Two-device sync — tutor flow (end-to-end)

- [ ] **6a** — On a parent device, go to "Manage Tutors" and invite a tutor (enter tutor's email). Confirm invite email or deep-link is generated (can use logging if SendGrid not provisioned).
- [ ] **6b** — On the tutor device, accept the invite deep-link. Confirm grant activation, Tutor PIN gate prompts.
- [ ] **6c** — On the tutor device, switch to the tutored child's profile. Confirm: AppBar shows tutor indicator (icon + colour accent). "Mark Complete" buttons are disabled/hidden.
- [ ] **6d** — Tutor attempts to mark complete (if any affordance exists). Confirm: TutorWriteForbiddenException dialog appears with friendly message.
- [ ] **6e** — On the parent device, go to Audit Log viewer. Confirm a tutor access entry exists showing the tutor's name and action.
- [ ] **6f** — Parent revokes tutor access. Confirm tutor can no longer see the child's profile in their app.

---

### 7. Settings / profile

- [ ] **7a** — Settings screen: confirm all tiles visible, no crash. Account email displayed correctly.
- [ ] **7b** — Parent Settings screen (with child profile active): confirm tiles visible, no crash.
- [ ] **7c** — Profile picker: switch between profiles. Confirm active profile indicator updates.

---

## Notes for Daniel

- **Item 2c (B3)** is the most important: it directly verifies the overdue-task generation from back-dated enrolment. If this is wrong, something in `TrackCreationService` or the daily plan projection is not reading `trackingStartDate` correctly.
- **Items 6a-6f** require two physical devices or careful simulator juggling. If SendGrid is not provisioned, the invite email won't send — check logs for the invite URL instead.
- **Item 1b (Hebrew)** requires either a HE-locale device or manually setting the locale in the simulator.
