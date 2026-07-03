#!/usr/bin/env python3
"""Partition git ls-files into audit tiers/batches per Part C of the orchestrator prompt."""
import json, os, re, subprocess, sys
from collections import defaultdict

ROOT = "/home/daniel/repos/learning-tracker"
os.chdir(ROOT)
files = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.splitlines()

GEN_PATTERNS = [r"\.g\.dart$", r"\.freezed\.dart$", r"\.gr\.dart$", r"\.mocks\.dart$",
                r"lib/l10n/app_localizations.*\.dart$"]
BINARY_EXT = {".png", ".jpg", ".jpeg", ".webp", ".ico", ".ttf", ".otf", ".db", ".xz", ".gz",
              ".zip", ".jar", ".keystore", ".jks", ".pdf", ".gif", ".svg", ".webm"}

def is_generated(p):
    return any(re.search(pat, p) for pat in GEN_PATTERNS)

def linecount(p):
    try:
        with open(p, "rb") as f:
            return sum(1 for _ in f)
    except Exception:
        return 0

ledger = {}   # path -> (tier, batch_or_reason)
batches = defaultdict(list)
hints = {}

def assign(p, tier, batch, hint=None):
    ledger[p] = (tier, batch)
    if tier in ("1", "2", "4"):
        batches[batch].append(p)
        if hint:
            hints[batch] = hint

def exclude(p, reason):
    ledger[p] = ("X", reason)

def tier3(p):
    ledger[p] = ("3", "regen-freshness")

# story_acceptance epic grouping -> ~8 batches
def story_batch(fname):
    m = re.match(r"epic_(\d+)", fname)
    n = int(m.group(1)) if m else 0
    if n <= 8: return "t1-story-epics-01-08"
    if n <= 16: return "t1-story-epics-09-16"
    if n <= 20: return "t1-story-epics-17-20"
    if n <= 24: return "t1-story-epics-21-24"
    if n == 25: return "t1-story-epic-25"
    if n == 26: return "t1-story-epic-26"
    if n == 27: return "t1-story-epic-27"
    return "t1-story-epics-28plus"

