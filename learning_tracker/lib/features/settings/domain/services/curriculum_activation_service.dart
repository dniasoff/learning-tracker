import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';

/// Service for managing curriculum activation state.
///
/// Handles activation, deactivation, and ensures business rules are enforced
/// (e.g., at least one curriculum must remain active).
class CurriculumActivationService {
  CurriculumActivationService({
    required this.database,
    this.firestoreDataSource,
  });

  final AppDatabase database;
  final FirestoreDataSource? firestoreDataSource;

  /// Get all active curriculum IDs
  Future<List<CurriculumId>> getActiveCurricula() async {
    final ids = await database.activeCurriculumDao.getActiveCurriculaIds();
    return ids
        .map((id) => CurriculumId.values.firstWhere((c) => c.storageKey == id))
        .toList();
  }

  /// Check if a curriculum is active
  Future<bool> isActive(CurriculumId curriculum) async {
    return database.activeCurriculumDao.isActive(curriculum.storageKey);
  }

  /// Activate a curriculum
  ///
  /// If the curriculum has no content imported, triggers import.
  /// Updates Firestore with the new active curricula list.
  Future<void> activate(CurriculumId curriculum) async {
    // Add to active curricula
    await database.activeCurriculumDao.activate(curriculum.storageKey);

    // TODO: Check if content is imported, trigger import if needed
    // This will be implemented when DNI-31 (import pipeline) is complete
    // Example: await _importService.importIfNeeded(curriculum);

    // Sync to Firestore
    await _syncActiveCurriculaToFirestore();
  }

  /// Deactivate a curriculum
  ///
  /// Throws if this would leave zero active curricula.
  /// Preserves all data (completions, bookmarks, content).
  /// Updates Firestore with the new active curricula list.
  Future<void> deactivate(CurriculumId curriculum) async {
    // Remove from active curricula (throws if last active)
    await database.activeCurriculumDao.deactivate(curriculum.storageKey);

    // TODO: Invalidate providers per P3 to prevent stale UI state
    // This requires understanding the provider architecture
    // Example: _ref.invalidate(familyProviderForCurriculum(curriculum));

    // Sync to Firestore
    await _syncActiveCurriculaToFirestore();
  }

  /// Toggle a curriculum's activation state
  Future<void> toggle(CurriculumId curriculum) async {
    final active = await isActive(curriculum);
    if (active) {
      await deactivate(curriculum);
    } else {
      await activate(curriculum);
    }
  }

  /// Initialize default active curricula (called during first-time setup)
  ///
  /// Activates at least one curriculum if none are active.
  Future<void> initializeDefaults() async {
    final count = await database.activeCurriculumDao.getActiveCount();
    if (count == 0) {
      // Activate Mishnayos by default
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );
      await _syncActiveCurriculaToFirestore();
    }
  }

  /// Sync active curricula to Firestore
  Future<void> _syncActiveCurriculaToFirestore() async {
    if (firestoreDataSource == null) return;

    try {
      final ids = await database.activeCurriculumDao.getActiveCurriculaIds();
      await firestoreDataSource!.pushActiveCurricula(ids);
    } catch (e) {
      // Silently fail if offline or auth issues - sync will happen later
    }
  }
}
