# Decision Order — Documentation Operations

When a BMAD skill needs to author or update documentation, follow this router
BEFORE choosing a recipe. The router is non-discretionary: skills walk it
top-to-bottom and dispatch the first matching branch.

This router enforces the constitution (the 7 principles). Three rules sit above
every branch:

- **Wiki-first (mandatory).** The wiki manual is the PRIMARY source of truth and
  OUTRANKS local files. Resolve the wiki before establishing project state from the
  filesystem; never conclude "no X exists" from local files alone. Full doctrine +
  access: `wiki-first-mandate.md`.
- **docmost-cli primitives only.** Never bake a filesystem path, never hand-write
  an HTTP call, never touch the SQLite cache. Every read and write goes through
  `docmost-cli` so audit, CAS, transclusion, dup-guard, and status-quarantine
  safeguards apply uniformly.
- **Branch on exit code + `errorCode`, never on stderr text.** See
  docmost-cli-reference.md §"Exit codes & error envelope".

The manual is a single living tree per project. Its root slug is
`docmost_manual_root_slug` and its section layout (the IA) is read from the
project's own `manual-outline.yaml` (key `docmost_manual_outline` in config). The
module ships **no fixed section skeleton** — the IA is derived per project at
scaffold time and confirmed with a human. Wherever this router says "manual
node," it means the IA node resolved from that project's outline, not a
hardcoded section name.

## Pre-flight (always)

```
BEFORE any read command
  └─→ docmost-cli cache sync                 (or `--space <slug>` for one space)
      (exit 3 / CACHE_STALE on a read means sync was missed — re-sync and retry)

BEFORE any write command
  ├─→ docmost-cli auth status                (exit 0 = authenticated)
  └─→ docmost-cli cache sync                 (so CAS / dup-guard reads are current)
```

## Routing

The branches below are ordered. READ → FIND → ASK → AMEND → CREATE is the
single authoring spine every content unit walks; the WIKI-FIRST, DRIFT, and
SUPERSEDE branches are entered by their triggering skill (`doc-spec-gate`,
`doc-drift`, `manual-supersede`) and then re-join the spine at AMEND or CREATE.

