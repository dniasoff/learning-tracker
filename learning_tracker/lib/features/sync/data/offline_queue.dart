import 'dart:convert';
import 'dart:math';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:talker/talker.dart';

/// Manages offline queue for pending Firestore operations.
///
/// When the device is offline, write operations are queued locally
/// in SQLite. When connectivity is restored, queued operations are
/// flushed to Firestore.
class OfflineQueue {
  OfflineQueue({
    required AppDatabase database,
    required FirestoreDataSource firestoreDataSource,
    required Talker logger,
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _logger = logger;

  final AppDatabase _database;
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

  /// Enqueue a goal operation.
  Future<void> enqueueGoal(Map<String, dynamic> goal) async {
    final payload = jsonEncode(goal);
    await _queue.enqueue('goal', payload);
    _logger.info('Queued goal for offline sync');
  }

  /// Enqueue a reward operation.
  Future<void> enqueueReward(Map<String, dynamic> reward) async {
    final payload = jsonEncode(reward);
    await _queue.enqueue('reward', payload);
    _logger.info('Queued reward for offline sync');
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

  /// Flush queued operations to Firestore.
  ///
  /// If [batchSize] is provided, only processes that many items per flush
  /// (battery-efficient mode per NFR27).
  /// Returns the number of successfully synced operations.
  Future<int> flush({int? batchSize}) async {
    var pending = await _queue.getAllPending();
    if (batchSize != null && pending.length > batchSize) {
      pending = pending.sublist(0, batchSize);
    }
    if (pending.isEmpty) {
      _logger.debug('No pending operations to flush');
      return 0;
    }

    _logger.info('Flushing ${pending.length} pending operations');
    var successCount = 0;

    for (final operation in pending) {
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
          case 'streak':
            await _firestoreDataSource.pushStreak(payload);
            break;
          case 'profile':
            await _firestoreDataSource.pushProfile(payload);
            break;
          case 'goal':
            await _firestoreDataSource.pushGoal(payload);
            break;
          case 'reward':
            await _firestoreDataSource.pushReward(payload);
            break;
          case 'curriculum_import_metadata':
            await _firestoreDataSource.pushCurriculumImportMetadata(payload);
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

    _logger.info(
      'Flushed $successCount/${pending.length} operations successfully',
    );
    return successCount;
  }

  /// Clear all queued operations (use with caution).
  Future<void> clearAll() async {
    await _queue.clearAll();
    _logger.warning('Cleared all queued operations');
  }
}
