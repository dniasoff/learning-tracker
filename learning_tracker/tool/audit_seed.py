"""Comprehensive audit of the shipped seed.db against Sefaria's authoritative
taxonomy + the build inputs (calendar caches, hierarchies, learning programs).

Run from Sefaria-Project venv (Mongo on port 27019):
  cd ~/repos/Sefaria-Project
  source .venv/bin/activate
  DJANGO_SETTINGS_MODULE=sefaria.settings PYTHONPATH=. \\
    python ~/repos/learning-tracker/learning_tracker/tool/audit_seed.py

Expects assets/db/content.db.xz to be the current shipped asset.
"""

import json
import re
import sqlite3
import subprocess
import sys
import warnings
from collections import Counter, defaultdict
from pathlib import Path

warnings.filterwarnings("ignore")

import django  # noqa: E402

django.setup()

from sefaria.model import IndexSet, library  # noqa: E402

APP_ROOT = Path(__file__).resolve().parent.parent
ASSET_XZ = APP_ROOT / "assets" / "db" / "content.db.xz"
HIERARCHY_DIR = APP_ROOT / "assets" / "content" / "hierarchy"
HEBCAL_CACHE = APP_ROOT / "tool" / "data" / "hebcal_calendar_cache.json"
SEFARIA_CACHE = APP_ROOT / "tool" / "data" / "sefaria_calendar_cache.json"

# Curriculum → category path or list of titles in Sefaria taxonomy. Used to
# detect what's MISSING from a curriculum hierarchy vs. what Sefaria has.
EXPECTED_BOOKS: dict = {
    "bavli": {"category_path": "Talmud/Bavli", "main_subcats": [
        "Seder Zeraim", "Seder Moed", "Seder Nashim", "Seder Nezikin",
        "Seder Kodashim", "Seder Tahorot",
    ]},
    "yerushalmi": {"category_path": "Talmud/Yerushalmi"},
    "mishnayos": {"category_path": "Mishnah", "main_subcats": [
        "Seder Zeraim", "Seder Moed", "Seder Nashim", "Seder Nezikin",
        "Seder Kodashim", "Seder Tahorot",
    ]},
    "chumash": {"category_path": "Tanakh/Torah"},
    "nach": {"category_path_any": ["Tanakh/Prophets", "Tanakh/Writings"]},
    "mishneh_torah": {"title_prefix": "Mishneh Torah, "},
    "shulchan_arukh": {"titles_exact": [
        "Shulchan Arukh, Orach Chayim", "Shulchan Arukh, Yoreh De'ah",
        "Shulchan Arukh, Even HaEzer", "Shulchan Arukh, Choshen Mishpat",
    ]},
    "kitzur_shulchan_aruch": {"titles_exact": ["Kitzur Shulchan Arukh"]},
    "arukh_hashulchan": {"titles_exact": ["Arukh HaShulchan"]},
    "chofetz_chaim": {"titles_exact": ["Chafetz Chaim"]},
    "shemirat_halashon": {"titles_exact": ["Shemirat HaLashon"]},
    "sefer_hamitzvot": {"titles_exact": ["Sefer HaMitzvot"]},
    "pirkei_avot": {"titles_exact": ["Pirkei Avot"]},
}

# Curricula we don't audit against Sefaria's taxonomy — manually-curated lists.
SKIP_TAXONOMY_AUDIT = {"mishna_berurah", "mussar"}

OK = "✓"
WARN = "⚠"
FAIL = "✗"


def color(s, c):
    codes = {"green": "\033[32m", "red": "\033[31m", "yellow": "\033[33m",
             "blue": "\033[34m", "bold": "\033[1m"}
    return f"{codes.get(c, '')}{s}\033[0m"


def section(title):
    print()
    print(color(f"━━ {title} ━━", "bold"))


# ── Open seed ─────────────────────────────────────────────────────────────
section("Decompressing shipped seed")
seed_path = "/tmp/audit_seed.db"
subprocess.run(["xz", "-dkc", str(ASSET_XZ)], stdout=open(seed_path, "wb"), check=True)
db = sqlite3.connect(seed_path)
db.row_factory = sqlite3.Row
print(f"  asset: {ASSET_XZ.name}  size: {ASSET_XZ.stat().st_size / 1024 / 1024:.1f} MB")

