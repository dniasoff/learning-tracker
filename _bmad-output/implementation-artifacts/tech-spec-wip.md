---
title: 'Multi-Profile Onboarding with Learning Program Wizard'
slug: 'multi-profile-onboarding-learning-wizard'
created: '2026-03-17'
status: 'in-progress'
stepsCompleted: [1]
tech_stack: ['Flutter 3.38.6', 'Dart 3.10.8', 'Drift 2.31.0', 'Riverpod 3.1.0', 'auto_route 11.x', 'Firebase Auth', 'Cloud Firestore', 'freezed 3.2.3', 'flutter_local_notifications']
files_to_modify: []
code_patterns: []
test_patterns: []
---

# Tech-Spec: Multi-Profile Onboarding with Learning Program Wizard

**Created:** 2026-03-17

## Overview

### Problem Statement

The current onboarding flow has no way to configure the learning/chazarah (review) process, treats child and adult modes identically, and only supports a single user per account. Parents/tutors cannot set up multiple learners, and users are stuck with default review stages that may not match their actual learning program (Oraysa, Dirshu, etc.). The sign-in screen is a non-functional stub that creates a dead end for unauthenticated users. AppBar titles truncate on longer curriculum names.

### Solution

Introduce a multi-profile system (up to 10 profiles per account), a learning program wizard during onboarding (with presets filtered by curriculum and custom schedule builder), improved bulk mark (standalone, multi-select, search, pagination), Dirshu test tracking with configurable reminders and score logging, and child-mode-specific UX with parent-directed language. Replace the stage editor with a "Change Program" flow.

### Scope

**In Scope:**

