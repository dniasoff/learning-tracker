# Story 15.7 — Enhanced Bulk Mark Tool (DNI-115)

## Story Overview

Replace the current onboarding-only `BulkMarkScreen` with a standalone, reusable Enhanced Bulk Mark feature. The current implementation lives at `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` and uses a drill-down navigation model with a single flat phase flow (selection -> stage selection -> confirmation -> processing -> done). It applies the same set of stages uniformly to all selections.

The enhanced version must:
- Be accessible from Settings at any time (not just onboarding)
- Be forceable during onboarding and when changing programs
- Support multi-select with checkboxes at every hierarchy level
- Allow per-selection stage assignment (different stages for different content groups)
- Include search with jump-to-result
- Handle 2,711+ items (Talmud Bavli) with virtualized scrolling

## Acceptance Criteria

### AC1: Standalone Access from Settings
- A "Mark Prior Completions" tile appears in the Settings screen under "More Settings"
- Tapping it shows a curriculum picker, then opens the Enhanced Bulk Mark screen for the chosen curriculum
- The screen works identically whether launched from Settings or onboarding

### AC2: Forced During Onboarding
- After curriculum import completes, the onboarding flow launches the Enhanced Bulk Mark screen (replacing the current `BulkMarkScreen`)
- The user cannot skip past it without explicitly tapping "Skip" or "Done"
- The onboarding flow continues to goal setup after bulk mark completes

### AC3: Forced on Program Change
- When a user activates a new curriculum via Settings toggle, offer to launch bulk mark for that curriculum
- When a user changes their active curriculum set, the bulk mark screen is presented for newly activated curricula

### AC4: Multi-Level Tree with Checkboxes
- Content displays as an expandable tree: Seder > Tractate > Perek > Daf/Mishna
- Each node has a checkbox that can be toggled independently
- Selecting a parent node auto-selects all children; deselecting a parent deselects all children
- Partially-selected parents show an indeterminate checkbox state
- "Select All" / "Deselect All" buttons at each visible level

### AC5: Per-Stage Marking
- After content selection, the stage assignment screen shows each selection group with its own stage picker
- Users can assign different stages to different selection groups
- Example: "Learn + Chazara 1 for Bava Kamma, only Learn for Bava Metzia"
- Default: all selections get stage 1 (Learn) pre-selected

### AC6: Search with Jump-to-Result
- A search bar (in AppBar or as a persistent field) filters the tree by `displayNameEn` and `displayNameHe`
- Matching nodes are highlighted in the tree
- Tapping a search result expands the tree to that node and scrolls to it
- Uses 300ms debounce (matching existing `ContentSearchScreen` pattern)

### AC7: Virtualized List Performance
- The tree list uses `ListView.builder` (already the pattern) or `CustomScrollView` with `SliverList`
- Smooth scrolling with 2,711+ items when a full seder is expanded
- Flattened tree model: only expanded nodes are in the list, so the item count stays manageable
- No frame drops on mid-range Android devices

### AC8: Progress Indicator
- During the processing phase, a progress bar shows `N / total` completions created
- Uses a stream or periodic setState to update in real-time as batch inserts proceed

### AC9: Back/Undo Support
- Physical back button and AppBar back arrow navigate up the phase flow (done -> confirmation -> stage assignment -> selection)
- Within the selection phase, back navigates up the tree (matching current behavior)
- A "Clear All Selections" button is available
- After bulk mark completes, an "Undo" option is available for 10 seconds (deletes the just-created completions)

### AC10: FittedBox AppBar Title
- The AppBar title wraps in `FittedBox` so long curriculum names (e.g., "Mark Prior Completions -- Talmud Yerushalmi") never truncate

## Screen Specifications

### Screen: EnhancedBulkMarkScreen

**Entry points:**
1. Settings > "Mark Prior Completions" > Curriculum Picker > This screen
2. Onboarding flow (after import, before goal setup)
3. Curriculum activation flow (after activating a new curriculum)

**Parameters:**
- `curriculumId: CurriculumId` (required)
- `mode: BulkMarkMode` enum: `{standalone, onboarding, programChange}`
  - `standalone`: shows "Done" button at end, pops with result
  - `onboarding`: shows "Skip" + "Continue", pops with `BulkMarkResult`
  - `programChange`: same as standalone but with contextual copy

**Phases (same as current, enhanced):**
1. **Selection Phase** -- expandable tree with multi-select
2. **Stage Assignment Phase** -- per-selection-group stage pickers
3. **Confirmation Phase** -- summary with item/stage counts
4. **Processing Phase** -- progress bar with real-time updates
5. **Done Phase** -- success message with undo option

