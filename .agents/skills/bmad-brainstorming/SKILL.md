---
name: bmad-brainstorming
description: 'Facilitate interactive brainstorming sessions using diverse creative techniques and ideation methods. Use when the user says help me brainstorm or help me ideate.'
---

<!-- bmad-docmost-patch v0.1.0 — WIKI-FIRST (brainstorming; core-skill has no customize hook) -->

## WIKI-FIRST (MANDATORY) — bmad-docmost

This is a living-wiki project. The Docmost wiki manual is the PRIMARY source of truth and OUTRANKS local files — for this session and every turn. Before you read local files to establish project context, resolve what the wiki holds (skill:doc-read-first, or `docmost-cli ai ask "<question>" --output json`, or `docmost-cli search "<topic>" --cached --content --space {docmost_space} --output json` then `docmost-cli page get <slug> --output json`). Load skill:doc-session-policy and file:{project-root}/_bmad/doc/data/wiki-first-mandate.md as the bedrock for this session. Verify access once: `docmost-cli auth status --output json` (branch on exit code + errorCode, never stderr).

Brainstorm output is **durable wiki canon (P2), not ephemeral scratch.** The local `{brainstorming_session_output_file}` is only a transient working draft. On completion, route the brainstorm into the project's living manual via skill:doc-amend: find-before-create for doc_type=brainstorm on this topic across drafts AND canonical; ASK one plain-English question on a fuzzy match; AMEND the existing node in place (current-state-only, P4) or CREATE at `--doc-type brainstorm --status draft` (NEVER --status canonical — AI never self-promotes; promotion is doc-ratify). One living page per topic — never a dated sibling (P1). If docmost-cli is unavailable, WARN and name the unsynced local draft; do not silently demote it to authoritative.

Follow the instructions in ./workflow.md.

<!-- bmad-docmost-patch:applied:v0.1.0 -->
