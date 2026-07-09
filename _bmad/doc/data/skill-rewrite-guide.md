# How to Rewrite a BMAD Skill for Docmost

> Audience: dev agents performing the skill rewrite wave.
> Companions: `taxonomy.md` (where docs go), `docmost-cli-reference.md` (the CLI surface), `decision-order.md` (the routing).

## BMAD-preservation stance — read this first

BMAD has a large community and this module must stay rebaseable against upstream. **Do not retire, merge, rename, or restructure BMAD skills.** The rewrite is additive:

- Existing skill bodies stay intact.
- An Orvex-specific **wiki-publish hunk** is *appended* to doc-producer skills.
- An Orvex-specific **wiki-read-first hunk** is *prepended* to doc-reader skills.
- A short **Tier-C guardrail** is *prepended* to local-only producer skills.
- New skills are added fresh — these use the full pattern below.

Every added block must be wrapped in a clearly-delimited comment:

```
<!-- ORVEX BEGIN: wiki-publish -->
... Orvex-specific instructions ...
<!-- ORVEX END: wiki-publish -->
```

## The three buckets

Every existing BMAD skill falls into exactly one of these buckets:

1. **Doc-producer** — apply three hunks: (a) the **find-first hunk** in the INITIALIZATION section; (b) the **wiki-publish hunk** appended to the end; and (c) for step-file workflows only, the **wiki-publish-trigger hunk** appended to the terminal step file.

2. **Doc-reader** — prepend the **wiki-read-first hunk** at the start of the read step.

3. **Local-only producer** — prepend the **Tier-C guardrail** paragraph. Output stays in `<work-output>/`.

## The wiki-publish hunk (for doc-producer skills)

Append this hunk verbatim (with placeholders filled) to the END of every doc-producer `workflow.md`:

```markdown
<!-- ORVEX BEGIN: wiki-publish -->
## Publish to wiki (Orvex addition)

After producing the local artifact, publish it to Docmost as the canonical version. The local copy remains as the working artifact; the wiki copy is the source of truth for human readers.

0. **Auth pre-flight** (required before any wiki write):
   ```bash
   docmost-cli auth status --output json
   # Exit non-zero: HALT — tell the user to run docmost-cli auth login first.
   ```

1. **Consult the taxonomy** to determine the wiki target:
   - Read `_bmad/doc/data/taxonomy.md` §4 — find the doc-type for this skill's output.
   - Note the parent path and cardinality (one-per-project vs many).

2. **Find before create.** Search for an existing page:
   ```bash
   docmost-cli page list --space {docmost_space} \
     --filter 'doc_type == "<type>" && status != "superseded" && status != "archived"' --output json
   docmost-cli search "<topic>" --cached --content --space {docmost_space} --output json
   ```
   - If a live match exists → **update** it (see §3 below).
   - If not → **create** new (see §4 below).

3. **Update existing** (single-page, full-body replacement):
   ```bash
   docmost-cli page update <existing-slug> \
     --content @<local-artifact-path> \
     --icon <emoji> \
     --owner-id <uuid> \
     --last-reviewed-at "$(date -u +%FT%TZ)" \
     --if-version "$(docmost-cli page get <existing-slug> --field updated_at)"
   ```

4. **Create new** (only after step 2 returned empty):
   ```bash
   docmost-cli page create "<Title>" \
     --space <slug> \
     --parent <parent-from-taxonomy> \
     --doc-type <type> \
     --status draft \
     --owner-id <uuid> \
     --content @<local-artifact-path>
   ```

5. **Promote to canonical** after user review:
   ```bash
   docmost-cli page update <new-slug> --status canonical --doc-type <type> \
     --owner-id <uuid> --last-reviewed-at "$(date -u +%FT%TZ)"
   ```

6. **If superseding an old doc** (only when a real prior slug exists):
   ```bash
   docmost-cli page transclusion-impact <old-slug> --operation supersede --output json
   docmost-cli page supersede <published-slug> --supersedes <old-slug>
   docmost-cli page update <published-slug> --redirect-from <old-slug>
   ```

7. **Audit is automatic** — every mutation writes to local JSONL and Docmost's audit table.
<!-- ORVEX END: wiki-publish -->
```

