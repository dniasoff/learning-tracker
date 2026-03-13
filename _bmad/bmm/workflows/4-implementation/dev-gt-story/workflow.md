---
name: dev-gt-story
description: 'Shared gastown story implementation. Inherits from dev-story. Adds: slung issue context, commit verification, checklist enforcement, gt done submission.'
---

# Dev Gastown Story Workflow (Shared Base)

**Goal:** Execute story implementation as a gastown agent — shared behavior for both polecats and crew.

**Inherits from:** `dev-story`. All base steps apply unless explicitly overridden below.

**Inherited by:** `dev-gt-polecat-story` and `dev-gt-crew-story`.

> **Linear Integration:** Gastown workflows REQUIRE tracking_system=linear. There is no local-file fallback.
> **READS:** Use `.linear-cache/stories/DNI-XX.yaml` for story details.
> If cache is missing, run `tool/linear-sync.sh sync` to auto-create it.
> **WRITES:** Always write to Linear first via `linearis` CLI (pipe through jq), then run
> `tool/linear-sync.sh story <ID>` to refresh the cache entry.

---

## GASTOWN RULES

<check if="{tracking_system} != linear">
  <output>HALT: Gastown workflows require tracking_system=linear in bmm config.</output>
</check>

1. **ONLY WORK ON SLUNG STORIES.** GT_LINEAR_ISSUE MUST be set. If empty → HALT. Do NOT auto-discover stories.
2. **COMMITS MUST BE REAL.** After every `git commit`, immediately run `git log --oneline -1` and verify YOUR commit appears. If not → HALT and re-run.
3. **EXIT VIA gt done.** Do NOT run `git push` manually. Do NOT update Linear status manually. gt done handles push, status, and Refinery notification.
4. **Commit trailers** ("Part of DNI-XX") are handled automatically by gt done. Do NOT add manually.

---

## STEP OVERRIDES

### Step 0: Verify gastown assignment

<check if="GT_LINEAR_ISSUE is not set OR empty">
  <output>HALT: No work assigned. GT_LINEAR_ISSUE is not set. Gastown agents do NOT self-assign stories.</output>
</check>

### Step 1: Load context from slung issue (REPLACES base Step 1)

Set {{linear_issue_id}} = $GT_LINEAR_ISSUE

**Fast path** — if GT_LINEAR_CONTEXT is set and file exists:
- Read pre-fetched context: `cat $GT_LINEAR_CONTEXT`
- Parse: title, status, description (Story statement, ACs, Dev Notes, Tasks), comments
- For checkbox ticking in later steps, always do a fresh fetch

**Fallback** — fetch via linearis:
- `linearis issues read $GT_LINEAR_ISSUE | jq -r '.description'`
- `linearis issues read $GT_LINEAR_ISSUE | jq '[.comments[] | {author: .user.name, body: .body}]'`

Parse Implementation Tasks, identify first incomplete task. Check for review continuation in comments.

Post context-loaded comment:
```bash
linearis comments create $GT_LINEAR_ISSUE --body "## Context Loaded
Story: {{issue_identifier}}
ACs: [count], Tasks: [total] total, [incomplete] remaining"
```

### Step 2: Branch setup (EXTENDED — subclasses override branch creation)

Update Linear status:
```bash
linearis issues update $GT_LINEAR_ISSUE -s "In Progress"
```

Post branch comment:
```bash
linearis comments create $GT_LINEAR_ISSUE --body "## Branch Ready
Branch: [name], Base: {default_branch} at [sha]"
```

### Step 5: Implementation (EXTENDED — add commit verification + checkbox ticking)

**HALT-LEVEL RULE:** After every `git commit`, immediately run `git log --oneline -1` and verify YOUR commit appears.

After each task completion, tick checkbox in Linear:
```bash
DESC=$(linearis issues read $GT_LINEAR_ISSUE | jq -r '.description' | sed 's/- \[ \] TASK/- [x] TASK/')
linearis issues update $GT_LINEAR_ISSUE -d "$DESC"
linearis comments create $GT_LINEAR_ISSUE --body "Task complete: [task]. Progress: [n]/[total]"
```

### Step 8: Commit (EXTENDED — zero-commit guard)

<check if="git log origin/{default_branch}..HEAD is empty AND implementation was done">
  HALT: Zero commits found. Your git commit commands did not execute. Return to Step 5.
</check>

### Step 9: Completion (EXTENDED — checklist hard gate)

Verify all checkboxes ticked:
```bash
linearis issues read $GT_LINEAR_ISSUE | jq -r '.description' | grep -c '- \[ \]'
```
If any unchecked → HALT. Tick them or complete the work.

Post confirmation:
```bash
linearis comments create $GT_LINEAR_ISSUE --body "## Checklist Gate Passed
All implementation tasks: ticked. All acceptance criteria: ticked."
```

### Step 10: Submit via gt done (REPLACES base Step 10)

Do NOT run `git push` manually — gt done handles it.
Do NOT update Linear status — gt done sets "Code Complete".
Do NOT close the issue — the Refinery does that after merge.

```bash
gt done
```
