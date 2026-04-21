# V1 Out-of-Scope Features & Code

This document lists all features and code in the codebase that are **beyond the v1 scope** defined in [`docs/developer-handbook.md`](docs/developer-handbook.md).

**Date audited:** 2026-04-21  
**Handbook reference:** developer-handbook.md (2026-04-19)  
**Project status reference:** linear-status.md (2026-04-19)

## Summary

**V1 scope (per handbook):** Core learning flow + basic dashboard + multi-track + onboarding + parent mode (PIN-protected child dashboard) + notifications + sync.

**Out of scope:** Advanced analytics, complex dashboard redesigns, catch-up/amnesty, tutor mode, school/tutor track promotion, smart streak recovery, mystery rewards, gamification beyond child-mode basics.

**Total codebase:** 17 features, ~54k LOC (including generated code).

---

## Feature-by-Feature Breakdown

### 1. **Gamification Feature** (1,037 LOC, 9 files) ❌ **FULLY OUT OF SCOPE**
- **Status:** Out of scope for v1
- **Location:** `lib/features/gamification/`
- **What it is:** Points system, streak tracking with recovery, mystery rewards system
- **Why out of scope:** Handbook explicitly says v1 is "clean progress tracking without gamification" for adults; child mode gamification (points, streaks) is minimal MVP only
- **Dependencies on gamification:**
  - `lib/core/navigation/app_router.dart` — registers gamification route
  - `lib/features/dashboard/presentation/providers/dashboard_providers.dart`
  - `lib/features/learning/data/repositories/completion_repository_impl.dart`
  - `lib/features/learning/presentation/providers/completion_providers.dart`
  - `lib/features/learning/presentation/screens/learning_screen.dart`
- **Recommendation:** Remove gamification feature entirely from v1; it's a v2 feature for child mode only

### 2. **Learning Order Feature** (772 LOC, 9 files) ⚠️ **PARTIALLY OUT OF SCOPE**
- **Status:** Configuration feature, optional for v1
- **Location:** `lib/features/learning_order/`
- **What it is:** Drag-and-drop learning order customization (reordering what gets learned each day)
- **Why out of scope:** Handbook treats as "Epic 5" completed, but this is a **power-user configuration feature**, not part of MVP daily flow
- **Dependencies on learning_order:**
  - `lib/core/navigation/app_router.dart`
  - `lib/features/scheduler/domain/services/scheduler_engine.dart`
  - `lib/features/scheduler/presentation/providers/scheduler_providers.dart`
- **Recommendation:** Consider for v1.1; not required for MVP. Users can use default learning order.

### 3. **Stages Feature** (830 LOC, 9 files) ⚠️ **PARTIALLY OUT OF SCOPE**
- **Status:** Configuration feature, optional for v1
- **Location:** `lib/features/stages/`
- **What it is:** Chazara (review) stage configuration — customize review delay schedule
- **Why out of scope:** Handbook treats as "Epic 5" completed, but configuration screens for adjusting review delays are power-user features, not v1 MVP
- **Dependencies on stages:**
  - `lib/features/onboarding/presentation/screens/` — used in onboarding (okay for v1)
  - `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` — advanced settings (out of scope)
  - `lib/features/scheduler/domain/services/scheduler_engine.dart` — core scheduler logic (needs stages data)
- **Recommendation:** Keep stage definitions, remove advanced settings UI. Use defaults only in v1.

### 4. **Parent Mode** (2,291 LOC, 17 files) ⚠️ **PARTIALLY OUT OF SCOPE**
- **Status:** Child-mode-only for v1; parent analytics out of scope
- **Location:** `lib/features/parent_mode/`
- **What's in v1:** PIN setup, basic child dashboard, point/reward management UI (child mode only)
- **What's out of scope:**
  - Advanced parent analytics beyond basic progress view
  - Streak recovery management from parent view
  - School/tutor track assignment (mentioned in handbook as "not promoted in v1 onboarding")
