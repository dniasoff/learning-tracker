# Copy / Text Review — Rebuilt Screens — 2026-05-20

**Companion to:** `docs/planning/ux-audit-2026-05-20-fix-plan.md` and `docs/planning/ux-audit-2026-05-20-hebrew-terms-findings.md`.
**Rules checked:** Hebrew Terms boundary (`docs/hebrew-terms.md` §3/§4/§5/§6/§10/§11), calendar terminology, profile model (`child`/`adult` only, no "parent"), completion-credit policy (3 tiers + sentinel date), pace-tracks-live-learning-only, offline-first, the 14 confirmed `DomainTermLabels` violations.

---

## Headline

**20 issues found across the rebuilt screens. The vast majority cluster into 3 root causes:**

1. **The 14 Hebrew-Terms-mis-classified labels** in `domain_term_labels.dart` — already documented in the findings doc. Surface on dashboard tile row, all 3 progress lens screens, active tracks card, recent activity, siyumim screen.
2. **2 date-formatting violations** in dashboard + curriculum summary card — hardcoded `Mon DD, YYYY` English-only format. Non-US locales see wrong date order.
3. **3 hardcoded pace-indicator strings** — "Ahead by X days" / "Behind by X days" / "On pace" are hardcoded English, not routed through ARB at all. Pace fails in non-English locale even when the rest of the screen localizes correctly.

The good news: lots of copy is **clean**. Bulk-mark and lifetime-mark wizards have *excellent* tier-credit disambiguation copy (line-cited below). No "Gregorian" in user-facing UI. No "parent" terminology in user-visible copy. Adult profiles correctly excluded from points displays. No offline-blocking copy.

---

## High-impact findings

### 1. Date format hardcoded in two places (Rule D)

- `lib/features/dashboard/presentation/widgets/dashboard_body.dart:101` — `"${_months[date.month]} ${date.day}, ${date.year}"`. English-only, US order. UK/IL users see "May 20, 2026" instead of "20 May 2026."
- `lib/features/dashboard/presentation/widgets/curriculum_summary_card.dart:194` — same pattern.

**Fix:** Switch to `DateFormat.yMMMd(locale)` from `intl` (already imported). Matches the rule from `feedback_calendar_terminology`.

### 2. Pace indicator hardcoded (Rule V)

- `lib/features/progress/presentation/widgets/pace_indicator.dart:26,30,32` — `"Ahead by ${value.days} days"`, `"On pace"`, `"Behind by ${value.days.abs()} days"` — all hardcoded English literals.

**Fix:** Add ARB keys `paceAheadByDays`, `paceBehindByDays`, `paceOnTrack`. Pluralize properly via ICU.

### 3. 14 Hebrew-Terms violations (Rule H ×14) — already documented

See `docs/planning/ux-audit-2026-05-20-hebrew-terms-findings.md`. Surface on every rebuilt screen via `progress_tier_counter_row.dart`, `active_track_card.dart`, the three progress lens screens, `recent_activity_screen.dart`. Fix shape: move from `domain_term_labels.dart` → ARB structural keys.

---

## Per-screen detail

### Dashboard — `lib/features/dashboard/`

- ❌ **D**: Hardcoded date format — `dashboard_body.dart:101`, `curriculum_summary_card.dart:194`.
- ❌ **H** (via facade): tile-row labels for streak/siyumim/items/points (`progress_tier_counter_row.dart`).
- ✅ Points correctly gated to child profile.
- ✅ Curriculum labels use `curriculumLabelText(ref)` correctly.

### Progress hub — `lib/features/progress/`

- ❌ **H** (via facade): all three lens titles + tier counter row.
- ✅ `recentActivityLiveOnlyDisclaimer` ("Live learning only — bulk-marked items appear under Lifetime Knowledge") — **excellent** tier-credit disambiguation per Rule 4.
- ✅ Child-only points gating intact.
- ✅ Empty states route through ARB.

### Pace indicator — `lib/features/progress/presentation/widgets/pace_indicator.dart`

- ❌ **V**: 3 hardcoded strings (lines 26, 30, 32).
- ✅ Caption parameter accepts the "Pace tracks live learning only" copy (correct intent).
- ⚠️ Caption is opt-in per call site — check all reuses include it.

### Active tracks card — `lib/features/tracks/.../active_track_card.dart`

- ❌ **H** (via facade): `terms.trackProgress`, `terms.lifetimeLabel`.
- ✅ Domain terms (curriculum name, chazara) correctly routed.

### Track detail (Mishnayos example)

- ❌ **H** (via facade): same `trackProgress` / `lifetimeLabel` violations.
- ⚠️ **§11.1 drift**: seder/masechta names not yet Hebrew-Terms-aware (render in transliteration even when toggle = Hebrew).
- ❌ **V**: "Ahead by 296 days" on day 1 — **the pace logic itself is wrong**, in addition to the localization issue. (Tracked in fix plan Stream F.)
- 🆕 **Missing track info** (new request 2026-05-20): track start date, target/goal date, required velocity, days elapsed, days remaining — none visible on the screen.

### Lifetime marking — `lib/features/settings/.../lifetime_marking_screen.dart`

- ✅ `lifetimeMarkingSubtitle` ("Items you've learned in your life, outside the app's tracks. Counted toward Lifetime Knowledge — not toward siyumim, streak, or points.") — **excellent**.

### Bulk-mark wizard

- ✅ `bulkMarkWizardSubtitle` ("These count toward siyumim and lifetime knowledge — but not toward your streak or points.") — **excellent** tier-credit copy.

### Onboarding / Learn

- ✅ Spot-check clean. No "parent" terminology. No "Gregorian" copy. No offline-blocking strings.

### Settings

- ⚠️ ARB key `calendarGregorian` (internal name) — user-visible label is "English" (correct). Key name is sloppy but not user-visible.

---

## What's verified clean

- ✅ **No "Gregorian" anywhere in user-facing copy.**
- ✅ **No "parent" terminology in user-facing copy.** (Code-side `UserMode.parent` exists — separate cleanup, tracked in Q-Term.)
- ✅ **No points or streak shown to adult profiles.**
- ✅ **No offline-blocking copy.** (Sync state is informational only.)
- ✅ **Tier-credit copy is consistently explicit** on bulk-mark, lifetime-mark, and recent-activity screens.
- ✅ **Empty / error / loading states** mostly route through ARB.

---

## Open owner decisions surfaced by the audit

- **Q-S1**: `siyum` / `siyumim` — domain term or structural? (Already in fix plan.)
- **Q-D**: Should the dashboard date format also support Hebrew calendar rendering (`כ"ד אייר תשפ"ו`) per `_useHebrewCalendar` setting, or only the English calendar locale-aware formatting? Currently neither is correctly applied.
- **Q-P**: Pace badge — when localized, should "Ahead by 5 days" use cardinal or ordinal form in target languages? (Hebrew has gendered numerals — `יום` vs `ימים`.)

---

## Summary count

| Rule | Code | Count | Severity |
|---|---|---|---|
| Hebrew Terms misclassification | H | 14 (in facade, surface multi-screen) | High |
| Date format hardcoded | D | 2 | High (non-US users) |
| Pace badge hardcoded | V | 3 | High (any non-English locale) |
| `calendarGregorian` ARB key name | G | 1 | Cosmetic (not user-visible) |
| **Total** | | **20** | |
