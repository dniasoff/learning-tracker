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


_SEFER_HAMITZVOT_TOKEN = re.compile(r"\b([NP])(\d+)\b")
_SEFER_HAMITZVOT_LONG = re.compile(
    r"(Negative|Positive)\s+Commandment\s+(\d+)", re.I
)
_SEFER_HAMITZVOT_PRINCIPLE = re.compile(
    r"Principle\s+(\d+)(?:\s*-\s*(\d+))?", re.I
)
_SEFER_HAMITZVOT_INTRO = re.compile(r"Introduction", re.I)


def _resolve_one(ref_str: str) -> tuple[str, str] | None:
    """Resolve a single Sefaria ref. Returns None if Ref() fails OR if
    Sefaria has the ref structurally but no text in either language (rare;
    happens for some Yerushalmi entries with no version yet)."""
    try:
        r = Ref(ref_str)
        en = _clean(r.text("en").as_string())
        he = _clean(r.text("he").as_string())
        if not en and not he:
            return None
        return en, he
    except Exception:
        return None


def _resolve_sefer_hamitzvot(ref_str: str) -> tuple[str, str] | None:
    """Hebcal's sefer_hamitzvot refs come in three flavours:

    - 'Day NN: N353, P149' (brief)  → Negative/Positive Commandments
    - 'Day NN: Negative Commandment 353; Positive Commandment 149' (long)
    - 'Day 1: Maimonides' Introduction to Sefer Hamitzvot' → Introductions
    - 'Day NN: Principle 1-3' → Sefer HaMitzvot, Shorashim 1-3

    Translate to one or more Sefaria refs and concat the text.
    """
    refs: list[str] = []

    # Introduction (treat as the broad "Introductions" node).
    if _SEFER_HAMITZVOT_INTRO.search(ref_str):
        refs.append("Sefer HaMitzvot, Introductions")

    # Principle (= Shorashim) — single or range.
    for m in _SEFER_HAMITZVOT_PRINCIPLE.finditer(ref_str):
        start = m.group(1)
        end = m.group(2)
        refs.append(
            f"Sefer HaMitzvot, Shorashim {start}-{end}" if end
            else f"Sefer HaMitzvot, Shorashim {start}"
        )

    # Numbered commandments — long form ("Negative Commandment 353") wins
    # over abbreviated ("N353") when both could match.
    pairs: list[tuple[str, int]] = []
    for kind, num in _SEFER_HAMITZVOT_LONG.findall(ref_str):
        pairs.append(("Negative" if kind.lower() == "negative" else "Positive", int(num)))
    if not pairs:
        for kind, num in _SEFER_HAMITZVOT_TOKEN.findall(ref_str):
            pairs.append(("Negative" if kind == "N" else "Positive", int(num)))
    for kind, n in pairs:
        # Sefaria's index uses the plural form ("Positive Commandments" /
        # "Negative Commandments" — one parent node, sub-indexed by number).
        refs.append(f"Sefer HaMitzvot, {kind} Commandments {n}")

    if not refs:
        return None
    en_parts, he_parts = [], []
    for sefaria_ref in refs:
        res = _resolve_one(sefaria_ref)
        if res is None:
            continue
        en_parts.append(res[0])
        he_parts.append(res[1])
    if not en_parts and not he_parts:
        return None
    return "\n\n".join(p for p in en_parts if p), "\n\n".join(p for p in he_parts if p)


def _resolve_mishneh_torah_multi(ref_str: str) -> tuple[str, str] | None:
    """Cross-book Mishneh Torah ranges like 'Forbidden Intercourse 21-22,
    Forbidden Foods 1' — comma-separated parts each meaning '<book> <range>'
    under the Mishneh Torah parent. Resolve each as 'Mishneh Torah, <part>'
    and concatenate.
    """
    parts = [p.strip() for p in ref_str.split(",") if p.strip()]
    if len(parts) < 2:
        return None
    en_parts, he_parts = [], []
    any_resolved = False
    for p in parts:
        res = _resolve_one(f"Mishneh Torah, {p}")
        if res is None:
            continue
        any_resolved = True
        en_parts.append(res[0])
        he_parts.append(res[1])
    if not any_resolved:
        return None
    return "\n\n".join(en_parts), "\n\n".join(he_parts)


def _resolve(
    ref_str: str,
    url_hint: str | None = None,
    program_key: str | None = None,
) -> tuple[str, str] | None:
    """Try to resolve a ref string to (en_text, he_text). Returns None on failure.

    Uses program-specific patches for refs that aren't directly Sefaria-canonical
    (sefer_hamitzvot's day-numbered shorthand, rambam_3_chapters cross-book ranges).
    Falls through to URL-decode hint and the bare ref string.
    """
    # Fast path: program-specific resolvers handle known non-canonical formats.
    if program_key == "sefer_hamitzvot":
        out = _resolve_sefer_hamitzvot(ref_str)
        if out is not None:
            return out
    if program_key == "rambam_3_chapters" and "," in ref_str:
        out = _resolve_mishneh_torah_multi(ref_str)
        if out is not None:
            return out

    candidates: list[str] = []
    if url_hint and "sefaria.org" in url_hint:
        from urllib.parse import unquote

        path = url_hint.split("?", 1)[0].split("/")[-1]
        candidates.append(unquote(path).replace("_", " "))
    candidates.append(ref_str)
    for cand in candidates:
        out = _resolve_one(cand)
        if out is not None:
            return out
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
            res = _resolve(en_ref, url, program_key)
            if res is None:
                # Last-resort fallback: hebcal supplied a display ref but
                # Sefaria can't resolve it (commonly Yalkut Yosef in kitzur's
                # shemitah-year cycle, which Sefaria doesn't host). Store the
                # display strings hebcal already has so the user sees the
                # ref name instead of a blank screen. Marked external so the
                # app could badge it differently.
                he_ref = ref.get("he", "")
                if en_ref or he_ref:
                    out[date][program_key] = {
                        "en": en_ref,
                        "he": he_ref,
                        "external": True,
                    }
                    n_done += 1
                else:
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