- **Recommendation:** Keep parent_mode; audit for advanced analytics screens

### 5. **Settings Feature** (4,003 LOC, 17 files) ⚠️ **PARTIALLY OUT OF SCOPE**
- **Status:** Core settings in scope; advanced settings out of scope
- **Location:** `lib/features/settings/`
- **What's in v1:** Notification preferences, basic account management (delete), basic theme
- **What's out of scope:**
  - `curriculum_settings_screen.dart` — stage customization (out of scope unless required for v1)
  - Data export/import (Epic 14, verify if truly v1)
  - Developer/debug settings
  - Complex preference hierarchies
- **Recommendation:** Audit for advanced/debug settings screens

### 6. **Progress Feature** (5,529 LOC, 30 files) ⚠️ **PARTIALLY OUT OF SCOPE**
- **Status:** Basic progress in v1; Epic 20 redesign out of scope
- **Location:** `lib/features/progress/`
- **What's in v1:** Basic per-curriculum progress views with simple stats
- **What's out of scope:**
  - Epic 20 dashboard redesign (multi-track isolation, per-track providers) — **explicitly backlog**
  - Complex progress charts/visualizations beyond simple bar/line
  - Learning Journey rework (Epic 20)
  - Recovery/catch-up actions (Epic 22)
  - Advanced filtering or drill-down analytics
- **Likely out of scope files:**
  - Complex chart widgets (cumulative_line_chart, etc.)
  - Files modified after 2026-04-15 (likely Epic 20 work)
- **Recommendation:** Audit for Epic 20 code; remove if found

### 7. **Dashboard Feature** (5,537 LOC, 36 files) ⚠️ **PARTIALLY OUT OF SCOPE**
- **Status:** Basic dashboard in v1; Epic 20 redesign out of scope
- **Location:** `lib/features/dashboard/`
- **What's in v1:** Cross-curriculum task list, basic today's tasks view, simple track cards
- **What's out of scope:**
  - Epic 20 dashboard redesign (multi-track isolation, stats row, 4 card variants) — **explicitly backlog**
  - Track recovery action buttons (found: `track_card/recovery_action_button.dart`)
  - Advanced pace/progress cards beyond simple layout
  - Complex filtering/sorting logic
- **Likely out of scope files:**
  - `dashboard/presentation/widgets/track_card/recovery_action_button.dart` — ⚠️ **FOUND: recovery actions (Epic 22)**
  - Files in `track_card/` directory modified after 2026-04-15
- **Recommendation:** Remove recovery_action_button; audit track card variants for Epic 20 code

### 8. **Notifications Feature** (2,212 LOC, 8 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature
- **Location:** `lib/features/notifications/`
- **What's in v1:** Daily learning reminders, streak protection alerts, Shabbos quiet mode
- **What's out of scope:**
  - Reward milestone notifications (likely Epic 22, which is backlog)
  - Advanced scheduling logic beyond standard interval
- **Assessment:** Keep; verify no Epic 22 reward notifications mixed in

### 9. **Sync Feature** (4,150 LOC, 16 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature
- **Location:** `lib/features/sync/`
- **What's in v1:** Push-on-write, pull-on-launch, basic real-time listeners (Epic 13)
- **Assessment:** Keep; foundational for offline-first architecture (Epic 19)

### 10. **Scheduler Feature** (6,428 LOC, 44 files — largest!) ⚠️ **MOSTLY IN SCOPE, AUDIT FOR EPIC 22**
- **Status:** Core v1 feature but check for catch-up/amnesty work
- **Location:** `lib/features/scheduler/`
- **What's in v1:** Daily task generation, goal management, three schedule types (delay, Friday/Shabbos, Shabbos) (Epic 6)
- **What's out of scope:**
  - Catch-up/amnesty logic (Epic 22 — explicitly backlog, 22 stories planned)
  - Recovery actions or amnesty primitives
  - Cycle boundary logic
  - Advanced rescoping
