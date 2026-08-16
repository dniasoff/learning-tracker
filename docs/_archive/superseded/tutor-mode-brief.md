# Tutor Mode — Requirements Brief

**Date:** 2026-05-20
**Status:** Draft — elicited via BA session with Mary, pending Daniel's sign-off
**Owner:** Daniel
**Source:** Interactive requirements elicitation (16 structured questions across 5 clusters)
**Consumer:** Tech-debt remediation plan v3 (folds this into the single-push refactor)

---

## Executive summary

Tutor mode grants a designated tutor (typically a paid Rebbe / hired professional) access to a specific child's learning profile. A tutor can do everything the parent can do *except* mark a live forward completion that would credit the child's streak / rewards. The relationship is **M:N**: one tutor can serve many children across many families, and one child can have many tutors. The feature lands as part of the same refactor wave that rebuilds the account / profile / sync subsystems, so the data model and Firestore rules absorb it natively rather than retrofitting later.

---

## Stakeholders

| Role | Description |
|---|---|
| **Creator-parent** | The parent who originally created the child profile. Sole authority for invite / revoke decisions on that child's tutors. |
| **Tutor (external)** | Typically a paid professional (Rebbe / hired tutor). Holds tutoring relationships across multiple unrelated families. Can simultaneously be a parent in their own right. |
| **Child** | The learner whose profile is shared. Sees which tutors have access; takes no active role in the invite lifecycle. |
| **Co-tutors** | Multiple tutors on the same child. Operate independently; do not see each other. |

---

## Use cases

1. **Invite a tutor** — Creator-parent enters the tutor's email; system creates a pending grant + transactional email + copyable share link.
2. **Accept an invite** — Tutor opens the link, signs up or signs in (must have an account), sets a Tutor PIN if not yet set, and the grant becomes active.
3. **Decline a pending invite** — Tutor declines before accepting; grant transitions to declined.
4. **Tutor a child** — Tutor switches into the tutored child's profile (after Tutor PIN check), sees their data, configures learning content, advances bookmarks, performs bulk-prior corrections.
5. **Revoke a tutor** — Creator-parent ends a grant; tutor immediately loses access.
6. **Resign a grant** — Tutor unilaterally ends an active grant; parent sees the resignation.
7. **Review tutor activity** — Parent opens audit log for a child and sees per-action history of every tutor change.
8. **Skip track setup at sign-up** — A new user (typically a tutor) signs up without creating their own learning track.

---

## Functional requirements

### FR-1 · Identity & relationships

- **FR-1.1** A creator-parent (the parent who created a child profile) is the sole authority for issuing invites and revoking grants on that child.
- **FR-1.2** A child profile may have zero or many active tutor grants (M:N).
- **FR-1.3** A tutor may simultaneously hold tutor grants on children of many different parents.
- **FR-1.4** A single user account may simultaneously be (a) a parent of their own children and (b) a tutor on children of other parents.
- **FR-1.5** The profile picker visually segments "My children" (own `learner_profiles`) and "Tutored children" (active tutor grants where this user is the tutor).

### FR-2 · Invite lifecycle

- **FR-2.1** The parent issues an invite by entering the tutor's email address. The system creates a pending grant document keyed by the email and a single-use invite token.
- **FR-2.2** On invite creation, the system sends a transactional invite email to the tutor's address. The parent is also given a copyable share-link as fallback delivery.
- **FR-2.3** A pending invite expires 7 days after creation (default — confirm at implementation).
- **FR-2.4** The tutor must have (or create) a Learning Tracker account to accept an invite. The invite flow MUST allow account creation as part of acceptance (frictionless sign-up).
- **FR-2.5** Accepted grants are open-ended — active until the parent revokes or the tutor resigns.
- **FR-2.6** The tutor may **decline** a pending invite (transitions to declined; parent sees this).
- **FR-2.7** The tutor may **resign** an accepted grant at any time (transitions to revoked-by-tutor; parent sees this).
- **FR-2.8** The parent may rescind a pending invite (transitions to rescinded) or revoke an accepted grant (transitions to revoked-by-parent).
- **FR-2.9** Revocation / resignation takes effect immediately — the next read by the tutor against the child's data fails the Firestore rules check.

### FR-3 · Permission boundary

The tutor has **parent-equivalent permissions on the tutored child** with one and only one prohibition:

> 🛑 **The tutor cannot create a new live forward completion that would credit the child's streak or rewards.**

