---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: ux-spec
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skills: bmad-create-ux-design, wds-3-scenarios, wds-4-ux-design (workflow-specify, workflow-handover)
- Target location: /Engineering/UX-Specs/<topic>
- One-or-many: many per project (one per page / scenario / feature area)
- Lifecycle: status starts as `draft`; flip to `canonical` when the spec is approved for build; archive when the surface is retired or supersede when redesigned
- Relationship to other types:
  - A redesign typically produces one Redesign Doc *and* one or more UX Specs.
  - UX Specs reference Personas and the Trigger Map for context — link them, don't duplicate them.
-->

# UX Spec — Replace with Title Case

<!-- One paragraph framing: which surface / page / flow this spec covers, and for whom. -->

## Scope

<!--
What this spec covers and what it deliberately doesn't.
- In scope: pages, components, flows, states, error / empty / loading variants.
- Out of scope: backend internals, infra, downstream API contracts (link to Technical Spec / API Reference).
-->

## Personas and triggers

<!--
Which personas drive this surface, and which Trigger-Map entries it serves.
Reference by slug:
- Persona: [persona/<name>](persona/<name>)
- Trigger Map entry: [trigger-map#<anchor>](trigger-map)
-->

## User journey

<!--
The happy-path scenario(s) this surface supports. One linear sunshine path per scenario;
edge cases live under "States" below, not inline in the journey.

Entry → Step 1 → Step 2 → ... → Exit
-->

## Interaction details

<!--
Component-by-component / control-by-control spec. For each interactive element:
- Name + purpose
- Trigger (click / hover / focus / submit / etc.)
- Behaviour on each input variant (valid, invalid, empty, slow network)
- Affordance: hover state, disabled state, focus ring, keyboard support
-->

## States

<!--
Enumerate every state the surface can occupy. The canonical set for most surfaces:
- Default / idle
- Loading (initial fetch, optimistic update, background refresh)
- Empty (no data yet, all filtered out, never had data)
- Error (network, validation, permission, server, partial)
- Success (transient confirmation, persistent acknowledgement)
- Disabled / read-only (lack of permission, soft-deleted parent)

For each state: trigger, visible content, transitions out.
-->

## Visual / layout

<!--
Layout grid, spacing, typography, color tokens. Reference the design system by component slug —
do NOT redefine tokens locally. If a needed token doesn't exist, raise it in the design-system
space first and link forward.

- Components used: [design-system/<component>](design-system/<component>)
- Tokens used: [design-system/design-tokens](design-system/design-tokens)
-->

## Responsive behaviour

<!--
Breakpoints and what changes at each. Mobile-first wording is fine if that's the project convention.
- Small (< 640px): ...
- Medium (640–1024px): ...
- Large (≥ 1024px): ...
-->

## Accessibility

<!--
Beyond "must pass WCAG AA". Concrete acceptance:
- Keyboard: every action reachable, focus order is logical
- Screen reader: every control labelled, every state announced
- Reduced motion: animation respects prefers-reduced-motion
- Contrast: every text/control passes AA for its size
-->

## Acceptance criteria

<!--
Testable Given/When/Then. Each criterion maps to at least one state above.

- Given <state>, when <action>, then <observable result>
-->

## Open questions

<!--
List deliberately. Each entry has: question, blocker-y/n, who can decide. Resolve before status flips to `canonical`.
-->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
