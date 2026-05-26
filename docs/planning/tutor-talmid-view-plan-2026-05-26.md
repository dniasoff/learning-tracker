# Tutor "Talmid View" — Implementation Plan

**Date:** 2026-05-26
**Status:** Draft for sign-off (Daniel chose "plan it properly first")
**Builds on:** `docs/planning/tutor-mode-brief.md` (use case #4 "Tutor a child")
**Scope:** The unbuilt half of tutor mode — a tutor actually **browsing and configuring a talmid's live data**. Invite / accept / grant / revoke / resign / audit-log are already built and working.

---

## 1. Current state (verified in code)

**Built & working:**
- Invite → pending grant (`inviteTutor`), now snapshotting `child_name` / `parent_name`.
- In-app discovery of pending invites by email (`listTutorGrants` mode `pending_for_me`) + accept card on the profile picker.
- Accept (`acceptTutorInvite`) → `tutor_active_access/{tutorUid}_{parentUid}_{profileId}` written by CF; Tutor PIN setup.
- Picker shows "Talmid Profiles" with the active grant; `ActiveTutoredProfileSelection.enter()` sets a context flag.
- Firestore rules: `hasActiveTutorAccess(ownerUid, profileId)` grants tutor **read** access to the child's subcollections.

**Missing (the gap):**
- **Nothing in the data layer reads `ActiveTutoredProfileSelection`.** `activeProfileIdProvider` derives only from `selectedProfileIdProvider`; every dashboard / progress / learning / scheduler provider reads the tutor's **own** local Drift profile.
- Entering a talmid currently routes to `ManageGrantsRoute` (placeholder) — `tutored_children_section.dart:338`.
- No mechanism fetches the child's data (it lives in the **parent's** Firestore: `users/{parentUid}/learner_profiles/{childId}/…`), and no write path targets that namespace.

---

## 2. Goal

When a tutor taps a talmid (after Tutor-PIN), land them **inside that child's normal app** (dashboard / learn / progress / settings) showing the **child's live data**, read-only except where `TutorPermissions` grant edit rights, and with **live forward completions always blocked** (`canMarkLiveCompletion = false`).

---

## 3. Architecture decision

### Option A — Read-only local mirror (RECOMMENDED)
On entering a talmid, **pull the child's data from the parent's Firestore into the tutor's local Drift** under a synthetic local profile, reusing the **existing per-entity merge pipeline** (`lib/core/sync/merge/*` — completions, bookmarks, ledgers, goals, tracks, study-day configs, etc.). Resolve `activeProfileId` to that mirrored profile, and the **entire existing UI renders the talmid unchanged**.

- **Pros:** Massive reuse — the UI, scheduler, progress all "just work" since they read local Drift by profileId. Works offline after first pull. One central resolution change.
- **Cons:** Pull/refresh lifecycle; mirror must be marked read-only & cleaned up; write-redirection needed for edits.

### Option B — Direct remote reads
Re-plumb every provider to optionally read the parent's Firestore directly (no mirror).
- **Pros:** Always live, no local copy.
- **Cons:** Invasive (every provider needs a remote variant), poor offline, large surface area, easy to leak the tutor's data into the child's view or vice-versa.

**Recommendation: Option A.** It aligns with the offline-first architecture and reuses the merge infrastructure that already exists for exactly this shape of problem (pull a namespace → local Drift).

---

## 4. Design (Option A)

### 4.1 Identity & storage
- The grant carries `childProfileId` (the child's id **in the parent's account**) + `parentUid`. The tutor's local Drift autoincrements its own ids → **id collision risk**.
- **Introduce a synthetic local "tutored profile"**: a local `learner_profiles` row (new local id) flagged `is_tutored` + a mapping `(local_id ↔ parentUid + remoteChildProfileId + grantId)`. All mirrored child data is stored under the **local** id, so existing providers work unchanged.
- Mark the mirrored profile + its rows **read-only / mirrored** so they're never pushed up the tutor's own outbox.

### 4.2 Profile resolution (central change)
- `activeProfileIdProvider` (or a new `effectiveProfileIdProvider` it delegates to): when `ActiveTutoredProfileSelection != null`, return the **synthetic local tutored profile id**; otherwise the tutor's own selected profile. Single chokepoint → whole UI follows.

