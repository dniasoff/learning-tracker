# Track Detail Screen, Bulk Mark & Per-Track Content Ordering — Implementation Plan

## Overview

Three sequentially-dependent stories:

| Story | Summary | Depends on |
|-------|---------|-----------|
| A | Track Detail Screen | — |
| B | Bulk Mark Content Done (post-setup) | A |
| C | Per-Track Drag Reorder (sedarim + masechtos) | A + DB migration |

---

## Story A — Track Detail Screen

**Goal:** Tapping an active track card navigates to a per-track management screen. Tapping archived tracks continues to show the reactivate dialog (no change there).

### Files to change

#### 1. NEW `lib/features/track_setup/presentation/screens/track_detail_screen.dart`

A `@RoutePage()` `ConsumerWidget` that takes a `CurriculumTrack` as a constructor argument (passed via `AutoRoute` extras).

**Layout:**
- `AppBar` with curriculum Hebrew + English name
- Header card: track type badge, activated-at date, cycle % progress bar, lifetime % progress bar (reuse same providers as `LearningTrackCard`)
- Action list tiles:
  - `ListTile` "Mark Content Done" → `Icons.check_circle_outline` → navigates to bulk mark (Story B)
  - `ListTile` "Reorder Content" → `Icons.swap_vert_rounded` → navigates to track order screen (Story C)
  - `ListTile` "Archive Track" → `Icons.archive_outlined` → same `_showArchiveDialog` logic as hub, then `context.router.pop()`

#### 2. MODIFY `lib/core/navigation/app_router.dart`

Add one route after the `TrackManagementHubRoute`:

```dart
AutoRoute(
  path: '/settings/tracks/detail',
  page: TrackDetailRoute.page,
  guards: [authGuard],
),
```

Then run `dart run build_runner build --delete-conflicting-outputs`.

#### 3. MODIFY `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart`

In the `activeTracks.map(...)` block, add `onTap` to the active `LearningTrackCard`:

```dart
LearningTrackCard(
  track: track,
  showProgress: true,
  onTap: () => context.router.push(TrackDetailRoute(track: track)),
  onLongPress: () => _showArchiveDialog(track),
),
```

Remove the archive action from `onLongPress` once it lives on the detail screen (or keep it — long-press as a shortcut is fine to retain).

### Code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Story B — Bulk Mark Content Done (Post-Setup)

**Goal:** From the Track Detail Screen, "Mark Content Done" opens `BulkMarkScreen` scoped to the track's content, awarding full gamification points.

### Key difference from onboarding

`BulkPriorCompletionService.execute()` hardcodes `awardGamificationPoints: false`. Post-setup bulk mark should award full points.

### Files to change

#### 1. MODIFY `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart`

Add `bool awardGamificationPoints = false` parameter to `execute()`:

```dart
Future<BulkPriorCompletionResult> execute({
  required CurriculumId curriculumId,
  required List<ContentItem> resolvedItems,
  required List<int> stageIds,
  int? profileId,
  bool awardGamificationPoints = false,   // ← add this
}) async {
  ...
  final request = BulkCompletionRequest(
    ...
    awardGamificationPoints: awardGamificationPoints,   // ← use it
  );
```

Default remains `false` so onboarding behaviour is unchanged.

#### 2. MODIFY `lib/features/track_setup/presentation/screens/track_detail_screen.dart`

Wire the "Mark Content Done" tile. The flow:

1. Load the track's scope constraints from the DB:
   ```dart
   final scopes = await ref.read(userDatabaseProvider)
       .curriculumScopeDao.getScopesByTrack(track.id);
   final scopeEntries = scopes
       .map((s) => ScopeEntry(level: s.scopeLevel, value: s.scopeValue))
       .toList();
   ```

2. Push `BulkMarkScreen` via `Navigator.of(context).push(MaterialPageRoute(...))`:
   ```dart
   final result = await Navigator.of(context).push<BulkMarkResult>(
     MaterialPageRoute(
       builder: (_) => BulkMarkScreen(
         curriculumId: curriculumId,        // resolved from track.curriculumId
         scopeConstraints: scopeEntries,    // null/empty = whole curriculum
         awardGamificationPoints: true,     // ← post-setup: full points
       ),
     ),
   );
   ```

