import 'dart:convert';
import 'dart:math';

import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:talker/talker.dart';

/// Manages offline queue for pending Firestore operations.
///
/// When the device is offline, write operations are queued locally
/// in SQLite. When connectivity is restored, queued operations are
/// flushed to Firestore.
class OfflineQueue {
  OfflineQueue({
    required UserDatabase database,
    required FirestoreDataSource firestoreDataSource,
    required Talker logger,
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _logger = logger;

  final UserDatabase _database;
  final FirestoreDataSource _firestoreDataSource;
  final Talker _logger;

  /// Maximum number of retry attempts before an item is considered dead (FR93).
  static const maxRetries = 5;

  /// Get the sync queue DAO.
  SyncQueueDao get _queue => _database.syncQueueDao;

  /// Get count of pending operations in the queue.
  Future<int> getPendingCount() {
    return _queue.getPendingCount();
  }

  /// Enqueue a completion operation.
  Future<void> enqueueCompletion(Map<String, dynamic> completion) async {
    final payload = jsonEncode(completion);
    await _queue.enqueue('completion', payload);
    _logger.info('Queued completion for offline sync: ${completion['id']}');
  }

  /// Enqueue a bookmark operation.
  Future<void> enqueueBookmark(Map<String, dynamic> bookmark) async {
    final payload = jsonEncode(bookmark);
    await _queue.enqueue('bookmark', payload);
    _logger.info('Queued bookmark for offline sync');
  }

  /// Enqueue a settings operation.
  Future<void> enqueueSettings(Map<String, dynamic> settings) async {
    final payload = jsonEncode(settings);
    await _queue.enqueue('settings', payload);
    _logger.info('Queued settings for offline sync');
  }

  /// Enqueue a notification settings operation.
  Future<void> enqueueNotificationSettings(
    Map<String, dynamic> notificationSettings,
  ) async {
    final payload = jsonEncode(notificationSettings);
    await _queue.enqueue('notification_settings', payload);
    _logger.info('Queued notification settings for offline sync');
  }

  /// Enqueue a streak operation.
  Future<void> enqueueStreak(Map<String, dynamic> streak) async {
    final payload = jsonEncode(streak);
    await _queue.enqueue('streak', payload);
    _logger.info('Queued streak for offline sync');
  }

  /// Enqueue a profile operation.
  Future<void> enqueueProfile(Map<String, dynamic> profile) async {
    final payload = jsonEncode(profile);
    await _queue.enqueue('profile', payload);
    _logger.info('Queued profile for offline sync');
  }

  /// Enqueue a learner profile operation.
  Future<void> enqueueLearnerProfile(Map<String, dynamic> profile) async {
    final payload = jsonEncode(profile);
    await _queue.enqueue('learner_profile', payload);
    _logger.info('Queued learner profile for offline sync');
  }

  /// Enqueue a learner profile delete operation.
  Future<void> enqueueLearnerProfileDelete(int profileId) async {
    final payload = jsonEncode({'profile_id': profileId});
    await _queue.enqueue('learner_profile_delete', payload);
    _logger.info('Queued learner profile delete for offline sync: $profileId');
  }

  /// Enqueue a goal operation.
  Future<void> enqueueGoal(Map<String, dynamic> goal) async {
    final payload = jsonEncode(goal);
    await _queue.enqueue('goal', payload);
    _logger.info('Queued goal for offline sync');
  }

  /// Enqueue a profile-program assignment operation.
  Future<void> enqueueProfileProgram(
    Map<String, dynamic> profileProgram,
  ) async {
    final payload = jsonEncode(profileProgram);
    await _queue.enqueue('profile_program', payload);
    _logger.info(
      'Queued profile program for offline sync: ${profileProgram['curriculum_id']}',
    );
  }

  /// Enqueue a ledger entry operation.
  Future<void> enqueueLedgerEntry(Map<String, dynamic> entry) async {
    final payload = jsonEncode(entry);
    await _queue.enqueue('ledger_entry', payload);
    _logger.info('Queued ledger entry for offline sync');
  }

  /// Enqueue curriculum import metadata operation.
  Future<void> enqueueCurriculumImportMetadata(
    Map<String, dynamic> metadata,
  ) async {
    final payload = jsonEncode(metadata);
    await _queue.enqueue('curriculum_import_metadata', payload);
    _logger.info(
      'Queued curriculum import metadata for offline sync: ${metadata['curriculum_id']}',
    );
  }

  /// Enqueue a curriculum-track operation.
  Future<void> enqueueCurriculumTrack(Map<String, dynamic> track) async {
    final payload = jsonEncode(track);
    await _queue.enqueue('curriculum_track', payload);
    _logger.info(
      'Queued curriculum track for offline sync: '
      '${track['curriculum_id']}_${track['track_type']}',
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
      _logger.debug('No pending operations to flush');
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

    _logger.info('Flushing ${allPending.length} pending operations');
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
            'Skipping dead-letter operation #${operation.id} '
            '(${operation.operationType}) after $maxRetries retries',
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
              'Skipping operation #${operation.id} — backoff until $nextRetryAt '
              '(retry ${operation.retryCount})',
            );
            continue;
          }
        }

        try {
          final payload = jsonDecode(operation.payload) as Map<String, dynamic>;

          switch (operation.operationType) {
            case 'completion':
              await _firestoreDataSource.pushCompletion(payload);
              break;
            case 'bookmark':
              await _firestoreDataSource.pushBookmark(payload);
              break;
            case 'settings':
              await _firestoreDataSource.pushSettings(payload);
              break;
            case 'notification_settings':
              await _firestoreDataSource.pushNotificationSettings(payload);
              break;
            case 'streak':
              await _firestoreDataSource.pushStreak(payload);
              break;
            case 'profile':
              await _firestoreDataSource.pushProfile(payload);
              break;
            case 'learner_profile':
              await _firestoreDataSource.pushLearnerProfile(payload);
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
                  'Invalid learner_profile_delete payload: $payload',
                );
                continue;
              }
              await _firestoreDataSource.deleteLearnerProfile(profileId);
              break;
            case 'goal':
              await _firestoreDataSource.pushGoal(payload);
              break;
            case 'profile_program':
              await _firestoreDataSource.pushProfileProgram(payload);
              break;
            case 'ledger_entry':
              await _firestoreDataSource.pushLedgerEntry(payload);
              break;
            case 'curriculum_import_metadata':
              await _firestoreDataSource.pushCurriculumImportMetadata(payload);
              break;
            case 'curriculum_track':
              await _firestoreDataSource.pushCurriculumTrack(payload);
              break;
            default:
              _logger.warning(
                'Unknown operation type: ${operation.operationType}',
              );
              continue;
          }

          // Successfully synced, remove from queue
          await _queue.remove(operation.id);
          successCount++;
          _logger.debug(
            'Synced ${operation.operationType} operation #${operation.id}',
          );
        } catch (e, stackTrace) {
          _logger.error(
            'Failed to sync ${operation.operationType} operation #${operation.id}',
            e,
            stackTrace,
          );
          await _queue.markFailed(operation.id, e.toString());
        }
      }
    }

    _logger.info(
      'Flushed $successCount/${allPending.length} operations successfully',
    );
    return successCount;
  }

  /// Clear all queued operations (use with caution).
  Future<void> clearAll() async {
    await _queue.clearAll();
    _logger.warning('Cleared all queued operations');
  }
}
