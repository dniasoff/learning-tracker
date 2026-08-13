> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/firestore-rewrite-map.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

# Tutor "Talmid View" — Stream Tracker

Maintained by the Talmid-View Orchestrator. Status legend:
`[ ] pending` · `[~] in-progress` · `[x] done (self-reported)` · `[V] verified (diff + device/emulator trace confirmed)`.

Plan: `tutor-talmid-view-plan-2026-05-26.md` · Log: `tutor-talmid-view-log.md` · Squad: `talmid-view-squad`.

Build to D1–D6: read-only local mirror · snapshot-on-entry + manual refresh · cache between sessions · v1 = read-only + Manage Tracks + Bulk-prior · live forward completion always barred · wipe on revoke/resign/sign-out.

---

## Wave 1 — read-side foundation (S1 + S5 rules-verify) → gate P1

### S1 — Mirror pull (foundation) — [V] verified 2026-05-26 17:20 (7480663e; +settings; isolation 5/5 green)
- [V] T1.profile — Synthetic tutored-profile create/upsert + mapping (uses v28 `isTutored`/`tutorParentUid`/`tutorRemoteProfileId`/`tutorGrantId`)
- [V] T1.gateway — Parent-scoped tutored gateway (`FirestoreGatewayImpl(activeAccountUid: () => parentUid)`)
- [V] T1.pull-decouple — Decouple path-profileId from merge-profileId in `PullPipeline`: read `users/{parentUid}/learner_profiles/{remoteId}/<coll>`, key local rows under the synthetic local id
- [V] T1.trigger — One-shot pull-on-entry + manual refresh
- [V] T1.isolation — Mirror rows flagged read-only / **never enqueued to the tutor's own outbox** (+ regression tests proving isolation)

### S5a — Rules verify (Wave 1 half) — [V] verified 2026-05-26 16:33 — all covered, 0 changes, no deploy
- [V] T5.rules-verify — Confirm `hasActiveTutorAccess(ownerUid, profileId)` covers **every** mirrored subcollection (completions, bookmarks, learning_ledger, points_ledger, streak_events, goals, curriculum_tracks, study_day_configs, stage_definitions, reward_*) + profile doc; add missing **read** clauses; keep writes CF-only; **deploy rules**; verify reads on a live device

**Gate P1** — [V] CLOSED 2026-05-26 17:20 — rules half (S5) + mirror-pull (S1) verified; isolation 5/5 + settings covered; real on-device pull deferred to P2 (nav trigger lands in S2). S2/S3 unblocked.

---

## Wave 2 — read-only surfaces (S2 + S3) → gate P2 (Daniel sanity-check)

### S2 — Resolution + nav — [V] verified 2026-05-26 18:00 (df6f224a; pull-before-nav; analyze clean)
- [V] T2.resolution — Make `activeProfileIdProvider` tutored-aware (return synthetic local id when `ActiveTutoredProfileSelection != null`, else own selected) — single chokepoint
- [V] T2.nav — Fix `tutored_children_section.dart`: after PIN + `enter(selection)`, `replaceAll([AppShellRoute()])` (talmid dashboard), not `ManageGrantsRoute`

### S3 — Read-only surfaces + gating — [V] verified 2026-05-26 18:00 (18 tests green; UNCOMMITTED pending Daniel's git call)
- [V] T3.render — Dashboard / Progress / Learn render the mirror (they already read `activeProfileId`)
- [V] T3.gating — Hide/disable any control not permitted; **block live forward completion always** (`tutorCannotMarkLiveCompletion`)
- [V] T3.readonly-state — Surface read-only state; "Tutor mode" indicator + clean exit

**Gate P2 — READ-ONLY CHECKPOINT** — [⏳ code VERIFIED 18:00; awaiting Daniel on-device sign-off] Tutor taps talmid → Tutor-PIN → talmid dashboard/progress/learn render the child's real data read-only; no live-mark; banner + exit work. **Build + install to device; Daniel sanity-checks before edits land.**

---

## Wave 3 — RE-SCOPED 2026-05-26 (see log [18:30]): FULL parent-equivalent (supersedes D4)
> Daniel rejected the read-only/child-mode build at P2 and chose "all features functional." Wave 3 now = **S3-rework** (tutor → child's parent/adult view, `isTutorElevated`, parent-admin surfaces still hidden) + **S4 expanded** (CFs for tracks/points/rewards/goals/study-days/stages/profile + bulk-prior, permission-gated + audited) + **S5 lifecycle** (mirror wipe on revoke/resign/sign-out). Open flag: rewards/points-config may be local-only (not pulled) — S4 verifying before building those two CFs. Live-mark always barred; learn view-only.

### (original) Wave 3 — bundled edits + lifecycle (S4 + S5 lifecycle) → gate P3

### S4 — Bundled edits (CF write paths)
- [ ] T4.cf-track — Cloud Function (Admin SDK): permitted **track-config** edits write under `users/{parentUid}/…` with grant + permission verification (`hasActiveTutorAccess` + grant `permissions`)
- [ ] T4.cf-bulkprior — Cloud Function: **bulk-prior completion** writes under parent namespace, same verification (no streak credit)
- [ ] T4.client-route — Client routes permitted edits to the CFs when active-as-tutored; un-permitted blocked server-side

### S5b — Lifecycle (Wave 3 half)
- [ ] T5.lifecycle — Wipe the mirror on **revoke / resign / sign-out**

**Gate P3** — [ ] permitted track-edit + bulk-prior write to the parent namespace + reflect on refresh; un-permitted blocked; mirror wipes on the three triggers.

---

## Verification (after P3, sequential)

- [ ] V1 — `make ci` green (loop fix until green)
- [ ] V2 — Adversarial review squad (R1 data-isolation · R2 pull-correctness · R3 permissions/rules · R4 lifecycle/cross-cutting); CRITICAL/HIGH/MEDIUM/LOW + file:line
- [ ] V3 — Fix-all (one fix-agent per CRITICAL/HIGH; batch MEDIUM; log LOW)
- [ ] V4 — Re-run CI (loop)
- [ ] V5 — Task-truth verification: every `done` task confirmed user-reachable (real pull / real nav / real write), not just present in code
- [ ] V6 — Final smoke: tutor charter flow end-to-end on device (EN + HE; offline render after first pull)

---

## Done definition
- [ ] Every stream task `[V]` verified (reachable on device)
- [ ] Tutor charter flow passes (V6); P2 read-only checkpoint signed off by Daniel
- [ ] Live forward completion barred; permitted edits land in parent namespace; un-permitted blocked
- [ ] Mirror never pollutes the tutor's own cloud data; wiped on revoke/resign/sign-out
- [ ] Rules deployed; every mirrored subcollection readable on a live device
- [ ] `make ci` green; V2 final round zero CRITICAL / zero unaddressed HIGH
