# docmost-cli CLI Reference (for BMAD skills)

> Source of truth: `docmost-cli instructions --agent`. This file is curated for skill use.

`docmost-cli` is the only sanctioned interface between a BMAD skill and the Docmost wiki. Skills never speak HTTP directly, never edit the SQLite cache, and never call the MCP surface. Every recipe below routes through `docmost-cli` so audit, CAS, and transclusion safeguards apply uniformly.

## Auth & cache

### Verify auth before any wiki call

```bash
docmost-cli auth status --output json
```

Exit codes: `0` = authenticated, non-zero = no usable profile. If exit non-zero, fail the skill with a structured message telling the user to run `docmost-cli auth login --instance <url> --token <api-key>`. Headless / CI environments may set `DOCMOST_API_TOKEN` instead — the CLI picks it up automatically.

### Sync the cache before any read

```bash
docmost-cli cache sync                  # full sync
docmost-cli cache sync --space <slug>   # one space
docmost-cli cache sync --since <RFC3339> # incremental
```

Reads from `page get`, `page list`, `search --cached`, `verify duplicates`, `verify staleness`, `page backlinks`, and `page breadcrumbs` serve out of the local SQLite cache, populated by `cache sync` and kept fresh by the daemon. If the daemon is running (`docmost-cli daemon status`), the cache auto-refreshes via Docmost's event stream; if not, run `cache sync` explicitly.

**Exit code 3 (`CACHE_STALE`)** on a read command means the cache is stale or empty — re-run `docmost-cli cache sync` and retry.

### Invoking commands

- Global format flag: `--output human|json|yaml|template` (also `--json` as shorthand). Skills should always pass `--output json` for machine parseability.
- `--profile <name>` switches between Docmost instances if a skill needs multi-tenant access.
- `--no-server-audit` is a kill-switch for the server-side audit dual-write; skills should leave it off so audit rows land in both the local JSONL log and the Docmost `audit` table.

## Find before create

Before any `page create` call, a skill MUST run this two-step check. If either step finds a match, the skill must update the existing page instead of creating a new one.

### Step 1 — Search body content

```bash
docmost-cli search "<topic>" --cached --content --space <slug> --output json
```

- `--cached` runs against the local SQLite cache (offline, sub-ms).
- `--content` performs FTS5 full-body search (not just title). Required when looking for a canonical concept that may not appear in titles.
- Without `--cached`, the call hits the live `/api/search` endpoint (online; supports `--mode keyword|hybrid|semantic`).

### Step 2 — List canonical alternatives

```bash
docmost-cli page list --status canonical --filter 'title contains "<topic>"' --output json
```

- `--filter` accepts an expr-lang expression. Common idioms: `title contains "<word>"`, `doc_type == "adr"`, `tags contains "<tag>"`, `updated_at > "2026-01-01"`, combine with `&&` / `||`.
- `--status canonical` ensures the skill is comparing against authoritative docs only.
- `--has-permission <Action>:<Subject>` filters to pages the caller can actually act on (e.g. `Edit:Page`). Useful when a skill needs to enumerate "what can I update?" without making N permission calls — particularly for bulk operations.

If both steps return empty, proceed with create. If either step returns a candidate, route the skill to update the candidate (`page mirror pull` → edit → `page mirror push`).

## Read a page

```bash
docmost-cli page get <slug>                     # markdown body (human format)
docmost-cli page get <slug> --output json       # full record incl. native metadata
docmost-cli page get <slug> --field doc_type    # single-field extract
docmost-cli page get <slug> --no-daemon         # bypass cache, hit live API
```

Use `--field` for cheap probes (status, owner_id, last_reviewed_at). Note: `--output json` and `--field` are mutually exclusive — `--field` returns a plain scalar; `--output json` returns the full record. Never combine them in a single call. Use `--no-daemon` when you need a guaranteed live read (e.g. immediately after an external user edit). Default reads are sub-ms from the SQLite cache.

`page info` does not exist as a separate command — `page get` serves both roles depending on `--output`.

## Resolve a slug

When a skill is handed a slug it doesn't trust (a slug from a `redirect_from` field, an old link in body content, a slug that may have been superseded), resolve it before reading.

```bash
docmost-cli page resolve-slug <slug>              # returns canonical slug + status
docmost-cli page resolve-slug <slug> --output json
```

The endpoint walks `redirect_from` chains first, then `superseded_by` chains, and returns the live canonical destination. If the input slug is already canonical, it returns unchanged. Skills processing redirects MUST resolve before issuing `page get` — otherwise they may read a stale or superseded page silently.

