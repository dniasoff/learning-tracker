# Learning Tracker — Testing Quick Reference

**Last Updated:** 2026-07-13
**Status:** Superseded — retained only as a redirect.

> **Superseded.** This page predated the current mocktail-based test suite: its
> worked examples used the `mockito` package (banned by
> [`docs/coding-standards.md` TQ-4](../coding-standards.md) — the live suite
> has 0 mockito imports and 200+ mocktail-based test files) and cited concrete
> file paths (`curriculum_card.dart`, `mishnayos_adapter.dart`, an
> `API Tests (Sefaria)` section describing a runtime HTTP-fetch content
> architecture) that no longer exist — content is bundled at build time, not
> fetched at runtime. Rather than duplicate maintenance across two docs, this
> page now only redirects:
>
> - **[Testing Guide](../testing-guide.md)** — how to write unit, widget,
>   story-acceptance, and integration tests; current mocktail patterns; test
>   infrastructure details; known gotchas.
> - **[Test Options](../test-options.md)** — overview of every test
>   layer/option (what each covers, how to run it, what it does not cover).
> - **[Developer Handbook](../developer-handbook.md)** — setup, workflow, and
>   coding standards, including the testing-quality (`TQ-*`) rules.

---

**Questions?** See the [Testing Guide](../testing-guide.md) or the
[Developer Handbook](../developer-handbook.md) for current coding standards
including testing requirements.
