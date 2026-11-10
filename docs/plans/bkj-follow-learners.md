# Social profiles, schools, and group learning tasks

**Status:** planning proposal for `learning-tracker-bkj` (social profiles/follows) and dependent `learning-tracker-k8j` (group learning tasks). No production code is part of this plan.

**Owner request:** learners can follow each other and share progress. A parent controls who a child may follow and who may follow the child. Schools can provide a bounded community and host groups. Group admins can set a curriculum-and-deadline task, members choose preferences/capacity, and the app allocates the work toward a shared siyum.

## Existing system and reuse

- Firebase Auth identifies an **account** (`users/{uid}`); an account owns one or more **learner profiles** at `users/{uid}/learner_profiles/{profileId}`. Learner profiles carry `display_name`, `avatar`, and `mode` (`adult`/`child`). Social identity must be profile-scoped so siblings are not conflated with the adult account. Relevant code: `docs/firestore-collection-layout.md`, `learning_tracker/lib/data/repositories/firestore_learner_profile_repository.dart`.
- Parent authority already has a server-verified PIN flow: `createParentSession` checks the PIN and issues a 30-minute session, and `assertActiveParentSessionInTransaction` validates it for server writes. Child social settings, child follow approvals, child school membership, and child group enrollment should use this parent-session boundary from the parent-only UI. Relevant code: `learning_tracker/functions/src/parent_sessions.ts`, `learning_tracker/functions/src/parent_session_validation.ts`.
- `tutor_grants/{grantId}` is the closest existing cross-account consent model: only callables create/change grants; `listTutorGrants` returns bounded relationship state; `tutor_active_access` is a server-maintained read index; and each grant has an audit log and scoped permissions. Keep social relationships separate from tutor grants, but reuse their server-owned state transitions, explicit consent, revoke semantics, auditability, and account deletion handling. School membership must not silently become tutor access. Relevant code: `learning_tracker/functions/src/tutor_invites.ts`, `learning_tracker/firestore.rules`, `docs/firestore-collection-layout.md`.
- Learner progress is not currently a ready-made public snapshot. The canonical learning history is the per-profile `learning_events` stream; progress views and streak/lifetime calculations are client/domain projections over that history and local state. Points have a separate `points_ledger`. Reading another profile's raw event stream would reveal detailed history and grant excessive access. Keep the current owner/tutor reads as they are and expose only a distinct, whitelisted social summary.
- Firestore uses default-deny rules, nested account ownership, and server-only writes for cross-account access. Functions are exported through `learning_tracker/functions/src/index.ts`. New relationship and organization writes should be callable-only; client writes to their backing collections should be denied.
- Existing notifications use data-only FCM, localized client copy, idempotent delivery receipts, and suppress child-mode presentation. Reuse that pattern for social/group notifications without putting progress, child names, or private content in notification text/payloads. Relevant code: `learning_tracker/functions/src/notifications.ts`.
- `ProgressScreen` and the Learn list already provide suitable surfaces. Add a social/community entry within Progress first; add a group assignment as a recognizable group-backed track/sub-track in the member's Learn list so ordinary learning events, progress, points, and streak behavior continue through existing paths. English and Hebrew strings must be added to both ARB catalogs, with RTL review.

## 1. Social concepts and privacy

### Learner profile and discovery

- Keep the authenticated account private. Each learner profile gets a separate social profile with an opaque profile ID, chosen display name/avatar, selected curriculum labels, and selected fields to share. Do not expose account email, Firebase UID, PIN state, parent identity, or sibling relationships.
- There is no public learner directory or username search. Connect through a high-entropy, revocable invite link/QR, or find learners only in a school directory for schools where the searching learner is a member. School member search is exact-match or tightly bounded, server-mediated, rate-limited, paginated, and non-enumerable; do not offer global/prefix search or public follower lists. Never upload address-book contacts. A child can search only within the parent's allow-listed schools and eligible results, but a child's profile never appears in search results. Child follow requests are allowed only between members of schools in the parent's allow-list and require parent approval.
- Invite tokens should be high-entropy, single-purpose, expiring, revocable, and rate-limited. Before creating a follow request to or from a child, the server verifies that both learners are inside at least one school in the child's parent-maintained allow-list. A link/QR cannot bypass that eligibility check.