for p in files:
    ext = os.path.splitext(p)[1].lower()
    base = os.path.basename(p)

    # ---- global excludes -------------------------------------------------
    if p.startswith(("_bmad/", ".agents/", ".cursor/", ".claude/", ".github/skills/",
                     ".github/agents/", "store_assets/", "memory/")):
        exclude(p, "vendored-agent-tooling"); continue
    if p.startswith("_bmad-output/"):
        exclude(p, "superseded-output-dir (hygiene finding)"); continue
    if p.startswith("build/") or p == "clear" or p == "app-icon.png":
        exclude(p, "accidental/binary artifact (hygiene finding)"); continue
    if p == "LICENSE" or base.endswith(".lock") or base == "package-lock.json":
        exclude(p, "lockfile/license"); continue
    if p.startswith("docs/_archive/") or p.startswith("docs/test-artifacts/"):
        exclude(p, "archived/test-artifact per Part C"); continue
    if ext in BINARY_EXT:
        exclude(p, "binary asset"); continue
    if p.startswith("learning_tracker/tool/data/") or p.startswith("learning_tracker/assets/"):
        exclude(p, "content/data asset or cache"); continue

    # ---- Tier 3: generated -----------------------------------------------
    if is_generated(p):
        tier3(p); continue

    # ---- Tier 1: lib + test ----------------------------------------------
    if p.startswith("learning_tracker/lib/") or p.startswith("learning_tracker/test/"):
        rel = p.split("learning_tracker/", 1)[1]
        m = re.match(r"(lib|test)/features/([^/]+)/", rel)
        if m:
            feat = m.group(2)
            if m.group(1) == "test" and feat in ("stages", "track_setup", "track_learning_order"):
                assign(p, "1", "t1-feat-tracks-extras"); continue
            assign(p, "1", f"t1-feat-{feat}"); continue
        m = re.match(r"(lib|test)/core/([^/]+)", rel)
        if m:
            sub = m.group(2)
            if sub.endswith(".dart"):
                assign(p, "1", "t1-core-misc"); continue
            if sub == "database":
                m2 = re.match(r"(lib|test)/core/database/(daos|tables|migrations?)/", rel)
                part = m2.group(2) if m2 else "root"
                part = {"daos": "daos", "tables": "tables", "migration": "migrations",
                        "migrations": "migrations"}.get(part, "root")
                assign(p, "1", f"t1-core-database-{part}"); continue
            if sub == "sync":
                m2 = re.match(r"(lib|test)/core/sync/([^/]+)/", rel)
                part = m2.group(2) if m2 and not m2.group(2).endswith(".dart") else "root"
                assign(p, "1", f"t1-core-sync-{part}"); continue
            small = {"constants": "t1-core-small-a", "enums": "t1-core-small-a",
                     "exceptions": "t1-core-small-a", "ids": "t1-core-small-a",
                     "time": "t1-core-small-a", "theme": "t1-core-theme-widgets",
                     "widgets": "t1-core-theme-widgets",
                     "email": "t1-core-services", "services": "t1-core-services",
                     "providers": "t1-core-providers-prefs", "preferences": "t1-core-providers-prefs",
                     "analytics": "t1-core-analytics-logging", "logging": "t1-core-analytics-logging",
                     "auth": "t1-core-auth", "navigation": "t1-core-nav-utils",
                     "utils": "t1-core-nav-utils", "labels": "t1-core-labels",
                     "content": "t1-core-content", "network": "t1-core-network",
                     "domain": "t1-core-domain-learning", "learning": "t1-core-domain-learning",
                     "streak": "t1-core-streak"}
            assign(p, "1", small.get(sub, f"t1-core-{sub}")); continue
        if re.match(r"lib/(app/|main\.dart)", rel) or re.match(r"lib/l10n/", rel) or rel == "lib/app.dart":
            assign(p, "1", "t1-app-l10n"); continue
        if rel.startswith("test/story_acceptance/"):
            assign(p, "1", story_batch(base)); continue
        if re.match(r"test/(helpers|fixtures|mocks)/", rel) or rel in (
                "test/flutter_test_config.dart", "test/infrastructure_test.dart"):
            assign(p, "1", "t1-test-helpers"); continue
        if re.match(r"test/(app|l10n)/", rel):
            assign(p, "1", "t1-app-l10n"); continue
        if re.match(r"test/(scheduler)/", rel):
            assign(p, "1", "t1-feat-scheduler"); continue
        if re.match(r"test/(sync)/", rel):
            assign(p, "1", "t1-feat-sync"); continue
        if re.match(r"test/(track_setup)/", rel):
            assign(p, "1", "t1-feat-tracks"); continue
        if re.match(r"test/(e2e|golden|overflow|widget|integration|migration|tool)/", rel):
            assign(p, "1", "t1-test-cross"); continue
        assign(p, "1", "t1-test-cross"); continue

    # ---- Tier 2: config / infra -------------------------------------------
    if (p in ("Makefile", "CLAUDE.md", ".gitignore", ".gitattributes", "firebase.json",
              ".firebaserc", "coding-standards.md")
            or p.startswith(".github/")
            or p in ("learning_tracker/Makefile", "learning_tracker/pubspec.yaml",
                     "learning_tracker/analysis_options.yaml", "learning_tracker/l10n.yaml",
                     "learning_tracker/dart_test.yaml", "learning_tracker/CLAUDE.md",
                     "learning_tracker/firebase.json", "learning_tracker/.firebaserc",
                     "learning_tracker/build.yaml", "learning_tracker/devtools_options.yaml")):
        assign(p, "2", "t2-build-ci-guardrails"); continue
    if p.startswith("packages/custom_lints/") or p.startswith("hooks/"):
        assign(p, "2", "t2-lints-hooks"); continue
    if p.startswith("tool/"):
        assign(p, "2", "t2-root-tool"); continue
    if p.startswith("learning_tracker/tool/"):
        assign(p, "2", "t2-app-tool"); continue
    if (p.startswith("learning_tracker/functions/") or p.startswith("test/firestore-rules/")
            or "firestore" in base or p.startswith("learning_tracker/firestore")):
        assign(p, "2", "t2-firebase-rules-functions"); continue
    if p.startswith("learning_tracker/android/") or p.startswith("learning_tracker/ios/"):
        assign(p, "2", "t2-platform-config"); continue
    if p.startswith("learning_tracker/assets/"):
        exclude(p, "content/data asset"); continue
    if p.startswith("learning_tracker/tool/data/"):
        exclude(p, "tool data cache"); continue
    if p.startswith("learning_tracker/"):
        assign(p, "2", "t2-build-ci-guardrails"); continue

    # ---- Tier 4: docs -------------------------------------------------------
    if p.startswith("docs/") or p in ("README.md", "CONTRIBUTING.md", "V1_OUT_OF_SCOPE.md"):
        if re.match(r"docs/(stories|planning|scenarios|qa|status|explainers|audits)/", p):
            assign(p, "4", "t4-docs-triage"); continue
        assign(p, "4", "t4-docs-canonical"); continue

    assign(p, "2", "t2-build-ci-guardrails")  # fallback: judge it

# ---- split oversized batches ---------------------------------------------
MAXL, MAXF = 6500, 34
final = {}
for name, plist in sorted(batches.items()):
    sized = [(p, linecount(p)) for p in sorted(plist)]
    total = sum(l for _, l in sized)
    maxl, maxf = MAXL, MAXF
    if name.startswith("t1-story-"): maxl = 9000
    if name.startswith("t4-docs-triage"): maxl, maxf = 10**9, 40
    if total <= maxl and len(sized) <= maxf:
        final[name] = sized; continue
    part, acc, idx = [], 0, 1
    for p, l in sized:
        if part and (acc + l > maxl or len(part) >= maxf):
            final[f"{name}-p{idx}"] = part; part, acc, idx = [], 0, idx + 1
        part.append((p, l)); acc += l
    if part:
        final[f"{name}-p{idx}"] = part

out = {"batches": [{"name": n,
                    "tier": ledger[fl[0][0]][0],
                    "files": [{"path": p, "lines": l} for p, l in fl],
                    "totalLines": sum(l for _, l in fl)}
                   for n, fl in sorted(final.items())],
       }
sp = os.environ.get("SCRATCH", "/tmp")
with open(os.path.join(sp, "batches.json"), "w") as f:
    json.dump(out, f, indent=1)
with open(os.path.join(sp, "ledger-initial.tsv"), "w") as f:
    for p in files:
        t, b = ledger[p]
        f.write(f"{p}\t{t}\t{b}\n")

tiers = defaultdict(int)
for p, (t, b) in ledger.items():
    tiers[t] += 1
print("files per tier:", dict(tiers))
print("batches:", len(out["batches"]))
for b in out["batches"]:
    print(f"  {b['name']:38s} {len(b['files']):3d} files {b['totalLines']:6d} lines")
