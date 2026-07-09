# Citations & cross-links

> Scope: how skills link pages to each other, build the navigation spine, cite evidence, and keep new pages from becoming orphans. Adapted in part from the Notion plugin's `citations` reference and `knowledge-capture` discoverability step.
> Companion files: `authoring-conventions.md` (the Canon row + breadcrumb conventions), `rich-page-authoring.md` (transclusion vs linking).

A living wiki is only as good as its links. An un-linked page is invisible no matter how good it is.

---

## 1. Link forms that work everywhere

- **Internal markdown links become native page mentions.** `page create`/`page update` publish a markdown link to a page as a first-class Docmost **mention** (not inert text), so cross-links are clickable and backlink-tracked.
- **Public share-URL form** for a link target: `https://<INSTANCE>/s/<SPACE-SLUG>/p/<SLUGID>`. slugIds are **global** (do not pass `--space` to `page get`). All page/comment commands accept this full URL form as a slug argument, so a copied wiki URL "just works" as an arg.
- **Transclusion ≠ a link.** A link points; a `transclusion --src` embeds the source's *live* content inline. Use a link for "see also"; use transclusion for "this fact is defined once over there" (see `rich-page-authoring.md` §4).

---

## 2. The navigation spine (house convention)

Every page in a program/manual carries three link affordances (see `authoring-conventions.md` §1):
- **`Canon:` row** — a `·`-joined row of links to the small set of authoritative companion docs (PRD · Architecture · Contracts · Command Reference). Identical on the hub and every child; a stable lateral spine.
- **`↑ Part of [<hub>](<url>)` breadcrumb** — an explicit upward backlink on every child (even though Docmost already nests pages).
- **Downward links** — a hub's roadmap/task-list names link down to each child page.

Confirm the spine actually resolves — these are cache-only, no API:
```bash
docmost-cli page backlinks <slug> --output json      # who links TO this page
docmost-cli page breadcrumbs <slug> --output json     # ancestor path
```

---

## 3. The anti-orphan step (run after every create)

A new page is not "done" when it is written — it is done when it is **discoverable**. After `page create`/scaffold, link it in:
1. Add it to its **section landing** (a `subpages` card grid auto-includes children; otherwise add a link in the parent's body).
2. Add the **`↑ Part of`** breadcrumb to the new page.
3. Add **lateral "Related" links** to sibling canon where relevant.
4. Verify: `page backlinks <new-slug>` returns at least its parent/section; if empty, the page is an orphan — fix before finishing.

(Card grids and `subpages` blocks **exclude superseded/archived pages**, so no dead cards survive on a live landing — P5.)

---

## 4. Citing evidence (research / spec pages)

When a page asserts a fact drawn from a source, cite it. Forms, in rough order of weight:
- **Inline citation** — a mention/link right after the claim, for a single fact.
- **Section citation** — a trailing "(per `<page>` / `<commit-sha>` / `<url>`)" for a paragraph.
- **Code/commit authority** — inline commit SHA (`` (lesson `ab24e35`) ``) for engineering claims, as the architecture exemplar does.
- **A grouped `## Sources` section** at the foot for a research page — every external URL + every wiki page the synthesis drew on.

**Balance:** cite enough that a reader can verify the load-bearing claims; do not cite every sentence (noise) or leave the central claims unsupported (untrustworthy). Aim for "every non-obvious factual claim is traceable."

**Distinguish facts from model insight.** A cited fact and a synthesised inference are different things. Label model-supplied analysis/recommendations as such (this is the same discipline as `doc-research`'s inference-flagging) — never present an unsourced inference as an established fact.

### Validation checklist (before promoting a research/spec page)
- [ ] Every load-bearing factual claim has a traceable source (page mention, URL, or commit).
- [ ] Inferences/recommendations are visibly distinguished from cited facts.
- [ ] A `## Sources` section exists for research pages and lists every external + internal source used.
- [ ] All internal links resolve (no broken mentions): `docmost-cli verify links <slug>`.
- [ ] The page is reachable from its section landing (`page backlinks` non-empty).
