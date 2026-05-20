import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Resolve the [entryScope] string written to `learning_ledger` for a given
/// [curriculum] and hierarchy [level].
///
/// F2 (W7-A): hardcoded `'masechta'`/`'seder'` strings broke unit-level siyum
/// detection for every curriculum except Mishnayos/Bavli/Yerushalmi. The
/// returned values must match the unit-scope whitelist used by
/// `_detectMilestones` (`{'masechta', 'sefer', 'siman', 'hilchos'}`) for level
/// 2 detection, and the aggregate-scope set (`{'seder', 'chelek', 'sefer'}`)
/// for level 1.
///
///   - `level == 2` (used when the content has a non-null `level2`):
///       * `mishnayos`, `bavli`, `yerushalmi` → `'masechta'`
///       * `mishnaBerurah`                    → `'siman'`
///       * `mishnehTorah`                     → `'hilchos'`
///       * other curricula                    → `'masechta'` (defensive)
///   - `level == 1` (level-1-only curricula, or aggregate fallback):
///       * `mishnayos`, `bavli`, `yerushalmi` → `'seder'`
///       * `mishnaBerurah`                    → `'chelek'`
///       * `mishnehTorah`, `chumash`, `nach`, `tanach`, `mussar` → `'sefer'`
String unitScopeFor(CurriculumId curriculum, {required int level}) {
  if (level == 2) {
    switch (curriculum) {
      case CurriculumId.mishnayos:
      case CurriculumId.bavli:
      case CurriculumId.yerushalmi:
        return 'masechta';
      case CurriculumId.mishnaBerurah:
        return 'siman';
      case CurriculumId.mishnehTorah:
        return 'hilchos';
      case CurriculumId.chumash:
      case CurriculumId.nach:
      case CurriculumId.tanach:
      case CurriculumId.mussar:
        // These curricula have no level-2 in their content data — the level-2
        // branch should never fire for them. Default defensively to 'masechta'
        // so any future content-data change still produces a recognisable
        // scope string.
        return 'masechta';
    }
  }
  // level == 1 (aggregate / level-1-only curricula).
  switch (curriculum) {
    case CurriculumId.mishnayos:
    case CurriculumId.bavli:
    case CurriculumId.yerushalmi:
      return 'seder';
    case CurriculumId.mishnaBerurah:
      return 'chelek';
    case CurriculumId.mishnehTorah:
    case CurriculumId.chumash:
    case CurriculumId.nach:
    case CurriculumId.tanach:
    case CurriculumId.mussar:
      return 'sefer';
  }
}

/// Detects when all leaf items within a unit (masechta/seder/sefer)
/// are complete across all stages, and auto-creates a ledger entry.
///
/// Called immediately after each markComplete() in CompletionRepositoryImpl.
class CompletionDetectionService {
  final UserDatabase _database;
  final ContentRepository _contentRepository;
  final LearningLedgerRepository _ledgerRepository;
  final StageDefinitionRepository? _stageRepository;

  CompletionDetectionService({
    required UserDatabase database,
    required ContentRepository contentRepository,
    required LearningLedgerRepository ledgerRepository,
    StageDefinitionRepository? stageRepository,
  }) : _database = database,
       _contentRepository = contentRepository,
       _ledgerRepository = ledgerRepository,
       _stageRepository = stageRepository;

  /// Check if completing this leaf item completes a parent unit.
  ///
  /// Checks unit-level (level2 when present) first, then cascades to
  /// aggregate-level (level1). The `entryScope` string written to the ledger
  /// is curriculum-aware — see [unitScopeFor].
  Future<void> checkAndRecordCompletions({
    required String curriculumId,
    required String sefariaRef,
    required String trackType,
    int? trackId,
    required int profileId,
    required int markedBy,
  }) async {
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumId'),
    );

    // Look up the completed item to find its parent unit
    final item = await _contentRepository.getContentByRef(
      curriculumId: curriculum,
      sefariaRef: sefariaRef,
    );
    if (item == null) return;

    // Check unit-level (level2) completion — uses curriculum-specific scope
    // string (masechta / siman / hilchos) per F2.
    if (item.level2 != null) {
      await _checkUnitCompletion(
        curriculum: curriculum,
        curriculumId: curriculumId,
        entryScope: unitScopeFor(curriculum, level: 2),
        unitIdentifier: item.level2!,
        level1: item.level1,
        level2: item.level2,
        trackType: trackType,
        trackId: trackId,
        profileId: profileId,
        markedBy: markedBy,
      );
    }

