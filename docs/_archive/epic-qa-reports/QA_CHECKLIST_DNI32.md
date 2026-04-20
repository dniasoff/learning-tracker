# QA Checklist for DNI-32: Content Hierarchy Browsing

## Pre-Test Setup

### 1. Code Generation (REQUIRED)
```bash
cd learning_tracker
dart run build_runner build --delete-conflicting-outputs
```

This will regenerate:
- `lib/core/navigation/app_router.gr.dart` (auto_route generated code)
- `lib/features/content_browsing/presentation/providers/content_providers.g.dart` (riverpod generated code)

### 2. Static Analysis
```bash
dart analyze
# Should pass with zero issues

dart format --set-exit-if-changed .
# Should produce no changes
```

## Unit Tests

### Run All Content Browsing Tests
```bash
flutter test test/features/content_browsing/
```

Expected to pass:
- `test/features/content_browsing/presentation/screens/curriculum_list_screen_test.dart`
- `test/features/content_browsing/presentation/screens/content_hierarchy_screen_test.dart`
- `test/features/content_browsing/presentation/widgets/breadcrumb_navigation_test.dart`
- `test/features/content_browsing/presentation/widgets/content_item_tile_test.dart`
- `test/features/content_browsing/integration/hierarchy_navigation_test.dart`

### Run All Existing Tests
```bash
flutter test
```

Expected: All pre-existing tests continue to pass (no regressions).

## Widget Tests

### Curriculum List Screen
- [ ] Displays all 5 curricula (Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash)
- [ ] Shows Hebrew and English names
- [ ] Displays item counts
- [ ] Shows appropriate icons for each curriculum
- [ ] Loading state displays correctly
- [ ] Error state displays correctly

### Content Hierarchy Screen
- [ ] Displays top-level items when navigating from curriculum list
- [ ] Breadcrumb navigation shows current position
- [ ] Hebrew names displayed with RTL directionality
- [ ] English names displayed as subtitles
- [ ] Container items show folder icon and chevron
- [ ] Leaf items show completion status icon
- [ ] Drill-down navigation works (tapping containers)
- [ ] Back button navigates to parent level
- [ ] Breadcrumb clicks navigate to selected level

### Breadcrumb Navigation
- [ ] Shows curriculum name as root
- [ ] Displays all levels with chevron separators
- [ ] Current level styled differently (bold, primary color)
- [ ] Previous levels are clickable with underline
- [ ] Scrolls horizontally for long breadcrumbs

### Content Item Tile
- [ ] Hebrew name as title with RTL
- [ ] English name as subtitle
- [ ] Folder icon for containers
- [ ] Unchecked icon for leaf items (placeholder)
- [ ] Chevron for containers
- [ ] Tap handler fires correctly

## Integration Tests

### Full Navigation Flow
```bash
flutter test test/features/content_browsing/integration/hierarchy_navigation_test.dart
```

- [ ] Navigate from curriculum list → hierarchy screen
- [ ] Drill down through multiple levels (4 levels for Mishnayos)
- [ ] Breadcrumb navigation allows jumping to parent levels
- [ ] Back button navigates correctly through hierarchy

### Performance Test
- [ ] List with 500+ items scrolls smoothly without frame drops
- [ ] `WidgetTester.pumpAndSettle()` completes without timeout

## Acceptance Tests (from Linear DNI-32)

### Unit Tests
- [ ] **AT1:** `ContentRepository.getContentForCurriculum(CurriculumId.mishnayos)` returns top-level items (6 Sedarim) with correct Hebrew and English names
- [ ] **AT2:** Querying children of a container item (e.g., Seder Zeraim) returns correct child items sorted by `sortOrder`
- [ ] **AT3:** Aggregate completion percentage for a container with 10 items, 3 fully completed, returns 30% (TODO: implement completion integration)
- [ ] **AT4:** Hierarchy config lookup returns correct level labels — "Seder" for level 1, "Masechta" for level 2, etc.

### Widget Tests
- [ ] **AT5:** Curriculum list screen renders all active curricula with icons and total item counts
- [ ] **AT6:** Breadcrumb trail updates correctly when navigating from Mishnayos → Seder Zeraim → Berachos and shows "Mishnayos > Seder Zeraim > Berachos"
- [ ] **AT7:** Leaf items display per-stage completion indicators (e.g., green check for learned, amber for chazara1 done) (TODO: implement)
- [ ] **AT8:** Back button at each hierarchy level navigates to the parent level, not the root
- [ ] **AT9:** List with 500+ items scrolls smoothly without frame drops (verified via `WidgetTester.pumpAndSettle`)

### Integration Tests
- [ ] **AT10:** Full drill-down flow: open curriculum list → tap Mishnayos → tap Seder Zeraim → tap Berachos → see list of Perakim → tap Perek 1 → see list of individual Mishnas
- [ ] **AT11:** Deactivating a curriculum via settings removes it from the curriculum list screen immediately (requires settings integration)

## Known TODOs / Follow-Up Work

### 1. Completion Status Integration
**Files to update:**
- `lib/features/content_browsing/presentation/widgets/content_item_tile.dart`
- Create provider for completion tracking per sefariaRef

**Implementation:**
- Query completions table for each content item's sefariaRef
- Calculate per-stage completion (learned, review, chazara)
- Calculate aggregate completion % for containers
- Use `StageCompletionIndicators` and `AggregateCompletionIndicator` widgets

### 2. Curriculum Deactivation Integration
**Requires:**
- Settings integration to filter active curricula
- Update CurriculumListScreen to watch curriculum activation state

### 3. Additional Edge Cases
- Handle empty content gracefully (no JSON file available)
- Handle malformed JSON data
- Network/asset loading errors

## Manual Testing Checklist

After automated tests pass, verify manually:

1. **Launch app** → Navigate to Browse screen
2. **Curriculum List:**
   - Verify all 5 curricula visible
   - Verify counts are accurate
   - Verify icons display correctly
3. **Mishnayos Hierarchy:**
   - Tap Mishnayos → see 6 Sedarim
   - Tap Seder Zeraim → see Masechtos
   - Tap Berachos → see Perakim
   - Tap Perek 1 → see individual Mishnas
4. **Navigation:**
   - Back button works at each level
   - Breadcrumb clicks work
   - Hebrew RTL alignment correct
5. **Performance:**
   - Scroll through large lists (Bavli with 5422 items)
   - Check for frame drops or jank
6. **Error Handling:**
   - Verify error states display correctly
   - Check loading states

## Definition of Done Verification

From Linear DNI-32:

- [ ] All acceptance criteria verified and checked off
- [ ] Unit tests for hierarchy data provider covering all 5 curricula
- [ ] Widget tests for curriculum list, hierarchy screen, and breadcrumb navigation
- [ ] Scroll performance test with 500+ items passes without jank
- [ ] `dart analyze` passes with zero issues
- [ ] `dart format` produces no changes
- [ ] Code reviewed and approved via PR (if using PR workflow)
- [ ] No unresolved TODO/FIXME comments (except documented follow-ups)
- [ ] P3 compliance: all browsing providers use `family(curriculumId)` pattern ✓
- [ ] Single generic `ContentHierarchyScreen` handles all curriculum depths ✓
- [ ] Content loaded via `ContentRepository` (in-memory JSON), not via DAO/SQLite queries ✓
- [ ] Feature branch merged to main (via Refinery or PR)