```
(1) READ  — resolve the living manual node FIRST  (doc-read-first; P2, P6)
  ├─→ skill:doc-read-first                  (resolves root + IA path for the
  │                                          concept, status-filtered)
  ├─ grounding read                    ─→ docmost-cli page get <node-slug> --output json
  │                                       (the resolver excludes draft / superseded /
  │                                        archived from grounding — never reason
  │                                        from a quarantined body)
  └─ spec mode (wiki-first)            ─→ resolve the INTENT node for the story
                                          being built (a technical-spec / prd
                                          section under the story's epic node)

(2) FIND-BEFORE-CREATE  — pre-probe + the authoritative create-path guard  (P1)
  │  Do NOT rely on a fresh `search` as the FINAL guard — search only sees indexed
  │  pages and will miss a sibling draft authored seconds ago. There is no standalone
  │  `page duplicate-check` verb; the synchronous dup guard is built INTO `page create`
  │  (--force-new + exit 8 / DUPLICATE_CANDIDATE — see (5)). Use a cheap pre-probe to
  │  catch the obvious collisions early, then let create be the authoritative arbiter.
  │
  ├─ STEP 1 — cheap pre-probe          ─→ docmost-cli search "<Title or key terms>" \
  │                                         --cached --content --space <slug> --output json
  │                                       (and/or `docmost-cli page list --filter '<expr>'`)
  │                                       (a hit → likely candidate, go to (3) ASK GATE)
  │                                       (no hit → proceed to (5) CREATE — the create-path
  │                                        guard still re-checks, including drafts)
  │
  └─ STEP 2 — draft-vs-draft race      ─→ two agents can author the same concept
                                          concurrently before either is indexed, and the
                                          pre-probe (STEP 1) can miss a sibling draft.
                                          The AUTHORITATIVE collision check is the
                                          create-path guard, server-side at `page create`
                                          (see (5)) — it includes drafts and returns
                                          exit 8 / DUPLICATE_CANDIDATE on a hit.
                                          If STEP 1 surfaces ANY draft on the concept,
                                          treat it as a candidate and go to (3) — do
                                          not create a second draft hoping to merge
                                          later.

(3) ASK GATE  — one plain-English question on a candidate  (P3)
  │  Triggered whenever (2) returns a candidate. Do NOT silently pick.
  │
  ├─ make the question durable         ─→ docmost-cli comment add <candidate-slug> \
  │                                         --body "Found existing «<title>». Amend it
  │                                                 to add: <one-line diff>?  (y = amend /
  │                                                 n = new page)"
  │
  ├─ SUSPEND the workflow              ─→ surface the SAME one question to the human
  │                                       in chat: existing title + a one-line diff of
  │                                       what this unit would add. Auto-resume on reply.
  │                                       Ask exactly ONE question — never a checklist.
  │
  ├─ human answers "amend"             ─→ go to (4) AMEND-FIRST against <candidate-slug>
  └─ human answers "new"               ─→ go to (5) CREATE with the human token

(4) AMEND-FIRST  — update affected sections in place  (P1, P4)
  │  Default for everything. Update the EXISTING node; never spawn a sibling.
  │
  ├─ read current body                 ─→ docmost-cli page get <slug> --output json
  │                                       (capture updated_at for CAS)
  │
  ├─ single affected section           ─→ docmost-cli page patch <slug> \
  │                                         --find "<old section text>" \
  │                                         --replace "<new section text>" \
  │                                         --if-version "<cached updated_at>"
  │                                       (regex: --regex · preview: --dry-run)
  │
  ├─ tldr / lead callout               ─→ docmost-cli page block callout <slug> \
  │                                         --op replace-at \
  │                                         --type info \
  │                                         --content @<lead>
  │                                       (never rewrites the protected story / "how this
  │                                        manual works" zones — those are transcluded
  │                                        canon and are non-AI-writable. role-anchored
  │                                        targeting by data-orvex-role="tldr" is PENDING;
  │                                        --role does not exist on `page block callout`.)
  │
  ├─ multi-section reconcile           ─→ docmost-cli page mirror pull <dir> --space <slug>
  │                                       edit ONLY the affected sections in <dir>/<slug>.md
  │                                       docmost-cli page mirror push <dir> --space <slug>
  │
  └─ ALWAYS: current-state-only body   ─→ the body says what is true NOW. No inline
                                          history, no "previously / as of / changed in"
                                          narration, no in-body changelog. History lives
                                          in git + Docmost page history + the
                                          server-rendered changelog projection (P4).
                                          (exit 7 / CONFLICT on --if-version → re-read,
                                           rebase the edit, retry)

(5) CREATE  — only when no candidate, or the human chose "new"  (P1)
  │  Reachable only from (2)-empty or (3)-"new". `page create` re-runs the
  │  synchronous dup guard itself — it is the authoritative draft-vs-draft arbiter.
  │
  ├─ default create                    ─→ docmost-cli page create "<Title>" \
  │                                         --space <slug> \
  │                                         --parent <ia-node-slug> \
  │                                         --doc-type <type-from-taxonomy §4> \
  │                                         --status draft \
  │                                         --content @<file>
  │                                       (NEVER --status canonical on create — AI
  │                                        authors at draft only; see (6))
  │                                       (server refuses DUPLICATE_CANDIDATE → return
  │                                        to (3) ASK GATE; do not retry blindly)
  │
  └─ human chose "new" over a candidate ─→ carry the human-attributed FORCE_NEW token as
                                          the value of --force-new (a single string — there
                                          is NO --human-token flag):
                                          docmost-cli page create "<Title>" … \
                                            --status draft \
                                            --force-new "<token>"
                                          (--force-new WITHOUT a server-minted human token is
                                           rejected; self-authored prose cannot satisfy it —
                                           review MA-1. Emits a FORCED_NEW audit event counted
                                           in the created-vs-updated summary.)

(6) DRAFT → RATIFY GATE  — promotion is a human act  (P3)
  │  AI never promotes its own writing. Every create/amend above lands at `draft`.
  │
  ├─ leave it at draft                 ─→ the page is authored; STOP. Drafts are
  │                                       quarantined from `ai ask` + grounding reads
  │                                       until ratified — they cannot poison the next
  │                                       agent's reasoning.
  │
  └─ promote                           ─→ skill:doc-ratify  (one question per decision;
                                          delight-review for root / section landings)
                                          docmost-cli page update <slug> \
                                            --status canonical \
                                            --ratify-token "<token>"
                                          (server-side draft→canonical guard REJECTS
                                           service-account / self-authored promotions)

(7) WIKI-FIRST branch  — record + CONFIRM intent before code  (WF, P3, P6)
  │  Driven by skill:doc-spec-gate. The confirm happens EARLY, where a human is.
  │
  ├─ at create-story (human present)   ─→ doc-amend RECORDS the intent node (a
  │                                         technical-spec / prd section under the
  │                                         story's epic) at status draft, then SUSPEND
  │                                         with the (3) one-question confirm BEFORE the
  │                                         story flips to ready-for-dev.
  │                                       on confirm → server issues a
  │                                         spec-confirmation token (validates substance,
  │                                         not mere existence — a stub page does not pass)
  │
  └─ at dev-story (autonomous loop)    ─→ docmost-cli spec gate check <story-id> --output json
                                          READ-ONLY token check. Happy path = no-op pass
                                          (preserves dev-story's continuous-execution
                                          contract). On a GENUINE miss:
                                            wiki_first_enforcement == block → HALT (default)
                                            wiki_first_enforcement == warn  → log WARN, proceed
                                            wiki_first_enforcement == off   → no-op

(8) DRIFT branch  — code changed; reconcile the manual  (P1, P6, WF)
  │  Driven by skill:doc-drift (and on_complete after a story). Steady-state engine.
  │
  ├─ STEP 1 — affected-page set        ─→ docmost-cli code graph --lang <l> --out graph.json
  │                                       docmost-cli verify drift --output json
  │                                       (walk caller edges ONE hop — referrers, not
  │                                        callees — for the exact referencer-scoped set)
  │
  ├─ STEP 2 — refresh as a DRAFT       ─→ for each affected canonical page, produce a
  │                                         DRAFT revision (never an in-place canonical
  │                                         rewrite) with --if-version CAS, current-state-
  │                                         only body, then route to (6) → skill:doc-ratify
  │
  └─ STEP 3 — stamp verified_against   ─→ body-delta split (review MA-3):
                                          • body CHANGED  → stamp only AFTER human
                                            ratification carries the token:
                                              docmost-cli page update <slug> \
                                                --verified-against <sha> --ratify-token "<token>"
                                          • ZERO body delta (re-affirm code unchanged) →
                                            headless stamp allowed:
                                              docmost-cli page update <slug> --verified-against <sha>
                                          (unreconcilable page → leave a review-required
                                           `comment add`; do not guess)

(9) SUPERSEDE branch  — whole-doc replacement only  (P5)
  │  Driven by manual-supersede (librarian-dispatched). A live doc holds ZERO
  │  superseded content — never amend old content INTO a live page; supersede the
  │  whole doc to archive and link the live successor.
  │
  ├─ STEP 1 — transclusion pre-flight  ─→ docmost-cli page transclusion-impact <old-slug> \
  │                                         --operation supersede --output json
  │                                       (exit 0 = safe · exit 1 = references exist)
  │
  ├─ if references exist               ─→ decide:
  │                                          a) abort + migrate the source content elsewhere
  │                                          b) auto-unsync: re-run supersede with
  │                                             --on-transclusion-conflict unsync
  │
  ├─ STEP 2 — atomic supersede         ─→ docmost-cli page supersede <new-slug> \
  │                                         --supersedes <old-slug>[,<old-slug-2>...]
  │                                       (server writes BOTH sides atomically and flips
  │                                        the loser to status superseded; card views
  │                                        auto-drop superseded/archived — no dead cards)
  │
  └─ STEP 3 — register redirects       ─→ docmost-cli page update <new-slug> \
                                            --redirect-from <old-slug-1>,<old-slug-2>
                                          (powers resolve-slug + async body-link rewrite)

QUESTION about wiki content (read-only, no authoring)
  └─→ docmost-cli ai ask "<question>" --output json
      (cited answer; drafts/superseded/archived are quarantined from retrieval,
       so every citation is a CURRENTLY-TRUE canonical line — P6;
       exit 1 / SEARCH_MODE_UNAVAILABLE → fall back to `search` + `page get`)
```

