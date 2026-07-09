#!/usr/bin/env python3
"""
apply_patch_impl.py — region-merge patch composer for apply-patch.sh.

This is the shared `bmad-patch-engine` (PLAN §C.2). It composes GUARD-block
substitutions contributed by MULTIPLE modules (bmad-linear, bmad-docmost, …)
into the installed BMAD implementation SKILL.md files, in a single pass, with
per-contributor idempotency.

It reads `_bmad/_config/manifest.yaml` to discover (a) the installed bmm version
(used to pick the nearest validated patch-set dir `patches/<MAJOR.MINOR>/` per
contributor — see resolve_patch_dirs()'s floor-match: an exact dir is not
required, the highest validated version <= the installed bmm is reused) and
(b) the list of installed IDEs (used to locate each IDE's skills directory).
Then, for each (IDE, skill) pair, it applies — in a defined
contributor order — every contributing module's guard set, re-deriving each
guard's anchor against the ALREADY-PATCHED running buffer so a later
contributor's anchor can target an earlier contributor's REPLACE output.

WHY A COMPOSER (PLAN §C.2 / review C-1, C-2, BL-1):
  - The old engine bailed on a SINGLE global terminal marker before applying any
    guards, so whichever module patched first silently skipped the second.
    Now each contributor has its OWN marker; idempotency is per-contributor.
  - Linear's create-story Guard 3 REPLACES the whole Step-5 body. A docmost guard
    must anchor against THAT replacement output, not the upstream original. The
    composer applies contributors in rank order against one running buffer, so
    re-derivation against the patched text is automatic.

CONTRIBUTOR REGISTRY:
  Contributors are declared in `contributors.yaml` (next to this script — see
  CONTRIBUTOR_REGISTRY below). Each entry supplies its own rank, marker name,
  patches-dir, and skill list. SKILL_NAMES is no longer hardcoded. The registry
  lives in the patch engine, NOT in any module.yaml.

Modes:
  --dry-run 1  Show unified diff of the composed result; do not write.
  --check 1    Report per-(IDE, skill) per-contributor patch state; do not write.
  --verbose 1  Log each guard's file:line range as it lands.

Patch DSL (one or more GUARD blocks per .patch file):
----------------------------------------------------------------------
GUARD_START
ANCHOR_BEGIN
<exact line(s) to match, verbatim — leading/trailing whitespace preserved>
ANCHOR_END
REPLACE_BEGIN
<replacement text>
REPLACE_END
GUARD_END
----------------------------------------------------------------------

Exit codes: 0 success / --check ok; 1 missing anchor / version mismatch / dep error.
"""
import argparse
import difflib
import os
import re
import sys

import yaml


# Per-IDE skills directory, relative to project root. Sourced from BMAD's
# tools/installer/ide/platform-codes.yaml. Entries here = IDEs we know how to
# patch; unknown IDEs (anything in manifest.ides but not in this map) are
# reported and skipped with a warning rather than silently ignored.
IDE_SKILLS_DIRS = {
    "claude-code":  ".claude/skills",
    "adal":         ".adal/skills",
    "amp":          ".agents/skills",
    "antigravity":  ".agent/skills",
    "auggie":       ".agents/skills",
    "bob":          ".bob/skills",
    "cline":        ".cline/skills",
    "codex":        ".agents/skills",
    "cursor":       ".cursor/skills",
    "copilot":      ".github/skills",
    "windsurf":     ".windsurf/skills",
    "gemini":       ".gemini/skills",
}

# Default contributor-registry filename, resolved next to this script unless
# --registry overrides it. See contributors.yaml for the documented format.
DEFAULT_REGISTRY_NAME = "contributors.yaml"


