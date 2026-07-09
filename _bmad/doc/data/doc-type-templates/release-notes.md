---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: release-notes
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
tags: [release]
---

<!--
How to use this template — PER-VERSION release-notes page
- Skill: doc-release (gathers the changelog) → doc-amend (CREATE at draft) → doc-ratify (ship to canonical)
- This is ONE version's page. The section also has a living LANDING page from `release-notes-index.md`.
- Title:  "Release Notes vX.Y"  (consistent, version-keyed — e.g. "Release Notes v1.1"). Add the patch (vX.Y.Z) only when you ship patch-level notes.
- Slug:   release-notes-vX-Y  (semver dots → hyphens). The version is this page's legitimate dated/append key — analogous to an ADR's leading NNNN- sequence (taxonomy §5/§6). It is NOT a banned duplicate-variant suffix.
- Ordering: the landing lists versions newest-first; create each version page in version order so the section reads in order.
- One-or-many: many per project (one per release). DATED/APPEND (taxonomy §5): a new version is a NEW child page, never an amend of a prior version. Past-tense "Released YYYY-MM-DD" is correct here — the P4 no-obsolescence-narration lint is EXEMPT for release-notes version pages.
- Lifecycle: `draft` while the release stabilises; a human flips it to `canonical` on ship, and updates the landing's "latest" pointer.
- Embeds to use: a `table` of changes (or `status` badges per change), and `linear_*` / Linear mention links to the issues shipped. Link PRDs/ADRs by Docmost page mention.
-->

# Release Notes vX.Y

<!-- HIGHLIGHTS: one-paragraph narrative lead (the tldr). Who this release is for and the 2–3 headline changes, scannable in 10 seconds. Lead with the highest-impact change. -->

> **Released** YYYY-MM-DD · **Channel** stable|beta|canary · **Build** <build-id, if any>

## Highlights

<!-- 2–4 bullets, each the user-facing impact of a headline change. Link the driving PRD/ADR/issue. -->

## Added

<!-- New user-visible features and capabilities. Internal refactors go in Changed. -->

## Changed

<!-- Behaviour or interface changes that are not strictly additions or fixes. Note migration steps. -->

## Fixed

<!-- Bug fixes, phrased from the user's perspective. -->

## Deprecated

<!-- Features marked for removal in a future release. Include sunset date and migration path. -->

## Removed

<!-- Features removed in this release. Cross-link the prior deprecation notice. -->

## Security

<!-- Security-relevant changes. CVE references and severity, if any. -->

## Breaking changes

<!-- Anything requiring consumer action to upgrade. Include before/after snippets. -->

## Links

<!-- Traceability. Use Docmost page mentions for wiki docs and Linear URLs/IDs for issues:
- PRD / ADRs that drove this release (page mentions)
- Linear issues / milestone shipped in this version
- The prior release: [Release Notes vX.(Y-1)](<url>)
-->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
