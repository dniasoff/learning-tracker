---
name: doc-session-policy
description: "Carry the documentation constitution (the 7 principles), the durable/transient tiering, and the manual-routing rules as session-persistent facts. Load once per session when working on documentation tasks."
---

# doc-session-policy

Load this skill once at the start of any session that reads, writes, ratifies, or publishes documentation. It is the machine-readable **constitution** for this project's living manual: the 7 principles, the durable-vs-transient tiering, the routing rules, and the Orvex Docmost fork context. These hold for the whole session without re-loading. When a routing decision is non-obvious, consult `{project-root}/_bmad/doc/data/decision-order.md` and `taxonomy.md` — never session memory.

## The north star

Every project owns **one living, rigidly-structured manual** — a Docmost wiki tree — seeded by planning, gated ahead of code, and continuously reconciled against the codebase. It is not date-stamped document sprawl. **The manual outranks the code; code conforms to the manual.** Before code is written, the intent is recorded in the manual and confirmed with a human, then built.

## The 7 principles (the constitution)

These are non-discretionary. Every authoring, routing, and ratification decision is checked against them.

- **P1 — Living register, not dated sprawl.** For any one concept there is exactly **one** live page, updated in place. No `-v2 / -final / -new / -wip / -revised / -copy / -updated / -2..-9` suffixes, and no date segments in slugs or titles except for the closed dated allow-list (P-dates below). The act of creating a sibling page for a concept that already has one is the failure mode this whole module exists to prevent.
- **P2 — Research and brainstorm are DURABLE, not ephemeral.** `research` and `brainstorm` are first-class living manual canon (Diátaxis *explanation* mode). They are updated in place like any other living doc. **"Ephemeral" means exactly three things and nothing else:** workflow state, test artifacts, and code-coupled in-flight story/epic files. If it isn't one of those, it is not ephemeral.
- **P3 — Update by default, ask when ambiguous.** Unambiguous updates flow autonomously. On a fuzzy candidate match, **suspend and ask one plain-English question** (existing page title + a one-line diff of what would change), then auto-resume from the reply. One question — not a form, not a nag.
- **P4 — Current-state-only bodies.** A page body describes the world as it is now. No inline history, no "previously / used to / no longer / deprecated as of" narration. History lives in git, in Docmost page history, and in a server-rendered changelog projection — never hand-authored into the body.
- **P5 — Supersession is whole-doc, to archive only.** When a concept is replaced, the **whole** old doc moves to archive and is linked to its live successor via `supersedes` / `superseded_by`. A live doc holds **zero** superseded content. There is no partial supersession inside a living page.
- **P6 — Reader empathy is the lens.** If a page is not archived, every line on it is true right now. Canonical pages change only through human ratification — never AI self-certification. A freshness signal (`status` + `last_reviewed_at` + `verified_against`) rides on every page.
- **P7 — Human-delightful, progressive disclosure.** The manual reads as a story that invites drilling deeper: a narrative root, a `tldr` lead on every non-root page, card-grid section landings, drill-down to detail, a picture before dense prose, a concrete example for every concept. The mechanics that make this achievable live in `data/rich-page-authoring.md` (the `page block` / instructions-embed surface) and `data/authoring-conventions.md` (house style); reach for them rather than settling for flat prose. **DIAGRAM POLICY:** coloured Excalidraw is the default for simple diagrams (≤~3–4 nodes) but renders blank until a human bakes it, so every Excalidraw block ships with an adjacent `[bake-pending]` warning and a tracked required-human bake task before promotion; use coloured Mermaid for anything multi-node / complex / must-render-unattended.

**The dated allow-list (P-dates).** Exactly three doc-types are dated/append (a new entry per occurrence is correct, dates are permitted): `release-notes`, `retro` (= `retrospective`), and `adr`. **Everything else is living** — update in place, dates banned. There are no other exceptions.

## Tiering — durable vs transient (the central rule)

The tier decides where a doc lives. This replaces any older three-letter tiering you may remember.

### Durable manual canon → the wiki

These are living docs in the project's Docmost manual. They are authored as `draft`, ratified to `canonical` by a human, and updated in place forever after:

`product-brief`, `prd`, `architecture`, `adr`, `technical-spec`, `api-reference`, `runbook`, `retrospective`, `release-notes`, `glossary`, `project-overview`, `feature-inventory`, `contract`, `ux-spec`, `trigger-map`, `persona`, `user-guide`, **`research`**, **`brainstorm`**.

**`research` and `brainstorm` belong here.** This is the central correction: they are durable manual canon, not scratch. Do not route them to a local repo path, do not treat them as ephemeral, do not let them sprawl into dated copies. `research` may file under a Product-facing node (market/domain research) or an Architecture-facing node (technical research), depending on subject — the project's own IA decides which.

### Transient → local repo only (the exact, closed set)

Only these are ephemeral, and the list is exhaustive:

- **Workflow state** — machine state files for an in-progress workflow.
- **Test artifacts** — generated test reports and fixtures (reproducible).
- **Code-coupled in-flight story/epic files** — a story or epic file while it is being implemented, before merge.

If content matures into durable knowledge, it transitions to a durable doc-type and is authored into the manual (e.g. a resolved brainstorm's decision becomes an ADR). The transient source is not what gets published — the durable output is.

## The IA is project-derived — there is NO fixed section skeleton

**This module ships no fixed manual section structure.** There is no canonical section skeleton to apply. Any specific section set you may encounter is one product's derived domain structure — not a documentation framework, and never a default to apply.

What the module ships is: (a) these 7 principles, (b) the universal durable doc-type catalog above, and (c) the mechanics (scaffold, amend, ratify, drift, supersede).

**Each project's manual section structure is derived at scaffold time** from that project's own planning artifacts — its brief, PRD, architecture, and domain — then confirmed with a human, and captured in a per-project `manual-outline.yaml` that the project owns. That file is a *generated per-project artifact* governed by a documented schema; it is never a shipped fixed skeleton. Any concrete multi-section layout you encounter is valid only as **one example** of a derived IA, never as the default.

When you read any doc that shows a concrete section layout, treat it as illustrative — never as a structure to apply.

## Routing — what the constitution requires

For the full decision tree, walk `{project-root}/_bmad/doc/data/decision-order.md`. The constitutional musts:

1. **Read against the manual node.** Resolve a planning artifact against the living manual (root + IA path), excluding `draft` / `superseded` / `archived` from grounding reads. Use `doc-read-first`.
2. **Find before create — across drafts AND canonical.** Query the synchronous duplicate-check before authoring anything new. A match means **update the existing node**, never spawn a sibling. Drafts count: a draft on the topic is still a match.
3. **Ask on ambiguity (P3).** One plain-English question; auto-resume.
4. **Amend in place, section-scoped.** Update only the affected sections; keep the body current-state-only (P4). Protected zones (the story root, the `tldr` lead, "how this manual works") are never flattened by an amend.
5. **Author as draft; ratify to canonical by human.** AI authors at `status: draft`. Promotion to `canonical` happens only through human ratification (server-guarded; service-account promotions are rejected). Drafts are quarantined from RAG/grounding reads until ratified.
6. **Record + confirm intent before implementing (wiki-first).** The manual outranks the code. New code is recorded as an intent node in the manual and human-confirmed **before** implementation. The confirmation lands at create-story time (where a human is present); dev-story only reads the resulting token.
7. **Supersede whole-doc to archive (P5).** Replacing a concept moves the whole old doc to archive with two-sided links and a transclusion-impact pre-flight. Never leave superseded content inside a live page.

## Guardrails carried for the whole session

- **Current-state-only.** Never write obsolescence narration into a body. History is projected, not authored (P4).
- **Supersede to archive, whole-doc.** No partial supersession; no superseded content on a live page (P5).
- **Ask when ambiguous, one question.** Do not stack questions; do not proceed past a genuine ambiguity (P3).
- **Draft is not canonical.** AI never self-promotes; canonical mutations are ratified (P6).
- **No version/date suffixes on living slugs.** Strip `v1/v2/vN/final/old/new/wip/draft-N` and date segments when deriving a wiki slug from a BMAD working filename. Dates are permitted only on the three dated types.
- **CAS by default.** Skill writes use `--if-version` to stay concurrency-safe.

## Fork-context: this is the Orvex Docmost fork

This installation connects to an Orvex-fork Docmost server with native page-metadata columns (`status`, `doc_type`, `owner_id`, `last_reviewed_at`, `supersedes`, `superseded_by`, `redirect_from`, plus `verified_against` and `spec_confirmed` on later phases) and server-side endpoints for audit, duplicate-check, and the spec gate.

- The `docmost-cli` CLI is the only sanctioned interface. Never call Docmost HTTP APIs directly; never edit the local cache directly.
- Every mutating `docmost-cli` command dual-writes an audit entry to the local JSONL log and to the server. On by default; the kill-switch is `--no-server-audit` / `ORVEX_DOC_NO_SERVER_AUDIT=1` — leave it off unless told otherwise.
- `--doc-type` and `--status` are required when creating or promoting a canonical page. The server validates `doc_type` against its allow-list; use the lowercase-kebab value from the catalog. `--owner-id` defaults to the authenticated user; pass it only to attribute a write to a different identity.

## Config keys

The session-scoped config for this project lives at `{project-root}/_bmad/doc/config.yaml`. Keys consumed by skills in this module:

| Key | Purpose |
|---|---|
| `docmost_url` | Server URL (passed automatically by the CLI from its own config; present here for documentation). |
| `docmost_space` | Space slug for this project's manual (docmost-cli resolves to UUID on demand). |
| `docmost_manual_root_slug` | Slug of the manual's root page — the entry point for manual-node resolution. |
| `docmost_manual_outline` | Path to this project's `manual-outline.yaml` (the project-derived IA). |
| `wiki_first_enforcement` | `off \| warn \| block`. **Defaults to `block`.** Governs whether dev-story HALTs on a missing confirmed intent node. |

Optional (resolve to sensible defaults if omitted):

| Key | Purpose |
|---|---|
| `docmost_default_owner_id` | Override the page owner. Default: the authenticated user from `docmost-cli auth login`. |

## Data files

The data files under `{project-root}/_bmad/doc/data/` are the authoritative sources for this session:

- `wiki-first-mandate.md` — the always-on wiki-first orientation: the wiki is the mandatory primary source of truth and outranks local files, plus how to access it (`docmost-cli`). Loaded into every agent and planning workflow so the doctrine is identical everywhere.
- `taxonomy.md` — the durable doc-type catalog, the living-vs-dated rule, the date-slug regex, and the IA-derivation contract.
- `decision-order.md` — the full routing decision tree for all documentation operations.
- `docmost-cli-reference.md` — complete CLI reference for `docmost-cli`, now covering the full v1.1.0 surface: the `page block` embed surface, `page replace` / `space replace`, line-addressed `page patch`, the `verify` suite (lint / drift / ia-conformance / render), the spec gate check, `migrate` (scan / apply / verify), `ai` image / cost / reembed, and `docs link`. It also carries the **EMBED-READ LANDMINE** (below).
- `rich-page-authoring.md` — the `page block` / instructions-embed surface (≈28 embed types), the composition recipe, `verify render`, the DIAGRAM POLICY, and the embed-read landmine in §0.
- `authoring-conventions.md` — house style: header-card callout, ·-metadata bar, emoji legend, Canon row + ↑Part-of breadcrumb, coloured mermaid, blank-header tables, tone registers, sibling uniformity.
- `citations-and-crosslinks.md` — page mentions, public share-URL form, backlinks / breadcrumbs, the anti-orphan link-in step, citing evidence + Sources + the validation checklist.
- `page-patterns/program-delivery.md` — copy-paste hub + milestone skeletons (the program-delivery layout).
- `doc-type-templates/` — starter templates for each durable doc-type, including the dual-mode release-notes templates (`release-notes.md` per-version and `release-notes-index.md` living landing).
- `manual-outline.yaml` — this project's derived IA (generated per-project artifact; the schema is documented, the content is project-owned). Absent until the manual is scaffolded.

**EMBED-READ LANDMINE.** `page get` — *including* `--output json` — silently drops embeds (they surface as empty `##` headers) and strips link URLs. `page mirror pull` is the only faithful read; `mirror push` is lossy for embeds (strips args). So: **read** embed-bearing pages via `mirror pull`, and **author / repair** embeds via `page block` — never reconstruct an embed from mirror markdown and push it back.

Consult these files rather than session memory when making routing decisions.
