#!/usr/bin/env bash
# test-linear-sync-race.sh — regression test for ENG-1254.
#
# Reproduces (pre-fix) and guards against (post-fix) the race in
# _write_issue_file() where concurrent `linear-sync.sh issue <id>` invocations
# share a single fixed tmp path ($CACHE_DIR/work-status.yaml.tmp) for the
# awk-rewrite + mv of work-status.yaml. Two processes racing on that literal
# path can have one process's `mv` consume the file out from under the other,
# producing "mv: cannot stat ... No such file or directory" and aborting the
# loser (set -euo pipefail) with its status update lost.
#
# Fires many concurrent `issue <id>` refreshes (synchronized on a start
# barrier to maximize interleaving) against a shared sandbox cache and
# asserts:
#   1. every invocation exits 0
#   2. no invocation's stderr contains "cannot stat"
#   3. work-status.yaml is left well-formed with every issue's final status
#   4. no stray tmp litter is left in the cache dir
#
# Runs the REAL script (_bmad/lnr/tools/linear-sync.sh) end-to-end via its
# public CLI, with `linearis` stubbed (the only true external boundary).
#
# Usage: bash test-linear-sync-race.sh [--iterations N] [--concurrency N]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/linear-sync.sh"

ITERATIONS=5
CONCURRENCY=10   # unique issue ids per iteration, each refreshed twice concurrently

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --concurrency) CONCURRENCY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

any_iteration_failed=0

for ((iter = 1; iter <= ITERATIONS; iter++)); do
  SANDBOX="$(mktemp -d)"

  mkdir -p "$SANDBOX/_bmad/lnr" "$SANDBOX/bin"
  cat > "$SANDBOX/_bmad/lnr/config.yaml" <<'EOF'
tracking_system: linear
linear_tenant: test-tenant
linear_initiative: "Test Initiative"
linear_project: "Test Project"
team_key: ENG
EOF

  # Stub linearis: the only true external boundary linear-sync.sh crosses.
  # `issues read ENG-N` returns canned-but-per-id JSON (status varies by id
  # so we can assert each id's final status lands correctly).
  cat > "$SANDBOX/bin/linearis" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "issues" && "$2" == "read" ]]; then
  id="$3"
  n="${id##*-}"
  status="Status$n"
  cat <<JSON
{"identifier":"$id","title":"Issue $id","state":{"name":"$status"},"projectMilestone":null,"cycle":null,"comments":{"nodes":[]}}
JSON
  exit 0
fi
echo "unsupported stub call: $*" >&2
exit 1
STUB
  chmod +x "$SANDBOX/bin/linearis"

  CACHE_DIR="$SANDBOX/.cache/linear"
  mkdir -p "$CACHE_DIR/issues"

  # Seed work-status.yaml with one entry per issue id, status "Backlog", so the
  # awk in-place status patch has something to find-and-replace concurrently.
  {
    echo "synced_at: \"seed\""
    echo "team_key: ENG"
    echo "linear_project: Test Project"
    echo "project: Test Project"
    echo ""
    echo "milestones:"
    echo ""
    echo "issues:"
    for ((i = 1; i <= CONCURRENCY; i++)); do
      echo "  ENG-$i:"
      echo "    title: \"Issue ENG-$i\""
      echo "    status: Backlog"
      echo "    kind: other"
      echo "    milestone: none"
      echo "    cycle: none"
    done
  } > "$CACHE_DIR/work-status.yaml"
  echo "seed" > "$CACHE_DIR/.last-sync"

  BARRIER="$SANDBOX/go"
  LOG_DIR="$SANDBOX/logs"
  mkdir -p "$LOG_DIR"

  pids=()
  for ((i = 1; i <= CONCURRENCY; i++)); do
    for rep in 1 2; do
      (
        # Busy-wait on the start barrier so all invocations pile up on the
        # same instant, maximizing interleaving on the shared tmp path.
        while [[ ! -f "$BARRIER" ]]; do :; done
        cd "$SANDBOX" || exit 99
        PATH="$SANDBOX/bin:$PATH" bash "$SYNC_SCRIPT" issue "ENG-$i" \
          > "$LOG_DIR/ENG-$i.rep$rep.out" 2> "$LOG_DIR/ENG-$i.rep$rep.err"
        echo $? > "$LOG_DIR/ENG-$i.rep$rep.exit"
      ) &
      pids+=($!)
    done
  done

  touch "$BARRIER"
  for pid in "${pids[@]}"; do wait "$pid"; done

  iter_ok=1

  # Assertion 1+2: every invocation exited 0, no "cannot stat" anywhere.
  for ((i = 1; i <= CONCURRENCY; i++)); do
    for rep in 1 2; do
      code=$(cat "$LOG_DIR/ENG-$i.rep$rep.exit" 2>/dev/null || echo "MISSING")
      if [[ "$code" != "0" ]]; then
        echo "    [iter $iter] ENG-$i rep$rep exited $code" >&2
        cat "$LOG_DIR/ENG-$i.rep$rep.err" >&2
        iter_ok=0
      fi
      if grep -q "cannot stat" "$LOG_DIR/ENG-$i.rep$rep.err" 2>/dev/null; then
        echo "    [iter $iter] ENG-$i rep$rep hit the tmp-file race (cannot stat)" >&2
        iter_ok=0
      fi
    done
  done

  # Assertion 3: work-status.yaml well-formed, every issue shows its final status.
  for ((i = 1; i <= CONCURRENCY; i++)); do
    if ! awk -v id="ENG-$i" -v want="Status$i" '
      $0 ~ "^  " id ":" { found=1; next }
      found && /^    status:/ { if ($0 == "    status: " want) ok=1; found=0; next }
      { }
      END { exit ok ? 0 : 1 }
    ' "$CACHE_DIR/work-status.yaml"; then
      echo "    [iter $iter] work-status.yaml missing/wrong status for ENG-$i" >&2
      iter_ok=0
    fi
  done

  # Assertion 4: no stray tmp litter left behind in the cache dir.
  stray=$(find "$CACHE_DIR" -maxdepth 1 -name 'work-status.yaml.??????' 2>/dev/null)
  if [[ -n "$stray" ]]; then
    echo "    [iter $iter] stray tmp file(s) left behind: $stray" >&2
    iter_ok=0
  fi

  if [[ $iter_ok -eq 1 ]]; then
    pass "iteration $iter ($CONCURRENCY ids x2 concurrent refreshes) clean"
  else
    fail "iteration $iter ($CONCURRENCY ids x2 concurrent refreshes) — race reproduced"
    any_iteration_failed=1
  fi

  rm -rf "$SANDBOX"
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $any_iteration_failed -eq 0 ]]
