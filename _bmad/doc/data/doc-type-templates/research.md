---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: research
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: bmad-research (placeholder; will be filled by skill rewrites)
- Target location: the Product-facing or Architecture-facing node your project's manual-outline.yaml defines for research, chosen by subject (market/domain → Product-ish; technical/build → Architecture-ish). No fixed path is shipped — resolve it from the project's outline (taxonomy §4).
- One-or-many: many per project (one living doc per subject — update in place, never date the slug)
- Lifecycle: status starts as `draft`; flip to `canonical` once findings are stable and reviewed
- Diataxis mode: explanation. This is durable canon (P2), NOT an ephemeral artifact — it is read away from the keyboard.
- Living, not dated (P1/P4): one doc per subject, updated in place. No "as of <date>" history in the body; supersession is whole-doc to archive (P5).
- Route by subject (MI-4): market/domain → Product; technical/build → Architecture.
-->

# Research — Replace with Title Case

> **In short** — <!-- The single conclusion in ~15-25 words: what we now know about this subject and the one decision it most informs. Not a restatement of the title. (P7 inverted-pyramid lead) -->

<!-- One paragraph framing: what subject this investigates, why it matters now, and which product/architecture decision it feeds. -->

## Subject

<!-- What was investigated and the question that motivated it. State the scope boundary: what this research covers and what it deliberately leaves out. -->

## Key findings

<!--
The conclusions, lead-with-the-answer. Each finding stands alone and is independently checkable.
Most important first. Prefer a short, scannable list; expand the rare detail in a toggle.
-->

## Evidence & sources

<!--
What each finding rests on. One row per source so a reader can re-derive the conclusion.
| Source | What it tells us | Strength | Link |
|---|---|---|---|
Mark confidence honestly (strong / suggestive / anecdotal). Synthetic numbers must be labelled as such.
-->

| Source | What it tells us | Strength | Link |
|---|---|---|---|
|  |  |  |  |

<!-- Placeholder: drop a chart, comparison table, or Mermaid/Excalidraw diagram here when it makes a finding land faster (P7 — a picture before dense prose). -->

## Implications

<!--
So-what. Translate findings into consequences for product and architecture.
- Product (market/domain): what this changes about the brief, the PRD, the audience, the bet.
- Architecture (technical): what this changes about the design, the constraints, the trade-offs.
Link the docs this research should update (page mentions). Resolved implications become canonical there, not here.
-->

## Open questions

<!-- What this research did not settle. Each entry names the question, why it is open, and the owner. When a question is resolved by a decision, link the ADR and remove the entry. -->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
