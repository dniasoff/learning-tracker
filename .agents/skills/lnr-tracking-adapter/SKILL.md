---
name: lnr-tracking-adapter
description: "Tracking system adapter. Routes create/update/read operations for issues, project-milestones, cycles, and work status to Linear via the linearis CLI (with the repo-local .cache/linear/ cache as the canonical read source). Loaded by the 5 implementation workflows when tracking_system=linear."
---

# lnr-tracking-adapter

This skill is the sole dispatch layer between BMAD implementation workflows and Linear. When `tracking_system=linear`, all issue/milestone/cycle/status operations in `bmad-create-story`, `bmad-dev-story`, `bmad-sprint-planning`, `bmad-sprint-status`, and `bmad-correct-course` route through this adapter instead of writing local files.

**Model mapping (no epics):** a BMAD epic is a Linear **project-milestone** (a `ProjectMilestone` inside the project, not a parent `[Epic N]` issue); a BMAD story is a Linear **issue** tagged to its milestone via the issue's `projectMilestone` field (and to the project); a story sub-task is a **sub-issue** (parent/child via `parentId`); a BMAD sprint is a Linear **cycle** (a ~1-week team time-box, orthogonal to the milestone hierarchy). Dependency "waves" are not a Linear entity — they are issue labels (e.g. `Wave 0`) plus blocked-by relations and milestone target-date order. Legacy projects may still carry `Epic N` parent issues (e.g. `ENG-433`); in this model those function as the milestone **spec** issue, not the delivery container — the project-milestone is the container.

**Wiring note:** The 5 stock SKILL.md files in 6.8 do not yet read `tracking_system` — that conditional gate is added by `_bmad/lnr/bin/apply-patch.sh`. The field is set in the override TOMLs so it is ready the moment the patch fires.

## Rationale: linearis writes, cache reads

- **Writes use the `linearis` CLI directly** — creates and status updates must be real-time; a stale local file cannot confirm the write landed.
- **Reads use the repo-local cache** — Linear's API rate limits and token costs make direct reads expensive in parallel agent sessions. The `linear-sync.sh` cache is the single source of truth for reads.

All dispatch happens through the `linearis` CLI; the Linear MCP is not used. `linearis` covers every operation BMAD needs (create, update, read, list, search, comment) and accepts identifiers (`ENG-42`), team keys (`ENG`), and status names directly — no state-UUID resolution dance required.

Cache root: repo-relative `.cache/linear/` inside the working project (gitignored; mirrors how docmost-cli links docs to `.cache/docs`). Not `.linear-cache`, not an XDG path.

Key files:

| File | Contents |
|------|----------|
| `work-status.yaml` | Index of milestones + issues, map-keyed by Linear identifier, with current statuses (each issue carries its own `cycle` + `kind` — there is no top-level cycles block) |
| `issues/<ID>.yaml` | Full issue detail including description + comments |
| `.last-sync` | ISO-8601 timestamp of last full sync |

Status-file virtual path (for `status_file` references): `linear://{linear_scope}/work-status`, where `{linear_scope}` resolves to the required `linear_initiative` config key. This is a display namespace, not a live scope query. A config with only the legacy `linear_project` key (no `linear_initiative`) is refused at run time — see the config block below.

---

## Cache freshness gate (applies before every read operation)

```bash
_bmad/lnr/tools/linear-sync.sh check
```

If output indicates **cache absent** or **cache stale** (> 30 min):

```bash
_bmad/lnr/tools/linear-sync.sh sync
```

Wait for sync to complete before proceeding. The sync command requires the `linearis` CLI on PATH; install with `npm i -g linearis` and authenticate with `linearis auth login`.

---

## Operations

### `create_issue(title, description, team_key, project, labels=[], parent_id=None, assignee=None, status=None)`

Create an issue in Linear (optionally tagged to a project-milestone; a sub-task is a sub-issue via `parentId`).

```bash
linearis issues create "<title>" \
  --team <team_key> \
  --project "<project>" \
  --description "<description>" \
  --labels "<comma,separated,labels>" \
  --parent-ticket <parent_id> \
  --assignee <assignee> \
  --status "<status>"
```

Omit any flag whose value is empty/None. `--team` is required; everything else is optional. `--project` accepts the project **NAME** (or UUID) — **not** the slug (linearis rejects a slug with `Project "<x>" not found`); `--parent-ticket` accepts an identifier like `ENG-10` and makes the new issue a sub-issue (the `parentId` relation); `--assignee` accepts user ID, name, email, or `me`; `--status` accepts the status name as shown in Linear's workflow.

To tag the issue to a project-milestone (the `projectMilestone` field — the BMAD-epic equivalent), set the milestone at create time or in a follow-up update. (transport: verify the linearis/Linear flag; project-milestone assignment may require the Linear UI or a future linear-cli verb.)

Capture the returned `identifier` (e.g., `ENG-42`) for the caller. Then refresh the cache:

```bash
_bmad/lnr/tools/linear-sync.sh issue <RETURNED-IDENTIFIER>
```

---

### `update_status(issue_id, new_status)`

Move an issue to a new workflow state.

```bash
linearis issues update <issue_id> --status "<new_status>"
_bmad/lnr/tools/linear-sync.sh issue <issue_id>
```

