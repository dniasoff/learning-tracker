# Manual Information Architecture — Derivation Procedure

> Scope: How a project's living-manual section structure is **derived** from that
> project's own planning artifacts — not picked from a shipped skeleton.
> Companion schema: `manual-outline.schema.yaml` (the shape of the generated artifact).
> Consumed by: the `manual-scaffold` procedure, which transforms this outline into a
> flat node list and feeds it to `docmost-cli page tree apply <flat-nodes-file>` (positional).

## The rule that governs this whole file

**This module hardcodes NO fixed section taxonomy.** There is no shipped
Platform/Product/Library/… skeleton, no canonical seven sections, no default
folder set. Any section taxonomy you find quoted in this module — including the
worked example in §5 — is **one project's own derived structure**, reproduced to
illustrate the procedure, never to be copied as a template.

What the module *does* ship is fixed and small:

1. **The constitution** — the 7 principles (see `doc-session-policy`). These are
   universal and do not change per project.
2. **The universal doc-type catalog** — the building blocks every manual is made
   of (see `taxonomy.md` §4). Doc-types are universal; *where they sit* is not.
3. **The mechanics** — `manual-outline.schema.yaml`, the scaffold procedure, the
   `page tree apply` idempotent applier, the lint and drift engines.

Everything between "the building blocks" and "a finished manual tree" — i.e. the
**section structure** — is **derived per project at scaffold time** from that
project's own planning artifacts, **confirmed with a human in one question**, and
then **captured in a `manual-outline.yaml` the project owns**. The module supplies
the procedure and the schema; the project supplies the structure.

Why: a documentation framework that ships a fixed IA forces every product into one
domain shape. A SaaS billing platform, a CLI tool, and a data pipeline do not share
top-level sections. The doc-types they use (prd, architecture, adr, runbook,
glossary, …) are the same; the *audience-facing sections* that organise those
doc-types are the product's own. We derive the sections; we never presuppose them.

---

## 1. Inputs to the derivation

The derivation reads what the project has already produced during planning. It is a
**read**, not a generation from nothing — the IA falls out of the work the team
already did.

| Input | What the derivation takes from it |
|---|---|
| **Product brief** | The product's reason to exist, audiences, and commercial shape → candidate audience-facing sections (e.g. a "Product" section for PM/stakeholder narrative). |
| **PRD** | Feature surfaces and capability groupings → candidate functional sections and the doc-types that hang under them. |
| **Architecture** | The system's structural decomposition (control plane / runtime / pillars / services) → candidate engineering- and architecture-facing sections. |
| **Domain model / glossary** | The product's nouns and their groupings → reference-section shape and naming language. |
| **UX spec / personas** | The distinct reader audiences → confirms *audience* as the organising axis where it fits, and seeds persona/UX-spec placement. |
| **Universal doc-type catalog** (`taxonomy.md` §4) | The fixed set of leaf node types each section will contain. Sections are **containers**; doc-types are the **contents**. |

If a project has not yet produced a given input, the derivation proceeds from what
exists and the confirmation question (§3) surfaces the gap rather than inventing
structure to fill it.

---

## 2. The derivation procedure (what `manual-scaffold` runs)

The scaffold derives sections by **reading the planning artifacts and grouping the
project's doc-types by the audiences and surfaces those artifacts reveal** — then
proposing a section list, never asserting one.

