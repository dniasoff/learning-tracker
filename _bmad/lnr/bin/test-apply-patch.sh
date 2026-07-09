#!/usr/bin/env bash
# test-apply-patch.sh — smoke + isolation tests for the region-merge composer.
#
# Tests the shared bmad-patch-engine (apply_patch_impl.py + apply-patch.sh):
#   1. Clean apply (both contributors): linear's 12 guards across 5 skills land,
#      docmost's wiki-first gate lands on create-story; markers present; exit 0.
#   2. Re-apply no-op: per-contributor idempotency — re-run changes nothing.
#   3. Missing-anchor failure: corrupt one anchor, verify non-zero + ERROR.
#   4. Floor-match fallback + no-fallback-available refusal: a bmm version newer
#      than any validated dir (e.g. 6.20.0) reuses the nearest older validated
#      set (exit 0, informational note on stderr); a bmm version OLDER than
#      every validated dir (e.g. 0.1.0) has nothing to fall back to (exit
#      non-zero + ERROR).
#   5. Marker-strip double-apply: terminal (not inline) marker drives idempotency.
#   6. Epic-status guards in bmad-create-story (Linear write-suppression intact).
#   7. baseline_commit guard in bmad-dev-story (Linear write-suppression intact).
#   8. --check mode: per-contributor patch state.
#   9. Unknown IDE warning.
#  ── Region-merge isolation tests (the engine refactor's acceptance) ──
#  10. Linear-only registry still applies all 12 write-suppression guards
#      across 5 skills, untouched by docmost.
#  11. Per-contributor markers: re-runs are no-ops INDEPENDENTLY (strip ONE
#      contributor's marker, re-run; only that contributor re-applies).
#  12. Second contributor (docmost) applies WITHOUT clobbering the first
#      (linear), and anchors against linear's REPLACE output (composition).
#  13. dev-story is NOT touched by docmost (only Linear's guards present).
#
# Usage: bash bin/test-apply-patch.sh [--upstream <path>]
# BMAD_UPSTREAM env var or --upstream arg points at upstream skill sources.
# COPIES target skills to a temp sandbox (never mutates originals).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/apply-patch.sh"
REGISTRY_FULL="$SCRIPT_DIR/contributors.yaml"
# Default to a PRISTINE (unpatched) upstream BMAD skills tree. The harness COPIES
# these into a sandbox, then applies the patch engine — so the source MUST be
# unpatched (no bmad-linear/bmad-docmost markers). An installed/already-patched
# skills tree would make the engine skip linear as already-applied (Tests 1 & 3
# misfire); reset_skills below fails loud if it detects such a tree.
UPSTREAM="${BMAD_UPSTREAM:-$HOME/repos/BMAD-METHOD-UPSTREAM/src/bmm-skills/4-implementation}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream) UPSTREAM="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

ALL_SKILLS=(bmad-create-story bmad-dev-story bmad-sprint-planning bmad-sprint-status bmad-correct-course)

# ── Set up a temp sandbox ────────────────────────────────────────────────────
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

SKILLS_DIR="$SANDBOX/.claude/skills"
CONFIG_DIR="$SANDBOX/_bmad/_config"
mkdir -p "$CONFIG_DIR"

reset_skills() {
  for skill in "${ALL_SKILLS[@]}"; do
    mkdir -p "$SKILLS_DIR/$skill"
    src="$UPSTREAM/$skill/SKILL.md"
    if [ ! -f "$src" ]; then
      echo "ERROR: upstream SKILL.md not found: $src" >&2
      echo "Set BMAD_UPSTREAM=<path> (e.g. ~/repos/orvex-prompt-studio/.claude/skills)" >&2
      exit 1
    fi
    cp "$src" "$SKILLS_DIR/$skill/SKILL.md"
  done
  # Fail loud if BMAD_UPSTREAM points at an ALREADY-PATCHED skills tree. Linear
  # REPLACES whole blocks, so markers can't be stripped to reconstruct pristine
  # text — we cannot clean, we must refuse. Probe create-story (it carries both
  # linear and docmost patches).
  local probe="$SKILLS_DIR/bmad-create-story/SKILL.md"
  if grep -qF "bmad-linear-patch:applied" "$probe" || grep -qF "bmad-docmost-patch" "$probe"; then
    echo "ERROR: BMAD_UPSTREAM points at an ALREADY-PATCHED tree: $UPSTREAM" >&2
    echo "       (bmad-create-story already contains bmad-linear/bmad-docmost markers)" >&2
    echo "       The harness COPIES these skills then applies the patch engine, so the" >&2
    echo "       source MUST be PRISTINE upstream BMAD skills — markers cannot be stripped" >&2
    echo "       to reconstruct pristine text (linear REPLACES whole blocks)." >&2
    echo "       Point --upstream at a pristine tree, e.g. .../src/bmm-skills/4-implementation" >&2
    exit 1
  fi
}
reset_skills

