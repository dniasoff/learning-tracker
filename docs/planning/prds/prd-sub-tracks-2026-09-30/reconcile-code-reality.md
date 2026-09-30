# Code-reality reconciliation

## Gaps

- **“Exactly one current position” is described as a requirement but PRD does not explicitly state that the live track model has no stored sequence or position**, nor distinguish the current curriculum track from newly modeled sub-tracks. Source: extract-code-reality.md §1; PRD location: §3 Glossary, §4.2 FR-9, §4.3 FR-11; **suggested disposition: add to addendum** (implementation constraint is present there in broad terms, but link it to the position requirement).
- **Main track as “one masechta at a time” conflicts with code facts**: existing code has one track per curriculum and no one-masechta-per-track restriction. Source: extract-code-reality.md §1; PRD location: §3 Glossary “Main track”, §5 Non-Goals; **suggested disposition: add to PRD** (resolve product rule against current implementation; do not treat it as an existing constraint).
- **PRD describes correction as voiding/removing an event**, while current storage uses purge timestamps and lifetime providers filter purged entries. Source: extract-code-reality.md §2; PRD location: §4.1 FR-4; **suggested disposition: add to addendum** (specify reuse/compatibility with purge semantics).
- **PRD’s “before tracking” date state implies a date-state representation**, while existing backfill is a `bulkInTrack` source/category with UTC 2000-01-01 sentinel and pace/scheduler-specific exclusion. Source: extract-code-reality.md §3; PRD location: §3 Glossary, §4.1 FR-3, §4.8 FR-28–30; **suggested disposition: add to addendum** (define mapping and preserve sentinel behavior).
- **Existing schedule’s reorder amnesty is not called out as a constraint when FR-19 says recomputation discards stale backlog or schedule.** Source: extract-code-reality.md §4; PRD location: §4.5 FR-19; **suggested disposition: add to addendum** (clarify how recompute interacts with `lastReorderAt` amnesty).
- **One deadline-bearing goal is required by the PRD but code permits multiple goals per curriculum.** Source: extract-code-reality.md §6; PRD location: §4.5 FR-19, addendum §1 Goals row; **suggested disposition: add to addendum** (require migration/enforcement or define selection semantics; current constraint is explicitly absent).
- **Tutor action attribution is required in FR-26, but current completion `markedBy` is a learner-profile ID rather than a tutor account ID.** Source: extract-code-reality.md §9; PRD location: §4.7 FR-26, addendum §1 Tutor grants row; **suggested disposition: add to addendum** (identify account attribution as a new persisted capability).
- **Shabbos lock depends on profile-specific location/Israel setting in FR-23, but current location is app-global SharedPreferences**, shared across profiles. Source: extract-code-reality.md §7; PRD location: §4.6 FR-23, addendum §1 sacred_time row; **suggested disposition: add to addendum** (address profile scoping before multi-profile use).
- **The addendum calls current storage Firestore-first and profile-scoped, but the PRD does not explicitly require sub-track persistence to follow those paths.** Source: extract-code-reality.md §8; PRD location: absent; **suggested disposition: add to addendum**.
- **Existing partial checkboxes only cover bulk marking and lifetime marking-scope rows**, while FR-15 requires tri-state across the corpus browser, ground picker, and sub-track detail. Source: extract-code-reality.md §5; PRD location: §4.4 FR-15; **suggested disposition: add to addendum** (extend existing capability, not assume universal support).
- **Existing `trackType` is a plain string (`personal`), not a track-kind enum**, so source and track-type semantics in the new event model need an explicit mapping. Source: extract-code-reality.md §1–2; PRD location: §3 Glossary, §4.1 FR-2–3; **suggested disposition: add to addendum**.

## NOT CAPTURED entries

- Current track model has no one-masechta-per-track restriction, despite the PRD’s single-masechta main-track rule.
- Current purge timestamp semantics are not reconciled with PRD correction semantics.
- Tutor account attribution is not persisted by current completion `markedBy` field.
- Location is global rather than profile-scoped.
- Multiple-goal current behavior conflicts with the one-deadline product constraint.
- No explicit persistence/path requirement for new sub-track records.