# ── Schema integrity ──────────────────────────────────────────────────────
section("1. Schema integrity")
schema_v = db.execute("PRAGMA user_version").fetchone()[0]
seed_v = db.execute("SELECT version FROM seed_metadata").fetchone()["version"]
print(f"  PRAGMA user_version = {schema_v}")
print(f"  seed_metadata.version = {seed_v}")
tables = [r[0] for r in db.execute(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
).fetchall()]
expected = {"calendar_cycles", "daily_content", "seed_metadata", "text_cache"}
missing_tables = expected - set(tables)
print(f"  tables present: {sorted(tables)}")
if missing_tables:
    print(color(f"  {FAIL} missing tables: {sorted(missing_tables)}", "red"))
else:
    print(color(f"  {OK} all 4 expected tables present", "green"))

# ── Row counts ────────────────────────────────────────────────────────────
section("2. Row counts")
counts = {}
for t in ("text_cache", "calendar_cycles", "daily_content", "seed_metadata"):
    counts[t] = db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    print(f"  {t:20s} {counts[t]:>8}")

# ── Calendar cycle coverage ───────────────────────────────────────────────
section("3. Calendar coverage (every (date, program) → daily_content)")
gap = db.execute(
    "SELECT COUNT(*) FROM calendar_cycles c "
    "LEFT JOIN daily_content d ON c.sefaria_ref = d.sefaria_ref "
    "WHERE d.sefaria_ref IS NULL"
).fetchone()[0]
if gap == 0:
    print(color(f"  {OK} 0 unresolved calendar entries (all {counts['calendar_cycles']:,} resolve)", "green"))
else:
    print(color(f"  {FAIL} {gap} unresolved calendar entries", "red"))

# ── Curriculum coverage (every leaf → text_cache) ─────────────────────────
section("4. Curriculum coverage (every hierarchy leaf → text_cache)")
text_refs = set(r[0] for r in db.execute("SELECT sefaria_ref FROM text_cache"))
total_missing = 0
for path in sorted(HIERARCHY_DIR.glob("*.json")):
    name = path.stem
    raw = json.loads(path.read_text())
    leaves = [it["sefariaRef"] for it in raw["items"] if it.get("isLeaf")]
    missing = [r for r in leaves if r not in text_refs]
    pct = 100 * (len(leaves) - len(missing)) / max(len(leaves), 1)
    sign = OK if not missing else FAIL
    col = "green" if not missing else "red"
    print(color(f"  {sign} {name:25s} {len(leaves)-len(missing):>6}/{len(leaves):<6} ({pct:6.2f}%)", col))
    if missing:
        for r in missing[:3]:
            print(f"      missing: {r!r}")
        total_missing += len(missing)
if total_missing == 0:
    print(color(f"  {OK} all curriculum leaves resolve", "green"))

# ── Bilingual coverage ────────────────────────────────────────────────────
section("5. Bilingual coverage (informational)")
bi = db.execute(
    "SELECT "
    "  SUM(CASE WHEN english_text != '' AND hebrew_text != '' THEN 1 ELSE 0 END) AS both, "
    "  SUM(CASE WHEN english_text = '' AND hebrew_text != '' THEN 1 ELSE 0 END) AS he_only, "
    "  SUM(CASE WHEN english_text != '' AND hebrew_text = '' THEN 1 ELSE 0 END) AS en_only "
    "FROM text_cache"
).fetchone()
total = bi['both'] + bi['he_only'] + bi['en_only']
print(f"  text_cache  both: {bi['both']:>6} ({100*bi['both']/total:5.1f}%)")
print(f"              he-only: {bi['he_only']:>6} ({100*bi['he_only']/total:5.1f}%) — Sefaria has no English version")
print(f"              en-only: {bi['en_only']:>6} ({100*bi['en_only']/total:5.1f}%) — rare")
print()
bi = db.execute(
    "SELECT "
    "  SUM(CASE WHEN english_text != '' AND hebrew_text != '' THEN 1 ELSE 0 END) AS both, "
    "  SUM(CASE WHEN english_text = '' AND hebrew_text != '' THEN 1 ELSE 0 END) AS he_only "
    "FROM daily_content"
).fetchone()
total = bi['both'] + bi['he_only']
print(f"  daily_content  both: {bi['both']:>6} ({100*bi['both']/total:5.1f}%)")
print(f"                 he-only: {bi['he_only']:>6} ({100*bi['he_only']/total:5.1f}%)")

# ── Sefaria taxonomy comparison: missing books ────────────────────────────
section("6. Sefaria-taxonomy audit (what books should be in each curriculum?)")