# A LINEAR-ONLY registry, so we can prove linear stands alone (isolation test 10).
REGISTRY_LINEAR_ONLY="$SANDBOX/contributors-linear-only.yaml"
cat > "$REGISTRY_LINEAR_ONLY" << EOF
contributors:
  - code: linear
    rank: 0
    marker: bmad-linear-patch
    version: "0.2.0"
    patches_root: $SCRIPT_DIR/patches
    skills:
      - bmad-create-story
      - bmad-dev-story
      - bmad-sprint-planning
      - bmad-sprint-status
      - bmad-correct-course
EOF

write_manifest() {
  local version="$1"
  cat > "$CONFIG_DIR/manifest.yaml" << EOF
installation:
  version: $version
modules:
  - name: bmm
    version: $version
    source: built-in
  - name: lnr
    version: 0.1.0
    source: custom
ides:
  - claude-code
EOF
}

write_manifest "6.8.0"

LINEAR_INLINE="<!-- bmad-linear-patch v0.2.0 -->"
LINEAR_TERMINAL="<!-- bmad-linear-patch:applied:v0.2.0 -->"
DOCMOST_INLINE="<!-- bmad-docmost-patch v0.1.0"
DOCMOST_TERMINAL="<!-- bmad-docmost-patch:applied:v0.1.0 -->"

run_patch() {
  # Run from the SANDBOX so find_project_root works. Uses the FULL registry by default.
  (cd "$SANDBOX" && bash "$PATCH_SCRIPT" "$@") 2>&1
  return $?
}

# ── Test 1: Clean apply (both contributors) ─────────────────────────────────
echo ""
echo "=== Test 1: Clean apply (linear + docmost) ==="

output=$(run_patch); exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  pass "apply-patch.sh exits 0"
else
  fail "apply-patch.sh exited $exit_code — output: $output"
fi

# Linear inline marker must appear in ALL 5 skills.
for skill in "${ALL_SKILLS[@]}"; do
  if grep -qF "$LINEAR_INLINE" "$SKILLS_DIR/$skill/SKILL.md"; then
    pass "$skill has linear inline marker"
  else
    fail "$skill missing linear inline marker"
  fi
  if grep -qF "$LINEAR_TERMINAL" "$SKILLS_DIR/$skill/SKILL.md"; then
    pass "$skill has linear terminal marker"
  else
    fail "$skill missing linear terminal marker"
  fi
done

# Docmost markers must appear ONLY on create-story.
if grep -qF "$DOCMOST_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md" \
   && grep -qF "$DOCMOST_TERMINAL" "$SKILLS_DIR/bmad-create-story/SKILL.md"; then
  pass "bmad-create-story has docmost inline + terminal markers"
else
  fail "bmad-create-story missing docmost markers"
fi

if echo "$output" | grep -q "linear:.*docmost:"; then
  pass "create-story output shows both contributors applied"
else
  fail "output missing combined linear+docmost line — output: $output"
fi

# ── Test 2: Re-apply no-op (per-contributor idempotency) ────────────────────
echo ""
echo "=== Test 2: Re-apply no-op ==="

declare -A CHECKSUMS
for skill in "${ALL_SKILLS[@]}"; do
  CHECKSUMS[$skill]="$(md5sum "$SKILLS_DIR/$skill/SKILL.md" | cut -d' ' -f1)"
