import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';

/// Detects when all leaf items within a unit (masechta/seder/sefer)
/// are complete across all stages, and auto-creates a ledger entry.
///
/// Called immediately after each markComplete() in CompletionRepositoryImpl.
class CompletionDetectionService {
  final AppDatabase _database;
  final ContentRepository _contentRepository;
  final LearningLedgerRepository _ledgerRepository;

  CompletionDetectionService({
    required AppDatabase database,
    required ContentRepository contentRepository,
    required LearningLedgerRepository ledgerRepository,
  }) : _database = database,
       _contentRepository = contentRepository,
       _ledgerRepository = ledgerRepository;

  /// Check if completing this leaf item completes a parent unit.
  ///
  /// Checks masechta-level (level2) first, then cascades to seder-level (level1).
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

    // Check masechta-level (level2) completion
    if (item.level2 != null) {
      await _checkUnitCompletion(
        curriculum: curriculum,
        curriculumId: curriculumId,
        unitType: 'masechta',
        unitIdentifier: item.level2!,
        level1: item.level1,
        level2: item.level2,
        trackType: trackType,
        trackId: trackId,
        profileId: profileId,
        markedBy: markedBy,
      );
    }

    // Check seder-level (level1) completion
    await _checkUnitCompletion(
      curriculum: curriculum,
      curriculumId: curriculumId,
      unitType: 'seder',
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
    required String unitType,
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
    final stages = await _database.stageDao.getStageDefinitionsByCurriculum(
      curriculumId,
    );
    if (stages.isEmpty) return;

    final stageIds = stages.map((s) => s.stageOrder).toList();

    // Check if every leaf has completions for every stage
    for (final leaf in leafItems) {
      final completions = await _database.completionDao
          .getCompletionsForContentAndProfile(leaf.sefariaRef, profileId);
      final completedStages = completions
          .where((c) => c.trackType == trackType)
          .map((c) => c.stageId)
          .toSet();

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

    // Find a representative item for display names at the unit level
    final unitItems = allItems.where((item) {
      if (unitType == 'seder') {
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
      unitType: unitType,
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