## Create a page

```bash
docmost-cli page create "<Title>" \
  --space <slug> \
  --parent <parent-slug> \
  --doc-type <type-from-taxonomy> \
  --status draft \
  --owner-id <uuid> \
  --icon <emoji> \
  --content @<file>     # or @- for stdin, or a literal string
```

Required by the taxonomy: `--doc-type` and `--status` (default `draft`; promote to `canonical` only after review). `--owner-id` is optional — `page upsert`/`page create` default to the authenticated user from `docmost-cli auth login`; pass `--owner-id <uuid>` explicitly only when publishing on behalf of a different identity. Optional but recommended: `--icon`, `--last-reviewed-at`.

### Templates

```bash
docmost-cli page create "<Title>" --space <slug> --template <decision|meeting> \
  --template-vars key1=val1 --template-vars key2=val2
```

Built-in templates are `decision` and `meeting`. Per-doc-type templates ship via the BMAD `doc-type-templates/` data dir — those are loaded by the skill, not by `--template`.

### Content sources

`--content` accepts:
- `@<file>` — read from a file path (max 10 MB by default; `--max-content-size` to lift).
- `@-` — read from stdin.
- `<literal>` — anything that doesn't start with `@`.

## Authoring rich pages (embeds / `page block`)

Pages are not flat markdown — Docmost has 28 native embed types (9 families). Authoring them is how a skill satisfies **P7** ("a picture before dense prose, a concrete example for every concept"). **Full guide: `data/rich-page-authoring.md`.** House style: `data/authoring-conventions.md`.

```bash
docmost-cli page block <type> <slug> [type-flags]   # alias: pb
docmost-cli instructions embeds [--output json]      # discover the catalog (don't hardcode it)
docmost-cli page block rm <slug> --block-id <uuid>   # delete a block
```

Every `page block` subcommand accepts the universal flags `--op append|prepend|replace-at|insert-at` (default `append`), `--if-version` (CAS — default-on), and `--dry-run` (prints the ProseMirror node, no API call). The families: Diagrams (`mermaid`/`excalidraw`/`drawio`), `callout`, `status`, Math (`math_block`/`math_inline`), Media (`pdf`/`video`/`audio`/`attachment`/`image_from_prompt`), `embed` (external URLs), Structure (`columns`/`details`/`subpages`/`transclusion`), Linear (8 `linear_*`), Tabular (`table`/`task_list`/`chart`).

> ⚠️ **EMBED-READ LANDMINE — read `rich-page-authoring.md` §0.** `page get` (*including `--output json`*) **silently drops every embed** (they show as empty `##` headers) and strips inline link URLs. Only **`page mirror pull`** shows the `:::…:::`/```mermaid/`:::linear-graph:::` fences. And **`mirror push` is itself lossy for embeds** — it strips embed args. So: **read** rich pages via `mirror pull`; **author/repair** embeds via `page block` (never reconstruct an embed from mirror markdown and push). A page that looks "empty" in `page get` is almost always full of embeds.

> 🖊️ **Diagram policy.** Default to **coloured Excalidraw** for *simple* diagrams (≤ ~3–4 nodes) — but Excalidraw renders blank until a **human** opens it and clicks **Save & Exit** (re-authoring wipes the bake), so every Excalidraw block ships with a `[bake-pending]` warning callout and is surfaced by `doc-ratify` as a required human task. Use **coloured Mermaid** for anything multi-node / complex / must-render-unattended (its arrows always connect and it needs no bake). See `rich-page-authoring.md` §3.

## Build a manual tree (`page scaffold` / `page tree apply`)

The wiki-first construction verbs (owned by `doc-librarian`; see `taxonomy.md` §1).

```bash
# Seed an entire nested tree from one YAML outline, depth-first, idempotent.
docmost-cli page tree apply <outline.yaml> --space <slug> [--parent <slug>] \
  --on-existing skip|update|recreate            # default skip: reuse+recurse, never clobber
# (auto-injects a re-runnable "Contents" block of [[slugId]] links into each parent; --link-children=false to disable)

# Stamp a single P7 doc-type skeleton on a page (ALWAYS draft; canonical rejected here).
docmost-cli page scaffold "<Title>" --space <slug> --doc-type <type> \
  --template @data/doc-type-templates/<type>.md \
  --scaffold manual-root|section-landing|concept|how-to|reference|index   # derived from --doc-type when omitted