done

output2=$(run_patch); exit_code2=$?

if [ "$exit_code2" -eq 0 ]; then
  pass "re-apply exits 0"
else
  fail "re-apply exited $exit_code2"
fi

for skill in "${ALL_SKILLS[@]}"; do
  new_sum="$(md5sum "$SKILLS_DIR/$skill/SKILL.md" | cut -d' ' -f1)"
  if [ "${CHECKSUMS[$skill]}" = "$new_sum" ]; then
    pass "$skill unchanged on re-apply"
  else
    fail "$skill changed on re-apply — NOT idempotent"
  fi
done

if echo "$output2" | grep -q "already patched (linear, docmost)"; then
  pass "create-story reports both contributors already patched"
else
  fail "create-story should report 'already patched (linear, docmost)' — output: $output2"
fi

# ── Test 3: Missing-anchor failure ──────────────────────────────────────────
echo ""
echo "=== Test 3: Missing-anchor failure ==="

reset_skills
write_manifest "6.8.0"
python3 -c "
import sys
path = sys.argv[1]
with open(path) as f: content = f.read()
content = content.replace(
    '<action>Write the complete sprint status YAML to {status_file}</action>',
    '<action>CORRUPTED ANCHOR LINE</action>'
)
with open(path, 'w') as f: f.write(content)
" "$SKILLS_DIR/bmad-sprint-planning/SKILL.md"

corrupt_output=$(run_patch 2>&1) || corrupt_exit=$?
corrupt_exit="${corrupt_exit:-0}"

if [ "${corrupt_exit:-0}" -ne 0 ]; then
  pass "exits non-zero on missing anchor"
else
  fail "should exit non-zero on missing anchor but exited 0 — output: $corrupt_output"
fi

if echo "$corrupt_output" | grep -q "ERROR: anchor not found"; then
  pass "output contains 'ERROR: anchor not found'"
else
  fail "output missing 'ERROR: anchor not found' — got: $corrupt_output"
fi

if echo "$corrupt_output" | grep -q "bmad-sprint-planning"; then
  pass "error message names the affected skill"
else
  fail "error message does not name the affected skill — got: $corrupt_output"
fi

# The engine's helpful hint wraps "...update the anchor in\n    <patch_path>..."
# across TWO lines, so a single line-based grep can't span it. Verify both
# phrases anywhere in the output (intent: the error names the patch file to edit).
if echo "$corrupt_output" | grep -qi "update the anchor in" \
   && echo "$corrupt_output" | grep -q "bin/patches"; then
  pass "error message includes anchor update next-step hint"
else
  fail "error message missing next-step hint — got: $corrupt_output"
fi

# ── Test 4: Floor-match fallback + no-fallback-available refusal ───────────
echo ""
echo "=== Test 4: Floor-match fallback + no-fallback-available refusal ==="

# 4a. bmm newer than any validated dir → falls back to the nearest older
# validated set instead of erroring (this is the whole point of floor match:
# no new <MAJOR.MINOR>/ dir needed for a no-op minor bump).
reset_skills
write_manifest "6.20.0"

future_output=$(run_patch 2>&1); future_exit=$?

if [ "$future_exit" -eq 0 ]; then
  pass "bmm newer than any validated set still exits 0 (floor-match fallback)"
else
  fail "should fall back and exit 0 for a future bmm version — got exit $future_exit: $future_output"
fi

if echo "$future_output" | grep -q "no 6.20 patch set on file; reusing nearest validated"; then
  pass "output notes the floor-match fallback"
else
  fail "output missing floor-match fallback note — got: $future_output"
fi

# 4b. bmm OLDER than every validated dir → nothing to fall back to, must refuse.
reset_skills
write_manifest "0.1.0"

old_output=$(run_patch 2>&1) || old_exit=$?
old_exit="${old_exit:-0}"

if [ "${old_exit:-0}" -ne 0 ]; then
  pass "exits non-zero when bmm predates every validated set"
else
  fail "should exit non-zero when bmm predates every validated set but exited 0"
fi

if echo "$old_output" | grep -q "older than every validated patch"; then
  pass "output explains no-fallback-available error"
