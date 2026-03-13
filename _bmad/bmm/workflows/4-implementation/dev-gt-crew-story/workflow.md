---
name: dev-gt-crew-story
description: 'Gastown crew story. Inherits from dev-gt-story. Adds crew branch lifecycle and gt handoff.'
---

# Dev Gastown Crew Story Workflow

**Goal:** Execute story implementation as a gastown crew member — a persistent branch agent.

**Inherits from:** `dev-gt-story` → `dev-story` (full chain).

> **Linear Integration (inherited):** READS from `.linear-cache/stories/DNI-XX.yaml`. WRITES via `linearis` CLI then `tool/linear-sync.sh story <ID>`.

---

## CREW RULES (in addition to gastown base rules)

1. **ONE STORY PER SESSION.** Complete one story, then immediately run `gt done` + `gt handoff --collect`. Do NOT loop back. Do NOT start another story.
2. **EXIT VIA gt done + gt handoff.** Both commands, in order, immediately.

---

## STEP OVERRIDES

### Step 0: Verify crew identity (PREPEND to gastown base)

```bash
echo "CREW=$GT_CREW LINEAR=$GT_LINEAR_ISSUE BMAD=$GT_BMAD CONTEXT=$GT_LINEAR_CONTEXT"
```

<check if="GT_CREW is not set">
  HALT: GT_CREW is not set. This workflow is for crew members only.
</check>

### Step 1: Context (EXTEND — include crew identity)

Ensure the context-loaded Linear comment includes: **Crew member:** $GT_CREW

### Step 2: Reset crew branch to latest default_branch (REPLACES base Step 2)

Never work on {default_branch} directly. Always work on `crew/$GT_CREW`.

```bash
git fetch origin
git checkout crew/$GT_CREW 2>/dev/null || git checkout -b crew/$GT_CREW origin/{default_branch}
```

Check for uncommitted/staged changes and committed divergence. If changes exist that are NOT in {default_branch} → HALT.

```bash
git reset --hard origin/{default_branch}
git push --force-with-lease origin crew/$GT_CREW
```

Update Linear status and post branch comment via linearis (inherited from dev-gt-story).

### Step 10: Submit + handoff (EXTEND base gt done)

After gt done completes, IMMEDIATELY run:
```bash
gt handoff --collect
```

VIOLATIONS (HALT-LEVEL):
- Do NOT ask "should I continue?" — just run gt handoff
- Do NOT loop back to Step 1
- Do NOT start another story in this session
- Do NOT skip gt handoff — context bleed causes hallucination
