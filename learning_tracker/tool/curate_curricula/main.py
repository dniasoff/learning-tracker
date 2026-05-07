"""Generate curriculum hierarchy JSONs from Sefaria-Project + local Mongo.

Output format matches the existing assets/content/hierarchy/*.json shape:
  { hierarchyConfig: {curriculumId, levelLabels, maxLevels, totalItems},
    items: [
      { curriculumId, level1, [level2, [level3, [level4]]],
        displayNameEn, displayNameHe, sefariaRef, sortOrder, isLeaf },
      ...
    ]
  }

Run from Sefaria-Project venv:
  cd ~/repos/Sefaria-Project
  source .venv/bin/activate
  DJANGO_SETTINGS_MODULE=sefaria.settings PYTHONPATH=. \\
    python /home/daniel/repos/learning-tracker/learning_tracker/tool/curate_curricula/main.py \\
      [--curriculum NAME] [--diff] [--write]

Default mode: dry-run (no writes); --write commits to assets/content/hierarchy/.
"""

import argparse
import json
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")

import django  # noqa: E402

django.setup()

from sefaria.model import library  # noqa: E402

APP_ROOT = Path(__file__).resolve().parents[2]
HIERARCHY_DIR = APP_ROOT / "assets" / "content" / "hierarchy"

# ────────────────────────────────────────────────────────────────────────
# Helpers


def _hebrew_numeral(n: int) -> str:
    """Encode a positive integer as Hebrew gematria letters (no thousands)."""
    if n <= 0:
        return ""
    letters = [
        (400, "ת"), (300, "ש"), (200, "ר"), (100, "ק"),
        (90, "צ"), (80, "פ"), (70, "ע"), (60, "ס"),
        (50, "נ"), (40, "מ"), (30, "ל"), (20, "כ"),
        (15, "טו"), (16, "טז"),  # avoid יה/יו
        (10, "י"), (9, "ט"), (8, "ח"), (7, "ז"),
        (6, "ו"), (5, "ה"), (4, "ד"), (3, "ג"),
        (2, "ב"), (1, "א"),
    ]
    out = []
    for val, letter in letters:
        while n >= val:
            out.append(letter)
            n -= val
    return "".join(out)


def _toc_subtree(path: str):
    """Walk Sefaria TOC categories by '/' delimited path, return the node."""
    toc = library.get_toc()
    parts = path.split("/")
    node = {"contents": toc}
    for p in parts:
        contents = node.get("contents") if isinstance(node, dict) else None
        if not contents:
            return None
        match = next((c for c in contents if c.get("category") == p), None)
        if not match:
            return None
        node = match
    return node


def _toc_book_titles(path: str):
    """All `title`-having leaves under a TOC category path."""
    node = _toc_subtree(path)
    if not node:
        return []
    out = []
    for it in node.get("contents", []):
        if it.get("title") and not it.get("category"):
            out.append(it["title"])
    return out


# ────────────────────────────────────────────────────────────────────────
# Strategies — one per curriculum, returns the items list


def bavli_strategy(curriculum_id="bavli"):
    """Bavli: Seder → Masechta → Daf → Amud, leaf at amud."""
    # Existing curriculum has 6 standard sedarim only — exclude Minor Tractates,
    # Guides, commentary, etc.
    main_sedarim = [
        ("Seder Zeraim", "סדר זרעים"),
        ("Seder Moed", "סדר מועד"),
        ("Seder Nashim", "סדר נשים"),
        ("Seder Nezikin", "סדר נזיקין"),
        ("Seder Kodashim", "סדר קודשים"),
        ("Seder Tahorot", "סדר טהרות"),
    ]
    items = []
    sort_order = 0
    for seder_idx, (seder_en, seder_he) in enumerate(main_sedarim):
        items.append({
            "curriculumId": curriculum_id,
            "level1": seder_en,
            "displayNameHe": seder_he,
            "displayNameEn": seder_en,
            "sefariaRef": seder_en,
            "sortOrder": sort_order,
            "isLeaf": False,
        })
        sort_order += 1
        masechtot = _toc_book_titles(f"Talmud/Bavli/{seder_en}")
        for mas in masechtot:
            try:
                idx = library.get_index(mas)
            except Exception:
                continue
            mas_he = idx.get_title("he") or mas
            items.append({
                "curriculumId": curriculum_id,
                "level1": seder_en,
                "level2": mas,
                "displayNameHe": mas_he,
                "displayNameEn": mas,
                "sefariaRef": mas,
                "sortOrder": sort_order,
                "isLeaf": False,
            })
            sort_order += 1
            # Talmud lengths[0] = number of amudim. Daf labels start at 2a.
            n_amudim = idx.nodes.lengths[0]
            n_dapim = (n_amudim + 1) // 2  # 2a counts as 1 daf
            for daf_offset in range(n_dapim):
                daf_n = daf_offset + 2  # daf number, starts at 2
                daf_label = str(daf_n)
                items.append({
                    "curriculumId": curriculum_id,
                    "level1": seder_en,
                    "level2": mas,
                    "level3": daf_label,
                    "displayNameHe": f"{mas_he} {_hebrew_numeral(daf_n)}",
                    "displayNameEn": f"{mas} {daf_label}",
                    "sefariaRef": f"{mas} {daf_label}",
                    "sortOrder": sort_order,
                    "isLeaf": False,
                })
                sort_order += 1
                for amud in ("a", "b"):
                    items.append({
                        "curriculumId": curriculum_id,
                        "level1": seder_en,
                        "level2": mas,
                        "level3": daf_label,
                        "level4": amud,
                        "displayNameHe": f"{mas_he} {_hebrew_numeral(daf_n)}{amud}",
                        "displayNameEn": f"{mas} {daf_label}{amud}",
                        "sefariaRef": f"{mas} {daf_label}{amud}",
                        "sortOrder": sort_order,
                        "isLeaf": True,
                    })
                    sort_order += 1
    return items, ["Seder", "Masechta", "Daf", "Amud"], 4


