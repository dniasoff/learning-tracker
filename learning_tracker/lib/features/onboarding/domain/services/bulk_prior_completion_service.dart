import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

export 'package:learning_tracker/core/content/hierarchy_selection.dart';

/// Sentinel [DateTime] used by the bulk-mark-prior flow to stamp completions
/// that represent "learned in the past, not today". Matches
/// [SchedulerEngine.kBulkPriorSentinel].
///
/// Backed by core's [kBulkPriorSentinelMs] (features/ → core/ is a legal
/// import direction; see docs/coding-standards.md Rule 1/Rule 2) — the single
/// source of truth for the expunge query in
/// [BulkPriorCompletionService.expungePriorCompletions].
const kBulkPriorSentinel = Duration(milliseconds: kBulkPriorSentinelMs);

/// True when [completedAt] is the bulk-prior sentinel.
///
/// Compares the moment (not the object) because a sentinel completion that
/// has round-tripped through Firestore (`Timestamp` → local `DateTime`) or
/// Drift comes back with a different `isUtc` flag than the original
/// `DateTime.utc(2000, 1, 1)` — a plain `==` then silently returns false and
/// the prior-completions pre-tick fails. `isAtSameMomentAs` after `toUtc()`
/// is flag-independent.
bool isBulkPriorSentinel(DateTime completedAt) =>
    completedAt.toUtc().isAtSameMomentAs(kBulkPriorSentinelDate);

/// Result of a bulk prior completion operation.
class BulkPriorCompletionResult {
  final int itemCount;
  final int completionCount;
  final String? bookmarkSefariaRef;

  const BulkPriorCompletionResult({
    required this.itemCount,
    required this.completionCount,
    this.bookmarkSefariaRef,
  });
}

/// Service for bulk-marking prior completions during onboarding.
///
/// Resolves hierarchy selections (e.g., "all of Seder Zeraim") into
/// individual leaf items, creates completion records for ALL required stages
/// (learn + every chazara), and sets the bookmark to the first uncompleted
/// item.
///
/// ### B6 — All-stages requirement
/// Under the item-based completion rule (B1) an item is only "done" when
/// completion_events exist for **every** stage the track defines. [execute]
/// therefore looks up the full stage list for the curriculum and unions it
/// with the caller-supplied [stageIds] before writing completions. This
/// guarantees that prior-marked items show 100% completion, not 0%.
///
/// ### B8 — Expunge API
/// [expungePriorCompletions] tombstones (sets `purgedAt`) the
/// completion_events rows that were created by a prior-marking run. Prior
/// rows are identified by their sentinel `eventTimestamp` of
/// `DateTime.utc(2000, 1, 1)`. Agent F (UI layer) calls this method when the
/// user un-selects a previously bulk-marked item.
class BulkPriorCompletionService {
  final ContentRepository _contentRepository;
  final CompletionRepository _completionRepository;
  final BookmarkRepository _bookmarkRepository;
  final UserDatabase _database;
  final AnalyticsService _analytics;
  final StageDefinitionRepository? _stageRepository;

  /// Optional outbox DAO for enqueuing tombstone propagation after
  /// [expungePriorCompletions]. When `null`, tombstones are written locally
  /// but NOT propagated to Firestore (a warning is logged).
  final OutboxDao? _outboxDao;

  /// Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
  /// owner decision 1). When set, [execute] routes its bulk-mark write
  /// through [CompletionOrchestrator.bulkMarkComplete] instead of calling
  /// [_completionRepository] directly — required for achievement (siyum)
  /// detection to fire, since the repository no longer does that itself.
  ///
  /// **Optional, not required**, to avoid a breaking constructor change
  /// across this service's ~10 existing test call sites, most of which
  /// exercise dedup/bookmark/expunge behavior and never assert siyum
  /// outcomes. When `null`, [execute] falls back to calling
  /// `_completionRepository.bulkMarkComplete` directly — the storage write
  /// still happens correctly, but the four post-write side effects
  /// (points, streak, siyum, bookmark) do NOT fire, since the repository is
  /// storage-only now. Production wiring (`onboarding_providers.dart`)
  /// always supplies a real orchestrator; only test doubles that do not
  /// care about those side effects may omit it.
  final CompletionOrchestrator? _orchestrator;

  /// Cached content items from the last [resolveSelections] call.
  List<ContentItem>? _cachedAllItems;
  CurriculumId? _cachedCurriculumId;