```
STEP 1 — READ the planning artifacts
  └─→ Pull brief, PRD, architecture, domain/glossary, UX/personas
      (via doc-read-first, status-filtered to canonical where present).
      If a manual already exists, read its current tree too (re-run case, §4).

STEP 2 — EXTRACT the organising axes
  └─→ From the artifacts, identify:
        a) the distinct READER AUDIENCES (PM, integrator, architect, SRE,
           implementer, everyone) the product actually has;
        b) the major SURFACES / capability groupings the product exposes.
      These axes are observed in the artifacts — not chosen from a menu.

STEP 3 — MAP doc-types onto candidate sections
  └─→ For each universal doc-type the project will use (taxonomy.md §4),
      place it under the audience/surface section it serves. A doc-type may be
      MANY-TO-ONE mappable: e.g. `research` files under a Product section
      (market/domain research) OR an Architecture section (technical research),
      decided by the research subject. Diataxis mode is a WITHIN-section content
      lens (§6), not a section axis.

STEP 4 — PROPOSE the section list (draft manual-outline.yaml)
  └─→ Emit a candidate `manual-outline.yaml`: root + ordered sections (key, title,
      icon, importance) + each section's children (the mapped doc-types as leaf
      pages). Status of every node starts `draft`. NOTHING is created yet.

STEP 5 — CONFIRM with the human (P3: ONE plain-English question)
  └─→ Present the proposed section list as a single question, e.g.:
        "I derived these sections for the {project} manual from its brief, PRD and
         architecture: <list>. Apply this structure, or adjust?"
      The human accepts, reorders, renames, or adds/drops a section. This is the
      ONLY gate; it is frictionless because a human is already present at scaffold.

STEP 6 — CAPTURE the confirmed outline as a project-owned artifact
  └─→ Write the confirmed `manual-outline.yaml` into the PROJECT's repo/space.
      It is a GENERATED, project-owned artifact from here on — the module never
      ships it and never overwrites it without re-deriving + re-confirming.

STEP 7 — APPLY idempotently
  └─→ docmost-cli page tree apply <flat-nodes-file>
      The CLI takes the node list as a POSITIONAL <file> (there is no --outline flag)
      and consumes a FLAT top-level list of nodes, each with
      {title, icon, status, doc_type, content, children} (children recurses). It does
      NOT understand the manual:{root, sections} wrapper this file's schema defines,
      nor the section-only fields key/importance/scaffold. So `manual-scaffold` first
      TRANSFORMS manual-outline.yaml into that flat node list (root → one top node;
      each section → a child; each section's children → straight across), then applies
      the flat file positionally. See doc-librarian Step 7 for the exact transform.
      Creates the tree on first run; on every re-run it MATCHES existing pages by
      title under parent (case-sensitive) and UPDATES IN PLACE — it never re-creates
      (P1: no v2 sprawl). Rename-safe key-matching is PENDING.
      `--on-existing` controls reuse on a sibling-title hit: skip (DEFAULT, reuse +
      recurse, content untouched) | update (overwrite content) | recreate (= update).
```

The procedure produces structure; it does not author page bodies. Bodies are filled
later by `doc-amend` (find-before-create, draft) and promoted by `doc-ratify`.

---

## 3. The confirmation gate (P3) is mandatory and singular

No derived IA is applied without human confirmation, and the confirmation is **one
question** (P3: update-by-default, ask-when-ambiguous). The scaffold:

- proposes the full section list in a single message;
- shows what each section will contain (the mapped doc-types);
- accepts a plain-English adjustment and re-emits the outline;
- applies only after the human confirms.

The human owns the section names, icons, order, and importance. The module owns the
*procedure* that proposes them and the *schema* that captures the answer.

---

## 4. Re-running on an existing manual (idempotent, update-in-place)

When the project's planning artifacts evolve, re-run the scaffold. The derivation
re-reads the artifacts AND the existing manual tree, and proposes a **diff** against
the current `manual-outline.yaml` (sections added / renamed / reordered / removed),
confirmed again in one question.

`docmost-cli page tree apply` then reconciles (matching by **title under parent**,
case-sensitive — see below):

- a section/page whose **title** already exists under the same parent is **reused/updated
  in place** — never duplicated; `--on-existing` decides whether content is overwritten
  (`skip` default = reuse + recurse, content untouched; `update` = overwrite; `recreate`
  = same as update);
- a new title creates a new node;
- a removed node is **not** auto-deleted — removal flows through the supersede/archive
  path (P5: whole-doc to archive only), surfaced as a flag, never silently dropped.

This is the P1-critical property: re-derivation refines the same tree; it never
spawns `manual-v2`.

> **Matching is by TITLE under parent (case-sensitive); rename-safe `key`-matching is
> PENDING.** The schema's `key` field is the *intended* stable IA identifier, but the
> CLI does not yet match on it — it matches on title under the parent. So renaming a
> node's title currently breaks the match (the renamed node looks new and a duplicate
> would be created). Until key-matching ships, keep section/leaf titles stable across
> re-applies, or route a rename through `manual-supersede`.

