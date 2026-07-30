---
name: Adversary Review — Drift→Firestore-Native Architecture Spine
type: architecture-review
lens: 2 (adversary / divergence-pair attack)
target: ../ARCHITECTURE-SPINE.md
status: draft
created: '2026-07-30'
sources:
  - ../ARCHITECTURE-SPINE.md
  - ../migration-plan.md
  - ../../../drift-to-firestore-migration-baseline.md
  - ../../../../reports/sync-reliability-efficiency-review-2026-07-29.md
---

# Adversary Review — Divergence-Pair Attack on the Architecture Spine

## Verdict

**REJECT (spine has load-bearing holes).** The paradigm is right and the ADOPTED decisions are sound, but the spine is **not yet a closed set of invariants**: I constructed six concrete pairs of implementation units — each of which obeys every AD *to the letter* — that nonetheless build **incompatibly** and, in three cases, **strand or corrupt real user data**. Two of the holes are outright internal contradictions (AD-5 vs AD-13; AD-8 vs AD-12) where *no* unit can satisfy both ADs, so any two teams necessarily diverge. Each pair below names the two units, proves both are AD-compliant, shows the clash, and specifies the new or tightened AD that closes it.

## Method

The spine claims to be "a lean spine of invariants that keeps everything built from it consistent." The falsification test: find two units one level down (a codec, a doc-id formula, a registry, a delete helper, a reducer, a reconciliation path) that each pass a literal AD audit yet cannot interoperate. Every such pair is a decision the spine *believes* it made but did not actually pin. Six were found; there are almost certainly more in the same classes.

---

## Divergence Pair 1 — The per-account FirebaseApp is resolvable two ways (`AccountFirebase` registry)

**The two units.** Two `data/firestore/account_firebase.dart` registries, both single-owner (AD-2), both persistence-pinned (AD-18), both one-app-per-account (AD-1), both backing local-born accounts with Anonymous Auth (AD-19).

- **Unit A** names each app `account_<deviceRegistryUuid>` — the stable, pre-auth `DeviceAccounts.dbFileName` stem (baseline §8, `user_acc_<uuid>.db`), known before any sign-in. It persists the resolved uid (cloud UID, or the anon UID after `signInAnonymously`) into the active-account record and addresses `users/{uid}/…` from that stored field.
- **Unit B** reads AD-1's literal token `account_<accountId>` together with AD-2's emphasis ("paths from the active-account record's uid, never `currentUser`") as *the identifier is the Firebase uid*, and names each app `account_<uid>`, deriving the path from the same uid.

**Both obey every AD.** AD-1 says "each device account gets its own `initializeApp(name:'account_<accountId>')`" but never defines `<accountId>` — the codebase has three candidate ids for one account (Drift autoincrement, device-registry UUID, Firebase UID; baseline §8, §2.1). AD-2 fixes *path* addressing to the record uid but says nothing about the *app name*. Both units satisfy both.

**They build incompatibly.**
- For a **local-born** account the anon uid does **not exist until after `initializeApp` + `signInAnonymously`** — so Unit B cannot name the app at "first activation" (AD-1) before the very sign-in that requires the app. Bootstrap paradox; Unit A has none.
- Anonymous users **do not survive reinstall**, and the project's App Check debug-token wipe regenerates tokens (user MEMORY: "wipes regenerate the App Check debug token → 403"). On any such reset the anon uid changes: Unit B's *app name and cache directory change*, orphaning the prior cache and the `users/<oldUid>/…` tree; Unit A keeps a stable app+cache but its *stored path uid* strands unless explicitly remapped. Two rebuilds of the same account resolve to different app + cache + document tree.

**Hole.** `<accountId>` (AD-1, app identity) and "active-account record's uid" (AD-2, path identity) are never pinned to *one stable identifier*, and the late-binding/instability of the Anonymous-Auth uid (AD-19) is unaddressed.

**Fix — new/tightened AD.** Pin the named-app key to the **stable device-registry account UUID** (never the Firebase uid, never `currentUser`); pin the Firestore-path uid to a **persisted uid field with an explicit remap-on-anon-reset** step; forbid deriving either identifier from the live auth uid at call time. AD-19 must state the anon-uid reset/relink recovery path.

---

## Divergence Pair 2 — "The stable track key" is a free variable (`doc_ids.dart`, track-scoped children)

