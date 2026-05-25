# Hebrew Terms Misuse Audit — 2026-05-20

**Companion to:** `docs/planning/ux-audit-2026-05-20-fix-plan.md` (Stream A).
**Spec:** `docs/hebrew-terms.md` is authoritative — read §3 (binary), §4 (structural vs domain), §5 (matrix), §6 (catalog), §10 (layering).
**Audit context:** UI locale = English, Hebrew Terms = ON (default). Per §5, that combination should render *English structural strings + Hebrew-script domain terms only*. Every Hebrew rendering of a non-§6 term is a violation.

---

## Headline

**14 violations. All in `learning_tracker/lib/core/labels/domain_term_labels.dart`. Feature widgets are clean.**

The §10 layering is being respected — feature code reads through the `domainTermLabels(ref)` facade as required. The bug is that the facade *exposes structural strings as if they were domain terms*. The catalog at §6 was misread when the facade was built.

**Fix shape:** Remove these 14 labels from the facade. Add ARB keys for them. Replace `terms.X` with `l10n.X` at the call sites. That's the entire fix.

---

## The 14 violations

| # | Symbol in `domain_term_labels.dart` | Line | English form | Hebrew rendered (when toggle ON) | Why it's a violation |
|---|---|---|---|---|---|
| 1 | `streakLabel` | 231 | "Streak" | `רצף` | Generic English word, not in §6 catalog |
| 2 | `today` | 235 | "Today" | (Hebrew) | Generic word, not in §6 |
| 3 | `trackProgress` | 240 | "Track progress" | `התקדמות מסלול` | Pure metric label, no domain term |
| 4 | `lifetimeLabel` | 247 | "Lifetime" | `ידע כולל` | Generic word |
| 5 | `tierLensRecentActivity` | 256 | "Recent Activity" | `פעילות אחרונה` | Screen title, structural |
| 6 | `streakAcrossAllCurricula` | 268 | "Streak across all curricula" | `רצף בכל המסלולים` | Explanatory sentence frame |
| 7 | `tierLensSiyumimMilestones` | 273 | "Siyumim & Milestones" | `סיומים והישגים` | Screen title (composed, but routed as a unit) |
| 8 | `tierLensLifetimeKnowledge` | 278 | "Lifetime Knowledge" | `ידע כולל` | Screen title, structural |
| 9 | `recentActivityShort` | 283 | "Recent Activity" (short) | (Hebrew) | Screen title variant |
| 10 | `tierCounterStreakDays(n)` | 293 | "X-day streak" | `רצף של X ימים` | Sentence frame with data |
| 11 | `tierCounterSiyumimEarned(n)` | 298 | "X siyumim earned" | (Hebrew) | Composed — "earned" is structural |
| 12 | `tierCounterLifetimeItems(n)` | 303 | "X items in lifetime" | `X פריטים ב…` | Pure structural |
| 13 | `tierCounterPoints(n)` | 308 | "X pts" | `נקודות X` | Generic word abbreviation |
| 14 | `milestone` / `milestoneAggregate` | 222, 226 | "Milestone" | (Hebrew) | English word, not in §6 |

---

## What is *correctly* in the facade (no change needed)

✅ `chazara`, `bubbleChazara`, `reviewSection`
✅ `daf`, `amud`, `perek`, `mishnah`, `seder`, `masechta`, `chumash`
✅ `talmidChochom`, `talmidChochomCaps`
✅ `stageLearn`, `chazaraStage(n)`, `stageName(n)`, `stageNameFromStageId(n)`, `resolveStoredStageName(s)`
✅ `limud`, `chazaros`
✅ `siyum*` curriculum-specific siyum celebrations (e.g. `siyumHaShas`, `siyumHaTorah`, `siyumHaMishnayos`) — *subject to Q-S below*

---

## Layering — clean

