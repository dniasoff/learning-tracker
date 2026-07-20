"""Shared Sefaria TOC-walking helper.

`tool/curate_curricula/main.py` and `tool/audit_seed.py` each descend
`library.get_toc()`'s nested category tree by matching '/'-delimited path
segments (e.g. "Talmud/Bavli/Seder Zeraim") against each node's `category`
key. This module holds that walk once so both scripts share one
implementation (AUD-guardrails-26).

Pure — takes the already-fetched `toc` list as an argument rather than
calling `library.get_toc()` itself, so it has no Django/Sefaria/Mongo
dependency and is unit-testable in isolation.
"""

from __future__ import annotations


def walk_toc_path(toc: list[dict], path: str) -> dict | None:
    """Walk a Sefaria TOC (as returned by `library.get_toc()`) along a
    '/'-delimited category path, descending one category node per segment.

    Returns the matched TOC node dict (its `contents` list is what callers
    typically enumerate next), or `None` if any segment has no matching
    `category` entry among its parent's `contents`.
    """
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
