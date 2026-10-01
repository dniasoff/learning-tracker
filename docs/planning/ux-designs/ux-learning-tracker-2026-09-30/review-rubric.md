# Spine Pair Review — Learning Tracker — Sub-tracks

## Overall verdict
The pair is highly traceable for its six journeys, defined tokens, and complete set of linked mockups. It is not yet a reliable downstream contract: a lock-scope decision remains open, PRD behavior conflicts persist, and several named behaviors lack matching visual specifications. Resolve those high-impact conflicts before implementation.

## 1. Flow coverage — thin
UJ-1 through UJ-6 are present with named protagonists, numbered steps, and climax beats; the reconciliation confirms that all six titles match the PRD. UJ-1 through UJ-4 include failure paths, while UJ-6 ends with an edge case rather than an export failure path, though its journey includes Export PDF. (EXPERIENCE.md:245-302; reconcile-prd.md:51-60)
### Findings
- **Low** UJ-6 has no report-export failure path (EXPERIENCE.md:296-302). The flow ends with the parent exporting a PDF but gives no outcome if generation or saving fails. That leaves the user-facing result undefined for a named journey action. *Fix:* Add a failure outcome for the export step.

## 2. Token completeness — thin
The DESIGN frontmatter defines 70 color values, each with a dark counterpart; all 62 DESIGN and 4 EXPERIENCE token references resolve. The stated non-text minimum is 3:1, but two icon/edge combinations are recorded below that threshold. (DESIGN.md:18-92, 144-284, 309-322; EXPERIENCE.md:219-220)
### Findings
- **Medium** Two declared non-text color pairs miss the stated contrast floor (DESIGN.md:309-316, 322). The spec sets non-text UI contrast at ≥3:1, while the warning icon is listed at 2.99:1 and tutor-mode accent at 2.9:1 on its fill. Both are load-bearing icons/edges. *Fix:* Use compliant non-text pairs and verify them against their immediate fills.

## 3. Component coverage — broken
The two component tables cover the main capture, setup, and status components, but multiple behavioral components and surfaces do not have a matching visual row in DESIGN.md. The reconciliation identifies the omissions against the source requirements. (EXPERIENCE.md:130-158; DESIGN.md:375-403; reconcile-prd.md:12-45)
### Findings
- **Medium** Several named behaviors lack a visual component specification (EXPERIENCE.md:130-158; DESIGN.md:375-403). No matching DESIGN component row is provided for Add next year, Delete sub-track, free-tick/corpus-browser capture, onboarding mention, planned list, tutor revocation, or per-source pace; the one-masechta scheduling rule also lacks a visual landing. Consumers must infer appearance and states for source-backed behavior. *Fix:* Add visual rows for the named omissions or explicitly bind each to an existing component spec.

## 4. State coverage — thin
The state table covers many important cases, including no sub-tracks, groundless/future/ended tracks, lock, catch-up, offline, and loading/error. It remains generic for all surfaces, and the user-facing treatment for an offline write rejected during a lock is explicitly open; surface-specific empty and failure states are not systematically accounted for. (EXPERIENCE.md:41-61, 160-188) The planned view also conflicts with the existing full-screen lock overlay, and the open question leaves its scope undecided. (EXPERIENCE.md:205-213, 308-310; reconcile-code.md:52-55)
### Findings
- **Medium** Surface-specific empty and sync-failure states are incomplete (EXPERIENCE.md:54-61, 178-185). The IA does not identify empty states for My talmidim, Mishna history, or lifetime reporting; the global Loading/Error row covers async errors generally, but an offline capture rejected at sync during a lock has no user-facing treatment. A consumer cannot determine what those surfaces show when data is absent or a write is rejected. *Fix:* Specify applicable empty, load/error, and rejected-sync treatments for each IA surface.
- **High** The Shabbos lock contract leaves overlay scope unresolved (EXPERIENCE.md:205-213, 308-310; reconcile-code.md:52-55). The experience requires a readable planned view during lock, but also says the existing SacredTimeLockOverlay makes the app unreadable and leaves open whether the replacement applies app-wide or only to learners with sub-tracks. Current shell behavior therefore conflicts with the proposed contract and its scope is not committed. *Fix:* Commit the lock behavior and scope for all affected roles before consumers implement it.

