# Sub-track analytics metric catalog

This catalog follows Epic 2 AC-4 and PRD deviation #15. Event payloads
contain enum and count fields only. The analytics backend's event timestamp
provides the aggregation day; no learner date, reference, name, or profile id
is added to event parameters.

| Metric | Aggregation | Guardrail |
| --- | --- | --- |
| SM-1 | Over 4 weeks: learner-days with at least one `capture` divided by non-locked learner-days. | The non-locked-day denominator source must be confirmed before release. Do not add date or lock-window fields to capture events to derive it. |
| SM-2 | In the last 14 days: hashed learners with at least one `subtrack_lifecycle` create and a sub-track `capture`. | Use the per-install salted profile hash user property. |
| SM-4 | Median over `(learner-day, source)` pairs with at least one capture of the sum of `taps` for that source's captures that day. | Target is at most 4 taps per source captured, not per full day. |
| SM-5 | Per track: absolute value of forecast capacity minus actual distinct leaves ticked within the track window. | Emit only on explicit end, delete, or Add next year. |

Events per day is a counter-metric only and is never a target (NFR-17).