### Follow, approval, and removal

- A follow is directional. A **mutual follow** means two separately approved directional edges; it does not create a stronger permission automatically.
- Adults send a request; the recipient accepts or declines. Both sides can remove a follow at any time. A block prevents new requests and discovery in either direction and removes existing edges; it should not disclose which party blocked whom.
- For a child, only people inside schools in the parent's allow-list are eligible to request a follow or receive a request from the child. The parent approves every eligible incoming and outgoing follow in the PIN-gated area. The child may suggest a person but cannot bypass parent approval. The server re-checks the live parent session, both school memberships, and the current allow-list inside the callable transaction. Parent controls include school allow-list, inbound/outbound approvals, pause sharing, and remove/block.
- There is no direct messaging, free-text profile field, public comments, or user-uploaded profile image in the initial release. This avoids unsolicited contact and moderation needs. Use a bounded avatar catalog and fixed action labels.

### What a follower can see

The social summary allowlist is fixed to the owner-approved fields below. Provide a preview and a parent-facing child consent summary:

- chosen display name and avatar;
- streak;
- current tracks and position;
- this week's learning;
- siyumim.

Do not share points. Never share Shabbos/location settings or inferred location, PIN or parent-session data, notes, tutor data, change history, raw event history, exact event timestamps, private curriculum configuration, or account identifiers. Do not show online status. A follower sees these fields only while the relationship is active. For children, the parent approves each relationship and sharing audience; a child cannot broaden the approved fields or audience.

### Freshness without event-log access

Recommend a **server-maintained, sanitized summary projection**, not a client-published snapshot. A client-published summary would let a modified client forge totals or inject arbitrary fields; giving followers event-log access would reveal a detailed private history and make rule boundaries difficult to audit.

Add a server-owned social summary document that contains only the approved public fields and a `computed_at`/schema version. Cloud Functions consume canonical learning events and relevant current-track/program state, update the projection idempotently, and never expose source events to followers. Establish a rebuild/backfill command before enabling sharing because the current progress/streak calculation is client/domain-side; port or share the domain algorithm with golden fixtures rather than inventing a second definition. Omit any metric whose canonical server derivation is not yet verified. Firestore rules allow a follower to read only the summary doc after checking the active edge and current privacy state, never the nested learner collections.

Projection is eventually consistent. Show its update time, tolerate offline/stale summary reads, and do not show optimistic cross-account state. Relationship changes revoke future reads immediately through rules; cached data may remain on an already-authorized device until its local cache is cleared, so use short-lived listeners/cache policy and clear social caches on unfollow, block, sign-out, and account switch.

## 2. School profiles and membership

### Organization identity and verification

- A school is an organization identity, not a learner account. Store its display name, optional logo from a controlled asset set, creator/admin profile references, creation date, optional owner-granted verification badge, membership policy, and audit timestamps separately from learner profiles.
- Anyone may create a school profile immediately; there is no mandatory pre-verification gate. Show the creator/admins and creation date on the school page, let the app owner grant an optional verified badge, and provide a report-school action with an owner review/suspension path. A school cannot grant itself the verified badge. Keep admin recovery/transfer and suspension controls; rate-limit creation and investigate reports for impersonation or abuse.
- School administrators can invite adult learner profiles using expiring, revocable, single-use or tightly capped invite codes/links. A learner joins only after accepting and the school admin approves, if the school uses approval. The join screen states that school staff automatically receive view-only access to member progress. Joining a child additionally requires parent approval in the PIN-gated area, with an explicit statement that school staff will see the child's progress; that parent approval is the consent. An admin-issued invite is not child consent.