- **Files mentioning catch-up/recovery:** Found scattered in codebase (see audit section below)
- **Recommendation:** Audit carefully for any Epic 22 code mixed in

### 11. **Learning Feature** (3,976 LOC, 30 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature
- **Location:** `lib/features/learning/`
- **What's in v1:** Mark completion, completion history, stage progression (Epic 3)
- **Note:** Has dependencies on gamification — will need cleanup if gamification removed
- **Assessment:** Keep; core feature

### 12. **Content Browsing Feature** (3,816 LOC, 20 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature
- **Location:** `lib/features/content_browsing/`
- **What's in v1:** Hierarchical browser, text display (Hebrew/English), content search (Epic 2)
- **Assessment:** Keep; core feature

### 13. **Track Setup Feature** (4,553 LOC, 12 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature
- **Location:** `lib/features/track_setup/`
- **What's in v1:** Track creation, curriculum selection, program selection, track editing, multi-track (Epics 1, 4, 18)
- **Note:** School/tutor tracks defined in enum but not promoted in v1 UI
- **Assessment:** Keep; core feature

### 14. **Onboarding Feature** (5,293 LOC, 17 files) ✅ **IN SCOPE (EPIC 18 IN REVIEW)**
- **Status:** Core v1 feature, actively being updated
- **Location:** `lib/features/onboarding/`
- **What's in v1:** Welcome, mode selection, curriculum selection, goal setup, bulk mark prior completions, initial rewards (Epics 9, 16, 18)
- **Note:** Epic 18 (12 stories) currently in review — do not remove code it depends on
- **Assessment:** Keep; core feature; align with Epic 18 work

### 15. **Profiles Feature** (1,848 LOC, 11 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature (Epic 21)
- **Location:** `lib/features/profiles/`
- **What's in v1:** Account switching, multi-profile UI (child + parent), profile creation/deletion (Epic 21)
- **Assessment:** Keep; core feature; foundational for multi-account device support

### 16. **Auth Feature** (3,189 LOC, 20 files) ✅ **IN SCOPE**
- **Status:** Core v1 feature (Epic 23 just shipped)
- **Location:** `lib/features/auth/`
- **What's in v1:** Email/password + Google Sign-In, mandatory signup, hard-tier auth model (Epics 1, 23)
- **Note:** Epic 23 (hard-tier auth refactor) just shipped (2026-04-15) — code is canonical
- **Assessment:** Keep; foundational feature

---

## Out-of-Scope Code Audit Results

### 🔴 Definite Out-of-Scope Code Found

**1. Recovery Action Button** (dashboard feature)
- **File:** `lib/features/dashboard/presentation/widgets/track_card/recovery_action_button.dart`
- **Purpose:** Shows "Jump to today" and "Reset pace" recovery actions below track card
- **Status:** Out of scope (Epic 22 — backlog)
- **Action:** Remove this file and any code that uses it

**2. Gamification Imports in Core Learning Path**
- **Files affected:**
  - `lib/features/learning/data/repositories/completion_repository_impl.dart` — imports gamification
  - `lib/features/learning/presentation/screens/learning_screen.dart` — imports gamification
  - `lib/features/dashboard/presentation/providers/dashboard_providers.dart` — imports gamification
- **Issue:** Gamification is deeply coupled with learning/dashboard; removal requires refactoring
- **Action:** If removing gamification, decouple these dependencies

### ⚠️ Potential Out-of-Scope Code (Requires Verification)

**1. Streak Recovery System**
- **File:** `lib/features/gamification/domain/models/streak_recovery_info.dart`
- **Status:** Part of gamification feature (out of scope)
- **Action:** Remove if removing gamification; verify no other code depends on it

**2. Curriculum Settings Screen**
- **File:** `lib/features/settings/presentation/screens/curriculum_settings_screen.dart`
- **Purpose:** Allows customizing stage definitions and learning order per curriculum
- **Status:** Unclear if v1 or v2 (advanced configuration)
- **Action:** Audit — likely v2 feature