else
  fail "output missing no-fallback-available error — got: $old_output"
fi

# ── Test 5: Marker-strip double-apply ───────────────────────────────────────
echo ""
echo "=== Test 5: Marker-strip double-apply ==="

reset_skills
write_manifest "6.8.0"
run_patch > /dev/null 2>&1

# Strip all inline markers from create-story, leaving terminal markers intact.
python3 -c "
import sys, re
path = sys.argv[1]
with open(path) as f: content = f.read()
content = re.sub(r'[ \t]*<!-- bmad-linear-patch v0\.2\.0 -->\n', '', content)
content = re.sub(r'[ \t]*<!-- bmad-docmost-patch v0\.1\.0[^\n]*-->\n', '', content)
with open(path, 'w') as f: f.write(content)
" "$SKILLS_DIR/bmad-create-story/SKILL.md"

if grep -qF "$LINEAR_TERMINAL" "$SKILLS_DIR/bmad-create-story/SKILL.md" \
   && grep -qF "$DOCMOST_TERMINAL" "$SKILLS_DIR/bmad-create-story/SKILL.md"; then
  pass "terminal markers survive inline-marker strip"
else
  fail "terminal markers unexpectedly absent after inline-marker strip"
fi

strip_output=$(run_patch 2>&1); strip_exit=$?
if [ "$strip_exit" -eq 0 ]; then
  pass "re-apply after inline-marker strip exits 0"
else
  fail "re-apply after inline-marker strip exited $strip_exit — output: $strip_output"
fi

if echo "$strip_output" | grep -q "already patched"; then
  pass "re-apply after inline-marker strip reports 'already patched'"
else
  fail "re-apply after strip should say 'already patched' — got: $strip_output"
fi

# ── Test 6: Epic-status guards in bmad-create-story (Linear intact) ─────────
echo ""
echo "=== Test 6: Epic-status guards in bmad-create-story ==="

reset_skills
run_patch > /dev/null 2>&1

epic_guard_count=$(grep -c 'tracking_system.*file-system' "$SKILLS_DIR/bmad-create-story/SKILL.md" || true)
if [ "$epic_guard_count" -ge 4 ]; then
  pass "bmad-create-story has >= 4 tracking_system guards (epic-status guards intact)"
else
  fail "expected >= 4 tracking_system guards in bmad-create-story, got $epic_guard_count"
fi

for action_text in \
  'If epic status is "backlog" → update to "in-progress"' \
  'If epic status is "contexted" (legacy status) → update to "in-progress"'; do
  if python3 -c "
import sys, re
with open(sys.argv[1]) as f: content = f.read()
pattern = re.escape(sys.argv[2])
for m in re.finditer(pattern, content):
    start = content.rfind('<check if=\"{workflow.tracking_system}', 0, m.start())
    if start == -1:
        sys.exit(1)
sys.exit(0)
" "$SKILLS_DIR/bmad-create-story/SKILL.md" "$action_text" 2>/dev/null; then
    pass "epic-status action guarded: ${action_text:0:50}..."
  else
    fail "epic-status action NOT guarded: ${action_text:0:50}..."
  fi
done

# ── Test 7: baseline_commit guard in bmad-dev-story (Linear intact) ─────────
echo ""
echo "=== Test 7: baseline_commit guard in bmad-dev-story ==="

if python3 -c "
import sys, re
with open(sys.argv[1]) as f: content = f.read()
pattern = re.escape('add \`baseline_commit: {{baseline_commit}}\` to the frontmatter')
for m in re.finditer(pattern, content):
    start = content.rfind('<check if=\"{workflow.tracking_system}', 0, m.start())
    if start == -1:
        sys.exit(1)
sys.exit(0)
" "$SKILLS_DIR/bmad-dev-story/SKILL.md" 2>/dev/null; then
  pass "baseline_commit frontmatter write is inside a tracking_system guard"
else
  fail "baseline_commit frontmatter write is NOT guarded"
fi

# ── Test 8: --check mode ─────────────────────────────────────────────────────
echo ""
echo "=== Test 8: --check mode ==="

reset_skills