Specifically allowed for tutors (parent-equivalent):
- ✅ View all child data: completions history, bookmarks, goals, streak, rewards, settings, content
- ✅ Configure curricula, stages, study-day patterns, rewards, point configs
- ✅ Set, modify, or remove goals
- ✅ Bulk-mark-prior (setup-time historical completions — does NOT credit streak per existing rule)
- ✅ Reset progress (un-mark a completion — correction path)
- ✅ Advance bookmarks (set the child's current position in a text)
- ✅ Edit child profile: display name, avatar, mode (child/adult)
- ✅ View text content the child has access to

Specifically forbidden for tutors:
- ❌ Tap "Mark complete" on a live forward completion (the one path that credits streak / reward milestones)
- ❌ Invite other tutors (only creator-parent does this)
- ❌ Revoke other tutors (only creator-parent does this)
- ❌ See co-tutors (siloed visibility — see FR-4)

### FR-4 · Visibility & audit

- **FR-4.1** The **child** sees a list of active tutors granted to their profile (tutor display names only).
- **FR-4.2** The **parent** sees, per child, a list of active tutors AND a per-action audit log of all tutor activity (FR-4.4).
- **FR-4.3** **Tutors do not see other tutors** on the same child (siloed visibility).
- **FR-4.4** Audit log granularity: **per-action with timestamp + tutor identity + field-level before/after**. Every config change, goal edit, bulk-prior, reset, bookmark advance, profile edit by a tutor produces an audit entry.
- **FR-4.5** Audit log retention: preserved **12 months after grant revocation/resignation**, then auto-purged. Active-grant logs are retained indefinitely.

### FR-5 · Tutor PIN

- **FR-5.1** The Tutor PIN is a **separate concept** from the Parent PIN (the existing device-local parent-mode gate). The Parent PIN is unchanged and irrelevant to tutors.
- **FR-5.2** Each tutor account has a **single Tutor PIN** that covers access to all their tutored children (one PIN per tutor, not per child).
- **FR-5.3** The Tutor PIN is set during **tutor onboarding** — mandatory before the tutor can open their first tutored child's data.
- **FR-5.4** The Tutor PIN is required whenever the tutor switches into a tutored child profile (data-protection / privacy gate).
- **FR-5.5** Recovery: Tutor PIN can be reset via email verification (mechanism to be detailed at design time).

### FR-6 · Tutor mode UI

- **FR-6.1** While a tutor is viewing a tutored child, the UI displays a **subtle indicator** (icon and / or colour accent in the AppBar) showing tutor mode is active. Not a persistent banner.
- **FR-6.2** All affordances for forbidden actions (live "Mark complete" tap) are visually disabled or hidden when in tutor mode.
- **FR-6.3** The profile picker offers a clear exit-to-my-profiles affordance.

### FR-7 · Account deletion cascades

- **FR-7.1** When a **parent deletes their account**: all child profiles under that account are deleted (existing cascade). All tutor grants tied to those children are revoked. Tutors see the children disappear from their picker.
- **FR-7.2** When a **tutor deletes their account**: all their active grants auto-resign. Parent's audit log records "tutor account deleted" and retains the tutor's display name as a string for historical reference. The 12-month audit-log retention clock starts.

### FR-8 · Cross-cutting: skip-track-setup at onboarding

Surfaced during elicitation but not strictly part of tutor mode — it's a refactor requirement that tutor mode depends on.

- **FR-8.1** New-user onboarding MUST offer a "Skip track setup" path. A tutor signing up (or any user uninterested in tracking their own learning) lands on a clean state with a clear CTA to either set up a track later or accept a pending invite.
- **FR-8.2** The current flow ("sign up → create child → create track → bulk-mark-prior") becomes one branch; the new branch ("sign up → skip → accept tutor invite or set up later") is equally first-class.

---

## Permission matrix

| Action | Parent (own child) | Child (self) | Tutor (granted) |
|---|:---:|:---:|:---:|
| Mark live forward completion (credits streak/rewards) | ✅ | ✅ | ❌ |
| Bulk-mark-prior (setup history; no streak credit) | ✅ | — | ✅ |
| Reset progress (un-mark) | ✅ | — | ✅ |
| Advance bookmark | ✅ | ✅ | ✅ |
| View text content | ✅ | ✅ | ✅ |
| View streak / rewards / progress | ✅ | ✅ | ✅ |
| Configure curricula / stages / study days | ✅ | — | ✅ |
| Configure goals | ✅ | — | ✅ |
| Configure rewards / point configs | ✅ | — | ✅ |
| Edit profile (name, avatar, mode) | ✅ | — | ✅ |
| Invite tutor | ✅ | — | ❌ |
| Revoke tutor | ✅ | — | ❌ |
| See list of tutors granted to this child | ✅ | ✅ (names only) | ❌ (no co-tutor visibility) |
| See audit log of tutor actions | ✅ | — | — |
| Set / change Parent PIN | ✅ | — | ❌ (device-local) |
| Set / change Tutor PIN | — | — | ✅ (own PIN only) |

---

## Data model implications

### New Firestore collection: `tutor_grants`

Top-level collection (cross-parent / cross-tutor lookups required from both sides). Recommended deterministic doc-id: `{tutor_uid_or_email_hash}_{parent_uid}_{child_profile_id}` so existence checks are O(1) inside security rules.

```
tutor_grants/{grantId}
{
  grant_id:          string,        // matches doc id
  parent_uid:        string,
  child_profile_id:  string,        // path-scoped under parent
  tutor_email:       string,        // canonical lower-cased
  tutor_uid:         string?,       // null until acceptance
  state:             'pending' | 'active' | 'declined' | 'rescinded'
                   | 'revoked_by_parent' | 'revoked_by_tutor' | 'expired',
  invite_token:      string?,       // present only in 'pending' state
  invited_at:        timestamp,
  accepted_at:       timestamp?,
  declined_at:       timestamp?,
  revoked_at:        timestamp?,
  expires_at:        timestamp?,    // for pending invites; 7d default
  updated_at:        timestamp,
}
```

**Indexes needed:**
- `(tutor_uid, state)` — for the tutor's "tutored children" picker list
- `(parent_uid, child_profile_id, state)` — for the parent's per-child active-tutors list
- `(tutor_email, state)` — for "do I have a pending invite for this email" checks during sign-up

### New Firestore collection: `tutor_audit_log`

Sub-collection under each grant (cleanest scoping for retention + cascade):

```
tutor_grants/{grantId}/audit_log/{entryId}
{
  entry_id:    string,
  tutor_uid:   string,
  tutor_name_snapshot: string,    // captured at write-time so it survives tutor account deletion
  action:      'config_changed' | 'completion_bulk_prior' | 'completion_reset'
             | 'bookmark_advanced' | 'profile_edited' | ...,
  target:      string,             // e.g. "goal/{goalId}.targetDate" or "stage/{stageId}.delayDays"
  before_value: any,
  after_value:  any,
  timestamp:    timestamp,
}
```

Retention: deleted by scheduled Cloud Function 12 months after the grant's `revoked_at` / `declined_at`.

### Session model (Drift / Riverpod)

```dart
sealed class ProfileSelection {
  factory ProfileSelection.own({required ProfileId profileId}) = _Own;
  factory ProfileSelection.tutored({
    required ProfileId profileId,
    required UserId ownerUid,
    required TutorGrantId grantId,
  }) = _Tutored;
}

class SessionRole {
  factory SessionRole.parentOfOwn() = _ParentOfOwn;
  factory SessionRole.childSelf() = _ChildSelf;
  factory SessionRole.tutor() = _Tutor;
}

class TutorPermissions {
  static const tutor = TutorPermissions._({
    canMarkLiveCompletion: false,
    canBulkMarkPrior:      true,
    canResetProgress:      true,
    canAdvanceBookmark:    true,
    canConfigureLearning:  true,
    canEditProfile:        true,
    canInviteTutors:       false,
    canRevokeTutors:       false,
  });
}
```

### Firestore rules outline

Read access to a child's subcollection: owner OR active tutor.

```
match /users/{ownerUid}/learner_profiles/{profileId}/{document=**} {
  allow read: if request.auth.uid == ownerUid
            || isActiveTutor(ownerUid, profileId, request.auth.uid);
  allow write: if request.auth.uid == ownerUid
            || (isActiveTutor(ownerUid, profileId, request.auth.uid)
                && !isLiveForwardCompletion(document, resource));
}

function isActiveTutor(ownerUid, profileId, tutorUid) {
  return exists(/databases/$(database)/documents/tutor_grants/$(grantDocId(tutorUid, ownerUid, profileId)))
      && get(/databases/$(database)/documents/tutor_grants/$(grantDocId(tutorUid, ownerUid, profileId))).data.state == 'active';
}
```

The "live forward completion" predicate is the single critical rule. Implementation candidates:
- Block all writes to the `completions/` subcollection from non-owner uids (bulk-prior writes via Cloud Function as owner).
- OR distinguish by a payload field (`isPriorMark: true` vs the live forward marker) and allow only the former for tutors.

The first option is cleaner — completion writes route through a Cloud Function when the actor is a tutor, which can validate the bulk-prior nature server-side.

### Local Drift schema additions

Optional in v1 — tutored children can stay live-Firestore-read-only (no local mirror). If we want offline tutoring, add:
- `learner_profiles.source ∈ {'local','tutored'}`
- `learner_profiles.remote_owner_uid: string?`
- `learner_profiles.tutor_grant_id: string?`

Recommend deferring local mirror for tutored profiles to a later iteration.

---

## Non-functional requirements

- **NFR-1 · Latency** — invite acceptance to first-data-load < 3 s on a good network.
- **NFR-2 · Email deliverability** — transactional email via Firebase Extension or SendGrid; > 99 % delivery rate to common providers.
- **NFR-3 · Security**
  - Invite tokens are 256-bit random, single-use, server-validated, expire in 7 days.
  - Tutor PIN stored hashed locally (existing PIN-hashing utility).
  - Firestore rules deny by default; the tutor-grant check is the only path that opens cross-uid access.
- **NFR-4 · Auditability** — every tutor-originated mutation produces an audit-log entry within the same transaction (best-effort, not strictly synchronous).
- **NFR-5 · Privacy** — child's tutor list and parent's audit log are not visible to other tutors; cross-tutor enumeration is not possible from any client.

---

## Open items / future considerations

| # | Item | Disposition |
|---|---|---|
| O-1 | Pending invite expiry exact value (7 days proposed) | Confirm at design time |
| O-2 | Tutor PIN recovery flow (email reset proposed) | Detail at design time |
| O-3 | Whether bulk-prior writes from tutor should route through a Cloud Function or via permissive rules | Architectural decision at implementation |
| O-4 | Offline support for tutored profiles (live-firestore-only in v1) | Deferred to future iteration |
| O-5 | Multi-language invite email templates | Add after EN baseline lands |
| O-6 | "Last accessed at" indicator for tutors in the parent's manage-tutors view | Nice-to-have |
| O-7 | Co-tutor coordination affordances (notes, handoffs) | Out of scope for v1 |

---

## Edge cases & risks

- **Email-keyed invites before tutor signs up.** A pending invite is keyed by email; the tutor's uid is filled in on acceptance. Risk: same email associated with multiple Firebase Auth accounts (different sign-in methods). Mitigation: on acceptance, the tutor's auth-verified email is checked against the invite's email; mismatch rejects.
- **Tutor accepts on the wrong device / account.** Invite token is single-use, so misclicks are recoverable only by parent re-issuing.
- **Multiple co-tutors mutating the same goal simultaneously.** Last-write-wins (existing sync semantics) is acceptable; both writes appear in the audit log so the parent can see the sequence.
- **Tutor accepts after their grant has been rescinded.** Token expiry + state-check on accept must atomically reject.
- **Parent deletes account while a tutor session is mid-load on the tutored child.** Tutor's next read fails the rule check; UI must handle "tutored child no longer accessible" gracefully (show empty state + return to picker).
- **Cross-cutting onboarding-skip path (FR-8)** has nothing to do with tutor mode strictly — but tutor mode *cannot ship* without it. Lock both in the same refactor wave.

---

## Hand-off

This brief is the BA deliverable. Next step is to fold it into the **tech-debt remediation plan v3**:
- Data-model wave absorbs `tutor_grants` + `tutor_audit_log` + the audit-purge Cloud Function.
- Domain-modelling wave introduces the `TutorGrant` aggregate, `TutorPermissions` value object, `ProfileSelection` sealed union, and the `SessionRole` discriminator.
- A dedicated **Tutor Mode wave** implements invite UI, accept UI, manage-tutors screen, manage-grants screen, profile-picker integration, tutor PIN onboarding, and the audit-log viewer.
- Onboarding refactor absorbs FR-8 (skip-track-setup path).
- Firestore rules update lands with the data-model wave; Cloud Function for bulk-prior writes lands with the tutor-mode wave.
