---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: redesign-doc
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: bmad-redesign (placeholder; will be filled by skill rewrites)
- Target location: /Engineering/Redesigns/<topic>
- One-or-many: many per project (one per redesign effort)
- Lifecycle: status starts as `draft`; flip to `canonical` when the redesign is approved; archive after delivery
-->

# Redesign — Replace with Title Case

<!-- One paragraph framing: which existing feature is being redesigned and why now. -->

## Current state

<!-- The system as it stands today. Be specific: behaviour, code locations, known issues. -->

## Pain points

<!-- The concrete problems driving the redesign. Each pain point is observable and ideally measurable. -->

## Proposed design

<!-- The new shape. Components, data flow, user-visible changes. Link to ADRs for foundational choices. -->

## Migration

<!-- How we move from current to proposed: phases, data migrations, dual-running, cutover, rollback. -->

## Trade-offs

<!-- What the new design gives up to gain what it gains. Make the cost explicit, not just the benefit. -->

## Phasing

<!-- The delivery plan. Each phase has scope, exit criteria, and the user value it unlocks. -->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