## Anti-patterns (DO NOT)

```
DO NOT  create a page named <topic>-v2 / <topic>-new / <topic>-final / <topic>-2026-01
        └─→ A slug collision is a duplicate signal. Go to (4) AMEND-FIRST.
            A trailing date segment is permitted ONLY for release-notes / retro / adr
            (validated against doc_type, not slug text — taxonomy §5).

DO NOT  skip (2) FIND-BEFORE-CREATE because a `search` came back empty
        └─→ search misses sibling drafts. Use it only as a pre-probe; the create-path
            guard built into `page create` (exit 8 / DUPLICATE_CANDIDATE, includes drafts)
            is the authoritative draft-vs-draft arbiter.

DO NOT  create or promote a page at --status canonical
        └─→ AI authors at draft only. Promotion is a human act through (6) doc-ratify
            with a human-attributed token. The server rejects service-account promotions.

DO NOT  pass --force-new with a self-authored --reason / prose
        └─→ --force-new requires a human-attributed token. An agent cannot approve its
            own sprawl. If unsure, drop into (3) ASK GATE instead.

DO NOT  write history into a live body ("previously…", "as of…", an in-body changelog)
        └─→ Bodies are current-state-only (P4). History lives in git + Docmost page
            history + the server-rendered changelog projection.

DO NOT  amend old/superseded content INTO a live page to "preserve" it
        └─→ Supersession is whole-doc to archive (P5). A live doc holds zero superseded
            content. Run branch (9).

DO NOT  let doc-drift rewrite a canonical page in place and self-stamp it verified
        └─→ Drift refresh lands as a DRAFT revision routed through (6) doc-ratify.
            verified_against stamps only on a human-ratified body change, or headless
            ONLY on a zero-body-delta re-affirmation (branch (8) STEP 3).

DO NOT  archive, delete, or supersede without `page transclusion-impact` first
        └─→ Silent reference breakage is the exact failure this workflow prevents.

DO NOT  rewrite the protected story / tldr / "how this manual works" zones
        └─→ They are transcluded from one canon source and are non-AI-writable.
            amend/drift target only the affected non-protected sections.

DO NOT  decide the doc_type yourself
        └─→ Consult taxonomy.md §4. The catalog is the only source of doc-type names.

DO NOT  parse stderr error text
        └─→ Branch on exit code + the errorCode field. See docmost-cli-reference.md.

DO NOT  bake filesystem paths or hand-write API calls
        └─→ Always go through docmost-cli primitives so audit, CAS, dup-guard,
            quarantine, and transclusion safeguards apply.
```