```

Both are **idempotent (P1)**: they match an existing IA node by **title under the parent (case-sensitive)** and update in place rather than creating a sibling. `--if-version` for CAS re-apply. The body template comes from `data/doc-type-templates/<type>.md` (loaded by the skill, not shipped in the CLI).

## Update a page (multi-line edit)

The preferred path for any non-trivial edit. Round-trips markdown through the filesystem so the agent can edit with normal file tools. **If the page has embeds, see the embed-read landmine above — `mirror push` strips embed args; repair embeds with `page block`, not by editing the mirrored markdown.**

```bash
docmost-cli page mirror pull <dir> --space <slug>
# edit <dir>/<slug>.md (front-matter + body)
docmost-cli page mirror push <dir> --space <slug>
```

`mirror pull` writes one `.md` file per page with YAML front-matter containing `slug`, `uuid`, `title`, `space_slug`, `parent_slug`, `icon`, `updated_at`, and the native metadata fields (`status`, `doc_type`, `owner_id`, `last_reviewed_at`, `supersedes`, `superseded_by`, `redirect_from`, `tags`).

`mirror push` reads those files, diffs against the cache, and pushes only changed pages. Optional flags:

- `--fresh` — first-push mode; skip conflict detection. Use on a freshly populated directory.
- `--prune` — delete wiki pages that no longer exist locally. Combine with `--yes` to skip the confirmation.

**Setting native metadata on promotion:**

```bash
docmost-cli page update <slug> \
  --status canonical \
  --doc-type <type-from-taxonomy> \
  --owner-id <uuid> \
  --last-reviewed-at "$(date -u +%FT%TZ)"
```

`--doc-type`, `--status`, `--owner-id`, and `--last-reviewed-at` are all valid on `page update` (not just `page create`). `--owner-id` is optional on update too — omit unless reassigning ownership. Use this form to promote a draft to canonical in a single call.

**Caveat on supersession via front-matter:** `mirror push` will set `superseded_by` on the page you edited, but it will NOT write the reciprocal `supersedes` entry on the other page. Use `docmost-cli page supersede` when establishing or breaking a supersession relationship.

## Update a page (single-line edit)

When the edit is one substring replacement, skip mirror entirely.

```bash
docmost-cli page patch <slug> --find "old text" --replace "new text"
```

Match semantics:
- Default mode: `--once` (implicit). Exactly one match required. Zero matches → `PAGE_NOT_FOUND`. >1 matches → `AMBIGUOUS` with line numbers in the error envelope.
- `--all` — replace every occurrence; receipt reports the count.
- `--regex` — treat `--find` as a Go regexp. Compile errors abort before any network call.

Line addressing (use `docmost-cli page get <slug> --line-numbers` / `-n` to read 1-based line numbers first):
- `--line N` — operate on a single line (sugar for `--from N --to N`).
- `--from N --to M` — an inclusive line window (`--from` alone → to EOF; `--to` alone → from line 1).
- With `--find`, `--line N` **disambiguates** which occurrence to replace. Without `--find`, the addressed lines are replaced wholesale by `--replace` (multi-line ok; `--replace ""` deletes; receipt echoes `replaced_text`).
- Insertion (nothing removed): `--after N --insert "text"` / `--before N --insert "text"` (`--before 1` prepends, `--after <last>` appends).

Safety flags:
- `--dry-run` — print unified diff on stderr and exit 0; no API call.
- `--if-version <cached_updated_at>` — CAS, **default-on**: `page patch`/`page update`/`page block` auto-read the cached `updated_at` and abort with `CONFLICT` if the cache drifted. `--no-cas` opts out (interactive use only; **skills never pass `--no-cas`**). Pass `--if-version` explicitly only to pin a specific version.

Receipt (JSON output):
```json
{
  "slug": "...", "uuid": "...", "url": "...",
  "matches_replaced": 1,
  "content_hash_before": "...", "content_hash_after": "..."
}
```

## Bulk update across pages

```bash
docmost-cli page patch --filter '<expr>' --find "<text>" --replace "<text>" --rate-limit 10
docmost-cli page update --filter '<expr>' --status canonical --rate-limit 10
```

- `--filter` accepts expr-lang expressions (same syntax as `page list --filter`).
- `--rate-limit` defaults to 10 req/s. Honors server `429 Retry-After`.
- `--dry-run` emits a JSON summary of would-be changes without any API call.
- `AMBIGUOUS` on any one page aborts the entire batch and returns partial results.

For very large spaces (>500 pages), narrow the filter and run in batches.

## Workspace-wide find-and-replace (`page replace` / `space replace`)

The **blunt** counterpart to `page patch`: replace *every* occurrence of a literal substring across *every* cached page. Use it for cross-wiki renames (a domain, an email, a renamed term) where `page patch --filter`'s `AMBIGUOUS` guard would make you fight it.

```bash
docmost-cli page replace "<find>" "<replace>" [-i] [--space <slug>] [--filter '<expr>'] [--dry-run] [--rate-limit 10]
docmost-cli space replace "<find>" "<replace>" --space <slug> [...]   # identical, but --space is REQUIRED (safety rail)
```

- **Literal substring only** (no regex). `-i`/`--ignore-case` for case-insensitive. `--replace ""` deletes the matched text.
- Scope with `--space` or `--filter`; `--dry-run` previews; `--rate-limit` (default 10 req/s, honors `429`).
- **Skips** trashed/superseded/archived pages.
- **Freshness-guarded:** it probes each page's live `updated_at` and **skips drifted pages** (never clobbers). A per-page failure does **not** abort the run — it finishes the rest and exits `PARTIAL_FAILURE`. stdout is a JSON array `{slug,uuid,url,replacements,updated_at}`.
- Contrast: `page patch` is **surgical/anchored** (one page, refuses `AMBIGUOUS`); `page replace` is **blunt replace-all** (every match, every page). `page replace` does **not** touch embed args — repair embeds via `page block`.

## Supersede a page

The verb-shaped endpoint. Use this — not raw front-matter edits — to establish or change a supersession relationship.

```bash
# B supersedes A
docmost-cli page supersede <B-slug> --supersedes <A-slug>