  BulkPriorCompletionService({
    required ContentRepository contentRepository,
    required CompletionRepository completionRepository,
    required BookmarkRepository bookmarkRepository,
    required UserDatabase database,
    // Retained for call-site/API compatibility but intentionally unused:
    // AUD-onboarding-08 removed the last consumer (an ad-hoc
    // `BookmarkRepositoryImpl(syncEngine: _syncEngine, ...)` construction in
    // execute()'s former profileId branch — see owner decision 2,
    // `docs/firestore-rewrite-map.md`, for why that branch and the
    // `bookmarkRepositoryFactory` seam it used are gone entirely now).
    // Dropping this parameter too would require updating ~40 existing call
    // sites for zero behavioural change; kept as a no-op instead.
    // ignore: avoid_unused_constructor_parameters
    SyncWriteFacade? syncEngine,
    AnalyticsService? analytics,
    StageDefinitionRepository? stageRepository,
    OutboxDao? outboxDao,
    CompletionOrchestrator? orchestrator,
  }) : _contentRepository = contentRepository,
       _completionRepository = completionRepository,
       _bookmarkRepository = bookmarkRepository,
       _database = database,
       _analytics = analytics ?? const NullAnalyticsService(),
       _stageRepository = stageRepository,
       _outboxDao = outboxDao,
       _orchestrator = orchestrator;

  /// Resolve hierarchy selections into leaf-level sefariaRefs.
  ///
  /// Each selection can be at any level (seder, masechta, perek, or individual
  /// mishna). Container selections expand to all leaf items within.
  Future<List<ContentItem>> resolveSelections({
    required CurriculumId curriculumId,
    required List<HierarchySelection> selections,
  }) async {
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    _cachedAllItems = allItems;
    _cachedCurriculumId = curriculumId;
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final selectedRefs = <String>{};

    for (final selection in selections) {
      // Filter all items matching this selection's hierarchy levels
      final matchingLeaves = leafItems.where((item) {
        if (selection.level1 != null && item.level1 != selection.level1) {
          return false;
        }
        if (selection.level2 != null && item.level2 != selection.level2) {
          return false;
        }
        if (selection.level3 != null && item.level3 != selection.level3) {
          return false;
        }
        if (selection.level4 != null && item.level4 != selection.level4) {
          return false;
        }
        return true;
      });

      for (final item in matchingLeaves) {
        selectedRefs.add(item.sefariaRef);
      }
    }

    return leafItems
        .where((item) => selectedRefs.contains(item.sefariaRef))
        .toList();
  }

  /// Resolve the full ordered list of stage IDs for [curriculumId].
  ///
  /// Returns the IDs sorted by [StageDefinition.stageOrder]. When no
  /// [StageDefinitionRepository] is injected (e.g. in tests that do not need
  /// B6 behaviour) falls back to the [fallback] list (default: `[1]`).
  ///
  /// ### Superseded stages
  /// [StageDefinitionRepository.getStagesForCurriculum] is backed by
  /// [StageDao.getStageDefinitionsByCurriculum], which filters
  /// `supersededAt IS NULL`. Superseded stage rows (left over from a
  /// previous track-edit operation) are therefore excluded here, so no
  /// phantom completions are written for stale stageOrders.
  ///
  /// Note: [StageDefinition] (the domain model) intentionally omits
  /// `supersededAt` — the filtering is enforced at the DAO layer.
  // Returns stageOrder values, not stage_definitions.id PKs.
  Future<List<int>> _allStageOrders(
    CurriculumId curriculumId, {
    List<int> fallback = const [1],
  }) async {
    if (_stageRepository == null) return fallback;
    final stages = await _stageRepository.getStagesForCurriculum(curriculumId);
    if (stages.isEmpty) {
      AppLogger.instance.warning(
        event:
            'BulkPriorCompletionService: no stage definitions found for '
            '$curriculumId — falling back to $fallback',
      );
      return fallback;
    }
    final ordered = [...stages]
      ..sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
    return ordered.map((s) => s.stageOrder).toList();
  }