1. **Multi-profile system** — Up to 10 learner profiles per account. Profile picker on launch when 2+, auto-skip when 1. Each profile has own name, mode (child/adult), curricula, completions, stages, goals, test scores.
2. **Revised onboarding flow** — Profile creation as first step after account creation. Parent-directed language for child profiles.
3. **Learning process wizard** — Per-curriculum program preset selection (filtered by curriculum) or custom schedule builder. Runs after curriculum import, before bulk mark.
4. **Program presets** — Oraysa, Dirshu Kinyan Torah, Dirshu Amud HaYomi, Dirshu Daf HaYomi B'Halacha, Dirshu Kinyan Chochma, Dirshu Kinyan Yerushalmi, Daf Yomi, Mishnah Yomis, Nach Yomi, Custom. Immutable preset definitions stored in DB. Preset ID saved per profile+curriculum.
    - **New curricula required:** `nach` (Nach — Nevi'im & Ketuvim), `mussar` (Mussar Sefarim)
5. **Expanded stage model** — Support delay-based, day-of-week, and rolling window (Oraysa back-20) scheduling types beyond the current `delay_days` field.
6. **Improved bulk mark** — Standalone feature accessible from settings anytime. Forced during onboarding and when changing programs. Multi-select at any hierarchy level (seder, tractate, perek, daf), search, pagination, per-stage marking.
7. **Program management post-onboarding** — "Change Program" replaces the existing stage editor. Triggers bulk mark for new stages. Existing completions preserved. "Request a Program" sends pre-filled email.
8. **Dirshu test tracking** — Test calendar per program (published Sunday dates), configurable reminders (sensible defaults: 1 week + 1 day before), score logging (percentage), motivational notifications on trends.
9. **Child-mode UX** — Parent-directed language during setup ("How does your child review?"), child's name displayed throughout ("Moshe's Dashboard"), handoff screen after setup, no PIN required for child mode.
10. **Auth guard fix** — Redirect to WelcomeRoute instead of stub SignInRoute.
11. **AppBar FittedBox fix** — Prevent title truncation on longer curriculum names.

**Out of Scope:**

- Chitas preset (multi-curriculum mapping — deferred)
- Tutor management app (future separate app)
- Adaptive SRS / Anki-style scheduling (ease factors, recall quality)
- Steipler method (completion-triggered count-based review)
- Zichru overlay (mnemonic + tiered review)
- Dirshu Kinyan Shas, Kinyan Halacha, Chaburas HaShas, Bnei Yeshivos presets (niche/institutional)
- Master Torah rapid cycling model

## Context for Development

### Codebase Patterns

- **Feature module pattern:** domain/ (models, repositories, services) → data/ (implementations, datasources) → presentation/ (providers, screens, widgets)
- **All domain models:** @freezed with `const factory`, updates via `.copyWith()`
- **Family providers:** Curriculum-scoped state isolation via `provider(curriculumId)` — will need expansion to `provider(profileId, curriculumId)`
- **Database:** Drift ORM with migrations (currently v9). All timestamps UTC. Every write uses `db.transaction()`.
- **Completions:** Use `sefariaRef` (String), NOT `content_item_id`
- **Navigation:** auto_route 11.x with typed guards (AuthGuard, RestoreGuard, ChildModeGuard, ParentPinGuard, TutorPinGuard)
- **Enums:** CurriculumId (mishnayos, bavli, yerushalmi, mishna_berurah, chumash, nach *(new)*, mussar *(new)*), UserMode (child, adult), TrackType (personal, school, tutor)
- **Code generation:** `dart run build_runner build --delete-conflicting-outputs` after Drift/Freezed/Riverpod changes

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `lib/core/database/app_database.dart` | Schema v9, migrations, DAO injections |
| `lib/core/database/tables/` | Drift table definitions |
| `lib/core/enums/curriculum_id.dart` | 5 curriculum IDs |
| `lib/core/enums/user_mode.dart` | child/adult enum |
| `lib/core/navigation/app_router.dart` | All routes + guards |
| `lib/core/navigation/guards/auth_guard.dart` | Auth redirect (needs WelcomeRoute fix) |
| `lib/features/onboarding/presentation/screens/` | Current onboarding screens |
| `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | Current bulk mark (5 phases) |
| `lib/features/stages/domain/models/stage_definition.dart` | Current stage model (name, delayDays, order) |
| `lib/features/stages/presentation/screens/stage_editor_screen.dart` | Current stage editor (to be replaced) |
| `lib/features/auth/presentation/screens/sign_in_screen.dart` | Stub sign-in screen |
| `lib/features/auth/presentation/screens/welcome_screen.dart` | Welcome screen with Get Started |
| `lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | Goal setup with Hebrew date support |

### Technical Decisions

1. **Multi-profile architecture:** Expand `user_profiles` table to support multiple profiles per Firebase UID. Add `profile_id` foreign key to all user-scoped tables (completions, bookmarks, stages, goals, etc.). Profile picker route added before AppShell.
2. **Program presets:** Immutable preset definitions stored in a new `learning_programs` table (bundled/seeded on first run). Each preset defines its stages, schedule types, and metadata. Presets linked to profiles via `profile_curricula` join table.
3. **Stage model expansion:** Add `schedule_type` enum (delay, day_of_week, rolling_window), `days_of_week` (comma-separated or JSON), `rolling_window_size` (int) to `stage_definitions` table. `delay_days` remains for delay-based stages.
4. **Bulk mark as standalone:** Extract from onboarding into its own feature module. Callable from onboarding flow AND settings. Enhanced with search, pagination, multi-level selection.
5. **Test tracking:** New `test_records` table (profile_id, program_id, test_date, score_percent, created_at). New `test_calendar` table (program_id, test_date) seeded from bundled data.
6. **Preset filtering:** Program presets tagged with applicable `curriculum_id` values. UI filters based on selected curriculum.
7. **One program per curriculum per profile:** Enforced at data layer. Changing program overwrites preset reference and reconfigures stages.

### Program Preset Data

#### Preset → Curriculum Mapping

| Preset | Curricula |
| ------ | --------- |
| Oraysa | bavli |
| Dirshu Kinyan Torah | bavli |
| Dirshu Amud HaYomi | bavli |
| Dirshu Daf HaYomi B'Halacha | mishna_berurah |
| Dirshu Kinyan Chochma | mussar *(new)* |
| Dirshu Kinyan Yerushalmi | yerushalmi |
| Daf Yomi | bavli |
| Mishnah Yomis | mishnayos |
| Nach Yomi | nach *(new)* |
| Custom | all |

#### Oraysa Stage Configuration
| Stage | Name | Schedule Type | Config |
| ----- | ---- | ------------- | ------ |
| 1 | Learn | daily | New amud Sun–Thu |
| 2 | Next-Day Review | delay | delay_days: 1 |
| 3 | Weekly Review | day_of_week | days: [friday, shabbos] |
| 4 | Back-20 Review | rolling_window | window_size: 20 |

#### Dirshu Kinyan Torah Stage Configuration
| Stage | Name | Schedule Type | Config |
| ----- | ---- | ------------- | ------ |
| 1 | Learn | daily | 1 daf/day |
| 2 | Monthly Test Prep | delay | test-driven review |

#### Dirshu Test Calendar (Example)
Monthly tests on specific Sundays (published annually):
- Oct 19, Nov 9, Dec 7 2025
- Jan 11, Feb 8, Mar 15, Apr 12, May 10, Jun 7, Jul 5, Aug 2, Sep 6 2026

Test format: 30 short-answer questions, scored as percentage. 80%+ for stipend.

#### Notification Defaults
- Test reminder: 7 days before + 1 day before (configurable)

## Implementation Plan

### Tasks

*To be completed in Step 2 (Deep Investigation)*

### Acceptance Criteria

*To be completed in Step 3 (Generate)*

## Additional Context

### Dependencies

- Schema migration v9 → v10+ (multi-profile, expanded stages, test tracking, program presets)
- Bundled preset data (JSON/YAML in assets)
- Dirshu test calendar data (bundled, updateable with app releases)
- Code generation rebuild after model changes

### Testing Strategy

*To be completed in Step 3 (Generate)*

### Notes

- **New curricula:** Adding `nach` (Nach — Nevi'im & Ketuvim) and `mussar` (Mussar Sefarim) curriculum IDs to support Nach Yomi and Dirshu Kinyan Chochma presets.
- **Oraysa back-20 rolling window** is the most complex scheduling model — needs careful design of the daily task composer to surface the right review items.
- **Profile-scoping migration** is the highest-risk task — every query that touches user data needs profileId filtering.
- **Existing completions on program change:** When a user switches programs, all existing completions are preserved. New stages from the new program appear in bulk mark so the user can mark what they've already done.