class Contributor:
    """One module that contributes guard sets to the composition.

    Fields (all sourced from contributors.yaml):
      code          short id (e.g. "linear", "docmost") — used in messages
      rank          int; apply order ASC (linear=0 applies before docmost=1)
      marker        marker stem, e.g. "bmad-linear-patch" — used to build the
                    per-contributor terminal marker AND the inline-marker version
      version       semver string the contributor's REPLACE blocks must agree
                    with (dual-pin check)
      patches_roots ordered candidate parent dirs; the FIRST whose <MAJOR.MINOR>/
                    subdir exists is used — so one registry works in BOTH the
                    source-tree layout (sibling module dirs, e.g. bmad-docmost/)
                    AND the installed layout (modules under code dirs: _bmad/lnr,
                    _bmad/doc).
      patches_dir   absolute path to the RESOLVED patches/<MAJOR.MINOR>/ dir
      skills        list of skill names this contributor patches (e.g.
                    ["bmad-create-story", ...]); contributor-supplied, NOT
                    hardcoded.
    """

    def __init__(self, code, rank, marker, version, patches_roots, skills):
        self.code = code
        self.rank = rank
        self.marker = marker
        self.version = version
        self.patches_roots = list(patches_roots)  # ordered candidates; first existing <MAJOR.MINOR> wins
        self.skills = list(skills)
        self.patches_dir = None  # resolved per-bmm-version in resolve_patch_dirs()

    def terminal_marker(self):
        """The HTML comment stamped once this contributor's guards have landed."""
        return f"{self.marker}:applied:v{self.version}"

    def inline_marker_re(self):
        """Regex matching this contributor's inline REPLACE markers (any version)."""
        return re.compile(re.escape(self.marker) + r"\s+v(\d+\.\d+\.\d+)")


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--manifest",     required=True)
    p.add_argument("--project-root", required=True)
    p.add_argument("--registry",     required=False, default=None,
                   help="Path to contributors.yaml (defaults to one beside this script).")
    # --patches-dir is retained for backward compatibility: when a registry
    # entry omits an explicit patches_root, it falls back to this value.
    p.add_argument("--patches-dir",  required=False, default=None)
    p.add_argument("--dry-run",      type=int, default=0)
    p.add_argument("--check",        type=int, default=0)
    p.add_argument("--verbose",      type=int, default=0)
    return p.parse_args()


def load_manifest(manifest_path):
    """Return (bmm_version, ides_list) from the BMAD manifest."""
    with open(manifest_path) as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        sys.exit(f"ERROR: manifest is not a YAML mapping: {manifest_path}")

    # ides: bare list of IDE codes
    ides = data.get("ides") or []
    if not isinstance(ides, list):
        sys.exit(f"ERROR: manifest.ides is not a list: {manifest_path}")

    # modules: list of {name, version, ...} entries; find the one named "bmm"
    bmm_version = None
    for mod in data.get("modules") or []:
        if isinstance(mod, dict) and mod.get("name") == "bmm":
            bmm_version = mod.get("version")
            break

    if not bmm_version:
        sys.exit(f"ERROR: could not find bmm module version in {manifest_path}")

    return str(bmm_version), [str(i) for i in ides]


def load_registry(registry_path, default_patches_root):
    """Read contributors.yaml → ordered list[Contributor].

    Each contributor maps its own patches-dir; when omitted it falls back to
    default_patches_root (the --patches-dir value, i.e. bmad-linear's own bin).
    Relative patches_root values are resolved against the registry file's dir.
    """
    if not os.path.isfile(registry_path):
        sys.exit(
            f"ERROR: contributor registry not found: {registry_path}\n"
            f"  The patch engine needs a contributors.yaml declaring at least one module."
        )

    with open(registry_path) as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict) or not isinstance(data.get("contributors"), list):
        sys.exit(f"ERROR: registry must be a mapping with a 'contributors' list: {registry_path}")

    registry_dir = os.path.dirname(os.path.abspath(registry_path))
    contributors = []
    for i, entry in enumerate(data["contributors"]):
        if not isinstance(entry, dict):
            sys.exit(f"ERROR: contributor #{i} is not a mapping in {registry_path}")
        for required in ("code", "rank", "marker", "version", "skills"):
            if required not in entry:
                sys.exit(f"ERROR: contributor '{entry.get('code', i)}' missing '{required}' in {registry_path}")
        if not isinstance(entry["skills"], list) or not entry["skills"]:
            sys.exit(f"ERROR: contributor '{entry['code']}' has empty/invalid 'skills' in {registry_path}")

        # patches_root may be a single path OR an ordered list of candidate paths
        # (the first whose <MAJOR.MINOR> subdir exists wins) — so one registry
        # works in BOTH the source-tree layout (sibling module dirs) and the
        # installed layout (modules under code dirs: _bmad/lnr, _bmad/doc).
        patches_root = entry.get("patches_root")
        if patches_root is None:
            if default_patches_root is None:
                sys.exit(
                    f"ERROR: contributor '{entry['code']}' omits 'patches_root' and no "
                    f"--patches-dir fallback was provided ({registry_path})."
                )
            raw_roots = [default_patches_root]
        else:
            raw_roots = patches_root if isinstance(patches_root, list) else [patches_root]
            if not raw_roots or not all(isinstance(r, str) and r for r in raw_roots):
                sys.exit(f"ERROR: contributor '{entry['code']}' has an empty/invalid 'patches_root' in {registry_path}")
        # Resolve each candidate relative to the registry file's dir (absolute paths kept).
        patches_roots = [
            r if os.path.isabs(r) else os.path.normpath(os.path.join(registry_dir, r))
            for r in raw_roots
        ]

        contributors.append(Contributor(
            code=str(entry["code"]),
            rank=int(entry["rank"]),
            marker=str(entry["marker"]),
            version=str(entry["version"]),
            patches_roots=patches_roots,
            skills=entry["skills"],
        ))

    if not contributors:
        sys.exit(f"ERROR: registry declares no contributors: {registry_path}")

    # Deterministic, defined application order (PLAN §C.2.3): rank ASC, code tie-break.
    contributors.sort(key=lambda c: (c.rank, c.code))
    return contributors


