---
project_name: "Learning Tracker"
document_type: "Development Handoff"
author: "Mimir (Orchestrator)"
date: "2026-02-08"
version: "1.0"
status: "Ready for Implementation"
---

# Learning Tracker - Development Handoff Package

**Purpose:** Complete handoff from design to development with everything needed to begin implementation.

**Target:** Flutter developers implementing Learning Tracker v1.0 for Android

**Status:** ✅ All planning artifacts complete - ready to code!

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Planning Artifacts Summary](#planning-artifacts-summary)
3. [Implementation Roadmap](#implementation-roadmap)
4. [Epic Implementation Order](#epic-implementation-order)
5. [Developer Quick Start](#developer-quick-start)
6. [Testing Strategy](#testing-strategy)
7. [Critical Success Factors](#critical-success-factors)
8. [FAQ for Developers](#faq-for-developers)

---

## Project Overview

### What We're Building

**Learning Tracker** is a multi-curriculum Torah learning Android app that transforms large-scale learning goals into achievable daily habits.

**Core Value Proposition:**
- Track learning across 5 Sefaria-sourced curricula (Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash)
- Configurable N-stage learning cycles (learn + chazara stages with user-defined timing)
- Per-curriculum adaptive scheduling with cross-curriculum daily planning
- Multi-track learning (personal/school/tutor per curriculum)
- Child mode (full gamification) + Adult mode (streamlined)
- Account-based multi-device sync with offline-first operation

### Target Users

- **Primary (Children 10-13):** Bar mitzvah-age learners needing daily engagement and motivation
- **Primary (Adults):** Self-directed Torah learners pursuing goals across curricula
- **Secondary (Parents):** Minimal-effort oversight for child accounts
- **Supporting (Tutors):** Read-only progress visibility

### Technical Summary

- **Platform:** Flutter 3.38.6 / Dart 3.9.0, Android API 21+
- **Architecture:** Clean architecture, 15 feature modules, feature-first organization
- **State:** Riverpod with family providers for curriculum scoping
- **Database:** drift (SQLite) local + Cloud Firestore sync
- **Navigation:** auto_route 11.x with auth/PIN guards
- **Design:** Material Design 3, RTL Hebrew support, Noto Sans Hebrew fonts

### Scope

**MVP v1.0:** All 14 epics (60 stories) are required for launch. No phased rollout.

**Post-MVP:** iOS, dark mode, advanced analytics, curriculum marketplace, social features

---

## Planning Artifacts Summary

All planning work is complete and available in [`_bmad-output/planning-artifacts/`](_bmad-output/planning-artifacts/):

### 1. Product Brief
**File:** [product-brief-mishnayos-tracker-2026-01-03.md](product-brief-mishnayos-tracker-2026-01-03.md)

**Contains:**
- Product vision and target users
- Success criteria and milestones
- MVP scope definition
- User journeys (4 complete journeys)

**Key Takeaway:** Child + adult dual-mode app serving Orthodox Jewish Torah learners with intelligent multi-curriculum tracking.

### 2. Product Requirements Document (PRD)
**File:** [prd.md](prd.md)

**Contains:**
- 113 Functional Requirements (FR1-FR113)
- 47 Non-Functional Requirements (NFR1-NFR47)
- Complete feature specifications
- Mobile app-specific requirements
- Calendar & date management (Jewish calendar primary)

**Key Takeaway:** Comprehensive requirements covering all 14 epics with offline-first, multi-device sync, and cultural sensitivity (Hebrew text, Shabbos awareness).

### 3. Architecture Decision Document
**File:** [architecture.md](architecture.md)

**Contains:**
- 8 Critical Architectural Decisions (D1-D8)
- 6 Implementation Patterns (P1-P6)
- Complete project structure (15 feature modules)
- Database schema design
- Integration patterns (Sefaria, Firebase, kosher_dart)

**Quick Reference:** [architecture-quick-reference.md](architecture-quick-reference.md)

**Key Decisions:**
- **D1:** Shared `content_items` table with generic hierarchy (level_1/2/3/4)
- **D2:** Email/password + Google Sign-In authentication
- **D3:** Separate `stage_definitions` table (configurable N-stage engine)
- **D4:** Hybrid sync (push-on-write + pull-on-launch + foreground listeners)
- **D5:** User mode as profile enum field (child/adult) with feature flags
- **D6:** Per-curriculum Sefaria API adapters with common interface
- **D7:** Separate `learning_order` table (content immutable, order customizable)
- **D8:** Per-curriculum points + global streak

### 4. UX Design Specification
**File:** [ux-design-specification.md](ux-design-specification.md)

**Contains:**
- Complete design system (Material 3 foundation)
- Curriculum identity colors (5 distinct colors)
- Typography system (Noto Sans Hebrew + Latin)
- Spacing, elevation, and layout tokens
- User experience principles
- Emotional design goals (child vs adult modes)
- Accessibility guidelines (WCAG AA)

**Quick Reference:** [ux-patterns-quick-reference.md](ux-patterns-quick-reference.md)

**Key Principle:** "Show me what to do now" - daily tasks are the hero screen, zero-thought actions.

### 5. Component Specifications
**File:** [component-specifications.md](component-specifications.md)

**Contains:**
- Complete design token definitions
- 6 base components (buttons, cards, progress bars, PIN keypad, date picker, bottom sheet)
- 11 Learning Tracker-specific components (curriculum cards, task cards, Hebrew text, streak counter, etc.)
- Feature module component mapping
- Flutter implementation specs with code examples
- Cultural design constraint: all illustrations depict boys/men

**Key Components:**
- Curriculum Summary Card (dashboard)
- Daily Task Card (scheduled completions)
- Hebrew Text Display (RTL support)
- Hierarchy Browser (up to 4 levels)
- Dual Date Picker (Gregorian + Hebrew)

---

## Implementation Roadmap

### v1.0 MVP Scope: 14 Epics, 60 Stories

All epics are required for v1.0 launch. Implementation follows dependency order (see next section).

| Epic | Stories | Complexity | Duration Est. |
|---|---|---|---|
| 1. Foundation & Infrastructure | 12 | High | 3-4 weeks |
| 2. Content Import & Browsing | 4 | Medium | 1-2 weeks |
| 3. Core Learning Cycle | 3 | Medium | 1 week |
| 4. Multi-Track Learning | 3 | Medium | 1 week |
| 5. Configurable Stages & Order | 2 | Medium | 1 week |
| 6. Smart Scheduler | 5 | High | 2 weeks |
| 7. Dashboard & Progress | 3 | Medium | 1 week |
| 8. Gamification | 3 | Medium | 1 week |
| 9. Onboarding | 5 | Medium | 1-2 weeks |
| 10. Parent Mode | 6 | Medium | 1-2 weeks |
| 11. Tutor Mode | 4 | Low | 1 week |
| 12. Notifications | 3 | Low | 1 week |
| 13. Cloud Sync | 3 | High | 1-2 weeks |
| 14. Settings | 4 | Low | 1 week |
| **Total** | **60** | | **16-22 weeks** |

**Note:** Estimates assume 1-2 developers working full-time. Adjust for team size and velocity.

### Milestones

**Milestone 1: Foundation Complete (Week 4)**
- Epic 1 done: project initialized, auth working, database schema implemented, basic nav
- Can sign in, see empty dashboard
- **Risk mitigation:** All infrastructure blockers resolved early

**Milestone 2: Core Loop Working (Week 8)**
- Epics 2, 3, 6 done: can import content, mark completions, see daily tasks
- Basic learning flow operational
- **Validation:** User can complete full learning cycle

**Milestone 3: Full Feature Set (Week 16)**
- All 14 epics complete
- All 113 FRs implemented
- Ready for internal testing

**Milestone 4: Launch Ready (Week 20-22)**
- Testing, bug fixes, polish
- APK signed and ready for distribution
- Documentation complete

---

## Epic Implementation Order

### Phase 1: Foundation (Weeks 1-4)

**Epic 1: Foundation & Infrastructure** ✅ MUST BE FIRST
- Story 1.1: Initialize Flutter project with architecture
- Story 1.2: Set up drift database with all tables
- Story 1.3: Configure Firebase (Auth + Firestore)
- Story 1.4: Implement auto_route navigation with guards
- Story 1.5: Set up Riverpod state management
- Story 1.6: Configure Talker logging
- Story 1.7: Set up CI/CD pipeline (GitHub Actions)
- Story 1.8: Implement Material 3 theme with RTL support
- Story 1.9: Set up secure storage (PINs)
- Story 1.10: Implement Hebrew calendar utilities (kosher_dart)
- Story 1.11: Create base component library
- Story 1.12: Set up testing infrastructure

**Dependencies:** None - this is the foundation for everything else

**Validation:**
- [ ] Project builds and runs on Android device
- [ ] Can navigate between placeholder screens
- [ ] Database initializes without errors
- [ ] Firebase connection established
- [ ] Theme displays correctly with Hebrew text
- [ ] All tests pass

---

### Phase 2: Core Learning Loop (Weeks 5-9)

**Epic 2: Content Import & Browsing**
- Story 2.1: Implement Sefaria API client with curriculum adapters
- Story 2.2: Create content import pipeline (all 5 curricula)
- Story 2.3: Build generic hierarchy browser
- Story 2.4: Implement content text display (Hebrew + English)

**Epic 3: Core Learning Cycle**
- Story 3.1: Implement mark completion with transaction safety
- Story 3.2: Create completion history with filters
- Story 3.3: Implement bookmark management with auto-advancement

**Epic 6: Smart Scheduler** (moved up - needed for daily tasks)
- Story 6.1: Implement parametric scheduler engine
- Story 6.2: Create daily task generation
- Story 6.3: Build goal management with Hebrew dates
- Story 6.4: Implement pace tracking
- Story 6.5: Create cross-curriculum schedule composer

**Dependencies:**
- Epic 2 requires: Epic 1 (database, network, state)
- Epic 3 requires: Epic 1, Epic 2 (content must exist)
- Epic 6 requires: Epic 1, Epic 2, Epic 3 (completions + content)

**Validation:**
- [ ] Can import all 5 curricula from Sefaria
- [ ] Can browse hierarchy and view Hebrew text
- [ ] Can mark item as complete (learn stage)
- [ ] Completion appears in history
- [ ] Bookmark advances automatically
- [ ] Daily tasks generate correctly
- [ ] Scheduler adapts to completions

---

### Phase 3: Multi-Curriculum Features (Weeks 10-13)

**Epic 7: Dashboard & Progress**
- Story 7.1: Create cross-curriculum dashboard
- Story 7.2: Build per-curriculum progress views
- Story 7.3: Implement progress charts

**Epic 4: Multi-Track Learning**
- Story 4.1: Implement track management per curriculum
- Story 4.2: Create track assignment with duplicate prevention
- Story 4.3: Build track-specific progress views

**Epic 5: Configurable Stages & Order**
- Story 5.1: Create stage definition editor
- Story 5.2: Implement drag-and-drop learning order

**Epic 8: Gamification**
- Story 8.1: Implement per-curriculum points system
- Story 8.2: Create global streak tracking
- Story 8.3: Build mystery rewards system

**Dependencies:**
- All require: Epic 1, 2, 3, 6 (core loop working)

**Validation:**
- [ ] Dashboard shows all active curricula
- [ ] Can add/remove school and tutor tracks
- [ ] Can customize stage definitions per curriculum
- [ ] Can drag-and-drop learning order
- [ ] Points accumulate on completion
- [ ] Streak increments daily
- [ ] Mystery rewards progress toward thresholds

---

### Phase 4: User Modes & Onboarding (Weeks 14-16)

**Epic 9: Onboarding**
- Story 9.1: Create welcome and mode selection
- Story 9.2: Build curriculum selection with import
- Story 9.3: Implement per-curriculum goal setup
- Story 9.4: Create bulk mark prior completions
- Story 9.5: Build initial rewards setup (child mode)

**Epic 10: Parent Mode**
- Story 10.1: Implement PIN setup and authentication
- Story 10.2: Create parent dashboard with analytics
- Story 10.3: Build reward management (CRUD)
- Story 10.4: Implement point value configuration
- Story 10.5: Create track management UI
- Story 10.6: Build parent analytics views

**Epic 11: Tutor Mode**
- Story 11.1: Implement tutor PIN setup
- Story 11.2: Create read-only tutor dashboard
- Story 11.3: Build completion history view for tutors
- Story 11.4: Implement chazara queue display

**Dependencies:**
- Epic 9 requires: All previous epics (onboarding is the entry point)
- Epic 10 requires: Epic 1, 8 (gamification must exist for child mode)
- Epic 11 requires: Epic 1, 3 (completions and history)

**Validation:**
- [ ] New user completes full onboarding flow
- [ ] Child mode shows gamification, parent mode available
- [ ] Adult mode hides parent mode, shows self-management
- [ ] Parent can enter with PIN and manage rewards
- [ ] Tutor can view progress read-only

---

### Phase 5: Polish & Production (Weeks 17-22)

**Epic 12: Notifications**
- Story 12.1: Implement daily learning reminders
- Story 12.2: Create streak protection alerts
- Story 12.3: Build reward milestone notifications

**Epic 13: Cloud Sync**
- Story 13.1: Implement push-on-write with offline queue
- Story 13.2: Create pull-on-launch merge logic
- Story 13.3: Set up foreground real-time listeners

**Epic 14: Settings**
- Story 14.1: Build general settings and user profile
- Story 14.2: Implement notification preferences
- Story 14.3: Create data export/import (JSON)
- Story 14.4: Build account management (delete, password change, provider linking)

**Dependencies:**
- Epic 12 requires: Epic 1, 3, 8 (completions and streaks)
- Epic 13 requires: Epic 1 (Firebase, database)
- Epic 14 requires: All epics (settings ties everything together)

**Validation:**
- [ ] Notifications fire at configured times
- [ ] Data syncs across devices correctly
- [ ] Conflict resolution works (additive merge, last-write-wins)
- [ ] Can export all data to JSON
- [ ] Can delete account (Firebase + Firestore cleanup)
- [ ] All settings persist correctly

---

## Developer Quick Start

### Prerequisites

```bash
# Required
flutter --version  # 3.38.6+
dart --version     # 3.9.0+
android --version  # SDK API 21+

# Recommended
git --version
```

### Initial Setup

```bash
# 1. Clone repository
git clone <repo-url>
cd learning_tracker

# 2. Install dependencies
flutter pub get

# 3. Copy config templates
cp config/dev.json.example config/dev.json
cp config/prod.json.example config/prod.json

# 4. Configure Firebase
# - Create Firebase project
# - Download google-services.json to android/app/
# - Update config files with Firebase credentials

# 5. Run code generation
dart run build_runner build --delete-conflicting-outputs

# 6. Verify setup
flutter doctor
flutter analyze
dart format --set-exit-if-changed .

# 7. Run on device
flutter run
```

### Project Structure Navigation

```
lib/
├── main.dart              # Entry point
├── app.dart               # MaterialApp + router setup
├── core/                  # Shared infrastructure
│   ├── database/          # Drift schema, DAOs
│   ├── navigation/        # auto_route config
│   ├── network/           # Sefaria API clients
│   ├── providers/         # Core providers
│   ├── services/          # Cross-curriculum services
│   ├── theme/             # Material 3 theme
│   └── widgets/           # Base components
└── features/              # 15 feature modules
    ├── auth/
    ├── onboarding/
    ├── content_browsing/
    ├── learning/
    ├── scheduler/
    ├── dashboard/
    ├── progress/
    ├── gamification/
    ├── parent_mode/
    ├── tutor_mode/
    ├── notifications/
    ├── settings/
    └── sync/
```

### Key Files to Start With

1. **Architecture overview:** [architecture-quick-reference.md](architecture-quick-reference.md)
2. **UX patterns:** [ux-patterns-quick-reference.md](ux-patterns-quick-reference.md)
3. **Component specs:** [component-specifications.md](component-specifications.md)
4. **Database schema:** `lib/core/database/tables/` (create based on architecture.md)
5. **Theme setup:** `lib/core/theme/app_theme.dart` (create based on UX spec)

### Development Workflow

```bash
# Daily workflow
flutter pub get                # Update dependencies
dart run build_runner watch    # Auto-generate code on file changes
flutter run                    # Hot reload enabled

# Before committing
dart format .                  # Format code
flutter analyze               # Static analysis
flutter test                  # Run all tests
git add . && git commit       # Commit with meaningful message
```

### Common Tasks

**Add a new feature module:**
1. Create folder: `lib/features/{feature_name}/`
2. Add layers: `data/`, `domain/`, `presentation/`
3. Follow clean architecture pattern (see existing modules)

**Add a new screen:**
1. Create in `presentation/screens/`
2. Add route to `lib/core/navigation/app_router.dart`
3. Add navigation guard if needed

**Add a new component:**
1. Create in `presentation/widgets/` (feature-specific) or `lib/core/widgets/` (shared)
2. Follow component specs in [component-specifications.md](component-specifications.md)
3. Write widget test

**Add a new database table:**
1. Create table class in `lib/core/database/tables/`
2. Add to `@DriftDatabase` annotation
3. Create DAO in `lib/core/database/daos/`
4. Run `dart run build_runner build --delete-conflicting-outputs`

---

## Testing Strategy

### Testing Pyramid

```
       /\
      /E2E\         ← 5% (Integration tests)
     /______\
    /        \
   / Widget   \     ← 30% (Component tests)
  /____________\
 /              \
/  Unit Tests    \   ← 65% (Business logic)
/__________________\
```

### Test Coverage Requirements

- **Unit tests:** All domain logic, repositories, services (target: 80%+ coverage)
- **Widget tests:** All components, screens (target: 70%+ coverage)
- **Integration tests:** Critical user flows (onboarding, learning cycle, sync)

### Testing Patterns

**1. Unit Tests (Repository/Service)**

```dart
// test/features/learning/data/repositories/completion_repository_test.dart
void main() {
  late CompletionRepositoryImpl repository;
  late MockCompletionDao mockDao;

  setUp(() {
    mockDao = MockCompletionDao();
    repository = CompletionRepositoryImpl(mockDao);
  });

  group('markComplete', () {
    test('should create completion and update bookmark in transaction', () async {
      // Arrange
      final completion = CompletionFixture.create();
      when(() => mockDao.insert(any())).thenAnswer((_) async => 1);

      // Act
      final result = await repository.markComplete(completion);

      // Assert
      expect(result, isA<Success>());
      verify(() => mockDao.insert(completion)).called(1);
    });
  });
}
```

**2. Widget Tests (Component)**

```dart
// test/features/dashboard/presentation/widgets/curriculum_card_test.dart
void main() {
  testWidgets('CurriculumSummaryCard displays correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CurriculumSummaryCard(
            curriculumId: CurriculumId.mishnayos,
            curriculumName: 'Mishnayos',
            completedItems: 1890,
            totalItems: 4192,
            progressPercent: 0.45,
            paceStatus: PaceStatus.ahead,
            daysDifference: 23,
            nextBookmark: 'Berachos 3:1',
          ),
        ),
      ),
    );

    expect(find.text('Mishnayos'), findsOneWidget);
    expect(find.text('1,890 / 4,192 items'), findsOneWidget);
    expect(find.text('23 days ahead'), findsOneWidget);

    // Golden test
    await expectLater(
      find.byType(CurriculumSummaryCard),
      matchesGoldenFile('goldens/curriculum_card_ahead.png'),
    );
  });
}
```

**3. Integration Tests (Flow)**

```dart
// integration_test/learning_cycle_test.dart
void main() {
  testWidgets('Complete learning cycle: import → browse → mark complete → see progress', (tester) async {
    await tester.pumpWidget(MyApp());

    // Import curriculum
    await tester.tap(find.text('Import Mishnayos'));
    await tester.pumpAndSettle();

    // Browse to item
    await tester.tap(find.text('Seder Zeraim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berachos'));
    await tester.pumpAndSettle();

    // Mark complete
    await tester.tap(find.text('Mark Complete'));
    await tester.pumpAndSettle();

    // Verify completion
    expect(find.text('✓ Complete'), findsOneWidget);
    expect(find.text('+10 pts'), findsOneWidget);  // Child mode points
  });
}
```

### Test Fixtures

Create reusable test data factories:

```dart
// test/fixtures/content_fixtures.dart
class ContentFixtures {
  static ContentItem mishnaBerakhot31() {
    return ContentItem(
      id: 1,
      curriculumId: 'mishnayos',
      level1: 'Seder Zeraim',
      level2: 'Berachos',
      level3: 'Perek 3',
      level4: 'Mishna 1',
      displayNameHe: 'ברכות פרק ג משנה א',
      displayNameEn: 'Berachos 3:1',
      sefariaRef: 'Mishnah Berakhot 3:1',
      sortOrder: 301,
    );
  }
}
```

### CI/CD Test Pipeline

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.6'

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze

      - name: Format check
        run: dart format --set-exit-if-changed .

      - name: Unit tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## Critical Success Factors

### Technical Excellence

**1. Data Integrity (Non-Negotiable)**
- Zero data loss - append-only completion log
- Transaction safety - all writes use drift transactions
- Multi-device sync consistency - test extensively
- **Validation:** Run sync stress tests with concurrent device writes

**2. Performance Targets**
- App startup: <2 seconds to usable state
- Scheduler calculation: <500ms across all curricula
- Database queries: <100ms with thousands of completions
- 60fps rendering on mid-range devices
- **Validation:** Profile on real mid-range Android device (not emulator)

**3. Offline-First Reliability**
- All core features work without network
- Sync queue persists through app restarts
- Graceful degradation when offline
- **Validation:** Test entire learning cycle in airplane mode

### User Experience

**4. Daily Task Flow (Make-or-Break)**
- Dashboard loads instantly with tasks
- Single tap marks complete (no confirmation dialogs)
- Smooth animations (child mode) without blocking
- **Validation:** 5-second rule - user can start learning within 5s of opening app

**5. Hebrew Text & RTL**
- All Hebrew text renders correctly
- BiDi text (Hebrew + English) displays properly
- RTL layout doesn't break on any screen
- **Validation:** Test every screen with Hebrew content

**6. Mode Differentiation (Child vs Adult)**
- Child mode feels celebratory and engaging
- Adult mode feels calm and professional
- No leakage between modes (parent mode only for child accounts)
- **Validation:** User testing with both age groups

### Cultural Sensitivity

**7. Orthodox Jewish Standards**
- All illustrations depict boys/men (no girls/women)
- Shabbos/Yom Tov awareness (notification quiet mode)
- Hebrew calendar primary (kosher_dart verified against authoritative sources)
- **Validation:** Review with Orthodox Jewish users

---

## FAQ for Developers

### Q: Which epic should I implement first?
**A:** Epic 1 (Foundation) MUST be first. It's the foundation for everything else. After that, follow the phased approach in "Epic Implementation Order" section.

### Q: How do I handle curriculum-specific logic?
**A:** Use family providers with `curriculumId` parameter. See Pattern P3 in [architecture-quick-reference.md](architecture-quick-reference.md). Never hardcode curriculum logic.

### Q: What's the difference between child and adult modes?
**A:** Simple enum field on user profile. Use `if (userMode == UserMode.child)` conditionals for UI differences. See [ux-patterns-quick-reference.md](ux-patterns-quick-reference.md) for specific patterns.

### Q: How do I test multi-device sync?
**A:** Run app on 2 devices/emulators simultaneously with same account. Make changes on one, verify they appear on the other. Test offline queue by going offline, making changes, then reconnecting.

### Q: Where do Hebrew dates come from?
**A:** All dates stored as UTC. Convert to Hebrew dates at display time using `kosher_dart`. See `lib/core/utils/hebrew_calendar_utils.dart` (to be created).

### Q: How do I add a new curriculum?
**A:** Update `CurriculumId` enum (P1), add Sefaria fetcher adapter (D6), add curriculum color to theme. The polymorphic content model handles the rest.

### Q: What if a story seems too big?
**A:** Break it down into tasks. Most stories in Epic 1 can be split into 2-4 tasks. Document sub-tasks in Linear/Jira as you work.

### Q: When should I write tests?
**A:** TDD approach: Write test first (red), implement feature (green), refactor (clean). At minimum, write tests alongside implementation, not after.

### Q: How do I handle errors in repositories?
**A:** Return `T?` for not-found (single items), `List<T>` (empty) for no results. Let exceptions bubble for infrastructure failures. See P2 in architecture doc.

### Q: What's the source of truth for design decisions?
**A:** Architecture document > UX Design spec > Component specs > Code. If code contradicts docs, docs win (or update docs if they're wrong).

---

## Next Steps

### Immediate Actions (Before Coding)

1. ✅ Review all planning artifacts (you're doing this now!)
2. ⏭️ Set up development environment (prerequisites, tools)
3. ⏭️ Initialize project with Epic 1, Story 1.1
4. ⏭️ Create team workspace (Linear, Slack, GitHub)
5. ⏭️ Schedule sprint planning (2-week sprints recommended)

### First Sprint Goals

**Sprint 1 (Weeks 1-2):**
- Complete Story 1.1-1.4 (project setup, database, Firebase, navigation)
- Goal: Can sign in and navigate to empty dashboard
- Definition of Done: All tests pass, code reviewed, deployed to test device

**Sprint 2 (Weeks 3-4):**
- Complete Story 1.5-1.12 (remaining Epic 1 stories)
- Goal: All infrastructure in place, base components working
- Definition of Done: Milestone 1 achieved - foundation complete

### Long-Term Success

- **Week 8:** Milestone 2 - core loop working (can learn daily)
- **Week 16:** Milestone 3 - all features complete
- **Week 20-22:** Milestone 4 - launch ready

---

## Document Index

**Planning Artifacts:**
1. [Product Brief](product-brief-mishnayos-tracker-2026-01-03.md) - Vision & users
2. [PRD](prd.md) - All requirements (113 FRs, 47 NFRs)
3. [Architecture](architecture.md) - Technical decisions & structure
4. [Architecture Quick Reference](architecture-quick-reference.md) - Developer guide
5. [UX Design Specification](ux-design-specification.md) - Complete design system
6. [UX Patterns Quick Reference](ux-patterns-quick-reference.md) - Implementation patterns
7. [Component Specifications](component-specifications.md) - All UI components
8. **This Document** - Development handoff

**Epic & Story Breakdown:**
- See README.md for epic summary table
- Detailed stories will be created in Linear/Jira as implementation progresses

---

## Sign-Off

**Design Team:** ✅ All planning artifacts complete and approved
**Architecture Team:** ✅ Technical design validated and documented
**Product Team:** ✅ Requirements finalized, ready for implementation

**Status:** 🚀 **READY TO CODE**

**Questions?** Reference this document and linked artifacts. For clarifications, consult original planning documents or raise questions in team channel.

---

**Good luck building Learning Tracker! May your code be bug-free and your tests all pass. 📚✡️**