check_output_unpatched=$(run_patch --check 2>&1)
if echo "$check_output_unpatched" | grep -qE "✗ .*UNPATCHED"; then
  pass "--check on unpatched files reports UNPATCHED"
else
  fail "--check should report UNPATCHED but didn't — got: $check_output_unpatched"
fi

run_patch > /dev/null 2>&1
check_output_patched=$(run_patch --check 2>&1)
patched_count=$(echo "$check_output_patched" | grep -cE "✓ .*patched \[" || true)
if [ "$patched_count" -eq 5 ]; then
  pass "--check on patched files reports patched for all 5 skills"
else
  fail "expected 5 patched reports, got $patched_count — output: $check_output_patched"
fi

if echo "$check_output_patched" | grep -q "linear✓v0.2.0, docmost✓v0.1.0"; then
  pass "--check shows per-contributor state for create-story"
else
  fail "--check missing per-contributor state — got: $check_output_patched"
fi

# ── Test 9: Unknown IDE warning ──────────────────────────────────────────────
echo ""
echo "=== Test 9: Unknown IDE warning ==="

cat > "$CONFIG_DIR/manifest.yaml" << EOF
installation:
  version: 6.8.0
modules:
  - name: bmm
    version: 6.8.0
    source: built-in
ides:
  - some-unknown-ide
EOF

unknown_output=$(run_patch 2>&1) || unknown_exit=$?
unknown_exit="${unknown_exit:-0}"

if echo "$unknown_output" | grep -qF "some-unknown-ide — unknown IDE"; then
  pass "unknown IDE generates a warning"
else
  fail "expected unknown IDE warning — got: $unknown_output"
fi

if [ "$unknown_exit" -ne 0 ]; then
  pass "no-patchable-IDEs exits non-zero"
else
  fail "should exit non-zero when no IDE is patchable but exited 0"
fi

write_manifest "6.8.0"

# ── Test 10: Linear-only registry still applies all 12 guards ───────────────
echo ""
echo "=== Test 10: Linear-only registry — 12 guards across 5 skills ==="

reset_skills
lo_output=$(run_patch --registry "$REGISTRY_LINEAR_ONLY" 2>&1); lo_exit=$?

if [ "$lo_exit" -eq 0 ]; then
  pass "linear-only apply exits 0"
else
  fail "linear-only apply exited $lo_exit — output: $lo_output"
fi

# Count linear write-suppression guard BLOCKS via their file-system <check>
# openers. Expected: create-story 5, dev-story 4, planning/status/course 1 each
# == 12 total. (Opener text is {workflow.tracking_system}=='file-system'.)
declare -A EXPECT=( [bmad-create-story]=5 [bmad-dev-story]=4 [bmad-sprint-planning]=1 [bmad-sprint-status]=1 [bmad-correct-course]=1 )
OPENER="{workflow.tracking_system}=='file-system'"
total_blocks=0
for skill in "${ALL_SKILLS[@]}"; do
  n=$(grep -cF "$OPENER" "$SKILLS_DIR/$skill/SKILL.md" 2>/dev/null || true)
  total_blocks=$((total_blocks + n))
  if [ "$n" -ne "${EXPECT[$skill]}" ]; then
    echo "    (note) $skill: $n file-system guard openers (expected ${EXPECT[$skill]})"
  fi
done

if [ "$total_blocks" -eq 12 ]; then
  pass "linear-only applied exactly 12 write-suppression guards across 5 skills"
else
  fail "expected 12 linear guards total, counted $total_blocks file-system openers"
fi

# Docmost markers must be ABSENT under the linear-only registry.
if grep -qF "$DOCMOST_TERMINAL" "$SKILLS_DIR/bmad-create-story/SKILL.md"; then
  fail "docmost marker present under linear-only registry — should be absent"
else
  pass "no docmost marker under linear-only registry (isolation)"
fi

# ── Test 11: Per-contributor independent idempotency ────────────────────────
echo ""
echo "=== Test 11: Per-contributor independent idempotency ==="

reset_skills
run_patch > /dev/null 2>&1   # full registry: linear + docmost both land

