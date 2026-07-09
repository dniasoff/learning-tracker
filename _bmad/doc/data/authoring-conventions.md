# Authoring conventions — the house style

> Scope: the micro-conventions that make our wiki pages cohesive and tech-writer-grade. Reverse-engineered from the canonical exemplar tree (the **linear-cli Delivery** program, space `linearcli`, hub `h8hL6peY5Y` + its 13 milestone children, plus the canon spec pages `ngQFzNgFmD` Architecture and `6OaGmQJg9g` PRD).
> Companion files: `rich-page-authoring.md` (embed mechanics), `citations-and-crosslinks.md` (links & sources).
> These are **conventions, not a straitjacket.** Apply the register that fits the doc-type. A dashboard/hub looks different from an architecture spec, which looks different from a user-facing landing — but all three share the emoji legend, the tone discipline, and the cross-link spine below.

Read a rich page the faithful way before imitating it: `docmost-cli page mirror pull <dir> --space <slug> --slug <id>` (see the embed-read landmine in `rich-page-authoring.md` §0).

---

## 1. The header-card callout (every milestone / dashboard / status page)

A page opens with **one `:::info` callout — not an H1** (the page title is the H1). It doubles as a metadata bar + breadcrumb so all metadata is *visible in the body*, not hidden in front-matter. Structure inside the callout:

```
🌊 **Issue command surface** · Milestone 2 of 13 · Wave A · spec [ENG-442](<linear-url>) · 🎯 2026-06-20 · 24 issues
One-sentence scope of this page.
Canon: [PRD](<url>) · [Architecture](<url>) · [Contracts](<url>) · [Command Reference](<url>)
↑ Part of [linear-cli Delivery](<hub-url>) — the program dashboard.
```

- **Line 1** — leading semantic emoji + **bold title** + a `·`-separated metadata bar (see §2).
- **Line 2** — the scope in one dense sentence.
- **Line 3** — the `Canon:` row (see `citations-and-crosslinks.md`).
- **Line 4** — the `↑ Part of …` upward breadcrumb to the parent hub (omit on the hub itself).

Author it: `docmost-cli page block callout <slug> --op prepend --type info --content @header.md`.

---

## 2. The `·`-separated metadata bar

One line, fields joined by **space-middot-space** (` · `). Fixed order for a milestone-style page:

`<emoji> **<name>** · Milestone N of M · Wave X · spec ENG-NNN (linked) · 🎯 YYYY-MM-DD · N issues`

It replaces a metadata table. Glyph conventions:
- `🎯` always prefixes a **target/due date**.
- The leading **wave emoji** classifies the item (see §3).

---

## 3. Emoji heading legend (controlled vocabulary)

Section headings begin with a **consistent semantic emoji** — a legend the reader learns once. Reuse the same emoji for the same concept across every page:

| Emoji | Meaning |
|---|---|
| `🖥️` | product / dashboard charter (hub title) |
| `📊` | program status / metrics |
| `🗺️` | roadmap |
| `🗂️` | issues / work list / "all work" rollup |
| `✅` | Definition of Done / acceptance gate |
| `🧱` | Wave 0 / foundation |
| `🌊` | a delivery wave (A / B — parallel build) |
| `🏁` | the finale wave |
| `🎯` | a target/due date (inline, in the metadata bar) |

Headings carry **descriptive text, not bare nouns** (`## 📊 Program status`, not `## Status`).

---

## 4. Delegate status to live embeds — never hand-type it

Progress/status is shown with **live Linear embeds**, not typed prose:
- `:::linear-graph type=status_distribution …:::` under a `## 📊 …` heading for progress.
- `:::linear-project:::` under a `## 🗂️ Issues` heading for the authoritative, never-hand-maintained work list.
- A hub repeats one `linear-graph` per wave section so each wave has its own live bar.

