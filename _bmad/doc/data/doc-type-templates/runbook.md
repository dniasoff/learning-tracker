---
# Documentation Taxonomy — required native fields (mirror as YAML on Markdown round-trip)
status: draft
owner_id: ""
doc_type: runbook
# Optional fields — fill when applicable, remove if unused
# last_reviewed_at: 2026-05-15
# supersedes: []
# superseded_by:
# redirect_from: []
# tags: [operations]
---

<!--
How to use this template
- Skill: bmad-runbook (placeholder; will be filled by skill rewrites)
- Target location: /Operations/Runbooks/<topic>
- One-or-many: many per project (one per operational procedure)
- Lifecycle: status starts as `draft`; flip to `canonical` after a successful dry-run
-->

# Runbook — Replace with Title Case

<!-- One paragraph framing: which scenario this runbook addresses and who runs it. -->

## Trigger

<!-- The condition that causes this runbook to be executed. Alert name, symptom, user report, schedule. -->

## Prerequisites

<!-- Access, tools, credentials, and environment state required before starting. List explicitly. -->

## Procedure

<!--
Step-by-step instructions. Each step:
- numbered
- imperative ("Run X", not "You should run X")
- includes the exact command or action
- includes the expected observable result
-->

1. <!-- Step 1 -->
2. <!-- Step 2 -->
3. <!-- Step 3 -->

## Verification

<!-- How to confirm the procedure worked. Concrete checks the operator can perform. -->

## Rollback

<!-- How to undo the procedure if it fails or makes things worse. Include the decision criteria. -->

## Escalation

<!-- Who to page or notify if the runbook does not resolve the issue. Include thresholds and channels. -->

---

<!-- Footer / metadata that does NOT belong in front-matter -->

**Owner:** <handle>
**Last reviewed:** <YYYY-MM-DD>
