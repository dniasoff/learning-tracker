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

- Keep the authenticated account private. Each learner profile gets a separate social profile with an opaque profile ID, chosen display name/avatar, selected curriculum labels, explicit discoverability setting, and selected fields to share. Do not expose account email, Firebase UID, PIN state, parent identity, or sibling relationships.
- Default profiles to **private and undiscoverable**. An adult explicitly opts into an adult-only username directory and chooses whether to accept follow requests. A random, revocable invite link/QR or contact code lets people connect without publishing an identity. Never upload address-book contacts. Do not make child profiles searchable in any directory; an adult can share an invite with a parent, but the parent must approve any child relationship.
- Use a normalized unique username only for adults who opt into search. Keep the lookup server-mediated (or keyed/hashed), exact-match, rate-limited, and non-enumerable; do not offer prefix search or public follower lists. Invite tokens should be high-entropy, single-purpose, expiring, revocable, and rate-limited. A school directory is searchable only by active members of that school and remains subject to child-specific policy.

### Follow, approval, and removal

- A follow is directional. A **mutual follow** means two separately approved directional edges; it does not create a stronger permission automatically.
- Adults send a request; the recipient accepts or declines. Recommend request-based follows for adults rather than instant follow, because the feature shares learning activity. Both sides can remove a follow at any time. A block prevents new requests and discovery in either direction and removes existing edges; it should not disclose which party blocked whom.
- For a child, every outgoing follow and every incoming follow requires explicit approval by the parent from the parent-PIN-gated area, even if the candidate came through an approved school. The child may suggest a person or accept/decline only within the parent's policy; the parent is the final authority. Parent controls include allowed/denied individual profiles, allowed schools, inbound/outbound policy, pause sharing, and remove/block. The server re-checks the live parent session and current policy inside the callable transaction.
- There is no direct messaging, free-text profile field, public comments, or user-uploaded profile image in the initial release. This avoids unsolicited contact and moderation needs. Use a bounded avatar catalog and fixed action labels.

### What a follower can see

Make sharing field-by-field opt-in and provide a preview. Initial allowlist proposal:

- chosen display name and avatar;
- chosen curriculum names;
- current streak and a coarse today/this-week activity indicator (no exact private study schedule);
- selected active tracks and coarse current position/percentage;
- optional completed masechta/siyum milestones;
- optional points total, with the setting off by default.

Never share Shabbos/location settings or inferred location, PIN or parent-session data, notes, tutor identity/grants/audit log, goals/pace settings, raw event history, exact event timestamps, private curriculum configuration, or account identifiers. Do not show online status. A follower sees no more than the owner's current selected summary and only while the relationship is active. For children, the parent's settings further limit fields; the child cannot enable a broader audience or more fields.

### Freshness without event-log access

Recommend a **server-maintained, sanitized summary projection**, not a client-published snapshot. A client-published summary would let a modified client forge totals or inject arbitrary fields; giving followers event-log access would reveal a detailed private history and make rule boundaries difficult to audit.

Add a server-owned social summary document that contains only the approved public fields and a `computed_at`/schema version. Cloud Functions consume canonical learning events and relevant current-track/program/points changes, update the projection idempotently, and never expose source events to followers. Establish a rebuild/backfill command before enabling sharing because the current progress/streak calculation is client/domain-side; port or share the domain algorithm with golden fixtures rather than inventing a second definition. For V1, prefer a coarse summary that can be recomputed reliably (current streak, this-week activity, active curriculum/position, completed milestone count); omit any metric whose canonical server derivation is not yet verified. Firestore rules allow a follower to read only the summary doc after checking the active edge and current privacy state, never the nested learner collections.

Projection is eventually consistent. Show its update time, tolerate offline/stale summary reads, and do not show optimistic cross-account state. Relationship changes revoke future reads immediately through rules; cached data may remain on an already-authorized device until its local cache is cleared, so use short-lived listeners/cache policy and clear social caches on unfollow, block, sign-out, and account switch.

## 2. School profiles and membership

### Organization identity and verification

