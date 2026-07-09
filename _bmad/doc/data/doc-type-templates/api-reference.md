---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: api-reference
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: []
---

<!--
How to use this template
- Skill: bmad-api-reference (placeholder; will be filled by skill rewrites)
- Target location: /Reference/API/<api>
- One-or-many: many per project (one per API surface)
- Lifecycle: status starts as `draft`; flip to `canonical` when the surface ships and is stable
-->

# API Reference — Replace with Title Case

<!-- One paragraph framing: which API this documents, who consumes it, and where the source of truth lives. -->

## Resource

<!-- The resource(s) this API exposes. Conceptual model, identity scheme, and lifecycle. -->

## Endpoints

<!-- Each endpoint: method, path, purpose, auth requirements. Keep the table or list compact and scannable. -->

## Authentication

<!-- How callers authenticate. Token format, header names, scopes, rotation expectations. -->

## Request/response shapes

<!-- Canonical request and response payloads. Field-by-field reference; mark required vs optional. -->

## Error codes

<!-- The full error taxonomy: code, HTTP status, meaning, and recommended caller response. -->

## Examples

<!-- End-to-end call examples for the most common flows. Copy-pasteable; use realistic but synthetic data. -->

## Versioning

<!-- Versioning policy: how versions are advertised, deprecation windows, breaking-change conventions. -->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