# Or from A's side
docmost-cli page supersede <A-slug> --superseded-by <B-slug>
```

The server atomically:
1. Sets `supersedes ⊇ [<A-slug>]` on B.
2. Sets `superseded_by = <B-slug>` on A.
3. Flips A's status to `superseded` (unless the caller explicitly overrode it).

Exactly one of `--supersedes` or `--superseded-by` must be present per call.

### Transclusion conflict handling on supersede

If the page being superseded has active transclusions and you want to proceed anyway:

```bash
docmost-cli page supersede <new-slug> --supersedes <old-slug>[,<old-slug-2>...] \
  --on-transclusion-conflict unsync
```

`--on-transclusion-conflict` values on `page supersede`:
- `block` (default) — refuses if any loser has active transclusions; returns `CONFLICT`.
- `unsync` — auto-converts every active reference to a static copy, then proceeds. Each unsync produces a separate audit entry.

### Supersession with redirect registration

When inbound links to A should resolve to B as part of the supersession:

```bash
docmost-cli page update <B-slug> --redirect-from <A-slug>[,<another-old-slug>]
```

This marks A as superseded and stamps B's `redirect_from` array. It also enqueues a server-side `PAGE_SLUG_REWRITE` background job that rewrites inbound links to A inside other pages' body content, repointing them to B. That rewrite is **asynchronous** — it is not complete the instant `page update` returns. `redirect_from` additionally powers read-time resolution: `docmost-cli page resolve-slug <A-slug>` returns B. Because the body-link rewrite may still be draining, a skill following a slug taken from page body content MUST `resolve-slug` it before `page get`. `--dry-run` previews without making API calls.

## Archive or delete a page

Always pre-flight transclusion impact first.

### Pre-flight

```bash
docmost-cli page transclusion-impact <slug> --operation archive --output json
docmost-cli page transclusion-impact <slug> --operation supersede --output json
docmost-cli page transclusion-impact <slug> --operation delete --output json
docmost-cli page transclusion-impact <slug> --operation permanent-delete --output json
```

Exit semantics:
- `0` — safe to proceed (zero active transclusions).
- `1` — transclusions exist. JSON output lists every referencing page; review before proceeding.

### Operations

```bash
# Archive (recoverable; pre-flight required)
docmost-cli page update <slug> --status archived
docmost-cli page update <slug> --status archived --on-transclusion-conflict unsync   # auto-unsync if refs exist

# Soft delete (to trash; recoverable via page restore)
docmost-cli page delete <slug>
docmost-cli page restore <slug>

