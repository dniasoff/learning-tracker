import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/study_day_config_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';

/// Service for managing curriculum activation/deactivation.
///
/// Scoped to a single profile — each profile on the account has its own
/// independent set of active curricula. The Firestore repository this service
/// depends on is constructed per active profile (ULID doc-id) by the provider,
/// so no profile id is threaded through its methods (AD-24).
///
/// ## Drift → Firestore rewiring (AD-23/AD-28)
///
/// This file lives under `domain/services/`, so it is forbidden from importing
/// `package:learning_tracker/data/firestore/...` or
/// `package:learning_tracker/data/repositories/...` directly. It reaches the
/// data-access ring only through feature-layer repository adapters that live
/// under `features/**/data/repositories/` — the dependency-direction gate
/// (`tool/check_dependency_direction.dart`) exempts exactly that path segment
/// and does not match these imports.
///
/// - [FirestoreCurriculumTrackRepositoryAdapter] (tracks feature) absorbs the
///   two Drift DAOs this service used to drive — `ActiveCurriculumDao` (the
///   "which curricula are active" queries + deactivate/archive guards) and
///   `TrackDao` (the track lifecycle) — onto the single `curriculum_tracks`
///   Firestore document, per the entity's doc comment. Its own class doc
///   comment explicitly records "option (b)": `CurriculumActivationService`
///   calling this adapter directly, since no abstract
///   `CurriculumTrackRepository` interface exists yet (its extraction is a
///   deferred future task, not a blocker for this change).
/// - [FirestoreStudyDayConfigRepositoryAdapter] (scheduler feature) replaces the
///   deleted `StudyDayConfigDao`/outbox push for seeding default study-day
///   configs; its class doc comment likewise notes a domain interface is still
///   to be extracted.
///
/// The Drift-era `UserDatabase`, `SyncWriteFacade`, `TrackCodec`, `TrackRow`
/// and `TrackState` symbols no longer exist; the direct-to-Firestore write model
/// makes the old sync-outbox/cloud-push steps (`_syncToFirestore`,
/// `_pushCurriculumTrack`, `_pushStudyDaysCloud`) obsolete — reads this change
/// cannot resolve now THROW, never fabricate, per the migration brief's D-E.
class CurriculumActivationService {
  CurriculumActivationService({
    required FirestoreCurriculumTrackRepositoryAdapter trackRepository,
    required FirestoreStudyDayConfigRepositoryAdapter studyDayConfigRepository,
  }) : _trackRepository = trackRepository,
       _studyDayConfigRepository = studyDayConfigRepository;

  final FirestoreCurriculumTrackRepositoryAdapter _trackRepository;
  final FirestoreStudyDayConfigRepositoryAdapter _studyDayConfigRepository;

  /// Initialize default active curricula for this profile if none exist.
  ///
  /// In Firestore, [FirestoreCurriculumTrackRepositoryAdapter.activateTrack]
  /// is the single create-or-reactivate entry point (it inserts if absent and
  /// re-activates from any non-active state), so seeding the first curriculum's
  /// defaults is just "activate it" + seed its study-day configs.
  Future<void> initialize() async {
    final active = await _trackRepository.countActiveTracks();
    if (active == 0) {
      await _trackRepository.activateTrack(CurriculumId.mishnayos);
      await _studyDayConfigRepository.initializeDefaults(
        CurriculumId.mishnayos,
      );
    }
  }

  /// Activate a curriculum for the active profile.
  ///
  /// Routes to
  /// [FirestoreCurriculumTrackRepositoryAdapter.activateTrack] (create-or-
  /// reactivate) and seeds this curriculum's default study-day configs via
  /// [FirestoreStudyDayConfigRepositoryAdapter.initializeDefaults], replacing
  /// the Drift `activateByProfile` + `initializeDefaultTracks` +
  /// `trackDao.activateTrack` + `seedDefaults` + outbox push sequence. The
  /// cloud-sync step itself is a deleted concept — Firestore writes are
  /// direct, so there is no `_syncToFirestore`/`_pushCurriculumTrack`
  /// equivalent to preserve.
  Future<void> activate(CurriculumId curriculum) async {
    await _trackRepository.activateTrack(curriculum);
    await _studyDayConfigRepository.initializeDefaults(curriculum);
  }