### Widget: BulkMarkTreeView

The core tree widget used in the selection phase.

**State model:**
```
class TreeNodeState {
  final ContentItem item;
  final int depth;             // 0=seder, 1=tractate, 2=perek, 3=leaf
  final bool isExpanded;
  final CheckState checkState; // checked, unchecked, indeterminate
}

enum CheckState { checked, unchecked, indeterminate }
```

**Flattened list approach:**
- Maintain a `Map<String, TreeNodeState>` keyed by a composite key (level1/level2/level3/level4)
- When rendering, flatten only expanded nodes into a `List<TreeNodeState>` for the `ListView.builder`
- Expanding/collapsing a node inserts/removes its children from the flat list
- This keeps the rendered item count small even for large curricula

### Widget: StageAssignmentPanel

Shows each selection group (e.g., "Bava Kamma", "Bava Metzia") as a card with:
- The selection label (tractate/seder name)
- Count of leaf items in that selection
- A row of stage checkboxes (from `stageListProvider`)
- Auto-cascade: selecting stage N auto-selects stages 1..N (matching current behavior)

## Architecture & Design Notes

### Feature Location

Move from `lib/features/onboarding/` to a new top-level feature:

```
lib/features/bulk_mark/
  domain/
    models/
      bulk_mark_selection.dart       # SelectionGroup, StageAssignment
      bulk_mark_state.dart           # BulkMarkState (Freezed)
      tree_node.dart                 # TreeNode, CheckState
    services/
      bulk_mark_service.dart         # Extracted from BulkPriorCompletionService
  presentation/
    screens/
      enhanced_bulk_mark_screen.dart # Main screen (ConsumerStatefulWidget)
    widgets/
      bulk_mark_tree_view.dart       # Tree widget
      tree_node_tile.dart            # Individual row in tree
      stage_assignment_panel.dart    # Per-group stage picker
      bulk_mark_search_bar.dart      # Search field
    providers/
      bulk_mark_providers.dart       # Riverpod providers
      bulk_mark_providers.g.dart
  data/
    # Reuses existing ContentRepository and CompletionRepository
```

### Tree Widget Strategy

**Why not `TreeView` package?** The standard Flutter `ExpansionTile` is too heavy for 2,711 items because it renders all children even when collapsed. Instead, use a **flattened virtualized tree**:

1. Load all `ContentItem` records for the curriculum via `contentRepositoryProvider` (already cached in memory)
2. Build a tree structure in memory: `Map<String, List<ContentItem>>` grouped by level
3. Maintain `Set<String> expandedNodes` tracking which nodes are open
4. On each render, flatten the tree into a `List<TreeNodeState>` containing only visible nodes
5. Feed this flat list to `ListView.builder` -- only visible items are built

**Estimated visible item counts:**
- All collapsed: ~6 sedarim (Mishnayos) or ~6 sedarim (Bavli) = 6 items
- One seder expanded: ~10 tractates = ~16 items
- One tractate expanded: ~10 chapters = ~26 items
- One chapter expanded: ~10 leaves = ~36 items
- Worst case (all expanded): 2,711 for Bavli -- `ListView.builder` handles this fine

### Selection State Model

```dart
/// Tracks which items are selected at which granularity.
class SelectionModel {
  /// Explicitly checked nodes (by composite key).
  final Set<String> checkedNodes;

  /// Explicitly unchecked nodes within a checked parent.
  final Set<String> uncheckedNodes;

  /// Resolve whether a leaf is selected:
  /// Walk up from leaf to root. If any ancestor is in checkedNodes
  /// and no intermediate ancestor is in uncheckedNodes, it's selected.
  bool isLeafSelected(ContentItem leaf) { ... }

  /// Compute check state for a container:
  /// If all children selected -> checked
  /// If some children selected -> indeterminate
  /// If no children selected -> unchecked
  CheckState containerState(String compositeKey) { ... }
}
```

This is more efficient than the current approach of storing individual `HierarchySelection` objects for every selected node, because selecting "Seder Zeraim" stores one entry rather than hundreds.

### Per-Stage Assignment

Replace the current single `_selectedStageIds` set with a map:

```dart
/// Maps selection group key -> set of stage IDs.
/// e.g., {"Bava Kamma": {1, 2}, "Bava Metzia": {1}}
Map<String, Set<int>> stageAssignments;
```

Selection groups are derived from the highest-level checked nodes. If the user checks "Seder Nezikin" (level 1), the group is "Seder Nezikin". If they individually check "Bava Kamma" and "Bava Metzia" (level 2), those are two separate groups.

