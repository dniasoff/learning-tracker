/// Shared e2e test doubles reused across `test/e2e/journeys/*_test.dart`.
///
/// Extracted per AUD-t-cross-10 (TQ-4 + Fowler duplication lens): every
/// journey file that needed a no-op tutored-selection notifier or a fake
/// [ContentRepository]/[CompletionRepository] used to hand-roll its own
/// private copy instead of sharing one. The copies had already diverged —
/// see [FakeContentRepository.filterByLevel]'s doc comment for the bug this
/// caused, and `test/e2e/fakes/e2e_fakes_test.dart` for the regression
/// coverage that now guards it.
///
/// Classes here are intentionally public (no leading underscore) — Dart's
/// library-privacy rules mean a `_`-prefixed identifier cannot be imported
/// by another library, so a shared, cross-file test double must use a
/// public name. This matches the `FakeX implements X` convention already
/// documented for hand-written fakes (see docs/coding-standards.md, TQ-4).
library;

import 'package:flutter_test/flutter_test.dart' show Fake;
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart'
    show TutoredProfileSelection;
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// [ActiveTutoredProfileSelection] notifier that always returns null — no
/// tutored session active. Formerly hand-rolled verbatim (byte-for-byte
/// identical) in 11 e2e journey files.
class NullTutoredSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

/// Fake [ContentRepository] that returns a fixed list of [ContentItem]s.
///
/// Formerly hand-rolled independently in `learning_p0_test.dart` and
/// `learning_p1_test.dart`; the two copies had already diverged
/// (AUD-t-cross-10): `learning_p1_test.dart`'s [filterByLevel] silently
/// ignored every level argument and returned the full unfiltered list,
/// while `learning_p0_test.dart`'s same-named, same-interface copy filtered
/// correctly. This shared implementation filters — see
/// `e2e_fakes_test.dart` for the regression test.
class FakeContentRepository extends Fake implements ContentRepository {
  FakeContentRepository(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async =>
      _items.where((i) => i.curriculumId == curriculumId.storageKey).toList();

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Level 1'],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
    var items = await getContentForCurriculum(curriculumId);
    if (level1 != null) {
      items = items.where((i) => i.level1 == level1).toList();
    }
    if (level2 != null) {
      items = items.where((i) => i.level2 == level2).toList();
    }
    if (level3 != null) {
      items = items.where((i) => i.level3 == level3).toList();
    }
    if (level4 != null) {
      items = items.where((i) => i.level4 == level4).toList();
    }
    return items;
  }

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => await getContentForCurriculum(curriculumId);

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async {
    final items = await getContentForCurriculum(curriculumId);
    final q = query.toLowerCase();
    return items
        .where(
          (i) =>
              i.displayNameEn.toLowerCase().contains(q) ||
              i.displayNameHe.contains(q),
        )
        .toList();
  }

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final items = await getContentForCurriculum(curriculumId);
    try {
      return items.firstWhere((i) => i.sefariaRef == sefariaRef);
    } catch (_) {
      return null;
    }
  }
}

/// Fake [CompletionRepository] that records mark calls and returns a
/// configurable [MarkCompletionResult].
///
/// Formerly hand-rolled independently in `learning_p0_test.dart` and
/// `learning_p1_test.dart`.
class FakeCompletionRepository extends Fake implements CompletionRepository {
  FakeCompletionRepository({List<RewardUnlockRecord>? unlocks})
    : _unlocks = unlocks ?? const [];

  final List<RewardUnlockRecord> _unlocks;
  final List<CompletionRequest> markedRequests = [];

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    markedRequests.add(request);
    return MarkCompletionResult(
      completion: _stubCompletion(request),
      newMilestoneUnlocks: _unlocks,
    );
  }

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async => false;

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async => const <Completion>[];

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    String sefariaRef,
  ) async => const <Completion>[];

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async => const <Completion>[];

  Completion _stubCompletion(CompletionRequest req) {
    final now = DateTimeFactory.nowUtc();
    return Completion(
      id: markedRequests.length,
      profileId: 1,
      curriculumId: req.curriculumId,
      sefariaRef: req.sefariaRef,
      stageId: req.stageId,
      trackType: req.trackType,
      trackId: 1,
      completedAt: now,
      points: 10,
    );
  }
}