    // Check aggregate-level (level1) completion — uses curriculum-specific
    // scope string (seder / chelek / sefer) per F2. For level-1-only
    // curricula (Chumash / Nach / Tanach / Mussar) this is the ONLY check
    // that fires, so its scope MUST be a recognised unit scope ('sefer') for
    // the journey provider's whitelist to count it as a unit-level siyum.
    await _checkUnitCompletion(
      curriculum: curriculum,
      curriculumId: curriculumId,
      entryScope: unitScopeFor(curriculum, level: 1),
      unitIdentifier: item.level1,
      level1: item.level1,
      level2: null,
      trackType: trackType,
      trackId: trackId,
      profileId: profileId,
      markedBy: markedBy,
    );
  }

  Future<void> _checkUnitCompletion({
    required CurriculumId curriculum,
    required String curriculumId,
    required String entryScope,
    required String unitIdentifier,
    required String level1,
    String? level2,
    required String trackType,
    int? trackId,
    required int profileId,
    required int markedBy,
  }) async {
    // Get all leaf items for this unit
    final allItems = await _contentRepository.filterByLevel(
      curriculumId: curriculum,
      level1: level1,
      level2: level2,
    );
    final leafItems = allItems.where((item) => item.isLeaf).toList();
    if (leafItems.isEmpty) return;

    // Get all stages that need to be complete
    final stages = _stageRepository != null
        ? await _stageRepository.getStagesForCurriculum(curriculum)
        : const <domain_stage.StageDefinition>[];
    if (stages.isEmpty) return;

    final stageIds = stages.map((s) => s.stageOrder).toList();

    // Issue ONE bulk query for all completions in this curriculum + profile,
    // then index by sefariaRef in memory. Previously this loop ran one DAO
    // call per leaf — for a masechta with 40 mishnayot leaves that was 40
    // round trips per detection call, and a seder-level check across
    // multiple masechtos could trigger hundreds.
    final allCompletions = await _database.completionDao
        .getCompletionsByCurriculumAndProfile(curriculumId, profileId);
    final stagesByRef = <String, Set<int>>{};
    for (final c in allCompletions) {
      if (c.trackType != trackType) continue;
      stagesByRef.putIfAbsent(c.sefariaRef, () => <int>{}).add(c.stageId);
    }

    // Check if every leaf has completions for every stage
    for (final leaf in leafItems) {
      final completedStages = stagesByRef[leaf.sefariaRef] ?? const <int>{};

      for (final stageId in stageIds) {
        if (!completedStages.contains(stageId)) {
          return; // Not all stages complete for this leaf
        }
      }
    }

    // All leaves complete across all stages — record completion
    // Get display names from the first leaf's parent level
    final displayHe = leafItems.first.displayNameHe;
    final displayEn = leafItems.first.displayNameEn;

    // Find a representative item for display names at the unit level.
    // F2 (W7-A): branch on whether this is the level-1 (aggregate) or
    // level-2 (unit) check instead of comparing the scope string — the
    // scope is now curriculum-aware (`seder` / `chelek` / `sefer`) so the
    // old `entryScope == 'seder'` discriminator no longer correctly
    // identifies the aggregate path for Mishna Berurah etc.
    final isAggregateLevel = level2 == null;
    final unitItems = allItems.where((item) {
      if (isAggregateLevel) {
        return item.level1 == level1 && item.level2 == null && !item.isLeaf;
      } else {
        return item.level2 == level2 && item.level3 == null && !item.isLeaf;
      }
    });

    final unitDisplayHe = unitItems.isNotEmpty
        ? unitItems.first.displayNameHe
        : displayHe;
    final unitDisplayEn = unitItems.isNotEmpty
        ? unitItems.first.displayNameEn
        : displayEn;

    await _ledgerRepository.recordCompletion(
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitDisplayHe,
      unitDisplayNameEn: unitDisplayEn,
      trackType: trackType,
      trackId: trackId,
      markedBy: markedBy,
      isManual: false,
    );
  }
}