def resolve_patch_dirs(contributors, bmm_version):
    """For each contributor, resolve the patches_root/<MAJOR.MINOR>/ dir to use.

    Version-agnostic floor match (not an exact-match requirement): among all
    <MAJOR.MINOR> dirs under the FIRST candidate root that has any, pick the
    HIGHEST one that is <= the installed bmm version. A bmm minor bump (e.g.
    6.9 -> 6.10) with no upstream skill-text changes then just reuses the
    nearest older validated set automatically — no new dir to author, validate,
    and land on every bump. This is safe because it is NOT the actual
    correctness check: apply_guards() below fails loudly ("anchor not found")
    if the reused patch set's anchors no longer match the installed skill
    text, which is what a real upstream change would look like. The version
    dir is a cache of "last known-good anchors", not a compatibility gate.

    Only fails here if bmm_version is OLDER than every validated set (nothing
    to fall back to) or no version dirs exist at all.
    """
    m = re.match(r"^(\d+)\.(\d+)", bmm_version)
    if not m:
        sys.exit(f"ERROR: malformed bmm version: {bmm_version}")
    bmm_tuple = (int(m.group(1)), int(m.group(2)))

    for c in contributors:
        candidates = []  # list of ((major, minor), path), from the first root that has any
        for root in c.patches_roots:
            if not os.path.isdir(root):
                continue
            found = []
            for e in os.listdir(root):
                p = os.path.join(root, e)
                if not os.path.isdir(p):
                    continue
                vm = re.match(r"^(\d+)\.(\d+)$", e)
                if not vm:
                    continue
                found.append(((int(vm.group(1)), int(vm.group(2))), p))
            if found:
                candidates = found
                break

        if not candidates:
            sys.exit(
                f"ERROR: no validated patch sets at all for contributor '{c.code}'.\n"
                f"  Tried patches roots: {', '.join(c.patches_roots)}\n"
                f"  Add at least one <MAJOR.MINOR>/ dir with validated anchors."
            )

        candidates.sort(key=lambda item: item[0])
        eligible = [item for item in candidates if item[0] <= bmm_tuple]
        if not eligible:
            oldest_version, _ = candidates[0]
            sys.exit(
                f"ERROR: installed bmm {bmm_version} is older than every validated patch "
                f"set for contributor '{c.code}' (oldest: {oldest_version[0]}.{oldest_version[1]}).\n"
                f"  Tried patches roots: {', '.join(c.patches_roots)}\n"
                f"  Downgrade bmm, or validate a patch set for {bmm_tuple[0]}.{bmm_tuple[1]}."
            )

        chosen_version, chosen_path = eligible[-1]
        if chosen_version != bmm_tuple:
            print(
                f"  [patch-engine] '{c.code}': no {bmm_tuple[0]}.{bmm_tuple[1]} patch set on file; "
                f"reusing nearest validated {chosen_version[0]}.{chosen_version[1]} "
                f"(anchors re-verified against the installed {bmm_version} skill text below).",
                file=sys.stderr,
            )
        c.patches_dir = chosen_path


