# T-37: tutor-enters-talmid-dashboard — architecture decision needed

**STATUS: AWAITING OWNER DECISION.** Written 2026-08-11 during the Phase 3
Drift→Firestore migration, after confirming (not assuming) that this cluster
is the sole remaining blocker on the app compiling at all.

## Why this is urgent, not just another cluster

`lib/app/router/app_router.dart` — the root of the entire route tree —
directly imports `manage_tutors_screen.dart` and `invite_tutor_screen.dart`.
Those transitively import the files listed below. Verified directly: running
`flutter test test/core/navigation/parent_escalation_pin_gating_test.dart`
(a run-10 P0 child-safety test — proves every parent-only route is PIN-gated)
fails at the **loading/compile** stage, not inside a test case, with errors
bottoming out entirely in this cluster once every other `lib/` error was
cleared. In short: **the whole app does not compile until this is resolved**,
not just the tutoring feature. Everything else in Phase 3 is downstream of
this one file cluster.

Affected files (all fail to compile today):
- `lib/features/profiles/presentation/widgets/tutored_children_section.dart`
- `lib/features/tutoring/presentation/screens/manage_tutors_screen.dart`
- `lib/features/tutoring/presentation/providers/manage_tutors_providers.dart`
- `lib/features/tutoring/presentation/providers/active_tutored_profile_provider.dart`
- `lib/features/tutoring/presentation/screens/manage_grants_screen.dart`

(Every other tutoring file — invite, accept/decline invite, the grant audit
log — has already been rebuilt on Firestore this session and compiles clean.
This is the last piece.)

## Root cause

The old (Drift/local-first) architecture let a tutor's device "enter" a
talmid's dashboard by **pulling a full copy of the talmid's data down into a
local SQLite mirror**, keyed by a synthetic local `int` profile id, then
reusing the entire rest of the app (which only ever read the local DB)
unmodified. A `TutoredPullService` did the initial pull; a
`TutoredListenerSupervisor` kept it live via delta listeners;
`TutoredMirrorWipeService` cleared it on revoke/permission-denied. All of
that — `tutored_pull_providers.dart`, `userDatabaseProvider`, the mirror
wipe service — was archived with the rest of Drift (`docs/planning/
phase3-wave-plan.md`, Wave 0). There is no local database left to pull into.

**This was already a partial feature before the migration** —
`tutored_children_section.dart`'s own comment on the row that enters the
talmid dashboard says it's "the tutor's combined-surface entry point until
3d wires the full child-profile view." The other two rows on the same
screen (View invitations, Manage grants) are unaffected and already work.

## Key finding: the new architecture may not need a mirror at all

`firestore.rules` already grants tutors **direct, server-enforced,
cross-account reads** on the talmid's own Firestore subcollections:

```
function hasActiveTutorAccess(ownerUid, profileId) {
  let accessId = request.auth.uid + '_' + ownerUid + '_' + profileId;
  return isSignedIn()
      && exists(/databases/$(database)/documents/tutor_active_access/$(accessId));
}
```

...used as `allow read: if isOwner(uid) || hasActiveTutorAccess(uid, profileId);`
on `points_ledger`, `reward_redemptions`, `settings`, `stage_definitions`,
and the grant's own `audit_log` (the file's own comments cite "V2-R3 C2:
tutor subcollection reads without requiring grantId in the path" — this was
evidently built with cross-account reads in mind). A tutor's device is
already allowed to read the talmid's live documents directly, authenticated
as itself — no local copy needed, no staleness, no wipe-on-revoke (the rule
re-evaluates every read).

The one seam that doesn't exist yet: every Firestore repository provider in
`lib/data/firestore/repository_providers.dart` resolves its `uid` through
`activeAccountFirebaseProvider` (`lib/data/firestore/
active_account_providers.dart`), which is the **signed-in user's own**
active account — there's no concept yet of "read someone else's uid's tree
while staying authenticated as myself."

## Options

**A — Rebuild talmid-view as live cross-account Firestore reads (recommended
target architecture).** Add an "effective read-scope uid" provider,
independent of `activeAccountIdProvider`, that resolves to the talmid's
`ownerUid` (from `TutoredProfileSelection`) when a tutor has entered talmid
view, and to the signed-in user's own uid otherwise. Point the relevant
Firestore repository providers at it. No pull, no mirror, no wipe service,
no synthetic local profile id, no staleness window — simpler than the old
design, and the security enforcement (`hasActiveTutorAccess`) already
exists server-side. Scope question for the owner: does the tutor see the
FULL talmid dashboard (every screen), or a deliberately narrower read-only
subset (e.g. progress + points only)? That's a product call, not an
engineering one.

**B — Minimal read-only summary now, defer full parity.** Ship a stripped
version of talmid view (e.g. progress % and points only, sourced the same
cross-uid way as A) rather than full dashboard parity, as a smaller first
slice.

**C — Stub the entry point now, defer the whole feature.** Change
`_TutoredChildRow`'s tap handler to route to `ManageGrantsRoute` (same
destination the other two rows already use) instead of attempting
pull-and-enter. Delete the now-dead pull/mirror/listener code in the 5
files above. Unblocks compilation and the P0 test **today**, with zero
data fabrication (this disables an already-incomplete feature rather than
faking data for a live one — consistent with the D-E owner ruling). The
full talmid dashboard becomes a separate future story built on Option A.

## Recommendation

C now, A later. The app not compiling blocks every other pending item in
this migration (product-visible or not), so restoring compilation is
strictly higher priority than finishing this one feature. C is fully
reversible — nothing about it forecloses A. I have **not** implemented C —
this file exists so the decision is ready the moment the owner engages;
Task #2 in the working tracker stays flagged as blocked-on-decision, not
defaulted.
