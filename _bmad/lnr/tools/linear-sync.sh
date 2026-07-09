#!/usr/bin/env bash
# linear-sync.sh — repo-local cache engine for bmad-linear.
# Uses the `linearis` CLI to fetch Linear data and writes a structured YAML cache
# at <project_root>/.cache/linear/ (gitignored, mirroring docmost-cli's .cache/docs).
# Model: Linear PROJECT holds project-MILESTONES (former epics); ISSUES tag to a
# milestone; CYCLES (former sprints) are orthogonal time-boxes. Every issue in the
# project is cached — stories AND tracking/epic/spec issues — with a `kind:` field
# so callers can slice (board views filter `kind: story`).
# Reads config from _bmad/lnr/config.yaml (or _bmad/bmm/config.yaml fallback).
set -euo pipefail

LINEAR_NOT_CONFIGURED=0
TRACKING_SYSTEM=""

# yaml_scalar <key> <file>: read a top-level YAML scalar value, stripping an inline `# comment`
# (YAML begins a comment at whitespace-then-`#`), surrounding quotes, and edge whitespace.
# WHY THIS EXISTS: the previous extractions (`grep|sed` for name-valued keys, `awk '{print $2}'`
# for single-token keys) did NOT strip inline comments, so a config line such as
#   linear_initiative: <uuid>   # "Orvex Studio" — scope note
# captured the WHOLE "<uuid>   # ... note" string as the value. That polluted value then failed
# the 36-char UUID test in cmd_sync_initiative (so the initiative filter keyed on `name`, not
# `id`) and matched NO initiative — the sync fetched ZERO in-scope open issues while the
# team-wide closed fetch still returned every Done/Canceled issue, and the run reported
# complete=true. Stripping the inline comment here kills that class of failure at the source.
yaml_scalar() {
  local key="$1" file="$2"
  # `|| true`: grep exits 1 when the key has NO matching line (absent, or commented-out —
  # e.g. `# linear_project: ...`), which is a legitimate "key not set" outcome, not an
  # error. Under `set -euo pipefail` an unguarded pipeline here would abort the WHOLE
  # script the instant any OPTIONAL scalar key is missing — every subcommand calls
  # resolve_config first, so this must never propagate as a fatal pipeline failure. The
  # comment-stripping / quote-stripping behavior (the f3c90fd fix target) is unaffected —
  # a matched line still runs through the full sed chain; only the "no match" case is
  # now non-fatal, yielding an empty string exactly as the pre-f3c90fd `|| true` extractions did.
  grep -E "^${key}:" "$file" 2>/dev/null | head -n1 \
    | sed -E "s/^${key}:[[:space:]]*//" \
    | sed -E 's/[[:space:]]+#.*$//; s/^#.*$//' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | sed -E "s/^(['\"])(.*)\\1\$/\\2/" \
    || true
}

# ---------- config resolution ----------
resolve_config() {
  # Walk up from cwd to find _bmad root
  local search="$PWD"
  local config_file=""
  PROJECT_ROOT=""
  while [[ "$search" != "/" ]]; do
    if [[ -f "$search/_bmad/lnr/config.yaml" ]]; then
      config_file="$search/_bmad/lnr/config.yaml"
      PROJECT_ROOT="$search"
      break
    elif [[ -f "$search/_bmad/bmm/config.yaml" ]]; then
      config_file="$search/_bmad/bmm/config.yaml"
      PROJECT_ROOT="$search"
      break
    fi
    search="$(dirname "$search")"
  done

  if [[ -z "$config_file" ]]; then
    echo "ERROR: Cannot find _bmad/lnr/config.yaml or _bmad/bmm/config.yaml in any parent directory of $PWD" >&2
    exit 1
  fi

  # All values go through yaml_scalar so inline `# comments` are stripped (see its header for
  # the failure this prevents). A commented-out line (`# linear_project: ...`) does not match
  # the `^key:` anchor, so it is correctly ignored.
  TEAM_KEY=$(yaml_scalar 'team_key' "$config_file")
  LINEAR_TENANT=$(yaml_scalar 'linear_tenant' "$config_file")
  LINEAR_PROJECT=$(yaml_scalar 'linear_project' "$config_file")
  LINEAR_INITIATIVE=$(yaml_scalar 'linear_initiative' "$config_file")
  PROJECT_NAME=$(yaml_scalar 'project_name' "$config_file")

  TRACKING_SYSTEM=$(yaml_scalar 'tracking_system' "$config_file")

  # Scope key: linear_initiative is REQUIRED for Linear mode. linear_project is a legacy
  # key that MAY still be set (an explicit single-project scope alongside the initiative,
  # e.g. for the legacy `sync` command), but it can no longer stand in for linear_initiative.
  # A config carrying linear_project WITHOUT linear_initiative is a hard migration error —
  # PO decision 2026-07-09 (hard cut): no silent project-scoped fallback. Scoped to Linear
  # mode only — a file-system-tracked repo with a stray/uncommented legacy linear_project
  # key is not blocked; the gate only fires when tracking_system actually selects Linear.
  if [[ "$TRACKING_SYSTEM" == "linear" && -z "$LINEAR_INITIATIVE" && -n "$LINEAR_PROJECT" ]]; then
    echo "ERROR: config-level Linear scope binding is out of date." >&2
    echo "  '$config_file' sets the legacy key 'linear_project' but not 'linear_initiative'." >&2
    echo "  linear_project alone is no longer a valid scope binding — it will NOT silently" >&2
    echo "  fall back to project scope." >&2
    echo "" >&2
    echo "  Fix — add one line to $config_file:" >&2
    echo "    linear_initiative: <initiative-name-or-UUID>" >&2
    echo "" >&2
    echo "  See bmad-linear/README.md 'Linear tracking' config block for the full key set." >&2
    echo "  (Per-command explicit overrides, e.g. --project on a single command, are" >&2
    echo "  unaffected — only this config-level binding is retired.)" >&2
    exit 1
  fi

  if [[ -z "$TEAM_KEY" || -z "$LINEAR_TENANT" || -z "$LINEAR_INITIATIVE" ]]; then
    LINEAR_NOT_CONFIGURED=1
    return 0
  fi

  # Repo-local cache (gitignored), mirroring docmost-cli's .cache/docs link.
  # No longer XDG-rooted or keyed by tenant/slug — the cache lives beside the code.
  CACHE_DIR="$PROJECT_ROOT/.cache/linear"
}

# ensure_gitignore: idempotently keep ".cache/linear/" out of version control,
# mirroring how docmost-cli gitignores its .cache/docs link.
ensure_gitignore() {
  [[ -n "$PROJECT_ROOT" ]] || return 0
  local gitignore="$PROJECT_ROOT/.gitignore"
  local entry=".cache/linear/"
  if [[ -f "$gitignore" ]]; then
    grep -qxF "$entry" "$gitignore" && return 0
  fi
  printf '%s\n' "$entry" >> "$gitignore"
}

check_deps() {
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found in PATH (apt install jq / brew install jq)" >&2; exit 1; }
  command -v linearis >/dev/null 2>&1 || { echo "ERROR: linearis CLI not found. Install with: npm i -g linearis && linearis auth login" >&2; exit 1; }
}

# project_hint: actionable guidance for the recurring name-vs-slug failure.
# `linearis` resolves --project by NAME (or UUID), NOT by slug. The BMAD installer
# tends to write the slug into linear_project, which linearis rejects.
project_hint() {
  echo "  → linearis matches --project by NAME (or UUID), not by slug." >&2
  echo "    Set linear_project to the project's display NAME (e.g. \"Linear CLI\")" >&2
  echo "    in _bmad/lnr/config.yaml AND its installer source _bmad/config.toml." >&2
  echo "    (The BMAD installer may have written the slug '$LINEAR_PROJECT', which linearis rejects.)" >&2
}

# kind_expr: jq snippet classifying an issue by title → story | epic | other.
# `other` covers tracking/meta issues (e.g. a sibling-alignment audit) that are
# real project issues but not work stories.
KIND_EXPR='(if (.title|test("^Story \\d")) then "story" elif (.title|test("^Epic ")) then "epic" else "other" end)'

