# Entity-Model Remediation Tracker

> Mirrors the 9-workstream plan. Each task: `pending` / `in-progress` / `done` / `verified`. Updated as work proceeds.
> Key: `[ ]` pending · `[>]` in-progress · `[x]` done · `[V]` verified

---

## Wave 1 — P1 gate

### WS1 — Profile & Account Switching (DEC-11, DEC-30, DEC-29, DEC-34, D1)

- [x] WS1.auth-model   (WS1, done)      Multi-session auth design: removed signOut() from _activateLocalAccountFromLocalData; Drift DB swap + AuthState update is the sole switch mechanism; both accounts stay authenticated
- [x] WS1.switcher     (WS1, done)      Always-on avatar/menu switcher added to bottom nav bar in app_shell.dart; lists profiles + accounts; no logout; opens bottom sheet
- [x] WS1.count-gate   (WS1, done)      Count-gate: switcher hidden entirely when 1 profile AND 1 account; profile section only when ≥2 profiles; account section only when ≥2 accounts
- [x] WS1.consolidate  (WS1, done)      Removed GestureDetector switch from Settings header + parent_settings header; removed "Switch Profile" row from parent_settings; tutor bar now indicator-only; manage_learners delegates to showAddProfileDialog

**Closes:** DEC-11 (🔴), DEC-30 (🔴), DEC-29 (🟡), DEC-34 (🟡→arch), D1

### WS2 — Empty Login / Skip-to-Tutor-Home (DEC-6, cardinality)

- [x] WS2.skip         (WS2, done)      Add Skip affordance at/before the profile-creation phase in onboarding_screen.dart (not only post-profile)
- [x] WS2.relax        (WS2, done)      Relax sign_in_controller.dart:457 — 0-profile account must reach empty-login state, not forced back to Onboarding
- [x] WS2.surface      (WS2, done)      Define empty-login minimal surface (device notification toggle, device settings, hidden tutor entry); reuse skipped_onboarding_cta_banner

**Closes:** DEC-6 (🔴), Login 0..N cardinality enforcement

---

## Wave 2 — P2 gate

### WS3 — Tutor Mode Wiring end-to-end (DEC-5/8/9/10/13t/14/21/22/23/24 + G3)

- [x] WS3.3a           (WS3, done)       Parent invite entry: add "Manage tutors" to child's parent settings → navigate to InviteTutorRoute/ManageTutorsRoute/ManageGrantsRoute
- [x] WS3.3b           (WS3, done)       Tutor invitations surface: show section iff ≥1 active talmid OR ≥1 pending invitation; "View invitations" + accept/decline; fix hard-coded stub grant (accept_invite_screen.dart:110)
- [x] WS3.3c           (WS3, done)       Talmid access + PIN: resolve child name (not raw "Child:{id}"); make onTap non-null; fix PinScope resolution in router_provider.dart:65-71 to branch on OwnProfileSelection vs TutoredProfileSelection; instantiate TutorPinEntryGate (0 call sites) on talmid-view route
- [x] WS3.3d           (WS3, done)       Combined tutor surface: consume canEdit* fields (written-never-read) so tutor sees everything + edits tracks/points/rewards; remove dead/unused permissions_provider
- [x] WS3.3e           (WS3, done)       Dual-role fix: gate _isTutorSession (text_display_screen.dart:748) on active selection being TutoredProfileSelection, not on existence of any incoming grant
- [x] WS3.3f           (WS3, done)       Manage/remove + co-tutors: parent add/remove-tutor UI (Firestore rules already server-only); co-tutor equality holds by construction
- [x] WS3.3g           (WS3, done)       Removal lifecycle: wire tutor_notification_service (TutorNotificationGateway, 3 emails, 0 call sites) into client revoke/resign/decline flows
- [x] WS3.3h           (WS3, done)       Corrections: KEEP canBulkPriorCompletion:true; wire tutor bulk-mark UI; reconcile accept-invite copy to actual editable set; remove duplicate tutorGrantRepositoryProvider

**Closes:** DEC-5 (🟡), DEC-8 (⚪), DEC-9 (🔴), DEC-10 (🟡), DEC-13-tutor (⚪), DEC-14 (⚪), DEC-21 (🔴), DEC-22 (🟡), DEC-23 (🟡), DEC-24-caveat, latent-tutor-bulk-mark, latent-accept-invite-stub
**Charter flow #1 must pass after WS3.**

---

## Wave 3 — P3 gate

### WS4 — Mode Boundaries, Banner & Scope-Legible Settings (DEC-25, DEC-4, D2, D3)

- [ ] WS4.banner       (WS4, pending)    "Viewing [child]" banner + exit in app_shell.dart for parent/child-mode path (mirrors existing tutor bar)
- [ ] WS4.boundary     (WS4, pending)    Harden parent-portal boundary: parent_portal_bottom_nav.dart:146 tab-0 silently drops into child full experience — make switch-into-child explicit or gate it (DEC-4)
- [ ] WS4.settings     (WS4, pending)    Settings by scope: group settings_screen.dart under Device / Login / Profile headings (currently grouped by feature)
- [ ] WS4.login-sect   (WS4, pending)    Empty Login section guard: either build/relocate debug toggle under Login heading, or omit the heading — no empty scope group shipped

**Closes:** DEC-25 (⚪), DEC-4 (🟡), D2 (🔴), D3, Login-scope debug toggle (⚪)

### WS5 — Per-Profile Notifications (DEC-27, DEC-28 + local/cloud clobber)