**The two units.** Two Phase-0 doc-id modules, both killing per-device autoincrement ids (AD-5), both claiming byte-for-byte formula reproduction (AD-13).

- **Unit A** reads "stable track key" (AD-5) as the existing `curriculum_tracks` doc-id, which today is `curriculum_id` (baseline §3.1: `curriculum_tracks/{curriculum_id}`). It emits `stage_definitions/{curriculum_id}_{stageOrder}` and `study_day_configs/{curriculumId}_{dayOfWeek}_{curriculum_id}`.
- **Unit B** reads "stable track key" as a track-identity **ULID** (AD-5 explicitly allows "a natural key **or** a ULID"; AD-20 promotes tracks to full owner-sync, making a minted track ULID natural). It emits `stage_definitions/{trackUlid}_{stageOrder}`.

**Both obey every AD.** AD-5 mandates "a stable track key, not the per-device `track_id`" without naming which stable identifier is *the* track key. AD-13 says "reproduce every doc-id formula byte-for-byte" — both units reproduce the *shape* `{trackKey}_{stageOrder}`. Both pass a literal audit.

**They build incompatibly.** The doc-ids diverge: a `stage_definition` written by Unit A's device is unmatchable by Unit B's device → the cross-device FK-analogue breakage that `resolveLocalTrackId` existed to prevent (baseline §4.0, F5) **returns by construction**. Worse, *both* diverge from historical cloud docs, which were written as `{oldPerDeviceTrackId}_{stageOrder}` — so AD-13's byte-for-byte promise is **literally unachievable** here (the old formula embeds the very per-device id AD-5 abolishes). AD-5 and AD-13 are in direct contradiction for `stage_definitions`/`study_day_configs`; the shared "track key" underdetermination guarantees two teams diverge.

**Hole.** AD-5 requires "a stable track key" but never designates the canonical one; AD-13 "byte-for-byte" cannot coexist with AD-5's remap-retirement for track-embedded formulas.

**Fix — new/tightened AD.** Name the **single canonical stable track key** (recommend `curriculum_id`, consistent with the live `curriculum_tracks/{curriculum_id}` doc-id) and re-express *every* track-scoped child formula against it explicitly in `doc_ids.dart`. Replace AD-13's "byte-for-byte" for these collections with an explicit **one-time doc-id re-key + backfill** of the historical `{perDeviceTrackId}_*` docs — reproduction is impossible; migration is mandatory.

---

## Divergence Pair 3 — Profile-deletion set: "the 6 no-cascade collections" vs the 16 subcollections, and the SR-1 wall (`write.dart` delete helper)

**The two units.** Two AD-8 ordered-delete helpers for profile deletion / tutor-mirror-wipe.

- **Unit A** ports the Drift dependency order literally and deletes "the 6 no-cascade collections" = `{CurriculumTracks, DailyPlans, Outbox, PointConfigs, ProfilePrograms, StudyDayConfigs}` (baseline §7) in FK-drop order.
- **Unit B** enumerates all **16** per-profile subcollections from `firestore.rules` (baseline §6) and deletes each.

**Both obey every AD.** AD-8 says "explicitly delete the 6 no-cascade collections in dependency order." Unit A matches the noun and the count exactly. Unit B satisfies the intent ("no orphans") and the parity register (AD-17). Both pass.

**They build incompatibly / strand data.**
- Three of Unit A's six no longer exist as synced Firestore collections — Outbox is deleted (AD-8 itself), DailyPlans is local-only (AD-16), PointConfigs is remodeled into a subcollection (AD-13/MCF-19). Unit A therefore deletes ~3 real collections and **orphans the other 13** — re-introducing MCF-24-orphan at far larger scope than today's 2-collection gap.
- "Dependency order" is a **no-op in Firestore** (no FK enforcement) — it gives false confidence while doing nothing, and Unit A vs Unit B order the deletes differently with no observable constraint to reconcile them.
- Unit B hits the wall: `completions`, `learning_ledger`, `streak_events`, `points_ledger` carry SR-1 **`deny delete`** (AD-12). The client repository path is **rejected by the security rules the spine mandates preserving** — Unit B physically cannot complete a GDPR hard delete from the seam AD-8 designates.

**Hole.** AD-8 pins the wrong enumeration basis (a Drift-era count of "6") and an inapplicable ordering constraint, and collides head-on with AD-12/SR-1 for append-only history — the client path can neither enumerate the right set nor legally delete it.