# Permanent delete (irreversible; admin)
docmost-cli page purge <slug> --yes
```

`--on-transclusion-conflict` values:
- `block` (default) — refuses to proceed when references exist; returns `CONFLICT`.
- `unsync` — auto-converts every active reference to a static copy, then proceeds. Each unsync is a separate audit entry.
- `force` — only honored on `page purge`. Skips the unsync and breaks references silently. Emits a high-priority audit entry naming every page that just had its references invalidated. Emergency-only.

## Label / tag management

Docmost labels are workspace-scoped by default — the same label name maps to the same row across every space. The CLI exposes both scopes.

```bash
docmost-cli page labels list <slug>
docmost-cli page labels add <slug> <label1> [label2 ...] --scope space|workspace   # default: space
docmost-cli page labels rm <slug> <label>

docmost-cli label list                                  # workspace-wide
docmost-cli label list --scope space --space <slug>     # space-scoped only
docmost-cli label pages <name> --space <slug>           # find pages by label
```

When using labels to mirror taxonomy facets (`type:adr`, `status:canonical`), prefer the `--scope workspace` form so the same vocabulary applies everywhere. Note: native columns (`status`, `doc_type`) are the source of truth; labels are a convenience query surface.

## Permissions

Two output shapes:

```bash
docmost-cli page permissions <slug>                # membership rows (default)
docmost-cli page permissions <slug> --evaluated    # caller's effective CASL set

docmost-cli space permissions <slug>
docmost-cli space permissions <slug> --evaluated
```

`--evaluated` returns `[{subject: 'Settings'|'Member'|'Page'|'Share', actions: ['Read'|'Manage']}]` — the CASL-rendered shape an MCP `get_page_permissions` would have returned. Use it when a skill needs to decide whether the caller can perform a privileged action; use the default membership-row form when a skill needs to enumerate who else has access.

## Identity

One-shot identity dump combining the caller, their workspace, and their space memberships:

```bash
docmost-cli user me --output json
# or, identically:
docmost-cli auth whoami --output json
```

Returns `{id, email, name, role, workspaceId, workspaceName, spaces: [...]}`. Always a flat object — never an array.

Use `auth status` only to verify a profile is loaded; use `user me` / `auth whoami` to actually read the identity.

## Comments

Skills doing review workflows (e.g. `tech-writer-consolidate` proposing merges, draft-review skills surfacing feedback) interact with page comments.

```bash
docmost-cli comment list <slug> --output json              # all comments on a page
docmost-cli comment get <uuid> --output json               # single comment by UUID
docmost-cli comment add <slug> --body "<text>"             # general page comment
docmost-cli comment edit <uuid> --body "<text>"            # update own comment
docmost-cli comment resolve <uuid>                          # mark resolved
docmost-cli comment resolve <uuid> --reopen                 # reopen
docmost-cli comment rm <uuid>                               # delete
```

Skills SHOULD use comments to surface review-required decisions to humans rather than blocking on AI judgment. A typical pattern: skill identifies a consolidation candidate cluster → adds a comment proposing the merge → waits for human resolution before executing the supersede.

## Audit

Every mutating CLI command writes a JSONL line to `$XDG_STATE_HOME/docmost-cli/audit.log`. Server-side dual-write to Docmost's `audit` table is on by default (disable with `--no-server-audit` or `ORVEX_DOC_NO_SERVER_AUDIT=1`).

```bash
docmost-cli audit summary --since 1h --output json
docmost-cli audit summary --since 24h --top 20 --output json
```

`--since` accepts durations (`1h`, `30m`, `24h`, …). `--top` caps the `by_action` map and groups the remainder under `other`. Skills can use the summary at session-end to surface "what did I just do?" to the user.

## Verification & health

These commands underpin the CI enforcement layer in `taxonomy.md` §7. Skills should run them at appropriate moments:

```bash
# Before promoting any cluster of pages to canonical
docmost-cli verify duplicates --output json                         # auto: server first, falls back to local
docmost-cli verify duplicates --space <slug> --output json          # scope to one space
docmost-cli verify duplicates --engine server --output json         # semantic only (requires AI provider)
docmost-cli verify duplicates --engine local --mode content --output json  # offline Jaccard similarity

# Before archiving / superseding broadly
docmost-cli verify staleness --older-than 180d --status canonical --output json
docmost-cli verify staleness --older-than 180d --strict   # exit 7 if any stale

# After mirror push / page create
docmost-cli verify links <slug> --output json

# After bulk migrations
docmost-cli verify orphans --space <slug> --output json   # orphan ATTACHMENTS (not pages)

