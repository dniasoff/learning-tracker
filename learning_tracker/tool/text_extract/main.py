"""Extract bilingual text for every calendar entry via Sefaria-Project +
local Mongo. No API calls.

Output: tool/data/daily_content_cache.json  (committed alongside the build)
  shape:
    {
      "YYYY-MM-DD": {
        "<program_key>": {"en": "...", "he": "..."},
        ...
      },
      ...
    }

Run from Sefaria-Project venv:
  cd ~/repos/Sefaria-Project
  source .venv/bin/activate
  DJANGO_SETTINGS_MODULE=sefaria.settings PYTHONPATH=. \\
    python ~/repos/learning-tracker/learning_tracker/tool/text_extract/main.py
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

from sefaria.model import Ref  # noqa: E402

APP_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = APP_ROOT / "tool" / "data"
HEBCAL_CACHE = DATA_DIR / "hebcal_calendar_cache.json"
SEFARIA_CACHE = DATA_DIR / "sefaria_calendar_cache.json"
OUTPUT = DATA_DIR / "daily_content_cache.json"

# Sefaria's `Ref().text(lang).as_string()` returns text with internal HTML
# (notes, italics). For our DB we want a plain reading form. This regex
# strips Sefaria's footnote markers and HTML tags conservatively.
_HTML = re.compile(r"<[^>]+>")
_FOOTNOTE = re.compile(r" ?\(…\)|<i class=\"footnote\".*?</i>", re.S)


def _clean(s: str) -> str:
    if not s:
        return ""
    s = _FOOTNOTE.sub("", s)
    s = _HTML.sub("", s)
    return s.strip()


def _resolve(ref_str: str, url_hint: str | None = None) -> tuple[str, str] | None:
    """Try to resolve a ref string to (en_text, he_text). Returns None on failure.

    Uses the URL hint if provided — hebcal's URLs are canonical Sefaria refs
    and resolve more reliably than the human-readable "desc" form.
    """
    candidates: list[str] = []
    if url_hint:
        # Strip query string + decode the path segment.
        from urllib.parse import unquote

        path = url_hint.split("?", 1)[0].split("/")[-1]
        candidates.append(unquote(path).replace("_", " "))
    candidates.append(ref_str)
    for cand in candidates:
        try:
            r = Ref(cand)
            en = _clean(r.text("en").as_string())
            he = _clean(r.text("he").as_string())
            return en, he
        except Exception:
            continue
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="Smoke-test: process N days then stop")
    ap.add_argument("--resume", action="store_true", help="Skip dates already in output")
    args = ap.parse_args()

    hebcal = json.loads(HEBCAL_CACHE.read_text())
    sefaria = (
        json.loads(SEFARIA_CACHE.read_text())
        if SEFARIA_CACHE.exists()
        else {}
    )

    # Merge calendars: hebcal first (most programs), Sefaria fills halakhah_yomit.
    days: dict[str, dict[str, dict]] = {}
    for date, progs in hebcal.items():
        days.setdefault(date, {}).update(progs)
    for date, progs in sefaria.items():
        days.setdefault(date, {}).update(progs)

    # Existing partial output for resume
    out: dict[str, dict[str, dict[str, str]]] = {}
    if args.resume and OUTPUT.exists():
        out = json.loads(OUTPUT.read_text())
        sys.stderr.write(f"resume: {sum(len(v) for v in out.values())} entries already cached\n")

    total = sum(len(v) for v in days.values())
    sys.stderr.write(f"resolving {total} calendar entries across {len(days)} days...\n")

    n_done = 0
    n_failed = 0
    failures: list[str] = []
    for i, (date, progs) in enumerate(sorted(days.items())):
        if args.resume and date in out and len(out[date]) == len(progs):
            n_done += len(progs)
            continue
        out.setdefault(date, {})
        for program_key, ref in progs.items():
            if args.resume and program_key in out[date]:
                n_done += 1
                continue
            en_ref = ref.get("en", "")
            url = ref.get("url")
            if not en_ref:
                continue
            res = _resolve(en_ref, url)
            if res is None:
                n_failed += 1
                failures.append(f"{date}|{program_key}|{en_ref}")
                continue
            en_text, he_text = res
            out[date][program_key] = {"en": en_text, "he": he_text}
            n_done += 1
        if (i + 1) % 100 == 0:
            sys.stderr.write(
                f"  {i + 1}/{len(days)} days  ({n_done}/{total} entries, {n_failed} failed)\n"
            )
            # Periodic flush
            OUTPUT.write_text(json.dumps(out, ensure_ascii=False, indent=2))
        if args.limit and (i + 1) >= args.limit:
            break

    OUTPUT.write_text(json.dumps(out, ensure_ascii=False, indent=2))
    sys.stderr.write(
        f"DONE — wrote {OUTPUT.relative_to(APP_ROOT)} ({n_done} entries, {n_failed} failed)\n"
    )
    if failures:
        sys.stderr.write("first 20 failures:\n")
        for f in failures[:20]:
            sys.stderr.write(f"  {f}\n")


if __name__ == "__main__":
    main()
