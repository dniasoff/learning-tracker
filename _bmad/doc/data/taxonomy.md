# Documentation Taxonomy

> Scope: Information architecture for project documentation — tooling-agnostic
> Storage: Docmost native page-metadata columns; YAML front-matter is the markdown interchange format

## Background

This taxonomy is designed for a small AI-augmented team. The pain point: AI agents have a structural tendency to write *new* documents rather than update *existing* ones, producing v1/v2/v3 sprawl and ambiguous canonical sources. The taxonomy makes "where does this go?" non-discretionary for AI, and navigation natural for humans.

The unit of organization is **one living manual per project** — not a pile of documents. Every project owns a single Docmost wiki tree that is seeded by planning, updated in place as the project evolves, and reconciled against the codebase. Authoring is *update-by-default*: the question is never "which new file?" but "which existing node does this belong to?"

---

## 1. The single living manual

Each project has **one** manual: a Docmost wiki tree with a story-first root page and a small set of section landings beneath it. Every doc_type from the catalog (§4) maps to a node in that tree. The tree is seeded — and idempotently re-seeded — by `docmost-cli page tree apply`, which matches existing pages by **title under the parent (case-sensitive)** and **updates in place** rather than re-creating (the P1-critical property). `--on-existing skip|update|recreate` (default `skip`) controls whether a matched node's content is overwritten. Rename-safe key-matching is **PENDING** (the CLI does not yet match on the IA `key`), so keep node titles stable across re-applies.

### 1.1 No fixed section IA is shipped

This module **does not ship a fixed section skeleton.** There is no built-in "these are the seven sections every manual has." A manual's section structure is **derived per project** from that project's own planning artifacts (brief, PRD, architecture, domain model) and **confirmed with a human** at scaffold time, then captured in a per-project `manual-outline.yaml` that the project owns.

What the module ships is exactly three things:

1. **The constitution** — the 7 principles (§2), which hold for every manual regardless of its shape.
2. **The universal doc-type catalog** (§4) — the building blocks. These are the *kinds* of documents a manual can contain; they are domain-agnostic and stable across projects.
3. **The mechanics** — naming rules, the living/dated discipline, supersession, the decision router (`decision-order.md`), and the lifecycle commands.

The per-project section IA is assembled *from* the catalog at scaffold time and recorded in `manual-outline.yaml` (a **generated** per-project artifact governed by a documented schema — never a shipped fixed skeleton). When `tree apply` re-runs, it reads that project's own `manual-outline.yaml`; it never imposes a section list of its own.

> **Sections are derived, never prescribed.** A project assembles its own top-level sections from this catalog at scaffold time, shaped by its own domain and artifacts. **No section set is a default, a template, or a required structure** — one project might land on *Product / Architecture / Operations / Reference*, another on something entirely different. Every project's `manual-outline.yaml` looks different, and that is correct. For a hypothetical worked example of the *shape*, see `manual-ia.md` §5.

### 1.2 The P5 invariant

A **live doc holds zero superseded content.** When a concept is replaced, the *whole* doc moves to archive and links forward to its successor (§7, supersession). Superseded material never lingers inside a live page as struck-through text, "old approach" sections, or commented-out blocks. If a page is not archived, every line in it is true now (P6).

---

## 2. The constitution — 7 principles

These hold for every manual. Skills carry them as machine-readable facts; CLI and server enforce the checkable ones.