# Aggregate health
docmost-cli verify space --space <slug> --output json
```

`verify duplicates` uses `--engine auto` by default: it tries the server's semantic duplicate engine (embeddings + reranker, runs as a background sweep on the server) and silently falls back to the local heuristic engine if the server is unavailable or lacks an AI provider. Use `--engine local` to force the offline path (regex suffix patterns + optional Jaccard body similarity via `--mode content`). The server engine reads pre-computed clusters and excludes superseded pages; the local engine includes them. `--status open|resolved|dismissed|all` (server engine only) filters by cluster status — use `--engine server --status all` to view resolved and dismissed clusters too. When acting on clusters, **skip `dismissed`** ones (a human already rejected them) so you don't re-surface them every run.

### The living-wiki CI layer (lint / drift / ia-conformance / render)

These back `doc-drift`, `doc-ratify`, and Marian's HEALTH menu. All exit `7` on failure (gateable in CI).

```bash
# P4/P7 editorial + Docmost-compat linter — local files OR a live page OR a whole space
docmost-cli verify lint <file...>                                    # local markdown
docmost-cli verify lint --page <slug> --space <slug> --rules 'P4-*,P7-*'   # one live page, selected rules
docmost-cli verify lint --space <slug> --strict                      # every page in a space; --strict promotes warnings to errors
#   --min-lead-words N (default 12) tunes P7-LEAD-THIN. Exit 7 VERIFICATION_FAILED on any error-severity finding.

# Code-state drift — compares each page's verified_against stamp to current code HEAD
docmost-cli verify drift --space <slug> [--since <sha>] [--strict]    # --strict → exit 7 DRIFT_DETECTED
docmost-cli verify drift --graph @graph.json --strict                 # one-hop referrer expansion via `code graph` output

# Structural taxonomy conformance against the project's manual outline
docmost-cli verify ia-conformance --outline @manual-outline.yaml --space <slug>   # exit 7 IA_NONCONFORMANT
#   run `cache sync` first — reads the live tree from the local cache.

# Headless-Chromium component-render assertions (chromium ships in the standard binary now)
docmost-cli verify render <slug> --screenshot /tmp/page.png [--timeout 10s]
```

- `verify render` is the **embed-render gate**: it asserts each component renders. A blank `linear_graph` (snapshot not baked) or an **unbaked Excalidraw** surfaces here — the latter is the one expected "failure" that is a *human bake task*, not a re-author (see `rich-page-authoring.md` §3, `[bake-pending]`).
- `verify drift`'s `--graph` expansion needs `code graph` output; `code graph` requires the Tree-Sitter cgo build (`CGO_ENABLED=1 -tags treesitter`) and is **absent from the standard binary** — drift then runs in provided-set mode. Treat `code graph` as build-conditional.

## AI ask (RAG)

`ai ask` queries the Docmost server's retrieval-augmented generation pipeline and returns a cited answer grounded in wiki content.

```bash
# Ask from the command line
docmost-cli ai ask "How do we handle database migrations?" --output json

# Read question from stdin
echo "What is our SLA policy?" | docmost-cli ai ask -

