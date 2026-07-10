import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Concrete [MergeStore] implementation backed by Drift DAOs.
///
/// Dispatches each [MergeStore] operation to the appropriate DAO for the
/// given [EntityKind]. The DAO is responsible for the final SQLite write
/// so no Firestore types leak into this layer.
///
/// Kind → DAO mapping:
///   completion      → [CompletionEventDao]      (insertOrIgnore on natural key)
///   learner_profile → [ProfileDao]               (upsert by id)
///   track_config    → [TrackDao]                 (upsert by curriculum_id)
///   bookmark        → [BookmarkDao]              (upsert by curriculum_id + track_id)
///   settings        → [StageDao]                 (replace stages for curriculum)
///   stage_definition → [StageDao]               (upsert by curriculum_id + track_id + stage_order)
///   streak          → not routed here — [StreakEventMerger] uses [StreakEventLog] directly
///
/// Phase 3 of the sync architecture plan adds LWW symmetry: every merger
/// calls [persistUpdatedAt] after a successful apply, and [currentUpdatedAt]
/// reads back from the [SyncKv] table so [remoteIsNewer] is symmetric.
/// Within a ±5 s clock-skew window, [remoteIsNewer] falls back to the
/// Firestore server timestamp (`synced_at`) to break ties.
class DriftMergeStore implements MergeStore {
  /// Clock-skew window for the [remoteIsNewer] tie-breaker. When two
  /// devices' clocks differ by less than this, the server timestamp
  /// (`synced_at`) decides instead of the strict `remote > local`
  /// comparison on the client `updated_at`.
  static const Duration clockSkewTieBreakWindow = Duration(seconds: 5);
  DriftMergeStore(UserDatabase db, {AnalyticsService? analytics})
    : _db = db,
      _analytics = analytics;

  final UserDatabase _db;
  // W7.5: optional analytics — fires merge_row_skipped at every silent-skip site.
  final AnalyticsService? _analytics;

  // ── W7.5 telemetry helper ───────────────────────────────────────────────────

  /// Fire [AnalyticsEvent.syncMergeRowSkipped] on the injected analytics
  /// service.
  ///
  /// Silent skips occur when a Firestore row arrives malformed (missing
  /// required fields) or when a dependency is missing (e.g. bookmark arrives
  /// before its track). Each skip call closes the L2 gap — these were
  /// previously invisible in dashboards.
  void _fireSkipped({required String kind, required String reason}) {
    final future = _analytics?.logEvent(
      AnalyticsEvent.syncMergeRowSkipped,
      parameters: {'entity_kind': kind, 'reason': reason},
    );
    if (future != null) unawaited(future);
  }

  // ── currentUpdatedAt ────────────────────────────────────────────────────────

