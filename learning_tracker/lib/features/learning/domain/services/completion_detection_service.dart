import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
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
///   - `level == 2` (used when the content has a non-null `level2` AND
///     [hasNamedLevel2Unit] says that value names a real unit — see below):
///       * `mishnayos`, `bavli`, `yerushalmi` → `'masechta'`
///       * `mishnaBerurah`                    → `'siman'`
///       * `mishnehTorah`                     → `'hilchos'`
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
        // P0 (false "Chumash complete!" siyum at 61.6% actual completion):
        // this branch used to be reached with the comment "these curricula
        // have no level-2 in their content data" — that was false. The
        // shipped assets (assets/content/hierarchy/{chumash,nach,mussar}
        // .json) DO carry a level-2 on ~97-99% of leaves: it is the chapter/
        // perek number (e.g. '1'), a bare POSITIONAL label, not a uniquely-
        // named unit like a masechta. Two different sefarim both have a
        // chapter '1', so recording it as `unitIdentifier` without
        // ancestor-qualifying it first collided across sefarim once
        // aggregated in `_detectMilestones` (journey_providers.dart),
        // corrupting the total-units denominator and firing a curriculum-
        // complete milestone after only 3 of 5 sefarim were done.
        //
        // Per product decision, a Chumash/Nach/Tanach/Mussar chapter is NOT
        // its own siyum tier — only the sefer (checked at level 1 below) is.
        // [CompletionDetectionService.checkAndRecordCompletions] gates the
        // level-2 branch on [hasNamedLevel2Unit], which is false for these
        // four curricula, so this case is never actually reached; it is
        // kept only so the switch stays exhaustive. If a future change
        // wants real per-chapter siyumim, do NOT return a bare chapter
        // number here — ancestor-qualify it first (e.g. `'$level1:$level2'`
        // or similar), mirroring `scopeUnitIdentifier()` in
        // `core/content/content_grouping.dart`, the codebase's existing
        // pattern for this exact sibling-id-collision class.
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

/// Whether [curriculum]'s level-2 hierarchy value names a real, uniquely-
/// identified siyum unit (a masechta / siman / hilchos) rather than a bare
/// positional label (a chapter/perek number that repeats across sefarim).
///
/// - Mishnayos / Bavli / Yerushalmi / Mishna Berurah / Mishneh Torah: `true`
///   — level-2 IS the masechta/siman/hilchos name, already unique within the
///   curriculum.
/// - Chumash / Nach / Tanach / Mussar: `false` — level-2 is a bare chapter
///   number (e.g. `'1'`), NOT unique across sefarim (Genesis ch. 1 and
///   Shemos ch. 1 both read `'1'`). See [unitScopeFor]'s level-2 doc comment
///   for the P0 this caused when it was treated as a unit identifier.
///
/// [CompletionDetectionService.checkAndRecordCompletions] uses this to skip
/// the level-2 (chapter) check entirely for these four curricula — a
/// chapter is not its own siyum tier here by product decision, so the
/// collision is avoided by never producing the identifier, rather than by
/// trying to qualify it after the fact.
bool hasNamedLevel2Unit(CurriculumId curriculum) {
  switch (curriculum) {
    case CurriculumId.mishnayos:
    case CurriculumId.bavli:
    case CurriculumId.yerushalmi:
    case CurriculumId.mishnaBerurah:
    case CurriculumId.mishnehTorah:
      return true;
    case CurriculumId.chumash:
    case CurriculumId.nach:
    case CurriculumId.tanach:
    case CurriculumId.mussar:
      return false;
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
  /// Checks unit-level (level2 — only when [hasNamedLevel2Unit] says the
  /// curriculum's level2 is a real, uniquely-named unit) first, then
  /// cascades to aggregate-level (level1). The `entryScope` string written
  /// to the ledger is curriculum-aware — see [unitScopeFor].
  ///
  /// [includeUnitLevelCheck] / [includeAggregateLevelCheck] let a caller
  /// that dispatches this once per distinct (level1, level2) pair AND once
  /// per distinct level1 — as the bulk-mark path does, to avoid firing the
  /// always-on aggregate check once per unit touched instead of once per
  /// bulk-mark batch (the P0 duplicate-siyum bug) — run only the half it
  /// needs on each dispatch. Both default to `true` so the single-item live
  /// path (one call per completion) is unaffected and still runs both.
  Future<void> checkAndRecordCompletions({
    required String curriculumId,
    required String sefariaRef,
    required String trackType,
    int? trackId,
    required int profileId,
    required int markedBy,
    CompletionSource source = CompletionSource.live,
    bool includeUnitLevelCheck = true,
    bool includeAggregateLevelCheck = true,
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
    // string (masechta / siman / hilchos) per F2. Gated on
    // [hasNamedLevel2Unit]: Chumash/Nach/Tanach/Mussar's level2 is a bare
    // chapter number, not a real unit — see [unitScopeFor]'s doc comment for
    // the P0 this caused when the branch fired for them regardless.
    if (includeUnitLevelCheck &&
        item.level2 != null &&
        hasNamedLevel2Unit(curriculum)) {
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
        source: source,
      );
    }

    // Check aggregate-level (level1) completion — uses curriculum-specific
    // scope string (seder / chelek / sefer) per F2. For level-1-only
    // curricula (Chumash / Nach / Tanach / Mussar) this is the ONLY check
    // that fires, so its scope MUST be a recognised unit scope ('sefer') for
    // the journey provider's whitelist to count it as a unit-level siyum.
    if (includeAggregateLevelCheck) {
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
        source: source,
      );
    }
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
    CompletionSource source = CompletionSource.live,
  }) async {
    // Get all leaf items for this unit
    final allItems = await _contentRepository.filterByLevel(
      curriculumId: curriculum,
      level1: level1,
      level2: level2,
    );
    final leafItems = allItems.where((item) => item.isLeaf).toList();
    if (leafItems.isEmpty) return;

    // Siyum fires on **limud (stage 1) completion** — finishing the
    // learning of every leaf in the unit. Chazara (stages ≥ 2) is review
    // of already-learned material and does NOT gate siyum. This is the
    // standard product semantic per docs/hebrew-terms.md §6 ("siyum =
    // completing a unit of learning") and is required for bulk-mark on a
    // chazara-enabled track to produce siyumim — bulk-mark only writes
    // stage 1, so requiring all stages would silently zero out siyumim
    // every time a user bulk-marks an entire masechta during onboarding.
    final stages = _stageRepository != null
        ? await _stageRepository.getStagesForCurriculum(curriculum)
        : const <domain_stage.StageDefinition>[];
    if (stages.isEmpty) return;

    // Find the limud (stage 1) row. Defensive fallback: if no stage has
    // `stageOrder == 1`, take the lowest-ordered stage we have.
    final limudStage = stages.firstWhere(
      (s) => s.stageOrder == 1,
      orElse: () =>
          stages.reduce((a, b) => a.stageOrder < b.stageOrder ? a : b),
    );
    // Completion rows in the live codebase write `stageId` as EITHER the
    // stage_definitions.id (autoincrement FK) OR the stageOrder (1, 2, 3…).
    // Accept both formats when checking limud completion.
    final limudStageIds = <int>{limudStage.id, limudStage.stageOrder};

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

    // Check that every leaf has a limud completion.
    for (final leaf in leafItems) {
      final completedStages = stagesByRef[leaf.sefariaRef] ?? const <int>{};
      if (!completedStages.any(limudStageIds.contains)) {
        return; // Limud not complete for this leaf — siyum not yet reached.
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
      source: source,
    );
  }
}
