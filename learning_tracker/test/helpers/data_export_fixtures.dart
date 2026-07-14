/// Shared test fixtures for `DataExportImportService` export/import JSON
/// payloads (AUD-t-settings-08).
///
/// Five files under `test/features/settings/domain/services/` used to
/// hand-roll the same ~20-key `schemaV1` export/import schema
/// independently — and had already drifted: one still emitted a legacy
/// `activeCurricula` key that its own comment said was "removed from
/// schema v9", while the others omitted it entirely. This file is now the
/// single source of truth: the full-payload envelope ([exportPayloadMap])
/// plus one row builder per exported table, mirroring the field shape
/// `DataExportImportService.exportData()` actually produces (see
/// `lib/features/settings/domain/services/data_export_import_service.dart`).
///
/// Every envelope section defaults to an empty list, and every row builder
/// defaults to a minimal valid row — callers override only the fields a
/// given test cares about. Extra/absent optional sections are harmless:
/// `DataExportImportService` reads optional sections via `?? []` and
/// ignores unknown keys entirely.
library;

/// Builds a full `schemaV1` export/import payload as a [Map]. All table
/// sections default to an empty list; `formatVersion` / `exportedAt` /
/// `appVersion` default to a valid header. Pass row maps built by the
/// `*Map` functions below (or ad-hoc maps, for tests that only assert
/// record *counts* and don't care about row shape) to populate a section.
///
/// Callers that need a JSON string call `jsonEncode(exportPayloadMap(...))`.
Map<String, dynamic> exportPayloadMap({
  String formatVersion = 'schemaV1',
  String exportedAt = '2026-01-01T00:00:00.000Z',
  String appVersion = '1.0.0',
  List<Map<String, dynamic>> userProfiles = const [],
  List<Map<String, dynamic>> learnerProfiles = const [],
  List<Map<String, dynamic>> curriculumTracks = const [],
  List<Map<String, dynamic>> curriculumScopes = const [],
  List<Map<String, dynamic>> profilePrograms = const [],
  List<Map<String, dynamic>> stageDefinitions = const [],
  List<Map<String, dynamic>> pointConfigs = const [],
  List<Map<String, dynamic>> studyDayConfigs = const [],
  List<Map<String, dynamic>> completions = const [],
  List<Map<String, dynamic>> completionEvents = const [],
  List<Map<String, dynamic>> dailyPlans = const [],
  List<Map<String, dynamic>> learningLedger = const [],
  List<Map<String, dynamic>> bookmarks = const [],
  List<Map<String, dynamic>> learningOrder = const [],
  List<Map<String, dynamic>> trackLearningOrder = const [],
  List<Map<String, dynamic>> goals = const [],
  List<Map<String, dynamic>> streaks = const [],
  List<Map<String, dynamic>> streakEvents = const [],
}) => <String, dynamic>{
  'formatVersion': formatVersion,
  'exportedAt': exportedAt,
  'appVersion': appVersion,
  'userProfiles': userProfiles,
  'learnerProfiles': learnerProfiles,
  'curriculumTracks': curriculumTracks,
  'curriculumScopes': curriculumScopes,
  'profilePrograms': profilePrograms,
  'stageDefinitions': stageDefinitions,
  'pointConfigs': pointConfigs,
  'studyDayConfigs': studyDayConfigs,
  'completions': completions,
  'completionEvents': completionEvents,
  'dailyPlans': dailyPlans,
  'learningLedger': learningLedger,
  'bookmarks': bookmarks,
  'learningOrder': learningOrder,
  'trackLearningOrder': trackLearningOrder,
  'goals': goals,
  'streaks': streaks,
  'streakEvents': streakEvents,
};

// ── Per-entity row builders ─────────────────────────────────────────────
// Field shape mirrors DataExportImportService.exportData()'s serializers.
// Fields the importer never reads (e.g. row `id` on tables that import via
// autoincrement) are still accepted so a builder can faithfully reproduce
// a real export row; they are harmless if unused.

