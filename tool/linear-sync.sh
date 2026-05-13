#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$PROJECT_ROOT/_bmad/bmm/config.yaml"

TEAM_KEY=$(grep '^team_key:' "$CONFIG" | awk '{print $2}')
LINEAR_TENANT=$(grep '^linear_tenant:' "$CONFIG" | awk '{print $2}')
LINEAR_PROJECT=$(grep '^linear_project:' "$CONFIG" | sed 's/^linear_project: *//')
PROJECT_NAME=$(grep '^project_name:' "$CONFIG" | sed 's/^project_name: *//')
PLANNING_DIR=$(grep '^planning_artifacts:' "$CONFIG" | sed 's/^planning_artifacts: *//' | sed 's/^"//;s/"$//' | sed "s|{project-root}|$PROJECT_ROOT|g")

# Store cache under XDG data dir: ~/.local/share/linear-sync/{tenant}/{project}
LINEAR_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/linear-sync"
PROJECT_SLUG=$(echo "$LINEAR_PROJECT" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-//; s/-$//')
CACHE_DIR="$LINEAR_DATA_HOME/$LINEAR_TENANT/$PROJECT_SLUG"

# Verify linearis is available
command -v linearis >/dev/null 2>&1 || { echo "ERROR: linearis CLI not found in PATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found in PATH"; exit 1; }

# ---------- story-map ----------
gen_story_map() {
  local map_file="$CACHE_DIR/story-map.md"
  local generated_at
  generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  {
    echo "# $PROJECT_NAME Story Map"
    echo ""
    echo "**Project:** $PROJECT_NAME"
    echo "**Team:** $TEAM_KEY"
    echo "**Generated:** $generated_at"
    echo ""
    echo "## Epic → Story Mapping"

    # Read epics from sprint-status.yaml
    local current_epic=""
    local epic_title=""
    local total_stories=0
    local epic_summaries=""
    local epic_story_count=0

    # Parse sprint-status.yaml for epics
    while IFS= read -r line; do
      local eid
      eid=$(echo "$line" | awk -F'|' '{print $1}')
      local etitle
      etitle=$(echo "$line" | awk -F'|' '{print $2}')
      epic_summaries="${epic_summaries}${eid}|${etitle}|0\n"
    done < <(awk '
      /^epics:/ { in_epics=1; next }
      /^stories:/ { in_epics=0 }
      in_epics && /^  [A-Z]+-/ {
        id=$1; sub(/:$/, "", id)
        getline; title_line=$0
        gsub(/^    title: "/, "", title_line)
        gsub(/"$/, "", title_line)
        print id "|" title_line
      }
    ' "$CACHE_DIR/sprint-status.yaml")

    # For each epic, find its stories from story files
    while IFS= read -r epic_line; do
      local eid etitle
      eid=$(echo "$epic_line" | awk -F'|' '{print $1}')
      etitle=$(echo "$epic_line" | awk -F'|' '{print $2}')

      echo ""
      echo "### ${eid}: ${etitle}"
      echo "| Story | Title | Status | File |"
      echo "|-------|-------|--------|------|"

      local epic_count=0
      for story_file in "$CACHE_DIR/stories"/*.yaml; do
        local s_epic s_id s_title s_status
        s_epic=$(grep '^epic:' "$story_file" | awk '{print $2}')
        if [[ "$s_epic" == "$eid" ]]; then
          s_id=$(grep '^identifier:' "$story_file" | awk '{print $2}')
          s_title=$(grep '^title:' "$story_file" | sed 's/^title: //' | sed 's/^"//;s/"$//')
          s_status=$(grep '^status:' "$story_file" | awk '{print $2}')
          echo "| $s_id | $s_title | $s_status | \`stories/$s_id.yaml\` |"
          epic_count=$((epic_count + 1))
          total_stories=$((total_stories + 1))
        fi
      done
    done < <(awk '
      /^epics:/ { in_epics=1; next }
      /^stories:/ { in_epics=0 }
      in_epics && /^  [A-Z]+-/ {
        id=$1; sub(/:$/, "", id)
        getline; getline; title_line=$0
        gsub(/^    title: "/, "", title_line)
        gsub(/"$/, "", title_line)
        print id "|" title_line
      }
    ' "$CACHE_DIR/sprint-status.yaml")

    echo ""
    echo "## Summary"
    echo ""
    echo "| Epic | Stories | Status |"
    echo "|------|---------|--------|"

    # Count stories per epic
    while IFS= read -r epic_line; do
      local eid etitle
      eid=$(echo "$epic_line" | awk -F'|' '{print $1}')
      etitle=$(echo "$epic_line" | awk -F'|' '{print $2}')
      # Extract short name from title
      local short_name
      short_name=$(echo "$etitle" | sed 's/^\[Epic[- ][0-9]*\] //; s/^Epic [0-9]* — //')

      local ecount=0
      for story_file in "$CACHE_DIR/stories"/*.yaml; do
        local s_epic
        s_epic=$(grep '^epic:' "$story_file" | awk '{print $2}')
        [[ "$s_epic" == "$eid" ]] && ecount=$((ecount + 1))
      done

      # Collect statuses
      local all_backlog=true
      for story_file in "$CACHE_DIR/stories"/*.yaml; do
        local s_epic s_status
        s_epic=$(grep '^epic:' "$story_file" | awk '{print $2}')
        if [[ "$s_epic" == "$eid" ]]; then
          s_status=$(grep '^status:' "$story_file" | awk '{print $2}')
          [[ "$s_status" != "Backlog" ]] && all_backlog=false
        fi
      done

      local status_text="Mixed"
      $all_backlog && status_text="All Backlog"
      local epic_num
      epic_num=$(echo "$etitle" | grep -oP 'Epic[- ]\K\d+')
      echo "| Epic $epic_num – $short_name | $ecount | $status_text |"
    done < <(awk '
      /^epics:/ { in_epics=1; next }
      /^stories:/ { in_epics=0 }
      in_epics && /^  [A-Z]+-/ {
        id=$1; sub(/:$/, "", id)
        getline; getline; title_line=$0
        gsub(/^    title: "/, "", title_line)
        gsub(/"$/, "", title_line)
        print id "|" title_line
      }
    ' "$CACHE_DIR/sprint-status.yaml")

    echo "| **Total** | **$total_stories** | |"
  } > "$map_file"
}

# ---------- epic-list ----------
gen_epic_list() {
  local epics_file="$PLANNING_DIR/epics.md"
  [[ -f "$epics_file" ]] || return 0
  [[ -f "$CACHE_DIR/sprint-status.yaml" ]] || return 0

  local content_file out_file
  content_file=$(mktemp)
  out_file=$(mktemp)

  {
    echo "<!-- AUTO:EPIC-LIST-START -->"
    echo "## Epic List"
    echo ""
    echo "> **This section is a read-only copy of data from Linear, auto-generated by \`tool/linear-sync.sh\`.** Do not edit — changes will be overwritten on next sync. To modify stories, update them in Linear and run \`tool/linear-sync.sh sync\`."

    while IFS= read -r epic_line; do
      local eid etitle epic_num short_name
      eid=$(echo "$epic_line" | awk -F'|' '{print $1}')
      etitle=$(echo "$epic_line" | awk -F'|' '{print $2}')
      epic_num=$(echo "$etitle" | grep -oP 'Epic[- ]\K\d+')
      short_name=$(echo "$etitle" | sed 's/^\[Epic[- ][0-9]*\] //; s/^Epic [0-9]* — //')

      # Read epic summary from companion file
      local summary=""
      if [[ -f "$PLANNING_DIR/epic-summaries.md" ]]; then
        summary=$(awk -v id="$eid" '
          $0 == "## " id { found=1; next }
          found && /^## / { found=0 }
          found && NF { print }
        ' "$PLANNING_DIR/epic-summaries.md")
      fi

      # Collect stories for this epic
      local story_lines=()
      for story_file in "$CACHE_DIR/stories"/*.yaml; do
        [[ -f "$story_file" ]] || continue
        local s_epic s_id s_title s_status
        s_epic=$(grep '^epic:' "$story_file" | awk '{print $2}')
        if [[ "$s_epic" == "$eid" ]]; then
          s_id=$(grep '^identifier:' "$story_file" | awk '{print $2}')
          s_title=$(grep '^title:' "$story_file" | sed 's/^title: //' | sed 's/^"//;s/"$//')
          s_status=$(grep '^status:' "$story_file" | awk '{print $2}')
          story_lines+=("- **${s_id}** — ${s_title} *(${s_status})*")
        fi
      done

      echo ""
      echo "### Epic $epic_num — $short_name ($eid, ${#story_lines[@]} stories)"
      echo ""
      if [[ -n "$summary" ]]; then
        echo "$summary"
        echo ""
      fi
      for line in "${story_lines[@]}"; do
        echo "$line"
      done
    done < <(awk '
      /^epics:/ { in_epics=1; next }
      /^stories:/ { in_epics=0 }
      in_epics && /^  [A-Z]+-/ {
        id=$1; sub(/:$/, "", id)
        getline; getline; title_line=$0
        gsub(/^    title: "/, "", title_line)
        gsub(/"$/, "", title_line)
        print id "|" title_line
      }
    ' "$CACHE_DIR/sprint-status.yaml")

    echo "<!-- AUTO:EPIC-LIST-END -->"
  } > "$content_file"

  if grep -q "AUTO:EPIC-LIST-START" "$epics_file"; then
    awk -v cf="$content_file" '
      /<!-- AUTO:EPIC-LIST-START -->/ {
        while ((getline line < cf) > 0) print line
        close(cf)
        skip = 1
        next
      }
      /<!-- AUTO:EPIC-LIST-END -->/ { skip = 0; next }
      !skip { print }
    ' "$epics_file" > "$out_file"
  else
    cat "$epics_file" > "$out_file"
    echo "" >> "$out_file"
    cat "$content_file" >> "$out_file"
  fi

  mv "$out_file" "$epics_file"
  rm -f "$content_file"
}

# ---------- sync ----------
cmd_sync() {
  mkdir -p "$CACHE_DIR/stories"

  echo "Syncing Linear issues for project $LINEAR_PROJECT (team $TEAM_KEY)..."
  local tmpfile
  tmpfile=$(mktemp)

  # Paginate until all issues are fetched
  local cursor="" has_next=true page=0
  # Start with an empty JSON array
  echo '[]' > "$tmpfile"
  while [[ "$has_next" == "true" ]]; do
    page=$((page + 1))
    local page_file
    page_file=$(mktemp)
    if [[ -n "$cursor" ]]; then
      linearis issues list --team "$TEAM_KEY" --project "$LINEAR_PROJECT" --limit 200 --after "$cursor" > "$page_file"
    else
      linearis issues list --team "$TEAM_KEY" --project "$LINEAR_PROJECT" --limit 200 > "$page_file"
    fi
    local count
    count=$(jq '.nodes | length' "$page_file")
    echo "  Page $page: $count issues"
    # Merge nodes into tmpfile
    jq -s '.[0] + .[1]' "$tmpfile" <(jq '.nodes' "$page_file") > "${tmpfile}.merged"
    mv "${tmpfile}.merged" "$tmpfile"
    has_next=$(jq -r '.pageInfo.hasNextPage' "$page_file")
    cursor=$(jq -r '.pageInfo.endCursor' "$page_file")
    rm -f "$page_file"
  done

  local synced_at
  synced_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build sprint-status.yaml
  {
    echo "synced_at: \"$synced_at\""
    echo "team_key: $TEAM_KEY"
    echo "linear_project: $LINEAR_PROJECT"
    echo "project: $PROJECT_NAME"
    echo ""
    echo "epics:"

    jq -r '
      [.[] | select(.title | test("^(\\[Epic|Epic [0-9])"))] |
      sort_by(.identifier | split("-") | last | tonumber) |
      .[] |
      "  " + .identifier + ":\n" +
      "    key: " + ((.title | capture("(?:^\\[Epic[- ]|^Epic )(?<num>\\d+)")) | "epic-\(.num)") + "\n" +
      "    title: \"" + .title + "\"\n" +
      "    status: " + .state.name
    ' "$tmpfile"

    echo ""
    echo "stories:"

    jq -r '
      [.[] | select(.title | test("^(\\[\\d+\\.\\d+\\]|\\d+\\.\\d+:)"))] |
      sort_by(.identifier | split("-") | last | tonumber) |
      .[] |
      "  " + .identifier + ":\n" +
      "    key: " + (try (
        if (.title | test("^\\[")) then
          .title | capture("\\[(?<e>\\d+)\\.(?<s>\\d+)\\]\\s*(?<rest>.*)") |
          "\(.e)-\(.s)-" + (.rest | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("(^-|-$)"; ""))
        else
          .title | capture("(?<e>\\d+)\\.(?<s>\\d+):\\s*(?<rest>.*)") |
          "\(.e)-\(.s)-" + (.rest | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("(^-|-$)"; ""))
        end
      ) catch "unknown") + "\n" +
      "    epic: " + (.parent.identifier // "none") + "\n" +
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
      "epic: " + (.parent.identifier // "none"),
      (if (.description // "") == "" then "description: \"\""
       else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
       end)
    ' > "$CACHE_DIR/stories/$id.yaml"

    story_count=$((story_count + 1))
  done < <(jq -c '.[] | select(.title | test("^(\\[\\d+\\.\\d+\\]|\\d+\\.\\d+:)"))' "$tmpfile")

  echo "$synced_at" > "$CACHE_DIR/.last-sync"

  local epic_count
  epic_count=$(jq '[.[] | select(.title | test("^(\\[Epic|Epic [0-9])"))] | length' "$tmpfile")

  rm -f "$tmpfile"

  # Regenerate story map and epic list
  gen_story_map
  gen_epic_list

  echo "✓ Synced $epic_count epics, $story_count stories to $CACHE_DIR/"
  echo "  sprint-status.yaml updated"
  echo "  story-map.md updated"
  echo "  epics.md updated"
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

  # Write story file (includes comments for cache-only reads)
  echo "$json" | jq -r '
    "identifier: " + .identifier,
    "title: \"" + .title + "\"",
    "status: " + .state.name,
    "epic: " + (.parentIssue.identifier // "none"),
    (if (.description // "") == "" then "description: \"\""
     else "description: |\n" + (.description | split("\n") | map("  " + .) | join("\n"))
     end),
    (if (.comments | length) == 0 then "comments: []"
     else "comments:\n" + ([.comments[] | "  - author: \"" + .user.name + "\"\n    body: |\n" + (.body | split("\n") | map("      " + .) | join("\n"))] | join("\n"))
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
  echo "  Note: story-map.md and epics.md are NOT regenerated by single-story sync."
  echo "  Run 'tool/linear-sync.sh sync' for a full refresh if stories were added/removed/renamed."
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
    echo "  sync                         Full refresh — all issues, story-map.md, epics.md"
    echo "                               Run after: adding/removing stories, renaming issues,"
    echo "                               editing epic titles, or any structural change in Linear."
    echo "  story <ID>                   Refresh a single story's cache file + sprint-status entry"
    echo "                               (does NOT regenerate story-map.md or epics.md)"
    echo "  update <ID> --status <S>     Write status to Linear, then refresh cache"
    echo "  check                        Verify cache freshness"
    exit 1
    ;;
esac
