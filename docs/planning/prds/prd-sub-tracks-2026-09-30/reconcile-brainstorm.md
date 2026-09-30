# Brainstorm reconciliation

## Gaps

- **Before-tracking is also listed as an event source**, while the PRD models it as a date state and free-tick batches default to home; source/date distinction remains inconsistent. Source: extract-brainstorm.md §2 decision 5, §3 S2-10, §4; PRD location: §3 Glossary, §4.1 FR-3, §4.8 FR-28–30; **suggested disposition: add to PRD** (resolve whether this is a source, date state, or both).
- **Editable event date at initial capture** is not explicit; FR-4 permits correcting a wrong date after the fact. Source: §2 decision 30, §3 S1-6; PRD location: §4.1 FR-3–4; **suggested disposition: add to PRD**.
- **Distinct before-tracking source default** for a free-tick batch is not defined; PRD says default home and permits before-tracking date state. Source: §3 S2-10, §5 Corpus browser/free-tick; PRD location: §4.1 FR-3; **suggested disposition: add to PRD**.
- **Ground assignment by dragging from the corpus browser** is absent as an interaction; PRD only says add ground. Source: §3 S2-6, §5 Ground assignment; PRD location: §4.3 FR-10; **suggested disposition: add to addendum**.
- **Tri-state visual treatment** says grey for partial, checked for complete; PRD calls partial/complete but does not specify visual states. Source: §2 decision 28, §3 S1-1; PRD location: §4.4 FR-15; **suggested disposition: add to addendum**.
- **Shabbos lock margin** around candle-lighting/tzeis is omitted; FR-23 gives the boundary without the brainstorm’s margin. Source: §3 S3-1; PRD location: §4.6 FR-23; **suggested disposition: add to PRD**.
- **Erev Shabbos planned view and frozen-status copy** are weakened to a generic planned view, with no explicit same view before the lock or status explanation. Source: §5 Erev view, Shabbos locked view; PRD location: §4.6 FR-24; **suggested disposition: add to PRD**.
- **Location/Israel setting described as one-time setup** is absent; PRD says windows follow location and Israel setting. Source: §3 S3-7; PRD location: §4.6 FR-23; **suggested disposition: add to addendum**.
- **Catch-up “Adjust…” behavior** is not defined and remains an open question; per-day allocation across three days is not specified. Source: §3 S3-4, §5 Motzei catch-up card; PRD location: §4.6 FR-25, §8 item 4; **suggested disposition: add to PRD**.
- **Governing principle “as simple as possible”** and the qualitative family identity (“the thing that shows a frum family built it”) are not explicit. Source: §2 decision 34 and brainstorm §1; PRD location: §1 Vision, §4; **suggested disposition: add to PRD**.
- **Phased build order** (minors, then sub-tracks, then Shabbos) is not retained as a product sequencing constraint; the PRD labels stage order a planning decision. Source: §2 decision 35; PRD location: §6.2; **suggested disposition: ignore-with-reason** (the PRD explicitly defers delivery order to epic planning).
- **Self-correcting rate proposal** and whether to include it remain unresolved in the brainstorm; there is no PRD disposition. Source: §7 item 4; PRD location: absent; **suggested disposition: add to addendum** (record as deferred/open design alternative).
- **Whether the on/off-target report measures total required pace or per-source estimate, and its velocity window** is unresolved in brainstorm but PRD gives an on-track assumption and a no-deadline projection without a window. Source: §8 D21; PRD location: §4.4 FR-18, §4.5 FR-20, §4.8 FR-30; **suggested disposition: add to PRD**.
- **Existing planner behavior without a deadline** remains unclear: PRD says main-track tasks stay as before and separately projects a finish date, without saying how task quantity is computed in that mode. Source: §8 D19; PRD location: §4.5 FR-20, §5 Non-Goals; **suggested disposition: add to PRD**.

## NOT CAPTURED entries

- Explicit editable date on initial event entry.
- Precise visual mapping of tri-state values to empty/grey/checked.
- Shabbos boundary safety margin and one-time location setup.
- Frozen status copy and shared erev/locked planned view.
- Detail for catch-up adjustment across multiple locked days.
- Family identity signal and governing simplicity principle.
- Self-correcting rate proposal disposition.
- Definition of on/off-target report metric and velocity window.
- No-deadline daily task sizing.
