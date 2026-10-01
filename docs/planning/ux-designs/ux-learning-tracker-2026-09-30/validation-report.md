# Validation Report — Learning Tracker — Sub-tracks

- **DESIGN.md:** `docs/planning/ux-designs/ux-learning-tracker-2026-09-30/DESIGN.md`
- **EXPERIENCE.md:** `docs/planning/ux-designs/ux-learning-tracker-2026-09-30/EXPERIENCE.md`
- **Run at:** 2026-10-01T00:24:18Z

## Overall verdict
The pair is highly traceable for its six journeys, defined tokens, and complete set of linked mockups. It is not yet a reliable downstream contract: a lock-scope decision remains open, PRD behavior conflicts persist, and several named behaviors lack matching visual specifications. Resolve those high-impact conflicts before implementation.

## Category verdicts
- Flow coverage — thin
- Token completeness — thin
- Component coverage — broken
- State coverage — thin
- Visual reference coverage — strong
- Bloat & overspecification — thin
- Inheritance discipline — broken
- Shape fit — thin

## Findings by severity

### Critical (0)
None.

### High (2)
**State coverage** — The Shabbos lock contract leaves overlay scope unresolved (§ EXPERIENCE.md:205-213, 308-310; reconcile-code.md:52-55)
The experience requires a readable planned view during lock, but also says the existing SacredTimeLockOverlay makes the app unreadable and leaves open whether the replacement applies app-wide or only to learners with sub-tracks. Current shell behavior therefore conflicts with the proposed contract and its scope is not committed.
Fix: Commit the lock behavior and scope for all affected roles before consumers implement it.

**Inheritance discipline** — Experience rules conflict with the PRD on child capacity and reminder timing (§ EXPERIENCE.md:142, 212; reconcile-prd.md:68-73)
The PRD says child-accessible detail shows capacity vs remaining path, while the spine hides the capacity bar. The PRD reminder fires when catch-up becomes available; the spine says it fires before expiry. Downstream implementation has two incompatible behaviors for FR-9 and FR-25.
Fix: Reconcile both statements with the source requirements and keep one committed behavior in the spine.


### Medium (4)
**Token completeness** — Two declared non-text color pairs miss the stated contrast floor (§ DESIGN.md:309-316, 322)
The spec sets non-text UI contrast at ≥3:1, while the warning icon is listed at 2.99:1 and tutor-mode accent at 2.9:1 on its fill. Both are load-bearing icons/edges.
Fix: Use compliant non-text pairs and verify them against their immediate fills.

**Component coverage** — Several named behaviors lack a visual component specification (§ EXPERIENCE.md:130-158; DESIGN.md:375-403)
No matching DESIGN component row is provided for Add next year, Delete sub-track, free-tick/corpus-browser capture, onboarding mention, planned list, tutor revocation, or per-source pace; the one-masechta scheduling rule also lacks a visual landing. Consumers must infer appearance and states for source-backed behavior.
Fix: Add visual rows for the named omissions or explicitly bind each to an existing component spec.

**State coverage** — Surface-specific empty and sync-failure states are incomplete (§ EXPERIENCE.md:54-61, 178-185)
The IA does not identify empty states for My talmidim, Mishna history, or lifetime reporting; the global Loading/Error row covers async errors generally, but an offline capture rejected at sync during a lock has no user-facing treatment. A consumer cannot determine what those surfaces show when data is absent or a write is rejected.
Fix: Specify applicable empty, load/error, and rejected-sync treatments for each IA surface.

**Bloat & overspecification** — Inherited design-system values are duplicated wholesale (§ DESIGN.md:2-3, 18-143)
The feature claims to inherit Material 3 and AppTheme/AppPalette while listing 70 colors, 18 typography roles, 13 radii, and 13 spacing tokens, most inherited unchanged. Duplicate base values can drift from the app and obscure which tokens are actual feature deltas.
Fix: Reference inherited system tokens by name and keep only feature-specific additions or overrides.


### Low (3)
**Flow coverage** — UJ-6 has no report-export failure path (§ EXPERIENCE.md:296-302)
The flow ends with the parent exporting a PDF but gives no outcome if generation or saving fails. That leaves the user-facing result undefined for a named journey action.
Fix: Add a failure outcome for the export step.

**Inheritance discipline** — “Reviews” is used for all events although the inherited glossary is narrower (§ EXPERIENCE.md:117; reconcile-prd.md:62-66)
The lifetime report labels 1,876 total events as “Reviews”; the PRD glossary uses learning event for the record and chazara for a repeat. The label can make total learning history read as repeat-only activity.
Fix: Use the source glossary term for the total-event metric.

**Shape fit** — Conditional Inspiration section is missing (§ EXPERIENCE.md:17-23; .memlog.md:16)
The source trail names a stale green visual direction and explicitly rejects it as a source, but the spine has no Inspiration section recording accepted and rejected references. A later consumer can recover that rejected source without seeing the decision.
Fix: Record the inherited app reference and rejected visual direction in an Inspiration section.

## Reviewer files
- `review-rubric.md`
