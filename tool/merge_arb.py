#!/usr/bin/env python3
"""Append-only ARB union: merge new keys from the R1 fix-wave branches into dev's
ARB files, preserving dev's existing formatting (only appends keys not already
present). Run from repo root."""
import json
import subprocess
import sys
from collections import OrderedDict

BRANCHES = ["r1-tracks2", "r1-content2", "r1-locale", "r1-gamif2"]
ARBS = ["learning_tracker/lib/l10n/app_en.arb", "learning_tracker/lib/l10n/app_he.arb"]


def load_branch_arb(branch, path):
    out = subprocess.run(
        ["git", "show", f"{branch}:{path}"], capture_output=True, text=True
    )
    if out.returncode != 0:
        return {}
    return json.loads(out.stdout, object_pairs_hook=OrderedDict)


for path in ARBS:
    with open(path, encoding="utf-8") as f:
        dev = json.load(f, object_pairs_hook=OrderedDict)
    dev_keys = set(dev.keys())
    new = OrderedDict()
    for br in BRANCHES:
        br_arb = load_branch_arb(br, path)
        for k, v in br_arb.items():
            if k not in dev_keys and k not in new:
                new[k] = v
    if not new:
        print(f"{path}: no new keys")
        continue
    # Append-only: keep dev's text intact, insert new entries before final '}'.
    with open(path, encoding="utf-8") as f:
        text = f.read().rstrip()
    assert text.endswith("}"), f"{path} does not end with }}"
    body = text[:-1].rstrip()
    if body.endswith(","):
        body = body[:-1].rstrip()
    dumped = json.dumps(new, ensure_ascii=False, indent=2)
    inner = dumped[1:-1].rstrip("\n")  # entries between the braces, no trailing nl
    new_text = body + ",\n" + inner.lstrip("\n") + "\n}\n"
    # sanity: must parse
    json.loads(new_text)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)
    print(f"{path}: appended {len(new)} entries -> {sorted(k for k in new if not k.startswith('@'))}")