1. **P1 — Living register, not dated sprawl.** For any concept there is exactly **one** live page. Update it in place. Banned filename/slug/title suffixes and out-of-allow-list date segments are rejected at the create API (§6).
2. **P2 — Research and brainstorm are DURABLE, not ephemeral.** `research` and `brainstorm` are first-class living manual canon (Diataxis *explanation* mode is their home). "Ephemeral" means **only**: workflow state, test artifacts, code-coupled in-flight story/epic files. Nothing else (§3).
3. **P3 — Update-by-default, ask-when-ambiguous.** On a fuzzy candidate match, suspend with **one** plain-English question (the existing page's title + a one-line diff) and auto-resume from the reply. Unambiguous updates flow autonomously.
4. **P4 — Current-state-only bodies.** No inline history or obsolescence narration ("previously…", "used to…", "no longer…", "deprecated as of…"). History lives in git + Docmost page history + a **server-rendered** changelog projection — never a hand- or AI-editable body block.
5. **P5 — Supersession is whole-doc to archive only.** A live doc holds **zero** superseded content. `page supersede` is atomic and two-sided. Card grids exclude superseded/archived pages so no dead cards survive on a live landing.
6. **P6 — Reader empathy is the lens.** If a page is not archived, every line is true now. A freshness ribbon (`status` + `last_reviewed_at` + `verified_against`) rides every page; canonical pages change only through human ratification.
7. **P7 — Human-delightful, progressive disclosure.** Story-first root; every non-root page leads with a `tldr`; section landings are card grids; drill-down for detail; visuals before dense prose.

> **Diataxis is a content lens, not the taxonomy.** When authoring, ask: is this *tutorial / how-to / reference / explanation*? That choice shapes how a page is written and which section it tends to land in. It does **not** decide where the doc lives — the catalog and the project's `manual-outline.yaml` do that.

---

## 3. Tiering

Two tiers, sharply separated. The dividing line is durability, not audience or format.

### Tier A — Durable manual canon (lives in the wiki)

Everything humans or future agents need to understand the project lives here, as one living page per concept. Tier A **includes `research` and `brainstorm`** (this is the central correction over earlier drafts): research findings and ideation are durable explanation, not throwaway notes. They are written once per topic and updated in place, exactly like any other canon.

Tier A doc_types: `product-brief`, `prd`, `architecture`, `adr`, `technical-spec`, `api-reference`, `runbook`, `retrospective`, `release-notes`, `glossary`, `project-overview`, `feature-inventory`, `contract`, `ux-spec`, `trigger-map`, `persona`, `user-guide`, **`research`**, **`brainstorm`**.

### Tier C — Transient-local (lives in the repo, never the wiki)

Tier C is **narrowed to exactly this closed set** — nothing else is transient:

| Transient artifact | Repo path | Why local |
|---|---|---|
| Workflow state | `<work-output>/.workflow-state/` | Machine-only execution state |
| Test artifacts | `<work-output>/test-artifacts/` | Generated; reproducible |
| Audit reports | `<work-output>/audit/` | Generated; one-shot |
| Design mockups | `<work-output>/design-mockups/` | Generated assets |
| In-flight story files (code-coupled) | `<work-output>/stories/<id>.md` | Coupled to active code; merged into the codebase |
| In-flight epic files (code-coupled) | `<work-output>/epics/<id>.md` | Coupled to active code; merged into the codebase |
| One-off prompts / plans | `docs/_prompts/`, `docs/_plans/` | AI-only; high churn; tied to a single run |
| Sprint-change proposals | `docs/_plans/sprint-change-*.md` | Tied to one active sprint |

If an artifact is not in this table, it is **not** Tier C. In particular, research, brainstorm, retrospectives, and readiness/validation findings worth keeping are durable canon (Tier A), not transient.

> There is no "transient → durable resolution" inversion table anymore. Durable knowledge is written *directly* to its living Tier-A node via `doc-amend`; it does not start life as a transient artifact that later gets promoted.

---

## 4. Doc-type catalog

The universal building blocks. Each row is a *kind* of document; the project's `manual-outline.yaml` decides which section each one lands under. Columns:

- **doc_type** — the lowercase-kebab value passed to `docmost-cli` and stored in the native `doc_type` column. Skills consult this catalog for the slug; they never coin or recase it.
- **One/many** — one page per project, or many.
- **Living vs dated** — see §5. Living = update-in-place, dates banned. Dated = append-only, date segment permitted.
- **Diataxis mode** — the dominant content lens for writing the page.
- **IA mapping** — which kind of derived section this type typically files under (audience-shaped; the actual node comes from `manual-outline.yaml`).

| doc_type | Description | One/many | Living vs dated | Diataxis mode | Typical IA node |
|---|---|---|---|---|---|
| `project-overview` | Manual root / project knowledge index | one | living | explanation | root |
| `product-brief` | Executive overview of the product | one | living | explanation | Product-ish |
| `prd` | Product requirements (with child sections) | one | living | explanation | Product-ish |
| `architecture` | System architecture canon | one | living | explanation | Architecture-ish |
| `platform-design` | Platform/design canon — durable design model | one | living | explanation | Architecture-ish / Platform-ish |
| `technical-spec` | Subsystem spec (schema, protocols, internals) | many | living | explanation → reference | Engineering-ish |
| `contract` | Inter-service or design contract | many | living | reference | Engineering-ish |
| `feature-inventory` | Operator/control-surface enumeration | many | living | reference | Engineering-ish |
| `api-reference` | Public API surface documentation | many | living | reference | Library-ish / Reference-ish |
| `user-guide` | End-user / operator guide (incl. onboarding) | many | living | how-to | Library-ish |
| `ux-spec` | UX / interaction / visual design specification | many | living | explanation → reference | Product-ish / Engineering-ish |
| `redesign-doc` | Scoped redesign of an existing feature | many | living | explanation | Engineering-ish |
| `glossary` | Canonical term definitions | one | living | reference | Reference-ish |
| `trigger-map` | Business-goals-to-user-psychology map | one | living | reference | Product-ish / Reference-ish |
| `persona` | User persona / archetype | many | living | reference | Product-ish / Reference-ish |
| **`research`** | Market/domain/technical research findings | many | **living** | explanation | **Product-ish OR Architecture-ish (by subject)** |
| **`brainstorm`** | Durable ideation / option exploration | many | **living** | explanation | Architecture-ish (or the relevant concept node) |
| `runbook` | Operational procedure | many | living | how-to | Operations-ish |
| `release-notes` | Per-release changelog | many | **dated/append** | reference | Operations-ish |
| `retrospective` | Post-epic / post-incident review | many | **dated/append** | explanation | Operations-ish |
| `adr` | Architecture Decision Record | many | **dated/append** | explanation | Architecture-ish |

Notes:

- **`research` routes by subject (many-to-one).** Market or domain research files under a Product-ish node; technical research files under an Architecture-ish node. The doc_type is the same (`research`); only the IA placement differs. The scaffolding human (or `doc-amend`) picks the node by subject.
- **`brainstorm` is durable** (P2). It is written once per topic and updated in place — it is not a scratchpad. Pre-decision ideation that genuinely is throwaway is workflow state (Tier C), not a `brainstorm` doc.
- **`release-notes` is dual-mode** (like `adr`). The IA node is a *living* **landing/index** page (`doc_type: release-notes`, scaffold recipe `index`, title `Release Notes`, no version/date in its slug, updated in place each ship) plus one *dated/append* **version child** per release (title `Release Notes vX.Y`, slug `release-notes-vX-Y`). Templates: `release-notes-index.md` (landing) + `release-notes.md` (per-version). Owned by the `doc-release` command → `doc-amend` (create at draft) → `doc-ratify` (ship to canonical + update the landing's latest pointer).
- **Onboarding** is a `user-guide` with `tags: [onboarding]`, not a separate type.
- **FAQ** is not a top-level type; FAQs live as a section inside the relevant doc.
- **`ux-spec` vs `redesign-doc`** — `ux-spec` captures interaction/visual design intent; `redesign-doc` is the broader workflow document (current-state pain + migration).
- **Cross-project / shared content** — patterns reused across projects live in a dedicated shared space; a shared tool/library gets its own per-tool space. Same catalog, same rules.

---

## 5. Living vs dated discipline

The default is **living**: one page per concept, updated in place, **dates banned** from slugs and titles. A living page reads as the current truth; its history is in git + page history + the server-rendered changelog projection (P4).

The **only** dated/append doc_types — a **closed allow-list** — are:

- `release-notes`
- `retrospective`
- `adr`

For these three, each entry is intrinsically tied to a moment (a release, a review, a decision) and is **append-only**: a new entry never overwrites an old one, and a date segment in the slug is meaningful and permitted. For every other doc_type, a dated slug is a bug.

**Per-occurrence dedup for dated types.** Find-before-create on a dated type asks "does *this* occurrence (this version / this date / this decision) already exist?" — **not** "does any release/retro/ADR page exist?". A prior version is **not** a duplicate to amend; a new release is a genuinely-new child. So `doc-amend`'s P1 amend-in-place reflex is **suspended** for a new dated occurrence: it CREATEs a new dated child under the section landing. Conversely, the P4 "no obsolescence narration" lint is **exempt** on dated version/entry pages — their whole purpose is dated, past-tense description ("Released YYYY-MM-DD", "Decided …"). The lint must not fire `P4-OBSOLESCENCE-NARRATION` on a `release-notes`/`retrospective`/`adr` page body.

**The living landing vs the dated children.** Each of these three has a *living index landing* (P1/P4 apply — one page, no dates in its slug, latest-pointer updated in place) **plus** the dated children (append-only history). `release-notes` → a `Release Notes` landing + `Release Notes vX.Y` children; `adr` → a Decision Records index + `NNNN-` children. Don't conflate the two: the landing is normal canon; the children are the sanctioned dated content.

> Enforcement: a trailing date segment is permitted on a slug **only** when `doc_type ∈ {release-notes, retrospective, adr}`, validated against the page's `doc_type` — **not** against the slug text. See §6 for the regex and the create-path validation.

---

## 6. Naming and navigation contract

### Slugs and titles

- **Slug:** kebab-case. No version markers, no dates (except the three dated types above).
- **Title:** human-friendly Title Case.
- **Banned suffixes** in any wiki filename, slug, or title (rejected at the create API):
  `-v2`, `-final`, `-new`, `-wip`, `-revised`, `-copy`, `-updated`, and bare numeric suffixes `-2` … `-9`.
- **Date-slug regex** (a trailing ISO date segment), permitted **only** for `release-notes` / `retrospective` / `adr`, validated against `doc_type`:

  ```
  -(\d{4}-\d{2}-\d{2})$
  ```

  (ADR slugs may instead carry a leading `NNNN-` sequence number, e.g. `0007-choose-postgres`. `release-notes` version children carry the **version as their dated key** — slug `release-notes-vX-Y` (semver dots → hyphens), title `Release Notes vX.Y` — which is the legitimate append-only identity for that type, analogous to the ADR sequence, **not** a banned `-v2`/`-final` duplicate-variant suffix. These keyed forms are accepted for their own dated type and no other.)

- **Conflict resolution:** if the natural slug for a new doc is already taken, the doc is **not created**. The existing page is updated. Slug collision is a duplicate signal, full stop.

### Navigation contract

- **One space per project** (plus a shared space for cross-project patterns and per-tool spaces for shared libraries).
- The space root is the manual root: a story-first `project-overview` page whose card grid lists the project's derived sections.
- Each section landing names which doc_types it contains — drawn from the project's `manual-outline.yaml`, not from a fixed list here.
- Test or temporary spaces are filtered out of default listings.

---

## 7. Lifecycle and guardrails

### Decision routing

The non-discretionary router lives in `decision-order.md`. The short version: READ the living node → FIND-BEFORE-CREATE (including drafts) → ASK on a fuzzy candidate (P3, one question) → AMEND in place → CREATE only when there is genuinely no candidate → AI authors at `draft`, humans ratify to `canonical` → wiki-first / drift / supersede branches. Consult that file for the exact command paths.

### What is enforced where

| Guardrail | Enforced by |
|---|---|
| Banned suffixes + date-slug-vs-`doc_type` validation | Server (create-path slug/title validation) |
| Find-before-create dup guard **including drafts** | CLI (`page create` synchronous dup guard) + Server (`POST /api/orvex/pages/duplicate-check`) |
| `--force-new` requires a human-attributed token | CLI + Server (rejects self-authored prose; emits a `FORCED_NEW` audit event) |
| Concurrency safety on writes | CLI/Server (`--if-version` CAS, default for skill writes) |
| Current-state-only bodies (P4) + P7 substance | CLI (`verify lint` rule-IDs: `P4-OBSOLESCENCE-NARRATION`, `P7-*`) |
| Draft → canonical only by a human | Server (transition guard; rejects service-account promotions) |
| Allowed `doc_type` set | Server (`allowedDocTypes` allow-list) |
| Living/dated discipline | Server (validation) + skill prose |

Everything else (which node a piece of content belongs to, how to phrase the one ASK, when to split across nodes) is skill judgment routed by `decision-order.md`.

### Supersession (P5)

Whole-doc only. To replace a concept:

```bash
docmost-cli page transclusion-impact <old-slug> --operation supersede --output json
docmost-cli page supersede <new-slug> --supersedes <old-slug>
docmost-cli page update <new-slug> --redirect-from <old-slug>
```

`page supersede` flips both sides atomically and moves the old doc to archive. The live successor holds **zero** superseded content. Card grids auto-drop archived/superseded pages.

### Quarantine vs the dedup index — they are different scopes

These two mechanisms both touch `draft` pages but answer different questions; do not conflate them:

- **Retrieval quarantine** governs *what feeds the next agent's reasoning.* `ai ask` and grounding reads **exclude** `draft`/`superseded`/`archived` (a `pages.status` join in retrieval SQL). An un-ratified draft must not silently become ground truth.
- **The create-time dedup index** governs *whether a new page may be created.* It **includes** drafts on purpose: find-before-create must catch a half-written draft on the same topic, or two agents racing would each create a parallel draft.

So a draft is invisible to RAG grounding but fully visible to the duplicate guard. That asymmetry is intentional.