### Batch Insert Strategy

The current `bulkMarkComplete` iterates one-by-one inside a transaction. For 2,711 items x 3 stages = 8,133 inserts, this could take several seconds. Optimize:

1. **Batch the transaction**: use Drift's `batch` API instead of looping `_markCompleteSingleInTransaction`:
   ```dart
   await _database.batch((batch) {
     for (final ref in sefariaRefs) {
       batch.insert(database.completions, CompletionsCompanion.insert(...));
     }
   });
   ```
2. **Skip validation for bulk prior completions**: The prior completion flow marks everything as "already done" -- stage progression validation is unnecessary because we're inserting stages 1..N in order.
3. **Stream progress**: Yield progress events every 100 items so the UI can update the progress bar.
4. **Chunk into batches of 500**: Keeps memory pressure manageable and allows UI updates between chunks.

### Router Integration

Add a new route to `app_router.dart`:

```dart
AutoRoute(
  path: '/bulk-mark/:curriculumId',
  page: EnhancedBulkMarkRoute.page,
  guards: [authGuard],
),
```

### Backward Compatibility

- Keep `BulkMarkScreen` temporarily with a deprecation comment
- Update `OnboardingScreen._buildBulkMark` to launch `EnhancedBulkMarkScreen` with `mode: BulkMarkMode.onboarding`
- Update `BulkPriorCompletionService` to use the new batched insert path
- The `BulkMarkResult` return type remains the same

## Implementation Steps

### Step 1: Create Domain Models (0.5 day)
1. Create `lib/features/bulk_mark/domain/models/tree_node.dart` -- `TreeNode`, `CheckState` enum
2. Create `lib/features/bulk_mark/domain/models/bulk_mark_selection.dart` -- `SelectionModel`, `SelectionGroup`
3. Create `lib/features/bulk_mark/domain/models/bulk_mark_state.dart` -- `BulkMarkState` (Freezed) with phase, selections, stage assignments, progress

### Step 2: Create Service Layer (0.5 day)
1. Create `lib/features/bulk_mark/domain/services/bulk_mark_service.dart`
   - Extract and enhance logic from `BulkPriorCompletionService`
   - Add `resolveSelectionsToGroups()` that returns `List<SelectionGroup>` with leaf counts
   - Add `executeBatched()` that yields `Stream<BulkMarkProgress>` for real-time UI updates
   - Add `undoLastBulkMark()` that deletes completions created in the last run (by timestamp range)
2. Optimize `CompletionRepositoryImpl.bulkMarkComplete` to use Drift `batch` API

### Step 3: Create Tree Widget (1 day)
1. Create `lib/features/bulk_mark/presentation/widgets/tree_node_tile.dart`
   - Indentation based on depth (16px * depth)
   - Expand/collapse chevron for containers
   - Checkbox with three states
   - Hebrew + English display names
2. Create `lib/features/bulk_mark/presentation/widgets/bulk_mark_tree_view.dart`
   - Flattened list builder
   - Expand/collapse logic
   - Select all / deselect all per visible level
   - Manages `SelectionModel` state

### Step 4: Create Search (0.5 day)
1. Create `lib/features/bulk_mark/presentation/widgets/bulk_mark_search_bar.dart`
   - Reuse `contentSearchProvider` pattern with 300ms debounce
   - Search results overlay or inline filter
   - On result tap: expand tree path to that node, scroll to it using `ScrollController.animateTo`

### Step 5: Create Stage Assignment Panel (0.5 day)
1. Create `lib/features/bulk_mark/presentation/widgets/stage_assignment_panel.dart`
   - Card per selection group
   - Stage checkboxes from `stageListProvider`
   - Auto-cascade: checking stage N checks 1..N
   - "Apply to all" shortcut

### Step 6: Create Main Screen (1 day)
1. Create `lib/features/bulk_mark/presentation/screens/enhanced_bulk_mark_screen.dart`
   - `ConsumerStatefulWidget` with `BulkMarkMode` parameter
   - Phase flow matching current `_Phase` enum but enhanced
   - `FittedBox` AppBar title
   - `WillPopScope` / `PopScope` for back navigation between phases
   - Progress streaming during processing phase
   - Undo button on done phase (10s timer)

### Step 7: Create Providers (0.5 day)
1. Create `lib/features/bulk_mark/presentation/providers/bulk_mark_providers.dart`
   - `bulkMarkServiceProvider` (reuses content + completion repos)
   - `bulkMarkTreeStateProvider` (manages tree expand/collapse/selection state)

