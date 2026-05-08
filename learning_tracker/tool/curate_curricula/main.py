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
import re
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")

import django  # noqa: E402

django.setup()

from sefaria.model import library, IndexSet, Ref  # noqa: E402

APP_ROOT = Path(__file__).resolve().parents[2]
HIERARCHY_DIR = APP_ROOT / "assets" / "content" / "hierarchy"
BOOK_TEXT_CACHE = APP_ROOT / "tool" / "data" / "book_text_cache.json"

_TEXT_REFS: set[str] | None = None


def _walk_index_node(node):
    """Recursively yield atomic Ref objects for any Index node — handles
    both JaggedArrayNode roots (direct) and SchemaNode roots (recursive)."""
    title = None
    if hasattr(node, "full_title"):
        try:
            title = node.full_title("en")
        except Exception:
            title = None
    if title:
        try:
            yielded = False
            for r in Ref(title).all_segment_refs():
                yielded = True
                yield r
            if yielded:
                return
        except Exception:
            pass
    children = getattr(node, "children", None)
    if children:
        for child in children:
            yield from _walk_index_node(child)


def _refs_with_text() -> set[str] | None:
    """Refs the book extractor confirmed have non-empty text. Used to filter
    out 'structurally exists but empty in Sefaria' leaves before emitting
    a hierarchy. Returns None if the cache hasn't been built yet (no
    filtering applied)."""
    global _TEXT_REFS
    if _TEXT_REFS is not None:
        return _TEXT_REFS
    if not BOOK_TEXT_CACHE.exists():
        return None
    _TEXT_REFS = set(json.loads(BOOK_TEXT_CACHE.read_text()).keys())
    return _TEXT_REFS

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


# ────────────────────────────────────────────────────────────────────────
# Generic builders for the new curricula. Each enumerates atomic segment
# refs via Sefaria-Project's Ref().all_segment_refs() and parses each ref
# into the hierarchy levels appropriate to that tradition.


def _items_for_simple_book(
    curriculum_id: str,
    book_title: str,
    book_he_title: str | None,
    level_labels: list[str],
    sort_offset: int,
    *,
    parent_levels: dict | None = None,
) -> tuple[list[dict], int]:
    """Walk one book and emit hierarchy items: book → sub-section → leaf.

    `parent_levels` lets a caller inject earlier-level fields (e.g. Sefer
    grouping) so each emitted item has the full path.

    Refs like 'Mishneh Torah, Blessings 4:7' parse as:
      (book_title='Mishneh Torah, Blessings', sections=['4', '7'])

    Top-level refs like 'Pirkei Avot 1:1' parse as:
      (book_title='Pirkei Avot', sections=['1', '1'])
    """
    parent_levels = parent_levels or {}
    items: list[dict] = []
    sort_order = sort_offset
    # Book row (depth-1 in our hierarchy).
    book_level_idx = len(parent_levels) + 1  # next level# field
    book_row = dict(parent_levels)
    book_row[f"level{book_level_idx}"] = book_title
    book_row.update({
        "curriculumId": curriculum_id,
        "displayNameHe": book_he_title or book_title,
        "displayNameEn": book_title,
        "sefariaRef": book_title,
        "sortOrder": sort_order,
        "isLeaf": False,
    })
    items.append(book_row)
    sort_order += 1

    # Walk atomic refs. Group by intermediate sections so we emit one row
    # per (parent path, intermediate, leaf).
    segs: list = []
    try:
        idx = library.get_index(book_title)
        segs = list(_walk_index_node(idx.nodes))
    except Exception:
        try:
            segs = list(Ref(book_title).all_segment_refs())
        except Exception:
            return items, sort_order

    text_refs = _refs_with_text()
    seen_intermediates: set[tuple[str, ...]] = set()
    for seg in segs:
        ref_str = seg.normal()
        # Drop leaves that have no text content (Sefaria recognises the ref
        # structurally but the text is empty in both languages).
        if text_refs is not None and ref_str not in text_refs:
            continue
        # Parse the ref into hierarchy levels. Three shapes:
        #   - 'Pirkei Avot 1:1'              → text_levels=[],            num=['1','1']
        #   - 'Sefer HaMitzvot, X 12:3'      → text_levels=['X'],         num=['12','3']
        #   - 'Sefer HaMitzvot, X, Y 1'      → text_levels=['X','Y'],     num=['1']
        # Comma-separated parts between the book title and the trailing
        # numeric tail are intermediate level fields.
        suffix = ref_str[len(book_title):]
        suffix = re.sub(r"^[\s,]+", "", suffix)
        m = re.match(r"^(?P<text>.*?)(?:\s+(?P<num>\d[\d:.\-]*))?\s*$", suffix)
        text_part = (m.group("text") if m else suffix).rstrip(", ")
        numeric = m.group("num") if m and m.group("num") else ""
        text_levels = [p.strip() for p in text_part.split(",") if p.strip()]
        num_levels = re.split(r"[:.]", numeric) if numeric else []
        sections = text_levels + num_levels
        if not sections:
            continue

        # Emit intermediate rows for every prefix path we haven't seen yet.
        for cut in range(1, len(sections)):
            key = tuple(sections[: cut])
            if key in seen_intermediates:
                continue
            seen_intermediates.add(key)
            row = dict(book_row)
            row[f"level{book_level_idx + cut}"] = sections[cut - 1]
            row["displayNameEn"] = f"{book_title} {':'.join(sections[: cut])}"
            row["displayNameHe"] = row["displayNameEn"]
            row["sefariaRef"] = (
                f"{book_title} {':'.join(sections[: cut])}"
            )
            row["sortOrder"] = sort_order
            row["isLeaf"] = False
            items.append(row)
            sort_order += 1

        # Leaf row.
        leaf = dict(book_row)
        for i, sec in enumerate(sections, start=1):
            leaf[f"level{book_level_idx + i}"] = sec
        leaf["displayNameEn"] = ref_str
        leaf["displayNameHe"] = ref_str
        leaf["sefariaRef"] = ref_str
        leaf["sortOrder"] = sort_order
        leaf["isLeaf"] = True
        items.append(leaf)
        sort_order += 1

    return items, sort_order


