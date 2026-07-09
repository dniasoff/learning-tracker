# Rich page authoring — embeds, diagrams & composition

> Scope: how a skill turns a flat-markdown page into a **rich, render-correct** Docmost page using the `docmost-cli page block` surface. Loaded by the authoring skills (`doc-amend`, `doc-research`, `doc-consolidate`, `doc-librarian`).
> Companion files: `authoring-conventions.md` (house style — header cards, emoji legend, tone), `citations-and-crosslinks.md` (linking & sources), `docmost-cli-reference.md` (the full CLI surface).
> Canonical worked exemplar: the embeds masterclass page — `docmost-cli page get FVupOILu34` (route `/s/docmostcli/p/FVupOILu34`). Read it once; it renders 22 embeds live.

This is the file that makes **P7** ("a picture before dense prose, a concrete example for every concept") real. P7 is not satisfiable with prose alone — reach for the right block.

---

## 0. THE EMBED-READ LANDMINE (read this first)

Embeds are ProseMirror nodes, **not** markdown. This has three consequences that bite every skill that touches a rich page:

1. **`page get` silently drops embeds** — *including `page get --output json`* (the `content` field is already-flattened markdown, not ProseMirror). A page full of mermaid / callouts / Linear cards comes back as **empty `##` section headers** with the embeds gone, and inline link URLs stripped to bare text. Verified: the masterclass page shows 64 embed/fence lines via `mirror pull` but only 21 via `page get`.
2. **`page mirror pull` is the only faithful read.** It writes `<slug>.md` with the `:::info`, ```mermaid, `:::linear-graph type=… team-id=… :::` fences intact, plus a `<slug>.meta.yaml` sidecar. **Always `mirror pull` before auditing, amending, or drift-checking a page that has (or might have) embeds.**
3. **`mirror push` is itself LOSSY for embeds.** It strips embed arguments — a `:::linear-project:::` fence pushed back loses its `--project`, a `linear_graph` loses its `--filter`/`--team-id`, an excalidraw loses its baked state. **Never reconstruct an embed by editing mirror markdown and pushing.**

### The rules that follow

- **Read** a rich page → `page mirror pull` (never trust `page get` for embed content).
- **Author or repair** an embed → `page block <type>` (it carries the args; the server stores a real node).
- **Edit prose around embeds** via mirror is fine; **edit the embeds themselves** is not — touch them only through `page block`.
- A page with empty-looking `##` headers in `page get` is almost always **full of embeds**, not empty. Confirm via `mirror pull`.

---

## 1. The `page block` surface

```bash
docmost-cli page block <type> <slug> [type-flags] [universal-flags]
docmost-cli pb <type> <slug> ...          # `pb` is the alias
```

**Universal flags on every block subcommand:**

| Flag | Meaning |
|---|---|
| `--op append\|prepend\|replace-at\|insert-at` | placement (default `append`) |
| `--if-version <updated_at>` | CAS guard — **default-on** for scripted writes (auto-read from cache); `--no-cas` opts out (skills never pass `--no-cas`) |
| `--dry-run` | print the ProseMirror-JSON node, make **no** API call (preflight any block) |
| `--output human\|json\|yaml` / `--json` | receipt format |

Content sources (where a block takes a body/diagram): a literal string, `@<file>`, or `@-` (stdin).

**Discover the catalog programmatically — do not hardcode a stale list:**

```bash
docmost-cli instructions embeds                 # all 28 types, 9 families
docmost-cli instructions embeds <type>          # one type: CLI form + markdown fence + notes
docmost-cli instructions embeds --output json   # machine-readable catalog
```

**Delete a block:** `docmost-cli page block rm <slug> --block-id <uuid>`.

---

## 2. The catalog — 28 types, 9 families

### Diagrams (3) — see the diagram policy in §3
- `mermaid` — flowchart/sequence/class/state/ER/gantt/pie. Renders hand-drawn + coloured, deterministic layout, **arrows always connect, no bake**. `--diagram @flow.mmd`.
- `excalidraw` — editable whiteboard seeded from Mermaid DSL. **Needs a human bake** (§3). `--diagram @flow.mmd`.
- `drawio` — draw.io/mxGraph from Mermaid DSL. Same fragility as excalidraw on multi-node graphs.

