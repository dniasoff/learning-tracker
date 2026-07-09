---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: project-overview
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: doc-librarian / manual-scaffold (the manual ROOT — one per project)
- Scaffold recipe: manual-root — `page scaffold ... --scaffold manual-root` adds the
  cover/icon hint, the role-anchored `tldr` lead callout, and the freshness ribbon
  ABOVE this body. Do NOT add your own "in short" lead here — the scaffold owns it.
- This is the reader's FRONT DOOR: a compelling story that invites drilling deeper.
- The frontmatter above is parsed to native metadata by the scaffold and is NOT
  rendered in the page body. Current-state-only; a human ratifies draft → canonical.
-->

# The {project_name} Manual

<!-- THE STORY (1–3 short paragraphs). Lead with the conclusion. Who is this for,
     why does {project_name} exist, and what changes for them because it does?
     Make a newcomer want to read on. Replace this block with the project's story. -->

{project_name} exists to {the why — the problem it removes / the outcome it creates}.
For {primary audience}, that means {the concrete change — the before → after}.

## How this manual works

:::info
**This manual outranks the code.** What is written here — once ratified — is the
intended truth; the code is reconciled to it, not the other way round.

- **Drill down.** Start here, then open a section, then a concept page. Each page
  leads with an "in short" so you can stop at the depth you need.
- **One living doc per concept.** We amend pages in place — never `…-v2`, never a
  dated copy. If something changed, the page already reflects *now*.
- **Amend, never overwrite the record.** History lives in version control + page
  history + the changelog; the body only states what is true today.
- **Drafts vs canonical.** AI and planning land changes as **drafts**; a human
  ratifies a draft → **canonical** one question at a time. If a page isn't
  archived, every line on it is true now.
:::

## Sections

<!-- The manual-scaffold procedure derives these from the project's own artifacts and
     fills this as a status-filtered card grid (subpages, display: card) linking each
     top-level section. Do not hand-maintain a list here — it is generated. -->
