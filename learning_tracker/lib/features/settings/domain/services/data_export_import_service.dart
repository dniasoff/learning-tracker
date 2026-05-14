import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Result of validating an import file.
class ImportPreview {
  const ImportPreview({
    required this.completionCount,
    required this.goalCount,
    required this.stageCount,
    required this.streakCount,
    required this.pointConfigCount,
    required this.bookmarkCount,
    required this.learningOrderCount,
    required this.curriculumTrackCount,
    required this.userProfileCount,
    required this.exportedAt,
    required this.appVersion,
  });

  final int completionCount;
  final int goalCount;
  final int stageCount;
  final int streakCount;
  final int pointConfigCount;
  final int bookmarkCount;
  final int learningOrderCount;
  final int curriculumTrackCount;
  final int userProfileCount;
  final String exportedAt;
  final String appVersion;

  int get totalRecords =>
      completionCount +
      goalCount +
      stageCount +
      streakCount +
      pointConfigCount +
      bookmarkCount +
      learningOrderCount +
      curriculumTrackCount +
      userProfileCount;
}

/// Service for exporting and importing user data as JSON.
///
/// Export format: `schemaV1` — all 21 user-DB tables, profileId on every
/// row, no PII (omits `firebaseUid`, `email`, `passwordHash`).
/// Import is per-profile and does not wipe accounts owned by other profiles.
///
/// Tables exported (user data; system-transit tables SyncQueue,
/// TextDownloadStatuses, and Outbox are intentionally excluded):
///   accounts, learnerProfiles, curriculumTracks, curriculumScopes,
///   profilePrograms, stageDefinitions, pointConfigs, studyDayConfigs,
///   completions, completionEvents, dailyPlans, learningLedger,
///   bookmarks, learningOrder, trackLearningOrder, goals, streaks,
///   streakEvents.
class DataExportImportService {
  DataExportImportService({
    required UserDatabase database,
    Future<String> Function()? appVersionFetcher,
  }) : _database = database,
       _appVersionFetcher =
           appVersionFetcher ??
           (() async {
             final info = await PackageInfo.fromPlatform();
             return info.version;
           });

  final UserDatabase _database;
  final Future<String> Function() _appVersionFetcher;

  static const String _formatVersion = 'schemaV1';

  /// Sections required for a valid import file.
  static const List<String> _requiredSections = [
    'completions',
    'goals',
    'stageDefinitions',
    'streaks',
    'pointConfigs',
    'bookmarks',
    'learningOrder',
    'curriculumTracks',
    'userProfiles',
  ];