### Callout (1)
- `callout --type info|success|warning|danger --content <text|@file>` — coloured emphasis box. info = context/orientation, success = shipped/done, warning = caveat, danger = destructive/blocked. Renders as `:::info … :::`.

### Inline (1)
- `status --label "In Review" --color gray|blue|green|yellow|red|purple` — inline coloured pill inside a line of text.

### Math (2)
- `math_block --latex '\int_0^1 x^2\,dx'` — display LaTeX (KaTeX). In shell, double-escape backslashes or use `@file`.
- `math_inline --latex 'e^{i\pi}+1=0'` — inline LaTeX span.

### Media (5)
- `pdf --upload report.pdf | --attachment <uuid> [--page N]` — native PDF viewer.
- `video --upload clip.mp4 | --attachment <uuid>` — native video player.
- `audio --upload sound.mp3 | --attachment <uuid>` — native audio player.
- `attachment --upload spec.zip | --attachment <uuid>` — file as a download chip.
- `image_from_prompt --prompt "…" [--size 1024x1024]` — AI-generated image (needs an image model in the workspace LiteLLM; equivalent to `ai image generate --page`).

### External embeds (1)
- `embed --url <url> [--theme dark]` — Loom / Figma / Miro / YouTube / Vimeo / Airtable / Typeform / Framer / Google Drive / Sheets / any iframe (provider auto-detected).

### Structure (4)
- `columns --layout two_equal|two_left_sidebar|two_right_sidebar|three_equal|three_left_wide|three_right_wide|three_with_sidebars|four_equal|five_equal --columns '["# Left…","# Right…"]'` — column **count in the JSON array must match the layout**. Use for before/after, option A/B.
- `details --summary "Advanced" --content <text|@file>` — collapsible disclosure (hide long API recipes / appendices / FAQ bodies).
- `subpages [--parent-id <uuid>]` — auto-listing of child pages; keeps an index page self-updating.
- `transclusion --src <src-slug-or-uuid> [--range h1]` — embed another page's **live** content inline (server enforces cycle detection). The single-source-of-truth primitive.

