import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

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
    required this.activeCurriculaCount,
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
  final int activeCurriculaCount;
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
      activeCurriculaCount +
      curriculumTrackCount +
      userProfileCount;
}

/// Service for exporting and importing user data as JSON.
///
/// Export includes: completions, goals, stages, rewards, settings,
/// streaks, points. Export does NOT include content items (text cache,
/// download statuses) or sync queue.
class DataExportImportService {
  DataExportImportService({required UserDatabase database})
    : _database = database;

  final UserDatabase _database;

  static const String _formatVersion = '1';
  static const List<String> _requiredSections = [
    'completions',
    'goals',
    'stageDefinitions',
    'streaks',
    'pointConfigs',
    'bookmarks',
    'learningOrder',
    'activeCurricula',
    'curriculumTracks',
    'userProfiles',
  ];

  /// Exports all user data to a JSON string.
  Future<String> exportData() async {
    final completions = await _database.completionDao.getAllCompletions();
    final goals = await _database.goalDao.getAllGoals();
    final stages = await _database.stageDao.getAllStageDefinitions();
    final streaks = await _database.streakDao.getStreak();
    final pointConfigs = await _database.select(_database.pointConfigs).get();
    final bookmarks = await _database.bookmarkDao.getAllBookmarks();
    final learningOrders = await _database.learningOrderDao
        .getAllLearningOrders();
    final activeCurricula = await _database
        .select(_database.activeCurricula)
        .get();
    final curriculumTracks = await _database
        .select(_database.curriculumTracks)
        .get();
    final userProfiles = await _database.userProfileDao.getAllUserProfiles();

    final data = <String, dynamic>{
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': '1.0.0',
      'completions': completions
          .map(
            (c) => {
              'id': c.id,
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
      'goals': goals
          .map(
            (g) => {
              'id': g.id,
              'curriculumId': g.curriculumId,
              'trackId': g.trackId,
              'targetPercent': g.targetPercent,
              'targetDate': g.targetDate?.toIso8601String(),
              'description': g.description,
              'dateType': g.dateType,
              'createdAt': g.createdAt.toIso8601String(),
              'updatedAt': g.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'stageDefinitions': stages
          .map(
            (s) => {
              'id': s.id,
              'curriculumId': s.curriculumId,
              'trackId': s.trackId,
              'stageOrder': s.stageOrder,
              'stageName': s.stageName,
              'delayDays': s.delayDays,
              'isDefault': s.isDefault,
            },
          )
          .toList(),
      'streaks': streaks != null
          ? [
              {
                'id': streaks.id,
                'currentStreak': streaks.currentStreak,
                'maxStreak': streaks.maxStreak,
                'lastCompletionDate': streaks.lastCompletionDate
                    ?.toIso8601String(),
              },
            ]
          : <Map<String, dynamic>>[],
      'pointConfigs': pointConfigs
          .map(
            (p) => {
              'id': p.id,
              'curriculumId': p.curriculumId,
              'trackId': p.trackId,
              'stageOrder': p.stageOrder,
              'points': p.points,
            },
          )
          .toList(),
      'bookmarks': bookmarks
          .map(
            (b) => {
              'id': b.id,
              'curriculumId': b.curriculumId,
              'trackType': b.trackType,
              'sefariaRef': b.sefariaRef,
              'updatedAt': b.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'learningOrder': learningOrders
          .map(
            (l) => {
              'id': l.id,
              'curriculumId': l.curriculumId,
              'sefariaRef': l.sefariaRef,
              'userSortOrder': l.userSortOrder,
            },
          )
          .toList(),
      'activeCurricula': activeCurricula
          .map(
            (ac) => {
              'curriculumId': ac.curriculumId,
              'activatedAt': ac.activatedAt.toIso8601String(),
            },
          )
          .toList(),
      'curriculumTracks': curriculumTracks
          .map(
            (t) => {
              'curriculumId': t.curriculumId,
              'trackType': t.trackType,
              'isActive': t.isActive,
              'activatedAt': t.activatedAt.toIso8601String(),
              'deactivatedAt': t.deactivatedAt?.toIso8601String(),
            },
          )
          .toList(),
      'userProfiles': userProfiles
          .map(
            (u) => {
              'id': u.id,
              'firebaseUid': u.firebaseUid,
              'displayName': u.displayName,
              'userMode': u.userMode,
              'createdAt': u.createdAt.toIso8601String(),
              'updatedAt': u.updatedAt.toIso8601String(),
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
      activeCurriculaCount: (data['activeCurricula'] as List).length,
      curriculumTrackCount: (data['curriculumTracks'] as List).length,
      userProfileCount: (data['userProfiles'] as List).length,
      exportedAt: data['exportedAt'] as String? ?? 'unknown',
      appVersion: data['appVersion'] as String? ?? 'unknown',
    );
  }

  /// Imports data from a JSON string, replacing all existing data.
  ///
  /// Runs in a transaction — all or nothing. Throws on failure
  /// and rolls back all changes.
  Future<void> importData(String jsonString) async {
    final data = json.decode(jsonString) as Map<String, dynamic>;

    // Validate first
    validateAndPreview(jsonString);

    await _database.transaction(() async {
      // Clear existing data
      await _database.delete(_database.completions).go();
      await _database.delete(_database.goals).go();
      await _database.delete(_database.stageDefinitions).go();
      await _database.delete(_database.streaks).go();
      await _database.delete(_database.pointConfigs).go();
      await _database.delete(_database.bookmarks).go();
      await _database.delete(_database.learningOrder).go();
      await _database.delete(_database.activeCurricula).go();
      await _database.delete(_database.curriculumTracks).go();
      await _database.delete(_database.userProfiles).go();

      // Import completions
      for (final c in data['completions'] as List) {
        final map = c as Map<String, dynamic>;
        await _database
            .into(_database.completions)
            .insert(
              CompletionsCompanion.insert(
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

      // Import goals
      for (final g in data['goals'] as List) {
        final map = g as Map<String, dynamic>;
        await _database
            .into(_database.goals)
            .insert(
              GoalsCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                targetPercent: Value(map['targetPercent'] as double? ?? 100.0),
                targetDate: Value(
                  map['targetDate'] != null
                      ? DateTime.parse(map['targetDate'] as String)
                      : null,
                ),
                description: Value(map['description'] as String? ?? ''),
                dateType: Value(map['dateType'] as String? ?? 'gregorian'),
                createdAt: DateTime.parse(map['createdAt'] as String),
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }

      // Import stage definitions
      for (final s in data['stageDefinitions'] as List) {
        final map = s as Map<String, dynamic>;
        await _database
            .into(_database.stageDefinitions)
            .insert(
              StageDefinitionsCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                stageOrder: map['stageOrder'] as int,
                stageName: map['stageName'] as String,
                delayDays: map['delayDays'] as int,
                isDefault: Value(map['isDefault'] as bool? ?? false),
              ),
            );
      }

      // Import streaks
      for (final s in data['streaks'] as List) {
        final map = s as Map<String, dynamic>;
        await _database
            .into(_database.streaks)
            .insert(
              StreaksCompanion.insert(
                currentStreak: Value(map['currentStreak'] as int? ?? 0),
                maxStreak: Value(map['maxStreak'] as int? ?? 0),
                lastCompletionDate: Value(
                  map['lastCompletionDate'] != null
                      ? DateTime.parse(map['lastCompletionDate'] as String)
                      : null,
                ),
              ),
            );
      }

      // Import point configs
      for (final p in data['pointConfigs'] as List) {
        final map = p as Map<String, dynamic>;
        await _database
            .into(_database.pointConfigs)
            .insert(
              PointConfigsCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                trackId: map['trackId'] as int? ?? 0,
                stageOrder: map['stageOrder'] as int,
                points: map['points'] as int,
              ),
            );
      }

      // Import bookmarks
      for (final b in data['bookmarks'] as List) {
        final map = b as Map<String, dynamic>;
        await _database
            .into(_database.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                trackType: map['trackType'] as String,
                sefariaRef: map['sefariaRef'] as String,
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }

      // Import learning order
      for (final l in data['learningOrder'] as List) {
        final map = l as Map<String, dynamic>;
        await _database
            .into(_database.learningOrder)
            .insert(
              LearningOrderCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                sefariaRef: map['sefariaRef'] as String,
                userSortOrder: map['userSortOrder'] as int,
              ),
            );
      }

      // Import active curricula
      for (final a in data['activeCurricula'] as List) {
        final map = a as Map<String, dynamic>;
        await _database
            .into(_database.activeCurricula)
            .insert(
              ActiveCurriculaCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                activatedAt: map['activatedAt'] != null
                    ? DateTime.parse(map['activatedAt'] as String)
                    : DateTime.now(),
              ),
            );
      }

      // Import curriculum tracks
      for (final t in data['curriculumTracks'] as List) {
        final map = t as Map<String, dynamic>;
        await _database
            .into(_database.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                curriculumId: map['curriculumId'] as String,
                trackType: map['trackType'] as String,
                isActive: Value(map['isActive'] as bool? ?? true),
                activatedAt: DateTime.parse(map['activatedAt'] as String),
                deactivatedAt: Value(
                  map['deactivatedAt'] != null
                      ? DateTime.parse(map['deactivatedAt'] as String)
                      : null,
                ),
              ),
            );
      }

      // Import user profiles
      for (final u in data['userProfiles'] as List) {
        final map = u as Map<String, dynamic>;
        await _database
            .into(_database.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                email:
                    (map['email'] as String?) ??
                    (map['firebaseUid'] as String? ?? ''),
                firebaseUid: Value(map['firebaseUid'] as String?),
                tier:
                    (map['tier'] as String?) ??
                    ((map['firebaseUid'] as String?) != null
                        ? 'cloudBorn'
                        : 'localBorn'),
                displayName: map['displayName'] as String,
                userMode: map['userMode'] as String,
                createdAt: DateTime.parse(map['createdAt'] as String),
                updatedAt: DateTime.parse(map['updatedAt'] as String),
              ),
            );
      }
    });
  }
}