def parse_patch_file(patch_path):
    """Return list of (anchor_text, replacement_template) from a .patch DSL file."""
    with open(patch_path) as f:
        raw = f.read()

    guards = []
    blocks = re.split(r'^\s*GUARD_END\s*$', raw, flags=re.MULTILINE)
    for block in blocks:
        if not re.search(r'^\s*GUARD_START\s*$', block, flags=re.MULTILINE):
            continue

        anchor_m = re.search(
            r'^\s*ANCHOR_BEGIN\s*$(.*?)^\s*ANCHOR_END\s*$',
            block, flags=re.MULTILINE | re.DOTALL,
        )
        if not anchor_m:
            sys.exit(f"ERROR: malformed patch block (missing ANCHOR_BEGIN/END) in {patch_path}")
        anchor = anchor_m.group(1).strip("\n")

        replace_m = re.search(
            r'^\s*REPLACE_BEGIN\s*$(.*?)^\s*REPLACE_END\s*$',
            block, flags=re.MULTILINE | re.DOTALL,
        )
        if not replace_m:
            sys.exit(f"ERROR: malformed patch block (missing REPLACE_BEGIN/END) in {patch_path}")
        replacement = replace_m.group(1).strip("\n")

        guards.append((anchor, replacement))

    return guards


def validate_marker(guards, contributor, patch_path):
    """Fail if any REPLACE block references a different patch version than the contributor pin."""
    marker_re = contributor.inline_marker_re()
    for _, replacement in guards:
        vm = marker_re.search(replacement)
        if vm and vm.group(1) != contributor.version:
            sys.exit(
                f"ERROR: marker version mismatch for contributor '{contributor.code}' — "
                f"registry pins v{contributor.version}, "
                f"patch references v{vm.group(1)} in {patch_path}"
            )


def apply_guards(content, guards, contributor, target_path, patch_path, verbose):
    """Apply one contributor's guard set against the RUNNING buffer.

    Anchors are matched against `content` as it stands NOW — already carrying any
    lower-rank contributor's replacements — so a later contributor's anchor can
    target an earlier contributor's REPLACE output (PLAN §C.2.3, re-derivation).

    Returns (new_content, guards_applied) or sys.exit on missing/duplicate anchor.
    """
    guards_applied = 0
    for anchor, replacement in guards:
        if anchor not in content:
            sys.exit(
                f"ERROR: anchor not found in {target_path} (contributor '{contributor.code}'):\n"
                f"  {anchor!r}\n"
                f"  → If a lower-rank contributor rewrote this region, re-derive this anchor\n"
                f"    against that contributor's REPLACE output. Otherwise update the anchor in\n"
                f"    {patch_path} to match the current upstream text."
            )

        count = content.count(anchor)
        if count > 1:
            sys.exit(
                f"ERROR: anchor is not unique in {target_path} "
                f"(contributor '{contributor.code}', found {count} times):\n"
                f"  {anchor!r}"
            )

        if verbose:
            before = content[:content.index(anchor)]
            line_no = before.count('\n') + 1
            replacement_end_line = line_no + replacement.count('\n')
            print(f"    guard [{contributor.code}]: {target_path}:{line_no}-{replacement_end_line}")

        content = content.replace(anchor, replacement, 1)
        guards_applied += 1

    return content, guards_applied