- A school is an organization identity, not a learner account. Store its display name, optional logo from a controlled asset set, verified state, admin profile/account references, membership policy, and audit timestamps separately from learner profiles.
- An adult account creates a **pending/unlisted** school profile and nominates an administrator. It becomes verified only after a human support review of an authoritative school contact/domain or equivalent evidence, with the verification method and reviewer recorded privately. Do not treat possession of a school email domain alone as conclusive: school domains may be shared, abandoned, or spoofed. Unverified schools cannot appear in discovery or issue member invites. Provide admin recovery/transfer and suspension; a school cannot verify itself by client write.
- School administrators can invite adult learner profiles using expiring, revocable, single-use or tightly capped invite codes/links. A learner joins only after accepting and the school admin approves, if the school uses approval. Joining a child additionally requires parent approval in the PIN-gated area. An admin-issued invite is not child consent.

### Visibility, staff access, and lifecycle

- School membership enables finding other members only inside the same active school. The directory returns minimal profile cards, excludes children unless the child's parent has enabled that school as an allowed discovery context, and never makes children publicly searchable. Child-to-child visibility is further constrained by each child's parent policy; directory visibility is not itself a follow or progress grant.
- A school admin/teacher has **no default progress access**. Membership and school administration do not confer `can_view_progress`. If a school requests progress access, use individually consented, auditable tutor-grant-like grants per learner (parent session and approval for a child), with explicit read-only scope and immediate revoke. Do not create a single broad school grant that grants access to every member. Open question: whether to ship this staff access at all or defer it.
- Support multiple simultaneous school memberships. Learners/parents can leave at any time; school admins may remove a member with a notice/reason code and audit trail. Leaving/removal removes school-directory visibility, cancels pending school invites, and re-evaluates child school allow-lists. It does not silently delete independent follow edges; parent/learner can review and remove those separately. Suspending a school disables discovery/invites and freezes admin actions. Deleting a school requires transfer or explicit closure, removes memberships/invites and group containers, and revokes any separately granted staff access; learner summaries/progress remain with their owners.
- School admin changes, verification, membership decisions, removals, suspensions, and deletion need server-side audit records. Never log invite tokens, PINs, or learning details.

## 3. Group learning tasks (`learning-tracker-k8j`, dependent on bkj)

### Product shape and data model

- A group is a small, explicit roster with one or more adult admins. It may be hosted by a verified school, but school membership alone does not enroll someone in a group. A group can also be independent of a school. Roster additions require member acceptance; child participation additionally requires parent approval and obeys the parent's allowed-school/person policy.
- A group task names a curriculum and a bounded scope (whole curriculum or selected section), a deadline/time zone, allocation policy/version, and status. Members receive a notification and submit preferences: selected masechtos/sedarim/sections, “assign me anything,” exclusions, and an optional sustainable capacity/pace. Do not treat a preference as an assignment until the server publishes the allocation.
- Proposed server-owned collections: `learning_groups/{groupId}`, `learning_groups/{groupId}/members/{profileId}`, `learning_groups/{groupId}/tasks/{taskId}`, task preferences, immutable allocation versions, member assignments, and unique unit claims. Store learner profile references as `(ownerUid, profileId)` and never copy private profile data into group docs. Client writes are denied; callable APIs validate roster/admin role and parent session where required.
- An assignment is represented in the member's ordinary Learn surface by a group-backed sub-track/assignment linked to that member's curriculum track and the group task. Reuse the existing `sub_tracks` and `learning_events` model when its current semantics support the curriculum unit; ordinary learning continues to drive that learner's progress, streak, and points. Add a stable group-assignment source/id so the group projection can attribute completion without giving the group access to unrelated learning. If a requested curriculum cannot be represented by the current sub-track model, resolve that mapping before implementation rather than inventing an untracked progress path.

### Deterministic, explainable allocation

Run allocation on the server. The request records normalized preferences and capacities; the function validates scope/deadline, reads current roster/task/claims transactionally, computes an allocation, then writes a versioned immutable plan and assignment records. Include the algorithm version, eligible-unit count/weight, member capacity, preference match, and concise reason per allocation so members/admins can understand the split. Stable tie-breakers (for example task ID + canonical unit ID + member ID) make the result repeatable.

Recommended V1 algorithm:

1. Expand the task into canonical, non-overlapping assignable units and weights using the curriculum's actual item counts where available (e.g. Mishnayos count), otherwise an explicitly documented fallback. Do not use guessed equal-size masechta weights.
2. Remove units already completed for this task and units already held by an active unique claim. Apply member exclusions and preferred units first; honor capacity caps derived from each member's stated pace and remaining time to deadline.
3. Allocate the remaining units among eligible members with a deterministic weighted-balance pass that minimizes the largest projected workload/capacity ratio, then the total ratio variance; use stable tie-breaks. If preferences/capacity make the deadline infeasible, mark the task “needs adjustment” and show the shortfall instead of promising completion.
4. Persist one allocation version and one active owner per unit in a transaction/bounded batched server operation. A unique `(taskId, unitId)` claim prevents two members from getting the same unit. Concurrent preference edits trigger a new version; do not mutate prior assignment history invisibly.

Conflict behavior: if two members select the same masechta, treat it as a preference conflict, not a duplicate assignment. The server allocates that unit once using preference priority plus fairness/capacity; the other member gets the next eligible unit and an explanation. If the product lets members manually claim individual units, the first valid server transaction wins, the second receives a conflict response and refreshed choices. Shared completion should be idempotent and attributed to the assignment source only.

### Reassignment and group progress

- Admin can rebalance, add/remove members, change deadline/scope, or lock a plan. A member can leave; their unfinished units return to the eligible pool only after an admin/member-confirmed release. Falling-behind detection should be based on the task's expected pace and a grace window, then notify the member/admin and offer reallocation; never silently take work away. Reassignment creates a new allocation version and preserves the audit trail.
- Group progress shows only task-level completion, assigned workload, and member-assignment status needed to coordinate the siyum. Each member sees other members' assignment titles and coarse completion state within that group, not their full profile summary, unrelated curricula, private daily schedule, location, points, notes, or raw events. For child members, parent policy governs joining and the shared group fields; the parent's allow-list and child follow policy still apply.
- Notifications use FCM for task invitation, assignment published/changed, due-date reminder (opt-in), reassignment request, and siyum completion. Send data-only types and render localized generic copy; suppress sensitive task/member details on lock screens and in child mode according to existing notification behavior. Group notifications should not bypass the member's notification settings.

## 4. Security, abuse, deletion, and offline behavior

- Relationship edges, requests, blocks, school admin/membership state, group roster/tasks/claims/allocations, and summary projections are server-owned. Add narrowly scoped Firestore rules for reads: caller can see only their own relationship/request/admin inbox, a profile's sanitized summary when an active allowed relationship grants it, school directory cards for active eligible members, and task assignment/group progress for active group members. Explicitly deny all raw learner event, points ledger, notes, tutor data, parent PIN/session, location, and account-profile cross-user reads. Account owners retain current rules; no broadening of `hasActiveTutorAccess`.
- Callables validate auth UID, profile ownership, profile mode, active relationship/school/group state, target privacy, block lists, current parent session for every child decision, school verification, admin authority, and allowed fields. Use transactions for request state, follow limits, membership/code consumption, unique task claims, allocation version checks, and revocation races. Maintain audit records for parent approvals, school admin/member actions, group allocations/reassignments, and staff grants.
- Rate-limit username lookup, invite creation/redemption, follow requests, blocks, school membership requests, group invitations, and task reallocation. Bound query pages and roster/group sizes. Use exact search only, generic not-found responses, abuse reporting, request cooldowns, duplicate suppression, and per-account/device quotas. Keep logs free of tokens, names, curriculum activity, and child identifiers.
- `deleteLearnerProfile` currently recursively removes nested profile data; `onUserDeleted` removes user data and revokes tutor grants. Extend these server cleanup paths to revoke social edges/requests, remove profile lookup entries, clear summary projections and memberships/assignments, release task claims, update affected groups/schools, and notify counterparties with privacy-preserving “profile unavailable” state. Account deletion must remove school admin authority or require/perform an audited transfer; deleting a school cascades memberships, invites, and groups while leaving learner-owned progress intact. Use idempotent cleanup and scheduled orphan reconciliation for cross-document graphs.
- Offline mode shows cached own data only. Do not queue relationship approvals, school changes, group joins, assignments, or rebalances as if successful; require server confirmation. Pending adult requests may be shown with an explicit pending state. Social/group summary is read-only and may be stale with its computed time visible. Clear cached social summaries on revoke/block/sign-out/account switch.
- Child safety and compliance: child profiles are never publicly searchable, have no direct messages/free text/contact discovery, and require parent approval at each child relationship/school/group boundary. Do not collect date of birth or other age data unless the owner/legal review requires it. Before release, review applicable child privacy/consent requirements (including COPPA-style obligations where relevant), Google Play Families policy/target-audience disclosures, push behavior, school-account handling, retention/deletion, and any jurisdiction-specific school/education-data rules with product/legal owners. This plan flags review work; it does not determine legal applicability.