# fetch_all_issues: paginate `linearis issues list` via pageInfo.endCursor into a
# single combined JSON node-array at $1. Aborts (returns 1) on any error/odd shape
# WITHOUT having written the cache, so a partial fetch never clobbers a good cache.
fetch_all_issues() {
  local out="$1"
  local after="" page=0 max_pages=50
  local page_json page_err; page_json=$(mktemp); page_err=$(mktemp)
  printf '[]' > "$out"
  while :; do
    page=$((page + 1))
    if [[ $page -gt $max_pages ]]; then
      echo "ERROR: pagination exceeded $max_pages pages (cursor not advancing?) — aborting" >&2
      rm -f "$page_json" "$page_err"; return 1
    fi
    # stdout (JSON) and stderr (warnings) are kept SEPARATE — merging them would let a
    # linearis stderr line corrupt the JSON buffer and false-abort the sync.
    if [[ -z "$after" ]]; then
      linearis issues list --team "$TEAM_KEY" --project "$LINEAR_PROJECT" --limit 100 > "$page_json" 2>"$page_err" || true
    else
      linearis issues list --team "$TEAM_KEY" --project "$LINEAR_PROJECT" --limit 100 --after "$after" > "$page_json" 2>"$page_err" || true
    fi
    # Error / shape guard — abort the whole sync before writing anything.
    local err
    err=$(jq -r 'if type=="object" and has("error") then .error else empty end' "$page_json" 2>/dev/null || echo "PARSE_ERROR")
    if [[ -n "$err" ]]; then
      echo "ERROR: linearis issues list failed: $err" >&2
      project_hint
      rm -f "$page_json" "$page_err"; return 1
    fi
    if ! jq -e 'has("nodes")' "$page_json" >/dev/null 2>&1; then
      echo "ERROR: unexpected linearis response shape (no .nodes):" >&2
      head -c 300 "$page_json" >&2; echo >&2
      [[ -s "$page_err" ]] && { echo "  linearis stderr:" >&2; head -c 300 "$page_err" >&2; echo >&2; }
      rm -f "$page_json" "$page_err"; return 1
    fi
    jq -s '.[0] + (.[1].nodes // [])' "$out" "$page_json" > "$out.next" && mv "$out.next" "$out"
    local has_next end_cursor
    has_next=$(jq -r '.pageInfo.hasNextPage // false' "$page_json")
    end_cursor=$(jq -r '.pageInfo.endCursor // empty' "$page_json")
    [[ "$has_next" == "true" && -n "$end_cursor" ]] || break
    after="$end_cursor"
  done
  rm -f "$page_json" "$page_err"
  return 0
}

# ---------- sync ----------
cmd_sync() {
  if [[ "${LINEAR_NOT_CONFIGURED:-0}" == "1" ]]; then
    echo "ERROR: Linear not configured — set tracking_system: linear, linear_tenant, linear_initiative, team_key in config" >&2
    exit 1
  fi
  if [[ -z "${LINEAR_PROJECT:-}" ]]; then
    echo "ERROR: 'sync' is the legacy single-project refresh and needs linear_project. You have linear_initiative set — use: linear-sync.sh sync-initiative" >&2
    exit 1
  fi
  check_deps
  ensure_gitignore
  mkdir -p "$CACHE_DIR/issues"

  echo "Syncing Linear issues for project \"$LINEAR_PROJECT\" (team $TEAM_KEY)..."

  local tmpfile ms_tmpfile
  tmpfile=$(mktemp)
  ms_tmpfile=$(mktemp)

  # Fetch ALL issues (paginated, all kinds). Abort before writing on any failure.
  if ! fetch_all_issues "$tmpfile"; then
    rm -f "$tmpfile" "$ms_tmpfile"
    echo "Sync aborted — existing cache left untouched." >&2
    exit 1
  fi

  # Fetch project-milestones separately (they are not issues). stdout (JSON) and
  # stderr (warnings) kept SEPARATE so a linearis stderr line can't corrupt the JSON.
  local ms_err; ms_err=$(mktemp)
  if ! linearis milestones list --project "$LINEAR_PROJECT" > "$ms_tmpfile" 2>"$ms_err" \
     || jq -e 'if type=="object" and has("error") then true else false end' "$ms_tmpfile" >/dev/null 2>&1; then
    echo "ERROR: linearis milestones list failed:" >&2
    head -c 300 "$ms_tmpfile" >&2; echo >&2
    [[ -s "$ms_err" ]] && { echo "  linearis stderr:" >&2; head -c 300 "$ms_err" >&2; echo >&2; }
    project_hint
    rm -f "$tmpfile" "$ms_tmpfile" "$ms_err"
    echo "Sync aborted — existing cache left untouched." >&2
    exit 1
  fi
  rm -f "$ms_err"
  # Normalise milestones to a bare array ({nodes,…} OR a bare array OR error-guarded above).
  jq '.nodes // .' "$ms_tmpfile" > "$ms_tmpfile.arr" && mv "$ms_tmpfile.arr" "$ms_tmpfile"

  _process_issues "$tmpfile" "$ms_tmpfile"
  rm -f "$tmpfile" "$ms_tmpfile"
}