**Fix — new/tightened AD.** Derive the delete set from the **Firestore collection registry (AD-17 parity)**, not the Drift no-cascade list; drop "dependency order" (state Firestore has no cascade *and* no ordering constraint); and route append-only-history deletion through the **Admin-SDK/CF `recursiveDelete` path** (the existing server route, baseline §6) because SR-1 denies client delete. AD-8 must acknowledge that a compliant profile hard-delete is *not* a pure client/repository operation.

---

## Divergence Pair 4 — PointsBalance: date-bounded vs denormalized-cache (AD-4's dangling OR)

**The two units.** Two `domain/**` points reducers.

- **Unit A** chooses "date-bounded" replay (AD-4 verbatim: "replay must be date-bounded **or** backed by a local denormalized cache").
- **Unit B** chooses the "local denormalized cache" seeded from full ledger history.

**Both obey every AD.** AD-4 offers the two as interchangeable. Both re-derive, never store a synced counter, both idempotency-gate on ULID-doc non-existence. Both pass.

**They build incompatibly.** A points balance is a **cumulative all-time sum** clamped `[0,2^30)` (baseline MCF-2). Date-bounding it (Unit A) silently drops every pre-window credit → a wrong, smaller balance — the exact lost-points class. On a fresh device cache for the *same* account, Unit A rebuilds a different number than Unit B's full-history cache → the same account shows two balances across two devices. AD-4 lumps points (not windowable) with **streak** (genuinely windowable) under one allowance.

**Hole.** AD-4's "date-bounded or cached" is safe for streak and unsafe for points; the spine grants the unsafe option to a cumulative aggregate.

**Fix — new/tightened AD.** Forbid date-bounding for **cumulative aggregates** (points balance must sum the *full* ledger, via a denormalized local cache rebuilt in full on a cold cache); restrict the date-bound option to state provably reconstructable from a bounded window (streak). Split the points and streak rules — they are not the same shape.

---

## Divergence Pair 5 — RewardRedemption predicate: AD-7's exception dangles on an unratified `[ASSUMPTION]`

**The two units.** Two `reward_redemption` reconciliation paths.

