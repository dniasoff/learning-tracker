# Entity-Model Remediation Plan (2026-05-24)

> Companion to **`entity-model-audit-2026-05-24.md`**. Turns every audit finding — 🔴 DRIFT, ⚪ ABSENT, 🟡 PARTIAL, plus the latent risks — into a sequenced, testable plan. Source-of-truth intent = the decisions (DEC-1…DEC-34) in the audit doc. The data model is largely sound and **most drift is UI/wiring** — *except* **WS1** (multi-session auth: DEC-34 needs several accounts authenticated at once; today the app is single-session) and **WS7** (points become stored, debitable state instead of a derived sum), which are genuine **architecture / data-model** changes. Treat those two as the high-risk workstreams, not wiring.
>
> **Revised 2026-05-24** after an adversarial review: corrected/desk-checked citations, honest re-scoping of WS1/WS7, removed the dead G1 "ladder" branch, resolved the WS3 notify fork against the actual Cloud Function, corrected the WS8 fix, and added automated-test gates.

## Guiding constraints (project norms)

- **Incremental, under a test net** — no big-bang rewrites; each fix lands committed + regression-tested.
- **Minimal & proportionate** — smallest correct fix per item; don't over-build.
- **Pre-launch, no live users** — Drift/Firestore schema resets are safe; **no migration shims or backwards-compat** needed.
- **Offline-first** — Drift-first reads, queued writes, no network-gated UI; sync is informational.
- **All work on `dev`** — no feature branches/worktrees.

## Effort scale & citation convention

- **Effort:** S ≈ ≤1 day / one slice; M ≈ 2–4 slices; L ≈ multi-slice **and** touches a data-model or auth-model change. A slice = one committed, test-backed change.
- **Citations** are pinned by **file + symbol**; the line numbers are as-of 2026-05-24 and approximate (incremental commits shift them) — navigate by symbol, not by line.

## Decision gates (need Daniel's call before the dependent WS starts)

- **G1 — Rewards model.** ✅ **RESOLVED (DEC-32) → spend-economy.** Parent stocks rewards; **child picks & spends points**; parent fulfils. Build the full loop in WS7 (not the ladder).
- **G2 — Multi-account UX.** ✅ **RESOLVED (DEC-34) → all accounts stay signed in; instant switch, no re-login, no sign-out.** Only one active on-screen at a time. Shapes WS1.
- **G3 — Tutor powers.** ✅ **RESOLVED (DEC-33) → tutor has the FULL parent toolset** (manage tracks, configure points, configure rewards, **and bulk-mark**). Only the child's live "mark a mishna" learning stays barred. **`canBulkPriorCompletion: true` is correct — keep it, wire the UI.** Roster management stays parent-only (DEC-22).

---

## Workstreams

### WS1 — Profile & Account Switching  · P1 · (DEC-11, DEC-30, DEC-29, DEC-34, D1)
**Goal:** the always-on switcher promised in DEC-11 — the original complaint.
**⚠️ Scope reality:** DEC-34 ("all accounts stay authenticated; instant switch, no `signOut()`") is **not** a UI task. Today the app is **single-session**: one `AuthState.currentUser` (`features/account/domain/models/auth_state.dart`), one `lastActiveAccountId` (registry key, `device_registry_database.dart:170`), and Firebase Auth itself holds exactly **one** `currentUser` at a time. Keeping N accounts live simultaneously is an **auth-model change** (cache + swap credentials, or a local multi-session layer) — not an avatar menu. This is the high-risk half of WS1; design it before building the switcher UI.
**Tasks:**
- **Auth model (the hard part):** decide how multiple accounts stay authenticated at once given Firebase's single-`currentUser` constraint; switching must NOT call `signOut()`. Today switching to a local account calls `signOut()` (`account_picker_screen.dart:482`, in `_activateLocalAccountFromLocalData`).
- Add an always-on switcher affordance in `app/router/app_shell.dart` (avatar/menu), reachable from anywhere, listing this login's profiles **and** signed-in accounts; no logout.
- **Count-gate** (DEC-30): show the profile-switch entry only when ≥2 profiles; the account-switch entry only when ≥2 accounts.
- Consolidate the 3 fragmented switch entry points (Settings header, parent-settings row, tutor bar) into the one switcher; collapse duplicate add-profile flows (`add_profile_dialog` vs `manage_learners_screen`).
**Acceptance:** from any tab, switch profile and switch account with no logout **and no re-auth** (assert no `signOut()`/credential prompt fires on switch); solo single-profile/single-account user sees no switcher; a parent lands on their kid in ≤2 taps. Tests: widget/integration test for the switcher + a test that account-switch leaves both sessions authenticated.
**Depends:** — (foundational). **Effort:** **L** (was M — the multi-session auth model dominates).