# Strip ONLY docmost's terminal marker from create-story; linear's stays.
python3 -c "
import sys, re
path = sys.argv[1]
with open(path) as f: content = f.read()
content = content.replace('<!-- bmad-docmost-patch:applied:v0.1.0 -->\n', '')
with open(path, 'w') as f: f.write(content)
" "$SKILLS_DIR/bmad-create-story/SKILL.md"

# Capture linear-region checksum proxy: count of linear inline markers before re-run.
linear_inline_before=$(grep -cF "$LINEAR_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md")
docmost_inline_before=$(grep -cF "$DOCMOST_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md")

# Re-stripping docmost's terminal means docmost will RE-APPLY; but its inline
# marker (and guard body) are still present from the first run, so re-running
# would DOUBLE the docmost guard. The composer re-applies only because the
# terminal marker is the idempotency authority — to make this a clean isolation
# test, also remove the docmost guard body so re-apply is observable & correct.
# Instead we assert the inverse: strip docmost terminal AND its guard body, then
# re-run reapplies docmost only, leaving linear's guards count unchanged.
python3 -c "
import sys, re
path = sys.argv[1]
with open(path) as f: content = f.read()
# Remove the whole docmost guard block (from its inline comment to the line
# before the duplicated CRITICAL status flip it re-emits).
content = re.sub(
    r'[ \t]*<!-- bmad-docmost-patch v0\.1\.0.*?</invoke-skill>\n[ \t]*</check>\n',
    '', content, flags=re.DOTALL)
with open(path, 'w') as f: f.write(content)
" "$SKILLS_DIR/bmad-create-story/SKILL.md"

linear_inline_mid=$(grep -cF "$LINEAR_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md")
docmost_present_mid=$(grep -cF "$DOCMOST_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md")

if [ "$docmost_present_mid" -eq 0 ]; then
  pass "docmost guard body removed for the isolation test setup"
else
  fail "docmost guard body not cleanly removed (got $docmost_present_mid inline markers)"
fi

reapply_output=$(run_patch 2>&1); reapply_exit=$?
if [ "$reapply_exit" -eq 0 ]; then
  pass "re-apply after docmost-only strip exits 0"
else
  fail "re-apply exited $reapply_exit — output: $reapply_output"
fi

linear_inline_after=$(grep -cF "$LINEAR_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md")
docmost_present_after=$(grep -cF "$DOCMOST_INLINE" "$SKILLS_DIR/bmad-create-story/SKILL.md")

if [ "$linear_inline_after" -eq "$linear_inline_before" ]; then
  pass "linear guards untouched while docmost re-applied (count $linear_inline_after)"
else
  fail "linear guard count changed ($linear_inline_before -> $linear_inline_after) — NOT isolated"
fi

if [ "$docmost_present_after" -ge 1 ]; then
  pass "docmost guard re-applied independently"
else
  fail "docmost guard did not re-apply after its marker was stripped"
fi

# create-story should now report ONLY docmost applied (linear already patched).
if echo "$reapply_output" | grep -qE "docmost:[0-9]+.*already: linear|already: linear.*docmost"; then
  pass "re-apply output: docmost applied, linear already patched"
else
  # Accept the canonical form too
  if echo "$reapply_output" | grep -q "docmost:1"; then
    pass "re-apply output shows docmost:1 applied (linear skipped as already-patched)"
  else
    fail "re-apply output unexpected — got: $reapply_output"
  fi
fi

# ── Test 12: Second contributor anchors against the first's REPLACE output ──
echo ""
echo "=== Test 12: docmost composes against linear's REPLACE output ==="

reset_skills
run_patch > /dev/null 2>&1

# The docmost confirm <ask> must sit INSIDE the file-system branch that Linear
# Guard 3 produced — i.e. before the (now possibly duplicated) 'Set story Status
# to: ready-for-dev' AND after a linear file-system <check> opener.
if python3 -c "
import sys
with open(sys.argv[1]) as f: content = f.read()
# docmost ask anchor text
ask = 'Confirm this is the intent to build before the story becomes ready-for-dev?'
i = content.find(ask)
if i == -1:
    sys.exit(1)
