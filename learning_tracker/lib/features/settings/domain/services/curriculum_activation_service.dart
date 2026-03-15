import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

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
    required TrackRepository trackRepository,
  }) : _database = database,
       _pushActiveCurricula = pushActiveCurricula,
       _trackRepository = trackRepository;

  final AppDatabase _database;
  final Future<void> Function(List<String>) _pushActiveCurricula;
  final TrackRepository _trackRepository;

  /// Initialize default active curricula if none exist.
  ///
  /// On first launch, only Mishnayos is active.
  Future<void> initialize() async {
    final activeCurricula = await _database.activeCurriculumDao
        .getActiveCurricula();
    if (activeCurricula.isEmpty) {
      await _database.activeCurriculumDao.activate(CurriculumId.mishnayos);
      await _trackRepository.initializeDefaultTracks(CurriculumId.mishnayos);
      await _syncToFirestore();
    }
  }

  /// Activate a curriculum.
  Future<void> activate(CurriculumId curriculum) async {
    await _database.activeCurriculumDao.activate(curriculum);
    await _trackRepository.initializeDefaultTracks(curriculum);
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
  ///
  /// The [isActive] check and [activate]/[deactivate] call are wrapped in a
  /// single database transaction to prevent a TOCTOU race where two concurrent
  /// toggle calls could both read the same state and both activate or both
  /// deactivate the curriculum.
  Future<void> toggle(CurriculumId curriculum) async {
    await _database.transaction(() async {
      final isActive = await _database.activeCurriculumDao.isActive(curriculum);
      if (isActive) {
        await deactivate(curriculum);
      } else {
        await activate(curriculum);
      }
    });
  }

  /// Get list of currently active curricula as enums.
  ///
  /// Unknown storage keys (e.g. from an old database) are skipped with a
  /// warning rather than throwing, so a stale DB row cannot crash the app.
  Future<List<CurriculumId>> getActiveCurricula() async {
    final storageKeys = await _database.activeCurriculumDao
        .getActiveCurricula();
    return storageKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          if (matches.isNotEmpty) {
            return matches.first;
          }
          AppLogger.instance.warning(
            'CurriculumActivationService.getActiveCurricula: '
            'unknown curriculum key: $key',
          );
          return null;
        })
        .whereType<CurriculumId>()
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
      // ignore: avoid_catches_without_on_clauses — intentional: silent fail for offline/auth
      // Silent fail for offline/auth issues — local database is source of truth
    }
  }
}
