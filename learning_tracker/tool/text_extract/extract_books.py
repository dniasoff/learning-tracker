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


def _expand_titles(spec: dict) -> list[str]:
    titles = list(spec.get("titles", []))
    prefix = spec.get("title_prefix")
    if prefix:
        for idx in IndexSet({"title": {"$regex": f"^{re.escape(prefix)}"}}).array():
            titles.append(idx.title)
    exclude = set(spec.get("exclude", []))
    return sorted(t for t in titles if t not in exclude)


def _walk_node(node):
    """Recursively yield atomic Ref objects for any Index node.

    Strategy: try the simple path first (Ref(node.full_title) →
    all_segment_refs), which works for JaggedArrayNode and the few
    SchemaNode roots Sefaria has consolidated. If that fails, descend
    into node.children and try each.
    """
    title = None
    if hasattr(node, "full_title"):
        try:
            title = node.full_title("en")
        except Exception:
            title = None
    if title:
        try:
            nref = Ref(title)
            yielded = False
            for r in nref.all_segment_refs():
                yielded = True
                yield r
            if yielded:
                return
        except Exception:
            pass
    children = getattr(node, "children", None)
    if children:
        for child in children:
            yield from _walk_node(child)


def _atomic_refs_for(title: str):
    """Yield atomic Ref objects for a book. Handles JaggedArrayNode roots
    directly and SchemaNode roots via recursive descent."""
    try:
        idx = __import__("sefaria.model", fromlist=["library"]).library.get_index(
            title
        )
    except Exception as e:
        sys.stderr.write(f"  cannot get_index({title!r}): {e}\n")
        return
    yield from _walk_node(idx.nodes)


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
        sys.stderr.write(
            f"== {curriculum}: {len(titles)} books ==\n"
        )
        per_book: dict[str, list[str]] = {}
        for title in titles:
            count = 0
            for r in _atomic_refs_for(title):
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