def expected_titles_for(curriculum: str) -> list[str]:
    spec = EXPECTED_BOOKS.get(curriculum)
    if not spec:
        return []
    if "titles_exact" in spec:
        return spec["titles_exact"]
    if "title_prefix" in spec:
        return sorted(
            i.title for i in IndexSet({"title": {"$regex": f"^{re.escape(spec['title_prefix'])}"}}).array()
            if i.title not in spec.get("exclude", [])
        )
    if "category_path" in spec:
        return _books_in_category(spec["category_path"], spec.get("main_subcats"))
    if "category_path_any" in spec:
        out = []
        for cp in spec["category_path_any"]:
            out.extend(_books_in_category(cp))
        return sorted(set(out))
    return []


def _books_in_category(path: str, main_subcats=None) -> list[str]:
    toc = library.get_toc()
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

    def walk(n, allow_subcat: bool):
        for it in n.get("contents", []):
            if it.get("title") and not it.get("category"):
                out.append(it["title"])
            elif it.get("category") and allow_subcat:
                if main_subcats and it["category"] not in main_subcats:
                    continue
                walk(it, allow_subcat=True)

    walk(node, allow_subcat=True)
    return sorted(set(out))


for curriculum in sorted(EXPECTED_BOOKS.keys()):
    if curriculum in SKIP_TAXONOMY_AUDIT:
        continue
    path = HIERARCHY_DIR / f"{curriculum}.json"
    if not path.exists():
        print(color(f"  {FAIL} {curriculum}: hierarchy file missing", "red"))
        continue
    raw = json.loads(path.read_text())
    leaves = [it["sefariaRef"] for it in raw["items"] if it.get("isLeaf")]
    # Books referenced by the hierarchy: take the prefix of each leaf ref up to
    # the first numeric segment.
    books_in_hierarchy = set()
    for r in leaves:
        m = re.match(r"^(.+?)(?:\s+\d.*)?$", r)
        if not m:
            continue
        # Strip any trailing comma list of intermediate sections — they're
        # part of the canonical Sefaria title for nested books.
        title = m.group(1).rstrip(", ").strip()
        # Try to find the longest matching real Sefaria title.
        for n in range(len(title.split(", ")), 0, -1):
            candidate = ", ".join(title.split(", ")[:n])
            try:
                idx = library.get_index(candidate)
                books_in_hierarchy.add(idx.title)
                break
            except Exception:
                continue
    expected = set(expected_titles_for(curriculum))
    missing = sorted(expected - books_in_hierarchy)
    extra = sorted(books_in_hierarchy - expected)
    sign = OK if not missing and not extra else WARN if not missing else FAIL
    col = "green" if sign == OK else "yellow" if sign == WARN else "red"
    print(color(f"  {sign} {curriculum:25s} expected={len(expected):>3}  in_hierarchy={len(books_in_hierarchy):>3}", col))
    for t in missing[:5]:
        print(color(f"      missing: {t!r}", "red"))
    if len(missing) > 5:
        print(color(f"      … +{len(missing)-5} more", "red"))
    for t in extra[:5]:
        print(color(f"      extra:   {t!r}", "yellow"))

# ── Calendar-program → curriculum mapping ─────────────────────────────────
section("7. Calendar program refs → curriculum coverage")
hebcal = json.loads(HEBCAL_CACHE.read_text())
sefaria_cache = json.loads(SEFARIA_CACHE.read_text()) if SEFARIA_CACHE.exists() else {}

prog_books = defaultdict(Counter)
for date, progs in hebcal.items():
    for prog, ref in progs.items():
        en = ref.get("en", "")
        m = re.match(r"^([^,\d]+(?:, [A-Z][^,\d]+)*)", en)
        prog_books[prog][m.group(1).strip() if m else en] += 1

for prog in sorted(prog_books):
    top = prog_books[prog].most_common(3)
    summary = ", ".join(f"{b!r}({n})" for b, n in top)
    print(f"  {prog:30s} {summary}")

# ── Orphans ───────────────────────────────────────────────────────────────
section("8. text_cache orphans (refs not in any hierarchy)")
in_hierarchy = set()
for path in HIERARCHY_DIR.glob("*.json"):
    raw = json.loads(path.read_text())
    for it in raw["items"]:
        if it.get("isLeaf"):
            in_hierarchy.add(it["sefariaRef"])
in_daily_content_keys = set(r[0] for r in db.execute("SELECT sefaria_ref FROM daily_content"))
orphans = text_refs - in_hierarchy - in_daily_content_keys
print(f"  orphan text_cache rows (not in any hierarchy nor daily_content): {len(orphans):,}")
if orphans:
    for r in list(orphans)[:5]:
        print(f"    {r}")
    if len(orphans) > 5:
        print(f"    … +{len(orphans)-5} more")

print()
print(color("AUDIT COMPLETE", "bold"))