## 5. UI and localization

- Add **Community** under Progress for profiles, discoverability/sharing controls, followers/following, outgoing requests, and incoming requests. Keep profile settings in the adult settings area and child social settings behind the parent-PIN-gated surface.
- Profile page: chosen identity, curriculum chips, explicitly shared summary fields, last-updated indicator, follow/request state, remove/block/report controls, and no private details. Lists paginate and expose only permitted profiles.
- Parent screen: separate “people my child may follow,” “people who may follow my child,” allowed-school list, pending child outgoing/incoming approvals, current relationships, and pause/remove actions. Show each decision's audience and shared fields before approval.
- School surfaces: verified school page, membership/invite status, admin roster tools, member directory with child policy filters, leave/remove flow, and audit/admin handoff. Explain that membership does not grant progress access.
- Group tasks: group roster and admin page, task creation/scope/deadline, member preference/capacity editor, allocation preview with reason/weight, conflict explanation, assigned group track in Learn, group siyum progress, and reallocation review screen. Child invitation and task enrollment flow through parent approval.
- Add English and Hebrew ARB keys for every new string, verify plural forms, long Hebrew labels, RTL direction, avatar/visibility icons, dialogs, and notification copy. Avoid concatenated strings and user-generated free text.

## 6. Delivery in reviewable beads

Keep each bead independently reviewable and avoid a large cross-cutting PR. The existing `learning-tracker-k8j` depends on bkj; preserve that dependency.

1. **bkj-1: social identity, privacy, and relationship schema** — final data contract, server-owned collections, adult discoverability/privacy defaults, callable request/accept/decline/remove/block flows, indexes, and Firestore rules. Add rules emulator tests before enabling any cross-account read.
2. **bkj-2: parent-controlled child policy** — parent session gated allow/deny people and schools, inbound/outbound approvals, policy re-checks/race tests, and parent approval UI. Children remain excluded from public search.
3. **bkj-3: sanitized social summary projection** — verify/reuse progress algorithms, build idempotent server projection/rebuild, enforce field whitelist and active-edge reads, and test source-event isolation and revocation. Start with metrics that have verified server derivation.
4. **bkj-4: school profiles and membership** — pending/verified organization lifecycle, support verification/admin transfer, invite and approval flows, school-only directory, multiple memberships, child policy, staff access consent decision, deletion/suspension cleanup, abuse limits, and rules tests.
5. **bkj-5: adult/parent social UI and en/he localization** — Community screens, profiles, lists, requests, sharing preview, school surfaces, notifications, RTL, accessibility and cache clearing.
6. **k8j-1: group/task schema and authorization** — group membership, school hosting link, child approvals, task lifecycle, preference/capacity schema, unique unit claims, privacy rules and emulator tests. Depends on bkj identity/school contract.
7. **k8j-2: deterministic allocation and reallocation** — documented weighted algorithm/versioning, conflict transactions, infeasibility/late/dropout handling, audit trail, server unit tests/golden fixtures, and concurrency tests.
8. **k8j-3: Learn integration and group progress** — group-backed sub-track/source, ordinary learning event attribution, progress aggregation, group task/admin/member UI, FCM events, en/he, offline behavior and deletion cleanup.

If the issue system requires all work under the two existing beads, use these as child beads rather than creating repo TODO lists. Add any legally required review as an explicit release gate, not a hidden implementation dependency.

## 7. Test strategy (rules emulator tests are essential)

Follow the project's lean testing policy: run targeted tests for changed code only; no full suite, emulator build, or device build in this planning lane. Implementation must include:

