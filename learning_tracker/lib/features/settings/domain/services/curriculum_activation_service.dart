import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Service for managing curriculum activation/deactivation.
///
/// Handles:
/// - Activating and deactivating curricula
/// - Enforcing "at least one active curriculum" constraint
/// - Syncing activation state to Firestore
/// - Initializing default active curriculum (Mishnayos)
class CurriculumActivationService {
  CurriculumActivationService({
    required AppDatabase database,
    required Future<void> Function(List<String>) pushActiveCurricula,
  }) : _database = database,
       _pushActiveCurricula = pushActiveCurricula;

  final AppDatabase _database;
  final Future<void> Function(List<String>) _pushActiveCurricula;

  /// Initialize default active curricula if none exist.
  ///
  /// On first launch, only Mishnayos is active.
  Future<void> initialize() async {
    final activeCurricula = await _database.activeCurriculumDao
        .getActiveCurricula();
    if (activeCurricula.isEmpty) {
      await _database.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await _syncToFirestore();
    }
  }

  /// Activate a curriculum.
  Future<void> activate(CurriculumId curriculum) async {
    await _database.activeCurriculumDao.activate(curriculum);
    await _syncToFirestore();
  }

  /// Deactivate a curriculum.
  ///
  /// Throws [StateError] if this is the last active curriculum.
  Future<void> deactivate(CurriculumId curriculum) async {
    await _database.activeCurriculumDao.deactivate(curriculum);
    await _syncToFirestore();
  }

  /// Toggle a curriculum on or off.
  Future<void> toggle(CurriculumId curriculum) async {
    final isActive = await _database.activeCurriculumDao.isActive(curriculum);
    if (isActive) {
      await deactivate(curriculum);
    } else {
      await activate(curriculum);
    }
  }

  /// Get list of currently active curricula as enums.
  Future<List<CurriculumId>> getActiveCurricula() async {
    final storageKeys = await _database.activeCurriculumDao
        .getActiveCurricula();
    return storageKeys
        .map(
          (key) => CurriculumId.values.firstWhere((c) => c.storageKey == key),
        )
        .toList();
  }

  /// Watch stream of active curriculum IDs.
  Stream<List<String>> watchActiveCurricula() {
    return _database.activeCurriculumDao.watchActiveCurricula();
  }

  /// Sync active curricula to Firestore.
  ///
  /// Fails silently if offline or auth issues.
  Future<void> _syncToFirestore() async {
    try {
      final activeCurricula = await _database.activeCurriculumDao
          .getActiveCurricula();
      await _pushActiveCurricula(activeCurricula);
    } catch (e) {
      // Silent fail for offline/auth issues
      // Local database is source of truth
    }
  }
}