### Step 8: Router & Settings Integration (0.5 day)
1. Add `EnhancedBulkMarkScreen` to `app_router.dart` with `@RoutePage()` annotation
2. Add "Mark Prior Completions" `ListTile` to `settings_screen.dart` under "More Settings"
3. Add curriculum picker dialog before launching bulk mark from settings
4. Run `dart run build_runner build --delete-conflicting-outputs` for router codegen

### Step 9: Onboarding Integration (0.5 day)
1. Update `OnboardingScreen._buildBulkMark` to use `EnhancedBulkMarkScreen` with `mode: BulkMarkMode.onboarding`
2. Remove direct `BulkMarkScreen` import from onboarding
3. Deprecate old `BulkMarkScreen` (keep file, add `@Deprecated` annotation)

### Step 10: Curriculum Activation Integration (0.5 day)
1. Update `_CurriculumToggleTile` in `settings_screen.dart` to offer bulk mark after activating a new curriculum
2. Show a dialog: "Would you like to mark prior completions for [curriculum]?"
3. If yes, push `EnhancedBulkMarkRoute` with `mode: BulkMarkMode.programChange`

### Step 11: Testing (1 day)
1. Unit tests for `SelectionModel` (checked/unchecked/indeterminate logic)
2. Unit tests for `BulkMarkService` (batched insert, undo)
3. Widget tests for `BulkMarkTreeView` (expand/collapse, checkbox states)
4. Story acceptance tests (see Test Plan below)

## Dev Notes

### Performance with 2,711 Items

- **Memory**: All `ContentItem` records are already cached in `ContentRepositoryImpl` after first load. The tree adds ~100 bytes of state per node (composite key + booleans) = ~270 KB for Bavli. Negligible.
- **Rendering**: The flattened-list approach means `ListView.builder` only builds visible tiles (~15-20 at a time). Expanding a large seder (e.g., Seder Nezikin with 750+ dapim) flattens to 750 items, which `ListView.builder` handles without jank.
- **Selection resolution**: Walking the tree to resolve leaf items from a seder-level selection is O(n) where n = items in that seder (~500). This runs once on "Next" tap, not on every frame.

### Batch Insert Strategy