3. `BulkMarkScreen` needs a new `awardGamificationPoints` constructor parameter (default `false`) that it threads through to `BulkPriorCompletionService.execute()`.

#### 3. MODIFY `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`

Add constructor parameter:
```dart
final bool awardGamificationPoints;

const BulkMarkScreen({
  super.key,
  required this.curriculumId,
  this.scopeConstraints,
  this.awardGamificationPoints = false,   // ← add
});
```

Pass it through to the service call in `_Phase.processing`.

---

## Story C — Per-Track Drag Reorder

**Goal:** From the Track Detail Screen, "Reorder Content" opens a screen with two drag-reorder sections — Sedarim (level1) and Masechtos (level2) — stored per-track. Resets fall back to canonical order.

### Schema

#### NEW `lib/core/database/tables/track_learning_order.dart`

```dart
class TrackLearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  TextColumn get sefariaRef => text()();
  IntColumn get sortOrder => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {trackId, sefariaRef},
  ];
}
```

#### MODIFY `lib/core/database/user/user_database.dart`

1. Add `TrackLearningOrder` to `tables` list.
2. Add `TrackLearningOrderDao` to `daos` list.
3. Bump `schemaVersion` to `7`.
4. Add migration:
   ```dart
   if (from < 7) {
     await m.createTable(trackLearningOrder);
   }
   ```

#### Run code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

### DAO

#### NEW `lib/core/database/daos/track_learning_order_dao.dart`

```dart
@DriftAccessor(tables: [TrackLearningOrder])
class TrackLearningOrderDao extends DatabaseAccessor<UserDatabase>
    with _$TrackLearningOrderDaoMixin {

  Future<List<TrackLearningOrderData>> getByTrack(int trackId) =>
      (select(trackLearningOrder)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<void> upsertOrder(int trackId, List<String> refs) async {
    for (var i = 0; i < refs.length; i++) {
      await into(trackLearningOrder).insert(
        TrackLearningOrderCompanion.insert(
          trackId: trackId,
          sefariaRef: refs[i],
          sortOrder: i,
        ),
        onConflict: DoUpdate(
          (_) => TrackLearningOrderCompanion(sortOrder: Value(i)),
          target: [trackLearningOrder.trackId, trackLearningOrder.sefariaRef],
        ),
      );
    }
  }

  Future<void> deleteByTrack(int trackId) =>
      (delete(trackLearningOrder)..where((t) => t.trackId.equals(trackId))).go();
}
```

### Repository

#### NEW `lib/features/track_learning_order/domain/repositories/track_learning_order_repository.dart`

```dart
abstract class TrackLearningOrderRepository {
  /// Returns ordered sedarim (level1 non-leaf) for the track.
  /// Falls back to canonical sort_order when no custom order saved.
  Future<List<LearningOrderItem>> getSedarimOrder(
      int trackId, CurriculumId curriculumId);

  /// Returns ordered masechtos (level2 non-leaf) for the track.
  Future<List<LearningOrderItem>> getMasechtosOrder(
      int trackId, CurriculumId curriculumId);

  Future<void> saveSedarimOrder(int trackId, List<LearningOrderItem> items);
  Future<void> saveMasechtosOrder(int trackId, List<LearningOrderItem> items);

  /// Deletes all custom order rows for the track (reset to canonical).
  Future<void> resetToDefault(int trackId);
}
```

#### NEW `lib/features/track_learning_order/data/repositories/track_learning_order_repository_impl.dart`

Builds two maps from `ContentRepository.getContentForCurriculum()`:
- **sedarim index**: items where `level2 == null` (pure level1 container nodes), keyed by `sefariaRef`
- **masechtos index**: items where `level2 != null && !isLeaf`, keyed by `sefariaRef`

For each, check if rows exist in `track_learning_order` for this `trackId`:
- If rows exist → sort by `sortOrder`, enrich with display names
- If no rows → fall back to `sort_order` from content, mark `isCustomOrdered: false`

`saveSedarimOrder` / `saveMasechtosOrder` call `dao.upsertOrder(trackId, refs)`.

`resetToDefault` calls `dao.deleteByTrack(trackId)`.

