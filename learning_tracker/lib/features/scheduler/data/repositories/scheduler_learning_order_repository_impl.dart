import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';

/// Adapts [LearningOrderDao] for scheduler consumption.
///
/// Scoped to a single profile so a sibling profile's custom learning order
/// cannot leak into this profile's daily plan (AUD-core-database-02).
///
/// **No longer wired into production** — `schedulerEngineProvider`
/// (`lib/features/scheduler/presentation/providers/scheduler_providers.dart`)
/// now constructs [SchedulerFirestoreLearningOrderRepositoryAdapter] below
/// instead. This class is a stranded reader left behind by the F2 rewire
/// (`learningOrderRepositoryProvider` → `FirestoreLearningOrderRepositoryAdapter`,
/// `lib/features/tracks/whole_curriculum_order/data/repositories/
/// learning_order_repository_impl.dart`): that rewire's `saveOrder` stopped
/// writing `learning_order_dao` entirely, so a reorder saved after the
/// cutover would never appear in [getOrder] below — daily-task generation
/// would silently keep serving whichever order was in Drift before the
/// cutover, forever. Kept only for its existing unit tests; do not
/// reintroduce it as the production wiring.
class SchedulerLearningOrderRepositoryImpl
    implements SchedulerLearningOrderRepository {
  SchedulerLearningOrderRepositoryImpl({
    required LearningOrderDao learningOrderDao,
    int profileId = 0,
  }) : _learningOrderDao = learningOrderDao,
       _profileId = profileId;

  final LearningOrderDao _learningOrderDao;
  final int _profileId;

  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId) async {
    final rows = await _learningOrderDao.getLearningOrderByCurriculum(
      curriculumId.storageKey,
      profileId: _profileId,
    );
    return rows
        .map(
          (r) => SchedulerOrderItem(
            sefariaRef: r.sefariaRef,
            userSortOrder: r.userSortOrder,
          ),
        )
        .toList();
  }
}

/// Firestore-backed [SchedulerLearningOrderRepository] adapter — the
/// scheduler-side read counterpart to
/// `FirestoreLearningOrderRepositoryAdapter`
/// (`lib/features/tracks/whole_curriculum_order/data/repositories/
/// learning_order_repository_impl.dart`), built to the same
/// resolved-`Ref`-per-call pattern that class and
/// `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// establish — see that class's doc comment for "the pattern to copy" in
/// full. This comment only calls out what is specific to the scheduler
/// boundary.
///
/// ## Why this exists — the regression this closes
///
/// `learningOrderRepositoryProvider` was rewired (F2) so the whole-
/// curriculum reorder screen writes to
/// `users/{uid}/learner_profiles/{ULID}/learning_order` via
/// `FirestoreLearningOrderRepositoryAdapter.saveOrder`, and stopped writing
/// the Drift `learning_order` table entirely. [SchedulerLearningOrderRepositoryImpl]
/// above still read that now-frozen Drift table — a reorder saved after
/// the cutover would never reach daily-task generation, silently. This
/// class points the scheduler's read at the SAME Firestore document tree
/// the writer now uses, closing that gap the same way
/// [FirestoreLearningOrderRepositoryAdapter] closed the bookmark-side one
/// (see that class's doc comment, "F2 fix — why this class exists").
///
/// ## Uses [FirestoreLearningOrderRepository.getCustomOrderRefs], not
/// `.getOrder`
///
/// `getOrder` SYNTHESIZES a full natural-order list whenever no rows are
/// stored (see that method's own doc comment) — every profile would then
/// read as "has a custom order," custom order or not. `SchedulerEngine`
/// (`lib/features/scheduler/domain/services/scheduler_engine.dart`,
/// `_buildOrderedRefs`) already has its own natural-order fallback (sorts
/// `SchedulerContentItem` by `sortOrder` when the returned list is empty),
/// so this adapter must hand it the raw, possibly-empty signal —
/// [FirestoreLearningOrderRepository.getCustomOrderRefs] — not a second,
/// differently-sourced natural order that could silently disagree with the
/// engine's own fallback.
///
/// ## Not-ready reads as "no custom order" — deliberate, and self-healing
///
/// [getOrder] returns `[]` when `firestoreLearningOrderRepositoryProvider`
/// resolves to `null` (no active account, or no active learner profile,
/// yet) — the same choice
/// [FirestoreLearningOrderRepositoryAdapter.getOrder] makes for the reorder
/// screen, and consistent with [SchedulerLearningOrderRepository.getOrder]'s
/// own pre-existing contract ("Returns empty list if no custom order is
/// set"). Concretely: a daily-task generation that races the very first
/// Firestore resolve after a cold start / fresh sign-in falls back to
/// natural content order for that one read, instead of the user's saved
/// custom order. This is judged acceptable rather than silently wrong
/// because it is NOT sticky — [_resolveOrNull] re-reads
/// `firestoreLearningOrderRepositoryProvider` fresh on every call (no
/// caching), and the overdue/today bucket that consumes it
/// (`allDailyTasksProvider` → `daily_task_projection_service.dart`'s
/// projection) is recomputed from scratch on every read rather than cached
/// per day, so the very next read after the provider resolves sees the
/// correct custom order. Widening [SchedulerLearningOrderRepository.getOrder]
/// to distinguish "not ready" from "no custom order" was considered and
/// rejected: it would require changing the interface and every
/// `SchedulerEngine` call site that folds this into `_buildOrderedRefs`, to
/// close a window that self-heals on the next read regardless — not
/// justified when the reference adapter one layer over already made the
/// same read-side trade-off.
class SchedulerFirestoreLearningOrderRepositoryAdapter
    implements SchedulerLearningOrderRepository {
  SchedulerFirestoreLearningOrderRepositoryAdapter({required Ref ref})
    : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreLearningOrderRepositoryProvider`, resolving to
  /// `null` exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreLearningOrderRepositoryAdapter._resolveOrNull`'s doc comment
  /// for why, and this class's own doc comment ("Not-ready reads as 'no
  /// custom order'") for why that matters here specifically.
  Future<FirestoreLearningOrderRepository?> _resolveOrNull() {
    return _ref.read(firestoreLearningOrderRepositoryProvider.future);
  }

  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    // Raw stored refs only, already ordered by `user_sort_order`
    // server-side — see the class doc comment's "Uses getCustomOrderRefs"
    // section for why this must not be `.getOrder`. List position becomes
    // the new `userSortOrder`, mirroring how `FirestoreLearningOrderRepository
    // .saveOrder` derived `user_sort_order` from list position in the first
    // place (`items[i]` ↦ `i`) — round-tripping it back out as list index
    // reproduces the same relative order `_buildOrderedRefs` sorts by.
    final refs = await repo.getCustomOrderRefs(curriculumId);
    return [
      for (var i = 0; i < refs.length; i++)
        SchedulerOrderItem(sefariaRef: refs[i], userSortOrder: i),
    ];
  }
}
