#!/usr/bin/env bash
# test-linear-sync-status-filter.sh — regression guard for the legacy `sync`
# command's active-only work-status.yaml scope (settled initiative model,
# PO decision 2026-07-09).
#
# `sync` (legacy single-project refresh) fetches via linearis' unfiltered
# `issues list`, which excludes "completed"-type issues (Done) — see the
# ORIGINAL ENG-1342 bug report. Post initiative-model, that exclusion is
# BY DESIGN for the legacy `sync` path: work-status.yaml is an active-only
# board view; Done/Canceled visibility lives in `sync-initiative`'s
# initiative.json (team-wide, all states, fetched via direct GraphQL — a
# different mechanism not subject to this linearis quirk). This test guards
# that the active-only scope stays correct and doesn't silently regress in
# either direction (Done leaking in, or an active issue silently dropped).
#
# Runs the REAL script (_bmad/lnr/tools/linear-sync.sh) end-to-end via its
# public CLI (`sync`), with `linearis` stubbed (the only true external
# boundary) to reproduce the exact fetch shape: unfiltered list excludes the
# Done-status issue; an explicit --status query would return it (unused by
# `sync`, kept in the stub to document the underlying linearis behaviour).
#
# Asserts:
#   1. `sync` exits 0
#   2. the Done issue (ENG-4) is correctly ABSENT from work-status.yaml
#      (active-only by design — it must never silently reappear)
#   3. the Done issue gets NO issues/ENG-4.yaml cache file (single-project
#      `sync` never fetches it)
#   4. the 4 active fixture issues are present exactly once each (no dupes,
#      no drops)
#
# Usage: bash test-linear-sync-status-filter.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/linear-sync.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

mkdir -p "$SANDBOX/_bmad/lnr" "$SANDBOX/bin"
cat > "$SANDBOX/_bmad/lnr/config.yaml" <<'EOF'
tracking_system: linear
linear_tenant: test-tenant
linear_initiative: "Test Initiative"
linear_project: "Test Project"
team_key: ENG
EOF

# Stub linearis: the only true external boundary linear-sync.sh crosses.
# Reproduces the underlying linearis fetch shape: unfiltered `issues list`
# excludes the Done-status issue (ENG-4) and reports hasNextPage=false; an
# explicit --status query returns the correct subset (including Done) — the
# latter branch is unused by `sync` (kept for stub fidelity/documentation).
cat > "$SANDBOX/bin/linearis" <<'STUB'
#!/usr/bin/env bash
DATA='[
  {"identifier":"ENG-1","title":"one","state":{"name":"Backlog"},"projectMilestone":null,"cycle":null},
  {"identifier":"ENG-2","title":"two","state":{"name":"In Progress"},"projectMilestone":null,"cycle":null},
  {"identifier":"ENG-3","title":"three","state":{"name":"In Review"},"projectMilestone":null,"cycle":null},
  {"identifier":"ENG-4","title":"four","state":{"name":"Done"},"projectMilestone":null,"cycle":null},
  {"identifier":"ENG-5","title":"five","state":{"name":"Canceled"},"projectMilestone":null,"cycle":null}
]'

if [[ "$1" == "issues" && "$2" == "list" ]]; then
  shift 2
  status=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) status="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [[ -z "$status" ]]; then
    # THE BUG: unfiltered call silently excludes the completed-type (Done) issue.
    nodes=$(jq -c '[.[] | select(.state.name != "Done")]' <<<"$DATA")
  else
    nodes=$(jq -c --arg s "$status" '[.[] | select(.state.name == $s)]' <<<"$DATA")
  fi
  jq -n --argjson nodes "$nodes" '{nodes: $nodes, pageInfo: {hasNextPage: false, endCursor: null}}'
  exit 0
fi

if [[ "$1" == "milestones" && "$2" == "list" ]]; then
  echo '{"nodes": []}'
  exit 0
fi

echo "unsupported stub call: $*" >&2
exit 1
STUB
chmod +x "$SANDBOX/bin/linearis"

cd "$SANDBOX" || exit 99
OUT_LOG="$SANDBOX/sync.out"
ERR_LOG="$SANDBOX/sync.err"
PATH="$SANDBOX/bin:$PATH" bash "$SYNC_SCRIPT" sync > "$OUT_LOG" 2> "$ERR_LOG"
exit_code=$?

CACHE_DIR="$SANDBOX/.cache/linear"

if [[ $exit_code -eq 0 ]]; then
  pass "sync exited 0"
else
  fail "sync exited $exit_code (expected 0) — stderr:"
  cat "$ERR_LOG" >&2
fi

dupe_count=$(grep -c '^  ENG-4:' "$CACHE_DIR/work-status.yaml" 2>/dev/null) || dupe_count=0
if [[ "$dupe_count" -eq 0 ]]; then
  pass "Done issue ENG-4 correctly absent from work-status.yaml (active-only by design)"
else
  fail "ENG-4 (Done) appears $dupe_count times in work-status.yaml — active-only scope regressed"
fi

if [[ ! -f "$CACHE_DIR/issues/ENG-4.yaml" ]]; then
  pass "issues/ENG-4.yaml correctly not written (single-project sync never fetches Done)"
else
  fail "issues/ENG-4.yaml was written — single-project sync should not fetch Done issues"
fi

total=$(grep -c '^    status:' "$CACHE_DIR/work-status.yaml" 2>/dev/null) || total=0
if [[ "$total" -eq 4 ]]; then
  pass "all 4 active fixture issues present exactly once (Done excluded, no dupes)"
else
  fail "expected 4 active issue entries in work-status.yaml, found $total"
fi

# Edge case: a pre-existing cache whose work-status.yaml has an EMPTY issues:
# map (zero "    status:" lines) must not abort the sync. The previous-count
# sanity-check reads that count via `grep -c`, which exits 1 (no match) on a
# zero-count cache — under the script's `set -e` a naive `x=$(grep -c ...)`
# would silently kill the whole sync in exactly this edge case.
cat > "$CACHE_DIR/work-status.yaml" <<'EOF'
synced_at: "seed"
team_key: ENG
linear_project: Test Project
project: Test Project

milestones:

issues:
EOF
PATH="$SANDBOX/bin:$PATH" bash "$SYNC_SCRIPT" sync > "$SANDBOX/sync2.out" 2> "$SANDBOX/sync2.err"
exit_code2=$?
if [[ $exit_code2 -eq 0 ]]; then
  pass "sync survives a pre-existing cache with zero prior issue entries (prev-count edge case)"
else
  fail "sync aborted ($exit_code2) against an empty-issues prior cache — stderr:"
  cat "$SANDBOX/sync2.err" >&2
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
