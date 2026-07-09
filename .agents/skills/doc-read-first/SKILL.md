---
name: doc-read-first
description: "Resolve a read against the project's living manual node (root + IA path) before falling back to a local file. Use when reading a planning artifact, or in spec mode to fetch the confirmed intent node for a story. Excludes draft/superseded/archived from grounding reads."
---

# doc-read-first

When you are about to read a planning artifact (PRD, product brief, UX spec, architecture, ADR, runbook, research, brainstorm, or any durable doc-type), run this resolver first. The manual is authoritative; a local file is the fallback.

This resolver does **not** do a loose title-stem search. It resolves against the **living manual node** — the manual root plus the project-derived IA path — so a read lands on the one canonical page for the concept, not whichever page happens to share a word with the filename.

## Pre-conditions

Before any wiki call, verify the CLI is present and authenticated:

```bash
which docmost-cli || { echo "NOTE: docmost-cli not on PATH — falling back to local file"; exit 0; }
docmost-cli auth status --output json
```

If `docmost-cli` is absent, log a NOTE and proceed with the local file. If auth status is non-zero, tell the user to run `docmost-cli auth login --instance <url> --token <api-key>` and halt.

## Step 1 — Read config

Resolve `{project-root}/_bmad/doc/config.yaml` to get:

- `docmost_space` — the space slug for this project's manual (docmost-cli resolves it to a UUID on demand).
- `docmost_manual_root_slug` — the manual's root page; the entry point for node resolution.
- `docmost_manual_outline` — path to this project's `manual-outline.yaml` (the project-derived IA mapping doc-type → manual node).

Space UUID and owner UUID are not required — `docmost-cli` resolves the space slug server-side and defaults the owner to the authenticated user. If `config.yaml` is absent or `docmost_space` is missing, log a NOTE naming the missing key and proceed with the local file. If `docmost_manual_root_slug` or `docmost_manual_outline` is missing, the manual is not yet scaffolded — log a NOTE and fall back to the local file.

## Step 2 — Resolve routing rules

Read `{project-root}/_bmad/doc/data/decision-order.md` for the pre-flight routing rules — which operations require a manual lookup and which can go local-first.

## Step 3 — Derive the doc-type for the artifact

From the local filename or the calling skill's context, determine the doc-type slug using the durable catalog in `{project-root}/_bmad/doc/data/taxonomy.md`. Examples: `prd`, `product-brief`, `ux-spec`, `architecture`, `adr`, `runbook`. **`research` and `brainstorm` are canonical durable types** — resolve them against the manual exactly like any other living doc; never treat them as ephemeral or skip the manual lookup for them. If the type cannot be determined, skip to Step 7 (local fallback) and log the reason.

## Step 4 — Resolve the manual node from the IA (not a title search)

Sync the cache, then map the doc-type to its manual node using this project's derived IA. The IA path is **project-specific** — read it from `manual-outline.yaml`; do not assume any fixed section set.

```bash
docmost-cli cache sync --space <docmost_space>
```

Read `<docmost_manual_outline>` (`manual-outline.yaml`) and find the node whose `doc_type` matches the artifact's type (for many-per-project types, also match on the artifact's subject/title). This yields the node's expected **title** and IA path under `docmost_manual_root_slug`.

> **Note:** there is no `page tree resolve` verb — the only subcommand under `page tree` is `apply`. Resolve the IA node to a page using the existing read primitives below (`page get` / `search` / `page list`) rather than a tree-path resolver.

Resolve that node to a page. Use `page list` filtered by the node's title (the stable handle the tree was applied under) and `doc_type`, scoped to `--status canonical` to keep the grounding read clean (`page list` supports a `status` filter; `search` does not — `search` only has `--include-superseded`, off by default):

```bash
docmost-cli page list \
  --space <docmost_space> \
  --status canonical \
  --filter 'title == "<node-title-from-manual-outline>" && doc_type == "<doc-type>"' \
  --output json
```

If that is empty, widen to a title match (still canonical) in case the doc_type differs from the outline's expectation, and confirm the hit sits under `docmost_manual_root_slug`:

```bash
docmost-cli page list \
  --space <docmost_space> \
  --status canonical \
  --filter 'title contains "<node-title-from-manual-outline>"' \
  --output json
```

If a canonical page is found for the IA node, capture its slug and go to Step 6. If the IA defines the node but no canonical page exists yet, the manual node is unseeded — go to Step 7 (local fallback) and note the unseeded node. If the IA does not define a node for this doc-type, fall back to the broader status-filtered search (Step 5).

## Step 5 — Fallback search (status-filtered, only when the IA has no node)

Only when Step 4 cannot resolve a node from the IA, search — then **confirm canonical via `page list`** so a grounding read never lands on quarantined or stale content. `search` has no `--status` flag (it excludes superseded/archived by default via `--include-superseded`, but does NOT exclude `draft`), so use `search` to find candidates and then status-filter with `page list`:

```bash
docmost-cli search "<concept-from-title>" \
  --cached --content \
  --space <docmost_space> \
  --output json
```

Confirm the top hit is canonical with a title + doc-type check (this is where the `draft`/`superseded`/`archived` exclusion is actually enforced, via `page list --status canonical`):

```bash
docmost-cli page list \
  --space <docmost_space> \
  --status canonical \
  --filter 'title contains "<concept>" && doc_type == "<doc-type>"' \
  --output json
```

If either returns a canonical match, go to Step 6. If both are empty, go to Step 7.

## Step 6 — Fetch the canonical page

**Resolve the slug to its live canonical first** if it came from anywhere indirect — a `redirect_from` entry, a link in another page's body, or any source that may have been superseded since. A grounding read must land on the live successor, not a stale or redirected handle:

```bash
docmost-cli page resolve-slug <slug> --output json
```

Follow `superseded_by` to the live canonical and use that slug for the fetch. (A slug captured directly from the Step 4/5 `page list --status canonical` result is already live and needs no resolve.)

```bash
docmost-cli page get <slug> --output json
```

Use the returned markdown body as the canonical content for this read. The response carries `status` — if it is anything other than `canonical`, do **not** use it for grounding (a draft/superseded page is excluded); fall back to the local file and log it. Otherwise log the routing decision and stop — do not read the local file. The manual page is authoritative.

> **Embed-bearing pages (dashboards, architecture hubs, anything with embeds):** `page get` — **including `--output json`** — silently drops embeds (they surface as empty `##` headers) and strips link URLs. For an embed-bearing node, read via `page mirror pull` instead, which is the only faithful read (see the embed-read landmine in `data/rich-page-authoring.md` §0). Still confirm `status == canonical` from the `page get`/`page list` metadata; use `mirror pull` only to obtain the faithful body for grounding.

```
[doc-read-first] routed to manual node <slug> (ia-path: <path>, doc_type: <doc-type>, status: canonical)
```

## Step 7 — Fall back to the local file

No usable canonical manual node was found. Proceed with the local file. Log:

```
[doc-read-first] no canonical manual node for doc_type=<doc-type> — using local file
```

## Spec mode — fetch the confirmed intent node for a story

When invoked during a build (the wiki-first gate, from `bmad-create-story` or `bmad-dev-story`), the goal is not a generic doc read — it is to fetch the **intent node** for the specific story being built: the `technical-spec` / `prd`-section that records what this story is supposed to do, recorded and confirmed before code.

Invoke spec mode with the story identifier. The steps mirror the read path but target the intent node and care about confirmation state:

1. Resolve config (Step 1) and the IA (Step 4) as above.
2. Resolve the intent node by the story's link, not by filename. The node is the spec page linked to the work item:

   ```bash
   docmost-cli spec gate check <story-id> --output json
   ```

   This returns whether a **confirmed** intent node exists (`satisfied`), its slug, and the confirmation token.
3. If `satisfied` is true, fetch the intent node (`docmost-cli page get <slug> --output json`) and use its body as the grounding spec for the build. Honor `wiki_first_enforcement`:
   - `block` (the default): a missing or unconfirmed intent node HALTs the build — code must not proceed without confirmed intent.
   - `warn`: log a WARN and proceed.
   - `off`: no-op.
4. A `draft` intent node that has not been human-confirmed does **not** satisfy the gate — confirmation is a human ratification, never AI self-certification (P6).

Spec mode reads the same way as the normal path otherwise: excludes `draft`/`superseded`/`archived` from grounding, and treats the manual as authoritative over any local story scratch.

## Grounding-read exclusion (applies to every mode)

Reads that feed an agent's reasoning (grounding, spec, RAG) use **canonical content only**. `draft`, `superseded`, and `archived` pages are excluded server-side via a status-filtered retrieval. A draft you authored this session is not yet grounding-eligible — it becomes so only after ratification.

## Error handling

| Condition | Action |
|---|---|
| `docmost-cli` not on PATH | Log NOTE; use local file |
| Auth status non-zero | Report to user; halt |
| `cache sync` exits 3 (CACHE_STALE) | Re-run `cache sync` once; if still 3, log WARN and proceed without manual lookup |
| IA-node resolution (Step 4 `search`/`page list`) exits non-zero | Log WARN; try the broader status-filtered search (Step 5) |
| `search` / `page list` exits non-zero | Log WARN with errorCode; fall back to local file |
| `page resolve-slug` exits non-zero (Step 6) | Log WARN; fall back to `page get` on the original slug |
| `page get` exits non-zero, or returns non-canonical status | Log WARN; fall back to local file |
| `spec gate check` exits non-zero (spec mode) | If `block`: HALT; if `warn`: log WARN and proceed; if `off`: proceed |
| `config.yaml` missing/incomplete, or manual not yet scaffolded | Log NOTE naming the missing key; use local file |

Never parse stderr error text — always branch on exit code and the `errorCode` field from the JSON envelope.