/// Returns a `userProfiles` row (imported as an `accounts` row).
Map<String, dynamic> userProfileMap({
  int id = 1,
  String displayName = 'Test User',
  String tier = 'localBorn',
  String createdAt = '2026-01-01T00:00:00.000Z',
  String updatedAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'profileId': id,
  'displayName': displayName,
  'tier': tier,
  'createdAt': createdAt,
  'updatedAt': updatedAt,
};

/// Returns a `learnerProfiles` row.
Map<String, dynamic> learnerProfileMap({
  int id = 1,
  int accountId = 1,
  String displayName = 'Test User',
  String mode = 'adult',
  int avatarIndex = 0,
  String createdAt = '2026-01-01T00:00:00.000Z',
  String updatedAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'accountId': accountId,
  'displayName': displayName,
  'mode': mode,
  'avatarIndex': avatarIndex,
  'createdAt': createdAt,
  'updatedAt': updatedAt,
};

/// Returns a `curriculumTracks` row using the current (W3.28/W3.29)
/// `state` / `stateChangedAt` shape. `importData()` also back-compat-parses
/// the older `isActive` / `deactivatedAt` shape, but new fixtures should
/// use this one — it is what a real export produces today.
Map<String, dynamic> curriculumTrackMap({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'bavli',
  String state = 'active',
  String stateChangedAt = '2026-01-01T00:00:00.000Z',
  String activatedAt = '2026-01-01T00:00:00.000Z',
  String? paceResetDate,
}) => {
  'id': id,
  'profileId': profileId,
  'curriculumId': curriculumId,
  'state': state,
  'stateChangedAt': stateChangedAt,
  'activatedAt': activatedAt,
  'paceResetDate': paceResetDate,
};

/// Returns a `curriculumScopes` row.
Map<String, dynamic> curriculumScopeMap({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'bavli',
  int trackId = 1,
  int scopeLevel = 1,
  String scopeValue = 'Zeraim',
  String createdAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'profileId': profileId,
  'curriculumId': curriculumId,
  'trackId': trackId,
  'scopeLevel': scopeLevel,
  'scopeValue': scopeValue,
  'createdAt': createdAt,
};

/// Returns a `stageDefinitions` row. `schedule` defaults to the legacy
/// delay-quartet shape (`_resolveScheduleJson`'s fallback path) so callers
/// that only care about a stage existing don't need to hand-build a
/// schedule JSON string; pass [schedule] to exercise the current shape.
Map<String, dynamic> stageDefinitionMap({
  int profileId = 1,
  String curriculumId = 'bavli',
  int trackId = 1,
  int stageOrder = 1,
  String stageName = 'Learn',
  bool isDefault = true,
  int delayDays = 0,
  String? schedule,
}) => {
  'profileId': profileId,
  'curriculumId': curriculumId,
  'trackId': trackId,
  'stageOrder': stageOrder,
  'stageName': stageName,
  'isDefault': isDefault,
  if (schedule != null) 'schedule': schedule else 'delayDays': delayDays,
};

/// Returns a `pointConfigs` row.
Map<String, dynamic> pointConfigMap({
  int profileId = 1,
  String curriculumId = 'bavli',
  int trackId = 1,
  int stageOrder = 1,
  int points = 10,
}) => {
  'profileId': profileId,
  'curriculumId': curriculumId,
  'trackId': trackId,
  'stageOrder': stageOrder,
  'points': points,
};

/// Returns a `studyDayConfigs` row (this table has no `id` column in the
/// export — matches `DataExportImportService.exportData()`).
Map<String, dynamic> studyDayConfigMap({
  int profileId = 1,
  String curriculumId = 'bavli',
  int trackId = 1,
  int dayOfWeek = 1,
  String dayType = 'study',
  String updatedAt = '2026-01-01T00:00:00.000Z',
}) => {
  'profileId': profileId,
  'curriculumId': curriculumId,
  'trackId': trackId,
  'dayOfWeek': dayOfWeek,
  'dayType': dayType,
  'updatedAt': updatedAt,
};

/// Returns a `completions` row.
Map<String, dynamic> completionMap({
  int profileId = 1,
  String curriculumId = 'bavli',
  String sefariaRef = 'Berakhot.2a',
  int trackId = 1,
  int stageId = 1,
  String trackType = 'personal',
  String completedAt = '2026-03-01T00:00:00.000Z',
  int points = 5,
}) => {
  'profileId': profileId,
  'curriculumId': curriculumId,
  'sefariaRef': sefariaRef,
  'stageId': stageId,
  'trackType': trackType,
  'trackId': trackId,
  'completedAt': completedAt,
  'points': points,
};

/// Returns a `goals` row.
Map<String, dynamic> goalMap({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'bavli',
  int trackId = 1,
  double targetPercent = 90.0,
  String? targetDate,
  String description = '',
  String dateType = 'gregorian',
  String goalType = 'deadline',
  int? paceValue,
  String? pacePeriod,
  String? paceGranularity,
  String createdAt = '2026-01-01T00:00:00.000Z',
  String updatedAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'profileId': profileId,
  'curriculumId': curriculumId,
  'trackId': trackId,
  'targetPercent': targetPercent,
  'targetDate': targetDate,
  'description': description,
  'dateType': dateType,
  'goalType': goalType,
  'paceValue': paceValue,
  'pacePeriod': pacePeriod,
  'paceGranularity': paceGranularity,
  'createdAt': createdAt,
  'updatedAt': updatedAt,
};

/// Returns a `bookmarks` row.
Map<String, dynamic> bookmarkMap({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'bavli',
  int trackId = 1,
  String sefariaRef = 'Berakhot.2a',
  String updatedAt = '2026-05-01T00:00:00.000Z',
}) => {
  'id': id,
  'profileId': profileId,
  'curriculumId': curriculumId,
  'trackId': trackId,
  'sefariaRef': sefariaRef,
  'updatedAt': updatedAt,
};

/// Returns a `learningOrder` row.
Map<String, dynamic> learningOrderMap({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'bavli',
  String sefariaRef = 'Berakhot.2a',
  int userSortOrder = 1,
  String updatedAt = '2026-05-01T00:00:00.000Z',
}) => {
  'id': id,
  'profileId': profileId,
  'curriculumId': curriculumId,
  'sefariaRef': sefariaRef,
  'userSortOrder': userSortOrder,
  'updatedAt': updatedAt,
};

/// Returns a `trackLearningOrder` row.
Map<String, dynamic> trackLearningOrderMap({
  int id = 1,
  int profileId = 1,
  int trackId = 1,
  String sefariaRef = 'Berakhot',
  int sortOrder = 0,
}) => {
  'id': id,
  'profileId': profileId,
  'trackId': trackId,
  'sefariaRef': sefariaRef,
  'sortOrder': sortOrder,
};

/// Returns a `learningLedger` row.
Map<String, dynamic> learningLedgerMap({
  int id = 1,
  int profileId = 1,
  String ulid = '01HZ000000000000000000001',
  String curriculumId = 'bavli',
  String entryScope = 'masechta',
  String unitIdentifier = 'Berakhot',
  String unitDisplayNameHe = 'ברכות',
  String unitDisplayNameEn = 'Berakhot',
  String trackType = 'personal',
  int? trackId,
  String completedAt = '2026-01-01T00:00:00.000Z',
  int completionNumber = 1,
  int markedBy = 0,
  bool isManual = false,
  String createdAt = '2026-01-01T00:00:00.000Z',
}) => {
  'id': id,
  'profileId': profileId,
  'ulid': ulid,
  'curriculumId': curriculumId,
  'entryScope': entryScope,
  'unitIdentifier': unitIdentifier,
  'unitDisplayNameHe': unitDisplayNameHe,
  'unitDisplayNameEn': unitDisplayNameEn,
  'trackType': trackType,
  'trackId': trackId,
  'completedAt': completedAt,
  'completionNumber': completionNumber,
  'markedBy': markedBy,
  'isManual': isManual,
  'createdAt': createdAt,
};

/// Returns a `streakEvents` row.
Map<String, dynamic> streakEventMap({
  int id = 1,
  int profileId = 1,
  String eventType = 'completion',
  String dayUtc = '2026-01-05T00:00:00.000Z',
  String eventTimestamp = '2026-01-05T10:00:00.000Z',
  String? clientDeviceId,
  String createdAt = '2026-01-05T10:00:00.000Z',
}) => {
  'id': id,
  'profileId': profileId,
  'eventType': eventType,
  'dayUtc': dayUtc,
  'eventTimestamp': eventTimestamp,
  'clientDeviceId': clientDeviceId,
  'createdAt': createdAt,
};

/// Returns a legacy `streaks` row (W3.20 dropped the `streaks` table —
/// `importData()` always ignores this section's content, reading streak
/// state from `streakEvents` instead; a payload's `streaks` list only
/// needs to exist to satisfy `_requiredSections`). Kept for tests that
/// exercise the "legacy `streaks` key is silently ignored" back-compat
/// path.
Map<String, dynamic> legacyStreakMap({
  int profileId = 1,
  int currentStreak = 7,
  int maxStreak = 14,
  String? lastCompletionDate = '2026-05-13T00:00:00.000Z',
  String? graceUsedDate,
  int gracePeriodDays = 1,
}) => {
  'profileId': profileId,
  'currentStreak': currentStreak,
  'maxStreak': maxStreak,
  'lastCompletionDate': lastCompletionDate,
  'graceUsedDate': graceUsedDate,
  'gracePeriodDays': gracePeriodDays,
};
