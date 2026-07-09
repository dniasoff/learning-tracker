# Page pattern — program delivery (hub + milestone)

> Scope: copy-paste skeletons for a **program dashboard hub** and its **milestone children**, reverse-engineered from the canonical exemplar (linear-cli Delivery, hub `h8hL6peY5Y`). This is a *composition pattern applied to existing doc-types* (e.g. a `project-overview`/section-landing hub + milestone tracking pages) — **not** a new doc_type (skills never coin doc_types; see `taxonomy.md` §4).
> Companion: `authoring-conventions.md` (the conventions these skeletons embody), `rich-page-authoring.md` (embed mechanics + the embed-read landmine).
> Aligns with Linear's no-epics structure: a **hub ≈ a Linear project/initiative**, a **milestone page ≈ a Linear project-milestone**, **waves** group milestones by dependency, **cycles** time-box. Status is shown with **live Linear embeds**, never hand-typed.

Build each block with `docmost-cli page block …`. Author embeds with `page block` (they carry args); never reconstruct them from mirrored markdown (embed-read landmine).

---

## A. The hub (program dashboard)

**Header card** (`page block callout <hub> --op prepend --type info --content @hub-header.md`):

```
🖥️ **<Program> Delivery** — <one-line mission>.
<Invariant / contract sentence, bolded stakes — e.g. **one binary, one contract, one cache**.>
Canon: [PRD](<url>) · [Architecture](<url>) · [Contracts](<url>) · [Command Reference](<url>)
```

**Then:**
1. `## 📊 Program status` → `page block linear_graph <hub> --type status_distribution --team-id <uuid>` (the program-wide live progress bar).
2. `## 🗺️ Roadmap by dependency wave` → a framing sentence (same-wave milestones run in parallel; contract freezes after Wave 0), then one `### <wave-emoji> Wave N — <tagline>` per wave (`🧱` Wave 0 / foundation, `🌊` Wave A/B / parallel build, `🏁` Wave C / finale). Under each wave: its own `page block linear_graph … --type status_distribution --filter '{"projectMilestone":{"id":{"eq":"<milestone-uuid>"}}}'` and a `task_list` of that wave's milestones — each row `- [ ] <Name>  ·  🎯 <date>  ·  <N> issues  ·  spec <ENG-id>` (link the milestone name down to its child page).
3. `## 🗂️ All work` → `page block linear_project <hub> --project <slug>` (the program rollup).

The hub omits the `↑ Part of` backlink (it is the top).

---

## B. A milestone child (one per Linear project-milestone)

All milestone children are **byte-for-byte structurally identical**, varying only in the parameterized fields. Generate them from this skeleton; do not free-author each (`authoring-conventions.md` §10).

**Header card** (`page block callout <milestone> --op prepend --type info --content @ms-header.md`):

```
🌊 **<Milestone name>** · Milestone <N> of <M> · Wave <X> · spec [ENG-NNN](<linear-url>) · 🎯 <YYYY-MM-DD> · <N> issues
<One-sentence scope.>
Canon: [PRD](<url>) · [Architecture](<url>) · [Contracts](<url>) · [Command Reference](<url>)
↑ Part of [<Program> Delivery](<hub-url>) — the program dashboard.
```

**Then:**
1. `page block linear_graph <milestone> --type status_distribution --team-id <uuid> --filter '{"projectMilestone":{"id":{"eq":"<milestone-uuid>"}}}'` — this milestone's live progress (scoped to its own issues).
2. `## 🗂️ Issues` → `page block linear_project <milestone> --project <slug>` (or a `linear_view` filtered to the milestone) — the authoritative, never-hand-maintained work list.
3. `## ✅ Definition of Done — the hard E2E gate` → `page block task_list <milestone> --items @dod.json`. Item 1 is parameterized with the issue count; items 2–5 are the verbatim-constant gate:

```json
[
  {"text": "All <N> issues ship as a passing live E2E", "checked": false},
  {"text": "Comprehensive E2E gate green", "checked": false},
  {"text": "Red gate = not done — no human override", "checked": false},
  {"text": "Contract conformance / golden-file check passes", "checked": false},
  {"text": "Secrets never leak — CI-scanned", "checked": false}
]
```

---

## Parameterized fields (the only things that vary per milestone)

`name`, `milestone N of M`, `wave (X + emoji)`, `spec ENG-NNN`, `target date`, `issue count`, `one-sentence scope`, `milestone-UUID` (for the graph `--filter`; from `page get <slug> --field uuid`), `linear project slug`. Everything else is the template.

## After authoring
- Verify it renders: `docmost-cli verify render <slug>` (or `screenshot shot /s/<space>/p/<slug> -O out.png --settle 3s --full-page`). Live Linear embeds disappear from `page get` — confirm via `mirror pull` + the screenshot, not `page get`.
- Link it in (`citations-and-crosslinks.md`): the hub roadmap links down to it; it carries the `↑ Part of` backlink up.