**3. Track Card Recovery Actions**
- **Location:** `lib/features/dashboard/presentation/widgets/track_card/` directory
- **Files:** All files modified 2026-04-15 onwards might contain Epic 20 code
- **Action:** Audit all files in this directory for Epic 20 (backlog) code

---

## Recommended Actions for v1 Simplification

### Must Remove (Breaking Change)
1. **Gamification Feature** → 9 files, 1,037 LOC
   - Remove `lib/features/gamification/` entirely
   - Decouple from learning & dashboard
   - Update app_router.dart to remove gamification route
   - Update pubspec.yaml to remove unused dependencies (if any)

### Should Remove (v2 Candidate)
2. **Recovery Action Button** → 1 file, ~60 LOC
   - Remove `lib/features/dashboard/presentation/widgets/track_card/recovery_action_button.dart`
   - Remove any code that instantiates this widget

3. **Learning Order Configuration Screen** → 9 files, 772 LOC
   - Remove from onboarding (if present)
   - Keep DAO & domain logic (used by scheduler)
   - Remove UI: `learning_order/presentation/screens/`

4. **Stages Configuration Screen** → Partial removal
   - Keep stage definitions & defaults
   - Remove advanced configuration UI: `stages/presentation/screens/`
   - Keep DAO, domain, validators (used by scheduler)

### Should Audit (Possible v2)
5. **Advanced Settings** → Partial feature
   - `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` — likely v2
   - Keep basic settings (notifications, account deletion, theme)

6. **Dashboard Track Cards** → Audit for Epic 20
   - Verify no multi-track isolation code
   - Verify no per-track stats variant cards
   - Remove any recovery actions (already found one)

7. **Progress Charts** → Audit for Epic 20
   - Verify no per-track filtering
   - Verify no advanced drill-down features
   - Keep basic curriculum progress view

---

## Feature Matrix: v1 Required vs Optional

| Feature | LOC | Files | v1 Status | Cleanup Required |
|---------|-----|-------|-----------|------------------|
| Auth | 3,189 | 20 | ✅ Required | No |
| Profiles | 1,848 | 11 | ✅ Required | No |
| Content Browsing | 3,816 | 20 | ✅ Required | No |
| Learning | 3,976 | 30 | ✅ Required | Decouple gamification |
| Scheduler | 6,428 | 44 | ✅ Required | Audit for Epic 22 |
| Track Setup | 4,553 | 12 | ✅ Required | No |
| Dashboard | 5,537 | 36 | ✅ Required (core) | Remove recovery actions; audit Epic 20 |
| Progress | 5,529 | 30 | ✅ Required (core) | Audit for Epic 20 |
| Onboarding | 5,293 | 17 | ✅ Required | Align with Epic 18; remove learning_order UI |
| Notifications | 2,212 | 8 | ✅ Required | No |
| Sync | 4,150 | 16 | ✅ Required | No |
| Settings | 4,003 | 17 | ✅ Required | Remove curriculum_settings_screen |
| Parent Mode | 2,291 | 17 | ✅ Required (child mode) | Audit for advanced analytics |
| Gamification | 1,037 | 9 | ❌ Remove | **REMOVE ENTIRELY** |
| Learning Order | 772 | 9 | ⚠️ Optional | Remove UI; keep DAO |
| Stages | 830 | 9 | ⚠️ Optional | Remove settings UI; keep defaults |
| **TOTAL** | ~54k | 309 | — | — |



---

## Next Steps

### Phase 1: Quick Wins (Easy Removals)
1. Delete `lib/features/gamification/` folder entirely (~1k LOC, decouples learning)
2. Delete `lib/features/dashboard/presentation/widgets/track_card/recovery_action_button.dart` (~60 LOC)
3. Remove gamification route from `lib/core/navigation/app_router.dart`
4. Delete `lib/features/learning_order/presentation/screens/` folder (UI only, ~400 LOC)
5. Delete `lib/features/stages/presentation/screens/` folder (UI only, ~300 LOC)

