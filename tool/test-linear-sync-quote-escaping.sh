#!/usr/bin/env bash
# test-linear-sync-quote-escaping.sh — regression guard for AUD-guardrails-11.
#
# tool/linear-sync.sh built quoted YAML scalars for issue titles and comment
# author names by raw string-concatenating a Linear-supplied value between
# literal `\"` delimiters (jq `"...\"" + .title + "\""`), with no escaping of
# embedded `"` characters. A Linear issue titled e.g. `Fix "broken" login`
# (or a comment author display name containing a quote) produced a malformed
# line like `title: "Fix "broken" login"` in sprint-status.yaml, the
# per-story .yaml cache files, AND the generated epics.md — silently corrupt,
# since jq itself exits 0 (set -e never catches it).
#
# The fix replaces the manual concatenation with jq's `tojson`, which
# correctly escapes embedded quotes/backslashes and stays valid YAML
# flow-scalar syntax, at all 5 sites named in the finding (lines 301, 323,
# 336, 381, 388 of the pre-fix file).
#
# This test runs the REAL script (tool/linear-sync.sh) end-to-end via its
# public CLI (`sync` and `story <ID>`), with `linearis` stubbed (the only
# true external boundary) to return a synthetic epic and story whose titles
# contain an embedded `"`, and a comment whose author name contains an
# embedded `"` — covering all 5 sites.
#
# Asserts:
#   1. `sync` exits 0
#   2. sprint-status.yaml parses cleanly as YAML (python3 yaml.safe_load)
#      AND the epic/story titles round-trip EXACTLY (embedded quote intact,
#      not truncated/corrupted into a sibling malformed key)
#   3. the per-story cache file written by `sync` (stories/<ID>.yaml) parses
#      cleanly and its title round-trips exactly
#   4. `story <ID>` exits 0, its (rewritten) cache file parses cleanly, and
#      both the title and the comment author round-trip exactly
#
# Usage: bash test-linear-sync-quote-escaping.sh [path/to/linear-sync.sh]
#   (defaults to the sibling tool/linear-sync.sh — an explicit path lets you
#   point this test at a pre-fix copy to confirm it goes red)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_SCRIPT="${1:-$SCRIPT_DIR/linear-sync.sh}"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH (needed for YAML validation)"; exit 1; }
python3 -c "import yaml" >/dev/null 2>&1 || { echo "ERROR: python3 'yaml' module (pyyaml) not importable"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found in PATH"; exit 1; }

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# Sandbox the script's own relative layout: linear-sync.sh derives
# PROJECT_ROOT as SCRIPT_DIR/.. and reads PROJECT_ROOT/_bmad/bmm/config.yaml,
# so copying it under $SANDBOX/tool/ gives us a fully isolated PROJECT_ROOT
# and CONFIG with no risk of touching the real repo/cache.
mkdir -p "$SANDBOX/tool" "$SANDBOX/_bmad/bmm" "$SANDBOX/bin" "$SANDBOX/docs/planning"
cp "$SYNC_SCRIPT" "$SANDBOX/tool/linear-sync.sh"
chmod +x "$SANDBOX/tool/linear-sync.sh"

cat > "$SANDBOX/_bmad/bmm/config.yaml" <<'EOF'
project_name: quote-test
planning_artifacts: "{project-root}/docs/planning"
team_key: ENG
linear_tenant: test-tenant
linear_project: Test Project
EOF

export EPIC_TITLE='[Epic-9] Setup "quoted" epic'
export STORY_TITLE='[1.1] Fix "broken" login'
export AUTHOR_NAME='Jane "JD" Doe'

# Stub linearis: the only true external boundary linear-sync.sh crosses.
# Reads the fixture strings from its own environment (exported above) so the
# heredoc itself can stay single-quoted (no premature shell expansion).
cat > "$SANDBOX/bin/linearis" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "issues" && "$2" == "list" ]]; then
  jq -n --arg epic_title "$EPIC_TITLE" --arg story_title "$STORY_TITLE" '
    {
      nodes: [
        {identifier: "ENG-9", title: $epic_title, state: {name: "Backlog"}, parent: null},
        {identifier: "ENG-11", title: $story_title, state: {name: "Backlog"}, parent: null}
      ],
      pageInfo: {hasNextPage: false, endCursor: null}
    }
  '
  exit 0
fi
if [[ "$1" == "issues" && "$2" == "read" ]]; then
  jq -n --arg story_title "$STORY_TITLE" --arg author "$AUTHOR_NAME" '
    {
      identifier: "ENG-11",
      title: $story_title,
      state: {name: "Backlog"},
      parentIssue: null,
      description: "",
      comments: [
        {user: {name: $author}, body: "looks good"}
      ]
    }
  '
  exit 0