---

## 5. ONE WORKED EXAMPLE — a derived IA (hypothetical, illustrative)

> **This is illustrative, not a template.** The structure below is a *hypothetical*
> project's derived manual IA — shown only so you can see what a *derived* outcome
> looks like and the framing it should carry. The sections are that imagined product's
> domain structure, **not a shipped default**. A different project derives a different
> set. Do not copy these sections into another project's `manual-outline.yaml`.

Imagine a small consumer app. From its own brief / PRD / architecture, the derivation
might yield top-level sections like these (each becomes a page under the manual root):

| Section (this project's own) | Icon | Derived from | What it contains there |
|---|---|---|---|
| Product | 🎯 | product-brief, PRD, market research | what it is, who it's for, the commercial shape |
| Using it | 📚 | UX spec, user-guide | the user-facing knowledge surface |
| Architecture | 🏛 | architecture, ADRs, technical research | how it's built |
| Operations | 📊 | runbooks, release-notes | how it runs — deploy, environments, day-2 |
| Reference | 📖 | glossary, ADR index | lookup — glossary, decisions, pointers |

The point of the example is the **shape of the output and the framing** — every section
traces to real artifacts — not the section names or their number. A good manual root
states its own conventions; aim for framing like:

- **In short** lead (the inverted-pyramid `tldr`): a one-paragraph statement of what the
  project is and why every other doc and code change flows from here.
- **Drill-down**: each section is its own page; each drills down again; read at any
  depth (progressive disclosure, P7).
- **Bit by bit**: new content lands as drafts; a human ratifies it one question at a
  time (P3, draft→canonical).
- **Outranks everything**: the manual outranks the PRD, the brief, the code.
- **Amend, never overwrite**: canonical pages change only via amend; old versions live
  in page history (P1 + P4).

A newly-scaffolded manual reproduces this *framing* (story-first root, in-short lead,
how-this-works callout) on whatever sections the project itself derives.

---

## 6. Doc-types are the building blocks; Diataxis is a within-section lens

Two axes that are easy to conflate — keep them separate:

- **Doc-type (the building block).** The universal catalog in `taxonomy.md` §4
  (product-brief, prd, architecture, adr, technical-spec, api-reference, runbook,
  retrospective, release-notes, glossary, project-overview, feature-inventory,
  contract, ux-spec, trigger-map, persona, user-guide, research, brainstorm). These
  are fixed and universal. They are the **leaf nodes** of any manual. A section is a
  named container that groups doc-types for one audience or surface.

- **Diataxis mode (the lens).** Tutorial / how-to / reference / explanation is a lens
  on **how a page is written**, applied *within* a section to its doc-types. It is
  **not** a section axis and never names a section. A "Reference" section may hold
  explanation-mode concept pages and reference-mode tables alike; an "Architecture"
  section is dominantly explanation but holds reference too. Choose the mode per page;
  choose the section per audience/surface.

So: the module ships universal **doc-types**; the project derives **sections** to
hold them; each **page** picks a Diataxis **mode**. Only the first is fixed.

---

## 7. What is fixed vs derived — the summary

| Concern | Fixed by the module | Derived per project |
|---|---|---|
| The 7 principles (constitution) | ✅ shipped | — |
| Universal doc-type catalog | ✅ shipped | — |
| `manual-outline.schema.yaml` (the schema) | ✅ shipped | — |
| Scaffold + `page tree apply` mechanics | ✅ shipped | — |
| Section list / names / icons / order | ❌ never | ✅ derived from artifacts, confirmed by human |
| `manual-outline.yaml` (the filled outline) | ❌ never shipped | ✅ generated, project-owned |
| Which doc-types appear and where | ❌ never | ✅ mapped during derivation |
| Diataxis mode per page | ❌ never | ✅ chosen per page (within a section) |

If you ever find yourself reading a fixed seven-section skeleton as "the default,"
you are reading an example out of context. The module's default is **no sections** —
only a procedure for deriving them.
