import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';

/// Service for managing curriculum activation/deactivation.
///
/// Scoped to a single profile — each profile on the account has its own
/// independent set of active curricula.
class CurriculumActivationService {
  CurriculumActivationService({
    required UserDatabase database,
    required Future<void> Function(Map<String, dynamic>)? pushCurriculumTrack,
    required TrackRepository trackRepository,
    int profileId = 0,
  }) : _database = database,
       _pushCurriculumTrack = pushCurriculumTrack,
       _trackRepository = trackRepository,
       _profileId = profileId;

  final UserDatabase _database;
  final Future<void> Function(Map<String, dynamic>)? _pushCurriculumTrack;
  final TrackRepository _trackRepository;
  final int _profileId;

  /// Initialize default active curricula for this profile if none exist.
  Future<void> initialize() async {
    final activeCurricula = await _database.activeCurriculumDao
        .getActiveCurriculaByProfile(_profileId);
    if (activeCurricula.isEmpty) {
      await _trackRepository.initializeDefaultTracks(
        CurriculumId.mishnayos,
        profileId: _profileId,
      );
      final trackId = await _resolveTrackId(CurriculumId.mishnayos, _profileId);
      await _database.studyDayConfigDao.seedDefaults(
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
      );
      await _syncToFirestore();
    }
  }

  /// Activate a curriculum for the active profile.
  Future<void> activate(CurriculumId curriculum) async {
    await _database.activeCurriculumDao.activateByProfile(
      curriculum,
      _profileId,
    );
    await _trackRepository.initializeDefaultTracks(
      curriculum,
      profileId: _profileId,
    );
    final trackId = await _resolveTrackId(curriculum, _profileId);
    await _database.studyDayConfigDao.seedDefaults(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
    );
    await _syncToFirestore();
  }

  /// Activate a curriculum for a specific profile (explicit override).
  Future<void> activateForProfile(
    CurriculumId curriculum,
    int profileId,
  ) async {
    await _database.activeCurriculumDao.activateByProfile(
      curriculum,
      profileId,
    );
    await _trackRepository.initializeDefaultTracks(
      curriculum,
      profileId: profileId,
    );
    final trackId = await _resolveTrackId(curriculum, profileId);
    await _database.studyDayConfigDao.seedDefaults(
      profileId: profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
    );
    await _syncToFirestore();
  }

  /// Deactivate a curriculum for the active profile.
  ///
  /// Throws [LastActiveCurriculumException] when the profile has exactly one
  /// active curriculum (minimum-1 invariant).
  Future<void> deactivate(CurriculumId curriculum) async {
    final active = await _database.activeCurriculumDao
        .getActiveCurriculaByProfile(_profileId);
    if (active.length <= 1) {
      throw const LastActiveCurriculumException();
    }
    await _database.activeCurriculumDao.deactivateByProfile(
      curriculum,
      _profileId,
    );
    await _syncToFirestore();
  }

  /// Toggle a curriculum on or off for the active profile.
  Future<void> toggle(CurriculumId curriculum) async {
    await _database.transaction(() async {
      final isActive = await _database.activeCurriculumDao.isActiveForProfile(
        curriculum,
        _profileId,
      );
      if (isActive) {
        await deactivate(curriculum);
      } else {
        await activate(curriculum);
      }
    });
  }

  /// Get list of currently active curricula for the active profile.
  Future<List<CurriculumId>> getActiveCurricula() async {
    final storageKeys = await _database.activeCurriculumDao
        .getActiveCurriculaByProfile(_profileId);
    return storageKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          if (matches.isNotEmpty) {
            return matches.first;
          }
          AppLogger.instance.warning(
            event: 'CurriculumActivationService.getActiveCurricula: '
                'unknown curriculum key: $key',
          );
          return null;
        })
        .whereType<CurriculumId>()
        .toList();
  }

  /// Watch stream of active curriculum IDs for the active profile.
  Stream<List<String>> watchActiveCurricula() {
    return _database.activeCurriculumDao.watchActiveCurriculaByProfile(
      _profileId,
    );
  }

  Future<int> _resolveTrackId(CurriculumId curriculum, int profileId) async {
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculum.storageKey) &
                    t.trackType.equals(TrackType.personal.storageKey),
              )
              ..limit(1))
            .getSingleOrNull();
    return track?.id ?? 0;
  }

  /// Sync this profile's tracks to Firestore.
  Future<void> _syncToFirestore() async {
    try {
      await _syncTracksToFirestore();
    } catch (e) {
      // Silent fail for offline/auth issues — local DB is source of truth
    }
  }

  Future<void> _syncTracksToFirestore() async {
    if (_pushCurriculumTrack == null) return;
    final tracks = await _database.trackDao.getAllForProfile(_profileId);
    for (final track in tracks) {
      await _pushCurriculumTrack.call({
        'profile_id': track.profileId,
        'track_id': track.id,
        'curriculum_id': track.curriculumId,
        'track_type': track.trackType,
        'is_active': track.isActive,
        'activated_at': track.activatedAt.toIso8601String(),
        'deactivated_at': track.deactivatedAt?.toIso8601String(),
        'pace_reset_date': track.paceResetDate?.toIso8601String(),
      });
    }
  }
}