### Visibility, staff access, and lifecycle

- School membership enables finding members only inside the same active school. There is no public learner directory and a child's profile never appears in search results. When a child searches, results are restricted to eligible people in the parent's allow-listed schools; that list also governs who may send or receive the child's follow requests, with parent approval required for each follow. Directory visibility does not itself create a follow.
- School staff automatically receive **view-only progress access** for active members. Model this as a school-scoped set of per-member read grants (a school can be represented as a group of tutor-style grants), with explicit staff roles, audit of reads/admin changes, and prompt revocation when membership or staff role ends. Keep the access projection limited to progress; it never grants edit rights or access to PINs, location/Shabbos settings, notes, tutor data, or change history. The adult school join screen discloses staff visibility; the parent-PIN-gated child join approval explicitly names it and records the consent.
- Support multiple simultaneous school memberships. Learners/parents can leave at any time; school admins may remove a member with a notice/reason code and audit trail. Leaving/removal removes school-directory visibility, cancels pending school invites, and re-evaluates child school allow-lists. It does not silently delete independent follow edges; parent/learner can review and remove those separately. Suspending a school disables discovery/invites and freezes admin actions. Deleting a school requires transfer or explicit closure, removes memberships/invites and group containers, and revokes any separately granted staff access; learner summaries/progress remain with their owners.
- School admin changes, verification, membership decisions, removals, suspensions, and deletion need server-side audit records. Never log invite tokens, PINs, or learning details.

## 3. Group learning tasks (`learning-tracker-k8j`, dependent on bkj)

### Product shape and data model

- Any adult may create a private group. A school may also create groups for its members. A school-hosted group roster is separate from school membership; membership alone does not enroll someone in a group. Roster additions require member acceptance; child participation requires parent approval and obeys the parent's school/person policy.
- A group task names a curriculum and bounded scope (whole curriculum or selected section), deadline/time zone, allocation policy/version, and status. Members receive a notification, rank preferred masechtos/sedarim/sections, and state their capacity. “Assign me anything” is the lowest-friction preference. The server allocates the entire task once, fairly, after preferences/capacities are collected; publish a complete plan and daily schedule to every member.
- Proposed server-owned collections: `learning_groups/{groupId}`, `learning_groups/{groupId}/members/{profileId}`, `learning_groups/{groupId}/tasks/{taskId}`, task preferences, immutable allocation versions, member assignments, and unique unit claims. Store learner profile references as `(ownerUid, profileId)` and never copy private profile data into group docs. Client writes are denied; callable APIs validate roster/admin role and parent session where required.
- An assignment is represented in the member's ordinary Learn surface by a group-backed sub-track/assignment linked to that member's curriculum track and the group task. Reuse the existing `sub_tracks` and `learning_events` model when its current semantics support the curriculum unit; ordinary learning continues to drive that learner's progress, streak, and points. Add a stable group-assignment source/id so the group projection can attribute completion without giving the group access to unrelated learning. If a requested curriculum cannot be represented by the current sub-track model, resolve that mapping before implementation rather than inventing an untracked progress path.

### Deterministic, explainable allocation

Run allocation on the server. The request records normalized preferences and capacities; the function validates scope/deadline, reads current roster/task/claims transactionally, computes an allocation, then writes a versioned immutable plan and assignment records. Include the algorithm version, eligible-unit count/weight, member capacity, preference match, and concise reason per allocation so members/admins can understand the split. Stable tie-breakers (for example task ID + canonical unit ID + member ID) make the result repeatable.

Owner-directed algorithm:

1. Expand the task into canonical, non-overlapping units weighted by actual curriculum workload (e.g. Mishnayos count); allocate whole masechtos first.
2. Use ranked preferences and member capacity to distribute the whole task as evenly as feasible. Split a masechta into perakim only when whole-masechta allocation cannot balance workload/capacity or meet the deadline. Show the resulting plan and daily tasks together.
3. Persist one allocation version and exactly one active owner per unit/perek in a transaction/bounded server operation. Unique `(taskId, unitId)` claims prevent duplicate ownership or double-counting. If the task is infeasible by the deadline, show the shortfall and invite capacity/deadline changes rather than promising completion. Publish the full allocation at once, while surfacing only each member's task for the current day in Learn.

Preference conflict behavior: when multiple members rank the same masechta highly, it remains a single unit and is allocated to one member by the server's fair allocation. Other members receive the next best available work. A perek split creates disjoint perakim with exactly one owner each. Completion is idempotent, attributed to the assignment source, and never counted twice toward the group siyum.

### Reassignment and group progress

- Admin can change the group/task or trigger a new allocation version. Each day, every member receives only that day's assigned task. If a member misses it, the server automatically recalculates that member's own remaining schedule and spreads the missed work over their remaining days within stated capacity. Only if the member cannot realistically finish by the deadline does the remainder return to the group for fair reallocation among other members' remaining capacity. Record the reason/version and notify affected members; do not silently drop completed work or duplicate ownership.
- Group members see one another's full social profiles, limited to the follower-visible fields defined above: chosen display name/avatar, streak, current tracks/position, this week's learning, and siyumim. Points, location/Shabbos, PIN, notes, tutor data, and change history remain excluded. Children can participate only with the required parent approvals; their visibility remains bounded by those approvals.
- Notifications use FCM for task invitations, the complete allocation/daily task, missed-task recalculation, deadline reminders, group reallocation, and siyum completion. Send data-only types and render localized copy; suppress sensitive task/member details on lock screens and in child mode according to existing notification behavior. Group notifications should not bypass member notification settings.

## 4. Security, abuse, deletion, and offline behavior

- Relationship edges, requests, blocks, school admin/membership state, group roster/tasks/claims/allocations, and summary projections are server-owned. Add narrowly scoped Firestore rules for reads: caller can see only their own relationship/request/admin inbox, a profile's sanitized summary when an active follower/group membership grants it, school directory cards for active eligible adult members, and school staff's view-only progress projection for active school members. Group members can see each other's approved social profile fields. Explicitly deny all raw learner event, points ledger, notes, tutor data, change history, parent PIN/session, location, and account-profile cross-user reads. Account owners retain current rules; no broadening of `hasActiveTutorAccess`.
- Callables validate auth UID, profile ownership, profile mode, active relationship/school/group state, target privacy, block lists, current parent session for every child decision, school verification, admin authority, and allowed fields. Use transactions for request state, follow limits, membership/code consumption, unique task claims, allocation version checks, and revocation races. Maintain audit records for parent approvals, school admin/member actions, group allocations/reassignments, and staff grants.
- Rate-limit school creation/reporting, member search within a school, invite creation/redemption, follow requests, blocks, school membership requests, group invitations, and task recalculation. Bound query pages and roster/group sizes. Use school-scoped search only, generic not-found responses, abuse reporting and owner moderation for school impersonation, request cooldowns, duplicate suppression, and per-account/device quotas. Keep logs free of tokens, names, curriculum activity, and child identifiers.
- `deleteLearnerProfile` currently recursively removes nested profile data; `onUserDeleted` removes user data and revokes tutor grants. Extend these server cleanup paths to revoke social edges/requests, remove profile lookup entries, clear summary projections and memberships/assignments, release task claims, update affected groups/schools, and notify counterparties with privacy-preserving “profile unavailable” state. Account deletion must remove school admin authority or require/perform an audited transfer; deleting a school cascades memberships, invites, and groups while leaving learner-owned progress intact. Use idempotent cleanup and scheduled orphan reconciliation for cross-document graphs.
- Offline mode shows cached own data only. Do not queue relationship approvals, school changes, group joins, assignments, or rebalances as if successful; require server confirmation. Pending adult requests may be shown with an explicit pending state. Social/group summary is read-only and may be stale with its computed time visible. Clear cached social summaries on revoke/block/sign-out/account switch.
- Child safety and compliance: child profiles are never publicly searchable, have no direct messages/free text/contact discovery, and require parent approval at each child relationship/school/group boundary. Do not collect date of birth or other age data unless the owner/legal review requires it. Before release, review applicable child privacy/consent requirements (including COPPA-style obligations where relevant), Google Play Families policy/target-audience disclosures, push behavior, school-account handling, retention/deletion, and any jurisdiction-specific school/education-data rules with product/legal owners. This plan flags review work; it does not determine legal applicability.