def _strategy_simple(
    curriculum_id: str,
    titles: list[str],
    level_labels: list[str],
):
    """For curricula whose books are independent siblings (no Sefer grouping).
    Emits one book per level1, with intermediate + leaf levels parsed from
    each book's segment refs.
    """
    def go(curr=curriculum_id):
        items: list[dict] = []
        sort_order = 0
        for title in titles:
            try:
                idx = library.get_index(title)
                he_title = idx.get_title("he")
            except Exception:
                he_title = None
            book_items, sort_order = _items_for_simple_book(
                curr, title, he_title, level_labels, sort_order,
            )
            items.extend(book_items)
        return items, level_labels, len(level_labels)
    return go


def _strategy_mishneh_torah(curriculum_id="mishneh_torah"):
    """Mishneh Torah — Sefer (e.g. 'Sefer Ahavah') / Hilchot ('Mishneh Torah,
    Blessings') / Chapter / Halakhah. 88 sub-volumes grouped by Sefer via
    Sefaria's Index.categories[2].
    """
    level_labels = ["Sefer", "Hilchot", "Chapter", "Halakhah"]
    excluded = {
        "Mishneh Torah, Negative Mitzvot",
        "Mishneh Torah, Overview of Mishneh Torah Contents",
        "Mishneh Torah, Positive Mitzvot",
    }
    by_sefer: dict[str, list] = {}
    for idx in IndexSet({"title": {"$regex": "^Mishneh Torah, "}}).array():
        if idx.title in excluded:
            continue
        sefer = idx.categories[2] if len(idx.categories) > 2 else "Other"
        by_sefer.setdefault(sefer, []).append(idx)

    items: list[dict] = []
    sort_order = 0
    sefer_order = [
        "Sefer Madda", "Sefer Ahavah", "Sefer Zemanim", "Sefer Nashim",
        "Sefer Kedushah", "Sefer Haflaah", "Sefer Zeraim", "Sefer Avodah",
        "Sefer Korbanot", "Sefer Taharah", "Sefer Nezikim", "Sefer Kinyan",
        "Sefer Mishpatim", "Sefer Shoftim",
    ]
    for sefer in sefer_order:
        idxs = by_sefer.get(sefer, [])
        if not idxs:
            continue
        items.append({
            "curriculumId": curriculum_id,
            "level1": sefer,
            "displayNameHe": sefer,
            "displayNameEn": sefer,
            "sefariaRef": sefer,
            "sortOrder": sort_order,
            "isLeaf": False,
        })
        sort_order += 1
        for idx in sorted(idxs, key=lambda i: i.title):
            book_items, sort_order = _items_for_simple_book(
                curriculum_id,
                idx.title,
                idx.get_title("he"),
                level_labels[1:],
                sort_order,
                parent_levels={"level1": sefer},
            )
            items.extend(book_items)
    return items, level_labels, 4


# Per-curriculum strategy table.
STRATEGIES = {
    "bavli": bavli_strategy,
    "pirkei_avot": _strategy_simple(
        "pirkei_avot", ["Pirkei Avot"], ["Book", "Chapter", "Mishnah"],
    ),
    "kitzur_shulchan_aruch": _strategy_simple(
        "kitzur_shulchan_aruch", ["Kitzur Shulchan Arukh"], ["Book", "Siman", "Seif"],
    ),
    "shulchan_arukh": _strategy_simple(
        "shulchan_arukh",
        [
            "Shulchan Arukh, Orach Chayim",
            "Shulchan Arukh, Yoreh De'ah",
            "Shulchan Arukh, Even HaEzer",
            "Shulchan Arukh, Choshen Mishpat",
        ],
        ["Volume", "Siman", "Seif"],
    ),
    "arukh_hashulchan": _strategy_simple(
        "arukh_hashulchan",
        ["Arukh HaShulchan"],
        ["Book", "Volume", "Siman", "Seif"],
    ),
    "chofetz_chaim": _strategy_simple(
        "chofetz_chaim",
        ["Chafetz Chaim"],
        ["Book", "Part", "Klal", "Seif"],
    ),
    "sefer_hamitzvot": _strategy_simple(
        "sefer_hamitzvot",
        ["Sefer HaMitzvot"],
        ["Book", "Section", "Subsection", "Item"],
    ),
    "shemirat_halashon": _strategy_simple(
        "shemirat_halashon",
        ["Shemirat HaLashon"],
        ["Book", "Sefer", "Chapter", "Verse"],
    ),
    "mishneh_torah": _strategy_mishneh_torah,
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
