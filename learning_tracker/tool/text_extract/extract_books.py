"""Extract every atomic ref + bilingual text for a configured list of books.

Produces:
  tool/data/book_text_cache.json  — flat {ref: {en, he}} keyed by Sefaria ref.
  tool/data/curriculum_books.json — book→atomic-refs map used by the
                                    hierarchy generator.

Run from Sefaria-Project venv:
  cd ~/repos/Sefaria-Project
  source .venv/bin/activate
  DJANGO_SETTINGS_MODULE=sefaria.settings PYTHONPATH=. \\
    python ~/repos/learning-tracker/learning_tracker/tool/text_extract/extract_books.py
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

from sefaria.model import IndexSet, Ref  # noqa: E402

APP_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = APP_ROOT / "tool" / "data"
TEXT_OUT = DATA_DIR / "book_text_cache.json"
BOOKS_OUT = DATA_DIR / "curriculum_books.json"

# Curriculum → list of Sefaria book titles (or a category-regex spec that
# expands to a list). Categories with many sub-volumes use prefix matching.
CURRICULUM_BOOK_SPECS: dict[str, dict] = {
    "bavli": {
        "category_path": "Talmud/Bavli",
        "main_subcats": [
            "Seder Zeraim", "Seder Moed", "Seder Nashim",
            "Seder Nezikin", "Seder Kodashim", "Seder Tahorot",
        ],
        "granularity": "section",  # 'Berakhot 2a' (amud) not 'Berakhot 2a:1' (line)
    },
    "yerushalmi": {
        "category_path": "Talmud/Yerushalmi",
        "main_subcats": [
            "Seder Zeraim", "Seder Moed", "Seder Nashim",
            "Seder Nezikin", "Seder Kodashim", "Seder Tahorot",
        ],
        "granularity": "section",
    },
    "mishnayos": {
        "category_path": "Mishnah",
        "main_subcats": [
            "Seder Zeraim", "Seder Moed", "Seder Nashim",
            "Seder Nezikin", "Seder Kodashim", "Seder Tahorot",
        ],
    },
    "chumash": {"category_path": "Tanakh/Torah"},
    "nach": {
        "category_path_any": ["Tanakh/Prophets", "Tanakh/Writings"],
    },
    "mishna_berurah": {"titles": ["Mishnah Berurah"]},
    "mussar": {
        "titles": [
            "Mesillat Yesharim",
            "Orchot Tzadikim",
            "Pirkei DeRabbi Eliezer",
            "Tanya",
            "Tomer Devorah",
            "Shaarei Teshuvah",
        ],
    },
    "mishneh_torah": {
        "title_prefix": "Mishneh Torah, ",
        "exclude": [
            "Mishneh Torah, Negative Mitzvot",
            "Mishneh Torah, Overview of Mishneh Torah Contents",
            "Mishneh Torah, Positive Mitzvot",
        ],
    },
    "shulchan_arukh": {
        "titles": [
            "Shulchan Arukh, Orach Chayim",
            "Shulchan Arukh, Yoreh De'ah",
            "Shulchan Arukh, Even HaEzer",
            "Shulchan Arukh, Choshen Mishpat",
        ],
    },
    "arukh_hashulchan": {
        "titles": ["Arukh HaShulchan"],
    },
    "kitzur_shulchan_aruch": {
        "titles": ["Kitzur Shulchan Arukh"],
    },
    "chofetz_chaim": {
        "titles": ["Chafetz Chaim"],
    },
    "sefer_hamitzvot": {
        "titles": ["Sefer HaMitzvot"],
    },
    "pirkei_avot": {
        "titles": ["Pirkei Avot"],
    },
    "shemirat_halashon": {
        "titles": ["Shemirat HaLashon"],
    },
}


_HTML = re.compile(r"<[^>]+>")


def _clean(s: str) -> str:
    if not s:
        return ""
    s = _HTML.sub("", s)
    return s.strip()


def _books_in_toc_category(path: str, main_subcats=None) -> list[str]:
    """Walk Sefaria's table-of-contents and collect book titles under the
    given category path. `main_subcats`, if given, restricts which
    sub-categories to descend into (used to skip commentary subtrees)."""
    from sefaria.model import library as _lib
    toc = _lib.get_toc()
    parts = path.split("/")
    node = {"contents": toc}
    for p in parts:
        contents = node.get("contents") if isinstance(node, dict) else None
        if not contents:
            return []
        match = next((c for c in contents if c.get("category") == p), None)
        if not match:
            return []
        node = match
    out = []

    def walk(n):
        for it in n.get("contents", []):
            if it.get("title") and not it.get("category"):
                out.append(it["title"])
            elif it.get("category"):
                if main_subcats and it["category"] not in main_subcats:
                    continue
                walk(it)

    walk(node)
    return sorted(set(out))


def _expand_titles(spec: dict) -> list[str]:
    titles = list(spec.get("titles", []))
    prefix = spec.get("title_prefix")
    if prefix:
        for idx in IndexSet({"title": {"$regex": f"^{re.escape(prefix)}"}}).array():
            titles.append(idx.title)
    cat_path = spec.get("category_path")
    if cat_path:
        titles.extend(_books_in_toc_category(cat_path, spec.get("main_subcats")))
    for cp in spec.get("category_path_any", []):
        titles.extend(_books_in_toc_category(cp))
    exclude = set(spec.get("exclude", []))
    return sorted(set(t for t in titles if t not in exclude))


def _walk_node(node, granularity="segment"):
    """Recursively yield Ref objects at the requested granularity.

    Two granularities:
      'segment' — leaves of the schema (Mishnah Berakhot 1:1, Genesis 1:1)
      'section' — one level above leaves (Berakhot 2a, Mishnah Berakhot 1)

    Strategy: try the simple path first (Ref(node.full_title) →
    all_segment_refs / subref enumeration). If that fails, descend
    into node.children.
    """
    title = None
    if hasattr(node, "full_title"):
        try:
            title = node.full_title("en")
        except Exception as e:
            sys.stderr.write(f"  full_title() failed for node: {e}\n")
            title = None
    if title:
        try:
            nref = Ref(title)
            yielded = False
            if granularity == "section":
                # Iterate top-level subrefs (one above segment).
                lengths = getattr(node, "lengths", None)
                top_n = lengths[0] if lengths else 0
                for i in range(1, top_n + 1):
                    try:
                        sr = nref.subref(i)
                        yielded = True
                        yield sr
                    except Exception as e:
                        sys.stderr.write(f"  subref({title!r}, {i}) failed: {e}\n")
                        continue
            else:
                for r in nref.all_segment_refs():
                    yielded = True
                    yield r
            if yielded:
                return
        except Exception as e:
            sys.stderr.write(f"  _walk_node({title!r}, {granularity!r}) failed: {e}\n")
    children = getattr(node, "children", None)
    if children:
        for child in children:
            yield from _walk_node(child, granularity)


def _atomic_refs_for(title: str, granularity: str = "segment"):
    """Yield Ref objects for a book at the chosen granularity. Handles
    JaggedArrayNode roots directly and SchemaNode roots via recursive
    descent."""
    try:
        idx = __import__("sefaria.model", fromlist=["library"]).library.get_index(
            title
        )
    except Exception as e:
        sys.stderr.write(f"  cannot get_index({title!r}): {e}\n")
        return
    yield from _walk_node(idx.nodes, granularity)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--curriculum", help="Only extract this curriculum (default: all)")
    ap.add_argument("--resume", action="store_true", help="Skip refs already in output")
    args = ap.parse_args()

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    text_cache: dict[str, dict[str, str]] = {}
    if args.resume and TEXT_OUT.exists():
        text_cache = json.loads(TEXT_OUT.read_text())
        sys.stderr.write(f"resume: {len(text_cache)} refs already cached\n")

    book_refs: dict[str, dict[str, list[str]]] = {}
    if BOOKS_OUT.exists():
        book_refs = json.loads(BOOKS_OUT.read_text())

    curricula = (
        [args.curriculum]
        if args.curriculum
        else list(CURRICULUM_BOOK_SPECS.keys())
    )

    for curriculum in curricula:
        spec = CURRICULUM_BOOK_SPECS.get(curriculum)
        if not spec:
            sys.stderr.write(f"  unknown curriculum {curriculum!r}, skipping\n")
            continue
        titles = _expand_titles(spec)
        granularity = spec.get("granularity", "segment")
        sys.stderr.write(
            f"== {curriculum}: {len(titles)} books (granularity={granularity}) ==\n"
        )
        per_book: dict[str, list[str]] = {}
        for title in titles:
            count = 0
            for r in _atomic_refs_for(title, granularity=granularity):
                ref_str = r.normal()
                per_book.setdefault(title, []).append(ref_str)
                count += 1
                if ref_str in text_cache and args.resume:
                    continue
                try:
                    en = _clean(r.text("en").as_string())
                    he = _clean(r.text("he").as_string())
                except Exception:
                    en, he = "", ""
                if not en and not he:
                    continue
                text_cache[ref_str] = {"en": en, "he": he}
            sys.stderr.write(f"  {title}: {count} atomic refs\n")
        book_refs[curriculum] = per_book
        # flush per-curriculum
        TEXT_OUT.write_text(json.dumps(text_cache, ensure_ascii=False))
        BOOKS_OUT.write_text(json.dumps(book_refs, ensure_ascii=False, indent=2))

    sys.stderr.write(
        f"DONE — text_cache size: {len(text_cache)} refs, books: "
        f"{sum(len(b) for b in book_refs.values())} groups\n"
    )


if __name__ == "__main__":
    main()