  /// Execute bulk mark of prior completions.
  ///
  /// B6 fix: ignores the caller-supplied [stageIds] and instead writes one
  /// completion record per (item × track-stage) so that every stage defined
  /// on the track is satisfied. The sentinel timestamp `DateTime.utc(2000,1,1)`
  /// is written to [completedAt] so downstream consumers (scheduler, streak
  /// restorer, items-learned screen) can distinguish these prior-mark records
  /// from genuine learning sessions.
  ///
  /// After writing, sets the bookmark to the first uncompleted item.
  ///
  /// Bulk-mark-prior is always the `bulkInTrack` source (B1 three-tier policy):
  /// engagement (streak + points) is unconditionally suppressed; achievement
  /// (siyumim) and lifetime totals are credited. There is no caller-tunable
  /// gamification flag — a "live" bulk-mark would be a contradiction in terms.
  ///
  /// Always operates on the CURRENTLY OPEN (active) profile — owner decision
  /// 2, `docs/firestore-rewrite-map.md`. This used to take an `int?
  /// profileId` naming a profile other than the session's (the live path was
  /// a parent adding a track for a specific child), but there is no way to
  /// resolve another profile's Firestore identity from a bare Drift int, and
  /// guessing would silently write one child's completions onto another's
  /// document tree, permanently. Removed rather than left in place and
  /// ignored. The one caller that used to pass a real cross-profile id
  /// (`AddTrackFlow` during onboarding, via `_applySelfPacedPriorCompletions`
  /// in `add_track_flow_screen.dart`) threads a newly-created child's
  /// profile id through `AddTrackFlow.profileId` without ever switching the
  /// session's active profile to that child first — see that file's doc
  /// comment for what it would need instead (switch the active profile,
  /// don't thread the id).
  Future<BulkPriorCompletionResult> execute({
    required CurriculumId curriculumId,
    required List<ContentItem> resolvedItems,

    /// Caller-supplied stage ids — kept for API compatibility but B6 replaces
    /// these with the full track stage list. Pass `[1]` from the UI as before;
    /// the service will union in all remaining stages automatically.
    required List<int> stageIds,
  }) async {
    final sefariaRefs = resolvedItems.map((item) => item.sefariaRef).toList();
    var totalCompletions = 0;

    // B6: determine the full ordered stage list for this track.
    // The configured set (superseded stages filtered at the DAO layer) covers
    // all active stages regardless of what the caller passes.
    final allConfiguredStageIds = await _allStageOrders(
      curriculumId,
      fallback: stageIds,
    );
    // Finding 10: ignore the caller-supplied stageIds; use only the
    // superseded-filtered configured set. The parameter is retained for
    // API compatibility — callers should pass [1] or empty.
    final effectiveStageIds = [...allConfiguredStageIds]..sort();

    // Create completions for each stage. Bulk-mark-prior is the bulkInTrack
    // source (B1 policy): engagement suppressed, achievement credited.
    for (final stageId in effectiveStageIds) {
      final request = BulkCompletionRequest(
        curriculumId: curriculumId.storageKey,
        sefariaRefs: sefariaRefs,
        stageId: stageId,
        trackType: 'personal',
        // profileId omitted — always the active profile now (owner decision
        // 2, see [execute]'s doc comment).
        // Engagement gate: prior-mark NEVER credits streak or points.
        awardGamificationPoints: false,
        // F1 (W7-A): bulk-mark-prior represents the `bulkInTrack` source —
        // engagement is suppressed, but achievement (siyum detection) must
        // fire so a learner who bulk-marks an entire masechta still earns
        // the corresponding unit/aggregate siyum ledger entry.
        creditsAchievement: true,
        completedAt: kBulkPriorSentinelDate, // sentinel: "learned in the past"
      );
      final orchestrator = _orchestrator;
      final completions = orchestrator != null
          ? await orchestrator.bulkMarkComplete(request)
          : await _completionRepository.bulkMarkComplete(request);
      totalCompletions += completions.length;
    }

    // Query DB for all existing completions for this curriculum — profileId
    // omitted, defaults to the active profile (owner decision 2).
    final existingCompletions = await _completionRepository
        .getCompletionsByCurriculum(curriculumId.storageKey);
    final allCompletedRefs = {
      ...sefariaRefs,
      ...existingCompletions.map((c) => c.sefariaRef),
    };

    // Set bookmark to first uncompleted item
    final bookmarkRef = await _findFirstUncompletedItem(
      curriculumId: curriculumId,
      completedRefs: allCompletedRefs,
    );

    if (bookmarkRef != null) {
      await _bookmarkRepository.setBookmark(
        curriculumId: curriculumId,
        sefariaRef: bookmarkRef,
      );
    }

    // Story 27.14 (DNI-390): fire analytics event when bulk-mark-prior completes.
    unawaited(
      _analytics.logBulkMarkPriorUsed(
        itemCount: sefariaRefs.length,
        completionCount: totalCompletions,
      ),
    );

    return BulkPriorCompletionResult(
      itemCount: sefariaRefs.length,
      completionCount: totalCompletions,
      bookmarkSefariaRef: bookmarkRef,
    );
  }