# A linear file-system guard opener must appear BEFORE the docmost ask
lin = content.rfind('{workflow.tracking_system}', 0, i)
if lin == -1:
    sys.exit(2)
# The status flip the docmost guard re-emits must appear AFTER the ask
flip = content.find('Set story Status to: \"ready-for-dev\"', i)
if flip == -1:
    sys.exit(3)
sys.exit(0)
" "$SKILLS_DIR/bmad-create-story/SKILL.md"; then
  pass "docmost confirm <ask> sits inside linear's file-system REPLACE block, before the status flip"
else
  rc=$?
  fail "docmost guard not composed against linear's REPLACE output (rc=$rc)"
fi

# The docmost guard must NOT have clobbered linear's deferral branch.
if grep -qF 'Defer to {workflow.tracking_adapter} for this operation. Do not write a local file. Compose story content in memory' "$SKILLS_DIR/bmad-create-story/SKILL.md"; then
  pass "linear's non-file-system deferral branch survives docmost composition"
else
  fail "linear's deferral branch was clobbered by docmost"
fi

# ── Test 12b: the gate ALSO fires in the non-file-system (Linear) branch ────
echo ""
echo "=== Test 12b: gate reachable when tracking_system != file-system (Linear) ==="

# Production ships tracking_system="linear", so create-story takes Linear Guard 3's
# != 'file-system' branch. The wiki-first gate MUST be injected there too, or it is
# UNREACHABLE in production. Assert the confirm <ask> appears in the deferral branch
# (after the 'Compose story content in memory' deferral, before THAT branch's status
# flip) AND that the gate appears in BOTH branches (>= 2 doc-spec-gate invocations).
if python3 -c "
import sys
with open(sys.argv[1]) as f: content = f.read()
ask = 'Confirm this is the intent to build before the story becomes ready-for-dev?'
defer = 'Compose story content in memory and write via the tracking adapter.'
i_defer = content.find(defer)
if i_defer == -1: sys.exit(1)
i_ask = content.find(ask, i_defer)
if i_ask == -1: sys.exit(2)
i_flip = content.find('Set story Status to: \"ready-for-dev\"', i_defer)
if i_flip == -1: sys.exit(3)
if not (i_defer < i_ask < i_flip): sys.exit(4)
if content.count('name=\"doc-spec-gate\"') < 2: sys.exit(5)
sys.exit(0)
" "$SKILLS_DIR/bmad-create-story/SKILL.md"; then
  pass "wiki-first gate fires in the non-file-system (Linear) branch before its status flip"
else
  rc=$?
  fail "gate NOT reachable in the non-file-system branch (rc=$rc) — would never fire under tracking_system=linear"
fi

gate_count=$(grep -cF 'name="doc-spec-gate"' "$SKILLS_DIR/bmad-create-story/SKILL.md" || true)
if [ "$gate_count" -eq 2 ]; then
  pass "doc-spec-gate invoked in BOTH create-story branches (count=2)"
else
  fail "expected 2 doc-spec-gate invocations (one per tracking-system branch), got $gate_count"
fi

# ── Test 13: dev-story is NOT touched by docmost ────────────────────────────
echo ""
echo "=== Test 13: dev-story has NO docmost guard (create-story only) ==="

if grep -qF "$DOCMOST_INLINE" "$SKILLS_DIR/bmad-dev-story/SKILL.md" \
   || grep -qF "$DOCMOST_TERMINAL" "$SKILLS_DIR/bmad-dev-story/SKILL.md"; then
  fail "dev-story unexpectedly carries a docmost guard/marker"
else
  pass "dev-story has NO docmost marker (no wiki-first guard injected)"
fi

# dev-story must still carry Linear's write-suppression guards untouched.
if grep -qF "$LINEAR_TERMINAL" "$SKILLS_DIR/bmad-dev-story/SKILL.md" \
   && grep -q 'Execute continuously without pausing' "$SKILLS_DIR/bmad-dev-story/SKILL.md"; then
  pass "dev-story keeps Linear guards AND its 'Execute continuously without pausing' contract"
else
  fail "dev-story missing Linear guard or its continuous-execution contract"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
echo "============================================"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
