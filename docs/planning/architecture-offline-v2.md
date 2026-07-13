# Offline-First Architecture v2 — Hard-Tier Auth Model

**Date:** 2026-04-10
**Status:** Decided — Supersedes 2026-03-27 architecture
**Author:** Mary (Business Analyst) with Daniel
**Origin:** Slack thread with Yafet Tesfaye (2026-04-10) triggered re-examination of local-first auth model.

---

## 1. What This Supersedes

| Document | Status |
|---|---|
| `offline-first-analysis-2026-03-27.md` | **Deleted 2026-04-10** — content absorbed here or into the still-canon companion docs |
| `local-first-auth-abstraction-layer.md` | **Deleted 2026-04-10** — fully superseded |
| `two-database-drift-architecture.md` | **Still canonical** — inherited unchanged (see §5) |
| `calendar-cycle-computation-analysis.md` | **Still canonical** — inherited unchanged (see §5) |

> ✅ **Tech debt closed.** This box originally flagged that production code still implemented the deleted March architecture — sealed `AppAuthState`, `LocalAuthGuard`, anonymous `localUid`, deferred/optional account creation. That is no longer true: none of those constructs exist as live classes in `learning_tracker/lib/` today (`grep -rl 'AppAuthState\|LocalAuthGuard\|localUid' learning_tracker/lib` returns only doc-comments in `auth_state.dart`, `auth_state_provider.dart` (and its generated mirror `auth_state_provider.g.dart`), and `auth_guard.dart` that cite the replaced v1 names for context — no `class AppAuthState` or `class LocalAuthGuard` definitions remain). The v2 target model described in this doc has shipped: [`AccountTier`](../../learning_tracker/lib/core/domain/value_objects/account_tier.dart), the argon2id password hash column on `Accounts`, and [`UpgradeToCloudService`](../../learning_tracker/lib/features/account/domain/services/upgrade_to_cloud_service.dart) implementing the local→cloud upgrade flow (§4.3) are all live in the codebase.

---

## 2. Why the Change

The March 2026 architecture treated local users as **anonymous** — a generated `localUid` UUID, no email, no password, no sign-in screen. Account creation was optional and deferred. It was designed to hide auth complexity from offline users entirely.

The cost of that model was hidden in the implementation: a parallel auth state hierarchy (`LocalAuthState` / `CloudAuthState`), an abstraction layer over Firebase, a UID migration step on upgrade, and a permanent two-code-path burden on every feature that touched identity. ~800 lines of design work, and every future feature has to remember there are two kinds of user.

**The new model: one auth concept, two storage backends.** Every user has an account with email + password. The only question is *where the credentials live*: Firebase (cloud-born) or local SQLite (local-born). Tier is set at signup and immutable. No abstraction layer, no migration step, no two-code-path hedge.

**Trade-off accepted:** Offline users now see a sign-in screen and must invent a password. This is a small UX cost that buys a large reduction in architectural complexity and technical debt.

---

## 3. Mental Model

- **Tier is set at signup and is immutable.** A cloud-born account stays cloud-born. A local-born account stays local-born unless explicitly upgraded (one-way) via the flow in §4.3.
- **"Online" at signup determines tier.** If the device has internet at signup, the user gets the cloud path (Firebase Auth + Firestore sync). If not, they get the local path (SQLite-backed auth, no cloud identity). The network-state-at-signup check is the only tier decision the app ever makes automatically.
- **Tier is not the same as current network state.** A cloud-born user can go offline for weeks and still use the app fully — their session persists locally (§4.5). A local-born user never gains a cloud identity just by coming online.
- **Local-first data always.** Regardless of tier, the app reads and writes to local SQLite as the source of truth. Sync is a background projection to Firestore for cloud-born users only. Sync is async and non-blocking — the app never waits on the network to render a screen.
- **Two databases:** Content DB (read-only, bundled, replaced on app update) and User DB (read-write, synced to Firestore for cloud-born users). Unchanged from the March two-DB split.

---

## 4. Decisions

### 4.1 Conflict Resolution (NEW — not covered in March architecture)

Multi-device and offline-edits-meet-cloud-state conflicts are resolved by a **hybrid per-data-type strategy**:

| Data Type | Strategy | Notes |
|---|---|---|
| Profile settings (name, avatar, active track) | Last-write-wins (LWW) by `updatedAt` | Rarely conflicts in practice |
| Progress markers (completions, read positions) | Merge-forward (union of completed items; max of read positions) | If either side says "done", it's done |
| Streaks | Event log, reduced to state | Append-only events with timestamps; each device reduces independently and converges |
| XP / gamification | Event log, reduced to state | Same as streaks — events are the source of truth, state is derived |
| Bookmarks, Goals, custom configs | LWW by `updatedAt` | User edits are infrequent, LWW is fine |

**Design target:** zero data loss for progress, streaks, and XP. **Worst-case tolerance:** a single day of offline work could be lost under catastrophic conflict scenarios — acceptable but should be rare.

**Implementation note:** Streak and XP tables become append-only event logs (`streak_events`, `xp_events`), with derived state cached in the existing `Streaks` and reward-summary tables. Sync pushes events, not state. State is recomputed locally whenever events change.

### 4.2 Local Password Storage

Local-born accounts store credentials as **argon2id hash in SQLite**, in the `UserProfiles` table alongside the email. UX parity with the cloud path: same sign-up and sign-in screens, just no network call.

- **No recovery path.** If a local-born user forgets their password, their account (and all progress) is unrecoverable. This must be surfaced **explicitly and prominently** at signup — the user must acknowledge it.
- **Argon2id parameters** must be tuned for low-end Android target (API 21). Follow-up task: benchmark memory/iterations/parallelism to land in the ~250ms range on target hardware.
- **Optional secondary defense:** also store the hash (or a derived key) in Android Keystore / iOS Keychain. Defers to implementation, not blocking this decision.

### 4.3 Local → Cloud Upgrade Path

Local-born users can upgrade to cloud-backed storage via an **explicit, guided UX flow**. Upgrade is one-way.

When a local-born user chooses to upgrade:

1. **Check for email collision with existing Firebase account.**
2. **No collision** → promote-in-place: create Firebase Auth user with the same email + password, enable sync, push the local User DB to Firestore. Zero data loss.
3. **Collision detected** → guided merge flow. Show the user what data exists on each side (local vs cloud account), and let them choose explicitly:
   - **Upload local into cloud** → sign in to the existing cloud account, merge local data up (merge rules per §4.1).
   - **Keep cloud, discard local** → sign in to the existing cloud account, local data is cleared.
   - **Cancel** → back out, local account unchanged.

**No silent auto-merge, ever.** The merge flow is its own UX spec and should be treated as real design work — not an afterthought.

### 4.4 Content DB Versioning

**v1: blow-and-replace on app update.** Content DB ships in the APK as `seed.db.gz`, decompressed on first launch (or on version bump), stored in a separate SQLite file from the User DB. Versioned via `content_schema_version`. On app update, the old content.db is deleted wholesale and replaced from the new bundled asset.

**v2: delta patches — deferred until proven necessary.** Triggers for revisiting:
- Content update cadence exceeds app release cadence (e.g. content team shipping corrections weekly)
- APK or update bandwidth becomes a measured user complaint

**Design discipline:** Content DB and User DB are separate files from day one, so the door stays open for delta patches without a rewrite.

### 4.5 Google Sign-In & Session Persistence

**Google Sign-In is supported on the cloud-born path alongside email/password.** The local-born path is email/password only by definition — no network at signup, no Google.

**Session persistence:** trust the locally cached Firebase session **indefinitely** (or a very long window, e.g. 30+ days). A cloud-born user can operate offline for weeks without getting locked out. Re-authentication happens opportunistically on reconnect, not on a timer.

**Rationale:** In a local-first app, locking a user out because their session token expired while offline would be a catastrophic UX failure. The security tradeoff is accepted: a lost device grants access to the app until the user signs out remotely.

**Startup behavior:**
- `Firebase.initializeApp()` is called in the background after `runApp()`. App launches without waiting for Firebase.
- `GoogleSignIn.initialize()` is deferred until the user actively taps the Google sign-in button.
- Neither is on the startup critical path. (This inherits from the March architecture — unchanged.)

### 4.6 Offline Mode UX Surface

Two offline contexts, two different UX treatments:

**Cloud-born user, temporarily offline:**
- **Subtle top banner** when offline, not dismissible. Communicates: "Offline — changes will sync when you're back."
- Banner disappears automatically when connectivity returns and sync catches up.

**Local-born user (always offline with no backup):**
- **Hard warning at signup** — user must acknowledge: "This account exists only on this device. If you forget your password or lose this device, your data cannot be recovered."
- **Persistent "no backup" badge** in the profile area, always visible. Tapping it opens the upgrade flow (§4.3).
- **No top banner** for local-born users — "offline" is their permanent state, not news.

**Deferred to UX spec phase (not blocking architecture):**
- First-time-offline toast semantics for cloud-born users
- Per-action sync indicators (likely not needed — persistent banner is enough)
- Contextual warnings on destructive actions for local-born users (e.g. "delete profile" should remind them there's no backup)

### 4.7 Multi-Device for Local-Born Users

**Not supported by construction.** A local-born account has no cloud identity; two devices claiming the same local account are two unrelated accounts.

- **No detection, no pairing, no QR code sync.** Attempting to build detection for "same user on second device" without a cloud identity is impossible by definition.
- **Clear upfront copy at signup:** *"This account exists only on this device. For multi-device use, connect to the internet and create a cloud-backed account instead."*
- **Escape hatch:** the upgrade flow (§4.3) serves as the "I want my stuff on my tablet" path. A local-born user upgrades to cloud, then signs in on their second device using the newly-created cloud account.

Cloud-born multi-device is handled by §4.1's conflict resolution. No additional spec needed.

---

## 5. What This Inherits Unchanged from March

All of the following are still canonical and should be implemented as specified in their respective docs:

- **Two-database split** (Content DB read-only + User DB read-write). See `two-database-drift-architecture.md`.
- **Bundled Content DB** — pre-built SQLite shipped as `assets/seed.db.gz`, decompressed on first launch/upgrade. ~22-30 MB gzipped, well under Play Store limits.
- **Local calendar cycle computation** — all 12 programs computed locally from a pre-built `CalendarCycles` table (date-keyed 2024-2030). See `calendar-cycle-computation-analysis.md`.
- **7 calendar registry bugs** must still be fixed as a prerequisite to the calendar seed tool (listed in March §8.1).
- **Startup hardening:** deferred Firebase init, deferred Google Sign-In init, optimized ConnectivityService with 2-second DNS timeout. (Already partially implemented — see DNI-187.)
- **Sync engine takes `UserDatabase`, not `AppDatabase`.** Content DB is never synced.

---

## 6. What This Supersedes from March

| March Concept | v2 Replacement |
|---|---|
| Anonymous `localUid` UUID generated on first launch | Local-born accounts with real email + argon2id password |
| `localUid` stored in SharedPreferences | Credentials stored in `UserProfiles` table |
| Optional / deferred account creation ("no sign-in wall") | Mandatory signup at first launch (cloud or local, tier decided by network state) |
| `localUid → firebaseUid` atomic migration on account creation | Explicit upgrade flow with collision handling (§4.3) |
| Sealed `AppAuthState` (`LocalAuthState` / `CloudAuthState`) | Single auth model with two storage backends |
| `LocalAuthGuard` vs `FirebaseAuthGuard` abstraction | Single auth guard — backend is an implementation detail |
| "Account creation optional, deferrable" NFR language | Revised: "Every user has an account; tier is determined by network state at signup" |

**Deleted 2026-04-10 (historical — no longer in repo):**
- `local-first-auth-abstraction-layer.md` (~822 lines) — was entirely superseded; removed from the repo.
- `offline-first-analysis-2026-03-27.md` (~677 lines) — content still valid was absorbed into §5 (Inherited Unchanged) of this doc and into the still-canon companion docs ([`two-database-architecture.md`](two-database-architecture.md), [`calendar-cycle-analysis.md`](calendar-cycle-analysis.md)).

**Features that never get built (design debt avoided):**
- UID migration logic across all tables
- Sealed auth state hierarchy
- "Convert anonymous session to account" UX flow
- Two-code-path handling of `hasAccount: true/false` throughout the app

---

## 7. Follow-Up Work (Not Blocking This Doc)

| # | Item | Owner | Priority |
|---|---|---|---|
| 1 | Tune argon2id parameters for API 21 target (benchmark to ~250ms) | Dev | Before Stream 1 impl |
| 2 | ~~UX spec for the upgrade flow (§4.3), including merge flow copy~~ | Analyst → UX designer | **Flow + copy + state spec done 2026-04-10** → `upgrade-flow-ux-spec-2026-04-10.md`. Remaining: wireframes, component selection, visual design, accessibility pass, and resolution of 9 open questions in §10 of that doc. |
| 3 | Amend `v1-developer-roadmap.md` to reflect new auth model | PM | Before next sprint |
| 4 | Amend `epics.md` and any sprint stories touching auth to reflect v2 | PM | Before next sprint |
| 5 | ~~Archive or delete `local-first-auth-abstraction-layer.md`~~ | Analyst | **Done 2026-04-10** |
| 6 | Decide: store argon2 hash in Android Keystore as secondary defense? | Dev | During implementation |
| 7 | Define event log schema for `streak_events` and `xp_events` (§4.1) | Dev + Analyst | During Stream 1 impl |
| 8 | **v2 code refactor — tracked as Epic 20 in Linear.** [Epic 20: Offline-First Architecture v2 — Hard-Tier Auth Refactor](https://linear.app/dniasoff/project/epic-20-offline-first-architecture-v2-hard-tier-auth-refactor-d9ed0690d244). Scope: drop `localUid`, add argon2id password hash to `UserProfiles`, collapse `AppAuthState` to single auth model, rewrite onboarding for mandatory signup at first launch, rewrite upgrade flow per §4.3, implement conflict resolution per §4.1, update affected tests. Affects ~15 production files + 6 test files in `learning_tracker/lib` and `learning_tracker/test`. Gates Epic 19 shipping in its current form. | Dev + PM | **Before Epic 19 ships** |

---

## 8. Open Threads to Reply to Yafet

From the Slack thread on 2026-04-10, Yafet asked three questions. Consolidated answers for reply:

**Q1: Can users create accounts offline then sync when connected? Does this rule out Google Sign-In?**

Partially. Users who sign up **while offline** get a local-born account (email + password stored on device, no backup, no Google). Users who sign up **with internet** get a cloud-born account (Firebase Auth, optionally via Google, with Firestore sync). Tier is set at signup and is immutable. Google Sign-In is supported only on the cloud path by definition.

**Q2: Must all data be stored locally, even passwords for email/password registration?**

Yes for local-born accounts — passwords are stored as argon2id hashes in SQLite alongside other local data. For cloud-born accounts, Firebase Auth handles credentials and nothing sensitive is persisted in app SQLite. **Critical caveat:** local-born accounts have no password recovery path, and this must be surfaced prominently at signup.

**Q3: Account → Profile → Track hierarchy — correct?**

Correct. One Account (email) → many Profiles (adult or child) → each Profile has its own learning tracks, progress, streaks, and gamification. Account must exist before Profiles can be created. This hierarchy is identical across cloud-born and local-born accounts — only the credential storage and sync behavior differ.

**Additional clarification for Yafet not in his questions:**
- The 90/10 split is not about "users who happen to be offline right now" — it's about **where the account was born**. A cloud-born user can use the app fully offline for weeks; their session persists locally. A local-born user never gains a cloud identity without an explicit opt-in upgrade.
- Users who delete the app or clear data on a local-born account **will lose everything** — this is inherent to local-only storage and is the reason the "no backup" warning and badge exist.

---

## 9. Success Criteria (Updated)

- [ ] Fresh install on airplane-mode device → local-born signup → full app use, no network
- [ ] Fresh install with internet → cloud-born signup (email or Google) → full app use, sync active
- [ ] Cloud-born user goes offline for 14+ days → app keeps working, session persists, sync catches up on reconnect
- [ ] Local-born user upgrades to cloud → data syncs up, tier flips, no data loss
- [ ] Local-born user upgrades and hits email collision → guided merge flow, user chooses explicitly, no silent merge
- [ ] Two cloud-born devices edit independently offline → reconnect → progress merges (no loss), streaks/XP reconcile via event log
- [ ] Local-born user in signup flow cannot proceed without acknowledging "no backup, no recovery" warning
- [ ] "No backup" badge visible in profile area for every local-born user, tappable to open upgrade flow