### 4.3 Tutored pull
- A "tutored pull" sources from `users/{parentUid}/learner_profiles/{childId}/<coll>` (NOT the tutor's own namespace) and routes each collection through the **existing mergers** into the mirrored local profile.
- Hook near `sync_orchestrator.dart` / `resolve_profile_id_provider.dart`; triggered on talmid entry + manual refresh.
- Decision needed: **one-shot pull** vs **live listeners** while in the talmid view (see §8).

### 4.4 Writes (configure)
- Edits permitted by `TutorPermissions` (tracks / goals / stages / rewards / study-days / points / bulk-prior / reset) must write to the **parent's namespace**, server-side, gated by the grant.
- Reuse / extend Cloud Functions (Admin SDK) so the tutor's edits land under `users/{parentUid}/…` with grant + permission verification — the client outbox cannot write another user's namespace directly (rules forbid tutor **writes**, only reads).
- **`canMarkLiveCompletion = false` is absolute** — live forward completion UI is hidden/blocked in the talmid view (already have `tutorCannotMarkLiveCompletion` copy).

### 4.5 Navigation
- `tutored_children_section.dart:338`: after PIN + `enter(selection)`, **`replaceAll([AppShellRoute()])`** (the talmid's dashboard), not `ManageGrantsRoute`.
- App shell already shows the `_TutorModeIndicatorBar` when a tutored selection is active.

### 4.6 Exit & cleanup
- Exiting the talmid (`ActiveTutoredProfileSelection.exit()` / banner) clears the selection and **purges or marks-stale the mirror** (decision §8), returns to the tutor's own context / picker.

### 4.7 Offline
- After first successful pull, the mirror renders offline (read-only). Edits queue and flush via the CF path when online.

---

## 5. Firestore rules — verification required
- Confirm `hasActiveTutorAccess(ownerUid, profileId)` is applied to **every** subcollection the mirror reads: completions, bookmarks, learning_ledger, points_ledger, streak_events, goals, curriculum_tracks, study_day_configs, stage_definitions, reward_*; and the profile doc itself.
- Confirm **writes** remain CF-only (no client tutor writes).

---

## 6. Permission → surface mapping
| Surface | Gate |
|---|---|
| Dashboard / Progress (view) | `canViewProgress` |
| Content / Learn (view) | `canViewContent` |
| Mark live completion | **always blocked** (`canMarkLiveCompletion=false`) |
| Bulk prior completion | `canBulkPriorCompletion` |
| Reset completion | `canResetCompletion` |
| Edit goals / stages / rewards / study-days / points | respective `canEdit*` |

---

## 7. Phased implementation
1. **P1 — Read-only viewing:** synthetic tutored profile + mapping; profileId resolution; tutored pull (one-shot) reusing mergers; navigation → shell; exit/cleanup; rules verification. *Outcome: tutor can browse the talmid's dashboard/progress/learn, read-only.*
2. **P2 — Permission-gated edits:** CF write paths for permitted edits (tracks/goals/stages/rewards/study-days/points) targeting the parent namespace; hide/disable un-permitted controls; block live completions.
3. **P3 — Liveness & polish:** live listeners vs refresh, stale indicators, multi-talmid switching, audit-log writes for tutor edits.

---

## 8. Decisions (resolved 2026-05-26)
1. **Pull model:** ✅ **Snapshot on entry** + manual refresh (one-shot pull; no live listeners in v1).
2. **Mirror lifecycle:** ✅ **Cache between sessions** — persist the mirror for fast re-entry/offline; wipe only when the grant is revoked/resigned or the tutor account signs out.
3. **v1 edit scope:** ✅ **Bundle key edits** — first release includes read-only browsing **plus** Manage Tracks + Bulk-prior completion (both permission-gated). Other edits (goals/stages/rewards/study-days/points) follow.
4. **Privacy:** ✅ Caching the child's data on the tutor's device is acceptable; mirror is wiped on **revoke/resign/sign-out**.

### Resulting v1 build = P1 (read-only) + the two bundled edits from P2
- Read-only: dashboard / progress / learn render the cached talmid mirror.
- Editable in v1 (if permitted): **Manage Tracks** (`canEditStages`/track config) + **Bulk-prior completion** (`canBulkPriorCompletion`), via CF writes to the parent namespace.
- Live forward completion: blocked always.

---

## 9. Risks
- **Data isolation:** the synthetic-profile + read-only marking must guarantee the talmid's mirror never pushes into the tutor's own cloud data, and the tutor's own data never leaks into the talmid view. Strong tests required.
- **Rules gaps:** any subcollection missing the tutor-read clause → silent empty sections (same class as the bugs hit this session).
- **Scope creep:** P2 edits touch many CFs; keep P1 strictly read-only to land value early.
