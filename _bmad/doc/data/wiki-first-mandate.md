# Wiki-First Mandate

> The single source of truth for the wiki-first doctrine. Loaded as a persistent
> fact into every BMAD agent and planning workflow in a living-wiki project, so the
> orientation is identical everywhere and never drifts. This file is **module-owned**
> (bmad-docmost) — do not hand-edit it per project. The machine-readable constitution
> is `skill:doc-session-policy`; the routing router is `data/decision-order.md`; the
> full CLI surface is `data/docmost-cli-reference.md`. This file is the short, always-on
> orientation that points at all three.

## The mandate (non-negotiable)

This is a **living-wiki project**. The project's Docmost wiki manual is the **primary
source of truth** and **OUTRANKS the local filesystem** — the README, source code,
schemas, planning artifacts, and every other local file. **The manual outranks the
code; code conforms to the manual**, not the other way around.

This binds **every turn** — structured workflows *and* free-form discussion. It is not
scoped to a particular workflow or menu item.

- **Resolve the wiki FIRST.** Before you read local files to establish project state,
  existence, or "ground truth," resolve what the wiki already holds.
- **Never conclude from the filesystem alone.** Do NOT conclude project state, "no X
  exists," or any project fact from the local filesystem. "Exists" means *exists in the
  wiki*. A local artifact is only a **transient working draft** reconciled to the wiki.
- **One living page per concept**, updated in place (P1). No `-v2 / -final / -wip`
  siblings, no dated copies. Research and brainstorm are **durable wiki canon**, not
  ephemeral scratch (P2).
- **Author at draft; humans ratify.** AI writes at `status: draft`; promotion to
  `canonical` is a human act (doc-ratify). AI never self-certifies (P6).
- **Intent before code (wiki-first gate).** New work is recorded as an intent node in
  the wiki and human-confirmed *before* implementation (`wiki_first_enforcement`).

## How to access the wiki

`docmost-cli` is the **only** sanctioned interface — never call Docmost HTTP directly,
never edit the local cache, and **branch on the exit code + the `errorCode` field,
never on stderr text**.

**Verify access once at activation:**

```bash
which docmost-cli || echo "NOTE: docmost-cli not on PATH"
docmost-cli auth status --output json        # exit 0 = authenticated
```

If `docmost-cli` is absent or auth fails, tell the user to run
`docmost-cli auth login --instance <docmost_url> --token <api-key>`. Until the wiki is
reachable, **WARN** before treating any local file as authoritative — never silently
demote the wiki to the filesystem.

**Read (the primary path — do this before local reads):**

```bash
docmost-cli cache sync --space <docmost_space>                                  # before any read (exit 3 CACHE_STALE → re-sync)
docmost-cli ai ask "<question>" --output json                                   # cited RAG answer over the wiki (workspace-scoped, no --space)
docmost-cli search "<topic>" --cached --content --space <docmost_space> --output json   # FTS5 body search
docmost-cli page get <slug> --output json                                       # full node + native metadata (status, doc_type, …)
```

Prefer `skill:doc-read-first`, which resolves the living manual node (root + IA path),
status-filtered (drafts/superseded/archived are excluded from grounding reads). Use
`ai ask` to answer a factual question about the project rather than guessing or relying
on possibly-stale local context; if it returns no citations or `SEARCH_MODE_UNAVAILABLE`,
fall back to `search` + `page get`.

**Write (find-before-create → amend-in-place → draft):** route authoring through
`skill:doc-amend` (find-before-create across drafts AND canonical, ask one question on
ambiguity, amend only the affected sections in place, current-state-only body, land at
draft). Walk `data/decision-order.md` for the full routing tree. Never
`page create --status canonical`; never spawn a dated sibling.

## When in doubt

Consult, in order: `skill:doc-session-policy` (the 7 principles + tiering), then
`data/decision-order.md` (the routing tree), then `data/docmost-cli-reference.md` (the CLI
reference). These — not session memory — are the authoritative sources for any routing
decision.