  /// Exports all user data to a JSON string.
  ///
  /// Omits PII (`firebaseUid`, `email`, `passwordHash`).
  /// Every row carries `profileId` (or `accountId` for `learnerProfiles`).
  Future<String> exportData() async {
    final appVersion = await _appVersionFetcher();

    // --- Accounts (no PII) ---
    final accounts = await _database.userProfileDao.getAllUserProfiles();

    // --- Learner profiles ---
    final learnerProfiles = await _database
        .select(_database.learnerProfiles)
        .get();

    // --- Curriculum tracks ---
    final curriculumTracks = await _database
        .select(_database.curriculumTracks)
        .get();

    // --- Curriculum scopes ---
    final curriculumScopes = await _database
        .select(_database.curriculumScopes)
        .get();

    // --- Profile programs ---
    final profilePrograms = await _database
        .select(_database.profilePrograms)
        .get();

    // --- Stage definitions ---
    final stages = await _database.select(_database.stageDefinitions).get();

    // --- Point configs ---
    final pointConfigs = await _database.select(_database.pointConfigs).get();

    // --- Study day configs ---
    final studyDayConfigs = await _database
        .select(_database.studyDayConfigs)
        .get();

    // --- Completions (cross-profile) ---
    final completions = await _database.completionDao
        .internalGetAllCompletionsCrossProfile(
          scope: CrossProfileScope.dataExport,
        );

    // --- Completion events (cross-profile via direct query) ---
    final completionEvents = await _database
        .select(_database.completionEvents)
        .get();

    // --- Daily plans ---
    final dailyPlans = await _database.select(_database.dailyPlans).get();

    // --- Learning ledger ---
    final learningLedger = await _database
        .select(_database.learningLedger)
        .get();

    // --- Bookmarks ---
    final bookmarks = await _database.bookmarkDao.getAllBookmarks();

    // --- Learning order ---
    final learningOrders = await _database.learningOrderDao
        .getAllLearningOrders();

    // --- Track learning order ---
    final trackLearningOrder = await _database
        .select(_database.trackLearningOrder)
        .get();

    // --- Goals ---
    final goals = await _database.goalDao.getAllGoals();

    // --- Streaks (cross-profile) ---
    final streaks = await _database.select(_database.streaks).get();

    // --- Streak events ---
    final streakEvents = await _database.select(_database.streakEvents).get();

    final data = <String, dynamic>{
      'formatVersion': _formatVersion,
      'exportedAt': DateTimeFactory.nowLocal().toIso8601String(),
      'appVersion': appVersion,

      // Accounts — PII stripped: no firebaseUid, no email, no passwordHash.
      'userProfiles': accounts
          .map(
            (u) => {
              'id': u.id,
              'profileId': u.id,
              'displayName': u.displayName,
              'tier': u.tier,
              'userMode': u.userMode,
              'createdAt': u.createdAt.toIso8601String(),
              'updatedAt': u.updatedAt.toIso8601String(),
            },
          )
          .toList(),

      'learnerProfiles': learnerProfiles
          .map(
            (p) => {
              'id': p.id,
              'accountId': p.accountId,
              'displayName': p.displayName,
              'mode': p.mode,
              'avatarIndex': p.avatarIndex,
              'createdAt': p.createdAt.toIso8601String(),
              'updatedAt': p.updatedAt.toIso8601String(),
            },
          )
          .toList(),

      'curriculumTracks': curriculumTracks
          .map(
            (t) => {
              'id': t.id,
              'profileId': t.profileId,
              'curriculumId': t.curriculumId,
              'trackType': t.trackType,
              'isActive': t.isActive,
              'activatedAt': t.activatedAt.toIso8601String(),
              'deactivatedAt': t.deactivatedAt?.toIso8601String(),
              'paceResetDate': t.paceResetDate?.toIso8601String(),
              'deletedAt': t.deletedAt?.toIso8601String(),
            },
          )
          .toList(),

      'curriculumScopes': curriculumScopes
          .map(
            (s) => {
              'id': s.id,
              'profileId': s.profileId,
              'curriculumId': s.curriculumId,
              'trackId': s.trackId,
              'scopeLevel': s.scopeLevel,
              'scopeValue': s.scopeValue,
              'createdAt': s.createdAt.toIso8601String(),
            },
          )
          .toList(),

      'profilePrograms': profilePrograms
          .map(
            (p) => {
              'id': p.id,
              'profileId': p.profileId,
              'curriculumType': p.curriculumType,
              'programId': p.programId,
              'trackingStartDate': p.trackingStartDate?.toIso8601String(),
              'trackingStartRef': p.trackingStartRef,
            },
          )
          .toList(),

      'stageDefinitions': stages
          .map(
            (s) => {
              'id': s.id,
              'profileId': s.profileId,
              'curriculumId': s.curriculumId,
              'trackId': s.trackId,
              'stageOrder': s.stageOrder,
              'stageName': s.stageName,
              'delayDays': s.delayDays,
              'isDefault': s.isDefault,
              'scheduleType': s.scheduleType,
              'daysOfWeek': s.daysOfWeek,
              'rollingWindowSize': s.rollingWindowSize,
            },
          )
          .toList(),

      'pointConfigs': pointConfigs
          .map(
            (p) => {
              'id': p.id,
              'profileId': p.profileId,
              'curriculumId': p.curriculumId,
              'trackId': p.trackId,
              'stageOrder': p.stageOrder,
              'points': p.points,
            },
          )
          .toList(),

      'studyDayConfigs': studyDayConfigs
          .map(
            (c) => {
              'profileId': c.profileId,
              'curriculumId': c.curriculumId,
              'trackId': c.trackId,
              'dayOfWeek': c.dayOfWeek,
              'dayType': c.dayType,
              'updatedAt': c.updatedAt.toIso8601String(),
            },
          )
          .toList(),

      'completions': completions
          .map(
            (c) => {
              'id': c.id,
              'profileId': c.profileId,
              'curriculumId': c.curriculumId,
              'sefariaRef': c.sefariaRef,
              'stageId': c.stageId,
              'trackType': c.trackType,
              'trackId': c.trackId,
              'completedAt': c.completedAt.toIso8601String(),
              'points': c.points,
            },
          )
          .toList(),

      'completionEvents': completionEvents
          .map(
            (e) => {
              'id': e.id,
              'profileId': e.profileId,
              'curriculumId': e.curriculumId,
              'sefariaRef': e.sefariaRef,
              'stageId': e.stageId,
              'trackType': e.trackType,
              'eventTimestamp': e.eventTimestamp.toIso8601String(),
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),

      'dailyPlans': dailyPlans
          .map(
            (p) => {
              'id': p.id,
              'profileId': p.profileId,
              'curriculumId': p.curriculumId,
              'planDate': p.planDate.toIso8601String(),
              'sefariaRef': p.sefariaRef,
              'stageOrder': p.stageOrder,
              'stageDefinitionId': p.stageDefinitionId,
              'trackId': p.trackId,
              'trackLabel': p.trackLabel,
              'priority': p.priority,
              'isOverdue': p.isOverdue,
              'reason': p.reason,
              'stageName': p.stageName,
              'estimatedEffortMinutes': p.estimatedEffortMinutes,
              'sortOrder': p.sortOrder,
              'createdAt': p.createdAt.toIso8601String(),
            },
          )
          .toList(),

      'learningLedger': learningLedger
          .map(
            (e) => {
              'id': e.id,
              'profileId': e.profileId,
              'ulid': e.ulid,
              'curriculumId': e.curriculumId,
              'entryScope': e.entryScope,
              'unitIdentifier': e.unitIdentifier,
              'unitDisplayNameHe': e.unitDisplayNameHe,
              'unitDisplayNameEn': e.unitDisplayNameEn,
              'trackType': e.trackType,
              'trackId': e.trackId,
              'completedAt': e.completedAt.toIso8601String(),
              'completionNumber': e.completionNumber,
              'markedBy': e.markedBy,
              'isManual': e.isManual,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),

      'bookmarks': bookmarks
          .map(
            (b) => {
              'id': b.id,
              'profileId': b.profileId,
              'curriculumId': b.curriculumId,
              'trackId': b.trackId,
              'sefariaRef': b.sefariaRef,
              'updatedAt': b.updatedAt.toIso8601String(),
            },
          )
          .toList(),

      'learningOrder': learningOrders
          .map(
            (l) => {
              'id': l.id,
              'profileId': l.profileId,
              'curriculumId': l.curriculumId,
              'sefariaRef': l.sefariaRef,
              'userSortOrder': l.userSortOrder,
              'updatedAt': l.updatedAt.toIso8601String(),
            },
          )
          .toList(),

      'trackLearningOrder': trackLearningOrder
          .map(
            (t) => {
              'id': t.id,
              'trackId': t.trackId,
              'sefariaRef': t.sefariaRef,
              'sortOrder': t.sortOrder,
            },
          )
          .toList(),

      'goals': goals
          .map(
            (g) => {
              'id': g.id,
              'profileId': g.profileId,
              'curriculumId': g.curriculumId,
              'trackId': g.trackId,
              'targetPercent': g.targetPercent,
              'targetDate': g.targetDate?.toIso8601String(),
              'description': g.description,
              'dateType': g.dateType,
              'goalType': g.goalType,
              'paceValue': g.paceValue,
              'pacePeriod': g.pacePeriod,
              'paceGranularity': g.paceGranularity,
              'createdAt': g.createdAt.toIso8601String(),
              'updatedAt': g.updatedAt.toIso8601String(),
            },
          )
          .toList(),

      'streaks': streaks
          .map(
            (s) => {
              'id': s.id,
              'profileId': s.profileId,
              'currentStreak': s.currentStreak,
              'maxStreak': s.maxStreak,
              'lastCompletionDate': s.lastCompletionDate?.toIso8601String(),
              'graceUsedDate': s.graceUsedDate?.toIso8601String(),
              'gracePeriodDays': s.gracePeriodDays,
            },
          )
          .toList(),

      'streakEvents': streakEvents
          .map(
            (e) => {
              'id': e.id,
              'profileId': e.profileId,
              'eventType': e.eventType,
              'dayUtc': e.dayUtc.toIso8601String(),
              'eventTimestamp': e.eventTimestamp.toIso8601String(),
              'clientDeviceId': e.clientDeviceId,
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Validates a JSON string and returns an [ImportPreview].
  ///
  /// Throws [FormatException] if the JSON is malformed or missing
  /// required sections.
  ImportPreview validateAndPreview(String jsonString) {
    final Map<String, dynamic> data;
    try {
      data = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('Invalid JSON format');
    }

    // Check format version
    if (!data.containsKey('formatVersion')) {
      throw const FormatException('Missing formatVersion field');
    }

    // Check all required sections exist and are lists
    for (final section in _requiredSections) {
      if (!data.containsKey(section)) {
        throw FormatException('Missing required section: $section');
      }
      if (data[section] is! List) {
        throw FormatException('Section "$section" must be a list');
      }
    }

    return ImportPreview(
      completionCount: (data['completions'] as List).length,
      goalCount: (data['goals'] as List).length,
      stageCount: (data['stageDefinitions'] as List).length,
      streakCount: (data['streaks'] as List).length,
      pointConfigCount: (data['pointConfigs'] as List).length,
      bookmarkCount: (data['bookmarks'] as List).length,
      learningOrderCount: (data['learningOrder'] as List).length,
      curriculumTrackCount: (data['curriculumTracks'] as List).length,
      userProfileCount: (data['userProfiles'] as List).length,
      exportedAt: data['exportedAt'] as String? ?? 'unknown',
      appVersion: data['appVersion'] as String? ?? 'unknown',
    );
  }

  /// Imports data from a JSON string, replacing all existing data.
  ///
  /// Per-profile import: deletes all existing rows and re-inserts from the
  /// export payload. Does not hard-delete accounts not present in the export
  /// (accounts are the identity anchor — they are upserted by displayName).
  ///
  /// Runs in a transaction — all or nothing. Throws on failure
  /// and rolls back all changes.
  Future<void> importData(String jsonString) async {
    final data = json.decode(jsonString) as Map<String, dynamic>;

    // Validate first
    validateAndPreview(jsonString);

    await _database.transaction(() async {
      // Clear existing user data (order: FK children before parents)
      await _database.delete(_database.streakEvents).go();
      await _database.delete(_database.streaks).go();
      await _database.delete(_database.completionEvents).go();
      await _database.delete(_database.completions).go();
      await _database.delete(_database.learningLedger).go();
      await _database.delete(_database.dailyPlans).go();
      await _database.delete(_database.trackLearningOrder).go();
      await _database.delete(_database.learningOrder).go();
      await _database.delete(_database.bookmarks).go();
      await _database.delete(_database.goals).go();
      await _database.delete(_database.studyDayConfigs).go();
      await _database.delete(_database.pointConfigs).go();
      await _database.delete(_database.stageDefinitions).go();
      await _database.delete(_database.profilePrograms).go();
      await _database.delete(_database.curriculumScopes).go();
      await _database.delete(_database.curriculumTracks).go();
      await _database.delete(_database.learnerProfiles).go();
      await _database.delete(_database.accounts).go();

      // --- Import accounts (userProfiles) ---
      // Preserve original IDs so that all profileId FKs in other tables
      // remain valid without remapping. No PII: email is a placeholder;
      // real email/firebaseUid are re-hydrated from the cloud on next sign-in.
      for (final u in data['userProfiles'] as List) {
        final map = u as Map<String, dynamic>;
        final originalId = map['id'] as int? ?? 0;
        await _database
            .into(_database.accounts)
            .insert(
              AccountsCompanion(
                id: Value(originalId),
                email: Value('restored-$originalId.placeholder'),
                tier: Value((map['tier'] as String?) ?? 'localBorn'),
                displayName: Value(map['displayName'] as String),
                userMode: Value(map['userMode'] as String),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
                updatedAt: Value(DateTime.parse(map['updatedAt'] as String)),
              ),
            );
      }

      // --- Import learner profiles ---
      for (final p in (data['learnerProfiles'] as List? ?? [])) {
        final map = p as Map<String, dynamic>;
        await _database
            .into(_database.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: map['accountId'] as int,
                displayName: map['displayName'] as String,
                mode: map['mode'] as String,
                avatarIndex: Value(map['avatarIndex'] as int? ?? 0),
                createdAt: DateTime.parse(map['createdAt'] as String),
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }

      // --- Import curriculum tracks ---
      for (final t in data['curriculumTracks'] as List) {
        final map = t as Map<String, dynamic>;
        await _database
            .into(_database.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackType: map['trackType'] as String,
                isActive: Value(map['isActive'] as bool? ?? true),
                activatedAt: DateTime.parse(map['activatedAt'] as String),
                deactivatedAt: Value(
                  map['deactivatedAt'] != null
                      ? DateTime.parse(map['deactivatedAt'] as String)
                      : null,
                ),
                paceResetDate: Value(
                  map['paceResetDate'] != null
                      ? DateTime.parse(map['paceResetDate'] as String)
                      : null,
                ),
                deletedAt: Value(
                  map['deletedAt'] != null
                      ? DateTime.parse(map['deletedAt'] as String)
                      : null,
                ),
              ),
            );
      }

      // --- Import curriculum scopes ---
      for (final s in (data['curriculumScopes'] as List? ?? [])) {
        final map = s as Map<String, dynamic>;
        await _database
            .into(_database.curriculumScopes)
            .insert(
              CurriculumScopesCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int,
                scopeLevel: map['scopeLevel'] as int,
                scopeValue: map['scopeValue'] as String,
                createdAt: DateTime.parse(map['createdAt'] as String),
              ),
            );
      }

      // --- Import profile programs ---
      for (final p in (data['profilePrograms'] as List? ?? [])) {
        final map = p as Map<String, dynamic>;
        await _database
            .into(_database.profilePrograms)
            .insert(
              ProfileProgramsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumType: map['curriculumType'] as String,
                programId: map['programId'] as int,
                trackingStartDate: Value(
                  map['trackingStartDate'] != null
                      ? DateTime.parse(map['trackingStartDate'] as String)
                      : null,
                ),
                trackingStartRef: Value(map['trackingStartRef'] as String?),
              ),
            );
      }

      // --- Import stage definitions ---
      for (final s in data['stageDefinitions'] as List) {
        final map = s as Map<String, dynamic>;
        await _database
            .into(_database.stageDefinitions)
            .insert(
              StageDefinitionsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                stageOrder: map['stageOrder'] as int,
                stageName: map['stageName'] as String,
                delayDays: map['delayDays'] as int,
                isDefault: Value(map['isDefault'] as bool? ?? false),
                scheduleType: Value(map['scheduleType'] as String? ?? 'delay'),
                daysOfWeek: Value(map['daysOfWeek'] as String?),
                rollingWindowSize: Value(map['rollingWindowSize'] as int?),
              ),
            );
      }

      // --- Import point configs ---
      for (final p in data['pointConfigs'] as List) {
        final map = p as Map<String, dynamic>;
        await _database
            .into(_database.pointConfigs)
            .insert(
              PointConfigsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                stageOrder: map['stageOrder'] as int,
                points: map['points'] as int,
              ),
            );
      }

      // --- Import study day configs ---
      for (final c in (data['studyDayConfigs'] as List? ?? [])) {
        final map = c as Map<String, dynamic>;
        await _database
            .into(_database.studyDayConfigs)
            .insert(
              StudyDayConfigsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                dayOfWeek: map['dayOfWeek'] as int,
                dayType: Value(map['dayType'] as String? ?? 'study'),
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }

      // --- Import completions ---
      for (final c in data['completions'] as List) {
        final map = c as Map<String, dynamic>;
        await _database
            .into(_database.completions)
            .insert(
              CompletionsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                sefariaRef: map['sefariaRef'] as String,
                stageId: map['stageId'] as int,
                trackType: map['trackType'] as String,
                trackId: map['trackId'] as int? ?? 0,
                completedAt: DateTime.parse(map['completedAt'] as String),
                points: Value(map['points'] as int? ?? 0),
              ),
            );
      }

      // --- Import completion events ---
      for (final e in (data['completionEvents'] as List? ?? [])) {
        final map = e as Map<String, dynamic>;
        await _database
            .into(_database.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                sefariaRef: map['sefariaRef'] as String,
                stageId: map['stageId'] as int,
                trackType: map['trackType'] as String,
                eventTimestamp: DateTime.parse(map['eventTimestamp'] as String),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
              ),
            );
      }

      // --- Import daily plans ---
      for (final p in (data['dailyPlans'] as List? ?? [])) {
        final map = p as Map<String, dynamic>;
        await _database
            .into(_database.dailyPlans)
            .insert(
              DailyPlansCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                planDate: DateTime.parse(map['planDate'] as String),
                sefariaRef: map['sefariaRef'] as String,
                stageOrder: map['stageOrder'] as int,
                stageDefinitionId: map['stageDefinitionId'] as int,
                trackId: map['trackId'] as int,
                trackLabel: Value(map['trackLabel'] as String? ?? ''),
                priority: map['priority'] as String,
                isOverdue: Value(map['isOverdue'] as bool? ?? false),
                reason: Value(map['reason'] as String? ?? ''),
                stageName: Value(map['stageName'] as String? ?? ''),
                estimatedEffortMinutes: Value(
                  map['estimatedEffortMinutes'] as int? ?? 3,
                ),
                sortOrder: Value(map['sortOrder'] as int? ?? 0),
                createdAt: DateTime.parse(map['createdAt'] as String),
              ),
            );
      }

      // --- Import learning ledger ---
      for (final e in (data['learningLedger'] as List? ?? [])) {
        final map = e as Map<String, dynamic>;
        await _database
            .into(_database.learningLedger)
            .insert(
              LearningLedgerCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                ulid: Value(map['ulid'] as String),
                curriculumId: map['curriculumId'] as String,
                entryScope: map['entryScope'] as String,
                unitIdentifier: map['unitIdentifier'] as String,
                unitDisplayNameHe: map['unitDisplayNameHe'] as String,
                unitDisplayNameEn: map['unitDisplayNameEn'] as String,
                trackType: map['trackType'] as String,
                trackId: Value(map['trackId'] as int?),
                completedAt: DateTime.parse(map['completedAt'] as String),
                completionNumber: map['completionNumber'] as int,
                markedBy: map['markedBy'] as int,
                isManual: Value(map['isManual'] as bool? ?? false),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
              ),
            );
      }

      // --- Import bookmarks ---
      for (final b in data['bookmarks'] as List) {
        final map = b as Map<String, dynamic>;
        await _database
            .into(_database.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                sefariaRef: map['sefariaRef'] as String,
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }

      // --- Import learning order ---
      for (final l in data['learningOrder'] as List) {
        final map = l as Map<String, dynamic>;
        await _database
            .into(_database.learningOrder)
            .insert(
              LearningOrderCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                sefariaRef: map['sefariaRef'] as String,
                userSortOrder: map['userSortOrder'] as int,
                updatedAt: Value(
                  map['updatedAt'] != null
                      ? DateTime.parse(map['updatedAt'] as String)
                      : DateTimeFactory.nowUtc(),
                ),
              ),
            );
      }

      // --- Import track learning order ---
      for (final t in (data['trackLearningOrder'] as List? ?? [])) {
        final map = t as Map<String, dynamic>;
        await _database
            .into(_database.trackLearningOrder)
            .insert(
              TrackLearningOrderCompanion.insert(
                trackId: map['trackId'] as int,
                sefariaRef: map['sefariaRef'] as String,
                sortOrder: map['sortOrder'] as int,
              ),
            );
      }

      // --- Import goals ---
      for (final g in data['goals'] as List) {
        final map = g as Map<String, dynamic>;
        await _database
            .into(_database.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                targetPercent: Value(
                  (map['targetPercent'] as num?)?.toDouble() ?? 100.0,
                ),
                targetDate: Value(
                  map['targetDate'] != null
                      ? DateTime.parse(map['targetDate'] as String)
                      : null,
                ),
                description: Value(map['description'] as String? ?? ''),
                dateType: Value(map['dateType'] as String? ?? 'gregorian'),
                goalType: Value(map['goalType'] as String? ?? 'deadline'),
                paceValue: Value(map['paceValue'] as int?),
                pacePeriod: Value(map['pacePeriod'] as String?),
                paceGranularity: Value(map['paceGranularity'] as String?),
                createdAt: DateTime.parse(map['createdAt'] as String),
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }

      // --- Import streaks ---
      for (final s in data['streaks'] as List) {
        final map = s as Map<String, dynamic>;
        await _database
            .into(_database.streaks)
            .insert(
              StreaksCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                currentStreak: Value(map['currentStreak'] as int? ?? 0),
                maxStreak: Value(map['maxStreak'] as int? ?? 0),
                lastCompletionDate: Value(
                  map['lastCompletionDate'] != null
                      ? DateTime.parse(map['lastCompletionDate'] as String)
                      : null,
                ),
                graceUsedDate: Value(
                  map['graceUsedDate'] != null
                      ? DateTime.parse(map['graceUsedDate'] as String)
                      : null,
                ),
                gracePeriodDays: Value(map['gracePeriodDays'] as int? ?? 1),
              ),
            );
      }

      // --- Import streak events ---
      for (final e in (data['streakEvents'] as List? ?? [])) {
        final map = e as Map<String, dynamic>;
        await _database
            .into(_database.streakEvents)
            .insert(
              StreakEventsCompanion.insert(
                profileId: map['profileId'] as int? ?? 0,
                eventType: map['eventType'] as String,
                dayUtc: DateTime.parse(map['dayUtc'] as String),
                eventTimestamp: DateTime.parse(map['eventTimestamp'] as String),
                clientDeviceId: Value(map['clientDeviceId'] as String?),
                createdAt: Value(DateTime.parse(map['createdAt'] as String)),
              ),
            );
      }
    });
  }
}