# Read question from a file
docmost-cli ai ask @question.txt --output json
```

JSON output shape:
```json
{
  "answer": "...",
  "citations": [
    { "page_id": "uuid", "page_title": "...", "snippet": "...", "similarity": 0.95, "slug": "..." }
  ]
}
```

`slug` is populated when the page UUID resolves in the local cache (run `cache sync` first). `ai ask` is **workspace-scoped** — there is no `--space` flag; it searches the whole workspace. It requires an AI provider configured on the Docmost server; a missing provider returns exit 1 with `errorCode: SEARCH_MODE_UNAVAILABLE`. When nothing in the workspace scores above the server's similarity threshold, `ai ask` returns a "not enough relevant information" answer with no citations — treat that as "no wiki grounding" and fall back to `search` + `page get`.

## AI image / cost / reembed

The AI group is more than `ai ask`:

```bash
docmost-cli ai image generate "<prompt>" --page <slug> --op append --size 1024x1024   # text→image, attached+embedded
docmost-cli ai cost --output json                                                      # token/cost dashboard by model/provider
docmost-cli ai reembed [--space <slug>]                                                # bulk-regenerate vector embeddings
```

- `ai image generate` is the page-attached form of `page block image_from_prompt`; both need an image model in the workspace LiteLLM.
- **`ai reembed` is a prerequisite for trustworthy semantic search.** Run it after changing the embedding model or after a bulk migration — otherwise `search --mode semantic`, `ai ask`, and `verify duplicates --engine server` score against stale vectors.
- `ai cost` surfaces RAG/image spend; use it in Marian's HEALTH pass.

## Spec gate (wiki-first)

Read-only probe of whether a story has a substantive, human-confirmed intent node in the wiki (CONTRACTS §1.8). Used by `doc-spec-gate`.

```bash
docmost-cli spec gate check <story-id> --space <slug> --output json
# → { "satisfied": true|false, "token": "...", "reason": "..." }
```

**Branch on the `satisfied` field, NOT the exit code.** A successful probe always exits `0` (a nonzero exit means the probe itself failed). When `satisfied` is false, enforce per `wiki_first_enforcement` (block/warn/off). The gate is satisfied only when a substantive, human-confirmed technical-spec/prd-section exists under the story's epic — a stub page does not satisfy it. (Exit code `9` `GATE_UNSATISFIED` is reserved for strict-gating shims.)

## Bulk import (migrate)

The purpose-built pipeline for importing a directory of legacy markdown into the wiki.

```bash
docmost-cli migrate scan <dir> --space <slug> [--parent <slug>] [--git-history] --out manifest.yaml
docmost-cli migrate apply manifest.yaml [--json]
docmost-cli migrate verify manifest.yaml
```

`migrate scan` builds a manifest (optionally with per-commit `--git-history`); `migrate apply` creates/updates pages (replaying history oldest-first when present, with `last_applied_sha` resume); `migrate verify` checks the result (including a history-depth check). `doc-migrate` deliberately route-by-taxonomy instead of 1:1 mirroring, but may use `migrate scan` to *enumerate* sources before classifying.

## Repo-local docs mirror (docs link)

Make a space readable as plain files in the repo (for file-based tooling/agents):

```bash
docmost-cli docs link [--space <slug>] [--path .cache/docs]   # materialize the space as read-only markdown
docmost-cli docs status                                       # symlink state + file count + freshness
docmost-cli docs unlink                                       # remove the symlink, README, and .gitignore entry
```

`docs link` symlinks `.cache/docs` to the per-instance mirror dir **and materializes every cached page of the space into it as `<slug>.md`** — each stamped with a small read-only front-matter header (`title`, `slug`, `space`, `status`, source `url`, `synced_at`) and the page body. Auto-setup: gitignores the whole **`.cache/`** folder and writes a **`.cache/README.md`** explaining the mirror.

- **One-shot from the LOCAL cache.** Run `docmost-cli cache sync` first for freshness, then `docs link`; re-run `docs link` any time to refresh (stale `.md` are pruned). Space resolves from `--space` or `_bmad/doc/config.yaml`.
- **Read-only.** Files are a snapshot; edits there do NOT sync back — edit in the wiki or via `docmost-cli page …`.
- **Embeds are dropped** (same markdown limitation as `page get`): mermaid/Linear/callout etc. don't appear in these files — open the live wiki (`url:` in each header), and for faithful embed fences use `page mirror pull`.

Note the two distinct caches: the authoritative SQLite cache at `~/.cache/docmost-cli/<instance>/cache.db` (daemon-managed) vs. this repo-local `.cache/docs/` **file view** of one space.

## Inspect & navigate

Cheap, mostly cache-only reads (no API call unless noted):

```bash
docmost-cli page diff <slug> --against server|<file>|<history-id>   # unified diff: cache vs live / local draft / a history version
docmost-cli page history <slug> [--all]                            # edit history (default 20; --all for full)
docmost-cli page revert <slug> --to <history-id>                   # restore a previous version
docmost-cli page backlinks <slug>                                  # who links TO this page (cache-only)
docmost-cli page breadcrumbs <slug>                                # ancestor path (cache-only)
docmost-cli page move <slug> --parent <new-parent>                 # re-parent (or --filter for bulk)
docmost-cli page duplicate <slug> [--with-descendants]             # copy a page (and optionally its subtree)
docmost-cli page watch <slug>                                      # stream changes as they arrive
```

Prefer `page diff --against server` to compute a body delta (e.g. in `doc-drift`) rather than hand-diffing. `page diff` reads markdown, so it does **not** see embed nodes — for embed-bearing pages, diff via `mirror pull`.

## Exit codes & error envelope

Skills must branch on these — never parse human-readable error text.

| Exit | Code | Meaning |
|---|---|---|
| 0 | — | success |
| 1 | `RUNTIME_ERROR`, others | generic runtime failure |
| 2 | `INVALID_ARGS`, `AUTH_MISSING`, `INVALID_FILTER`, `INVALID_INSTANCE_URL` | usage / argument problem |
| 3 | `CACHE_STALE` | re-run `docmost-cli cache sync` |
| 4 | `TITLE_AMBIGUOUS` | the title resolved to multiple pages — disambiguate by slug |
| 5 | `FORBIDDEN` | caller lacks the required permission |
| 6 | `SERVER_UNREACHABLE` | network / API down |
| 7 | `VERIFICATION_FAILED`, `CACHE_DRIFT`, `DRIFT_DETECTED`, `IA_NONCONFORMANT` | verify-step failure (lint/drift/ia-conformance/staleness) |
| 8 | `DUPLICATE_CANDIDATE` | find-before-create dup guard blocked the create — amend the candidate instead |
| 9 | `GATE_UNSATISFIED` | wiki-first spec gate not satisfied (strict shims; otherwise branch on the `satisfied` field) |

Common `errorCode` values inside the stderr JSON envelope:

- `CACHE_STALE` — read attempted with stale cache; sync first.
- `CONFLICT` — CAS check failed (`--if-version` mismatch) OR `TRANSCLUSION_REFERENCES_ACTIVE` on a destructive operation.
- `TRANSCLUSION_REFERENCES_ACTIVE` — destructive op blocked; run `page transclusion-impact` for the surface area; either resolve or pass `--on-transclusion-conflict unsync`.
- `PAGE_NOT_FOUND` — slug doesn't exist, or `page patch` found zero matches.
- `TITLE_AMBIGUOUS` — multiple pages share the title; pass slug not title.
- `AMBIGUOUS` (within a patch receipt) — `--find` matched more than once and `--once` was in effect; line numbers included.
- `FORBIDDEN` — CASL check failed.
- `RATE_LIMITED` — server-side throttling; the CLI respects `Retry-After` automatically on bulk paths.

The stderr envelope shape:

```json
{
  "errorCode": "...",
  "message": "...",
  "hint": "...",
  "matches": [...],
  "requestId": "..."
}
```

## Recipes for common skill operations

Decision tree for the four most common operations:

### EDIT existing
- Multi-line / large rewrite → `page mirror pull` → edit file → `page mirror push` (**not** for embed-bearing pages — `mirror push` strips embed args; see the embed-read landmine).
- Single substring → `page patch <slug> --find … --replace …` (CAS is default-on; `--line N` to disambiguate a repeated match — read line numbers with `page get -n`).
- Many docs at once → `page patch --filter '<expr>' --find … --replace …` or `page update --filter '<expr>' --status …`.
- Cross-wiki rename (every match, every page) → `page replace "<find>" "<replace>" [--space …]` (or `space replace`).

### AUTHOR rich (embeds)
1. Draft prose (create/scaffold/amend), then satisfy P7 by attaching the right block: `page block <type> <slug>` — `mermaid`/`excalidraw` for a diagram (per the diagram policy), `callout` for a gotcha/lead, `table`/`chart` for data, `task_list` for steps, `transclusion` for a reused fact, `subpages` for an index, live `linear_*` for status. See `rich-page-authoring.md`.
2. `--dry-run` to preview the PM-JSON, then write.
3. Verify it renders: `verify render <slug>` (or `screenshot shot /s/<space>/p/<slug> -O out.png --settle 3s --full-page` — full route, not bare slugId).
4. Re-read embeds with `mirror pull`, never `page get`.

### CREATE new
1. `docmost-cli search "<topic>" --cached --content --output json` — body match check.
2. `docmost-cli page list --status canonical --filter 'title contains "<topic>"' --output json` — title match check.
3. Only if both empty: `docmost-cli page create "<Title>" --space … --doc-type … --status draft --owner-id …`.

### SUPERSEDE
- Atomic verb: `docmost-cli page supersede <new> --supersedes <old>`.
- With backlink rewrite: `docmost-cli page update <new> --redirect-from <old1>,<old2>`.
- Never set `superseded_by` in front-matter alone — the reciprocal won't be written.

### ARCHIVE / DELETE
1. `docmost-cli page transclusion-impact <slug> --operation <archive|delete|permanent-delete> --output json`.
2. If exit 0: proceed with `page update <slug> --status archived` (archive) or `page delete <slug>` (soft) or `page purge <slug> --yes` (permanent).
3. If exit 1: either resolve manually OR re-run with `--on-transclusion-conflict unsync` on the destructive command itself.