# Stubs for the rest — populate as we expand
STRATEGIES = {
    "bavli": bavli_strategy,
    # "yerushalmi": ..., "mishnayos": ..., "chumash": ..., "nach": ...,
    # "mishna_berurah": ..., "mussar": ...,
    # NEW:
    # "mishneh_torah": ..., "shulchan_arukh": ..., "arukh_hashulchan": ...,
    # "kitzur_shulchan_aruch": ..., "chofetz_chaim": ..., "sefer_hamitzvot": ...,
    # "pirkei_avot": ...,
}


# ────────────────────────────────────────────────────────────────────────
# Main


def build(curriculum_id: str):
    strategy = STRATEGIES.get(curriculum_id)
    if not strategy:
        sys.exit(f"No strategy for curriculum {curriculum_id!r}")
    items, level_labels, max_levels = strategy(curriculum_id)
    return {
        "hierarchyConfig": {
            "curriculumId": curriculum_id,
            "levelLabels": level_labels,
            "maxLevels": max_levels,
            "totalItems": sum(1 for it in items if it["isLeaf"]),
        },
        "items": items,
    }


def diff(curriculum_id: str, generated: dict) -> str:
    """Return a short summary of differences vs the on-disk hierarchy file."""
    on_disk_path = HIERARCHY_DIR / f"{curriculum_id}.json"
    if not on_disk_path.exists():
        return f"  (no existing {on_disk_path.name} — diff skipped)"
    with open(on_disk_path) as f:
        existing = json.load(f)
    e_leaves = [it["sefariaRef"] for it in existing["items"] if it["isLeaf"]]
    g_leaves = [it["sefariaRef"] for it in generated["items"] if it["isLeaf"]]
    e_set, g_set = set(e_leaves), set(g_leaves)
    only_e = sorted(e_set - g_set)
    only_g = sorted(g_set - e_set)
    return (
        f"  existing: {len(e_leaves)} leaves   generated: {len(g_leaves)} leaves\n"
        f"  only in existing ({len(only_e)}): {only_e[:8]}{'…' if len(only_e) > 8 else ''}\n"
        f"  only in generated ({len(only_g)}): {only_g[:8]}{'…' if len(only_g) > 8 else ''}"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--curriculum", required=False, default="bavli")
    ap.add_argument("--diff", action="store_true")
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    print(f"== {args.curriculum} ==", file=sys.stderr)
    out = build(args.curriculum)
    print(
        f"  total items: {len(out['items'])}, leaves: "
        f"{out['hierarchyConfig']['totalItems']}",
        file=sys.stderr,
    )

    if args.diff:
        print(diff(args.curriculum, out), file=sys.stderr)

    if args.write:
        path = HIERARCHY_DIR / f"{args.curriculum}.json"
        path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
        print(f"  wrote {path}", file=sys.stderr)
    else:
        # Dry run — print first 5 items
        for it in out["items"][:5]:
            print(json.dumps(it, ensure_ascii=False), file=sys.stderr)


if __name__ == "__main__":
    main()
