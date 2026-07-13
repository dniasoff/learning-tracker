import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
    SyncWriteFacade? syncFacade,
  }) : _database = database,
       _pushCurriculumTrack = pushCurriculumTrack,
       _trackRepository = trackRepository,
       _profileId = profileId,
       _syncFacade = syncFacade;

  final UserDatabase _database;
  final Future<void> Function(Map<String, dynamic>)? _pushCurriculumTrack;
  final TrackRepository _trackRepository;
  final int _profileId;
  // Facade for enqueuing study-day configs to the sync outbox (R3-5 fix).
  final SyncWriteFacade? _syncFacade;

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
      await _pushStudyDaysCloud(
        profileId: _profileId,
        curriculumId: CurriculumId.mishnayos,
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
    // Re-activate any retired track so _resolveTrackId finds state='active'.
    await _database.trackDao.activateTrack(curriculum, profileId: _profileId);
    final trackId = await _resolveTrackId(curriculum, _profileId);
    await _database.studyDayConfigDao.seedDefaults(
      profileId: _profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
    );
    await _pushStudyDaysCloud(
      profileId: _profileId,
      curriculumId: curriculum,
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
    // Re-activate any retired track so _resolveTrackId finds state='active'.
    await _database.trackDao.activateTrack(curriculum, profileId: profileId);
    final trackId = await _resolveTrackId(curriculum, profileId);
    await _database.studyDayConfigDao.seedDefaults(
      profileId: profileId,
      curriculumId: curriculum.storageKey,
      trackId: trackId,
    );
    await _pushStudyDaysCloud(
      profileId: profileId,
      curriculumId: curriculum,
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

  /// Archive a curriculum for the active profile — deactivates it while
  /// preserving its track configuration (goals/stages/point config/etc.)
  /// for possible reactivation later, via
  /// [ActiveCurriculumDao.archiveByProfile]. Use this for the "Archive
  /// (keep history)" UI action; use [deactivate] only where hard-deleting
  /// the config on deactivation is actually intended (AUD-profiles-01).
  ///
  /// Throws [LastActiveCurriculumException] when the profile has exactly one
  /// active curriculum (minimum-1 invariant).
  Future<void> archive(CurriculumId curriculum) async {
    final active = await _database.activeCurriculumDao
        .getActiveCurriculaByProfile(_profileId);
    if (active.length <= 1) {
      throw const LastActiveCurriculumException();
    }
    await _database.activeCurriculumDao.archiveByProfile(
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
            event:
                'CurriculumActivationService.getActiveCurricula: '
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
    // W3.22: trackType column dropped; UNIQUE is now {profileId, curriculumId}.
    // A profile has at most one track per curriculum — fetch by the new key.
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculum.storageKey) &
                    t.state.equals(TrackState.active.storageKey),
              )
              ..limit(1))
            .getSingleOrNull();
    return track?.id ?? 0;
  }

  /// Enqueue seeded study-day configs (all 7 default days) to the sync outbox.
  ///
  /// Mirrors [TrackCreationService._pushStudyDaysCloud]. Called after every
  /// [StudyDayConfigDao.seedDefaults] so a fresh device/restore receives the
  /// schedule via the normal OutboxProcessor drain cycle (R3-5 fix).
  Future<void> _pushStudyDaysCloud({
    required int profileId,
    required CurriculumId curriculumId,
    required int trackId,
  }) async {
    final facade = _syncFacade;
    if (facade == null) return;
    final now = DateTimeFactory.nowUtc().toIso8601String();
    for (var day = 1; day <= 7; day++) {
      await facade.pushStudyDayConfig({
        'profile_id': profileId,
        'curriculum_id': curriculumId.storageKey,
        'track_id': trackId,
        'day_of_week': day,
        'day_type': 'study',
        'updated_at': now,
      });
    }
  }

  /// Sync this profile's tracks to Firestore.
  Future<void> _syncToFirestore() async {
    try {
      await _syncTracksToFirestore();
    } catch (e) {
      // Silent fail for offline/auth issues — local DB is source of truth
    }
  }

  static const _trackCodec = TrackCodec();

  Future<void> _syncTracksToFirestore() async {
    if (_pushCurriculumTrack == null) return;
    final tracks = await _database.trackDao.getAllForProfile(_profileId);
    for (final track in tracks) {
      await _pushCurriculumTrack.call(
        _trackCodec.encode(
          TrackRow(
            profileId: track.profileId,
            trackId: track.id,
            curriculumId: track.curriculumId,
            state: track.state,
            stateChangedAt: track.stateChangedAt,
            activatedAt: track.activatedAt,
            paceResetDate: track.paceResetDate,
          ),
        ),
      );
    }
  }
}