### Providers

#### NEW `lib/features/track_learning_order/presentation/providers/track_learning_order_providers.dart`

```dart
// Repository provider
final trackLearningOrderRepositoryProvider =
    Provider<TrackLearningOrderRepository>((ref) { ... });

// Family keyed by (trackId, curriculumId)
final trackSedarimOrderProvider =
    FutureProvider.family<List<LearningOrderItem>, ({int trackId, CurriculumId curriculumId})>(
      (ref, args) => ref.watch(trackLearningOrderRepositoryProvider)
          .getSedarimOrder(args.trackId, args.curriculumId),
    );

final trackMasechtosOrderProvider =
    FutureProvider.family<List<LearningOrderItem>, ({int trackId, CurriculumId curriculumId})>(
      (ref, args) => ref.watch(trackLearningOrderRepositoryProvider)
          .getMasechtosOrder(args.trackId, args.curriculumId),
    );
```

### Screen

#### NEW `lib/features/track_learning_order/presentation/screens/track_learning_order_screen.dart`

Constructor: `(int trackId, CurriculumId curriculumId)`

**Layout — single `CustomScrollView` with slivers:**

```
SliverAppBar / AppBar  — "[Curriculum] • Reorder Content"  +  Reset button

SliverToBoxAdapter     — section header "סדרים / Sedarim"
SliverPadding (shrinkWrap ReorderableListView of sedarim)

SliverToBoxAdapter     — section header "מסכתות / Masechtos"
SliverPadding (shrinkWrap ReorderableListView of masechtos)
```

Each `ReorderableListView` uses `DraggableOrderItem` (reused unchanged).

Local state mirrors provider data optimistically (same pattern as existing `LearningOrderScreen`): `List<LearningOrderItem>? _localSedarim` and `List<LearningOrderItem>? _localMasechtos`.

On drag end, update local state immediately and call `repository.saveSedarimOrder` / `saveMasechtosOrder` async, then invalidate the provider.

Reset button → confirmation dialog (reuse `ResetOrderDialog`) → `repository.resetToDefault(trackId)` → set both local lists to `null` → invalidate both providers.

**Note on `shrinkWrap` + scroll:** use `ReorderableListView` with `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()` inside the `CustomScrollView`. This is safe here because each section has a bounded, small count of items (sedarim: 6 max; masechtos: ~60 max). If masechtos count is large, consider making them independently scrollable with a fixed height.

#### MODIFY `lib/features/track_setup/presentation/screens/track_detail_screen.dart`

Wire "Reorder Content" tile:
```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => TrackLearningOrderScreen(
    trackId: track.id,
    curriculumId: curriculumId,
  ),
));
```

---

## Execution order

1. **Story A** — detail screen scaffold, router change, hub wiring, code-gen
2. **Story B** — `BulkMarkScreen` param, service param, detail screen wiring
3. **Story C** — DB table + DAO + code-gen, repository + providers, order screen, detail screen wiring

Each story is independently testable once the previous is complete.

---

## Acceptance checklist

### Story A
- [ ] Tapping active track card navigates to detail screen
- [ ] Archive action on detail screen works and pops back
- [ ] Archived tracks still show reactivate dialog (hub behaviour unchanged)

### Story B
- [ ] "Mark Content Done" opens `BulkMarkScreen` showing only content within track scope (or full curriculum if unscoped)
- [ ] Completions created with today's timestamp, full gamification points
- [ ] Completions appear in both track progress and lifetime progress
- [ ] Onboarding bulk mark still sets `awardGamificationPoints: false` (no regression)

### Story C
- [ ] "Reorder Content" opens two-section screen
- [ ] Sedarim section shows all sedarim for curriculum; drag reorder persists
- [ ] Masechtos section shows all masechtos; drag reorder persists
- [ ] Each section is independent (dragging in one doesn't affect the other)
- [ ] Reset → canonical order restored; custom rows deleted
- [ ] Custom order used by the scheduler for this track (verify via `SchedulerEngine` which reads from `learningOrderRepository` — note: scheduler currently reads the *global* `learning_order` table, so this integration point may be out of scope for this story and tracked separately)
- [ ] Different tracks for the same curriculum can have different orders