- [ ] WS5.key-prefs    (WS5, pending)    Namespace reminder prefs AND notification IDs by profileId (shared_prefs_notification_preferences_repository.dart:18-44; notification_gateway.dart:13,17,30)
- [ ] WS5.per-profile  (WS5, pending)    Schedule per-profile; decouple from activeProfileIdProvider; inactive profiles' reminders fire; tap → switch into that profile then open Scheduler
- [ ] WS5.two-layers   (WS5, pending)    Add device-level OS notification toggle (layer 1, available on empty login) distinct from per-profile reminder schedules (layer 2)
- [ ] WS5.clobber      (WS5, pending)    Fix local/cloud clobber: make local storage consistently per-profile to match Firestore per-profile singleton; merger round-trip test

**Closes:** DEC-27 (🔴), DEC-28 (🔴), latent-local-cloud-clobber

### WS6 — Location Scope Consistency (DEC-26) [paired with WS5]

- [ ] WS6.location     (WS6, pending)    Store/sync location at device level (registry or shared doc), off per-profile snapshot in ui_preferences_merger.dart:21; merger round-trip test

**Closes:** DEC-26 (🟡), latent-local-cloud-clobber (location half)

### WS7 — Rewards: Redeem→Fulfil Loop (DEC-18, DEC-17, G1=spend-economy)

- [ ] WS7.balance      (WS7, pending)    Introduce stored debitable points balance (replacing/feeding monotonic SUM from points_service.dart); all readers cut over together
- [ ] WS7.reward-price (WS7, pending)    Reward = priced item with points cost (not cumulative-threshold milestone reward_milestone.dart)
- [ ] WS7.redeem       (WS7, pending)    Child redemption: spend points on a reward; parent approval/fulfilment state on the unlock/redemption record
- [ ] WS7.adjust       (WS7, pending)    DEC-17 manual adjust: parent add/deduct via adjustment ledger entry, PIN-gated, in parent mode
- [ ] WS7.child-ui     (WS7, pending)    Update child UI: "Redeem Prizes"/"Current Balance" (child_points_rewards_tab_card.dart:124,222) actually redeem

**Closes:** DEC-18 (🔴), DEC-17 (🟡)

### WS8 — Learning-Credit Integrity (latent, DEC-19)

- [ ] WS8.credit-path  (WS8, pending)    Pick one credit-policy code path: migrate lifetime/manual marking onto CompletionSource-aware BulkMarkCompletionUseCase path (option a preferred), retiring orphan ManualCompletionUseCase and parallel LearningLedgerRepository batch path
- [ ] WS8.route-guard  (WS8, pending)    Guard LifetimeMarkingRoute + LifetimeCurriculumMarkingRoute with childModeGuard + pinGuard (today authGuard only, app_router.dart:256-265)

**Closes:** latent-sentinel-date, DEC-19 harden

---

## Wave 4 — P4 gate

### WS9 — Model & Code Hygiene (latent cleanup)

- [ ] WS9.enum         (WS9, pending)    Unify UserMode vs ProfileMode into one enum; add enum/check constraint on free-text learner_profiles.mode column
- [ ] WS9.shims        (WS9, pending)    Remove "transitional shims, delete after 20.x" on production paths (auth_state_provider.dart:105-130 — promoteToCloud/demoteToLocal)
- [ ] WS9.flows        (WS9, pending)    Collapse duplicate add-profile flows; drop vestigial Account-level userMode hardcoded 'adult'
- [ ] WS9.dedupe       (WS9, pending)    Decide dedupeByEmail healing (device_registry_database.dart:148-166) under DEC-34 multi-session model; document the decision either way

**Closes:** latent-dual-enums, latent-dup-flows, latent-shims, DEC-34 cleanup

---

## Sync points

- [ ] P1               (sync, pending)   Wave 1 gate: WS1 switcher verified (profile+account, count-gated, no logout) AND WS2 empty-login reachable — both verified before WS3 starts
- [ ] P2               (sync, pending)   Wave 2 gate: Charter flow #1 + #2 pass end-to-end; all WS3 sub-tasks verified
- [ ] P3               (sync, pending)   Wave 3 gate: Banner+settings-by-scope; per-profile reminders fire when inactive; rewards spend loop works; sentinel/route-guard in place
- [ ] P4               (sync, pending)   Wave 4 gate: Location no-clobber; enums unified, shims gone, dups collapsed

---

## Verification phase

- [ ] V1.ci            (verify, pending)  Run `make ci` from learning_tracker/; must be green
- [ ] V2.review        (verify, pending)  Adversarial review squad: R1 (account/login/switching), R2 (tutor end-to-end), R3 (notif/location/settings), R4 (rewards/credit), R5 (hygiene/rules); return severity-classified findings
- [ ] V3.fix           (verify, pending)  Fix-all pass: one fix-agent per CRITICAL/HIGH; batch MEDIUM; log LOW as optional
- [ ] V4.ci-rerun      (verify, pending)  Re-run CI post-fixes; loop until green
- [ ] V5.task-truth    (verify, pending)  ⚠️ CRITICAL — Sample every done task; confirm artifact exists AND is user-reachable; upgrade done→verified or demote done→pending; loop until all verified
- [ ] V6.smoke         (verify, pending)  Final smoke: charter flow #1 (tutor) + charter flow #2 (relationship mgmt) + switcher + per-profile reminder + rewards spend; each spot screen EN+HE; offline-first holds