### WS2 — Empty Login / Skip-to-Tutor-Home  · P1 · (DEC-6, cardinality Login 0..N)
**Goal:** make "skip profile creation → empty login" actually reachable (the tutor's profile-less home base).
**Where the block actually is:** `onboarding_screen.dart` sets `_phase = profileCreation` as the field default, **but** `initState` resumes mid-flow via `_tryResumeFromSavedState()`, so "always begins at profileCreation" isn't literally true. The real gap: the only Skip paths (`OnboardingIntent.skipForNow` handler and `_navigateToDashboardSkipped`) fire **after** `_onProfileCreated` — you can skip *track setup*, never *profile creation*. And `sign_in_controller.dart:457` routes any 0-profile account back to Onboarding.
**Tasks:**
- Offer Skip **at/before the profile-creation step**, not only after a profile exists — add a skip affordance to the profile-creation phase itself.
- Stop forcing ≥1 profile: relax the `finalProfileCount == 0 && !cloudAccountHasProfiles → OnboardingRoute` branch (`sign_in_controller.dart:457`) to permit a resting empty-login state.
- Define the empty-login minimal surface (device notification toggle from WS5 + device settings + the hidden tutor entry from WS3); reuse `skipped_onboarding_cta_banner`.
**Acceptance:** a fresh sign-in can reach a usable zero-profile state; can later add a profile; matches DEC-6. Integration test: sign in → skip at profile creation → land on the empty-login surface → add a profile later.
**Depends:** — . **Effort:** S–M.

### WS3 — Tutor Mode Wiring (end-to-end)  · P1 · (DEC-8, DEC-9, DEC-10, DEC-13-tutor, DEC-14, DEC-21, DEC-22, DEC-23, DEC-24-caveat + latent)
**Goal:** ignite the fully-built-but-stranded tutor engine. Backend (models, use-cases, CF, rules, PIN service, audit log, notifications) exists — this is wiring + a few corrections.
**Tasks (sub-stream):**
- **3a Parent invite entry (DEC-8):** add "Manage tutors" to the child's parent settings → navigate to `InviteTutorRoute`/`ManageTutorsRoute`/`ManageGrantsRoute` (today reachable only in generated router). Invite-by-email already correct (DEC-20).
- **3b Tutor invitations surface (DEC-8 visibility rule):** show a section/box **iff ≥1 active talmid OR ≥1 pending invitation** — pending invitations currently don't surface (`tutored_children_section.dart:35` gates on active only). Add "View invitations" + accept/decline; fix the hard-coded stub grant in `accept_invite_screen.dart:110`.
- **3c Talmid access + PIN (DEC-13-tutor, DEC-24):** make talmid rows interactive (resolve child name, not raw `Child:{id}` at `tutored_children_section.dart:99`; `onTap:null` at `:142`). Wire the tutor PIN: `PinGuard.getScope` in **`lib/app/router/router_provider.dart:65-71`** (NOT the 3-line re-export at `core/navigation/router_provider.dart`) hard-codes `PinScope.parent(selectedProfileId)`. `PinScope.tutor(profileId)` **already exists** (`pin_scope.dart:18`) and `PinService` keys an independent tutor hash — so the fix is to **resolve scope from the active selection** (`OwnProfileSelection`→parent, `TutoredProfileSelection`→tutor, the same split `session_role`/`permissions_provider` already make) and add the `PinScopeTutor` branch to `onSessionAuthenticated`/`onSessionLocked` (+ a tutor-authenticated-profile provider). Then instantiate `TutorPinEntryGate` (zero call sites today) on the talmid-view route so a PIN is required on **every** talmid view.
- **3d Combined tutor surface (DEC-9/14):** consume the `tutor_permissions` VO (the `canEdit*` fields are **written-never-read** — verified) so a tutor sees everything the child sees and edits tracks/points/rewards in one surface; "cannot learn" already enforced (`mark_live_completion_use_case.dart:54-66`). Remove the unused `permissions_provider` — note its header still claims a "static owner session", but the body already branches on selection type (`OwnProfileSelection`/`TutoredProfileSelection`); it's dead either way (grep confirms no real call sites).
- **3e Dual-role fix (DEC-21):** `_isTutorSession` (`text_display_screen.dart:748`) is a **method that returns true whenever ANY incoming grant is active** (it reads `incomingTutorGrantsProvider`) — it is *not* a global flag and is *not* keyed to which profile is on-screen. Bug: a tutor who also holds their own adult profile gets live-mark wrongly disabled on their **own** profile. Fix: gate on whether the **active selection** is a `TutoredProfileSelection`, not on the mere existence of an incoming grant.
- **3f Manage/remove + co-tutors (DEC-10, DEC-22):** parent add/remove-tutor UI (rules already server-only); co-tutor equality holds by construction.
- **3g Removal lifecycle (DEC-23):** the deployed Cloud Function (`functions/src/index.ts`) transitions grant **state** on account-deletion (`revoked_by_parent`/`revoked_by_tutor`) and runs the audit purge + bulk-completion proxy, but sends **no emails/notifications** (no mailer/FCM anywhere in `functions/src` — verified). `tutor_notification_service` (`TutorNotificationGateway`, all 3 emails present, **zero call sites**) is the intended sender, so **wire it into the client revoke/resign/decline flows** — there is no existing sender to defer to. (Immediate revoke itself already works.)
- **3h Corrections (G3=DEC-33):** **KEEP** `tutor_permissions.canBulkPriorCompletion: true` (tutors get full parent powers incl bulk-mark) and **wire the tutor bulk-mark UI**; reconcile accept-invite copy to the actual editable set (tracks/points/rewards + bulk-mark); remove the duplicate `tutorGrantRepositoryProvider`.
**Acceptance:** the **charter flow** passes end-to-end — parent invites by email → invitee sees "View invitations" → accepts → talmid appears in a separate section → tutor PINs in → views all, **edits tracks/points/rewards and can bulk-mark (full parent toolset)**, but **cannot** live-mark a mishna; parent/tutor can remove, other side notified, re-invite works. Land it as a charter-flow integration test (see Testing strategy).
**Sub-stream order:** 3a→3b (invite/accept surface) → **3c (PIN + access)** → 3d (edit surface) → 3e (dual-role) → 3f→3g (manage/remove + notify) → 3h (bulk-mark UI). **3c gates 3d** (no edit surface without the PIN/access path).
**Depends:** WS2 (empty-login home), WS1 (switcher reaches talmidim). **Effort:** L.

### WS4 — Mode boundaries, "Acting-as" banner & scope-legible settings · P2 · (DEC-25, DEC-4, D2, D3)
**Goal:** stop parent/child "leaking" and make scopes legible.
**Tasks:**
- **"Viewing [child]" banner + exit** in `app_shell.dart` for the parent/child-mode path (mirror the existing tutor bar) — absent today (DEC-25, D3).
- Harden the parent-portal boundary: tab-0 silently drops into the child's full experience (`parent_portal_bottom_nav.dart:146`); make "switch into child" explicit or gate it (DEC-4).
- **Settings by scope (D2):** group `settings_screen.dart` under Device / Login / Profile headings (today grouped by feature; device-level permissions/location interleaved with profile-level items). Note `scope_selection_screen` is *curriculum* scope — unrelated.
- **Don't ship an empty Login section:** the audit found the only Login-scoped datum — the **debug toggle** — does **not exist** (⚪). Either build/relocate it under the Login heading or omit the heading; a three-scope layout with an empty "Login" group is dead UI.
**Acceptance:** while inside a child, the banner is always visible with a one-tap exit; settings visibly separate the three scopes (no empty scope group).
**Depends:** WS1 (switch semantics). **Effort:** M.

### WS5 — Per-Profile Notifications (two layers) · P2 · (DEC-27, DEC-28 + local/cloud clobber)
**Goal:** per-learner reminders + a device-level OS toggle.
**Tasks:**
- **Key reminders by profile:** reminder prefs use global SharedPrefs keys (`shared_prefs_notification_preferences_repository.dart:18-44`) and fixed singleton notification IDs (`notification_gateway.dart:13,17,30`). Namespace prefs **and** notification IDs by `profileId`.
- **Schedule per-profile, fire regardless of active (DEC-28):** decouple from `activeProfileIdProvider` (`notification_providers.dart:407`); inactive profiles' reminders must still fire; tap handler (`_handleNotificationTap`, `notification_initializer.dart:34`) → **switch into that profile** then open Scheduler.
- **Two layers (DEC-27):** add a device-level OS notification toggle (layer 1, available on empty login) distinct from per-profile reminder schedules (layer 2). Today feature toggles just call `requestPermission()`.
- **Fix local/cloud clobber:** notifications are global locally (SharedPrefs keys + singleton IDs) but a **per-account/per-profile singleton in Firestore** (`notification_settings_merger.dart:42`) → switching+syncing can clobber. Make storage consistently per-profile. *(There are no "contradictory comments" at `:42` — that earlier claim was unfounded; the defect is the local-global vs cloud-per-profile mismatch itself.)*
**Acceptance:** each profile has its own reminder schedule that fires whether or not it's active; OS on/off is separate; no cross-profile clobber on sync.
**Sync risk:** WS5 edits the merger surface implicated in the 2026-05-17 sync crisis. Land each change with a **merger round-trip test** (write→push→pull→merge preserves per-profile separation) and a green `make ci` run — not just a manual walkthrough.
**Depends:** WS1 (tap→switch). **Pairs with WS6** (same merger surface — `ui_preferences_merger` carries location). **Effort:** M–L.

### WS6 — Location Scope Consistency · **P2 (paired with WS5)** · (DEC-26)
**Goal:** location truly Device-scoped, no per-profile clobber.
**Tasks:** location is device-global locally (`sacred_time_preferences.dart:4`) ✅ but the cloud copy rides each profile's UI-prefs doc with LWW across profiles (`ui_preferences_merger.dart:21`). Store/sync location at device level (registry or a single shared doc), off the per-profile snapshot.
**Why paired with WS5:** location and notifications are two halves of one "local-global / cloud-per-profile" clobber bug, and location physically rides the `ui_preferences_merger` snapshot — splitting them across phases leaves a half-fixed clobber window. Same merger round-trip test requirement as WS5.
**Acceptance:** changing location on one profile doesn't get overwritten by another profile's sync; one device = one location. Merger round-trip test.
**Depends:** — (but land alongside WS5). **Effort:** S.

### WS7 — Rewards: Redeem→Fulfil Loop · P2 · **G1 RESOLVED = spend-economy (DEC-32)** · (DEC-18, DEC-17)
**Goal:** build the configure→redeem→fulfil loop where the **child picks & spends**.
**⚠️ Scope reality:** today points are a **derived, monotonic** value — `SUM(completion.points)` (`points_service.dart`, the fold in `_sumPointsForRewardEligibleTracks`), never stored, never debited. A debitable balance + adjustment ledger turns points into **stored mutable state**, which changes every reader (dashboard gating, reward eligibility, the points sync merger). This is a **data-model change**, not UI wiring — and since pre-launch = no migration, every reader must be cut over together.
**Tasks (spend-economy — confirmed, G1=DEC-32):**
- Introduce a stored **points balance** that can be **debited** (replacing/feeding today's derived sum).
- **Reward = priced item** (cost in points), not a cumulative-threshold milestone (`reward_milestone.dart`).
- **Child redemption** (spend points) + **parent approval/fulfilment** state on the unlock/redemption record.
- **DEC-17 manual adjust:** parent add/deduct via an adjustment ledger entry (PIN-gated, in parent mode).
- Update child UI so "Redeem Prizes"/"Current Balance" (`child_points_rewards_tab_card.dart:124,222`) actually redeem.
**Acceptance:** child spends points on a configured reward, parent approves/fulfils, balance decreases; parent can add/deduct; **every points reader reflects the debited balance**. Unit + widget tests for debit / redeem / adjust.
**Depends:** — (G1 resolved = spend). **Effort:** **L** (data-model change — see scope reality).

### WS8 — Learning-Credit Integrity · P2 · (latent risks around DEC-19)
**Goal:** keep bulk/lifetime marking from leaking into streak/recent activity.
**The real defect (two divergent bulk stacks):** the sentinel + three-tier gating live **only** in `BulkMarkCompletionUseCase` → `CompletionRepository.bulkMarkComplete` (sentinel `DateTime.utc(2000,1,1)` at `bulk_mark_completion_use_case.dart:85`, driven by `CompletionSource`). The **lifetime/manual** path is a *separate* stack — `LearningLedgerRepositoryImpl.recordCompletion` (writes `nowUtc` at `:101`) and `recordCompletionsBatch` (`:156`) — that exposes **no `completedAt`/`CompletionSource` parameter at all**, so it *cannot* emit the sentinel. The lifetime screen calls `recordCompletionsBatch` directly (`lifetime_marking_screen.dart:411`). ⚠️ The previously-proposed "route through `ManualCompletionUseCase`" does **not** fix this — that use-case just calls `recordCompletion`, which still writes `nowUtc`. The two stacks also write **different DAOs** (`learningLedgerDao` vs `completion_dao`).
**Tasks:**
- **Pick one credit-policy code path.** Either **(a)** migrate lifetime/manual marking onto the `CompletionSource`-aware `BulkMarkCompletionUseCase`/`CompletionRepository` path (both `bulkInTrack` and `lifetimeOnly` already enforce the sentinel and suppress streak/points — choose the source matching the intended tier: `bulkInTrack` credits siyumim+lifetime, `lifetimeOnly` is lifetime-only), retiring the orphan `ManualCompletionUseCase` **and** the parallel `LearningLedgerRepository` batch path; or **(b)** add `CompletionSource`/`completedAt` support to `LearningLedgerRepository` so it applies the same sentinel. **(a) preferred** — one credit-policy code path. This is a real decision (different DAOs), not a one-liner.
- **Guard `LifetimeMarkingRoute` and `LifetimeCurriculumMarkingRoute`** with `childModeGuard + pinGuard` (today `[authGuard]` only, `app_router.dart:256-265`; defense currently lives only in the repo).
**Acceptance:** parent bulk/lifetime marks credit lifetime/siyumim per the chosen tier, never streak/recent (assert the sentinel date on stored rows); routes are child-mode + PIN-guarded. Unit test proving non-live sources write the sentinel.
**Depends:** — . **Effort:** M (was S–M — stack convergence is the work).

### WS9 — Model & Code Hygiene · P3 · (latent cleanup)
**Tasks:**
- Unify `UserMode` vs `ProfileMode` into one enum; add an enum/check constraint on the free-text `learner_profiles.mode` column.
- Remove the "transitional shims, delete after 20.x" still on production paths (`auth_state_provider.dart:105-130` — `promoteToCloud`/`demoteToLocal`).
- Collapse duplicate add-profile flows; drop the vestigial Account-level `userMode` hardcoded `'adult'`.
- Decide whether `dedupeByEmail` healing (`device_registry_database.dart:148-166`) stays (defensive) or is removed — and decide it against the **DEC-34 multi-session** model, **not** a "one-active-account" assumption. DEC-34 *abolishes* one-active-account (several accounts stay authenticated), so the dedupe must be re-evaluated under that model rather than assuming WS1 will re-stabilize a single active account. Document either way.
**Acceptance:** one mode type end-to-end; no dead shims; single add-profile flow.
**Depends:** WS1 (auth model settled per DEC-34). **Effort:** M.

---

## Sequencing

- **Phase 1 (P1):** WS2 and WS1 start in parallel (WS2 unblocks WS3's empty-login home; WS1's switcher reaches talmidim), then WS3. **WS1 is now L** — start its auth-model design first; it is the long pole alongside WS3.
- **Phase 2 (P2):** WS4 and WS8 in parallel; **WS5 + WS6 together** (one merger surface); WS7 (G1 resolved = spend — treat as a data-model change, cut all points readers over together).
- **Phase 3 (P3):** WS9.
- **WS3 sub-stream order:** 3a→3b → 3c (PIN+access, gates 3d) → 3d → 3e → 3f→3g → 3h.
- **Gates:** G1/G2/G3 are already resolved (see top); they shaped WS7/WS1/WS3 respectively.

## Coverage matrix — every audit finding → workstream

| DEC / item | Verdict | Workstream |
|---|---|---|
| DEC-1 app permissions=Device | ✅ | — |
| DEC-2 notifications profile-scoped | ✅→see WS5 | WS5 |
| DEC-3 legible scopes + switching | (rolls up) | WS1, WS4 |
| DEC-4 parent surface manage-only | 🟡 | WS4 |
| DEC-5 tutor hidden | 🟡 | WS3 |
| DEC-6 skip→empty login | 🔴 | WS2 |
| DEC-7 profile types adult/child | ✅ | — |
| DEC-8 tutor invite flow + visibility | ⚪ | WS3 (3a,3b) |
| DEC-9 tutor combined surface | 🔴 | WS3 (3d) |
| DEC-10 M:N severable | 🟡 | WS3 (3f) |
| DEC-11 always-on switcher | 🔴 | WS1 |
| DEC-12 reopen smart | ✅ | — |
| DEC-13 PIN (parent ✅ / tutor ⚪) | mixed | WS3 (3c) |
| DEC-14 tutor edit surface | ⚪ | WS3 (3d) |
| DEC-15 any adult manages | ✅ | — |
| DEC-16 adults un-gamified | ✅ | — |
| DEC-17 points auto + parent adjust | 🟡 | WS7 |
| DEC-18 rewards redeem→fulfil | 🔴 | WS7 (G1) |
| DEC-19 learning child-only | ✅ (harden) | WS8 |
| DEC-20 invite by email | ✅ | — |
| DEC-21 tutor dual-role | 🔴 | WS3 (3e) |
| DEC-22 co-tutor / parent manages | 🟡 | WS3 (3f) |
| DEC-23 removal lifecycle | 🟡 | WS3 (3g) |
| DEC-24 talmidim section | ✅(caveat) | WS3 (3c) |
| DEC-25 acting-as banner | ⚪ | WS4 |
| DEC-26 location scope | 🟡 | WS6 |
| DEC-27 two notification layers | 🔴 | WS5 |
| DEC-28 per-profile reminders | 🔴 | WS5 |
| DEC-29 multi-account + sign-out | 🟡 | WS1 (G2) |
| DEC-30 switcher count-gating | 🔴 | WS1 |
| DEC-31 learning layer endorsed | ✅ baseline | — |
| DEC-34 multi-account stay-authed | 🟡 → arch | WS1 |
| D2 settings by scope | 🔴 | WS4 |
| D3 parent/child leak | (mitig.) | WS4 |
| Login-scope debug toggle | ⚪ absent | WS4 |
| Latent: tutor bulk-mark default | risk | WS3 (3h, G3) |
| Latent: sentinel date / route guard | risk | WS8 |
| Latent: local/cloud notif+loc clobber | risk | WS5, WS6 |
| Latent: dual enums / dup flows / shims | cleanup | WS9 |
| Latent: accept-invite stub / UI copy | risk | WS3 (3b,3h) |

**Every 🔴/⚪/🟡 verdict and latent risk maps to a workstream — including the previously-omitted Login-scope debug toggle (WS4) and DEC-34 (WS1).**

## Testing strategy

- **Automated tests are the unit of "done", not manual runs.** Each WS lands with named tests (the repo's `test/story_acceptance/` + widget/integration), and **`make ci` must be green** before any WS is marked complete (per `learning_tracker/CLAUDE.md`). Manual in-app runs are a supplement, not the gate.
- **Charter flows (must pass):** (1) tutor invite → accept → **PIN** → view/edit/bulk-mark, **live-mark blocked**, end-to-end (WS3 acceptance); (2) relationship management — add/remove from both ends, section visible iff ≥1 talmid OR ≥1 invitation.
- **Sync-crisis guard (WS5/WS6):** merger **round-trip** tests (write→push→pull→merge preserves per-profile separation; device-scoped data not clobbered by another profile's sync). This is the surface that broke on 2026-05-17 — do not rely on manual checks.
- **Regression net by WS:** switcher + account-switch-keeps-auth (WS1); skip→empty-login (WS2); PIN scope resolution + `TutorPinEntryGate` (WS3); sentinel-on-non-live-source (WS8); debit/redeem/adjust (WS7); per-profile reminder fires while inactive (WS5).
- Incremental: each WS lands as committed, test-backed slices on `dev`.
