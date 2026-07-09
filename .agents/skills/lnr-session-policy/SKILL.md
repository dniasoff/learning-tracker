---
name: lnr-session-policy
description: "Loaded when bmad-linear active. Steers reads to the repo-local .cache/linear/ cache; routes writes through the linearis CLI via lnr-tracking-adapter."
---

# bmad-linear Session Policy

This skill is automatically active when the `bmad-linear` module is installed. It governs how all BMAD agents interact with Linear data during a session.

## Wiki-first for documentation & specs (when bmad-docmost is installed)

Linear is the system of record for **work items** (issues, project-milestones, cycles). It is **not** the source of truth for **documentation, specs, or project knowledge** — that is the living Docmost wiki, owned by `bmad-docmost`.

When both modules are installed, the wiki is the **primary source of truth and outranks local files** for any plan/design/spec/knowledge question, in workflows *and* free-form chat. Before establishing project state or "ground truth" from local files, resolve the wiki first (`skill:doc-read-first`, or `docmost-cli ai ask "<question>" --output json`). The full doctrine + access commands live in `{project-root}/_bmad/doc/data/wiki-first-mandate.md`; the constitution is `skill:doc-session-policy`. Implementation does not proceed without a human-confirmed wiki intent node for the work item (the wiki-first spec gate, `skill:doc-spec-gate`, honouring `wiki_first_enforcement`). If `bmad-docmost` is not installed, this section is inactive.

## Read Policy — Cache-Only

**NEVER** call `linearis issues list`, `linearis issues read`, `linearis issues search`, or any other read command directly for routine workflow reads. Direct reads bypass the cache, rack up API quota, and produce stale views the next agent in the session won't share.

**ALWAYS** read Linear data from the repo-local cache (gitignored) at:

```
.cache/linear/
```

Key cache files:

| File | Contents |
|------|----------|
| `work-status.yaml` | Index: milestones → issues with current statuses, plus current/next cycles (maps keyed by Linear identifier) |
| `issues/<ID>.yaml` | Full issue detail including description and comments |
| `.last-sync` | ISO-8601 timestamp of last full sync |

## Cache Freshness Gate

Before reading from the cache, check whether it is fresh:

```bash
_bmad/lnr/tools/linear-sync.sh check
```

If the output indicates **cache absent** or **cache stale** (older than 30 minutes):

```bash
_bmad/lnr/tools/linear-sync.sh sync
```

Wait for sync to complete before proceeding with reads.

## Write Policy — linearis via lnr-tracking-adapter

Writes go through `lnr-tracking-adapter`, which dispatches the `linearis` CLI. Do not invoke `linearis issues create/update/discuss` directly from workflow steps — go through the adapter so the cache refresh after each write happens uniformly. (transport: verify the linearis/Linear flag; project-milestone assignment may require the Linear UI or a future linear-cli verb.)

Permitted write paths (all via adapter):

| Adapter op | linearis command |
|------------|------------------|
| `create_issue` | `linearis issues create` |
| `update_status` | `linearis issues update --status` |
| `add_comment` | `linearis issues discuss` |
| `set_baseline_commit` | `linearis issues discuss --body "baseline_commit: <sha>"` |

After any write, the adapter refreshes the affected issue's cache entry. After structural changes (bulk creation, renames, milestone reassignments), run a full sync:

```bash
_bmad/lnr/tools/linear-sync.sh sync
```

## Linear is canonical — no local work-status files

When `tracking_system=linear`, BMAD does **not** write `work-status.yaml`, issue `.md` files, or work-item change proposal `.md` files to the project tree. Those artifacts live in Linear; the repo-local `.cache/linear/` is the read surface. The 5 patched implementation skills enforce this at the `<action>`/`<template-output>` level — see `_bmad/lnr/bin/apply-patch.sh`.

If a workflow needs a transient working draft, compose it in memory or in a scratch file outside the project tree. Never commit transient drafts to the project tree.

## When tracking_system != linear

This policy is **inactive**. All read and write behaviour follows stock BMAD (local `sprint-status.yaml` and story markdown files in the project tree). Do not reference this policy.

## Summary Table

| Operation | tracking_system=linear | tracking_system=file-system |
|-----------|----------------------|----------------------------|
| Read work/cycle status | `.cache/linear/work-status.yaml` | local `sprint-status.yaml` |
| Read issue detail | `.cache/linear/issues/<ID>.yaml` | local story `.md` file |
| Create issue / set status | adapter → `linearis` | local file write |
| Add comment | adapter → `linearis issues discuss` | append to local story file |
| Full refresh | `linear-sync.sh sync` | n/a |
