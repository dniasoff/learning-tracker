import 'dart:convert';
import 'dart:math';

import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';

/// Manages offline queue for pending Firestore operations.
///
/// When the device is offline, write operations are queued locally
/// in SQLite. When connectivity is restored, queued operations are
/// flushed to Firestore.
class OfflineQueue {
  OfflineQueue({
    required UserDatabase database,
    required FirestoreDataSource firestoreDataSource,
    required AppLogger logger,
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _logger = logger;

  final UserDatabase _database;
  final FirestoreDataSource _firestoreDataSource;
  final AppLogger _logger;

  /// Maximum number of retry attempts before an item is considered dead (FR93).
  static const maxRetries = 5;

  /// Get the sync queue DAO.
  SyncQueueDao get _queue => _database.syncQueueDao;

  int? _parseProfileId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  ({FirestoreDataSource dataSource, Map<String, dynamic> payload})
  _resolveTarget(Map<String, dynamic> payload) {
    final scopedPayload = Map<String, dynamic>.from(payload);
    final targetProfileId = _parseProfileId(
      scopedPayload['profile_id'] ?? scopedPayload['_target_profile_id'],
    );
    scopedPayload.remove('_target_profile_id');

    if (targetProfileId == null ||
        targetProfileId == _firestoreDataSource.profileId) {
      return (dataSource: _firestoreDataSource, payload: scopedPayload);
    }

    return (
      dataSource: _firestoreDataSource.forProfile(targetProfileId),
      payload: scopedPayload,
    );
  }

  /// Get count of pending operations in the queue.
  Future<int> getPendingCount() {
    return _queue.getPendingCount();
  }

  /// Enqueue a completion operation.
  Future<void> enqueueCompletion(Map<String, dynamic> completion) async {
    final payload = jsonEncode(completion);
    await _queue.enqueue('completion', payload);
    _logger.info(
      event: 'offline_queue_enqueue_completion',
      fields: {'id': completion['id']},
    );
  }

  /// Enqueue a bookmark operation.
  Future<void> enqueueBookmark(Map<String, dynamic> bookmark) async {
    final payload = jsonEncode(bookmark);
    await _queue.enqueue('bookmark', payload);
    _logger.info(event: 'offline_queue_enqueue_bookmark');
  }

  /// Enqueue a settings operation.
  Future<void> enqueueSettings(Map<String, dynamic> settings) async {
    final payload = jsonEncode(settings);
    await _queue.enqueue('settings', payload);
    _logger.info(event: 'offline_queue_enqueue_settings');
  }

  /// Enqueue a notification settings operation.
  Future<void> enqueueNotificationSettings(
    Map<String, dynamic> notificationSettings,
  ) async {
    final payload = jsonEncode(notificationSettings);
    await _queue.enqueue('notification_settings', payload);
    _logger.info(event: 'offline_queue_enqueue_notification_settings');
  }

  /// Enqueue a gamification settings operation.
  Future<void> enqueueGamificationSettings(
    Map<String, dynamic> gamificationSettings,
  ) async {
    final payload = jsonEncode(gamificationSettings);
    await _queue.enqueue('gamification_settings', payload);
    _logger.info(event: 'offline_queue_enqueue_gamification_settings');
  }

  /// Enqueue UI preferences (locale, calendar, text display, learning order).
  Future<void> enqueueUiPreferences(Map<String, dynamic> uiPreferences) async {
    final payload = jsonEncode(uiPreferences);
    await _queue.enqueue('ui_preferences', payload);
    _logger.info(event: 'offline_queue_enqueue_ui_preferences');
  }

  /// Enqueue a streak operation.
  Future<void> enqueueStreak(Map<String, dynamic> streak) async {
    final payload = jsonEncode(streak);
    await _queue.enqueue('streak', payload);
    _logger.info(event: 'offline_queue_enqueue_streak');
  }

  /// Enqueue a profile operation.
  Future<void> enqueueProfile(Map<String, dynamic> profile) async {
    final payload = jsonEncode(profile);
    await _queue.enqueue('profile', payload);
    _logger.info(event: 'offline_queue_enqueue_profile');
  }

  /// Enqueue a learner profile operation.
  Future<void> enqueueLearnerProfile(Map<String, dynamic> profile) async {
    final payload = jsonEncode(profile);
    await _queue.enqueue('learner_profile', payload);
    _logger.info(event: 'offline_queue_enqueue_learner_profile');
  }

  /// Enqueue a learner profile delete operation.
  Future<void> enqueueLearnerProfileDelete(int profileId) async {
    final payload = jsonEncode({'profile_id': profileId});
    await _queue.enqueue('learner_profile_delete', payload);
    _logger.info(
      event: 'offline_queue_enqueue_learner_profile_delete',
      fields: {'profileId': profileId},
    );
  }

  /// Enqueue a goal operation.
  Future<void> enqueueGoal(Map<String, dynamic> goal) async {
    final payload = jsonEncode(goal);
    await _queue.enqueue('goal', payload);
    _logger.info(event: 'offline_queue_enqueue_goal');
  }

  /// Enqueue a profile-program assignment operation.
  Future<void> enqueueProfileProgram(
    Map<String, dynamic> profileProgram,
  ) async {
    final payload = jsonEncode(profileProgram);
    await _queue.enqueue('profile_program', payload);
    _logger.info(
      event: 'offline_queue_enqueue_profile_program',
      fields: {'curriculumId': profileProgram['curriculum_id']},
    );
  }

  /// Enqueue deletion of a profile-program assignment (self-paced switch).
  Future<void> enqueueProfileProgramDelete(Map<String, dynamic> payload) async {
    final encoded = jsonEncode(payload);
    await _queue.enqueue('profile_program_delete', encoded);
    _logger.info(
      event: 'offline_queue_enqueue_profile_program_delete',
      fields: {'curriculumId': payload['curriculum_id']},
    );
  }

  /// Enqueue a ledger entry operation.
  Future<void> enqueueLedgerEntry(Map<String, dynamic> entry) async {
    final payload = jsonEncode(entry);
    await _queue.enqueue('ledger_entry', payload);
    _logger.info(event: 'offline_queue_enqueue_ledger_entry');
  }

  /// Enqueue curriculum import metadata operation.
  Future<void> enqueueCurriculumImportMetadata(
    Map<String, dynamic> metadata,
  ) async {
    final payload = jsonEncode(metadata);
    await _queue.enqueue('curriculum_import_metadata', payload);
    _logger.info(
      event: 'offline_queue_enqueue_curriculum_import_metadata',
      fields: {'curriculumId': metadata['curriculum_id']},
    );
  }

  /// Enqueue a curriculum-track operation.
  Future<void> enqueueCurriculumTrack(Map<String, dynamic> track) async {
    final payload = jsonEncode(track);
    await _queue.enqueue('curriculum_track', payload);
    _logger.info(
      event: 'offline_queue_enqueue_curriculum_track',
      fields: {
        'curriculumId': track['curriculum_id'],
        'trackType': track['track_type'],
      },
    );
  }

  /// Enqueue a single learning-order item (LWW, deterministic doc ID).
  Future<void> enqueueLearningOrderItem(Map<String, dynamic> item) async {
    final payload = jsonEncode(item);
    await _queue.enqueue('learning_order_item', payload);
    _logger.info(
      'Queued learning order item for offline sync: '
      '${item["curriculum_id"]}_${item["sefaria_ref"]}',
    );
  }

  /// Flush queued operations to Firestore.
  ///
  /// If [batchSize] is provided, only processes that many items per flush
  /// (battery-efficient mode per NFR27).
  /// Returns the number of successfully synced operations.
  Future<int> flush({int? batchSize}) async {
    final allPending = await _queue.getAllPending();
    if (allPending.isEmpty) {
      _logger.debug(event: 'offline_queue_flush_empty');
      return 0;
    }

    // When batchSize is provided, process in batches with a small delay
    // between each batch to reduce sustained network activity (NFR27).
    final batches = <List<SyncQueueData>>[];
    if (batchSize != null) {
      for (var i = 0; i < allPending.length; i += batchSize) {
        final end = (i + batchSize > allPending.length)
            ? allPending.length
            : i + batchSize;
        batches.add(allPending.sublist(i, end));
      }
    } else {
      batches.add(allPending);
    }

    _logger.info(
      event: 'offline_queue_flush_start',
      fields: {'pendingCount': allPending.length},
    );
    var successCount = 0;

    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      // Add inter-batch delay to reduce sustained network activity.
      if (batchIndex > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      for (final operation in batches[batchIndex]) {
        // Skip items that have exceeded the retry limit (dead-letter).
        if (operation.retryCount >= maxRetries) {
          _logger.warning(
            event: 'offline_queue_dead_letter_skipped',
            fields: {
              'operationId': operation.id,
              'operationType': operation.operationType,
              'maxRetries': maxRetries,
            },
          );
          continue;
        }

        // Non-blocking exponential backoff: skip items whose retry time
        // hasn't arrived yet instead of sleeping in the flush loop.
        if (operation.retryCount > 0) {
          final backoffSeconds = pow(2, operation.retryCount).toInt();
          final nextRetryAt = operation.queuedAt.add(
            Duration(seconds: backoffSeconds),
          );
          if (DateTime.now().toUtc().isBefore(nextRetryAt)) {
            _logger.debug(
              event: 'offline_queue_backoff_skip',
              fields: {
                'operationId': operation.id,
                'retryCount': operation.retryCount,
                'nextRetryAt': nextRetryAt.toIso8601String(),
              },
            );
            continue;
          }
        }

        try {
          final rawPayload =
              jsonDecode(operation.payload) as Map<String, dynamic>;
          final resolved = _resolveTarget(rawPayload);
          final payload = resolved.payload;
          final dataSource = resolved.dataSource;

          switch (operation.operationType) {
            case 'completion':
              await dataSource.pushCompletion(payload);
              break;
            case 'bookmark':
              await dataSource.pushBookmark(payload);
              break;
            case 'settings':
              await dataSource.pushSettings(payload);
              break;
            case 'notification_settings':
              await dataSource.pushNotificationSettings(payload);
              break;
            case 'gamification_settings':
              await dataSource.pushGamificationSettings(payload);
              break;
            case 'ui_preferences':
              await dataSource.pushUiPreferences(payload);
              break;
            case 'streak':
              await dataSource.pushStreak(payload);
              break;
            case 'profile':
              await dataSource.pushProfile(payload);
              break;
            case 'learner_profile':
              await dataSource.pushLearnerProfile(payload);
              break;
            case 'learner_profile_delete':
              final rawProfileId = payload['profile_id'];
              final profileId = rawProfileId is int
                  ? rawProfileId
                  : rawProfileId is num
                  ? rawProfileId.toInt()
                  : int.tryParse(rawProfileId?.toString() ?? '');
              if (profileId == null) {
                _logger.warning(
                  event: 'offline_queue_invalid_payload',
                  fields: {
                    'operationType': 'learner_profile_delete',
                    'reason': 'missing_profile_id',
                  },
                );
                continue;
              }
              await dataSource.deleteLearnerProfile(profileId);
              break;
            case 'goal':
              await dataSource.pushGoal(payload);
              break;
            case 'profile_program':
              await dataSource.pushProfileProgram(payload);
              break;
            case 'profile_program_delete':
              final cid = payload['curriculum_id'] as String?;
              if (cid == null || cid.isEmpty) {
                _logger.warning(
                  event: 'offline_queue_invalid_payload',
                  fields: {
                    'operationType': 'profile_program_delete',
                    'reason': 'missing_curriculum_id',
                  },
                );
                continue;
              }
              await dataSource.deleteProfileProgramForCurriculum(cid);
              break;
            case 'ledger_entry':
              await dataSource.pushLedgerEntry(payload);
              break;
            case 'curriculum_import_metadata':
              await dataSource.pushCurriculumImportMetadata(payload);
              break;
            case 'curriculum_track':
              await dataSource.pushCurriculumTrack(payload);
              break;
            case 'learning_order_item':
              await dataSource.pushLearningOrderItem(payload);
              break;
            default:
              _logger.warning(
                event: 'offline_queue_unknown_operation_type',
                fields: {'operationType': operation.operationType},
              );
              continue;
          }

          // Successfully synced, remove from queue
          await _queue.remove(operation.id);
          successCount++;
          _logger.debug(
            event: 'offline_queue_operation_synced',
            fields: {
              'operationId': operation.id,
              'operationType': operation.operationType,
            },
          );
        } catch (e, stackTrace) {
          _logger.error(
            event: 'offline_queue_operation_failed',
            fields: {
              'operationId': operation.id,
              'operationType': operation.operationType,
            },
            exception: e,
            stackTrace: stackTrace,
          );
          await _queue.markFailed(operation.id, e.toString());
        }
      }
    }

    _logger.info(
      event: 'offline_queue_flush_complete',
      fields: {'successCount': successCount, 'totalCount': allPending.length},
    );
    return successCount;
  }

  /// Clear all queued operations (use with caution).
  Future<void> clearAll() async {
    await _queue.clearAll();
    _logger.warning(event: 'offline_queue_cleared_all');
  }
}
