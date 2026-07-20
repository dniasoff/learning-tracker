"""Tests for AUD-guardrails-33: extract_books.py's `_clean()` must strip
Sefaria footnote spans the same way its sibling main.py's `_FOOTNOTE` regex
does. Before this fix, `_clean()` only stripped HTML *tags* (`_HTML.sub`)
and left footnote *bodies* merged into the main text — a contributor
re-running this retired path to add a book would silently corrupt
`book_text_cache.json`/`curriculum_books.json` with footnote text folded
into the primary reading.

extract_books.py needs `django` and `sefaria.model` importable — it calls
`django.setup()` and imports `IndexSet`/`Ref` from Sefaria-Project at module
level. Neither package is installed outside the Sefaria-Project venv this
tool is designed to run in (see the README). This test installs minimal
stand-ins in `sys.modules` before import, so it exercises the REAL
`_clean()` function shipped in extract_books.py without requiring that venv.

Run directly (no Django/Sefaria/Mongo needed — pure stdlib):
  python3 tool/text_extract/test_extract_books.py
or via unittest discovery:
  python3 -m unittest tool.text_extract.test_extract_books -v
"""

import importlib.util
import sys
import types
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parent / "extract_books.py"


def _install_sefaria_stubs() -> None:
    """Install no-op stand-ins for `django` and `sefaria.model` so
    extract_books.py's module-level `import django; django.setup()` and
    `from sefaria.model import IndexSet, Ref` succeed without the real
    Sefaria-Project venv. Only the import-time surface is stubbed; nothing
    here participates in the `_clean()` behavior under test.
    """
    if "django" not in sys.modules:
        django_stub = types.ModuleType("django")
        django_stub.setup = lambda: None
        sys.modules["django"] = django_stub

    if "sefaria" not in sys.modules:
        sys.modules["sefaria"] = types.ModuleType("sefaria")

    if "sefaria.model" not in sys.modules:
        sefaria_model_stub = types.ModuleType("sefaria.model")

        class _StubRef:
            def __init__(self, *args, **kwargs):
                pass

        class _StubIndexSet:
            def __init__(self, *args, **kwargs):
                pass

            def array(self):
                return []

        sefaria_model_stub.Ref = _StubRef
        sefaria_model_stub.IndexSet = _StubIndexSet
        sys.modules["sefaria.model"] = sefaria_model_stub


def _load_extract_books():
    _install_sefaria_stubs()
    spec = importlib.util.spec_from_file_location(
        "text_extract_extract_books_under_test", MODULE_PATH
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


extract_books = _load_extract_books()


class CleanStripsFootnoteBodiesTests(unittest.TestCase):
    """AC2: extract_books.py's _clean() removes an
    `<i class="footnote">…</i>` span wholesale, matching main.py's
    _FOOTNOTE behavior, instead of merging the footnote body into the
    main text."""

    def test_clean_removes_footnote_span_wholesale(self):
        raw = (
            'Genesis 1:1 In the beginning<i class="footnote">'
            "some scholars render this as an independent clause</i> "
            "God created the heaven and the earth."
        )
        cleaned = extract_books._clean(raw)
        self.assertNotIn("footnote", cleaned)
        self.assertNotIn(
            "some scholars render this as an independent clause", cleaned
        )
        self.assertIn("In the beginning", cleaned)
        self.assertIn("God created the heaven and the earth.", cleaned)

    def test_clean_matches_main_py_footnote_behavior(self):
        # Same input run through main.py's already-correct _clean() (the
        # sibling this fix mirrors) must produce the same footnote-free
        # result as extract_books.py's _clean().
        main_path = Path(__file__).resolve().parent / "main.py"
        main_spec = importlib.util.spec_from_file_location(
            "text_extract_main_under_test", main_path
        )
        main_module = importlib.util.module_from_spec(main_spec)
        assert main_spec.loader is not None
        main_spec.loader.exec_module(main_module)

        raw = 'Plain text<i class="footnote">drop me</i> tail.'
        self.assertEqual(
            extract_books._clean(raw),
            main_module._clean(raw),
        )

    def test_clean_still_strips_plain_html_tags(self):
        # Pre-existing behavior must not regress.
        raw = "<b>bold</b> and <i>italic</i> text"
        cleaned = extract_books._clean(raw)
        self.assertEqual(cleaned, "bold and italic text")

    def test_clean_handles_empty_string(self):
        self.assertEqual(extract_books._clean(""), "")


if __name__ == "__main__":
    unittest.main()
