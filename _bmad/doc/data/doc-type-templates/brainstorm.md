---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: brainstorm
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: bmad-brainstorm (placeholder; will be filled by skill rewrites)
- Target location: the Architecture-facing (or relevant concept) node your project's manual-outline.yaml defines for brainstorm. No fixed path is shipped — resolve it from the project's outline (taxonomy §4).
- One-or-many: many per project (one living doc per open question — update in place, never date the slug)
- Lifecycle: status starts as `draft`; flip to `canonical` once the question and its current leaning are stable
- Diataxis mode: explanation. This is durable canon (P2), NOT an ephemeral artifact — the reasoning is meant to be re-read.
- Living, not dated (P1/P4): one doc per question, updated in place as thinking moves. No dated entries or "we used to think" narration in the body; supersession is whole-doc to archive (P5).
- When the question is decided, the decision lives in an ADR — link it from "What resolves it" and keep this doc current.
-->

# Brainstorm — Replace with Title Case

> **In short** — <!-- The one-line state of play in ~15-25 words: the question, and where we are currently leaning. Not a restatement of the title. (P7 inverted-pyramid lead) -->

<!-- One paragraph framing: the open question this explores, why it is worth thinking hard about, and what a good answer unlocks. -->

## The question

<!-- The decision or design problem under exploration, stated precisely. What forces are in tension? What would make any answer "good enough"? State the scope: what is and isn't on the table. -->

## Options considered

<!--
The candidate answers, each weighed on its own terms. Lead each with its core idea, then the case for and against.
Keep it current-state: list the options still worth comparing. Discarded dead-ends can be summarised in one line, not narrated as history.
A before/after or trade-off Mermaid diagram or comparison table earns its place here (P7 — a picture before dense prose).
-->

### Option A — <name>

<!-- The idea, then for / against. -->

### Option B — <name>

<!-- The idea, then for / against. -->

## What we are leaning toward

<!-- The current best answer and the reasoning that makes it the front-runner. State it as the present view, not a chronology. Honest about what would change our minds. -->

## What resolves it

<!-- The concrete thing that would settle the question: an experiment, a spike, a stakeholder call, a constraint we are waiting on. Name the owner. When decided, link the ADR here and reflect the outcome in the leaning above. -->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
