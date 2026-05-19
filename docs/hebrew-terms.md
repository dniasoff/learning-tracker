# Hebrew Terms — Localization Rules

Status: **Defined** (2026-05-18). This document is the canonical spec for how
Torah domain terminology is rendered across the app. Where the current code
diverges from these rules, see §11 — those are defects to fix, not the spec.

## 1. Purpose

The app is used by Torah learners. Many user-facing words are Hebrew domain
terms — *chazara*, *daf*, the masechta and seder names, the curriculum names.
Some users want those in **Hebrew script** (חזרה); others — especially on the
English UI — want them in **Latin transliteration** (Chazara). The **Hebrew
Terms** setting controls this, independently of the app's UI language.

## 2. Two independent axes

A user-facing string is positioned by two separate settings:

1. **UI locale** — English or Hebrew. The whole app's language (device locale
   driven; no in-app picker). Governs *structural* strings.
2. **Hebrew Terms mode** — how *domain terms* render. Per-profile, stored
   independently of the UI locale.

These do not interact except as described in the matrix in §5.

## 3. The Hebrew Terms mode is binary

A domain term has exactly **two** written forms:

| Form | Example (chazara) | Example (curriculum) |
|---|---|---|
| **Hebrew script** | חזרה | משניות |
| **Transliteration** | Chazara | Mishnayos |

There is deliberately **no "translated" form**. Torah learners do not call
chazara "Review", a daf a "Page", or a masechta a "Tractate" — the
transliteration *is* the English form. A third "translated" mode would be
empty, so the setting is **binary**:

- **Hebrew** — domain terms in Hebrew script.
- **English** — domain terms transliterated.

The setting label reads "Hebrew / English" to the user; "English" means the
transliteration.

## 4. Structural strings vs domain terms

Every user-facing string is **exactly one** of:

- **Structural string** — UI chrome: buttons, headers, sentence frames,
  settings labels, generic words ("Completion", "with", "Next", "Skip",
  "Today's Missions"). → Follows the **UI locale only**. The Hebrew Terms
  setting never touches a structural string.
- **Domain term** — a Torah concept or proper name (see the catalog in §6).
  → Follows the **Hebrew Terms** setting.

A composed label is a structural frame with domain term(s) interpolated:

> `Completion (with {chazara})` → "Completion (with Chazara)" or
> "Completion (with חזרה)" — the frame is structural, `{chazara}` is a term.

## 5. Rendering matrix

| | Structural string | Domain term |
|---|---|---|
| English locale, Hebrew Terms = English | English | Transliteration |
| English locale, Hebrew Terms = Hebrew | English | Hebrew script |
| Hebrew locale | Hebrew | Hebrew script |

In Hebrew locale every term is already Hebrew, so the Hebrew Terms setting is a
no-op — and is **hidden** from the settings screen there (§9).

## 6. Domain-term catalog

The Hebrew Terms setting is authoritative for **all** of the following. None of
them may be hardcoded at a call site.

- **Learning terms** — chazara, the review concept.
- **Structural Torah units** — daf, amud, perek, mishnah, seder, masechta.
- **Curriculum names** — mishnayos, bavli, yerushalmi, chumash, nach, tanach,
  mishna berurah, mussar, mishneh torah.
- **Seder / masechta proper names** — Zeraim, Moed, Berakhos, …
- **Stage names** — Learn (לימוד), Chazara 1/2/3 (חזרה א׳/ב׳/ג׳), etc. (§8).
- **Scholar tiers / honorifics** — e.g. talmid chochom.

**Proper-name exception.** Proper names (curriculum, masechta, seder) have only
two forms — Hebrew script and a transliteration. They have no English
*translation*; "English" mode renders the transliteration. This is consistent
with §3 (binary), it simply means the two forms for a proper name are
"Hebrew script" and "transliteration", same as every other term.

## 7. Transliteration variant

When Hebrew Terms = English, the transliteration follows the separate
**Transliteration** setting (Ashkenazi / Sephardi): e.g. "Shabbos" vs
"Shabbat", "Bereishis" vs "Bereshit". The Transliteration setting is only
meaningful — and only shown — when Hebrew Terms = English.

## 8. Stage names

A track moves each item through *stages*: Learn first, then the chazara passes
(Chazara 1, Chazara 2, …). The label of each step is a **domain term** and
obeys the Hebrew Terms setting.

Stage names **re-render live** when the setting changes. They are **not** frozen
at track creation — switching Hebrew Terms must immediately re-render every
stage label (Learn ⇄ לימוד ⇄ transliteration) everywhere it appears
(scheduler, tasks, track setup).

## 9. Defaults & visibility

- **Default: Hebrew.** The setting ships ON (Hebrew script).
- The setting is **hidden in Hebrew locale** — it is a no-op there (§5).

## 10. Implementation contract

- Domain terms render through the single Hebrew-Terms provider
  (`useHebrewTermsProvider`). No domain term is hardcoded at a call site.
- The provider read is confined to `lib/core/labels/`, `lib/core/preferences/`,
  and the settings screens. Feature widgets receive already-resolved strings
  (e.g. via `CurriculumLabel` / a resolved term passed in), or read the
  provider only at the allowed layers. This boundary is meant to be enforced
  by a `make audit` layering grep.
- The English (transliteration) form of a term lives in the English ARB; the
  Hebrew form lives in the Hebrew ARB and in the `HebrewTerms` constants. A
  term must not appear as hardcoded Hebrew in the English ARB.

## 11. Known drift to fix

The audit (2026-05-18) found the implementation has diverged from this spec:

1. **Coverage gap.** Only *chazara/review* and *talmid chochom* are actually
   Hebrew-Terms-aware. `daf`, `seder`, `chumash`, `amud`, `masechta` and the
   structural unit words are **not** — they follow the UI locale only. Per §6
   they must all become Hebrew-Terms-aware.
2. **Translated form leaking in.** The English string for chazara is
   `"Chazara/Review"` in places. Per §3 the English form is pure
   transliteration — correct it to `"Chazara"`. "Review" is not used for a
   domain term.
3. **Dead constant.** `HebrewTerms.uiBubbleChazara` is defined but never used;
   the "CHAZARA" bubble reads a plain locale string and never switches.
4. **Hardcoded term.** "Talmid Chochom" / "TALMID CHOCHOM" appear as inline
   string literals instead of going through the setting.
5. **Broken enforcement.** The `make audit` layering grep targets a symbol name
   (`hebrewTermsScriptProvider`) that does not exist; the real provider
   (`useHebrewTermsProvider`) is unguarded. The grep must be corrected.
6. **Stage names frozen.** Existing stage labels do not re-render on a setting
   change (§8) — only newly-created defaults are affected. Must be fixed.
7. **Stale doc.** A settings-screen comment claims the default is `false`; it
   is `true` (§9).
8. **Duplication.** `HebrewTerms.curriculumDisplayNames` duplicates
   `CurriculumId.displayNameHe`; the Hebrew "חזרה" string is defined in several
   places. Consolidate to one source per term.
