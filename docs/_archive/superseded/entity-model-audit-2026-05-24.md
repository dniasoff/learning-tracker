# Entity Model — Discussion & Audit Notes (2026-05-24)

> **Status: ACTIVE / LIVE CAPTURE.** Written during an open chat between Daniel and the analyst (Mary). This is a working document, not a finalized spec. The model below is *intent as Daniel describes it* and is the source of truth we will audit code against. Updated continuously as the conversation proceeds.

---

## Purpose — Audit Charter

When the model discussion is complete, run a **three-way consistency check**:

1. **The model articulated in this discussion** — the intent. Source of truth.
2. **The data model in code** — entities, fields, relationships as actually built.
3. **The screens** — what the UI exposes, assumes, and lets users do.

**Win condition:** all three tell the *same story*. Flag every gap and every drift:
- Data model has a concept the screens never surface → gap.
- A screen implies a relationship the data model can't represent → gap.
- Either drifts from what Daniel describes here → drift.

**Scope (refined 2026-05-24):** the rework — and the audit's change-focus — is the **account / login / profile / switching / tutor / gating** layer (DEC-1…DEC-30). The **learning layer is endorsed as-is** (DEC-31) and treated as the stable baseline, not re-measured against a fresh intent.

Audit does **not** start until Daniel says "go."

### Flows that must be tested (Daniel: "we need to test this flow")
- **Tutor invite → accept → manage**, end-to-end: parent invites in child settings → tutor sees "View invitations" → accepts → child appears in tutor's profiles → tutor can view + edit tracks/points/rewards but **cannot learn** (DEC-8, DEC-9).
- **Tutor relationship management:** parent adds/removes **multiple** tutors; tutor removes a child/talmid; verify the tutor section appears **iff ≥1 active student OR ≥1 invitation** and vanishes otherwise (DEC-8, DEC-10).

---

## Working Vocabulary (kept crisp so the audit has stable terms)

- **Login / Account** — a sign-in **credential**, via **Google *or* email/password** (DEC-20). Proves the device has access. *(Earlier "Google sign-in only" framing is superseded.)*
- **Profile** — a *learner* (an actual person who tracks study). Adult or child. **Owns the learning data.**
- **Device** — the physical device; can host multiple Logins.