- **Direct `useHebrewTermsProvider` reads outside the allowed layers:** none found. The only direct reads are in `lib/features/settings/` and `lib/features/onboarding/` step that sets the preference, both of which are §10-permitted.
- **Hardcoded Hebrew in feature widgets:** none in presentation code. Hebrew appears only in legitimate data-layer constants (stage definitions, calendar program registry) and in ARBs.
- **English ARB containing Hebrew script:** none.
- **`make audit` grep:** broken — targets `hebrewTermsScriptProvider` (doesn't exist). Tracked in Stream A5 of the fix plan.

---

## Per-screen impact (what the user sees today)

**Dashboard top section (child profile):**
- 4-tile row labels: streak (#1, #10), siyumim earned (#11), lifetime items (#3 frame + #12), points (#13) — **all four tile labels mis-Hebrewized**.

**Active Tracks card:**
- "Track progress: 0%" → `התקדמות מסלול: 0%` (#3).
- "Lifetime: 32%" → `ידע כולל: 32%` (#4).
- (Curriculum name e.g. `משניות` Mishnayos = correctly domain ✅.)

**Recent Activity screen:**
- Page title (#5).
- Streak section header (#1), pill (#10), explanatory text (#6).
- Tier counter row (#10–13).

**Progress hub tabs:**
- All three lens titles (#5, #7, #8) plus short variant (#9).
- Tier counter row repeats (#10–13).

---

## Open classification questions (need owner decision)

Spec §6 does **not** list these terms. We need to either add them to the catalog (domain term, Hebrew-Terms-aware) or treat them as structural English words (UI-locale only).

| ID | Term | Recommendation | Rationale |
|---|---|---|---|
| Q-S1 | **siyum / siyumim** (the *concept* — completing a tractate) | **Add to §6 (domain term).** | It's a Torah-learning ritual word with no English translation — same shape as "chazara." Daniel's earlier feedback ("the only lower box that should be hebrew is mishnayos") might suggest otherwise; please confirm. If structural, fine — but then `siyumHaShas` etc. also become structural composed labels with proper-name interpolation. |
| Q-S2 | **siyum*HaShas/HaTorah/etc.** (proper-name siyum celebrations) | **Domain (per §6's "seder/masechta proper names" pattern).** | These ARE proper names of Jewish-learning milestones. |
| Q-M | **milestone** | **Structural.** | Generic English word with a perfectly good Hebrew equivalent (`אבן דרך`). No reason to bind to Hebrew Terms. |
| Q-T | **streak / today / lifetime / points / track progress / recent activity / overall knowledge** | **Structural.** | Already classified as violations above; this is the confirmation. |
| Q-L | **limud, chazaros, chazara** | **Domain (already in §6).** | No change. |

If Q-S1 lands as "structural," that simplifies the fix considerably — items #7 and #11 in the violations table become straightforward ARB replacements.

---

## Fix scope (for Stream A of the plan)

1. **Decide the open questions above** (Q-S1, Q-S2, Q-M).
2. **Remove the 14 confirmed violations** from `domain_term_labels.dart`.
3. **Add ARB keys** in both `app_en.arb` and `app_he.arb` for each removed label (e.g. `tileStreakLabel`, `tileTrackProgress`, `tileLifetimeLabel`, `screenTitleRecentActivity`, etc.).
4. **Update call sites** to read `l10n.X` instead of `terms.X` for the 14 labels — grep finds them.
5. **Fix the `make audit` grep** (`hebrewTermsScriptProvider` → `useHebrewTermsProvider`) so this class of regression is caught in CI.
6. **Add a CI test:** snapshot of `DomainTermLabels`' public surface compared against §6's catalog — fail if a non-catalog label is added.

---

## What this audit does NOT cover

- §11 punch list of the spec (daf/seder/chumash etc. not yet Hebrew-Terms-aware; stage names not re-rendering live) — tracked in the main fix plan, Stream A4.
- Hebrew locale screens (those should already be Hebrew everywhere; no audit needed for the inverse direction).
- Non-rebuilt screens (sign-in, password reset, error screens) — sample-checked, no violations found, but not exhaustive.
