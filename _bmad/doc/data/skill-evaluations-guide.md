# Skill evaluations — format & usage

Behavioral **regression specs** for the doc-* skills, co-located at
`skills/<skill>/evaluations/*.json`. The format is adapted from the official Notion
Claude Code plugin's skill evaluations. Each case pins down a load-bearing behavior
(usually one or more of the 7 principles) so a skill rewrite can't silently regress it.

## Format

```json
{
  "name": "Short human title for the case",
  "skills": ["doc-amend"],
  "query": "The user request / trigger that invokes the skill",
  "context": "The wiki/repo state the case assumes",
  "expected_behavior": ["Ordered steps the skill SHOULD take"],
  "success_criteria": ["Observable pass/fail checks"]
}
```

## How to run them

BMAD ships **no automated eval runner**, so these are checked two ways:

1. **Review-time (static):** a reviewing agent reads the skill's `SKILL.md` (and/or a
   real session transcript) and confirms it satisfies every `expected_behavior` and
   `success_criteria`. Good for catching a rewrite that drops a guard.
2. **Live (dynamic):** run the `query` against the sandbox Docmost space (`LWLAB`) with
   `docmost-cli` and assert the `success_criteria` on the real wiki (e.g. "exactly one
   living page exists — no sibling was created").

A case **fails** if any `success_criteria` is unmet. Treat a failure as a regression in
the skill, not a reason to weaken the criteria — the criteria encode the constitution
(`doc-session-policy`) and the routing tree (`decision-order.md`).

## Coverage

| Skill | Case(s) | Principle(s) locked |
|---|---|---|
| `doc-amend` | find-before-create, ask-on-ambiguity | P1, P3, P4, P6 |
| `doc-research` | durable-canon-update-in-place | P1, P2, P4 |
| `doc-consolidate` | dedup-supersede-whole-doc | P1, P5 |
| `doc-spec-gate` | dev-story-gate-enforcement | wiki-first gate, non-blocking happy path |
| `doc-ratify` | no-self-promote | P6 |
| `doc-read-first` | quarantine-drafts | P6 |

Add a case whenever a new load-bearing behavior is introduced; keep them current-state
(delete a case only when the behavior is intentionally removed).