fi
echo "unsupported stub call: $*" >&2
exit 1
STUB
chmod +x "$SANDBOX/bin/linearis"

CACHE_DIR="$SANDBOX/xdg/linear-sync/test-tenant/test-project"

# ---------- YAML validation helpers ----------
check_sprint_status() {
  local file="$1"
  python3 - "$file" "$EPIC_TITLE" "$STORY_TITLE" <<'PY'
import sys, yaml
path, epic_title, story_title = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = yaml.safe_load(f)
assert isinstance(data, dict), "top-level YAML did not parse to a mapping"
got_epic = data["epics"]["ENG-9"]["title"]
got_story = data["stories"]["ENG-11"]["title"]
assert got_epic == epic_title, f"epic title mismatch: got {got_epic!r} want {epic_title!r}"
assert got_story == story_title, f"story title mismatch: got {got_story!r} want {story_title!r}"
print("OK")
PY
}

check_story_file_title() {
  local file="$1" want_title="$2"
  python3 - "$file" "$want_title" <<'PY'
import sys, yaml
path, want_title = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = yaml.safe_load(f)
assert isinstance(data, dict), "top-level YAML did not parse to a mapping"
got = data["title"]
assert got == want_title, f"title mismatch: got {got!r} want {want_title!r}"
print("OK")
PY
}

check_story_file_full() {
  local file="$1" want_title="$2" want_author="$3"
  python3 - "$file" "$want_title" "$want_author" <<'PY'
import sys, yaml
path, want_title, want_author = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = yaml.safe_load(f)
assert isinstance(data, dict), "top-level YAML did not parse to a mapping"
got_title = data["title"]
assert got_title == want_title, f"title mismatch: got {got_title!r} want {want_title!r}"
comments = data.get("comments")
assert isinstance(comments, list) and len(comments) == 1, f"expected exactly 1 comment, got {comments!r}"
got_author = comments[0]["author"]
assert got_author == want_author, f"author mismatch: got {got_author!r} want {want_author!r}"
print("OK")
PY
}

# ---------- run: sync ----------
cd "$SANDBOX" || exit 99
SYNC_OUT="$SANDBOX/sync.out"
SYNC_ERR="$SANDBOX/sync.err"
XDG_DATA_HOME="$SANDBOX/xdg" PATH="$SANDBOX/bin:$PATH" bash "$SANDBOX/tool/linear-sync.sh" sync > "$SYNC_OUT" 2> "$SYNC_ERR"
sync_exit=$?

if [[ $sync_exit -eq 0 ]]; then
  pass "sync exited 0"
else
  fail "sync exited $sync_exit (expected 0) — stderr:"
  cat "$SYNC_ERR" >&2
fi

if out=$(check_sprint_status "$CACHE_DIR/sprint-status.yaml" 2>&1) && [[ "$out" == "OK" ]]; then
  pass "sprint-status.yaml parses as valid YAML with exact epic+story title round-trip"
else
  fail "sprint-status.yaml invalid or title corrupted: $out"
fi

if out=$(check_story_file_title "$CACHE_DIR/stories/ENG-11.yaml" "$STORY_TITLE" 2>&1) && [[ "$out" == "OK" ]]; then
  pass "stories/ENG-11.yaml (written by sync) parses as valid YAML with exact title round-trip"
else
  fail "stories/ENG-11.yaml invalid or title corrupted: $out"
fi

# ---------- run: story <ID> (covers comment-author site) ----------
STORY_OUT="$SANDBOX/story.out"
STORY_ERR="$SANDBOX/story.err"
XDG_DATA_HOME="$SANDBOX/xdg" PATH="$SANDBOX/bin:$PATH" bash "$SANDBOX/tool/linear-sync.sh" story ENG-11 > "$STORY_OUT" 2> "$STORY_ERR"
story_exit=$?

if [[ $story_exit -eq 0 ]]; then
  pass "story ENG-11 exited 0"
else
  fail "story ENG-11 exited $story_exit (expected 0) — stderr:"
  cat "$STORY_ERR" >&2
fi

if out=$(check_story_file_full "$CACHE_DIR/stories/ENG-11.yaml" "$STORY_TITLE" "$AUTHOR_NAME" 2>&1) && [[ "$out" == "OK" ]]; then
  pass "stories/ENG-11.yaml (rewritten by 'story') parses as valid YAML with exact title AND comment-author round-trip"
else
  fail "stories/ENG-11.yaml (post 'story') invalid or title/author corrupted: $out"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