## The find-first hunk (for doc-producer skills)

Add this hunk to the INITIALIZATION section of the doc-producer `workflow.md`, before it hands off to generation steps:

```markdown
<!-- ORVEX BEGIN: find-first -->
## Find before create (Orvex addition — runs during INITIALIZATION)

1. Consult `_bmad/doc/data/taxonomy.md` §4 — confirm `doc_type` (lowercase-kebab); resolve the parent slug from config `docmost_parent_slugs.<type>`.
2. Search the wiki:
   - `docmost-cli auth status --output json`  (exit non-zero → HALT)
   - `docmost-cli cache sync --space {docmost_space}`
   - `docmost-cli search "<topic>" --cached --content --space {docmost_space} --output json`
   - `docmost-cli page list --space {docmost_space} --filter 'doc_type == "<type>" && status != "superseded" && status != "archived"' --output json`
3. Branch: a live page found → `{{orvex_mode}} = update`, `{{orvex_canonical_slug}} = <slug>`; none → `{{orvex_mode}} = create`.
4. Persist `{{orvex_mode}}` / `{{orvex_canonical_slug}}` to the output file's frontmatter.
<!-- ORVEX END: find-first -->
```

## The wiki-read-first hunk (for doc-reader skills)

Prepend this hunk to the START of every doc-reader skill's read step:

```markdown
<!-- ORVEX BEGIN: wiki-read-first -->
## Read from wiki first (Orvex addition — MANDATORY)

The wiki is the **primary source of truth** and **OUTRANKS local files**. ALWAYS resolve
the wiki FIRST — never establish project state, existence, or "ground truth" from local
files without first checking Docmost via `docmost-cli`:

```bash
docmost-cli cache sync --space <slug>
docmost-cli search "<topic>" --cached --content --space <slug> --output json
docmost-cli page list --status canonical --filter '<expr>' --space <slug> --output json
```

For each candidate page:
```bash
docmost-cli page get <slug>                  # markdown body
docmost-cli page get <slug> --output json    # full record with native metadata
```

Filter by `status: canonical` — drafts, deprecated, superseded, and archived must not influence reasoning. If a candidate is `status: superseded`, follow `superseded_by` and read the successor instead.

ONLY if the wiki genuinely has no match (or `docmost-cli` is unreachable) may you fall back to the skill's existing local-read behavior — and when you do, say so explicitly. NEVER silently treat a local file as authoritative while the wiki is reachable; the wiki is primary, local files are transient working drafts. When the fallback greps or reads local `docs/`, it MUST honor the repo-root `.bmadignore`.
<!-- ORVEX END: wiki-read-first -->
```

## The Tier-C guardrail (for local-only producer skills)

Prepend this paragraph to the top of every local-only producer skill body:

```markdown
<!-- ORVEX BEGIN: tier-c-guardrail -->
> **Tier C output — do not publish to wiki.** This skill produces ephemeral / AI-only artifacts under `<work-output>/` per `_bmad/doc/data/taxonomy.md` §3 Tier C (the closed transient-local set — `research` and `brainstorm` are NOT here; they are durable Tier-A canon). Do not invoke `docmost-cli page create`, `page update`, or any `mirror push` from inside this skill.
<!-- ORVEX END: tier-c-guardrail -->
```

## Common pitfalls

- **Don't combine migrate + consolidate in one skill.** They're separate workstreams.
- **Don't have a skill decide doc_type.** Always consult `taxonomy.md` §4.
- **Don't bake filesystem paths or hand-write API calls.** Use `docmost-cli` primitives.
- **Always run `page transclusion-impact` before any destructive operation.**
- **Use `--if-version` on `page patch` for CAS safety.**
- **Bidirectional supersession only works via `page supersede`.** Setting `superseded_by:` in front-matter alone is NOT enough.
- **Don't push drafts to canonical in the same call.**
- **Don't bypass the find-before-create gate.**