## 5. Visual reference coverage — pass
All 42 files in mockups/ are linked from relevant DESIGN or EXPERIENCE sections, and the checked local Markdown links resolve. The spines state precedence over mocks. (DESIGN.md:288, 351-363, 379-402; EXPERIENCE.md:15, 41-61, 203-204, 236-237)
### Findings
- None.

## 6. Bloat & overspecification — thin
The feature contract is intentionally detailed and its editorial rationale is useful, but it republishes the inherited app palette, typography, radii, and spacing at substantial length despite saying Sub-tracks specifies only additions. This creates a second copy of base-system values to maintain. (DESIGN.md:2-3, 18-143, 296-302)
### Findings
- **Medium** Inherited design-system values are duplicated wholesale (DESIGN.md:2-3, 18-143). The feature claims to inherit Material 3 and AppTheme/AppPalette while listing 70 colors, 18 typography roles, 13 radii, and 13 spacing tokens, most inherited unchanged. Duplicate base values can drift from the app and obscure which tokens are actual feature deltas. *Fix:* Reference inherited system tokens by name and keep only feature-specific additions or overrides.

## 7. Inheritance discipline — broken
All declared source paths and token references resolve, and the six UJ titles match the PRD. However, the spines still disagree with the PRD on child detail capacity and catch-up reminder timing, and the report uses “Reviews” for all logged events despite the source glossary distinguishing learning events and chazara. These conflicts prevent a single inherited contract. (DESIGN.md:6-14; EXPERIENCE.md:5-10, 117, 142, 212; reconcile-prd.md:62-74)
### Findings
- **High** Experience rules conflict with the PRD on child capacity and reminder timing (EXPERIENCE.md:142, 212; reconcile-prd.md:68-73). The PRD says child-accessible detail shows capacity vs remaining path, while the spine hides the capacity bar. The PRD reminder fires when catch-up becomes available; the spine says it fires before expiry. Downstream implementation has two incompatible behaviors for FR-9 and FR-25. *Fix:* Reconcile both statements with the source requirements and keep one committed behavior in the spine.
- **Low** “Reviews” is used for all events although the inherited glossary is narrower (EXPERIENCE.md:117; reconcile-prd.md:62-66). The lifetime report labels 1,876 total events as “Reviews”; the PRD glossary uses learning event for the record and chazara for a repeat. The label can make total learning history read as repeat-only activity. *Fix:* Use the source glossary term for the total-event metric.

## 8. Shape fit — thin
DESIGN.md follows the canonical section order, and EXPERIENCE.md includes all required default sections plus Responsive & Platform for its phone/tablet scope. The conditional Inspiration section is absent even though the memlog records an explicit rejected visual reference. (DESIGN.md:286-405; EXPERIENCE.md:17-18, 39-63, 85-126, 160-241; .memlog.md:16)
### Findings
- **Low** Conditional Inspiration section is missing (EXPERIENCE.md:17-23; .memlog.md:16). The source trail names a stale green visual direction and explicitly rejects it as a source, but the spine has no Inspiration section recording accepted and rejected references. A later consumer can recover that rejected source without seeing the decision. *Fix:* Record the inherited app reference and rejected visual direction in an Inspiration section.

## Mechanical notes
- All 42 mockup files are linked from relevant sections; no broken local Markdown links were found.
- DESIGN token frontmatter parses; all 70 color entries have `-dark` counterparts; all 62 DESIGN and 4 EXPERIENCE token references resolve.
- All source paths in both spine frontmatters resolve in the workspace. The six UJ titles match the PRD titles (reconcile-prd.md:51-60).
- The “spines win on conflict” precedence statement appears in both spines (EXPERIENCE.md:15; DESIGN.md:288), although the rubric asks for it once.
- Finding counts: Critical 0, High 2, Medium 4, Low 3.
