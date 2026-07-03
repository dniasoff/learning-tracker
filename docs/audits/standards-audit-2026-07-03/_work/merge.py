#!/usr/bin/env python3
"""Phase 2/3 merge: attach all verdicts, integrate sweep + supplemental, fold mega-clusters,
dedup by root cause, assign AUD ids, emit findings.json + register-data.json + kill-log."""
import json, os, re, sys
from collections import Counter, defaultdict

W = "/home/daniel/repos/learning-tracker/docs/audits/standards-audit-2026-07-03/_work"
SEV = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}; RSEV = ["P0", "P1", "P2", "P3"]
CONF = {"CONFIRMED": 0, "SUSPECTED": 1}; RCONF = ["CONFIRMED", "SUSPECTED"]

harvest = json.load(open(f"{W}/harvest-finders.json"))
orch = json.load(open(f"{W}/orchestrator-findings.json"))
hv = json.load(open(f"{W}/harvest-verdicts.json"))
manifest = json.load(open(f"{W}/chunk-manifest.json"))
so_manifest = json.load(open(f"{W}/so-manifest.json"))
sweep = json.load(open(f"{W}/sweep-verdicts.json")) if os.path.exists(f"{W}/sweep-verdicts.json") else {}
supp = json.load(open(f"{W}/supplemental-verified.json")) if os.path.exists(f"{W}/supplemental-verified.json") else []

def get_finding(src, i):
    return orch[i] if src == "orchestrator" else harvest[src]["findings"][i]