`--status` accepts the state name (e.g., `"In Progress"`, `"Todo"`, `"Done"`). The state name must match a state configured in the team's workflow; consult `data/linear-mapping-template.yaml` `status_map` for the BMAD → Linear name mapping.

---

### `add_comment(issue_id, body)`

Append a discussion comment to an existing issue.

```bash
linearis issues discuss <issue_id> --body "<body>"
```

Use literal newlines in `--body`; markdown is supported. No cache refresh needed — `work-status.yaml` does not include comments. If the issue's `.yaml` detail file must include the new comment, optionally run:

```bash
_bmad/lnr/tools/linear-sync.sh issue <issue_id>
```

---

### `set_baseline_commit(issue_id, sha)`

Record a `baseline_commit` SHA against a Linear issue. Posted as a discussion comment so the value is preserved without read-modify-write of the issue description.

```bash
linearis issues discuss <issue_id> --body "baseline_commit: <sha>"
```

To retrieve later, scan the issue's discussions (in the cached issue YAML) for a `baseline_commit:` prefix; the most recent value wins.

---

### `list_issues(team_key, status=None, project=None, limit=N)`

Return issues from the local cache. **Never call `linearis issues list` directly during a session-policy-active workflow** — go via the cache.

1. Check freshness:
   ```bash
   _bmad/lnr/tools/linear-sync.sh check
   ```

2. If stale or absent, sync first:
   ```bash
   _bmad/lnr/tools/linear-sync.sh sync
   ```

3. Read:
   ```
   .cache/linear/work-status.yaml
   ```

4. Filter by `status` and/or `project` in the parsed YAML. Apply `limit` to truncate results.

The `work-status.yaml` schema written by `linear-sync.sh sync` (the legacy single-project scope — see note below):

```yaml
synced_at: "<ISO-8601>"
team_key: ENG
linear_project: <project_display_name>   # example placeholder — NOT a real project name
project: <project_display_name>

milestones:
  <milestone-uuid>:
    name: "Foundation & the 8 adapter ops"
    target_date: 2026-07-11

issues:
  ENG-42:
    title: "Story 1.2 — issue get"
    status: Todo
    kind: story            # story | epic | other (tracking/meta)
    milestone: <milestone-uuid>   # the issue's projectMilestone.id, or "none"
    cycle: 12              # cycle number, or "none"
  ENG-890:
    title: "Sibling-alignment audit …"
    status: Todo
    kind: other            # a tracking issue — cached, but board views filter it out
    milestone: none
    cycle: none
```

Top-level keys: `synced_at`, `team_key`, `linear_project`, `project`. (`work-status.yaml` is produced only by the legacy single-project `sync` command, which requires `linear_project`; it does not carry `linear_initiative` or a `scope` key. `sync-initiative` writes the separate `initiative.json` cache file instead — see the sync-initiative subcommand.) The `milestones` and `issues` blocks are maps — not lists. A `milestones` entry is keyed by the **project-milestone UUID** and carries `name` + `target_date` (sourced from `linearis milestones list`). An `issues` entry is keyed by Linear identifier and carries `title`, `status`, `kind`, `milestone` (its `projectMilestone` UUID, or `none`), and `cycle` (number, or `none`). **Every issue in the project is cached** — stories, epics, AND tracking/meta issues — distinguished by `kind`; board / sprint views should filter `kind: story` (or degrade cleanly). (Cycle is a per-issue field, not a separate top-level block; a sub-issue `parent` is not currently emitted.)

---

### `get_issue(issue_id)`

Return full issue detail from cache.

1. Check freshness gate (same as `list_issues`).
2. Read:
   ```
   .cache/linear/issues/<issue_id>.yaml
   ```

3. If the file is missing (issue was created after last sync), fetch it:
   ```bash
   _bmad/lnr/tools/linear-sync.sh issue <issue_id>
   ```
   Then re-read the file.

The per-issue YAML includes `identifier`, `title`, `status`, `kind` (`story` | `epic` | `other` — `other` = tracking/meta issues), `milestone` (its `projectMilestone` UUID, or `none`), `cycle` (number, or `none`), `description`, and `comments` (rendered from the issue's `.comments.nodes`; `[]` when none).

---

### `get_user(query)`

Resolve a user by name, email, or identifier. Cache-first:

- If the user identifier is already known from a previous `create_issue` response or the work-status cache, use it directly.

Fallback — list workspace members and filter:

```bash
linearis users list | jq '.[] | select(.name == "<query>" or .email == "<query>" or .id == "<query>")'
```

Cache the resolved id for the current session.

---

### `get_team(team_key)`

```bash
linearis teams read <team_key>
```

Returns the team's id, name, key, and workflow states. Useful when bootstrapping a project to verify the configured `team_key` resolves.

---

## Error handling

- If `linearis` returns non-zero, log the stderr verbatim and halt with a clear error message naming which operation failed, the issue id (if applicable), and the raw error. Do not silently continue — Linear is canonical; partial writes are worse than halt.
- If the cache is corrupt or unreadable, run `_bmad/lnr/tools/linear-sync.sh sync` and retry once. If sync also fails, halt loud.
- If `linearis` is not on PATH at all, halt with: `ERROR: linearis CLI not installed. Run: npm i -g linearis && linearis auth login`.