_process_issues() {
  local tmpfile="$1"   # combined bare array of ALL issue nodes
  local ms_tmpfile="$2"
  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local ws_tmp="$CACHE_DIR/work-status.yaml.tmp"

  {
    echo "synced_at: \"$synced_at\""
    echo "team_key: $TEAM_KEY"
    echo "linear_project: $LINEAR_PROJECT"
    echo "project: ${PROJECT_NAME:-$LINEAR_PROJECT}"
    echo ""
    echo "milestones:"

    # Real project-milestones from linearis milestones list, keyed by UUID.
    jq -r '
      sort_by(.targetDate // "9999") |
      .[] |
      "  " + .id + ":\n" +
      "    name: " + (.name | @json) + "\n" +
      "    target_date: " + (.targetDate // "null")
    ' "$ms_tmpfile"

    echo ""
    echo "issues:"

    # ALL issues (stories + epics + tracking/meta), keyed by Linear identifier,
    # sorted by issue number. `kind:` classifies; `milestone:`=projectMilestone.id.
    jq -r '
      def kind: '"$KIND_EXPR"';
      sort_by(.identifier | split("-") | last | tonumber) |
      .[] |
      "  " + .identifier + ":\n" +
      "    title: " + (.title | @json) + "\n" +
      "    status: " + .state.name + "\n" +
      "    kind: " + kind + "\n" +
      "    milestone: " + (.projectMilestone.id // "none") + "\n" +
      "    cycle: " + ((.cycle.number // empty | tostring) // "none")
    ' "$tmpfile"
  } > "$ws_tmp"
  mv "$ws_tmp" "$CACHE_DIR/work-status.yaml"

  local issue_count=0
  while IFS= read -r issue; do
    local id
    id=$(echo "$issue" | jq -r '.identifier')
    echo "$issue" | jq -r '
      def kind: '"$KIND_EXPR"';
      "identifier: " + .identifier,
      "title: " + (.title | @json),
      "status: " + .state.name,
      "kind: " + kind,
      "milestone: " + (.projectMilestone.id // "none"),
      "cycle: " + ((.cycle.number // empty | tostring) // "none"),
      (if (.description // "") == "" then "description: \"\""
       else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
       end)
    ' > "$CACHE_DIR/issues/$id.yaml"
    issue_count=$((issue_count + 1))
  done < <(jq -c '.[]' "$tmpfile")

  echo "$synced_at" > "$CACHE_DIR/.last-sync"

  local milestone_count
  milestone_count=$(jq 'length' "$ms_tmpfile")

  echo "Synced $milestone_count milestones, $issue_count issues to $CACHE_DIR/"
  echo "  work-status.yaml updated"
  echo "  $issue_count issue files written to issues/"
}

# ---------- issue (single-issue refresh; `story` kept as an alias) ----------
cmd_issue() {
  if [[ "${LINEAR_NOT_CONFIGURED:-0}" == "1" ]]; then
    echo "ERROR: Linear not configured — set tracking_system: linear, linear_tenant, linear_initiative, team_key in config" >&2
    exit 1
  fi
  check_deps
  ensure_gitignore
  local issue_id="$1"
  mkdir -p "$CACHE_DIR/issues"

  echo "Refreshing $issue_id..."
  local json err_file; err_file=$(mktemp)
  # stdout (JSON) captured to $json; stderr to $err_file so a warning can't corrupt the JSON.
  # --with-comments: the refresh-on-write cache model makes this file the ONLY read surface
  # for the ticket — agents need the discussion thread too.
  if ! json=$(linearis issues read "$issue_id" --with-comments 2>"$err_file") \
     || jq -e 'if type=="object" and has("error") then true else false end' <<<"$json" >/dev/null 2>&1; then
    echo "ERROR: linearis issues read $issue_id failed:" >&2
    head -c 300 <<<"$json" >&2; echo >&2
    [[ -s "$err_file" ]] && { echo "  linearis stderr:" >&2; head -c 300 "$err_file" >&2; echo >&2; }
    rm -f "$err_file"
    exit 1
  fi
  rm -f "$err_file"
  _write_issue_file "$issue_id" "$json"
}

_write_issue_file() {
  local issue_id="$1"
  local json="$2"

  local status
  status=$(echo "$json" | jq -r '.state.name')

  echo "$json" | jq -r '
    def kind: '"$KIND_EXPR"';
    "identifier: " + .identifier,
    "title: " + (.title | @json),
    "status: " + .state.name,
    "kind: " + kind,
    "milestone: " + (.projectMilestone.id // "none"),
    "cycle: " + ((.cycle.number // empty | tostring) // "none"),
    (if (.description // "") == "" then "description: \"\""
     else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
     end),
    # Comments live under .comments.nodes (an object with a nodes[] array), NOT a
    # bare array. Author/body access is defensive (shape varies across linearis versions).
    (if ((.comments.nodes // []) | length) == 0 then "comments: []"
     else "comments:\n" + ([.comments.nodes[] |
       "  - author: " + ((.user.name // .user.displayName // .user.email // "unknown") | @json) + "\n" +
       "    body: |\n" + ((.body // "") | split("\n") | map("      " + .) | join("\n"))] | join("\n"))
     end)
  ' > "$CACHE_DIR/issues/$issue_id.yaml"

  if [[ -f "$CACHE_DIR/work-status.yaml" ]]; then
    # ENG-1254: concurrent `issue <id>` refreshes race on this read-modify-write.
    # Fix has two parts: (1) a per-invocation unique tmp file via mktemp, so a
    # racing `mv` never finds the file already renamed away by another process
    # ("mv: cannot stat ..."); and (2) an flock around the whole read-modify-write
    # so concurrent refreshes serialize instead of clobbering each other's status
    # edits (lost-update) — a unique tmp alone stops the crash but NOT the race
    # where two processes both read the pre-edit file and the second's write wins
    # with stale data for every OTHER issue's status.
    local ws_tmp ws_lock
    ws_tmp=$(mktemp "$CACHE_DIR/work-status.yaml.XXXXXX")
    ws_lock="$CACHE_DIR/.work-status.lock"
    (
      trap 'rm -f "$ws_tmp"' EXIT
      flock 200
      awk -v id="$issue_id" -v new_status="$status" '
        $0 ~ "^  " id ":" { found=1; print; next }
        found && /^    status:/ { print "    status: " new_status; found=0; next }
        { print }
      ' "$CACHE_DIR/work-status.yaml" > "$ws_tmp"
      mv "$ws_tmp" "$CACHE_DIR/work-status.yaml"
    ) 200>"$ws_lock"
  fi

  # Refresh-on-write cache model: also update initiative.json (the delivery engines'
  # state/graph cache) so LOCAL frontier recomputes see this ticket's new state with
  # zero API calls — including ACROSS partitioned engines (A's Done unblocks B's
  # successors). flock serializes concurrent refreshes from two engines; the state
  # AND the blockedBy/blocks edges are updated from the same live read.
  local init="$CACHE_DIR/initiative.json"
  if [[ -f "$init" ]]; then
    (
      flock -x 9
      jq --arg id "$issue_id" --arg st "$status" \
         --argjson bb "$(echo "$json" | jq '[.inverseRelations.nodes[]? | select(.type=="blocks") | .issue.identifier] | unique')" \
         --argjson bl "$(echo "$json" | jq '[.relations.nodes[]? | select(.type=="blocks") | .relatedIssue.identifier] | unique')" \
         'if .issues[$id] then (.issues[$id].state = $st | .issues[$id].blockedBy = $bb | .issues[$id].blocks = $bl) else . end' \
         "$init" > "$init.tmp.$$" && mv "$init.tmp.$$" "$init"
    ) 9>"$init.lock"
  fi

  echo "Refreshed $issue_id (status: $status)"
}

# ---------- update ----------
cmd_update() {
  if [[ "${LINEAR_NOT_CONFIGURED:-0}" == "1" ]]; then
    echo "ERROR: Linear not configured — set tracking_system: linear, linear_tenant, linear_initiative, team_key in config" >&2
    exit 1
  fi
  check_deps
  local issue_id="$1"
  shift

  local status=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$status" ]]; then
    echo "ERROR: --status is required" >&2
    echo "Usage: linear-sync.sh update <ID> --status <state>" >&2
    exit 1
  fi

  echo "Updating $issue_id to status '$status' in Linear..."
  linearis issues update "$issue_id" --status "$status"
  cmd_issue "$issue_id"
}

# ---------- check ----------
cmd_check() {
  if [[ "${LINEAR_NOT_CONFIGURED:-0}" == "1" ]]; then
    echo "linear tracking not active (tracking_system: ${TRACKING_SYSTEM:-file-system}) — set tracking_system: linear in config to enable"
    exit 0
  fi

  if [[ ! -f "$CACHE_DIR/.last-sync" ]]; then
    echo "cache absent — run: _bmad/lnr/tools/linear-sync.sh sync"
    exit 0
  fi

  local last_sync
  last_sync=$(cat "$CACHE_DIR/.last-sync")

  local last_epoch now_epoch age_minutes
  last_epoch=$(date -d "$last_sync" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$last_sync" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  age_minutes=$(( (now_epoch - last_epoch) / 60 ))

  if [[ $age_minutes -gt 30 ]]; then
    echo "cache stale ($age_minutes min old) — run: _bmad/lnr/tools/linear-sync.sh sync"
    exit 0
  fi

  echo "cache fresh ($age_minutes min old) — $CACHE_DIR"
  exit 0
}

# ---------- initiative sync (whole-team, ALL states + blocked-by graph) ----------
# The delivery engine needs the WHOLE initiative (all projects under it — one team),
# INCLUDING Done (which `issues list` excludes by default), plus each candidate's
# blocked-by edges. The linearis list payload already carries state, labels, project,
# milestone, updatedAt, AND populated relations/inverseRelations — so the entire
# frontier is a handful of paginated list calls with ZERO per-issue reads (a naive
# frontier that did a per-project live sweep + a per-candidate live relation read
# every tick would drain the shared hourly quota). Output: .cache/linear/initiative.json
# — a slim, jq-friendly projection keyed by identifier. Deliberately does NOT touch
# work-status.yaml / issues/*.yaml (those stay owned by the single-project `sync`).

# ============================================================================
# Direct-GraphQL initiative fetch (replaces the linearis `issues list` path for
# cmd_sync_initiative ONLY — every other command still uses linearis).
#
# WHY: `linearis issues list` issues ONE HTTP request per page (dist/services/
# issue-service.js listIssues → GraphQLClient.request → @linear/sdk rawRequest — NO
# per-issue fan-out), BUT the fixed `CompleteIssueFields` fragment (dist/gql/gql.js)
# requests FOUR UNBOUNDED nested connections — labels.nodes, children.nodes,
# relations.nodes, inverseRelations.nodes — with no `first:` cap. Linear's rate limiter
# is COMPLEXITY-metered: a `first:100` page × ~4 nested connections (default ~50 each)
# scores ~tens-of-thousands of complexity and debits ~hundreds of "request-equivalents"
# from the hourly bucket. Empirically a naive team-wide Done pass can die after only a
# handful of such fat requests. PLUS each filtered `issues list` invocation silently
# runs a BatchResolveForSearch request first (dist/common/resolve-filters.js:61).
#
# FIX: talk to https://api.linear.app/graphql directly with the SAME token linearis uses,
# with (A) an ACTIVE query whose nested connections are BOUNDED `first:50`, and (B) a SLIM
# CLOSED query with ZERO nested connections — collapsing per-page complexity to ~O(1)
# request-equivalents. Server-side team + state (+ optional project/initiative) filters
# replace the BatchResolve round-trip. Output contract (initiative.json + per-issue YAML)
# is unchanged.
# ============================================================================
LINEAR_GQL_ENDPOINT="https://api.linear.app/graphql"

# resolve_linear_token: mirror linearis' token precedence for the token that is OPERATIVE
# in this environment. dist/common/auth.js resolves: --api-token flag > $LINEAR_API_TOKEN >
# encrypted stored (~/.config/linearis/token) > legacy plaintext (~/.linear_api_token).
# The encrypted stored token cannot be read from bash; if linearis on a given box already
# falls back to the legacy plaintext file (it prints the "~/.linear_api_token is
# deprecated" warning on every call), that file IS the live token. Precedence here: env,
# then legacy.
resolve_linear_token() {
  if [[ -n "${LINEAR_API_TOKEN:-}" ]]; then
    LINEAR_TOKEN="$LINEAR_API_TOKEN"; return 0
  fi
  if [[ -f "$HOME/.linear_api_token" ]]; then
    LINEAR_TOKEN="$(tr -d '[:space:]' < "$HOME/.linear_api_token")"
    [[ -n "$LINEAR_TOKEN" ]] && return 0
  fi
  echo "ERROR: no Linear API token — set \$LINEAR_API_TOKEN or create ~/.linear_api_token" >&2
  return 1
}

# LAST_RATELIMIT_HEADERS: the raw "name: value" rate-limit/complexity header lines captured
# from the MOST RECENT gql_post response. Callers append it to error messages so every
# failure carries the real budget numbers. Reset to empty by each gql_post.
LAST_RATELIMIT_HEADERS=""

# sync_log_path: where the per-call rate-limit budget line is appended. Lives beside the
# cache when configured; falls back to a temp file otherwise (e.g. the `quota` probe before
# a cache exists). Never fatal.
sync_log_path() {
  if [[ -n "${CACHE_DIR:-}" ]]; then
    printf '%s' "$CACHE_DIR/sync.log"
  else
    printf '%s' "${TMPDIR:-/tmp}/linear-sync.log"
  fi
}

# log_ratelimit_headers <raw-header-lines>: append ONE timestamped line carrying the raw
# Linear rate-limit / complexity headers (name+value) to the sync log, so every call's
# remaining budget is durably recorded. Best-effort — never fails the sync.
log_ratelimit_headers() {
  local headers="$1"
  [[ -n "$headers" ]] || return 0
  local logf ts
  logf=$(sync_log_path)
  mkdir -p "$(dirname "$logf")" 2>/dev/null || true
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '%s ratelimit %s\n' "$ts" "$(printf '%s' "$headers" | tr '\n' ' ' | sed 's/  */ /g')" \
    >> "$logf" 2>/dev/null || true
}

# gql_post <query> <variables_json>: POST to Linear's GraphQL endpoint; raw response JSON
# to stdout. @linear/sdk sends the personal API key as a raw Authorization header (no
# "Bearer " prefix) — we mirror that. Returns non-zero only on curl/transport failure;
# GraphQL-level errors (rate limit, bad filter) surface as {errors:[...]} in the body.
# INSTRUMENTED: response headers are dumped via `curl -D` and every Linear rate-limit /
# complexity header (whatever x-ratelimit-* / x-complexity / retry-after the API returns)
# is captured to LAST_RATELIMIT_HEADERS and appended to the sync log — so the real request
# AND complexity budget (remaining/limit/reset) is recorded on EVERY call, and any future
# 429 carries the numbers that explain it.
gql_post() {
  local query="$1" vars="$2" body hdr rc
  body=$(jq -cn --arg q "$query" --argjson v "$vars" '{query:$q, variables:$v}') || return 1
  hdr=$(mktemp)
  curl -sS -X POST "$LINEAR_GQL_ENDPOINT" \
    -H "Authorization: $LINEAR_TOKEN" \
    -H "Content-Type: application/json" \
    -D "$hdr" \
    --max-time 45 \
    --data-binary "$body"
  rc=$?
  # Grep the rate-limit / complexity headers case-insensitively (HTTP/2 lowercases them;
  # HTTP/1.1 may not) and strip CRs. We log whatever Linear actually returns rather than
  # hardcoding names, so a rename or an added complexity header still lands in the log.
  # `|| true`: grep exits 1 when NO rate-limit header is present (e.g. an edge/CDN 429); that
  # must not abort the caller under set -e/pipefail — an empty capture is a valid outcome.
  LAST_RATELIMIT_HEADERS=$(grep -iE '^(x-ratelimit-|x-complexity|retry-after)' "$hdr" 2>/dev/null | tr -d '\r' || true)
  rm -f "$hdr"
  log_ratelimit_headers "$LAST_RATELIMIT_HEADERS"
  return $rc
}

# gql_paginate <out> <query> <base_vars_json> <page_size>: drain issues(...) pagination via
# pageInfo.endCursor into a combined bare node-array at <out>. `first`/`after` are injected
# per page (the caller's base vars carry only `filter`). Returns 1 on any transport / GraphQL
# error / odd shape, LEAVING whatever nodes were accumulated in <out> (so a non-fatal Done
# caller can keep the partial). Never writes the caller's cache — only <out>.
gql_paginate() {
  local out="$1" query="$2" base_vars="$3" page_size="$4"
  local after="" page=0 max_pages=200
  local resp; resp=$(mktemp)
  printf '[]' > "$out"
  while :; do
    page=$((page + 1))
    if [[ $page -gt $max_pages ]]; then
      echo "ERROR: pagination exceeded $max_pages pages (cursor not advancing?) — aborting" >&2
      rm -f "$resp"; return 1
    fi
    local vars
    vars=$(echo "$base_vars" | jq -c --argjson first "$page_size" --arg after "$after" \
      '. + {first:$first, after: (if $after=="" then null else $after end)}') || { rm -f "$resp"; return 1; }
    if ! gql_post "$query" "$vars" > "$resp" 2>/dev/null; then
      echo "ERROR: GraphQL transport failure (curl) on page $page" >&2
      rm -f "$resp"; return 1
    fi
    local gqlerr
    gqlerr=$(jq -r 'if (.errors|type)=="array" then (.errors[0].message // "unknown") else empty end' "$resp" 2>/dev/null || echo "PARSE_ERROR")
    if [[ -n "$gqlerr" ]]; then
      echo "ERROR: Linear GraphQL error on page $page: $gqlerr" >&2
      [[ -n "$LAST_RATELIMIT_HEADERS" ]] && { echo "  rate-limit budget at failure:" >&2; printf '%s\n' "$LAST_RATELIMIT_HEADERS" | sed 's/^/    /' >&2; }
      rm -f "$resp"; return 1
    fi
    if ! jq -e '.data.issues | has("nodes")' "$resp" >/dev/null 2>&1; then
      echo "ERROR: unexpected GraphQL response shape (no .data.issues.nodes) on page $page:" >&2
      head -c 300 "$resp" >&2; echo >&2
      rm -f "$resp"; return 1
    fi
    jq '.data.issues.nodes' "$resp" > "$resp.nodes"
    jq -s '.[0] + .[1]' "$out" "$resp.nodes" > "$out.next" && mv "$out.next" "$out"
    rm -f "$resp.nodes"
    local has_next end_cursor
    has_next=$(jq -r '.data.issues.pageInfo.hasNextPage // false' "$resp")
    end_cursor=$(jq -r '.data.issues.pageInfo.endCursor // empty' "$resp")
    [[ "$has_next" == "true" && -n "$end_cursor" ]] || break
    after="$end_cursor"
  done
  rm -f "$resp"
  return 0
}

# Query A — ACTIVE issues (state type NOT completed/canceled). Nested connections are
# BOUNDED first:50 and each carries its OWN `pageInfo { hasNextPage }` so first-page
# truncation is DETECTABLE (never silent). The caps are SMALL on purpose: a big bulk cap
# multiplies per-page complexity substantially and can rate-limit on PAGE 1 of a thin quota
# window. Because resolve_overflow/drain_connection below re-fetch ANY connection reporting
# hasNextPage=true to exhaustion per issue, small caps + drains for the rare outlier is
# strictly cheaper than a large bulk cap paid on every page:
#   * relations / inverseRelations at first:50 — observed blockedBy fan-out is small in
#     practice, so drains fire for almost nothing; the tail is carried correctly by
#     drain_connection when it does.
#   * labels stays first:50 (issues typically carry only a handful) — still guarded.
#
# Per-issue complexity of THIS fragment under Linear's node-count model (connection first:N
# contributes N leaf nodes; a node with a 1:1 sub-object costs itself + the sub-object):
#     labels(50)            = 50
#     relations(50)         = 50 nodes + 50 relatedIssue = 100
#     inverseRelations(50)  = 50 nodes + 50 issue        = 100
#     scalars + 5 small 1:1 objects (state/project/projectMilestone/cycle/assignee) ≈ 10
#     ---------------------------------------------------------------
#     per issue ≈ 260  → budget with margin at ~300.
# The top-level issues(first: P) multiplies that by P, so page complexity ≈ P × 300.
# gql_paginate is called with P=25 (see cmd_sync_initiative) ⇒ worst case 25 × 300 = 7,500,
# a safe margin under Linear's per-request complexity hard cap.
GQL_ACTIVE='query ActiveIssues($first: Int!, $after: String, $filter: IssueFilter) {
  issues(first: $first, after: $after, filter: $filter, orderBy: updatedAt, includeArchived: false) {
    nodes {
      id
      identifier
      title
      description
      updatedAt
      state { name type }
      project { name }
      projectMilestone { id name }
      cycle { number }
      assignee { name }
      labels(first: 50) { nodes { name } pageInfo { hasNextPage } }
      relations(first: 50) { nodes { type relatedIssue { identifier } } pageInfo { hasNextPage } }
      inverseRelations(first: 50) { nodes { type issue { identifier } } pageInfo { hasNextPage } }
    }
    pageInfo { hasNextPage endCursor }
  }
}'

# Follow-up single-issue connection queries — used by drain_connection to paginate ONE
# nested connection of ONE issue to exhaustion when the list query flagged hasNextPage=true.
# Node shapes match GQL_ACTIVE exactly (so the drained set slots straight into projection);
# these carry endCursor because THEY are the paginating query.
GQL_LABELS_PAGE='query IssueLabels($id: String!, $first: Int!, $after: String) {
  issue(id: $id) {
    labels(first: $first, after: $after) { nodes { name } pageInfo { hasNextPage endCursor } }
  }
}'
GQL_RELATIONS_PAGE='query IssueRelations($id: String!, $first: Int!, $after: String) {
  issue(id: $id) {
    relations(first: $first, after: $after) { nodes { type relatedIssue { identifier } } pageInfo { hasNextPage endCursor } }
  }
}'
GQL_INVREL_PAGE='query IssueInverseRelations($id: String!, $first: Int!, $after: String) {
  issue(id: $id) {
    inverseRelations(first: $first, after: $after) { nodes { type issue { identifier } } pageInfo { hasNextPage endCursor } }
  }
}'

# drain_connection <issue_uuid> <connection>: paginate ONE nested connection of ONE issue
# to exhaustion via its follow-up query, printing the FULL node array (JSON) to stdout.
# Re-fetches the connection from the start (after=null) and returns the complete set — the
# caller REPLACES the (truncated) first-page nodes with this, avoiding any cursor-alignment
# assumption between the list query and the single-issue query. Returns 1 on any transport /
# GraphQL / shape error or if pagination fails to terminate; the caller then marks the cache
# complete=false so nested incompleteness is covered by the honesty bit.
drain_connection() {
  local id="$1" conn="$2"
  local query
  case "$conn" in
    labels)           query="$GQL_LABELS_PAGE" ;;
    relations)        query="$GQL_RELATIONS_PAGE" ;;
    inverseRelations) query="$GQL_INVREL_PAGE" ;;
    *) echo "ERROR: drain_connection: unknown connection '$conn'" >&2; return 1 ;;
  esac
  local after="" page=0 max_pages=200 acc resp
  acc='[]'
  resp=$(mktemp)
  while :; do
    page=$((page + 1))
    if [[ $page -gt $max_pages ]]; then
      echo "ERROR: drain_connection $conn: exceeded $max_pages pages (cursor not advancing?)" >&2
      rm -f "$resp"; return 1
    fi
    local vars
    vars=$(jq -cn --arg id "$id" --argjson first 250 --arg after "$after" \
      '{id:$id, first:$first, after: (if $after=="" then null else $after end)}') || { rm -f "$resp"; return 1; }
    if ! gql_post "$query" "$vars" > "$resp" 2>/dev/null; then
      echo "ERROR: drain_connection $conn: GraphQL transport failure on page $page" >&2
      rm -f "$resp"; return 1
    fi
    local gqlerr
    gqlerr=$(jq -r 'if (.errors|type)=="array" then (.errors[0].message // "unknown") else empty end' "$resp" 2>/dev/null || echo "PARSE_ERROR")
    if [[ -n "$gqlerr" ]]; then
      echo "ERROR: drain_connection $conn: Linear GraphQL error on page $page: $gqlerr" >&2
      [[ -n "$LAST_RATELIMIT_HEADERS" ]] && { echo "  rate-limit budget at failure:" >&2; printf '%s\n' "$LAST_RATELIMIT_HEADERS" | sed 's/^/    /' >&2; }
      rm -f "$resp"; return 1
    fi
    if ! jq -e --arg c "$conn" '.data.issue[$c] | has("nodes")' "$resp" >/dev/null 2>&1; then
      echo "ERROR: drain_connection $conn: unexpected response shape on page $page" >&2
      rm -f "$resp"; return 1
    fi
    local nodes
    nodes=$(jq -c --arg c "$conn" '.data.issue[$c].nodes' "$resp")
    acc=$(jq -cn --argjson a "$acc" --argjson n "$nodes" '$a + $n') || { rm -f "$resp"; return 1; }
    local has_next end_cursor
    has_next=$(jq -r --arg c "$conn" '.data.issue[$c].pageInfo.hasNextPage // false' "$resp")
    end_cursor=$(jq -r --arg c "$conn" '.data.issue[$c].pageInfo.endCursor // empty' "$resp")
    [[ "$has_next" == "true" && -n "$end_cursor" ]] || break
    after="$end_cursor"
  done
  rm -f "$resp"
  printf '%s' "$acc"
  return 0
}

# resolve_overflow <issues_file>: <issues_file> is a bare array of ACTIVE nodes fetched by
# GQL_ACTIVE. For every issue whose bounded nested connection reported hasNextPage=true,
# drain that connection to exhaustion (drain_connection) and REPLACE the issue's connection
# nodes with the full set — IN PLACE — so projection sees complete edge sets. Returns 0 if
# no overflow occurred OR every needed follow-up fully drained; returns 1 if ANY follow-up
# failed (the caller then marks complete=false so nested truncation is never silently
# accepted). This makes silent blockedBy truncation structurally impossible.
resolve_overflow() {
  local file="$1"
  local rc=0
  local overflow
  overflow=$(jq -c '
    [ .[] | . as $i
      | (["labels","relations","inverseRelations"][]) as $c
      | select(($i[$c].pageInfo.hasNextPage // false) == true)
      | {id: $i.id, identifier: $i.identifier, conn: $c} ]
  ' "$file") || return 1
  local n; n=$(echo "$overflow" | jq 'length')
  [[ "$n" -eq 0 ]] && return 0
  echo "Overflow: $n nested connection(s) exceeded the first-page cap — draining via follow-up queries." >&2
  local idx
  for ((idx = 0; idx < n; idx++)); do
    local id ident conn full
    id=$(echo "$overflow" | jq -r ".[$idx].id")
    ident=$(echo "$overflow" | jq -r ".[$idx].identifier")
    conn=$(echo "$overflow" | jq -r ".[$idx].conn")
    if ! full=$(drain_connection "$id" "$conn"); then
      echo "WARN: follow-up pagination failed for $ident.$conn — marking cache complete=false." >&2
      rc=1
      continue
    fi
    jq --arg ident "$ident" --arg conn "$conn" --argjson full "$full" '
      map(if .identifier == $ident then .[$conn] = {nodes: $full} else . end)
    ' "$file" > "$file.next" && mv "$file.next" "$file"
  done
  return $rc
}

# Query B — CLOSED issues (Done + Canceled + Duplicate, i.e. state type completed|canceled).
# SLIM: id/identifier/state/project/updatedAt ONLY — NO description, NO nested connections.
# Scoped by project.name.in <initiative member projects> (same filter as GQL_ACTIVE) — a
# team-wide fetch pulls every closed issue across every project the team has ever touched
# (observed: 1095 issues returned for a single-project initiative expecting ~200). A blocker
# living in a project outside the initiative won't resolve locally; that's an accepted
# tradeoff for keeping this cache scoped to the initiative. Per-page complexity is
# ~O(page_size) — negligible against the budget.
GQL_CLOSED='query ClosedIssues($first: Int!, $after: String, $filter: IssueFilter) {
  issues(first: $first, after: $after, filter: $filter, orderBy: updatedAt, includeArchived: false) {
    nodes {
      id
      identifier
      updatedAt
      state { name type }
      project { name }
    }
    pageInfo { hasNextPage endCursor }
  }
}'

# ---------- initiative scope oracle (honesty invariants) ----------
# resolve_initiative_scope: ONE authoritative GraphQL call (never per-project) that resolves the
# configured initiative to (a) its display name, (b) its FULL member-project NAME set, and (c) an
# INDEPENDENT open-work signal (does the initiative currently have any non-terminal issue?). This
# is the oracle the honesty invariants in cmd_sync_initiative check the written cache against, so a
# mis-scoped or open-frontier-losing sync can NEVER be reported complete=true.
#
# Independence is deliberate: member projects come from the `initiative` OBJECT, the open-work
# signal comes from an `issues(filter: project.initiatives…)` probe, and the actual active fetch is
# scoped by `project.name.in <members>`. Three mechanisms that must AGREE — a Done-only cache born
# from one silently-empty scope mechanism is caught by the other two.
#
# Requires $ikey (id|name) + globals TEAM_KEY / LINEAR_INITIATIVE / gql_post. Sets globals:
#   INIT_RESOLVED_NAME  resolved initiative display name ("" if the scope value resolves to NO
#                       initiative — e.g. a polluted/renamed/deleted scope key)
#   MEMBER_PROJECTS     newline-delimited member project names ("" if none)
#   MEMBER_TRUNCATED    1 if the projects connection overflowed the fetch cap (M is partial)
#   OPEN_WORK_EXISTS    1 if the initiative has >=1 open issue upstream, else 0
# Returns non-zero only on transport / GraphQL error (caller treats that as fatal — scope
# unverifiable, so the existing cache must not be overwritten).
resolve_initiative_scope() {
  INIT_RESOLVED_NAME=""; MEMBER_PROJECTS=""; MEMBER_TRUNCATED=0; OPEN_WORK_EXISTS=0
  local q vars resp probe_filter base
  probe_filter=$(jq -cn --arg team "$TEAM_KEY" --arg k "$ikey" --arg v "$LINEAR_INITIATIVE" \
    '{team:{key:{eq:$team}}, state:{type:{nin:["completed","canceled"]}}, project:{initiatives:{some:{($k):{eq:$v}}}}}')
  if [[ "$ikey" == "id" ]]; then
    q='query($v: String!, $af: IssueFilter) {
      node: initiative(id: $v) { name projects(first: 250) { nodes { name } pageInfo { hasNextPage } } }
      openProbe: issues(first: 1, filter: $af) { nodes { identifier } }
    }'
    base='.data.node'
  else
    q='query($v: String!, $af: IssueFilter) {
      inits: initiatives(filter: { name: { eq: $v } }, first: 2) { nodes { name projects(first: 250) { nodes { name } pageInfo { hasNextPage } } } }
      openProbe: issues(first: 1, filter: $af) { nodes { identifier } }
    }'
    base='.data.inits.nodes[0]'
  fi
  vars=$(jq -cn --arg v "$LINEAR_INITIATIVE" --argjson af "$probe_filter" '{v:$v, af:$af}')
  resp=$(mktemp)
  if ! gql_post "$q" "$vars" > "$resp" 2>/dev/null; then
    echo "ERROR: initiative-scope resolution: GraphQL transport failure." >&2
    rm -f "$resp"; return 1
  fi
  local gqlerr
  gqlerr=$(jq -r 'if (.errors|type)=="array" then (.errors[0].message // "unknown") else empty end' "$resp" 2>/dev/null || echo "PARSE_ERROR")
  if [[ -n "$gqlerr" ]]; then
    echo "ERROR: initiative-scope resolution: Linear GraphQL error: $gqlerr" >&2
    [[ -n "$LAST_RATELIMIT_HEADERS" ]] && { echo "  rate-limit budget at failure:" >&2; printf '%s\n' "$LAST_RATELIMIT_HEADERS" | sed 's/^/    /' >&2; }
    rm -f "$resp"; return 1
  fi
  INIT_RESOLVED_NAME=$(jq -r "($base.name) // empty" "$resp" 2>/dev/null || true)
  MEMBER_PROJECTS=$(jq -r "[$base.projects.nodes[]?.name] | .[]" "$resp" 2>/dev/null || true)
  if [[ "$(jq -r "($base.projects.pageInfo.hasNextPage) // false" "$resp" 2>/dev/null || echo false)" == "true" ]]; then
    MEMBER_TRUNCATED=1
  fi
  local op; op=$(jq -r '(.data.openProbe.nodes | length) // 0' "$resp" 2>/dev/null || echo 0)
  if [[ "$op" -gt 0 ]]; then OPEN_WORK_EXISTS=1; fi
  rm -f "$resp"
  return 0
}

cmd_sync_initiative() {
  if [[ "${LINEAR_NOT_CONFIGURED:-0}" == "1" ]]; then
    echo "ERROR: Linear not configured — set tracking_system: linear, linear_tenant, linear_initiative, team_key in config" >&2
    exit 1
  fi
  check_deps
  command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found in PATH — required for the direct-GraphQL initiative sync." >&2; exit 1; }
  ensure_gitignore
  mkdir -p "$CACHE_DIR"

  if [[ $# -gt 0 ]]; then
    echo "ERROR: Unknown option: $1" >&2
    exit 1
  fi

  resolve_linear_token || exit 1

  # Scope value shape: a 36-char UUID → resolve/filter by initiative id; else by display name.
  local ikey="name"
  [[ "$LINEAR_INITIATIVE" =~ ^[0-9a-fA-F-]{36}$ ]] && ikey="id"

  # Authoritative scope oracle (ONE call, never per-project): resolve the configured initiative
  # to its member-project NAME set + an independent open-work signal. INVARIANT A (fatal, before
  # any write): a scope value that resolves to NO initiative or ZERO member projects — the
  # signature of a stale/renamed key or a value polluted by an inline comment — must NEVER be
  # allowed to overwrite a good cache with a mis-scoped one.
  if ! resolve_initiative_scope; then
    echo "ERROR: could not resolve initiative scope '$LINEAR_INITIATIVE' — existing initiative.json left untouched." >&2
    exit 1
  fi
  if [[ -z "$MEMBER_PROJECTS" ]]; then
    echo "ERROR: initiative scope '$LINEAR_INITIATIVE' resolved to ZERO member projects." >&2
    echo "  Likely a wrong linear_initiative value (renamed/deleted initiative, or a value" >&2
    echo "  polluted by an inline '# comment'). Refusing to write a mis-scoped cache —" >&2
    echo "  existing initiative.json left untouched." >&2
    exit 1
  fi
  if [[ "$MEMBER_TRUNCATED" == "1" ]]; then
    echo "ERROR: initiative '${INIT_RESOLVED_NAME:-$LINEAR_INITIATIVE}' has more member projects than the 250 resolution cap — the member set is partial; refusing to write a partial-scope cache." >&2
    exit 1
  fi

  # Effective active scope = the initiative's authoritatively-resolved member projects.
  # `project.name.in` is the PROVEN scope filter (it produced the trusted backup cache) and
  # makes the scope EXPLICIT and auditable rather than an opaque server-side filter that can
  # silently match nothing. Scope is fully config-driven — there is no operator override flag.
  local scope_names="$MEMBER_PROJECTS"
  local member_count
  member_count=$(printf '%s\n' "$scope_names" | grep -c .)

  local scope_desc="initiative \"${INIT_RESOLVED_NAME:-$LINEAR_INITIATIVE}\" ($member_count member project(s))"
  echo "Initiative sync (direct GraphQL): team $TEAM_KEY — active + closed (both scoped to $scope_desc, slim) + blocked-by graph..."

  local active_tmp done_tmp all_tmp synced_at complete
  active_tmp=$(mktemp); done_tmp=$(mktemp); all_tmp=$(mktemp)
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  complete=true

  # Build server-side filters. Both active and closed are team + project.name.in <members> —
  # a team can carry many unrelated projects, and an unscoped closed fetch pulls EVERY closed
  # issue across ALL of them (observed: 1095 issues for a single-project initiative expecting
  # ~200). A blocker living in a project OUTSIDE the initiative won't resolve locally, but that
  # is the correct tradeoff — this cache is the initiative's frontier, not the team's.
  local filter_active vars_active plist
  plist=$(printf '%s\n' "$scope_names" | jq -R -s 'split("\n") | map(select(length>0))')
  filter_active=$(jq -cn --arg team "$TEAM_KEY" --argjson p "$plist" \
    '{team:{key:{eq:$team}}, state:{type:{nin:["completed","canceled"]}}, project:{name:{in:$p}}}')
  vars_active=$(jq -cn --argjson f "$filter_active" '{filter:$f}')

  local filter_closed vars_closed
  filter_closed=$(jq -cn --arg team "$TEAM_KEY" --argjson p "$plist" \
    '{team:{key:{eq:$team}}, state:{type:{in:["completed","canceled"]}}, project:{name:{in:$p}}}')
  vars_closed=$(jq -cn --argjson f "$filter_closed" '{filter:$f}')

  # 1) ACTIVE issues (in-scope). Fatal on failure — without the open set there is no usable
  #    frontier, so leave the existing cache untouched rather than half-write.
  #    Page size 25: GQL_ACTIVE costs ≈300 complexity/issue (labels 50 + relations 50×2 +
  #    inverseRelations 50×2 + scalars, see the fragment comment), so 25 × 300 = 7,500 —
  #    a safe margin under Linear's per-request complexity hard cap. Overflow past the
  #    first:50 nested caps is drained per-issue by resolve_overflow, so 25 is safe.
  if ! gql_paginate "$active_tmp" "$GQL_ACTIVE" "$vars_active" 25; then
    rm -f "$active_tmp" "$done_tmp" "$all_tmp"
    echo "Initiative sync aborted (active fetch failed, likely rate-limited) — existing initiative.json left untouched." >&2
    exit 1
  fi
  # 1b) Overflow guard: any ACTIVE issue whose bounded nested connection (labels/relations/
  #     inverseRelations) reported hasNextPage=true is drained to exhaustion via a follow-up
  #     single-issue query and its edge set replaced IN FULL before projection — so a gate's
  #     blockedBy edges can never silently truncate at the page cap. A follow-up FAILURE is
  #     treated exactly like an incomplete closed fetch: keep the partial, mark complete=false
  #     (nested completeness is part of the honesty bit, not just page-level completeness).
  if ! resolve_overflow "$active_tmp"; then
    complete=false
  fi
  # 2) CLOSED issues (scoped to member projects, slim). NON-fatal: on failure keep the partial
  #    set and mark complete=false so the engine frontier sets readComplete=false and retries
  #    instead of trusting an under-resolved blocker graph.
  #    Page size 250 stays large: GQL_CLOSED has ZERO nested connections — per issue ≈ 10
  #    complexity (id/identifier/updatedAt + state{name,type} + project{name}), so
  #    250 × 10 = 2,500 — well within Linear's per-request complexity hard cap. Verified safe.
  if ! gql_paginate "$done_tmp" "$GQL_CLOSED" "$vars_closed" 250; then
    echo "WARN: closed (Done/Canceled) fetch incomplete (rate-limited?) — marking cache complete=false." >&2
    complete=false   # keep whatever $done_tmp accumulated; do not clobber
  fi

  # 2b) HONESTY INVARIANTS (run BEFORE projection so `complete` written into the JSON is
  #     truthful). These make a mis-scoped / open-frontier-losing result that still claims
  #     complete=true structurally impossible — the exact failure mode of the broken sync
  #     (Done-only cache, complete=true, exit 0). These checks operate on the ACTIVE (open) set
  #     — the in-scope frontier the engine actually consumes.
  local open_count member_json open_out_of_scope
  open_count=$(jq 'length' "$active_tmp")
  member_json=$(printf '%s\n' "$MEMBER_PROJECTS" | jq -R -s 'split("\n") | map(select(length>0))')
  # (B) Scope purity — every OPEN issue must sit in a resolved member project. The active fetch
  #     is scoped by project.name.in <members> so this holds by construction; re-verify as a
  #     belt-and-suspenders catch for a server-side over-return (issues leaking in from outside
  #     the initiative).
  open_out_of_scope=$(jq --argjson m "$member_json" \
    '[ .[] | (.project.name // "«no-project»") as $p | select(($m | index($p)) == null) | $p ] | unique' "$active_tmp")
  if [[ "$(echo "$open_out_of_scope" | jq 'length')" -gt 0 ]]; then
    echo "HONESTY-FAIL: open issues reference project(s) outside initiative '${INIT_RESOLVED_NAME:-$LINEAR_INITIATIVE}': $(echo "$open_out_of_scope" | jq -c .) — marking cache complete=false." >&2
    complete=false
  fi
  # (C) Open-frontier-lost guard — an INDEPENDENT open-work probe (the project.initiatives
  #     server filter in resolve_initiative_scope, a DIFFERENT scope mechanism than this fetch's
  #     project.name.in) said the initiative has open work, yet the active fetch returned ZERO
  #     open issues. The two scope mechanisms disagree ⇒ the open frontier was lost (precisely
  #     the Done-only-but-complete=true failure). Never trust it.
  if [[ "$OPEN_WORK_EXISTS" == "1" && "$open_count" -eq 0 ]]; then
    echo "HONESTY-FAIL: initiative '${INIT_RESOLVED_NAME:-$LINEAR_INITIATIVE}' has open work upstream but the active fetch returned 0 open issues — the open frontier was lost; marking cache complete=false." >&2
    complete=false
  fi

  # 3) Merge + dedupe by identifier (states are disjoint; active listed first so its
  #    full-field node wins on any defensive collision).
  if ! jq -s '(.[0] + .[1]) | unique_by(.identifier)' "$active_tmp" "$done_tmp" > "$all_tmp"; then
    rm -f "$active_tmp" "$done_tmp" "$all_tmp"
    echo "ERROR: failed to merge issue sets — initiative.json left untouched." >&2
    exit 1
  fi

  # 4) Project a slim, jq-friendly cache keyed by identifier. blockedBy = the inverse
  #    "blocks" edges (issues that block THIS one); blocks = outgoing (for most-blocking
  #    ordering). Labels/project/milestone/updatedAt let the frontier apply holds and
  #    ordering entirely from cache. `complete` is the honesty bit.
  local init_tmp="$CACHE_DIR/initiative.json.tmp"
  if ! jq --arg ts "$synced_at" --arg team "$TEAM_KEY" --argjson complete "$complete" '
    . as $all |
    {
      synced_at: $ts,
      team: $team,
      complete: $complete,
      counts: {
        total: ($all | length),
        byState: ($all | map(.state.name) | group_by(.) | map({key: .[0], value: length}) | from_entries)
      },
      issues: ($all | map({
        key: .identifier,
        value: {
          state: .state.name,
          project: (.project.name // null),
          milestone: (.projectMilestone.id // null),
          labels: [.labels.nodes[]?.name],
          updatedAt: .updatedAt,
          blockedBy: ([.inverseRelations.nodes[]? | select(.type=="blocks") | .issue.identifier] | unique),
          blocks: ([.relations.nodes[]? | select(.type=="blocks") | .relatedIssue.identifier] | unique)
        }
      }) | from_entries)
    }
  ' "$all_tmp" > "$init_tmp"; then
    rm -f "$active_tmp" "$done_tmp" "$all_tmp" "$init_tmp"
    echo "ERROR: projection failed — initiative.json left untouched." >&2
    exit 1
  fi
  mv "$init_tmp" "$CACHE_DIR/initiative.json"
  echo "$synced_at" > "$CACHE_DIR/.last-initiative-sync"

  # Per-issue body files (cache-first read model): the ACTIVE (Query A) payload carries the
  # FULL description, so every in-scope active issue gets its issues/<id>.yaml written here
  # with zero extra API calls. Bodies are written ONLY for in-scope active issues — the
  # CLOSED (Query B) set is slim (no description) and exists solely as blocker-
  # resolution targets in initiative.json, so it gets NO body files (a closed ticket that is
  # ever re-opened/read regenerates its body on the next refresh-on-write). Comments are not
  # in the list payload — they appear on the first `linear-sync.sh issue <id>` (--with-comments)
  # write. Agents read tickets ONLY from these files.
  mkdir -p "$CACHE_DIR/issues"
  local body_count=0
  while IFS= read -r issue; do
    local iid
    iid=$(echo "$issue" | jq -r '.identifier')
    echo "$issue" | jq -r '
      def kind: '"$KIND_EXPR"';
      "identifier: " + .identifier,
      "title: " + (.title | @json),
      "status: " + .state.name,
      "kind: " + kind,
      "milestone: " + (.projectMilestone.id // "none"),
      "cycle: " + ((.cycle.number // empty | tostring) // "none"),
      (if (.description // "") == "" then "description: \"\""
       else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
       end)
    ' > "$CACHE_DIR/issues/$iid.yaml"
    body_count=$((body_count + 1))
  done < <(jq -c '.[]' "$active_tmp")

  rm -f "$active_tmp" "$done_tmp" "$all_tmp"

  local total done_n
  total=$(jq -r '.counts.total' "$CACHE_DIR/initiative.json")
  done_n=$(jq -r '.counts.byState.Done // 0' "$CACHE_DIR/initiative.json")
  echo "Initiative synced: $total issues ($done_n Done, complete=$complete, $body_count body files) → $CACHE_DIR/initiative.json"
  jq -r '.counts.byState | to_entries[] | "  " + .key + ": " + (.value|tostring)' "$CACHE_DIR/initiative.json"
  [[ "$complete" == "true" ]] || exit 3   # non-zero (partial) so callers can detect
}

# ---------- quota (rate-limit probe) ----------
# cmd_quota: make ONE minimal GraphQL request (query { viewer { id } }) purely to read the
# current rate-limit budget, and print the Linear rate-limit headers as JSON to stdout. This
# is the cheapest possible call (no connections) so it never meaningfully spends the budget
# it reports. Output shape:
#   { "requestsRemaining": "...", "requestsLimit": "...", "requestsReset": "...",
#     "raw": { "<header>": "<value>", ... }, "error": <null|string> }
# `raw` carries EVERY x-ratelimit-* / x-complexity / retry-after header verbatim (lowercased
# keys) so complexity budget headers surface even though the top-level convenience fields key
# off the request-bucket names. On a 429 the headers are still captured and `error` is set.
cmd_quota() {
  command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found in PATH — required for the quota probe." >&2; exit 1; }
  command -v jq   >/dev/null 2>&1 || { echo "ERROR: jq not found in PATH." >&2; exit 1; }
  resolve_linear_token || exit 1

  local resp gqlerr
  resp=$(mktemp)
  # Run gql_post with a REDIRECT (not command substitution) so it executes in THIS shell —
  # command substitution would run it in a subshell and LAST_RATELIMIT_HEADERS (set inside
  # gql_post) would never propagate back here, leaving `raw` empty. `|| true`: a curl
  # transport failure still leaves us the headers/body we have.
  gql_post 'query { viewer { id } }' '{}' > "$resp" 2>/dev/null || true
  gqlerr=$(jq -r 'if (.errors|type)=="array" then (.errors[0].message // "unknown") else empty end' "$resp" 2>/dev/null || echo "")

  # Parse the captured "name: value" header lines into a lowercased-key JSON object, then
  # lift the request-bucket convenience fields off it.
  printf '%s\n' "$LAST_RATELIMIT_HEADERS" | jq -R -s --arg err "$gqlerr" '
    (split("\n") | map(select(length>0))
      | map(capture("^(?<k>[^:]+):[[:space:]]*(?<v>.*)$"))
      | map({(.k | ascii_downcase): .v}) | add // {}) as $raw
    | {
        requestsRemaining: ($raw["x-ratelimit-requests-remaining"] // null),
        requestsLimit:     ($raw["x-ratelimit-requests-limit"] // null),
        requestsReset:     ($raw["x-ratelimit-requests-reset"] // null),
        raw: $raw,
        error: (if $err == "" then null else $err end)
      }
  '
  rm -f "$resp"
  # Surface a non-zero exit on a rate-limit / GraphQL error so scripted callers can detect it,
  # but the JSON (with headers) is already on stdout for the human/parent.
  [[ -z "$gqlerr" ]]
}

# ---------- main ----------
# Source guard: when this file is `source`d (e.g. an offline fixture harness sourcing it to
# unit-test resolve_overflow / drain_connection against mocked gql_post) the CLI dispatch
# below is SKIPPED. Behaviour when executed directly is unchanged.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
resolve_config

case "${1:-}" in
  sync)             cmd_sync ;;
  sync-initiative)  shift; cmd_sync_initiative "$@" ;;
  issue|story)      cmd_issue "${2:?Usage: linear-sync.sh issue <ID>}" ;;
  update)           shift; cmd_update "$@" ;;
  check)            cmd_check ;;
  quota)            cmd_quota ;;
  *)
    echo "Usage: linear-sync.sh {sync|sync-initiative|issue <ID>|update <ID> --status <STATE>|check|quota}"
    echo ""
    echo "Commands:"
    echo "  sync                         Full refresh — fetches ALL project issues (paginated) via linearis"
    echo "  sync-initiative              Initiative-scoped refresh (all projects under linear_initiative, all"
    echo "                               states incl. Done) + blocked-by graph → .cache/linear/initiative.json"
    echo "                               (for the delivery engine frontier). Requires linear_initiative in"
    echo "                               config — a config with only the legacy linear_project key is refused"
    echo "                               with a migration error (see resolve_config)."
    echo "  issue <ID>                   Refresh a single issue's cache file + work-status entry (alias: story)"
    echo "  update <ID> --status <S>     Write status to Linear via linearis, then refresh cache"
    echo "  check                        Verify cache freshness (exit 0 always; notes if stale/absent)"
    echo "  quota                        Probe Linear's rate-limit budget via ONE minimal query"
    echo "                               (viewer{id}); prints the x-ratelimit-* headers as JSON to stdout"
    echo ""
    echo "Requires: linearis (npm i -g linearis), jq, linearis auth login completed."
    echo "Cache location: <project_root>/.cache/linear/ (gitignored)"
    echo "Note: scope of record is linear_initiative (name or UUID); linearis matches --project by name or UUID, never slug."
    exit 1
    ;;
esac
fi