def decide(f, votes, need):
    votes = [v for v in votes if v]
    if not votes:
        out = dict(f); out["verify"] = {"status": "UNVERIFIED", "upheldVotes": 0, "totalVotes": 0, "refutations": [], "corrections": []}
        out["originalSeverity"] = f["severity"]; return out
    yes = [v for v in votes if v.get("upheld")]
    status = "UPHELD" if len(yes) >= need else "KILLED"
    out = dict(f); out["originalSeverity"] = f["severity"]
    if status == "UPHELD" and yes:
        sevs = sorted(SEV[v["severity"]] for v in yes); out["severity"] = RSEV[sevs[len(sevs)//2]]
        confs = sorted(CONF[v["confidence"]] for v in yes); out["confidence"] = RCONF[confs[len(confs)//2]]
    out["verify"] = {"status": status, "upheldVotes": len(yes), "totalVotes": len(votes),
                     "refutations": [ (v.get("reasoning") or "")[:300] for v in votes if not v.get("upheld")],
                     "corrections": [v["evidence_correction"] for v in votes if v.get("evidence_correction")]}
    return out

# ---------- 1. attach primary verdicts ----------
sweep_by_title = {}
for cid, entries in so_manifest.items():
    g = sweep.get(cid)
    if not g: continue
    for i, e in enumerate(entries):
        vote = next((v for v in g.get("verdicts", []) if v.get("index") == i), None)
        if vote: sweep_by_title[e["title"]] = vote

records, contested = [], []
for cid, entries in manifest.items():
    if cid.startswith("high-"):
        votes = list(hv["high"].get(cid, {}).values())
        e = entries[0]; f = get_finding(e["sourceBatch"], e["findingIndex"])
        rec = decide(f, votes, 2)
        rec["sourceBatch"] = e["sourceBatch"]; rec["chunk"] = cid
        records.append(rec)
    else:
        g = hv["grp"].get(cid); vlist = g.get("verdicts", []) if g else []
        for i, e in enumerate(entries):
            f = get_finding(e["sourceBatch"], e["findingIndex"])
            vote = next((v for v in vlist if v.get("index") == i), None)
            votes = [vote] if vote else []
            sv = sweep_by_title.get(f["title"])
            if sv is not None and vote is not None:
                if bool(sv.get("upheld")) == bool(vote.get("upheld")):
                    rec = decide(f, [vote, sv], 2 if vote.get("upheld") else 1)
                else:
                    rec = decide(f, [vote, sv], 2)  # 1-1 split -> not upheld
                    rec["verify"]["status"] = "CONTESTED"
                    contested.append(f["title"])
            else:
                rec = decide(f, votes, 1)
            rec["sourceBatch"] = e["sourceBatch"]; rec["chunk"] = cid
            records.append(rec)

records.extend(supp)  # supplemental findings arrive pre-verified with sourceBatch set

# ---------- 1b. chair adjudication of contested findings ----------
ADJUDICATE = {
    "Replace raw Colors.* literals with theme colors in content_browsing widgets":
        ("UPHELD", "P3", "lens:theme-consistency (beyond no_color_literal_outside_theme's Color(0x..) scope; extend lint or document statics-allowed)"),
    "Route account_actions_sheet.dart's Sign Out / Delete Account icon glyphs through a theme token instead of a Colors.white literal":
        ("UPHELD", "P3", "lens:theme-consistency (beyond no_color_literal_outside_theme's Color(0x..) scope; extend lint or document statics-allowed)"),
    "Replace source-text-grep assertions with real widget tests in t3_readonly_surfaces_gating_test.dart and r3_shell_revocation_exit_test.dart":
        ("KILLED", None, "Chair: central claim ('sole regression coverage') factually false - second verifier located real widget tests covering the illustrated mutation; grep-style-test critique without that premise does not stand alone."),
}
for r in records:
    adj = ADJUDICATE.get(r["title"])
    if adj and r["verify"]["status"] == "CONTESTED":
        status, sev, note = adj
        r["verify"]["status"] = status
        r["verify"]["adjudicated"] = "chair"
        if status == "UPHELD":
            r["severity"] = sev; r["rule"] = note; r["verify"]["upheldVotes"] = max(r["verify"]["upheldVotes"], 1)
        else:
            r["verify"]["refutations"].append(note)
contested = [t for t in contested if t not in ADJUDICATE]

# ---------- 2. mega-folds ----------
def rulekey(r):
    m = re.match(r'\s*(Rule \d|SM-\d|EH-\d|DB-\d|FB-\d|SR-\d|PV-\d|AU-\d|ST-\d|PF-\d|AX-\d|TQ-\d|AG-\d+|profileId)', r.get("rule", ""))
    return m.group(1) if m else (r.get("rule") or "")[:24]

FOLDS = {
    "AG-3": dict(title="Land the AG-3 file-length checker and ratchet down the 327 files over 400 lines",
                 sites=327, extra="Deterministic global scan: 327 hand-written Dart files exceed 400 lines (top: epic_15_multi_profile_test.dart 3588). Per-file list: _work/global/ag3-over400.txt."),
    "AG-5": dict(title="Land the AG-5 test-mirroring checker — 537/715 lib files lack a mirrored test",
                 sites=537, extra="Deterministic global scan; list: _work/global/ag5-unmirrored.txt. Rule as written is aspirational — checker should ratchet (new files hard-fail, backlog burn-down)."),
}
folded, kept = defaultdict(list), []
for r in records:
    rk = rulekey(r)
    if r["verify"]["status"] == "UPHELD" and rk in FOLDS and r["sourceBatch"] != "orchestrator":
        folded[rk].append(r)
    else:
        kept.append(r)
for rk, members in folded.items():
    spec = FOLDS[rk]
    base = max(members, key=lambda r: len(r.get("evidence", [])))
    agg = dict(base)
    agg["title"] = spec["title"]; agg["sites"] = spec["sites"]
    agg["why"] = spec["extra"] + " Representative per-area consequences: " + " | ".join(
        (m.get("why") or "")[:120] for m in members[:4])
    agg["evidence"] = [e for m in members[:10] for e in m.get("evidence", [])[:1]]
    agg["mergedFrom"] = [m["title"] for m in members]
    agg["sourceBatch"] = "fold:" + rk
    kept.append(agg)

# ---------- 3. cross-batch dedup ----------
def evfiles(r): return {e["file"] for e in r.get("evidence", [])}
upheld = [r for r in kept if r["verify"]["status"] == "UPHELD"]
rest = [r for r in kept if r["verify"]["status"] != "UPHELD"]
used, merged = set(), []
order = sorted(range(len(upheld)), key=lambda i: (SEV[upheld[i]["severity"]], -upheld[i]["verify"]["upheldVotes"], -len(upheld[i].get("evidence", []))))
for i in order:
    if i in used: continue
    r = upheld[i]; group = [r]; used.add(i)
    for j in order:
        if j in used: continue
        s = upheld[j]
        if rulekey(r) == rulekey(s) and (evfiles(r) & evfiles(s)):
            group.append(s); used.add(j)
    if len(group) > 1:
        prim = group[0]
        prim = dict(prim)
        seen_ev = {(e["file"], e["line"]) for e in prim.get("evidence", [])}
        for s in group[1:]:
            for e in s.get("evidence", []):
                if (e["file"], e["line"]) not in seen_ev:
                    prim["evidence"].append(e); seen_ev.add((e["file"], e["line"]))
        prim["sites"] = max(prim.get("sites", 1), len(seen_ev))
        prim["mergedFrom"] = prim.get("mergedFrom", []) + [s["title"] for s in group[1:]]
        prim["coDiscoverers"] = sorted({s["sourceBatch"] for s in group})
        merged.append(prim)
    else:
        merged.append(r)

# ---------- 3b. forced merges for known escaped clusters ----------
def is_check15(r):
    t = (r.get("title") or "").lower()
    return ("check 15" in t or "15/15" in t) and any("makefile" in e["file"].lower() for e in r.get("evidence", []))
for marker in ("setupFlutterErrorHandlers",):
    pair = [r for r in merged if marker.lower() in (r.get("title") or "").lower()]
    if len(pair) > 1:
        prim = min(pair, key=lambda r: SEV[r["severity"]])
        for s2 in pair:
            if s2 is prim: continue
            prim["mergedFrom"] = prim.get("mergedFrom", []) + [s2["title"]]
            seen_ev = {(e["file"], e["line"]) for e in prim["evidence"]}
            for e in s2.get("evidence", []):
                if (e["file"], e["line"]) not in seen_ev: prim["evidence"].append(e); seen_ev.add((e["file"], e["line"]))
            merged.remove(s2)
c15 = [r for r in merged if is_check15(r)]
if len(c15) > 1:
    prim = min(c15, key=lambda r: SEV[r["severity"]])
    for s2 in c15:
        if s2 is prim: continue
        prim["mergedFrom"] = prim.get("mergedFrom", []) + [s2["title"]]
        seen_ev = {(e["file"], e["line"]) for e in prim["evidence"]}
        for e in s2.get("evidence", []):
            if (e["file"], e["line"]) not in seen_ev: prim["evidence"].append(e); seen_ev.add((e["file"], e["line"]))
        merged.remove(s2)

# ---------- 4. AUD ids ----------
def area_slug(r):
    fs = [e["file"] for e in r.get("evidence", [])]
    f = re.sub(r"^learning_tracker/", "", fs[0]) if fs else ""
    m = re.match(r"lib/features/([^/]+)/", f)
    if m: return "features/" + m.group(1)
    m = re.match(r"lib/core/([^/]+?)(?:/|\.dart|$)", f)
    if m: return "core/" + m.group(1)
    if f.startswith("lib/app") or f == "lib/main.dart": return "app"
    if f.startswith("lib/l10n"): return "l10n"
    m = re.match(r"test/features/([^/]+)/", f)
    if m: return "tests/" + m.group(1)
    if f.startswith("test/story_acceptance"): return "tests/story-acceptance"
    if f.startswith(("test/", "integration_test/")): return "tests/cross"
    if ("Makefile" in f or f.startswith(("tool/", ".github/", "packages/", "hooks/", "analysis_options", "pubspec"))): return "guardrails"
    if "firestore" in f.lower() or f.startswith(("functions", "firebase", ".firebaserc")): return "firebase"
    if f.startswith("docs/") or (f.endswith(".md") and "/" not in f): return "docs"
    if "/android/" in "/" + f or "/ios/" in "/" + f or f.startswith(("android/", "ios/")): return "platform"
    a = (r.get("area") or "").lower()
    if "sync" in a: return "core/sync"
    if "guardrail" in a or "makefile" in a or "tool" in a: return "guardrails"
    if "doc" in a: return "docs"
    return "repo"
counters = Counter()
for r in sorted(merged, key=lambda r: (area_slug(r), SEV[r["severity"]], r.get("title", ""))):
    a = area_slug(r); counters[a] += 1
    r["normArea"] = a
    slug = a.replace("features/", "").replace("core/", "core-").replace("tests/", "t-").replace("/", "-")
    r["id"] = f"AUD-{slug}-{counters[a]:02d}"

kill_log = [{"title": r["title"], "rule": r.get("rule"), "sourceBatch": r["sourceBatch"],
             "originalSeverity": r.get("originalSeverity"), "status": r["verify"]["status"],
             "refutations": r["verify"].get("refutations", [])} for r in rest]

json.dump(merged, open(f"{W}/findings-merged.json", "w"), indent=1)
json.dump(kill_log, open(f"{W}/kill-log-full.json", "w"), indent=1)
print("upheld raw:", len(upheld), "| after dedup+folds:", len(merged),
      "| killed/contested/unverified:", len(rest), "| contested:", len(contested))
print("by severity:", dict(Counter(r["severity"] for r in merged)))
print("dedup clusters formed:", sum(1 for r in merged if r.get("mergedFrom")))
if contested: print("CONTESTED (adjudicate):", *contested, sep="\n  ")
EOF_MARKER_UNUSED = None
