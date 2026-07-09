#!/usr/bin/env bash
# apply-patch.sh — entry point for the shared bmad-patch-engine (region-merge composer).
#
# Composes the GUARD-block substitutions contributed by MULTIPLE modules
# (bmad-linear write-suppression + bmad-docmost wiki-first gate, …) into the
# installed BMAD implementation SKILL.md files, in a single pass, with
# per-contributor idempotency. Contributors are declared in bin/contributors.yaml
# (the registry), each with its own rank, marker, version, patches-dir and skill
# list — there is no hardcoded skill list any more.
#
# Run after every `npx bmad-method install` or Quick Update.
#
# Usage:
#   apply-patch.sh [--dry-run] [--check] [--verbose] [--registry <path>]
#
# Modes:
#   --check         Report current patch state per (IDE, skill) per contributor; no file edits.
#   --dry-run       Show the composed result as a unified diff; no file edits.
#   --verbose       Log contributor order + each guard's file:line range as it is applied.
#   --registry P    Use an alternate contributors.yaml (defaults to one beside the engine).
#
# Exit codes:
#   0  — all contributors composed (or already patched / --check passed)
#   1  — hard failure (missing anchor, version mismatch, dependency unavailable)

set -euo pipefail

# ── Mode flags ──────────────────────────────────────────────────────────────
DRY_RUN=0
VERBOSE=0
CHECK=0
REGISTRY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --check)   CHECK=1 ;;
    --verbose) VERBOSE=1 ;;
    --registry) REGISTRY="$2"; shift ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Locate project root (walk up to find _bmad/) ────────────────────────────
find_project_root() {
  local dir
  dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/_bmad" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "ERROR: could not find _bmad/ directory. Run from within a BMAD project." >&2
  return 1
}

PROJECT_ROOT="$(find_project_root)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$PROJECT_ROOT/_bmad/_config/manifest.yaml"

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: manifest not found at $MANIFEST. Has bmad-method been installed?" >&2
  exit 1
fi

# ── Sanity-check Python + PyYAML ────────────────────────────────────────────
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "ERROR: Python 3 with PyYAML is required. Install with: pip install pyyaml (or pip3 install pyyaml)" >&2
  exit 1
fi

# ── Delegate the whole compose loop to the Python impl ──────────────────────
# The Python composer reads the manifest, the contributor registry
# (bin/contributors.yaml unless --registry overrides), resolves each IDE's
# skills dir, and composes every contributing module's guard sets per
# (ide, skill) pair in rank order. --patches-dir is the fallback patches_root
# for any registry entry that does not declare its own.
REGISTRY_ARGS=()
if [ -n "$REGISTRY" ]; then
  REGISTRY_ARGS=(--registry "$REGISTRY")
fi

exec python3 "$SCRIPT_DIR/apply_patch_impl.py" \
  --manifest    "$MANIFEST" \
  --project-root "$PROJECT_ROOT" \
  --patches-dir "$SCRIPT_DIR/patches" \
  "${REGISTRY_ARGS[@]}" \
  --dry-run    "$DRY_RUN" \
  --check      "$CHECK" \
  --verbose    "$VERBOSE"