def compose_one(target_path, skill_name, contributors, dry_run, verbose):
    """Compose ALL contributing modules' guard sets for one SKILL.md, in rank order.

    Per-contributor idempotency: a contributor whose terminal marker is already
    present is skipped INDEPENDENTLY, and the others still apply. Each
    contributor stamps its own terminal marker on success.

    Returns a status string for the caller to print.
    """
    if not os.path.isfile(target_path):
        return f"· {skill_name}/SKILL.md — not installed, skipped"

    with open(target_path) as f:
        original = f.read()

    content = original
    applied_summary = []      # ["linear:5", "docmost:1"]
    skipped_summary = []      # ["docmost"]
    any_applied = False

    for c in contributors:
        if skill_name not in c.skills:
            continue  # this contributor does not patch this skill

        # Per-contributor idempotency: independent of every other contributor.
        if f"<!-- {c.terminal_marker()} -->" in content:
            skipped_summary.append(c.code)
            continue

        patch_file = os.path.join(c.patches_dir, f"{skill_name}.patch")
        if not os.path.isfile(patch_file):
            # Contributor lists this skill but ships no patch file for it.
            sys.exit(
                f"ERROR: contributor '{c.code}' lists skill '{skill_name}' but its patch file "
                f"is missing: {patch_file}"
            )

        guards = parse_patch_file(patch_file)
        if not guards:
            sys.exit(f"ERROR: no GUARD blocks found in {patch_file}")

        validate_marker(guards, c, patch_file)

        content, n = apply_guards(content, guards, c, target_path, patch_file, verbose)
        # Stamp this contributor's own terminal marker.
        content = content.rstrip("\n") + f"\n\n<!-- {c.terminal_marker()} -->\n"
        applied_summary.append(f"{c.code}:{n}")
        any_applied = True

    # Nothing contributed to this skill at all.
    if not applied_summary and not skipped_summary:
        return f"· {skill_name}/SKILL.md — no contributor patches this skill"

    # Fully idempotent: every relevant contributor already applied.
    if not any_applied:
        return f"· {skill_name}/SKILL.md — already patched ({', '.join(skipped_summary)})"

    parts = [f"{', '.join(applied_summary)} guard set(s) applied"]
    if skipped_summary:
        parts.append(f"already: {', '.join(skipped_summary)}")
    msg = "; ".join(parts)

    if dry_run:
        diff = list(difflib.unified_diff(original.splitlines(), content.splitlines(), lineterm="", n=2))
        if diff:
            for line in diff[:80]:
                print(f"    {line}")
            if len(diff) > 80:
                print(f"    ... ({len(diff) - 80} more diff lines)")
        return f"~ {skill_name}/SKILL.md — {msg} [dry-run]"

    with open(target_path, "w") as f:
        f.write(content)
    return f"✓ {skill_name}/SKILL.md — {msg}"


def check_one(target_path, skill_name, contributors):
    """Report per-contributor patch state for --check mode. No edits."""
    relevant = [c for c in contributors if skill_name in c.skills]
    if not relevant:
        return f"· {skill_name}/SKILL.md — no contributor patches this skill"
    if not os.path.isfile(target_path):
        return f"· {skill_name}/SKILL.md — not installed"

    with open(target_path) as f:
        content = f.read()

    states = []
    all_present = True
    for c in relevant:
        if f"<!-- {c.terminal_marker()} -->" in content:
            states.append(f"{c.code}✓v{c.version}")
        else:
            states.append(f"{c.code}✗")
            all_present = False

    glyph = "✓" if all_present else "✗"
    tail = "patched" if all_present else "UNPATCHED (run apply-patch.sh)"
    return f"{glyph} {skill_name}/SKILL.md — {tail} [{', '.join(states)}]"


def main():
    args = parse_args()
    dry_run = bool(args.dry_run)
    check = bool(args.check)
    verbose = bool(args.verbose)

    bmm_version, ides = load_manifest(args.manifest)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    registry_path = args.registry or os.path.join(script_dir, DEFAULT_REGISTRY_NAME)
    contributors = load_registry(registry_path, args.patches_dir)
    resolve_patch_dirs(contributors, bmm_version)

    # Union of every contributor's skill list, preserving a stable order: each
    # skill in the order it first appears across rank-sorted contributors.
    all_skills = []
    for c in contributors:
        for s in c.skills:
            if s not in all_skills:
                all_skills.append(s)

    if verbose:
        order = ", ".join(f"{c.code}(rank {c.rank}, v{c.version})" for c in contributors)
        print(f"[engine] contributor order: {order}")

    if not ides:
        sys.exit(
            "ERROR: manifest reports no installed IDEs — apply-patch.sh has nothing to patch.\n"
            "  Re-run `npx bmad-method install` with at least one --tools target."
        )

    any_patchable = False
    for ide in ides:
        rel_skills_dir = IDE_SKILLS_DIRS.get(ide)
        if rel_skills_dir is None:
            print(f"⚠ {ide} — unknown IDE, no skills-dir mapping (no-op for this IDE)", file=sys.stderr)
            continue

        skills_dir = os.path.join(args.project_root, rel_skills_dir)
        if not os.path.isdir(skills_dir):
            print(f"⚠ {ide} — skills directory missing at {rel_skills_dir} (skipped)", file=sys.stderr)
            continue

        any_patchable = True
        print(f"[{ide}] {rel_skills_dir}")
        for skill in all_skills:
            target = os.path.join(skills_dir, skill, "SKILL.md")
            if check:
                print("  " + check_one(target, skill, contributors))
            else:
                print("  " + compose_one(target, skill, contributors, dry_run, verbose))

    if not any_patchable:
        sys.exit("ERROR: no patchable IDE skills directories found for any installed IDE.")


if __name__ == "__main__":
    main()
