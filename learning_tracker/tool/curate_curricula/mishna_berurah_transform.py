"""Deterministic Mishnah Berurah hierarchy transform.

The Sefaria source is a flat Orach Chaim Siman/Seif Katan tree.  This module
adds the app-only hilchos grouping while preserving the existing root, siman,
and leaf refs.  It is intentionally independent of Django/Sefaria so the
checked-in asset can be regenerated from a baseline hierarchy deterministically.
"""

import argparse
import json
import sys
from pathlib import Path


MISHNA_BERURAH_SECTIONS = [
    ("Morning conduct", "הלכות הנהגת אדם בבוקר", 1, 7),
    ("Tzitzis", "הלכות ציצית", 8, 24),
    ("Tefillin", "הלכות תפילין", 25, 45),
    ("Morning blessings", "הלכות ברכות השחר ושאר ברכות", 46, 57),
    ("Krias Shema", "הלכות קריאת שמע", 58, 88),
    ("Tefillah", "הלכות תפילה", 89, 127),
    (
        "Birkat Kohanim and nefilat apayim",
        "הלכות נשיאת כפים ונפילת אפים",
        128,
        134,
    ),
    ("Krias HaTorah", "הלכות קריאת ספר תורה", 135, 149),
    ("Beis Haknesses", "הלכות בית הכנסת", 150, 156),
    ("Netilas Yadayim", "הלכות נטילת ידים", 157, 165),
    ("Bitzias HaPas", "הלכות בציעת הפת", 166, 168),
    ("Seudah", "הלכות דברים הנוהגים בסעודה", 169, 181),
    ("Birkat Hamazon", "הלכות ברכת המזון", 182, 201),
    ("Fruit and fragrance blessings", "הלכות ברכת הפירות והריח", 202, 217),
    ("Other blessings", "הלכות שאר מיני ברכות", 218, 231),
    ("Mincha", "הלכות תפילת המנחה", 232, 234),
    ("Maariv", "הלכות קריאת שמע ותפילה של ערבית", 235, 239),
    ("Tznius", "הלכות צניעות", 240, 241),
    ("Shabbos", "הלכות שבת", 242, 344),
    ("Eruvin", "הלכות עירובין", 345, 416),
    ("Rosh Chodesh", "הלכות ראש חודש", 417, 428),
    ("Pesach", "הלכות פסח", 429, 494),
    ("Yom Tov", "הלכות יום טוב", 495, 529),
    ("Chol HaMoed", "הלכות חול המועד", 530, 548),
    ("Tisha B'Av and other fasts", "הלכות תשעה באב ושאר תעניות", 549, 561),
    ("Fast days", "הלכות תענית", 562, 580),
    ("Rosh Hashanah", "הלכות ראש השנה", 581, 603),
    ("Yom Kippur", "הלכות יום הכיפורים", 604, 624),
    ("Sukkah", "הלכות סוכה", 625, 644),
    ("Lulav", "הלכות לולב", 645, 669),
    ("Chanukah", "הלכות חנוכה", 670, 685),
    ("Purim", "הלכות מגילה", 686, 697),
]


def _section_for(siman: int) -> tuple[str, str, int, int]:
    for section in MISHNA_BERURAH_SECTIONS:
        if section[2] <= siman <= section[3]:
            return section
    raise ValueError(f"No Mishnah Berurah section for siman {siman}")


def transform_items(
    old_items: list[dict], curriculum_id: str = "mishna_berurah"
) -> tuple[list[dict], list[str], int]:
    """Transform the old Book → Siman → Seif rows to Book → Section → Siman → Seif."""
    roots = [item for item in old_items if item.get("level2") is None]
    if len(roots) != 1 or roots[0].get("sefariaRef") != "Mishnah Berurah":
        raise ValueError("expected one legacy Mishnah Berurah root row")

    root = dict(roots[0])
    root["level1"] = "Mishnah Berurah"
    root.pop("level2", None)
    root.pop("level3", None)
    root.pop("level4", None)

    by_siman = {}
    for section in MISHNA_BERURAH_SECTIONS:
        for siman in range(section[2], section[3] + 1):
            by_siman[siman] = section

    items = [root]
    emitted = set()
    for raw in old_items:
        if raw.get("level2") is None:
            continue
        siman = int(raw["level2"])
        en, he, _, _ = by_siman[siman]
        if en not in emitted:
            items.append(
                {
                    "curriculumId": curriculum_id,
                    "level1": "Mishnah Berurah",
                    "level2": en,
                    "displayNameHe": he,
                    "displayNameEn": en,
                    "sefariaRef": f"Mishnah Berurah|section|{en}",
                    "sortOrder": 0,
                    "isLeaf": False,
                }
            )
            emitted.add(en)
        item = dict(raw)
        item["level1"] = "Mishnah Berurah"
        item["level2"] = en
        item["level3"] = raw["level2"]
        if raw.get("level3") is not None:
            item["level4"] = raw["level3"]
        else:
            item.pop("level4", None)
        items.append(item)

    if len(emitted) != len(MISHNA_BERURAH_SECTIONS):
        raise ValueError("not every Mishnah Berurah section was emitted")
    for sort_order, item in enumerate(items):
        item["sortOrder"] = sort_order
    return items, ["Book", "Section", "Siman", "Seif"], 4


def transform_asset(asset: dict) -> dict:
    items, level_labels, max_levels = transform_items(asset["items"])
    return {
        "hierarchyConfig": {
            **asset["hierarchyConfig"],
            "levelLabels": level_labels,
            "maxLevels": max_levels,
            "totalItems": sum(1 for item in items if item["isLeaf"]),
        },
        "items": items,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="baseline JSON, or - for stdin")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    asset = json.loads(args.input.read_text() if str(args.input) != "-" else sys.stdin.read())
    args.output.write_text(
        json.dumps(transform_asset(asset), ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