## 5. UI and localization

- Add **Community** under Progress for profiles, discoverability/sharing controls, followers/following, outgoing requests, and incoming requests. Keep profile settings in the adult settings area and child social settings behind the parent-PIN-gated surface.
- Profile page: chosen identity, curriculum chips, explicitly shared summary fields, last-updated indicator, follow/request state, remove/block/report controls, and no private details. Lists paginate and expose only permitted profiles.
- Parent screen: allowed-school list; child follow requests to/from eligible people in those schools; parent approval queue for every inbound/outbound child follow; current relationships; pause/remove actions. Show fields/audience before approval.
- School surfaces: school profile with creator/admins, creation date, optional owner-granted verified badge, and report-school action; membership/invite status; staff roster and view-only progress; school-only member search; leave/remove flow; audit/admin handoff. Child join confirmation explicitly states staff progress visibility.
- Group tasks: private group creation for any adult and school-hosted groups for school members; group roster/admin page; task scope/deadline; ranked preference/capacity entry; all-at-once allocation preview showing whole masechtos and any perakim splits; daily task card in Learn; missed-day recalculation explanation; group siyum progress; and updated daily schedule. Group members see the full follower-visible profile fields. Child invitation and enrollment flow through parent approval.
- Add English and Hebrew ARB keys for every new string, verify plural forms, long Hebrew labels, RTL direction, avatar/visibility icons, dialogs, and notification copy. Avoid concatenated strings and user-generated free text.

## 6. Delivery in reviewable beads

Six implementation beads were created, with dependency links recorded in Beads. The existing `learning-tracker-k8j` depends on `learning-tracker-bkj`.

1. **`learning-tracker-ay8` — Social: Build school-scoped follow requests and parent child controls.** Depends on `learning-tracker-bkj`.
2. **`learning-tracker-w4v` — Social: Publish follower progress summaries and community UI.** Depends on `learning-tracker-bkj` and `learning-tracker-ay8`.
3. **`learning-tracker-4ll` — Schools: Add open school profiles, membership and staff progress access.** Depends on `learning-tracker-bkj` and `learning-tracker-ay8`.
4. **`learning-tracker-3cx` — Groups: Add private and school-hosted groups with child consent.** Depends on `learning-tracker-k8j` and `learning-tracker-4ll`.
5. **`learning-tracker-va7` — Groups: Allocate whole masechtos and daily assignments fairly.** Depends on `learning-tracker-k8j` and `learning-tracker-3cx`.
6. **`learning-tracker-9sm` — Groups: Rebalance missed work and integrate shared progress in Learn.** Depends on `learning-tracker-k8j`, `learning-tracker-va7`, and `learning-tracker-w4v`.

All six are open task beads; implementation details and acceptance boundaries are in each bead. Any legally required review remains an explicit release gate.

## 7. Test strategy (rules emulator tests are essential)

Follow the project's lean testing policy: run targeted tests for changed code only; no full suite, emulator build, or device build in this planning lane. Implementation must include:

