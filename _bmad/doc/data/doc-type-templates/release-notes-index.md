---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: release-notes
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
tags: [release, index]
---

<!--
How to use this template — the LANDING / INDEX page for the Release Notes section
- Skill: doc-librarian scaffolds it (scaffold recipe = index); doc-ratify updates the "latest" pointer on each ship.
- This is the ONE LIVING page for the section (P1): title "Release Notes", no version/date in its slug, updated in place each release.
- Each release gets its own dated/append child page from `release-notes.md` (title "Release Notes vX.Y").
- Scaffold it with:  docmost-cli page scaffold "Release Notes" --space <slug> --parent <ops-section-slug> --doc-type release-notes --scaffold index --template @data/doc-type-templates/release-notes-index.md
- The "All releases" list is the section's children NEWEST-FIRST. `page tree apply --link-children` / a `subpages` block auto-maintains a Contents block; keep this page's manual list ordered newest-first as the human-readable index.
- This landing is current-state (P1/P4): the tldr/latest pointer is updated each release; it carries NO dated content itself.
-->

# Release Notes

<!-- tldr LEAD (the in-short): one paragraph — where to find what changed, and a pointer to the latest version + date. -->

In short: every release of <project> gets its own versioned page below. **Latest: [Release Notes vX.Y](<url>) — YYYY-MM-DD.**

:::info
📦 **Latest release — vX.Y (YYYY-MM-DD).** <One-line highlight of the newest release.> See **[Release Notes vX.Y](<url>)** for the full changelog.
:::

## All releases

<!-- NEWEST-FIRST. Either a `subpages` block (auto-lists children) or the maintained list below. Keep version order. -->

- [Release Notes vX.Y](<url>) — YYYY-MM-DD — <one-line highlight>
- [Release Notes vX.(Y-1)](<url>) — YYYY-MM-DD — <one-line highlight>
- …

## Conventions

- **Naming:** each release page is titled **`Release Notes vX.Y`** (add `.Z` for patch releases), slug `release-notes-vX-Y`.
- **Order:** releases are listed **newest-first**; version pages are created in version order so the section reads in sequence.
- **Append-only:** a shipped release page is never edited after ship (P4 carve-out for `release-notes`). A correction ships as the next version, not as an edit to a past one.
- **Per-version structure:** Highlights → Added / Changed / Fixed / Deprecated / Removed / Security / Breaking → Links (PRDs/ADRs/issues). See `release-notes.md`.

---

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