  /// Activate a curriculum for a specific profile (explicit override).
  ///
  /// In Firestore the profile is carried by the repository's collection path
  /// (the adapter is built per active profile by the provider), so an explicit
  /// profile id is no longer meaningful — AD-25 made a track IS its curriculum,
  /// and AD-24 made the profile ULID a constructor-level concern of the
  /// repository, not a per-call argument. This override is retained as a plain
  /// forwarder to [activate]; callers that relied on it for a different
  /// profile than the active one must re-scope to that profile's provider —
  /// there is no cross-profile write this service can perform without the
  /// owning repository instance, and inventing one would be a fabricated value.
  Future<void> activateForProfile(CurriculumId curriculum, int profileId) {
    // [profileId] is intentionally not used: there is no int profile id in the
    // Firestore model (it is a ULID carried by the adapter's path), so the only
    // honest behaviour is to activate for the already-scoped active profile.
    return activate(curriculum);
  }

  /// Deactivate a curriculum for the active profile.
  ///
  /// ### Semantics decision — soft retire, NOT hard-delete
  ///
  /// Both production callers invoke this method exclusively for the
  /// `choice == 'archive'` ("Archive — keep history") UI action:
  /// `track_management_body.dart:336` and `track_detail_screen.dart:996`, each
  /// inside `if (choice == 'archive')`. The "wipe / Delete and wipe history"
  /// action is routed to a *separate* method — `purgeTrackHistory` (the
  /// hard-delete path) — never to `deactivate`.
  ///
  /// Therefore `deactivate` means "stop showing this track but keep the
  /// history": it maps to the soft
  /// [FirestoreCurriculumTrackRepositoryAdapter.retireTrack], which preserves
  /// the track configuration (goals/stages/point config) for later
  /// reactivation via `activateTrack`. Routing it to the permanent-delete path
  /// instead would silently turn the keep-history "Archive" button into a wipe
  /// — exactly the silent behaviour change this migration round-trip
  /// forbids.
  ///
  /// Throws [LastActiveCurriculumException] when the profile has exactly one
  /// active curriculum (minimum-1 invariant). The underlying
  /// [FirestoreCurriculumTrackRepository.retireTrack] enforces that guard with
  /// a [StateError]; it is translated here so existing callers'
  /// `on LastActiveCurriculumException` handling keeps working.
  Future<void> deactivate(CurriculumId curriculum) async {
    try {
      await _trackRepository.retireTrack(curriculum);
    } on StateError {
      throw const LastActiveCurriculumException();
    }
  }

  /// Archive a curriculum for the active profile — deactivates it while
  /// preserving its track configuration (goals/stages/point config/etc.) for
  /// possible reactivation later.
  ///
  /// Routes to
  /// [FirestoreCurriculumTrackRepositoryAdapter.archiveTrack], whose own
  /// "don't drop this profile to zero active curricula" guard
  /// ([FirestoreCurriculumTrackRepository.archiveTrack]) is re-used; the
  /// resulting [StateError] is translated to [LastActiveCurriculumException]
  /// for caller compatibility, matching [deactivate].
  ///
  /// Throws [LastActiveCurriculumException] when the profile has exactly one
  /// active curriculum (minimum-1 invariant).
  Future<void> archive(CurriculumId curriculum) async {
    try {
      await _trackRepository.archiveTrack(curriculum);
    } on StateError {
      throw const LastActiveCurriculumException();
    }
  }

  /// Hard-delete ("wipe") a curriculum track and its dependent data.
  ///
  /// In Firestore, `curriculum_tracks` is `allow delete: if false` in
  /// `firestore.rules` — a client cannot delete the document directly, by
  /// design. Deletion must fan out across the sibling collections
  /// (`goals`, `stage_definitions`, `study_day_configs`,
  /// `curriculum_scopes`, `learning_order`, `profile_programs`) plus the
  /// document itself, so it is owned by the `deleteCurriculumTrack` Cloud
  /// Function. This is the in-service caller of that function via
  /// [FirestoreCurriculumTrackRepositoryAdapter.deleteTrackPermanently].
  ///
  /// AD-25: there is no integer track id in Firestore — a track IS its
  /// curriculum — so the deleted Drift `TrackDao.purgeHistory(int trackId)`
  /// signature is replaced with the curriculum-keyed one. This is the only
  /// permanent-delete surface this service exposes; [deactivate] is soft.
  Future<void> purgeTrackHistory(CurriculumId curriculum) {
    return _trackRepository.deleteTrackPermanently(curriculum);
  }

  /// Toggle a curriculum on or off for the active profile.
  Future<void> toggle(CurriculumId curriculum) async {
    final isActive = await _trackRepository.isActive(curriculum);
    if (isActive) {
      await deactivate(curriculum);
    } else {
      await activate(curriculum);
    }
  }

  /// Get list of currently active curricula for the active profile.
  Future<List<CurriculumId>> getActiveCurricula() async {
    final storageKeys = await _trackRepository.getActiveCurriculumIds();
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
    return _trackRepository.watchActiveCurriculumIds();
  }
}