- **Unit A** keeps the bespoke plain-`isAfter` LWW (baseline §3.1 #13, F3), invoking AD-7's escape clause: "standardized … **unless AD-21 preserves one deliberately**." AD-21 is `[ASSUMPTION]` (unconfirmed), so it has not *affirmatively* standardized anything yet.
- **Unit B** standardizes onto the canonical ±5s / `synced_at` / D15 predicate (AD-21's stated rule; AD-7 default).

**Both obey every AD.** AD-7's conditional and AD-21's unratified status genuinely admit both readings. Both pass a literal audit.

**They build incompatibly.** Plain-`isAfter` (ties-to-local, no clock-skew window) and the canonical predicate (±5s window, `synced_at` authority, prefer-newer-unpushed-local) resolve a concurrent decline/fulfil **differently** — on two devices of one account this yields divergent redemption state, i.e. a possible double-spend or a lost decline (baseline MCF-13). A build-time option gated on an unratified AD is not an invariant.

**Hole.** An `[ASSUMPTION]`-gated exception inside AD-7 leaves predicate ownership for one collection genuinely ambiguous until Daniel confirms.

**Fix — new/tightened AD.** Resolve AD-21 (strip `[ASSUMPTION]`) *or* make AD-7 unconditional (no per-merger exception). An exception clause that points at an unratified AD must not survive into the build contract — exactly one predicate governs every LWW collection.

---

## Divergence Pair 6 — gamification_settings fan-out: no single owner, no cross-store atomicity

**The two units.** Two `gamification_settings` apply paths (AD-13 fan-out).

- **Unit A** gives one repository ownership of the whole doc: it writes the `points_config` subcollection *and* the `(accountId,profileId)`-namespaced `reward_settings` SharedPreferences keys (AD-15).
- **Unit B** splits ownership: `GamificationRepository` owns the Firestore subcollection; a separate prefs path owns `reward_settings` (MCF-uiprefs-sor / AD-15 store-of-record).

**Both obey every AD.** AD-13 mandates the one-doc→subcollection remodel but names no owner for the second store; baseline §3.1 #4 and MCF-14 confirm the doc fans into *two* stores. Both units satisfy AD-3 (all access via a repository) and AD-15 (namespaced prefs). Both pass.

**They build incompatibly.** The fan-out spans Firestore **and** SharedPreferences, which **cannot** share a Firestore `WriteBatch`/transaction — AD-8's atomicity covers Firestore-only. A crash between the two writes tears state (points_config current, reward_settings stale, or vice-versa) under Unit A; under Unit B the two owners can apply the same source doc at different times with no coordinating write. Two owners of one entity, no atomicity rule.

**Hole.** AD-13 requires a two-store fan-out but assigns neither a single owner nor a cross-store consistency rule; AD-8's atomicity is structurally Firestore-only.

**Fix — new/tightened AD.** Assign `gamification_settings` a **single repository owner** and declare Firestore **authoritative** with the SharedPreferences copy a **rebuildable projection re-derived on read** (not a co-equal store) — so a torn fan-out self-heals on next read rather than persisting a split-brain.

---

## Additional structural defects (not divergence pairs, but spine bugs)

- **AD-5 says "`learner_profiles` is keyed by Firebase UID."** An account owns **many** profiles (spine ER: `ACCOUNT ||--o{ LEARNER_PROFILE`; path is already `users/{uid}/learner_profiles/{profileId}`). Keying the *profile doc-id* by the uid collides every child of an account onto one document. AD-5 conflates the path-uid with the doc-id; the profile doc-id must be a profile-scoped stable key (ULID), not the uid. **No unit can implement AD-5 as written without data loss.**

- **AD-11's 3-state model cannot represent a dead listener that AD-9 admits exists.** After AD-9's bounded backoff is exhausted, a channel is permanently dark with connectivity *up* — that is neither `synced` (data is stale), `syncing` (nothing is in flight), nor `offline` (network is fine). Two teams will map it oppositely (spinning-forever vs lying-synced); the reliability review flags "error status masking real backlog" (R-4) as a shipped bug class. The 3-state model needs an explicit rule for the exhausted-resubscribe terminal state.

- **Per-collection strangler (AD-3/Plan Phase 3) strands cross-collection identity mid-migration.** AD-5 retires `resolveLocalTrackId` "by construction," but that only holds if *all* track-scoped collections cut over atomically. Phase 3 cuts `curriculum_tracks` (Wave A) before `study_day_configs`/`goals` (Wave B): between waves, tracks live in Firestore under the new stable key while `study_day_configs` still merges via the old per-device `track_id` remap in Drift. Each wave "satisfies its exit criteria" (its own collection round-trips) yet a `study_day_config` written in the gap references a track identity that moved layers — stranded across the seam. The strangler-granularity unit and the doc-id-reform unit disagree about atomicity boundaries.

---

## Holes → proposed ADs (summary)

| # | Hole | Contradicting/underspecified ADs | Proposed new/tightened AD |
|---|------|----------------------------------|---------------------------|
| 1 | App name vs path uid not pinned; anon uid unstable | AD-1, AD-2, AD-19 | Named-app key = stable device-registry UUID; path uid = persisted, remap-on-anon-reset; never live `currentUser` |
| 2 | "Stable track key" undefined; byte-for-byte impossible for track formulas | AD-5, AD-13 | Name the canonical track key (`curriculum_id`); one-time doc-id re-key + backfill for history |
| 3 | Delete set = Drift "6"; SR-1 denies client delete | AD-8, AD-12, AD-16, AD-17 | Delete set from Firestore registry; drop "dependency order"; hard delete via Admin-SDK/CF recursiveDelete |
| 4 | Date-bound allowed for a cumulative sum | AD-4 | Forbid date-bounding cumulative aggregates; split points (full-cache) from streak (windowable) |
| 5 | Predicate exception gated on unratified `[ASSUMPTION]` | AD-7, AD-21 | Ratify AD-21 or make AD-7 unconditional; one predicate governs all |
| 6 | Two-store fan-out: no owner, no atomicity | AD-13, AD-8, AD-15 | Single owner; Firestore authoritative; prefs a rebuildable projection |
| + | Profile doc-id = uid collides children | AD-5 | Profile doc-id is a profile-scoped ULID, distinct from the path uid |
| + | 3-state status can't express exhausted-dead channel | AD-9, AD-11 | Explicit rule for the terminal resubscribe-exhausted state |
| + | Per-collection strangler strands track identity between waves | AD-3, AD-5, Plan P3 | Cut all track-scoped collections in one wave, or bridge the key across the seam |

*End of adversary review (draft).*