  /// Returns the persisted last-applied `updated_at` for `(kind, naturalKey)`.
  ///
  /// Phase 3: every LWW kind reads from the [SyncKv] table. The persisted
  /// value is written by [persistUpdatedAt] inside every merger's
  /// successful-apply branch. When no value has been recorded yet, returns
  /// `null` (callers treat that as "remote wins on first sync").
  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) {
    return _db.syncKvDao.get(kind, _scopedKey(profileId, naturalKey));
  }

  /// Returns the persisted Firestore `synced_at` server timestamp for
  /// `(kind, naturalKey)`. Used as the tie-breaker by [remoteIsNewer]
  /// inside the ±5 s clock-skew window.
  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) {
    return _db.syncKvDao.getSyncedAt(kind, _scopedKey(profileId, naturalKey));
  }

  /// Persist the remote `updated_at` (and optional Firestore `synced_at`)
  /// for `(kind, naturalKey)`. Called by every LWW merger after a
  /// successful [upsert].
  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) {
    return _db.syncKvDao.upsert(
      kind,
      _scopedKey(profileId, naturalKey),
      updatedAt,
      syncedAt: syncedAt,
    );
  }

  /// Phase-3 LWW gate. See [MergeStore.remoteIsNewer] for the rule order.
  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;

    final localUtc = localUpdatedAt.toUtc();
    final remoteUtc = remoteUpdatedAt.toUtc();
    final diff = remoteUtc.difference(localUtc).abs();

    // Outside the clock-skew window: strict `remote > local` wins; ties go
    // to local (matches the long-standing flapping-free behaviour).
    if (diff > clockSkewTieBreakWindow) {
      return remoteUtc.isAfter(localUtc);
    }

    // Inside the window: when BOTH sides carry a Firestore server timestamp,
    // it is the authoritative ordering for two already-pushed writes.
    if (remoteSyncedAt != null && localSyncedAt != null) {
      if (remoteSyncedAt.isAfter(localSyncedAt)) return true;
      if (localSyncedAt.isAfter(remoteSyncedAt)) return false;
      // Equal synced_at — fall through to the updated_at / convergence tie.
    }

    // D15: at least one side has no usable server timestamp — typically a
    // fresh LOCAL edit that has `updated_at` but no `synced_at` yet (it has
    // not been pushed). Do NOT blindly prefer remote here: that silently
    // clobbers a demonstrably-newer un-pushed local edit with an OLDER remote
    // value. Compare the client `updated_at` and keep the strictly-newer side.
    if (remoteUtc.isAfter(localUtc)) return true;
    if (localUtc.isAfter(remoteUtc)) return false;

    // The one true tie (equal `updated_at`, no decisive server timestamp) is
    // resolved by preferring remote so two devices that wrote the same value
    // at the same instant converge instead of bouncing.
    return true;
  }

  /// Compose the per-profile [SyncKv] entity key from [profileId] and the
  /// merger's per-kind natural key.
  ///
  /// The `(kind, entityKey)` primary key in [SyncKv] is global to the DB,
  /// not scoped per profile. Prefixing the natural key with `profileId|`
  /// keeps profiles isolated without adding a third column.
  static String _scopedKey(int profileId, String naturalKey) =>
      '$profileId|$naturalKey';

  // ── upsert ──────────────────────────────────────────────────────────────────

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    switch (kind) {
      case EntityKind.learnerProfile:
        await _upsertLearnerProfile(profileId, fields);

      case EntityKind.trackConfig:
        await _upsertTrack(profileId, fields);

      case EntityKind.bookmark:
        await _upsertBookmark(profileId, fields);

      case EntityKind.settings:
        // Settings upsert = replace all stage definitions for the curriculum.
        await _upsertSettings(profileId, fields);

      case EntityKind.stageDefinition:
        await _upsertStageDefinition(profileId, fields);

      case EntityKind.profileProgram:
        await _upsertProfileProgram(profileId, fields);

      case EntityKind.learningOrder:
        await _upsertLearningOrder(profileId, fields);

      default:
        // Unknown kind — no-op (the MergeRouter has already validated the kind).
        break;
    }
  }

  // ── insertIfAbsent ──────────────────────────────────────────────────────────

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {
    if (kind == EntityKind.completion) {
      await _insertCompletionIfAbsent(profileId, fields);
    }
    // Other kinds use upsert — insertIfAbsent is only meaningful for event logs.
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _insertCompletionIfAbsent(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final sefariaRef = fields['sefaria_ref'] as String?;
    final stageId =
        fields['stage_id'] as int? ??
        int.tryParse(fields['stage_id']?.toString() ?? '');
    final trackType = fields['track_type'] as String?;
    final eventTs = _parseDateTime(
      fields['completed_at'] ?? fields['event_timestamp'],
    );
    // track_id is optional — absent from legacy rows and from Firestore docs
    // written before Phase B; null is the correct fallback.
    final trackId =
        fields['track_id'] as int? ??
        int.tryParse(fields['track_id']?.toString() ?? '');
    // points defaults to 0 when absent (legacy rows pre-date this field).
    final points =
        fields['points'] as int? ??
        int.tryParse(fields['points']?.toString() ?? '') ??
        0;

    if (curriculumId == null ||
        sefariaRef == null ||
        stageId == null ||
        trackType == null ||
        eventTs == null) {
      // W7.5: fire telemetry for every silently-skipped completion row.
      _fireSkipped(kind: EntityKind.completion, reason: 'malformed_fields');
      return;
    }

    // H2: before inserting, check whether a tombstoned row already occupies
    // this natural key. If so, the remote is "more alive" than local — clear
    // the tombstone instead of inserting (INSERT OR IGNORE would silently
    // no-op and leave the tombstone in place).
    final tombstoned = await _db.completionEventDao
        .findTombstonedEventByNaturalKey(
          profileId: profileId,
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
        );
    if (tombstoned != null) {
      // Resurrect: clear the tombstone and adopt the incoming completion time.
      // The re-mark's timestamp (eventTs) differs from the tombstoned row's
      // original — matching on the natural key (not the timestamp) is what lets
      // this find the tombstone at all (D11).
      await _db.completionEventDao.clearTombstone(
        tombstoned.id,
        eventTimestamp: eventTs,
      );
      return;
    }

    await _db.completionEventDao.appendEvent(
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        trackId: Value(trackId),
        points: Value(points),
        eventTimestamp: eventTs,
      ),
    );
  }

  Future<void> _upsertLearnerProfile(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final remoteId =
        fields['profile_id'] as int? ??
        int.tryParse(fields['profile_id']?.toString() ?? '') ??
        profileId;
    final remoteAccountId =
        fields['account_id'] as int? ??
        int.tryParse(fields['account_id']?.toString() ?? '') ??
        0;
    final displayName = fields['display_name'] as String? ?? '';
    final mode = fields['mode'] as String? ?? 'adult';
    final avatarIndex =
        fields['avatar_index'] as int? ??
        int.tryParse(fields['avatar_index']?.toString() ?? '') ??
        0;
    final updatedAt =
        _parseDateTime(fields['updated_at']) ?? DateTimeFactory.nowUtc();
    final createdAt = _parseDateTime(fields['created_at']) ?? updatedAt;

    final existing = await _db.profileDao.getProfileById(remoteId);
    if (existing == null) {
      // Bug 1: the remote `account_id` is the cloud account row id and almost
      // never matches the local autoincrement `accounts.id` (they are minted
      // independently per device). Inserting the profile with the raw remote
      // id violates the learner_profiles → accounts FK → SqliteException(787),
      // which previously aborted the whole launch pull and bounced the user
      // to the first-launch splash. Resolve the FK to a LOCAL account row that
      // is guaranteed to exist before inserting.
      final accountId = await _resolveLocalAccountId(
        remoteAccountId: remoteAccountId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      await _db
          .into(_db.learnerProfiles)
          .insertOnConflictUpdate(
            LearnerProfilesCompanion.insert(
              id: Value(remoteId),
              accountId: accountId,
              displayName: displayName,
              mode: mode,
              avatarIndex: Value(avatarIndex),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
    } else {
      await (_db.update(
        _db.learnerProfiles,
      )..where((t) => t.id.equals(remoteId))).write(
        LearnerProfilesCompanion(
          displayName: Value(displayName),
          mode: Value(mode),
          avatarIndex: Value(avatarIndex),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }

  /// Resolve a LOCAL `accounts.id` that is guaranteed to exist, so the
  /// learner_profiles → accounts FK can never fail (Bug 1).
  ///
  /// Resolution order:
  ///   1. The referenced [remoteAccountId] already exists locally → use it.
  ///   2. Exactly one local account exists → remap the profile onto it. This is
  ///      the common case: a device hosts a single signed-in account whose
  ///      autoincrement id differs from the cloud account id.
  ///   3. No usable account exists yet (the accounts row has not been seeded /
  ///      restored) → seed a placeholder `accounts` row carrying
  ///      [remoteAccountId] so the FK is satisfiable. The real account row
  ///      (email/tier/firebaseUid) is reconciled by the auth/bootstrap path;
  ///      this seed only exists to keep the profile insert from crashing the
  ///      launch pull. When [remoteAccountId] is 0/absent, a fresh
  ///      autoincrement id is minted instead.
  Future<int> _resolveLocalAccountId({
    required int remoteAccountId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    // 1. Exact match — the FK target already exists.
    if (remoteAccountId > 0) {
      final exact = await _db.userProfileDao.getUserProfileById(
        remoteAccountId,
      );
      if (exact != null) return exact.id;
    }

    // 2. Single local account — remap onto it (autoincrement id ≠ cloud id).
    final accounts = await _db.userProfileDao.getAllUserProfiles();
    if (accounts.length == 1) return accounts.first.id;
    if (accounts.isNotEmpty) {
      // Multiple accounts on the device and no exact match: prefer a cloud-born
      // row (sync only happens for cloud accounts) to avoid binding the synced
      // profile to an unrelated local-born account.
      final cloudBorn = accounts.where(
        (a) => a.accountTier == UserTier.cloudBorn,
      );
      return (cloudBorn.isNotEmpty ? cloudBorn.first : accounts.first).id;
    }

    // 3. No account row at all — seed a placeholder so the FK holds. Carry the
    // remote id when present so a later exact match reuses it; otherwise let
    // SQLite mint a fresh autoincrement id.
    final seed = AccountsCompanion.insert(
      id: remoteAccountId > 0 ? Value(remoteAccountId) : const Value.absent(),
      email: 'account-$remoteAccountId@sync.placeholder',
      tier: UserTier.cloudBorn.dbValue,
      displayName: '',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    return _db.into(_db.accounts).insert(seed);
  }

  Future<void> _upsertTrack(int profileId, Map<String, dynamic> fields) async {
    final curriculumId = fields['curriculum_id'] as String?;
    if (curriculumId == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.trackConfig,
        reason: 'missing_curriculum_id',
      );
      return;
    }

    // W3.22: trackType dropped. W3.28: use state enum.
    final state =
        fields['state'] as String? ??
        ((fields['is_active'] as bool? ?? true)
            ? 'active'
            : 'retired'); // back-compat shim
    final activatedAt = _parseDateTime(fields['activated_at']);
    if (activatedAt == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.trackConfig,
        reason: 'missing_activated_at',
      );
      return;
    }
    final stateChangedAt =
        _parseDateTime(fields['state_changed_at']) ??
        _parseDateTime(fields['deactivated_at']) ??
        activatedAt;
    final paceResetDate = _parseDateTime(fields['pace_reset_date']);

    final existing =
        await (_db.select(_db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              state: Value(state),
              stateChangedAt: stateChangedAt,
              activatedAt: activatedAt,
              paceResetDate: Value(paceResetDate),
            ),
          );
    } else {
      await (_db.update(
        _db.curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          state: Value(state),
          stateChangedAt: Value(stateChangedAt),
          activatedAt: Value(activatedAt),
          paceResetDate: Value(paceResetDate),
        ),
      );
    }
  }

  Future<void> _upsertBookmark(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    // Dual-key: the live writers (BookmarkEntity.toFirestore,
    // LocalDataUploadService, TrackCreationService) persist the ref under
    // `content_item_id`, while the codec / legacy docs use `sefaria_ref`. Read
    // BOTH or every live-written bookmark is dropped here as 'malformed_fields'
    // and never replicates cross-device (the value is identical under either
    // key). Rules allow both, so this was invisible to the rules/contract tests.
    final sefariaRef =
        (fields['sefaria_ref'] ?? fields['content_item_id']) as String?;
    final updatedAt = _parseDateTime(fields['updated_at']);

    if (curriculumId == null || sefariaRef == null || updatedAt == null) {
      // W7.5
      _fireSkipped(kind: EntityKind.bookmark, reason: 'malformed_fields');
      return;
    }

    // Bookmarks in the DB are keyed by trackId (FK). One track per
    // {profileId, curriculumId}. Find the track row to get the trackId.
    final track =
        await (_db.select(_db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId),
            ))
            .getSingleOrNull();

    if (track == null) {
      // Track not yet synced — skip the bookmark; it will re-arrive when
      // the listener fires after the track is synced.
      // W7.5: this is a non-malformed skip (dependency ordering), fire telemetry.
      _fireSkipped(kind: EntityKind.bookmark, reason: 'track_not_yet_synced');
      return;
    }

    await _db.bookmarkDao.upsertBookmarkByProfile(
      curriculumId: curriculumId,
      trackId: track.id,
      sefariaRef: sefariaRef,
      updatedAt: updatedAt,
      profileId: profileId,
    );
  }

  Future<void> _upsertSettings(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    // Settings document shape: { curriculum_id, track_id, stages: [...], updated_at }
    final curriculumId = fields['curriculum_id'] as String?;
    if (curriculumId == null) {
      // W7.5
      _fireSkipped(kind: EntityKind.settings, reason: 'missing_curriculum_id');
      return;
    }

    final stagesList = fields['stages'] as List<dynamic>?;
    if (stagesList == null || stagesList.isEmpty) {
      // W7.5: no stages to merge — likely a partial settings doc.
      _fireSkipped(kind: EntityKind.settings, reason: 'empty_stages_list');
      return;
    }

    final defaultTrackId = fields['track_id'] as int? ?? 0;

    // Bug 3: resolve the LOCAL track id from (profile, curriculum) so stage
    // rows under a tutored mirror bind to the mirror's local track id rather
    // than the remote id (which never matches). No-op for own-data sync.
    final localTrack = await _db.trackDao.getTrackByProfileAndCurriculum(
      profileId,
      curriculumId,
    );

    // AUD-core-sync-07: stage_definitions.trackId is a FK into
    // curriculum_tracks. If this settings snapshot merges before its track's
    // own snapshot (independent per-collection listeners, or a first-launch
    // pull racing ahead), replaceStagesForCurriculum's insert would throw a
    // FK-constraint violation (SqliteException 787) inside its transaction()
    // — rolling back and aborting the ENTIRE settings channel merge for this
    // page, not just this one document. Skip instead; the next pull
    // re-merges idempotently once the track exists (mirrors the guard
    // already applied to bookmark/gamification_settings/study_day_config).
    final resolvedTrackId = localTrack?.id ?? defaultTrackId;
    if (localTrack == null &&
        await _db.trackDao.getById(resolvedTrackId) == null) {
      _fireSkipped(kind: EntityKind.settings, reason: 'track_not_yet_synced');
      return;
    }

    final companions = stagesList.cast<Map<String, dynamic>>().map((s) {
      final trackId =
          localTrack?.id ?? (s['track_id'] as int? ?? defaultTrackId);
      final stageOrder = s['stage_order'] as int? ?? 0;
      final stageName = s['stage_name'] as String? ?? '';
      final isDefault = s['is_default'] as bool? ?? false;
      // W3.27: prefer pre-encoded JSON schedule; fall back to quartet fields.
      final schedule = _encodeSchedule(s);
      final updatedAt =
          _parseDateTime(s['updated_at']) ?? DateTimeFactory.nowUtc();

      return StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        stageOrder: stageOrder,
        stageName: stageName,
        isDefault: Value(isDefault),
        schedule: Value(schedule),
        updatedAt: Value(updatedAt),
      );
    }).toList();

    await _db.stageDao.replaceStagesForCurriculum(curriculumId, companions);
  }

  Future<void> _upsertStageDefinition(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final remoteTrackId =
        fields['track_id'] as int? ??
        int.tryParse(fields['track_id']?.toString() ?? '');
    final stageOrder =
        fields['stage_order'] as int? ??
        int.tryParse(fields['stage_order']?.toString() ?? '');
    final stageName = fields['stage_name'] as String? ?? '';

    if (curriculumId == null || remoteTrackId == null || stageOrder == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.stageDefinition,
        reason: 'missing_key_fields',
      );
      return;
    }

    // Bug 3: resolve the LOCAL track id from (profile, curriculum). The stored
    // track_id is the remote id; under a tutored mirror the track row was
    // re-inserted with a different local autoincrement id, so binding stages
    // to the remote id leaves getStagesByTrack(localTrackId) empty and the
    // scheduler projection computes nothing. Resolving by (profile, curriculum)
    // realigns the FK and is a no-op for own-data sync.
    final localTrack = await _db.trackDao.getTrackByProfileAndCurriculum(
      profileId,
      curriculumId,
    );
    final trackId = localTrack?.id ?? remoteTrackId;

    // AUD-core-sync-07: guard against this row's track not having synced
    // locally yet — inserting would violate the stage_definitions →
    // curriculum_tracks FK (SqliteException 787) and abort merging the
    // whole page. Skip; the next pull re-merges idempotently once the
    // track exists (mirrors the guard already applied to
    // bookmark/gamification_settings/study_day_config).
    if (localTrack == null && await _db.trackDao.getById(trackId) == null) {
      _fireSkipped(
        kind: EntityKind.stageDefinition,
        reason: 'track_not_yet_synced',
      );
      return;
    }

    final isDefault = fields['is_default'] as bool? ?? false;
    // W3.27: prefer pre-encoded JSON schedule; fall back to quartet fields.
    final schedule = _encodeSchedule(fields);
    final updatedAt =
        _parseDateTime(fields['updated_at']) ?? DateTimeFactory.nowUtc();

    final existing =
        await (_db.select(_db.stageDefinitions)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId) &
                  t.trackId.equals(trackId) &
                  t.stageOrder.equals(stageOrder),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: stageOrder,
          stageName: stageName,
          isDefault: Value(isDefault),
          schedule: Value(schedule),
          updatedAt: Value(updatedAt),
        ),
      );
    } else {
      await (_db.update(
        _db.stageDefinitions,
      )..where((t) => t.id.equals(existing.id))).write(
        StageDefinitionsCompanion(
          stageName: Value(stageName),
          isDefault: Value(isDefault),
          schedule: Value(schedule),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }

  /// Encode schedule spec from raw Firestore fields into the JSON column format.
  ///
  /// Accepts either a pre-encoded `schedule` JSON string (new shape, W3.27)
  /// or the legacy quartet (schedule_type, delay_days, days_of_week,
  /// rolling_window_size). Returns a JSON string compatible with ScheduleSpec.
  static String _encodeSchedule(Map<String, dynamic> s) {
    // New shape: schedule is already a JSON string or map.
    final raw = s['schedule'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw is Map) {
      return jsonEncode(raw);
    }
    // Legacy quartet → JSON.
    final scheduleType = s['schedule_type'] as String? ?? 'delay';
    final delayDays = (s['delay_days'] as num?)?.toInt() ?? 0;
    final daysOfWeek = s['days_of_week'];
    final rollingWindowSize = s['rolling_window_size'] as int?;

    switch (scheduleType) {
      case 'days_of_week':
        List<int> days;
        if (daysOfWeek is String) {
          try {
            final decoded = jsonDecode(daysOfWeek);
            days = (decoded as List).cast<int>();
          } catch (_) {
            days = const [];
          }
        } else if (daysOfWeek is List) {
          days = daysOfWeek.cast<int>();
        } else {
          days = const [];
        }
        return jsonEncode({'type': 'days_of_week', 'days': days});
      case 'rolling_window':
        return jsonEncode({
          'type': 'rolling_window',
          'window_size': rollingWindowSize ?? 7,
        });
      default:
        return jsonEncode({'type': 'delay', 'delay_days': delayDays});
    }
  }

  Future<void> _upsertProfileProgram(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final rawProgramId = fields['program_id'];
    final programId = rawProgramId is int
        ? rawProgramId
        : int.tryParse(rawProgramId?.toString() ?? '');
    if (curriculumId == null || programId == null) return;

    final rawProfileId = fields['profile_id'];
    final resolvedProfileId = rawProfileId is int
        ? rawProfileId
        : int.tryParse(rawProfileId?.toString() ?? '') ?? profileId;

    final trackingStartDate = _parseDateTime(fields['tracking_start_date']);
    final trackingStartRef = fields['tracking_start_ref'] as String?;

    await _db.profileProgramDao.setProfileProgram(
      profileId: resolvedProfileId,
      curriculumType: curriculumId,
      programId: programId,
      trackingStartDate: trackingStartDate,
      trackingStartRef: trackingStartRef,
    );
  }

  Future<void> _upsertLearningOrder(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final sefariaRef = fields['sefaria_ref'] as String?;
    final userSortOrder =
        fields['user_sort_order'] as int? ??
        int.tryParse(fields['user_sort_order']?.toString() ?? '');
    final updatedAt = _parseDateTime(fields['updated_at']);

    if (curriculumId == null || sefariaRef == null || userSortOrder == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.learningOrder,
        reason: 'missing_key_fields',
      );
      return;
    }
    final ts = updatedAt ?? DateTimeFactory.nowUtc();

    await _db.learningOrderDao.upsertLearningOrderIfNewer(
      LearningOrderCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        userSortOrder: userSortOrder,
        updatedAt: Value(ts),
      ),
      updatedAt: ts,
    );
  }

  // ── Shared parse helpers ────────────────────────────────────────────────────

  /// Delegate to [FirestoreCodec.parseDateTime] — centralised timestamp
  /// parsing handles DateTime, String (ISO-8601), int (Unix seconds), and
  /// Map `{'seconds': int}` (Timestamp JSON).
  static DateTime? _parseDateTime(Object? raw) =>
      FirestoreCodec.parseDateTime(raw);
}