  /// B8 — Tombstone completion_events created by prior-marking for an item.
  ///
  /// Sets `purgedAt` to the current UTC timestamp on every row in
  /// `completion_events` that matches:
  ///   - `profileId` == [profileId] (or the session default when null)
  ///   - `sefariaRef` == [sefariaRef]
  ///   - `trackType` == personal (prior-marks are always on the personal track)
  ///   - `eventTimestamp` == `DateTime.utc(2000, 1, 1)` — the bulk-prior
  ///     sentinel date, distinguishing these rows from live-learning records.
  ///
  /// C3 invariant: rows are **never deleted** — this is a tombstone write only.
  /// The `completions_view` (backed by `completion_events WHERE purgedAt IS
  /// NULL`) will stop returning the row immediately after this call.
  ///
  /// **Tombstone propagation (Finding 2).** After writing the local tombstone,
  /// each affected row is enqueued into the outbox so the tombstone reaches
  /// Firestore. The gateway writes `purged_at` onto the document; other devices
  /// see it on pull and tombstone their local rows. Requires [_outboxDao] to be
  /// set; when absent, a warning is logged and propagation is skipped.
  ///
  /// Agent F (UI layer) calls this when the user un-selects a previously
  /// bulk-marked item so the item reverts to "not started" status.
  ///
  /// AUD-onboarding-06 (DB-2): steps 2–4 (the tombstone UPDATE, the
  /// import-record delete, and the outbox-propagation inserts) run inside a
  /// single [UserDatabase.transaction] call. Pre-fix these were three
  /// independently-awaited statements; a crash after the tombstone UPDATE
  /// but before the outbox inserts landed would tombstone the local device
  /// while the delete/propagation never reached Firestore or other devices —
  /// this device shows the item unmarked while every synced device still
  /// shows it complete. Step 1 (the read that decides whether there is
  /// anything to expunge) stays outside the transaction — it is read-only
  /// and its result is only used to decide whether to open one.
  Future<void> expungePriorCompletions({
    required int profileId,
    required String sefariaRef,
    required CurriculumId curriculumId,
  }) async {
    final purgedAt = DateTimeFactory.nowUtc();
    const trackType = 'personal';
    final curriculumKey = curriculumId.storageKey;

    // ── 1. Identify the stage IDs that have prior-import records ─────────────
    // B8 fix: only tombstone completion_events rows that still have a matching
    // row in prior_completion_imports. Rows promoted to real-learning by
    // CompletionWriter (B8 upgrade) will have had their import record deleted,
    // so they will be invisible here and left untouched.
    final importRows =
        await (_database.select(_database.priorCompletionImports)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.sefariaRef.equals(sefariaRef) &
                  t.curriculumId.equals(curriculumKey) &
                  t.trackType.equals(trackType),
            ))
            .get();

    if (importRows.isEmpty) return; // Nothing to expunge.

    final stageIds = importRows.map((r) => r.stageId).toList();

    await _database.transaction(() async {
      // ── 2. Tombstone the completion_events rows for the identified stages ──
      await (_database.update(_database.completionEvents)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.sefariaRef.equals(sefariaRef) &
                t.curriculumId.equals(curriculumKey) &
                t.trackType.equals(trackType) &
                t.stageId.isIn(stageIds),
          ))
          .write(CompletionEventsCompanion(purgedAt: Value(purgedAt)));

      // ── 3. Delete the import records ────────────────────────────────────────
      await _database.priorCompletionImportDao.deleteImportsForItem(
        profileId: profileId,
        sefariaRef: sefariaRef,
        curriculumId: curriculumKey,
        trackType: trackType,
      );

      // ── 4. Propagate tombstones to Firestore via outbox ─────────────────────
      if (_outboxDao == null) {
        // No outbox DAO injected — tombstone is local-only. Acceptable in
        // tests.
        return;
      }

      // Query the rows just tombstoned (within this same transaction) to
      // build per-row outbox entries.
      final tombstonedRows =
          await (_database.select(_database.completionEvents)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.curriculumId.equals(curriculumKey) &
                    t.trackType.equals(trackType) &
                    t.stageId.isIn(stageIds) &
                    t.purgedAt.isNotNull(),
              ))
              .get();

      for (final row in tombstonedRows) {
        final entityKey =
            '${row.profileId}:${row.sefariaRef}:${row.stageId}:${row.trackType}:${row.curriculumId}';
        final payload = jsonEncode({
          'profile_id': row.profileId,
          'curriculum_id': row.curriculumId,
          'sefaria_ref': row.sefariaRef,
          'stage_id': row.stageId,
          'track_type': row.trackType,
          'track_id': row.trackId,
          'completed_at': row.eventTimestamp.toUtc().toIso8601String(),
          'points': row.points,
          'purged_at': purgedAt.toUtc().toIso8601String(),
        });
        await _outboxDao.insertOutboxRow(
          OutboxCompanion.insert(
            profileId: profileId,
            entityKind: OutboxEntityKind.completion,
            entityKey: entityKey,
            payload: payload,
            createdAt: purgedAt,
          ),
        );
      }
    });
  }

  /// Find the first uncompleted leaf item in learning order.
  Future<String?> _findFirstUncompletedItem({
    required CurriculumId curriculumId,
    required Set<String> completedRefs,
  }) async {
    final allItems =
        (_cachedCurriculumId == curriculumId && _cachedAllItems != null)
        ? _cachedAllItems!
        : await _contentRepository.getContentForCurriculum(curriculumId);
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final item in leafItems) {
      if (!completedRefs.contains(item.sefariaRef)) {
        return item.sefariaRef;
      }
    }
    return null; // All items completed
  }
}