- Firestore rules emulator matrix: anonymous; unrelated account; owner; accepted follower; pending/removed/blocked follower; school member/nonmember; owner-badged/unbadged school; creator/admin/staff; group member/nonmember/admin; parent and child; child whose school/person policy changes mid-request. Verify school creation does not require verification and clients cannot grant the owner badge; verify only the exact follower/school-staff/group profile scopes are readable; points, raw events, notes, location, tutor data, change history, PIN/session always remain denied cross-account. Test bounded queries and pagination.
- Callable tests for state transitions, input allowlists, auth/owner checks, parent-session missing/expired/revoked/wrong-profile cases, block/privacy policy races, rate limits, one-use invite code redemption, deletion cleanup idempotency, and concurrent duplicate follow/membership/task-claim attempts.
- Projection tests against golden domain fixtures for streak, this week's learning, active track position, and siyumim; duplicate/out-of-order/retried event delivery; rebuild equality; field allowlist; and follower access revocation. Assert points and every never-share field stay out. Never validate summaries by giving a test follower access to source events.
- Allocation unit tests for unequal masechta weights, ranked preferences, member capacities/deadline, whole-masechta preference and perek fallback, two people ranking the same masechta, no capacity/infeasible tasks, deterministic repeatability/tie-breaking, all-at-once publication, daily schedules, missed-day redistribution across the member's own remaining days, group fallback only when deadline completion is unrealistic, retries, and transaction races. Assert no unit is assigned or counted twice.
- UI tests for adult requests/blocks, parent-gated child allow-list and approvals, school creation metadata/report/optional verification/staff access/join consent, group preference/allocation explanations, daily tasks and missed-day recalculation, Learn integration, notification settings, stale/offline state, English/Hebrew/RTL, and accessibility labels.
- Keep a minimal set of cross-account emulator integration cases that prove a child/member cannot read any data beyond the exact summary/group projection granted. Review rule coverage for every new match; no CI pass alone implies deployment.

## 8. Confirmed owner decisions

The owner answered all design questions on 2026-11-10. These decisions are binding for implementation; no owner questions remain open.

1. **Discovery:** connect by invite link/QR and search only within schools the learner belongs to. There is no public learner directory. Children are never searchable.
2. **Adult follows:** every adult follow begins as a request the recipient must approve.
3. **Follower-visible fields:** streak, current tracks and position, this week's learning, and siyumim. Do not show points. Never show location/Shabbos data, PIN, notes, tutor data, or change history.
4. **Child follows:** only people inside schools in the parent's allow-list can even request to follow or be followed by a child. The parent approves each incoming and outgoing follow in the PIN-gated area.
5. **School profiles:** anyone may create a school profile immediately. Show its creator/admins and creation date; the app owner may grant an optional verified badge; provide a report-school action.
6. **School staff access:** staff automatically receive view-only access to members' progress. For a child, school-join approval must clearly state that staff will see the child's progress; that parent approval is the consent.
7. **Group allocation:** members rank learning preferences and state their capacity. The app assigns the whole task at once as fairly as possible.
8. **Group creation:** any adult may create a private group; a school may also create groups for its members.
9. **Assignment granularity:** assign whole masechtos first; split into perakim only when needed. Each piece has exactly one owner and is counted once.
10. **Group visibility:** members see each other's full profiles, meaning the follower-visible fields in decision 3. Children remain subject to parent approval.
11. **Daily recovery:** each day every member receives a task for that day. If a member misses work, first spread it over that member's own remaining days. Only when that member cannot realistically finish by the deadline does the remaining work return to the group for reallocation.

## References inspected

- `docs/firestore-collection-layout.md`
- `learning_tracker/firestore.rules`
- `learning_tracker/functions/src/{parent_sessions.ts,parent_session_validation.ts,tutor_invites.ts,notifications.ts,deletes.ts,index.ts}`
- `learning_tracker/lib/data/repositories/firestore_learner_profile_repository.dart`
- `learning_tracker/lib/features/progress/` and the canonical `learning_events` / `points_ledger` repositories