Scope a per-milestone graph to its own issues with `--filter '{"projectMilestone":{"id":{"eq":"<milestone-uuid>"}}}'` (the milestone UUID comes from `page get <slug> --field uuid` / the meta sidecar) rather than reusing one team-wide graph. See `rich-page-authoring.md` §2 (Linear) and §4 (live vs static).

---

## 5. The Definition-of-Done gate (template invariant)

Every milestone page closes with a `## ✅ Definition of Done` heading + a **GFM checkbox task list** that is verbatim-constant across siblings except item 1 (parameterized with the issue count). This is a fill-the-template discipline: generate sibling pages from one parameterized template (see `doc-type-templates/milestone.md`), varying only the metadata-bar values, the one-sentence scope, and the DoD count — never free-author each.

---

## 6. Colored mermaid conventions

Mermaid is hand-colored to encode meaning, never left default (see `rich-page-authoring.md` §3 for when to use Mermaid vs Excalidraw):
- **Per-node:** `style <id> fill:#hex,stroke:#hex,color:#hex` — e.g. `style F fill:#fdd,stroke:#c00` (red = error/violation path), `style H fill:#dfd,stroke:#070` (green = success/exit).
- **Semantic groups:** `classDef boundary fill:#1f6feb,stroke:#0b3d91,color:#fff` + `class R,RA boundary` to color a whole role-group one colour (blue = trust boundary, green = safe sink).
- Pick the grammar by intent: `flowchart TB` with `subgraph … end` clusters + `<br/>` multi-line labels for layered architecture; `graph TD` for hierarchies; `sequenceDiagram` with `autonumber`/`participant … as`/`Note over`/`par … end` for flows.
- **Keep style lines when simplifying** — dropping them ships an uncoloured diagram.

---

## 7. Table idioms

- **Titled comparison tables** (dense technical tables — package maps, error-code registries, exit-code tables): render with a deliberately **blank leading header row** (`|  |  |  |`) then the real column-title row as the first data row. This styles the title row as bold body text rather than the default header treatment. Add a second blank row for spacing where a section wants air.
- **Benefit-framed catalogs** (user-facing landings): a literal two-column `| Feature | What it means for you |` shape, every capability translated into a plain-language user outcome.

---

## 8. Self-describing spec / architecture register

Canon spec pages (`architecture`, `technical-spec`, `prd`) open with:
1. An H1, then
2. A blockquote front-matter block that names the page's own wiki coordinates:
   ```
   > **Scope.** …
   > **Status.** Published to space `linearcli`, page `<slugId>` (doc_type: architecture, child of root `<slug>`), status **draft** pending ratification.
   > **Companion sources.** …
   ```
3. A numbered `## Table of contents` mirroring the H2 order, then `---` rules between major sections.

Blockquotes (`> **Label.** …`) are the **light callout register** for inline asides (scope/status notes, "the lesson" sidebars) inside dense technical prose — distinct from the heavyweight `:::` callout blocks.

---

## 9. Tone — graded by register

Three registers, deliberately separated:
1. **Banner / hub:** terse, punchy, em-dash-joined declaratives ("one binary, one contract, one cache"; "red = not done, no human override"). Compress each scope into one dense sentence.
2. **Architecture / PRD:** precise engineering prose; cite authority with inline commit SHAs (`` (lesson `ab24e35`) ``); "baked-in, not aspirational" framing; parenthetical rationale.
3. **User-facing landing:** warm second-person benefit prose ("what it means for you"); every feature reframed as an outcome; zero jargon.

Across all registers: **bold** load-bearing/contract terms; wrap **every** identifier, flag, errorCode, path, and entity name in `code spans` (never paraphrase them).

---

## 10. Sibling uniformity

When a set of pages are instances of one archetype (milestones under a hub, ADRs under a decision index, release-notes versions under a landing), they are **byte-for-byte structurally identical**, varying only in their parameterized fields. Generate them from one template; do not free-author each. This is what makes a tree feel cohesive at a glance.
