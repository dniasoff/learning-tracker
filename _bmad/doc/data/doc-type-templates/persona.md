---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: persona
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: wds-2-trigger-mapping (produces personas alongside the Trigger Map)
- Target location: /Product/Personas/<name>
- One-or-many: many per project (one page per persona; slug is the persona's short name in kebab-case)
- Lifecycle: status starts as `draft`; flip to `canonical` once UX + business agree the persona is accurate;
  revise in-place as you learn — do NOT create -v2 siblings or archetype variants. Variations live under "Variants" below.
- Relationship to other types:
  - Referenced by Trigger Map (`/Product/Trigger-Map`) and by UX Specs (`/Engineering/UX-Specs/<topic>`).
  - Cite the persona by slug from those docs, don't duplicate the fields here.
-->

# Persona — Replace with Persona Name

<!-- One paragraph framing: who this persona is in one human sentence, not a job-title list. -->

## Snapshot

<!--
The single-page summary. Keep this tight; depth lives in the sections below.

- **Short name (slug):** <kebab-case identifier used in references>
- **Archetype label:** <e.g. "Pragmatic Platform Engineer">
- **Primary context:** <where they work, time pressure, environment>
- **Decision power:** <who they influence, who decides for them>
-->

## Goals

<!--
What this persona is trying to achieve in the contexts where our product matters. 3–7 entries.
Phrase as outcomes ("ship the feature without on-call incidents"), not features ("uses our dashboard").
-->

## Contexts

<!--
The recurring situations in which the persona engages. Each context is a setting + a motivation.

### <Context name>
- **Setting:** <when / where / under what pressure>
- **Trigger to engage:** <what makes them turn to a tool like ours>
- **Success looks like:** <observable outcome>
-->

## Triggers

<!--
Psychological states that pull the persona toward the desired behaviour.
Mirror entries in the Trigger Map. If the Trigger Map changes, update both sides — or use transclusion to keep one source.

- **<Trigger name>** — <description>
-->

## Counter-triggers

<!--
What pushes them away — fears, frictions, mistrust. WDS-specific extension. Mirror Trigger Map entries.

- **<Counter-trigger name>** — <description>
-->

## Mental model

<!--
How this persona thinks about the problem space. The vocabulary they use, the mental shortcuts they take,
the analogies they reach for. Critical for content + interaction design.
-->

## Constraints

<!--
What they cannot or will not do, regardless of how well-designed the surface is. Time budgets, tooling lock-in,
organisational rules, accessibility needs, language, device. These shape what's even *possible* for this persona.
-->

## Variants

<!--
If this persona has meaningful sub-types, describe them here as sub-sections — NOT as separate persona pages.
A persona splits into a new page only when the differences are large enough that triggers + goals diverge.

### <Variant name>
- **How they differ from the base:** <one paragraph>
- **Where the variant matters:** <specific surfaces or flows>
-->

## Anti-persona

<!--
Optional but valuable: who this product is explicitly NOT for. Naming the anti-persona helps prevent
scope creep in trigger mapping and UX specs.
-->

## Open questions

<!--
Things we don't yet know about this persona. Resolve before status flips to `canonical`.
-->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