- Firestore rules emulator matrix: anonymous; unrelated account; owner; accepted follower; pending/removed/blocked follower; school member/nonmember; verified/unverified school; group member/nonmember/admin; parent and child; child whose school/person policy changes mid-request. Verify summary reads only and raw events/points/notes/location/tutor/PIN/session reads always denied cross-account. Test bounded queries and pagination.
- Callable tests for state transitions, input allowlists, auth/owner checks, parent-session missing/expired/revoked/wrong-profile cases, block/privacy policy races, rate limits, one-use invite code redemption, deletion cleanup idempotency, and concurrent duplicate follow/membership/task-claim attempts.
- Projection tests against golden domain fixtures for streak, today/week, active track position, points (if enabled), and milestones; duplicate/out-of-order/retried event delivery; rebuild equality; removed field consent; and follower access revocation. Never validate summaries by giving a test follower access to the source events.
- Allocation unit tests for unequal unit weights, member capacities/deadline, preferences/exclusions, two people preferring the same masechta, no capacity/infeasible tasks, deterministic repeatability/tie-breaking, join/leave/late/dropout reallocation, retries, and transaction races. Assert no unit is simultaneously assigned twice and completed units are not silently reissued.
- UI tests for adult requests/blocks, parent-gated child approvals and allow-lists, school invite/leave/admin transfer, group preference/allocation explanations, Learn integration, notification settings, stale/offline state, English/Hebrew/RTL, and accessibility labels.
- Keep a minimal set of cross-account emulator integration cases that prove a child/member cannot read any data beyond the exact summary/group projection granted. Review rule coverage for every new match; no CI pass alone implies deployment.

## 8. Owner decisions

These choices change authorization, discoverability, and the allocation contract, so settle them before implementation.

1. **Adult discovery and default sharing:** (A) private/undiscoverable until the adult opts into exact-username search and selected summary fields; (B) searchable by default with opt-out. **Recommendation: A.**
2. **Adult follow behavior:** (A) recipient must accept each request; (B) instant follow for discoverable adults, with block/remove. **Recommendation: A**, because progress is personal activity and request approval is a small added step.
3. **School verification and creation:** (A) anyone may create a public school profile immediately; (B) adult-created pending profile, human verification before directory/invites, admin transfer/recovery. **Recommendation: B**, with support review based on authoritative evidence and a clear fallback for schools without a domain.
4. **School staff progress access:** (A) school admins/teachers never see learner progress; (B) each learner/parent grants a tutor-style, read-only per-learner permission; (C) school admin gets roster-wide progress by membership. **Recommendation: B only if required by the product; otherwise defer. Never C.**
5. **School member discovery for children:** (A) no school directory for children; parent can approve named invitees only; (B) a parent can enable a school-bounded directory, with every follow still individually parent-approved. **Recommendation: B**, default off, since it supports the requested school-only allow-list while retaining per-relationship approval.
6. **Group assignment unit and overlap:** (A) indivisible whole masechta units, one member owns each; (B) smaller canonical sections may be split when needed, but any one unit has one assignee; (C) duplicate/overlapping assignment is allowed for group study. **Recommendation: B**, with whole masechta preference first and deterministic smaller-unit fallback to fit capacity; never count the same unit twice toward the siyum.
7. **Allocation inputs and changes:** (A) member preferences are advisory, with explicit capacity/pace and admin-confirmed rebalancing; (B) preferences are hard claims and app automatically reassigns when someone falls behind. **Recommendation: A**, plus notify and offer a proposed reallocation after an agreed grace window; do not silently take assigned work away.
8. **Group progress visibility:** (A) members see only their own assignments and aggregate group totals; (B) members see each other's assigned units and coarse completion; (C) full learner progress summaries are visible to the group. **Recommendation: B**, limited to the task, with child participation and fields subject to parent approval; never C by default.

## References inspected

- `docs/firestore-collection-layout.md`
- `learning_tracker/firestore.rules`
- `learning_tracker/functions/src/{parent_sessions.ts,parent_session_validation.ts,tutor_invites.ts,notifications.ts,deletes.ts,index.ts}`
- `learning_tracker/lib/data/repositories/firestore_learner_profile_repository.dart`
- `learning_tracker/lib/features/progress/` and the canonical `learning_events` / `points_ledger` repositories

