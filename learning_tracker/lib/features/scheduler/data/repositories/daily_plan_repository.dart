import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Snapshots the day's scheduled tasks and serves them back on subsequent
/// reads. The scheduler is invoked only when no snapshot exists for
/// ([profileId], local date); completions do not trigger regeneration.
///
/// NOTE (architecture §6): `daily_plans` is a disposable cache.  The
/// authoritative overdue/today/review view is derived by the pure
/// projection module — this repository only caches that result for the
/// current local day so repeated reads are cheap.
///
/// ## Stays local — never leaves the device
///
/// `docs/firestore-rewrite-map.md` classifies `DailyPlans` under "Stays
/// local (never leaves the device)": the plan is recomputed per device from
/// stages + goals + bookmarks, and Firestore owns no `daily_plans`
/// collection. With the Drift user DB deleted, the snapshot now lives in an
/// in-memory session cache keyed by `(profileId, local date)` instead of a
/// table — the same "build once per local day" contract, scoped to the
/// current app session (a cold start re-runs [buildPlan] for the day, which
/// a disposable cache always tolerated). The cache stores the [DailyTask]
/// values directly, so fields the old table could not round-trip (the
/// seed-sourced `unitDisplayHe`/`unitDisplayEn` labels) now survive the
/// snapshot.
///
/// There is no backend resolution on any path, so there is no "not ready"
/// state to throw on: every result is either a cache hit or the caller's
/// freshly built plan — never a fabricated empty snapshot.
///
/// ## Achievement-shaped reads (D-E)
///
/// The plan this serves is achievement-shaped: an empty list would read as
/// "nothing scheduled for today", indistinguishable from a learner who has
/// no plan. This repository therefore never returns an empty plan of its
/// own making — it serves only what [buildPlan] actually produced (or what
/// was already cached), and the caller's own scheduler/achievement adapters
/// own the not-ready policy.
class DailyPlanRepository {
  DailyPlanRepository();

  final Map<(int, DateTime), List<DailyTask>> _snapshots = {};

  /// Returns today's plan, running [buildPlan] exactly once per local day
  /// to materialize rows. Subsequent calls on the same local day read the
  /// snapshot regardless of any completions that happened since.
  ///
  /// The returned record also carries [isNew] = true when the plan was
  /// freshly generated in this call (i.e. no prior snapshot existed).
  /// Callers can use this flag to skip expensive integrity guards that only
  /// matter immediately after generation.
  Future<({List<DailyTask> tasks, bool isNew})> getOrSnapshotPlan({
    required int profileId,
    required DateTime now,
    required Future<List<DailyTask>> Function() buildPlan,
  }) async {
    final planDate = LocalDayUtils.extractLocalDate(now);
    final key = (profileId, planDate);

    final cached = _snapshots[key];
    if (cached != null) {
      return (tasks: cached, isNew: false);
    }

    final freshTasks = await buildPlan();
    _snapshots[key] = List.unmodifiable(freshTasks);
    return (tasks: freshTasks, isNew: true);
  }

  /// Forces regeneration for today's plan by clearing the existing snapshot.
  Future<List<DailyTask>> rebuildPlan({
    required int profileId,
    required DateTime now,
    required Future<List<DailyTask>> Function() buildPlan,
  }) async {
    final planDate = LocalDayUtils.extractLocalDate(now);
    _snapshots.remove((profileId, planDate));

    final freshTasks = await buildPlan();
    _snapshots[(profileId, planDate)] = List.unmodifiable(freshTasks);
    return freshTasks;
  }
}
