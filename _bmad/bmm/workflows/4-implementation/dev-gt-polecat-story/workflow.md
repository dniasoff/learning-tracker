---
name: dev-gt-polecat-story
description: 'Gastown polecat story. Inherits from dev-gt-story. Adds GT_BRANCH verification and gt mol step done tracking.'
---

# Dev Gastown Polecat Story Workflow

**Goal:** Execute story implementation as a gastown polecat — an ephemeral sandbox agent.

**Inherits from:** `dev-gt-story` → `dev-story` (full chain).

> **Linear Integration (inherited):** READS from `.linear-cache/stories/DNI-XX.yaml`. WRITES via `linearis` CLI then `tool/linear-sync.sh story <ID>`.
> After completing each step, you MUST call `gt mol step done <step-id>` with a detailed --body. This is IN ADDITION TO Linear comments.

---

## STEP OVERRIDES

### Step 0: Verify polecat identity (PREPEND to gastown base)

```bash
echo "POLECAT=$GT_POLECAT BRANCH=$GT_BRANCH ROLE=$GT_ROLE AGENT=$BEADS_AGENT_NAME"
```

<check if="GT_POLECAT is not set">
  HALT: GT_POLECAT is not set. This workflow is for polecats only.
</check>

<check if="GT_BRANCH is not set">
  HALT: GT_BRANCH is not set. Polecat sandbox was not properly initialized.
</check>

### Step 1: Context (APPEND — add gt mol + polecat identity)

Include in Linear comment: **Polecat:** $GT_POLECAT, **Branch:** $GT_BRANCH

```bash
gt mol step done load-context --body "Context Loaded. Story: {{issue_identifier}}, Polecat: $GT_POLECAT, Branch: $GT_BRANCH"
```

### Step 2: Verify polecat branch (REPLACES base Step 2)

Polecats use a pre-created branch ($GT_BRANCH). Do NOT create a new branch.

```bash
git branch --show-current  # Expected: $GT_BRANCH
git fetch origin
git rebase origin/{default_branch}
```

If rebase conflicts → resolve carefully. If stuck → HALT.

Update Linear status and post branch comment via linearis.

```bash
gt mol step done branch-setup --body "Branch: $GT_BRANCH, rebased on {default_branch}"
```

### Steps 3-9: Add gt mol step done at each gate

After each step, run:
- Step 3: `gt mol step done preflight-tests --body "Result: PASS/FAIL"`
- Step 4: `gt mol step done plan --body "Files: [list], Approach: [desc]"`
- Step 5: `gt mol step done implement --body "Commits: [list], Tasks: [n]/[total]"`
- Step 6: `gt mol step done self-review --body "Files reviewed: [n], Issues: [list]"`
- Step 7: `gt mol step done run-tests --body "Result: [pass]/[fail]"`
- Step 8: `gt mol step done commit-changes --body "$(git log --oneline origin/{default_branch}..HEAD)"`
- Step 9: `gt mol step done prepare-for-review --body "Issue: {{issue_identifier}}, Summary: [what]"`

### Step 10: Exit (EXTEND — sandbox destruction)

gt done handles everything (push, Refinery notification, Code Complete, sandbox nuke).
No gt handoff needed — the sandbox is destroyed.
