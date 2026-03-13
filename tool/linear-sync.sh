#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$PROJECT_ROOT/.linear-cache"
CONFIG="$PROJECT_ROOT/_bmad/bmm/config.yaml"

TEAM_KEY=$(grep '^team_key:' "$CONFIG" | awk '{print $2}')
PROJECT_NAME=$(grep '^project_name:' "$CONFIG" | sed 's/^project_name: *//')

# Verify linearis is available
command -v linearis >/dev/null 2>&1 || { echo "ERROR: linearis CLI not found in PATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found in PATH"; exit 1; }

# ---------- sync ----------
cmd_sync() {
  mkdir -p "$CACHE_DIR/stories"

  echo "Syncing Linear issues for team $TEAM_KEY..."
  local tmpfile
  tmpfile=$(mktemp)

  linearis issues search "" --team "$TEAM_KEY" --limit 200 > "$tmpfile"

  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build sprint-status.yaml
  {
    echo "synced_at: \"$synced_at\""
    echo "team_key: $TEAM_KEY"
    echo "project: $PROJECT_NAME"
    echo ""
    echo "epics:"

    jq -r '
      [.[] | select(.title | test("^\\[Epic"))] |
      sort_by(.identifier | split("-") | last | tonumber) |
      .[] |
      "  " + .identifier + ":\n" +
      "    key: " + (.title | capture("\\[Epic[- ](?<num>\\d+)\\]") | "epic-\(.num)") + "\n" +
      "    title: \"" + .title + "\"\n" +
      "    status: " + .state.name
    ' "$tmpfile"

    echo ""
    echo "stories:"

    jq -r '
      [.[] | select(.title | test("^\\[\\d+\\.\\d+\\]"))] |
      sort_by(.identifier | split("-") | last | tonumber) |
      .[] |
      "  " + .identifier + ":\n" +
      "    key: " + (try (.title | capture("\\[(?<e>\\d+)\\.(?<s>\\d+)\\]\\s*(?<rest>.*)") |
        "\(.e)-\(.s)-" + (.rest | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("(^-|-$)"; "")))
        catch "unknown") + "\n" +
      "    epic: " + (.parentIssue.identifier // "none") + "\n" +
      "    title: \"" + .title + "\"\n" +
      "    status: " + .state.name
    ' "$tmpfile"
  } > "$CACHE_DIR/sprint-status.yaml"

  # Write individual story files
  local story_count=0
  while IFS= read -r issue; do
    local id
    id=$(echo "$issue" | jq -r '.identifier')

    echo "$issue" | jq -r '
      "identifier: " + .identifier,
      "title: \"" + .title + "\"",
      "status: " + .state.name,
      "epic: " + (.parentIssue.identifier // "none"),
      (if (.description // "") == "" then "description: \"\""
       else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
       end)
    ' > "$CACHE_DIR/stories/$id.yaml"

    story_count=$((story_count + 1))
  done < <(jq -c '.[] | select(.title | test("^\\[\\d+\\.\\d+\\]"))' "$tmpfile")

  echo "$synced_at" > "$CACHE_DIR/.last-sync"

  local epic_count
  epic_count=$(jq '[.[] | select(.title | test("^\\[Epic"))] | length' "$tmpfile")

  rm -f "$tmpfile"

  echo "✓ Synced $epic_count epics, $story_count stories to .linear-cache/"
  echo "  sprint-status.yaml updated"
  echo "  $story_count story files written to stories/"
}

# ---------- story ----------
cmd_story() {
  local issue_id="$1"
  mkdir -p "$CACHE_DIR/stories"

  echo "Refreshing $issue_id..."

  local json
  json=$(linearis issues read "$issue_id")

  local status
  status=$(echo "$json" | jq -r '.state.name')

  # Write story file
  echo "$json" | jq -r '
    "identifier: " + .identifier,
    "title: \"" + .title + "\"",
    "status: " + .state.name,
    "epic: " + (.parentIssue.identifier // "none"),
    (if (.description // "") == "" then "description: \"\""
     else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
     end)
  ' > "$CACHE_DIR/stories/$issue_id.yaml"

  # Update sprint-status.yaml if it exists
  if [[ -f "$CACHE_DIR/sprint-status.yaml" ]]; then
    awk -v id="$issue_id" -v new_status="$status" '
      $0 ~ "^  " id ":" { found=1; print; next }
      found && /^    status:/ { print "    status: " new_status; found=0; next }
      { print }
    ' "$CACHE_DIR/sprint-status.yaml" > "$CACHE_DIR/sprint-status.yaml.tmp"
    mv "$CACHE_DIR/sprint-status.yaml.tmp" "$CACHE_DIR/sprint-status.yaml"
  fi

  echo "✓ $issue_id refreshed (status: $status)"
}

# ---------- update ----------
cmd_update() {
  local issue_id="$1"
  shift

  local status=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$status" ]]; then
    echo "ERROR: --status is required"
    echo "Usage: linear-sync.sh update <ID> --status <status>"
    exit 1
  fi

  echo "Updating $issue_id → $status in Linear..."
  linearis issues update "$issue_id" -s "$status"

  # Refresh cache
  cmd_story "$issue_id"
}

# ---------- check ----------
cmd_check() {
  if [[ ! -f "$CACHE_DIR/.last-sync" ]]; then
    echo "ERROR: No cache found. Run: tool/linear-sync.sh sync"
    exit 1
  fi

  local last_sync
  last_sync=$(cat "$CACHE_DIR/.last-sync")

  local last_epoch now_epoch age_minutes
  last_epoch=$(date -d "$last_sync" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$last_sync" +%s 2>/dev/null)
  now_epoch=$(date +%s)
  age_minutes=$(( (now_epoch - last_epoch) / 60 ))

  echo "Last sync: $last_sync ($age_minutes minutes ago)"

  if [[ $age_minutes -gt 30 ]]; then
    echo "WARNING: Cache is stale (>30 minutes). Run: tool/linear-sync.sh sync"
    exit 1
  fi

  echo "✓ Cache is fresh"
}

# ---------- main ----------
case "${1:-}" in
  sync)    cmd_sync ;;
  story)   cmd_story "${2:?Usage: linear-sync.sh story <ID>}" ;;
  update)  shift; cmd_update "$@" ;;
  check)   cmd_check ;;
  *)
    echo "Usage: linear-sync.sh {sync|story <ID>|update <ID> --status <STATUS>|check}"
    echo ""
    echo "Commands:"
    echo "  sync                         Full refresh of all issues"
    echo "  story <ID>                   Refresh a single story (e.g., DNI-43)"
    echo "  update <ID> --status <S>     Write status to Linear, then refresh cache"
    echo "  check                        Verify cache freshness"
    exit 1
    ;;
esac