### Phase 2: Careful Decoupling (Requires Testing)
1. Remove gamification imports from:
   - `lib/features/learning/data/repositories/completion_repository_impl.dart`
   - `lib/features/learning/presentation/screens/learning_screen.dart`
   - `lib/features/dashboard/presentation/providers/dashboard_providers.dart`
2. Remove `settings/presentation/screens/curriculum_settings_screen.dart` (if not used by v1)
3. Audit and cleanup recovery action code in dashboard track cards

### Phase 3: Verification
1. Run `make test-all-stories` after each phase to ensure no breakage
2. Run `make ci` (analyze + format + tests) to ensure clean codebase
3. Verify Epic 18 in-review stories still pass after changes
4. Check git blame on modified files to ensure no recent feature work is broken

---

## Reference: Epics Status

| Epic | Title | Status | v1 Decision |
|------|-------|--------|-----------|
| 1 | Foundation & Infrastructure | Done | ✅ Keep (foundational) |
| 2 | Content Import & Browsing | Done | ✅ Keep (core feature) |
| 3 | Core Learning Cycle | Done | ✅ Keep (core feature) |
| 4 | Multi-Track Learning | Done | ✅ Keep (core feature) |
| 5 | Configurable Stages & Learning Order | Done | ⚠️ Keep defaults, remove UI |
| 6 | Smart Scheduler | Done | ✅ Keep (core feature) |
| 7 | Dashboard & Progress | Done | ✅ Keep (core feature, audit Epic 20 code) |
| 8 | Gamification & Engagement | Done | ❌ Remove entirely (v2 feature) |
| 9 | Onboarding Flow | Done | ✅ Keep (core feature, audit with Epic 18) |
| 10 | Parent Mode | Done | ✅ Keep (child mode required, audit analytics) |
| 11 | Tutor Mode | Done | ❌ Deprioritized (not promoted in v1, keep code for now) |
| 12 | Notifications | Done | ✅ Keep (core feature) |
| 13 | Cloud Sync | Done | ✅ Keep (foundational) |
| 14 | Settings | Done | ✅ Keep (core feature, audit advanced settings) |
| 15 | Multi-Profile & Learning Program | — | Absorbed into 18 & 21 |
| 16 | Onboarding-to-Dashboard Perfect Flow | Done | ✅ Keep (v1 flow refinement) |
| 17 | V1 Roadmap Phase 1 | Ongoing | 📍 Tracking umbrella |
| 18 | Onboarding & Track Management Overhaul | **In Review** | 📍 **Do not remove code it depends on** |
| 19 | Offline-First Architecture & Two-Database Split | Done | ✅ Keep (foundational) |
| 20 | Dashboard & Progress Redesign | Backlog | ❌ Remove related code if found |
| 21 | Multi-Account Device | Done | ✅ Keep (foundational) |
| 22 | Catch-up & Amnesty System | Backlog | ❌ Remove any code found |
| 23 | Offline-First Architecture v2 — Hard-Tier Auth Refactor | Done | ✅ Keep (just shipped, canonical) |

---

## Notes for v1 Focus

- **Handbook date:** 2026-04-19
- **Project status last synced:** 2026-04-19
- **Audit date:** 2026-04-21
- **Epic 18 status:** 12 stories currently in review — **do not remove code these depend on**
- **Epic 20 status:** Explicitly backlog (12 stories, dashboard redesign) — **identify and remove any code from this epic**
- **Epic 22 status:** Explicitly backlog (22 stories, catch-up/amnesty) — **identify and remove any code from this epic**
- **Tutor mode:** Deprioritized but code remains; not promoted in v1 onboarding; safe to leave as-is
- **School/tutor track types:** Defined in enum but not promoted in UI (TrackType enum only has `.personal`)

