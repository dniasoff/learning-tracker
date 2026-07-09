---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: architecture
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: bmad-create-architecture (placeholder; will be filled by skill rewrites)
- Target location: /Engineering/Architecture
- One-or-many: one per project
- Lifecycle: status starts as `draft`; flip to `canonical` when owner accepts
-->

# Architecture — Replace with Title Case

<!-- One paragraph framing: what system this describes and how this doc relates to the Platform Design. -->

## Overview

<!-- The high-level shape of the system. What problem space it covers, and the major design ideas. -->

## Components

<!-- The major building blocks. For each: responsibility, owner, and where its code/spec lives. -->

## Data flow

<!-- How information moves through the system. Include diagrams or sequence outlines for key paths. -->

## Dependencies

<!-- External services, internal subsystems, and libraries this architecture depends on. Note SLAs/criticality. -->

## Boundaries

<!-- What this system is responsible for and where its responsibility ends. Failure-domain notes. -->

## Trade-offs

<!-- Significant trade-offs taken. What was chosen, what was rejected, and the reasoning. Link to ADRs. -->

## Open questions

<!-- Unresolved architectural questions with named owners. Move resolved entries to ADRs and remove. -->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