> ⚠️ "User" is ambiguous — Daniel uses it for both Login and Profile. For this audit: **Profile = the learner**, **Login/Account = the Google credential.** (Pending Daniel's confirmation — see Q3.)

---

## Decisions Made

Firm decisions taken during the discussion — these are intent, and part of what the audit measures against.

- **DEC-1 (2026-05-24) — App permissions are Device-scoped** (moved from Login). OS grants to the app, per physical device; shared by every login/profile on it.
- **DEC-2 (2026-05-24) — Notification settings are Profile-scoped** (moved from Login). Reminders are per-learner — family members want different schedules.
- **DEC-3 (2026-05-24) — The UI must make the scope boundaries legible AND make switching easy.** (a) Settings/data must be presented under the right scope (Device vs Login vs Profile); (b) there must be an easy, intuitive way to **switch login** and **switch learning profile**. Daniel: current UX is "not that intuitive today."
- **DEC-4 (2026-05-24) — Parent mode for a child profile is exactly {manage tracks · manage points · manage rewards} — nothing else.** Everything else (all data, reports, the full experience) requires **switching into the child's profile**. Parent mode and child mode must not leak into each other. (Same active-as-child mechanic tutor mode uses — see P1.)
- **DEC-5 (2026-05-24) — Tutor Mode is hidden, not prominent.** It's a tucked-away part of the app, not a headline feature. (How it's revealed = Q9.)
- **DEC-6 (2026-05-24) — Sign-in does not force profile creation.** The create-profile wizard is offered, but a **Skip** option leaves an **empty login** (zero profiles) with only a minimal surface. Enables the tutor use case (manage children without learning on the device).
- **DEC-7 (2026-05-24) — Add-profile offers only {adult, child} — "your profile."** No tutor option in profile creation; tutoring is a *grant/relationship*, not a profile type and not created via add-profile.
- **DEC-8 (2026-05-24) — Two-phase tutor invite flow.** *Invite side:* a **"Manage tutors"** option appears in a child profile's parent settings (only once a child profile exists); the parent invites tutors there. *Accept side:* the tutor's **tutor section appears only if the tutor has ≥1 active student (talmid) OR ≥1 pending invitation** — otherwise no tutor section shows at all. It holds invitations to accept and the list of active students; on acceptance the tutored child appears among the tutor's own profiles (distinct section).
- **DEC-9 (2026-05-24) — Tutor capabilities = complete view + manage, minus learn.** A tutor sees everything (like child mode) and can edit exactly what a parent can (tracks, points, rewards), but **cannot record learning** as the child.
- **DEC-10 (2026-05-24) — Tutor↔child is M:N and severable from both ends.** A child may have **multiple tutors**; the **parent adds and removes tutors** (via "Manage tutors"); a **tutor can remove a child/talmid** from their side.
- **DEC-11 (2026-05-24) — Always-on profile/account switcher.** A switcher reachable anytime (e.g. tap avatar) lets you jump to any profile, or any already-signed-in Google account, **without logging out**; signed-in accounts are remembered (Gmail-style). "Active profile" is **session state**, switchable anytime. Resolves Q1 / fixes D1.
- **DEC-12 (2026-05-24) — Reopen lands smartly.** If the login has exactly one profile, open straight into it; if multiple, show the profile picker. (Fast for solo, correct for shared devices.) Resolves Q16.
- **DEC-13 (2026-05-24) — PIN gating (data protection).** *Parent:* a PIN guards crossing from the **child's view → parent controls** (child mode is open; reaching management needs the PIN). Picking/entering profiles — including adult profiles — stays open (no PIN). *Tutor:* a PIN is required **whenever viewing a talmid's profile** (stricter — every access to another family's child data is gated). A tutor is a "single user" — no parent↔child switch concept. Resolves Q18, Q2.
- **DEC-14 (2026-05-24) — Tutor uses a single combined surface (refines DEC-9).** Unlike a parent (who splits into manage-only *parent mode* ↔ full *child mode* via switch-in), a tutor sees **everything the child can see** AND edits **only the parent-editable items** (tracks, points, rewards) in one view — but **cannot learn** (e.g. cannot mark a mishna learned).
- **DEC-15 (2026-05-24) — Parent controls live *inside the child*.** Open the child (via switcher), then PIN across into parent mode for that child (DEC-13). **Any adult on the login** can manage that login's children (matches current behavior). Resolves Q8.
- **DEC-16 (2026-05-24) — Adults are not gamified.** No points, no rewards. Adults have tracks, goals, chazara, streaks (they're learners) and **fully self-manage** — no parent over them, no PIN to be themselves (matches current behavior). Resolves Q19.
- **DEC-17 (2026-05-24) — Points: auto on completion + parent adjust.** A child earns points **automatically** on completing learning; the **parent can add/deduct** for special cases (in parent mode). Resolves Q20.
- **DEC-18 (2026-05-24) — Rewards: parent configures, child redeems, parent fulfils.** The parent sets up rewards with a points cost (e.g. 100 pts = 30 min screen time); the **child spends points to redeem**; the **parent approves/fulfils** the real-world item. Resolves Q21.
- **DEC-19 (2026-05-24) — Recording learning is the child's alone.** Neither parent nor tutor records a child's real-time learning — **the child records what they learnt**. *Exception:* a parent may **bulk-mark** (credits lifetime/siyumim via sentinel date, no streak/recent-activity impact — completion-credit policy). Tutor never learns (DEC-9). Resolves Q12.
- **DEC-20 (2026-05-24) — Tutor invites are addressed by email; pending until claimed.** Invite by **email**, for accounts via **Google *or* email/password**. The target email need not be registered yet — the invite **waits** and surfaces in that person's invitation section once they log in with the matching account. *(Refines the auth model: a Login is a credential via Google **or** email/password — not Google-only.)* Resolves Q24.
- **DEC-21 (2026-05-24) — A tutor is usually profile-less but may also hold an adult profile.** Typically skips profile creation and just manages talmidim, but may create their own adult profile to learn too. Resolves Q11.
- **DEC-22 (2026-05-24) — Co-tutors have equal rights; only the parent manages the tutor list.** All tutors of a child get the same view+edit (DEC-9/14); a tutor manages only the child, not other tutors; only the **parent** adds/removes tutors. Resolves Q25.
- **DEC-23 (2026-05-24) — Tutor-link removal: immediate, notified, re-creatable.** Removing (either side) revokes access immediately, notifies the other side, and can be re-established with a fresh invite. Resolves Q14.
- **DEC-24 (2026-05-24) — Talmidim appear in a separate switcher section.** On the tutor's switcher, talmidim sit in a distinct **"Talmidim / Students"** section, separate from the tutor's own profiles; label follows the Hebrew-terms rules. One adult can hold own profiles + talmidim, cleanly separated. Resolves Q13, Q26.
- **DEC-25 (2026-05-24) — "Acting-as" banner + exit.** When inside a child (viewing / child mode), show a clear banner (e.g. "Viewing [child]") with an obvious exit back to your own profile — directly mitigates the leaking (D3). Resolves Q17.
- **DEC-26 (2026-05-24) — Location is Device-scoped** (moved from Login). Environmental like app permissions; a shared device is in one place. Login-scope now holds only the debug toggle. Resolves Q6.
- **DEC-27 (2026-05-24) — Two notification layers.** (1) a **device-level notification toggle** (OS on/off, available even on an empty login); (2) **per-profile reminder schedules** (each learner's nudges). Distinct things. Resolves Q10.
- **DEC-28 (2026-05-24) — Reminders fire per-profile regardless of active profile.** Every profile's reminders fire on schedule even when another profile is active; tapping a reminder switches into that profile. Resolves Q22.
- **DEC-29 (2026-05-24) — Multiple accounts signed in at once; per-account sign-out.** Several accounts can be signed in simultaneously and switched easily ("Add account" in the switcher). Sign-out is per-account (others stay); the signed-out account's local data clears from the device but is safe in the cloud and re-syncs on next login. Resolves Q23.
- **DEC-30 (2026-05-24) — Switcher UX appears only when there's something to switch to** (refines DEC-11). Account-switch affordance shows only with **≥2 accounts** signed in; profile-switch affordance shows only with **≥2 profiles** on the active login. One account + one profile → no switcher shown. (Same "hide controls with no purpose" principle as the hidden tutor section, DEC-8.)
- **DEC-31 (2026-05-24) — Learning layer is endorsed as-is; out of redesign scope.** The learning layer (tracks, curricula, programs/enrolment, goals, chazara, completions, streaks, siyumim, plus the points/rewards defined above) is **already built and Daniel is happy with its structure** — not being re-modelled. The entity-model rework (and the audit's change-focus) is scoped to **account / login / profile / switching / tutor / gating**. For the audit, the learning layer's existing structure is the stable baseline (source-of-truth), not measured against a freshly-stated intent. Closes Q15.
- **DEC-32 (2026-05-24, gate G1) — Rewards are a spend-economy; the child picks & chooses.** The parent configures rewards (points cost); the **child browses and picks which reward to redeem**, spending points; the parent approves/fulfils. NOT the auto-unlock achievement-ladder that exists today. Drives WS7.
- **DEC-33 (2026-05-24, gate G3) — A tutor has the FULL parent management toolset.** A tutor can do anything a parent can to the child's learning: **manage tracks, configure points, configure rewards, AND bulk-mark** corrections — not view-only. The only thing still barred is the child's **live/real-time learning** ("marking a mishna" as the learner), which neither parent nor tutor does (DEC-19). **Resolves the audit's flagged "tutor bulk-mark contradiction" in favour of ALLOWING it** — `canBulkPriorCompletion: true` is correct; only the UI needs wiring. Tutor-**roster** management stays parent-only (DEC-22) unless changed. Refines DEC-9/DEC-14.
- **DEC-34 (2026-05-24, gate G2) — Multi-account: all signed-in accounts stay authenticated; switching is instant.** Several accounts can be signed in at once on a device; switching between them is **instant — tap a name, no password, no sign-out**; only one account is the active on-screen context at a time. The switcher must keep all accounts authenticated; switching must NOT call `signOut()`. Shapes WS1.

**Guiding principle (emerged 2026-05-24):** a setting/datum belongs to the **lowest level at which people would reasonably want it to differ** — Device → Login → Profile.

---

## Entity Model — Captured So Far

### Hierarchy & cardinality
- **Device 1 — N Login** — usually 1; occasionally 2 separate Google accounts on one device. Valid scenario, must be supported (Daniel: "pretty easy to support").
- **Login 0 — N Profile** — usually 1; a family may have several (adults + children); and **zero is valid** — a login can skip profile creation entirely (DEC-6, see "empty login" below).
- **Profile N — 1 Login** — base rule: a profile lives under exactly one login. *(Tutor cross-login access is the exception — see P1.)*
- **Child Profile N — N Tutor** — a separate cross-login **grant** (not ownership). True many-to-many (**confirmed by Daniel 2026-05-24**): a **child has 0..N tutors** — *zero is the norm* (tutoring is rare/hidden) — and a **tutor has 1..N children** (the role only exists once there's ≥1 invite/student, per DEC-8). Severable from both ends (DEC-10). See "Tutor invite & access flow."

### The empty login (no-profile) state

Sign-in does **not** force profile creation (DEC-6). The wizard is offered, but **Skip** is allowed — leaving a login with **zero profiles**: an "empty device." Minimal surface only — Daniel: "the notification screen, the debug screen, not much." (Profile-scoped things don't exist yet; a profile can be created later.)

**Why it exists:** **tutors** — adults who don't learn on the device themselves but only *manage children*. The empty login is their home base; from there they reach the children they manage via (hidden) tutor mode. See P1.

### Profile types
- **adult** — a grown-up learner. *(Prior context: adults have no points / aren't gamified — confirm.)*
- **child** — a learner whose profile is *managed by an adult* (see Parent mode vs Child mode below).

> ⚠️ **"Parent" is a role/mode, not a profile type.** There is no Parent entity — a "parent" is an **adult** acting as manager of a child profile. Profile types stay exactly `{adult, child}`.

### Child profiles — Parent mode vs Child mode

A child profile is seen through **two distinct surfaces that must NOT leak into each other:**

- **Parent mode** — an adult *managing* the child. Surface is deliberately tiny: **manage tracks · manage points · manage rewards. Nothing else** — no reports, no data browsing, no doing the learning.
- **Child mode** — *switching into* the child's profile (active-as-child). This is where **all the data, reports, and the full experience** live.

**Hard rule (DEC-4):** to see anything beyond tracks/points/rewards for a child, you must switch into the child's profile. *(Same active-as-child mechanic tutor mode relies on — see P1.)*

### Capability model — View / Manage / Learn

Three distinct verbs on a **child** profile, granted to different roles (an *adult* profile just does all three for itself — no split):

| Capability | What it is | Child (self) | Parent | Tutor |
|---|---|---|---|---|
| **Learn** | record study / do the learning | ✅ | ❌ — bulk-mark only (DEC-19) | ❌ (DEC-9) |
| **Manage** | edit tracks, points, rewards | — | ✅ (DEC-4) | ✅ (DEC-9) |
| **View** | all data, reports, full experience | ✅ | ✅ via switch-in (DEC-4) | ✅ complete view (DEC-9) |

> A tutor = **parent powers + complete view, minus the ability to learn.**
> **Surfaces & PIN:** Parent = two surfaces (manage-only *parent mode* ↔ full *child mode* via switch-in), with a **PIN to cross child→parent** (DEC-13). Tutor = one combined surface (sees all + parent-level edits), with a **PIN to view any talmid** (DEC-13, DEC-14).

### Points, rewards & learning credit (first slice of the learning layer — see Q15)

- **Points** — earned **automatically on completion**; parent can add/deduct in parent mode (DEC-17). Child-Profile-scoped.
- **Rewards** — parent **configures** (points cost); child **redeems** by spending points; parent **approves/fulfils** the real-world item (DEC-18).
- **Recording learning** — **child only** for real-time study (DEC-19); parent may **bulk-mark** for lifetime/siyumim credit (sentinel date, no streak/recent impact — completion-credit policy); tutor never.

> This is only the first slice of the broader learning layer (tracks, curricula, programs, goals, chazara, completions, streaks, siyumim) that is otherwise still unmodelled — **Q15**.

### Tutor invite & access flow (DEC-8, DEC-10)

Tutoring is deliberately **non-prominent** (DEC-5) and surfaces only contextually, from both ends.

**Visibility rule (tutor's screen):** the **tutor section appears only if the tutor has ≥1 active student (talmid) OR ≥1 pending invitation.** No students and no invitations → no tutor section at all.
> Term note: **talmid / talmidim** (student/tutee) — confirmed term (DEC-24); follows the Hebrew-terms rules.

1. **Invite (parent side):** once a child profile exists, its **parent settings** show a **"Manage tutors"** option → parent invites a tutor. A child may have **multiple tutors**; the parent can **add and remove** them here (DEC-10).
2. **Notify (tutor side):** when an invited tutor logs in, the tutor section surfaces (per the visibility rule) with a **"View invitations"** entry.
3. **Accept:** the tutor accepts the invitation.
4. **Result:** the tutored child appears among the tutor's **own profiles**, in a distinct section *(Daniel: "under a … mid section" — exact placement/label unclear, see Q13)*. The tutor then has tutor capabilities (DEC-9).
5. **Sever (either end):** the **parent can remove a tutor**; the **tutor can remove a child/talmid**. (Removal lifecycle — notify? immediate revoke? re-invite? — see Q14.)

This is the M:N, cross-login grant from P1: a child under one login becomes accessible to one or more tutors under other logins, severable from both sides.

### The normal / "95%" use case
Log into your Google account → see your profiles (adult + child) → choose a profile → learn.
Then another family member gets to *their* profile → learns.

→ **Implication:** the app must be able to return to the profile chooser without ending the session. **Profile-switching is structurally required by the normal use case** — not an optional extra.

### Data ownership — three scopes: Device / Login / Profile

Refined 2026-05-24: data lives at **the level it actually varies with**, mirroring the entity hierarchy Device → Login → Profile.

**Device-scoped** (this physical install; shared by every login & profile on the device):
- **App permissions** — DEC-1; OS grants to the app, per device.
- **Location** — DEC-26 (moved here from Login); environmental, shared on one device.
- **Notification toggle** (OS on/off) — DEC-27; device-level layer, available even on an empty login.

**Login-scoped** (this sign-in / environment):
- **Debug button** (toggle)

**Profile-scoped** (this learner):
- Learning **tracks** — and all learning data (progress, goals, completions, points, rewards, streaks). *(Full list — Q15.)*
- **Notification reminders** (per-learner schedules) — DEC-2, DEC-27, DEC-28. (OS on/off toggle is device-level, above.)

> Principle: **Device = the install · Login = the credential/environment · Profile = the learner.** A datum belongs to the lowest level at which people would reasonably want it to differ.

---

## Drift / Tensions Identified

- **D1 — Multi-profile login vs. no in-app switch.**
  The login boundary treats profiles as plural (you can sign into more than one), but once inside the app the active profile is singular and fixed — no switcher.
  Root cause: nobody decided whether **"active profile" is a property of the *login*** (pick once, locked until logout) **or of the *session*** (live, switchable). Login screen was built as session-state; in-app was built as login-state.
  This directly breaks the 95% use case (the child can't get to his profile after the parent used theirs).
  **Update (2026-05-24):** confirmed as a requirement — see DEC-3. There are actually *two* switch actions: **switch profile** (within a login) and **switch login** (between Google accounts on the device). Both must be easy.
  **Resolved (DEC-11):** always-on avatar switcher covers both; "active profile" is now session state, switchable anytime without logout.

- **D2 — UI doesn't reflect the ownership scopes.**
  Settings and data aren't clearly grouped by Device vs Login vs Profile, so it's not obvious what's shared vs personal. The UI must express the three-tier boundary (DEC-3a).

- **D3 — Parent mode and child mode leak into each other.**
  Daniel: "you are leaking between the two." Parent mode should expose *only* manage-tracks / manage-points / manage-rewards; everything else (data, reports, full experience) should require switching into the child. Today the boundary isn't clean. (See DEC-4.)

---

## Parked Items (revisit, don't lose)

- **P1 — Tutor access (specified 2026-05-24).** A tutor manages child profiles that live under *other* logins (M:N cross-login access — the exception to "Profile belongs to exactly one Login"). Hidden by default (DEC-5); tutor is typically profile-less (DEC-6); invite/accept flow and capabilities now specified — see "Tutor invite & access flow", the Capability model, and DEC-7/8/9. Residual: can a parent learn? (Q12); tutored-profile placement/label (Q13); whether a tutor may also hold an adult profile (Q11).

---

## Open Questions Queue  ⭐ IMPORTANT — do not lose these

Holding all questions until Daniel signals the model dump is done, then asking together.

- **Q1 — ✅ RESOLVED (DEC-11).** Always-on switcher (avatar menu); switch profile or already-signed-in account with no logout; accounts remembered Gmail-style.
- **Q2 — ✅ RESOLVED (DEC-13).** Choosing/entering a profile is NOT gated (incl. adult profiles); the gate is on parent controls (child→parent) and on a tutor viewing talmidim.
- **Q3 — ✅ RESOLVED.** Standardized: **Login/Account = credential** (Google or email/password, DEC-20), **Profile = learner**. Used consistently throughout; no pushback.
- **Q4 — ✅ RESOLVED (DEC-1).** App permissions → Device-scoped.
- **Q5 — ✅ RESOLVED (DEC-2).** Notification settings → Profile-scoped (per learner).
- **Q6 — ✅ RESOLVED (DEC-26).** Location → Device-scoped.
- **Q7 — ✅ RESOLVED (DEC-17, DEC-18).** Points = auto-on-completion + parent adjust; Rewards = parent-configured, child redeems with points, parent fulfils. (Fuller learning-layer model still pending — Q15.)
- **Q8 — ✅ RESOLVED (DEC-15).** Parent controls live inside the child (PIN to cross from child view); any adult on the login can manage that login's children.
- **Q9 — ✅ Largely resolved (DEC-8).** Parent invites via "Manage tutors" in child settings; tutor sees a "View invitations" box (only when invitations exist) and accepts; tutored child then appears among the tutor's profiles. Residual placement/label detail → Q13.
- **Q10 — ✅ RESOLVED (DEC-27).** Two layers: device-level OS toggle (shows on empty login) + per-profile reminder schedules.
- **Q11 — ✅ RESOLVED (DEC-21).** Usually profile-less; may also create their own adult profile to learn. Both allowed.
- **Q12 — ✅ RESOLVED (DEC-19).** No — recording real-time learning is the child's alone; a parent may only **bulk-mark** (lifetime/siyumim, sentinel date). Tutor never learns.
- **Q13 — ✅ RESOLVED (DEC-24).** Separate "Talmidim / Students" section in the switcher, distinct from own profiles; term = **talmid/talmidim** (Hebrew-terms rules).
- **Q14 — ✅ RESOLVED (DEC-23).** Removal (either side): immediate revoke, other side notified, re-creatable via fresh invite.
- **Q15 — ✅ CLOSED (DEC-31).** Learning layer is *already built* and Daniel is happy with the structure — not being re-modelled. Existing structure is the audit baseline (source-of-truth), not measured against a fresh intent.
- **Q16 — ✅ RESOLVED (DEC-12).** One profile → open straight in; multiple → show picker on launch.
- **Q17 — ✅ RESOLVED (DEC-25).** "Viewing [child]" banner + obvious exit back to own profile.
- **Q18 — ✅ RESOLVED (DEC-13).** PIN guards child→parent-controls; tutor needs a PIN to view any talmid profile. Profile selection itself stays open.
- **Q19 — ✅ RESOLVED (DEC-16).** Adults not gamified (no points/rewards); have tracks/goals/chazara/streaks; fully self-manage, no PIN to be themselves.
- **Q20 — ✅ RESOLVED (DEC-17).** Points auto-earned on completion; parent can add/deduct for special cases.
- **Q21 — ✅ RESOLVED (DEC-18).** Parent configures rewards (point cost) → child redeems with points → parent approves/fulfils.
- **Q22 — ✅ RESOLVED (DEC-28).** Yes — every profile's reminders fire regardless of who's active; tapping one switches into that profile.
- **Q23 — ✅ RESOLVED (DEC-29, DEC-30).** Multiple accounts signed in at once, easy switch; per-account sign-out (others stay; local data clears, safe in cloud, re-syncs). Switcher UX shows only when ≥2 accounts/profiles exist.
- **Q24 — ✅ RESOLVED (DEC-20).** Invite by email (Google or email/password); may target an unregistered email; pending until claimed on login.
- **Q25 — ✅ RESOLVED (DEC-22).** Co-tutors equal (view+edit); a tutor manages only the child, not other tutors; only the parent adds/removes tutors.
- **Q26 — ✅ RESOLVED (DEC-24).** Yes — one adult can hold own (adult+child) profiles plus a separate Talmidim section; chooser separates them.

---

---

## Audit Findings (2026-05-24)

**Method:** six parallel code deep-dives over `learning_tracker/lib` (one per cluster), plus spot-verification of the load-bearing claims (tutor route reachability, reward redemption, skip→empty-login, PIN-gate wiring — all confirmed by grep). Verdicts: ✅ MATCH · 🟡 PARTIAL · 🔴 DRIFT · ⚪ ABSENT.

### Headline

The **data model and domain layer are largely faithful** to the captured intent — `Accounts` vs `LearnerProfiles`, profile modes `{adult, child}`, M:N tutor grants, the permissions value-object, the PIN service, and the Firestore rules/indexes all exist and mostly match. **The drift is concentrated in the UI / wiring layer**, and in three places it is structural:

1. **Switching — the original complaint — is still not fixed.** No always-on switcher; profile-switch is buried in Settings; account-switch needs a sign-out (D1 / DEC-11 / DEC-30).
2. **The entire tutor feature is backend-complete but UI-stranded.** Models, use-cases, Cloud-Functions repo, Firestore rules/indexes, PIN service, audit log and notification service all exist — but nothing navigates to them, the PIN gate is uninstantiated, and talmid rows are `onTap: null`. End-to-end tutoring cannot be exercised from the app (DEC-8/9/13/14/22/23).
3. **Rewards have no redeem→fulfil loop.** What's built is an auto-unlock *achievement ladder*, not a *spend* economy; points are a monotonic sum that is never debited (DEC-18).

Also: notifications are single-active-profile (DEC-27/28 drift), there is no "Viewing [child]" banner (DEC-25 absent), and "skip → empty login" is unreachable (DEC-6 drift) — which undermines the tutor's profile-less home base.

### Per-decision verdicts

**A — Login / Account / Device**
- ✅ **DEC-20** — Google (`google_sign_in_gateway_impl.dart:31`) + email/password (cloud `firebase_auth_gateway_impl.dart:78`; local argon2id `local_auth_service.dart:64`); email = stable identity (`accounts.dart:16`); signup offers both (`signup_screen.dart:644,696`).
- 🟡 **DEC-29** — Schema supports ≤5 accounts/device (`device_registry_database.dart:29`) but it's **switch-between, not simultaneous** (single `lastActiveAccountId` :170, single `AuthState.currentUser`; switching to a local account calls `signOut()` `account_picker_screen.dart:482`). Re-sync handled. **Sign-out does NOT clear local data** — only Remove/Delete does (`account_lifecycle_service.dart:34,67`).
- 🔴 **DEC-6** — Skip exists (`onboarding_intent_screen.dart:23`) but onboarding **always begins at `profileCreation`**; the chooser fires only after `_onProfileCreated` (`onboarding_screen.dart:72,179-183`). You can skip *track setup*, not *profile creation* → **empty login is unreachable**.
- 🟡 **Cardinality** — Device 1..N Login ✅; Login 0..N Profile: schema allows zero, code forces ≥1 (`sign_in_controller.dart:457`).

**B — Profiles / types / switching**
- ✅ **DEC-7** — `profile_mode.dart:14` = `{adult, child}`; add-profile offers exactly child/adult (`add_profile_dialog.dart:180`, `manage_learners_screen.dart:290`). No parent/tutor/personal type leaks.
- ✅ **DEC-16** — Adults un-gamified (points/streak gated on `UserMode.child` `dashboard_body.dart:310,438`); self-manage, no PIN (`manual_completion_use_case.dart:49`).
- 🔴 **DEC-11** — **No always-on switcher.** Profile-switch only via Settings header (`settings_screen.dart:67`); account-switch unreachable in-session (sign-out/launch only). D1 essentially unfixed.
- ✅ **DEC-12** — `profile_guard.dart:66-82`: one→auto-select; 2+→picker; zero→picker.
- 🔴 **DEC-30** — No count-gating; Settings "switcher" shows even for a single solo profile; no account-switch affordance.

**C — Parent mode / PIN / learning-credit**
- 🟡 **DEC-4** — `parent_settings_screen.dart:91-171` exposes the right tiles, but `parent_portal_bottom_nav.dart:146` tab 0 drops into the child's **full** experience — manage-only boundary is soft.
- ✅ **DEC-15** — `childModeGuard` (`app_router.dart:207-238`); any adult; no per-adult ownership check.
- ✅ **DEC-13 (parent)** — Parent routes carry `pinGuard` (`app_router.dart:208,213,218,238`); profile entry not gated.
- ⚪ **DEC-25** — **No "Viewing [child]" banner/exit**; `app_shell.dart` renders only the tutor bar. Parent-path D3 mitigation unbuilt.
- ✅ **DEC-19** — Child records own learning freely (`MarkCompletionUseCase`, no PIN); manual/lifetime marking PIN-gated, fires only on `isManual` (`learning_ledger_repository_impl.dart:36-46`).

**D — Tutor (backend-complete, UI-stranded)**
- 🟡 **DEC-5** — Not headline, but `_TutorModeIndicatorBar` shows on ANY active incoming grant, even on own profile (`app_shell.dart:60,74`).
- ⚪ **DEC-8** — **No "Manage tutors" entry** (grep verified); mgmt routes have **no in-app navigation** (verified); no "View invitations" entry; talmid section gates on **active** grant only — **pending invitations don't surface** (`tutored_children_section.dart:35`).
- 🔴 **DEC-9** — Combined view+edit surface doesn't exist; `canEdit*` permission fields never read by any UI; only the "cannot learn" half is enforced.
- 🟡 **DEC-10** — Model genuinely M:N (`tutor_grant.dart:122`; revoke/resign use-cases) but parent-side removal UI unreachable.
- ⚪ **DEC-13 (tutor)** — **PIN gate built, zero call sites** (verified); talmid rows `onTap: null` (`tutored_children_section.dart:142`); no route applies tutor PIN scope (`router_provider.dart:66-71` hard-codes parent).
- ⚪ **DEC-14** — No combined surface; `permissions_provider` returns a static owner session (dead).
- ✅ **DEC-20** — Invite by email; grantId from email hash; pending surfaces on login (`tutor_invite_use_cases.dart:95`, `firestore.rules:128`). Backend correct; UI entry unreachable.
- 🔴 **DEC-21** — `_isTutorSession` is **global** (`text_display_screen.dart:748`) → a tutor who also holds their own profile gets live "mark complete" wrongly disabled on their OWN profile.
- 🟡 **DEC-22** — Co-tutor equality by construction; server-only grant writes (`firestore.rules:135-147`); parent add/remove UI unreachable.
- 🟡 **DEC-23** — Immediate revoke via callables; notify-service has all 3 emails but **zero call sites** (`tutor_notification_service.dart:48,68,88`) — relies on CF; re-invite supported.
- ✅⚠️ **DEC-24** — Separate "Talmid Profiles" section, Hebrew-terms label (`tutored_children_section.dart:46`); caveat: rows show raw `Child: {id}`, non-interactive.
- ✅ **mark_live_completion** — Tutor **live**-mark correctly **blocked** (`mark_live_completion_use_case.dart:54-66` + `firestore.rules:226`) — the child's live learning stays the child's alone. `tutor_permissions.dart:23` defaults `canBulkPriorCompletion: true`; **per gate G3 (DEC-33) this is CORRECT** — a tutor has full parent powers incl bulk-mark. (Earlier "contradiction" resolved in favour of allowing it; just wire the tutor bulk-mark UI — WS3.)

**E — Scopes / notifications / location**
- ✅ **DEC-1** — Permissions via OS APIs (`notification_gateway.dart:76`, `permission_prompt_screen.dart`).
- 🟡 **DEC-26** — Location device-global locally (`sacred_time_preferences.dart:4`) ✅; cloud copy rides each profile's UI-prefs doc (LWW across profiles, `ui_preferences_merger.dart:21`); not on Login anywhere.
- 🔴 **DEC-27** — Layer-2 reminders are a single **global** set; layer-1 **device OS toggle ABSENT** (`notifications_screen` toggles just call `requestPermission`).
- 🔴 **DEC-28** — Single-active-profile: global prefs keys, fixed singleton notification IDs (`notification_gateway.dart:13,17,30`), streak bound to active profile (`notification_providers.dart:407`); inactive profiles' reminders would NOT fire.
- ⚪ **Debug toggle (Login)** — does not exist.
- 🔴 **D2** — Settings grouped by feature, not scope; `scope_selection_screen` is *curriculum* scope (unrelated).

**F — Points & rewards**
- 🟡 **DEC-17** — Auto-credit on completion ✅ (`completion_repository_impl.dart:130-147`); **manual parent add/deduct ABSENT** (points = `SUM(completion.points)`; no adjustment ledger/UI).
- 🔴 **DEC-18** — Only the *configure* leg, mis-shaped as **threshold milestones** not priced items; **no child redeem/spend** (points never debited; auto-unlock at cumulative threshold); **no parent approve/fulfil**. UI "Redeem Prizes"/"Current Balance" overclaims (`child_points_rewards_tab_card.dart:124,222`).
- ✅ **DEC-13 (config)** — Config routes `pinGuard`'d (`app_router.dart:208,213,218`); no child self-award path.

### Three-way check (data model ↔ screens ↔ intent)
- **Model has concepts the screens never surface:** tutor permissions VO (`canEdit*`) unread by any UI; tutor mgmt routes exist but unreachable; reward unlock records have no fulfilment/approval state.
- **Screens imply behavior the model can't do:** "Redeem Prizes"/"Current Balance" (no spend); accept-invite promises tutors can "configure curricula, goals, study days" (broader than the intended tracks/points/rewards).
- **Both drift from intent:** the switcher, notification scoping, and the parent "Viewing [child]" banner.

### Recommended fixes (prioritized)
- **P1 — Switching (DEC-11/30, D1):** add the always-on profile/account switcher (avatar menu, shown only when ≥2); enable in-app account-switch without sign-out. Highest value — it's the original complaint.
- **P1 — Wire tutor mode end-to-end (DEC-8/9/13/14/22/23):** "Manage tutors" entry in the child's parent settings; navigation to invite/accept/manage routes; instantiate the tutor PIN gate on talmid view; make talmid rows interactive; consume the permissions VO in a real edit surface; confirm removal notifications (client or CF). The backend is done — this is wiring.
- **P2 — Rewards loop (DEC-18):** decide spend-economy vs achievement-ladder. Either add points-debit + redemption + parent approval/fulfilment, or fix the child UI copy ("Redeem Prizes"/"Balance") to match the milestone reality.
- **P2 — Per-profile notifications (DEC-27/28):** key reminder prefs + notification IDs by profile; schedule per-profile; add a device-level OS toggle distinct from per-profile reminders; tap → switch into the right profile.
- **P2 — "Viewing [child]" banner + exit (DEC-25):** add to `app_shell` for the parent/child-mode path (D3); harden the parent-portal tab-0 boundary (DEC-4).
- **P3 — Skip → empty login (DEC-6):** let sign-in skip profile creation to reach the empty-login / tutor home base.
- **P3 — Manual point adjust (DEC-17):** add a parent add/deduct path.

### Latent risks / cleanup
- ~~Tutor `canBulkPriorCompletion` vs DEC-19~~ **RESOLVED by gate G3 (DEC-33):** tutors are *meant* to have full parent powers incl bulk-mark — the backend default is correct; just wire the tutor bulk-mark UI (WS3). Still reconcile the accept-invite copy ("configure curricula/goals/study days") to the actual editable set.
- **Lifetime/manual ledger writes `nowUtc`, not the sentinel date** (`learning_ledger_repository_impl.dart:88,143`) unlike the bulk path — risks leaking into streak/recent activity (the DEC-19 exception clause). Also `LifetimeMarkingRoute` is route-unguarded (defense lives only in the repo) and the lifetime screen bypasses `ManualCompletionUseCase`.
- **Local-vs-cloud scope clobber:** notifications + location are device/global locally but stored per-profile in Firestore → switching profiles can clobber the global local set on sync (`notification_settings_merger.dart:42` vs `ui_preferences_merger.dart:36`).
- **Dual mode enums** (`UserMode` vs `ProfileMode`) over a free-text `mode` column; **duplicate** add-profile flows and `tutorGrantRepositoryProvider` definitions; **"transitional shims, delete after 20.x"** (`auth_state_provider.dart:105-130`) still on production paths; `dedupeByEmail` healing logic (evidence of past one-active-account dup bugs); accept-invite uses a hard-coded stub grant.

*(End of live capture — audit appended 2026-05-24. Decisions are the captured intent; verdicts above are point-in-time against the code on this date.)*