Current `bulkMarkComplete` does N individual inserts inside one transaction. For 2,711 x 3 stages:
- **Current**: ~8,100 individual INSERT + validation + bookmark advance = ~5-10 seconds
- **Optimized**: Drift `batch` API batches INSERTs into a single SQL statement per ~500 rows. Skip validation (prior completions don't need stage progression checks). Skip per-item bookmark advance (set bookmark once at end). Target: < 2 seconds.

Progress reporting: chunk into batches of 500, yield progress after each chunk.

### Key Existing Code to Reuse

| What | Where | How |
|------|-------|-----|
| Content hierarchy data | `contentRepositoryProvider` / `ContentRepository` | Load all items, build tree |
| Hierarchy config (level labels) | `curriculumHierarchyConfigProvider` | Display level names in tree |
| Content search | `contentSearchProvider` | Search with debounce |
| Stage list | `stageListProvider(curriculumId)` | Stage picker checkboxes |
| Bulk completion insert | `CompletionRepository.bulkMarkComplete` | Batch insert (optimize) |
| Bookmark setting | `BookmarkRepository.setBookmark` | Set after bulk mark |
| Breadcrumb widget | `BreadcrumbNavigation` | Could reuse for tree path display |
| Content item tile pattern | `ContentItemTile` | Reference for Hebrew/English display |

### Migration Path

The old `BulkMarkScreen` is only used in `OnboardingScreen._buildBulkMark` via a `Navigator.push`. The migration is:
1. Replace that push with the new `EnhancedBulkMarkScreen`
2. Keep `BulkMarkResult` class (move to shared location or keep in old file with export)
3. `BulkPriorCompletionService` is reused by the new service layer -- no breaking changes
4. `HierarchySelection` class can be deprecated in favor of `SelectionModel`

## Test Plan

### Unit Tests

**File: `test/features/bulk_mark/domain/models/selection_model_test.dart`**
- Selecting a parent marks all children as selected
- Deselecting a parent marks all children as deselected
- Partially selected children show parent as indeterminate
- Unchecking a child within a checked parent tracks the exception
- `resolveToLeafRefs()` correctly expands container selections to leaf sefariaRefs

**File: `test/features/bulk_mark/domain/services/bulk_mark_service_test.dart`**
- `resolveSelectionsToGroups()` returns correct group count and leaf counts
- `executeBatched()` creates correct number of completion records
- `executeBatched()` streams progress updates
- `undoLastBulkMark()` deletes only the completions from the last run
- Bookmark is set to first uncompleted item after bulk mark

### Widget Tests

**File: `test/features/bulk_mark/presentation/widgets/bulk_mark_tree_view_test.dart`**
- Tree renders collapsed by default (only top-level nodes visible)
- Tapping expand icon reveals children
- Checking a parent checkbox checks all visible children
- Unchecking one child shows parent as indeterminate
- "Select All" button at current level selects all visible nodes
- "Deselect All" button clears all selections at current level

**File: `test/features/bulk_mark/presentation/screens/enhanced_bulk_mark_screen_test.dart`**
- Screen shows correct title with `FittedBox`
- Selection phase -> Next button enabled only when selections exist
- Stage assignment phase shows one card per selection group
- Confirmation phase shows correct item/stage/total counts
- Processing phase shows progress bar
- Done phase shows undo button for 10 seconds
- Back button navigates between phases correctly
- `BulkMarkMode.onboarding` shows "Skip" button
- `BulkMarkMode.standalone` shows "Cancel" button

### Story Acceptance Tests

**File: `test/story_acceptance/epic_15_settings_test.dart`** (or new file)

```dart
group('Story 15.7: Enhanced Bulk Mark Tool', tags: ['story_15_7'], () {
  // AC1: Standalone access from Settings
  test('bulk mark tile appears in Settings screen');
  test('tapping bulk mark tile shows curriculum picker');
  test('selecting curriculum opens Enhanced Bulk Mark screen');

  // AC4: Multi-level tree with checkboxes
  test('tree shows top-level nodes collapsed by default');
  test('selecting parent auto-selects children');
  test('partially selected parent shows indeterminate state');

  // AC5: Per-stage marking
  test('stage assignment shows separate pickers per selection group');
  test('different stages can be assigned to different groups');

  // AC6: Search
  test('search filters tree by Hebrew and English names');
  test('tapping search result expands and scrolls to node');

  // AC8: Progress indicator
  test('processing phase shows real-time progress');

  // AC10: FittedBox title
  test('AppBar title does not truncate for long curriculum names');
});
```

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/bulk_mark/domain/models/tree_node.dart` | TreeNode, CheckState enum |
| `lib/features/bulk_mark/domain/models/bulk_mark_selection.dart` | SelectionModel, SelectionGroup |
| `lib/features/bulk_mark/domain/models/bulk_mark_state.dart` | BulkMarkState (Freezed) |
| `lib/features/bulk_mark/domain/services/bulk_mark_service.dart` | Core service with batched insert + undo |
| `lib/features/bulk_mark/presentation/screens/enhanced_bulk_mark_screen.dart` | Main screen |
| `lib/features/bulk_mark/presentation/widgets/bulk_mark_tree_view.dart` | Flattened virtualized tree |
| `lib/features/bulk_mark/presentation/widgets/tree_node_tile.dart` | Single tree row |
| `lib/features/bulk_mark/presentation/widgets/stage_assignment_panel.dart` | Per-group stage picker |
| `lib/features/bulk_mark/presentation/widgets/bulk_mark_search_bar.dart` | Search with jump-to |
| `lib/features/bulk_mark/presentation/providers/bulk_mark_providers.dart` | Riverpod providers |
| `test/features/bulk_mark/domain/models/selection_model_test.dart` | Unit tests |
| `test/features/bulk_mark/domain/services/bulk_mark_service_test.dart` | Service tests |
| `test/features/bulk_mark/presentation/widgets/bulk_mark_tree_view_test.dart` | Widget tests |
| `test/features/bulk_mark/presentation/screens/enhanced_bulk_mark_screen_test.dart` | Screen tests |

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/navigation/app_router.dart` | Add `EnhancedBulkMarkRoute`, import new screen |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Add "Mark Prior Completions" tile, curriculum picker dialog, post-activation bulk mark offer |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Replace `BulkMarkScreen` with `EnhancedBulkMarkScreen(mode: onboarding)` |
| `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | Add `@Deprecated` annotation, keep for reference |
| `lib/features/learning/data/repositories/completion_repository_impl.dart` | Optimize `bulkMarkComplete` with Drift `batch` API, add `bulkDeleteByTimestampRange` for undo |
| `lib/features/learning/domain/repositories/completion_repository.dart` | Add `bulkDeleteByTimestampRange` method signature |
| `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart` | Refactor to delegate to new `BulkMarkService` |