### Linear (8) — live unless noted; gate on `workspace integrations linear`
- `linear_issue --identifier ENG-433 [--issue-id <uuid>] [--expanded]` — issue card (self-fetches; snapshot null).
- `linear_mention --identifier ENG-123 [--display-mode identifier-status]` — inline issue pill. **Bakes a snapshot.**
- `linear_project --project <slug>` — project card (status/progress/lead/live counts; self-fetches).
- `linear_dashboard --project <slug> --window 90` — project burndown + scope over a window.
- `linear_cycle --cycle <id>` — sprint progress + in-flight issues.
- `linear_roadmap --roadmap <uuid>` — initiatives + their projects.
- `linear_view --view-id <uuid> [--filter '<IssueFilter>']` — live filtered issue list. **Reuse one base view across pages by AND-combining a per-embed `--filter`.**
- `linear_graph --type status_distribution|throughput|burndown|lead_time_histogram|cycle_progress|project_health [--team-id <uuid>] [--date-range 7d|14d|30d|90d] [--filter '<IssueFilter>']` — **the one embed that must be created+baked**: the server computes the series and the CLI bakes the returned snapshot into the node. Without the snapshot it **renders blank** (the #1 Linear gotcha). Required filters: `burndown`/`cycle_progress` need a cycle; `lead_time_histogram` needs a team; the rest are org-wide or scoped by `--team-id`/`--filter`. Distinct filters → distinct graphIds, so one base graph is safely reused per page (scope a milestone with `--filter '{"projectMilestone":{"id":{"eq":"<uuid>"}}}'`).

### Tabular (3)
- `table --headers A,B,C --rows @rows.csv|@rows.json` — GFM table. Ragged rows (column count ≠ headers) rejected client-side.
- `task_list --items @tasks.json` — checkbox list, JSON `[{"text":"…","checked":false,"children":[…]}]` (nested ok; text ≤ 500 chars).
- `chart --type bar|line|pie|scatter --data @data.json --title "…"` — **STATIC** (JSON baked in). For live, auto-refreshing data use a `linear_graph`, not `chart`.

---

## 3. Diagram policy (DECISION — follow exactly)

We want the hand-drawn, coloured sketch aesthetic. Two paths, chosen by complexity:

### Default for SIMPLE diagrams → coloured **Excalidraw** (with a tracked bake step)

A "simple" diagram is **≤ ~3–4 nodes, mostly linear, light arrow routing**. Author it as Excalidraw:

```bash
docmost-cli page block excalidraw <slug> --diagram @sketch.mmd
```

Colour comes from the Mermaid `style`/`classDef` lines in the source DSL (Excalidraw is seeded from Mermaid DSL).

**Excalidraw needs a human bake.** An agent-authored Excalidraw renders **blank** until a human opens the block and clicks **Save & Exit** once; re-authoring the page **wipes** that bake. So **every time a skill authors an Excalidraw (or drawio) block it MUST also leave a tracked bake step:**

1. Place an adjacent warning callout so the human knows what to do:
   ```bash
   docmost-cli page block callout <slug> --type warning --op insert-at \
     --content "🖋️ **Unbaked diagram.** Open the diagram above and click **Save & Exit** once to bake it — it renders blank until then, and re-authoring the page wipes the bake. Delete this note after baking. [bake-pending]"
   ```
   The `[bake-pending]` sentinel is machine-greppable.
2. The page is **not promotable**: `doc-ratify` runs `verify render <slug>` (an unbaked Excalidraw fails the component-render assertion) and/or greps for `[bake-pending]`, and surfaces it as a **required human task** before any draft→canonical promotion. The human bakes the diagram, removes the warning callout, then ratifies.

### Anything COMPLEX / multi-node / must-render-unattended → coloured **Mermaid**

```bash
docmost-cli page block mermaid <slug> --diagram @flow.mmd
```

Mermaid renders **hand-drawn + coloured automatically** (the server pins the look), with **deterministic layout so arrows always connect, and no bake step**. Use it whenever:
- the diagram has more than ~3–4 nodes or any non-trivial arrow routing (**Excalidraw/drawio arrow-routing detaches — edges float into empty space — on any multi-node graph**), OR
- nobody will open the page promptly to bake an Excalidraw, OR
- the page must be render-correct the instant it ships (CI, automated drift refresh).

Colour Mermaid with per-node `style <id> fill:#hex,stroke:#hex,color:#hex` or semantic classes (`classDef boundary fill:#1f6feb,stroke:#0b3d91,color:#fff` + `class R,RA boundary`). **Keep the style lines when simplifying a diagram** — dropping them is the #1 way agents ship uncoloured diagrams.

> Rule of thumb: **simple sketch a human will see → coloured Excalidraw + bake step. Real flowchart / unattended / many nodes → coloured Mermaid.** When unsure, Mermaid is the safe choice (it always renders).

---

## 4. Composition — what makes a page *rich*

A rich page is layered, not a wall of prose. The recipe demonstrated by the masterclass:

1. **Open with a callout** — `info` for orientation / a `tldr` lead, `warning`/`danger` for caveats.
2. **Use a coloured diagram for any process or architecture** — Excalidraw (simple) or Mermaid (complex), per §3. Red = problem/error path, yellow = in-progress, green = done/success.
3. **Put before/after or option-A/option-B side by side** with a `columns` block.
4. **Summarise structured facts in a `table`**; track work with a `task_list`.
5. **Hide long API/detail bodies under `details`** so the page scans fast.
6. **Math** where it earns its place (`math_block`/`math_inline`).
7. **Close with a `success` callout** (sign-off / "what this unlocks").

### Live vs static — choose deliberately
- **Live** (refreshes on view): `linear_graph`, `linear_view`, and the Linear cards. Use these for any status / progress / roadmap / sprint surface — never hand-type a status that a Linear embed can show live.
- **Static** (baked at author time): generic `chart`, `table`, `task_list`. Use only when the data is genuinely a fixed historical snapshot.
- `linear_graph` and `linear_mention` **bake a snapshot** (graph renders blank without it); the other Linear cards self-fetch (`snapshot: null`).

### Single source of truth
Write a fact **once** on a canonical page, then `transclusion --src` it into every consumer (edit-once-updates-everywhere). Make index/hub pages self-maintaining with a `subpages` block instead of hand-listing children. This is the wiki-first composition layer that keeps the corpus DRY (and is the mechanism behind the supersession transclusion safeguards).

---

## 5. Verify-render workflow (load-bearing)

After authoring **any** diagram or embed, confirm it actually renders before trusting it:

```bash
# Component assertions in headless Chromium (preferred for skills):
docmost-cli verify render <slug> --screenshot /tmp/page.png

# Or a raw screenshot — NOTE the FULL route, not a bare slugId:
docmost-cli screenshot shot /s/<space>/p/<slug> -O /tmp/page.png --settle 3s --full-page
```

- The screenshot route is the **full `/s/<space>/p/<slug>` form**. A bare slugId (e.g. `FVupOILu34`) returns the Docmost 404 page.
- `--settle 3s` waits out chart entry-animations (~1.5s) so charts/graphs aren't captured blank; `--full-page` captures the whole scroll height.
- A **blank** screenshot almost always means bad/expired auth, not a render failure.
- Confirm **boxes AND arrows** render. If an Excalidraw/drawio diagram has floating, detached arrows → it was multi-node; switch that block to **Mermaid**.
- If a `linear_graph` is blank → its snapshot wasn't baked; re-author it (the CLI bakes the series).
- An **unbaked Excalidraw** is the expected state until a human bakes it (§3) — that is the one render "failure" that is a human task, not a re-author.

---

## 6. Quick chooser

| You want to show… | Use |
|---|---|
| A process / architecture flow (real, multi-node) | `mermaid` (coloured) |
| A tiny hand-drawn sketch a human will see | `excalidraw` (coloured) + bake step |
| A warning / context / sign-off | `callout` (warning / info / success) |
| A lifecycle/state pill in a sentence | `status` |
| Structured facts / a comparison matrix | `table` |
| A checklist / acceptance criteria / rollout steps | `task_list` |
| Fixed historical data | `chart` (static) |
| **Live** project/sprint/roadmap status | `linear_graph` / `linear_view` / `linear_project` |
| Before/after or option A vs B | `columns` |
| A long appendix / API recipe to hide | `details` |
| A fact reused on many pages | `transclusion` (+ `subpages` for indexes) |
| A formula | `math_block` / `math_inline` |
| A file / video / PDF | `attachment` / `video` / `pdf` |

## 7. Embeds by doc-type (nudges)

When amending/authoring a page of a given `doc_type`, reach for these:

| doc_type | Reach for |
|---|---|
| `architecture`, `technical-spec`, `platform-design` | coloured **mermaid** (system/sequence/state); blank-header comparison tables; `details` for long internals |
| `prd` | `task_list` for acceptance criteria; live `linear_view`/`linear_project` for delivery status; `callout` for scope/risk |
| `runbook` | `task_list` for the procedure; `callout --type danger` for destructive steps; `mermaid` for the flow |
| `release-notes` | `table` of changes (or `status` badges per change); Linear mention links to shipped issues; page mentions to PRDs/ADRs |
| `retrospective` | `columns` (what-went-well / what-didn't); `task_list` for action items |
| `research` | `table`/`chart` for evidence comparison; `transclusion` of source facts; a `## Sources` section (`citations-and-crosslinks.md`) |
| `adr` | `mermaid` for the decision/option graph; `callout` for the status; `columns` for alternatives |
| section landing / `project-overview` | `subpages` card grid; `callout` tldr lead; the program-delivery hub pattern (`page-patterns/program-delivery.md`) |
| any dashboard / status page | live `linear_graph`/`linear_project`/`linear_view` — never a static `chart` for live data |
