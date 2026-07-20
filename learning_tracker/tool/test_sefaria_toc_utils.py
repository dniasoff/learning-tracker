"""Tests for AUD-guardrails-26: the Sefaria TOC category-walk loop must have
exactly one implementation (`sefaria_toc_utils.walk_toc_path`), shared by
tool/curate_curricula/main.py and tool/audit_seed.py, rather than being
copy-pasted in each.

Run directly (no Django/Sefaria/Mongo needed — pure stdlib):
  python3 tool/test_sefaria_toc_utils.py
or via unittest discovery:
  python3 -m unittest tool.test_sefaria_toc_utils -v
"""

import re
import unittest
from pathlib import Path

from sefaria_toc_utils import walk_toc_path

TOOL_DIR = Path(__file__).resolve().parent
MAIN_PY = TOOL_DIR / "curate_curricula" / "main.py"
AUDIT_SEED_PY = TOOL_DIR / "audit_seed.py"

# The distinguishing line of the walk-loop body that used to be copy-pasted
# in all three sites (identical in each prior copy). If this string still
# appears in main.py or audit_seed.py, the loop has been re-duplicated
# instead of delegating to walk_toc_path.
_DUPLICATED_LOOP_MARKER = 'node = {"contents": toc}'


# A minimal fixture shaped like the real `library.get_toc()` return value,
# covering the AC's sample path (Talmud/Bavli/Seder Zeraim) plus a sibling
# seder and a non-matching top-level category, so both the "found" and
# "not found" walk branches are exercised.
FIXTURE_TOC = [
    {
        "category": "Talmud",
        "heCategory": "תלמוד",
        "contents": [
            {
                "category": "Bavli",
                "heCategory": "בבלי",
                "contents": [
                    {
                        "category": "Seder Zeraim",
                        "heCategory": "סדר זרעים",
                        "contents": [
                            {"title": "Berakhot", "heTitle": "ברכות"},
                        ],
                    },
                    {
                        "category": "Seder Moed",
                        "heCategory": "סדר מועד",
                        "contents": [
                            {"title": "Shabbat", "heTitle": "שבת"},
                        ],
                    },
                ],
            },
        ],
    },
    {
        "category": "Tanakh",
        "heCategory": "תנך",
        "contents": [],
    },
]


class WalkTocPathTests(unittest.TestCase):
    """AC2: a sample category path resolves correctly through the shared
    walker — this is the behavior the three call sites relied on before the
    refactor and must keep relying on after it."""

    def test_resolves_sample_path_talmud_bavli_seder_zeraim(self):
        node = walk_toc_path(FIXTURE_TOC, "Talmud/Bavli/Seder Zeraim")
        self.assertIsNotNone(node)
        self.assertEqual(node["category"], "Seder Zeraim")
        self.assertEqual(
            [c["title"] for c in node["contents"]],
            ["Berakhot"],
        )

    def test_resolves_sibling_path_under_same_parent(self):
        node = walk_toc_path(FIXTURE_TOC, "Talmud/Bavli/Seder Moed")
        self.assertIsNotNone(node)
        self.assertEqual(node["category"], "Seder Moed")

    def test_resolves_single_segment_top_level_path(self):
        node = walk_toc_path(FIXTURE_TOC, "Tanakh")
        self.assertIsNotNone(node)
        self.assertEqual(node["category"], "Tanakh")

    def test_returns_none_for_nonexistent_top_level_category(self):
        self.assertIsNone(walk_toc_path(FIXTURE_TOC, "Nonexistent"))

    def test_returns_none_for_nonexistent_nested_category(self):
        self.assertIsNone(
            walk_toc_path(FIXTURE_TOC, "Talmud/Bavli/Seder Nonexistent")
        )

    def test_returns_none_when_descending_into_a_leaf(self):
        # "Tanakh" has empty contents — descending further must not match.
        self.assertIsNone(walk_toc_path(FIXTURE_TOC, "Tanakh/Torah"))


class NoDuplicateWalkLoopTests(unittest.TestCase):
    """AC1: only one implementation of the TOC-path-walk loop exists across
    tool/curate_curricula/main.py and tool/audit_seed.py — both must
    delegate to the shared walk_toc_path helper instead of re-inlining the
    split/descend loop."""

    def test_main_py_does_not_reinline_the_walk_loop(self):
        src = MAIN_PY.read_text(encoding="utf-8")
        self.assertNotIn(
            _DUPLICATED_LOOP_MARKER,
            src,
            f"{MAIN_PY} re-inlines the TOC walk loop instead of calling "
            "walk_toc_path — extraction incomplete",
        )

    def test_audit_seed_py_does_not_reinline_the_walk_loop(self):
        src = AUDIT_SEED_PY.read_text(encoding="utf-8")
        self.assertNotIn(
            _DUPLICATED_LOOP_MARKER,
            src,
            f"{AUDIT_SEED_PY} re-inlines the TOC walk loop instead of "
            "calling walk_toc_path — extraction incomplete",
        )

    def test_main_py_imports_the_shared_helper(self):
        src = MAIN_PY.read_text(encoding="utf-8")
        self.assertRegex(
            src,
            re.compile(r"^\s*from sefaria_toc_utils import walk_toc_path", re.M),
            f"{MAIN_PY} does not import walk_toc_path from sefaria_toc_utils",
        )

    def test_audit_seed_py_imports_the_shared_helper(self):
        src = AUDIT_SEED_PY.read_text(encoding="utf-8")
        self.assertRegex(
            src,
            re.compile(r"^\s*from sefaria_toc_utils import walk_toc_path", re.M),
            f"{AUDIT_SEED_PY} does not import walk_toc_path from sefaria_toc_utils",
        )


if __name__ == "__main__":
    unittest.main()
