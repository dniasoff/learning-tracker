import 'dart:async';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart'
    as models;
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart'
    as models;
import 'package:learning_tracker/features/content_import/domain/models/import_progress.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:talker/talker.dart';

/// Service for importing curriculum content from Sefaria API into local database.
///
/// Handles:
/// - Fetching content hierarchy from Sefaria fetchers
/// - Storing content_items and curriculum_hierarchy_config
/// - Seeding default stage_definitions (learn/chazara1/chazara2 at 0/1/7 days)
/// - Batched inserts for large curricula (batch size ≤ 500)
/// - Transaction rollback on error
/// - Cancellation support
/// - Idempotency via unique constraints
/// - Firestore sync of import metadata
class CurriculumImportService {
  CurriculumImportService({
    required AppDatabase database,
    required Map<String, CurriculumContentFetcher> fetchers,
    required SyncEngine syncEngine,
    required Talker logger,
  }) : _database = database,
       _fetchers = fetchers,
       _syncEngine = syncEngine,
       _logger = logger;

  final AppDatabase _database;
  final Map<String, CurriculumContentFetcher> _fetchers;
  final SyncEngine _syncEngine;
  final Talker _logger;

  final _progressController = StreamController<ImportProgress>.broadcast();
  Stream<ImportProgress> get progressStream => _progressController.stream;

  bool _isCancelled = false;
  static const int _batchSize = 500;

  /// Import a curriculum's complete content hierarchy.
  ///
  /// Returns true if import succeeded, false if cancelled.
  /// Throws [SefariaApiException] on network errors.
  /// Throws [StateError] if fetcher not found for curriculum.
  Future<bool> importCurriculum(CurriculumId curriculum) async {
    final curriculumId = curriculum.storageKey;
    _isCancelled = false;

    _logger.info('Starting import for curriculum: $curriculumId');
    _emitProgress(ImportProgress.fetching(curriculumId: curriculumId));

    try {
      // Get appropriate fetcher
      final fetcher = _fetchers[curriculumId];
      if (fetcher == null) {
        throw StateError('No fetcher configured for curriculum: $curriculumId');
      }

      // Check for cancellation
      if (_isCancelled) {
        _emitProgress(ImportProgress.cancelled(curriculumId: curriculumId));
        return false;
      }

      // Fetch from Sefaria API
      final fetchResult = await fetcher.fetchAllContent();
      final items = fetchResult.items;
      final hierarchyConfig = fetchResult.hierarchyConfig;

      _logger.info('Fetched ${items.length} items for $curriculumId');
      _emitProgress(
        ImportProgress.parsing(
          curriculumId: curriculumId,
          itemsFetched: items.length,
        ),
      );

      // Check for cancellation
      if (_isCancelled) {
        _emitProgress(ImportProgress.cancelled(curriculumId: curriculumId));
        return false;
      }

      // Store in database within transaction
      await _database.transaction(() async {
        // Delete existing data for this curriculum (for idempotency)
        await _database.contentDao.deleteAllForCurriculum(curriculumId);
        await _database.stageDao.deleteAllForCurriculum(curriculumId);
        await _deleteHierarchyConfig(curriculumId);

        // Check for cancellation before storing
        if (_isCancelled) {
          throw Exception('Import cancelled during transaction');
        }

        // Store content items in batches
        for (var i = 0; i < items.length; i += _batchSize) {
          if (_isCancelled) {
            throw Exception('Import cancelled during batch insert');
          }

          final batch = items.skip(i).take(_batchSize).toList();
          await _insertContentBatch(batch);

          _emitProgress(
            ImportProgress.storing(
              curriculumId: curriculumId,
              totalItems: items.length,
              storedItems: (i + batch.length).clamp(0, items.length),
            ),
          );
        }

        // Store hierarchy config
        await _insertHierarchyConfig(hierarchyConfig);

        // Seed default stage definitions
        await _seedDefaultStageDefinitions(curriculumId);

        _logger.info('Stored ${items.length} items for $curriculumId');
      });

      // Sync import metadata to Firestore
      await _syncImportMetadata(curriculumId, items.length);

      _emitProgress(
        ImportProgress.completed(
          curriculumId: curriculumId,
          totalItems: items.length,
        ),
      );
      return true;
    } on SefariaApiException catch (e) {
      _logger.error('Sefaria API error during import: $e');
      _emitProgress(
        ImportProgress.error(
          curriculumId: curriculumId,
          message: 'Network error: ${e.message}',
          errorCode: 'NETWORK_ERROR',
        ),
      );
      rethrow;
    } on Exception catch (e) {
      if (e.toString().contains('cancelled')) {
        _emitProgress(ImportProgress.cancelled(curriculumId: curriculumId));
        return false;
      }

      _logger.error('Error during import: $e');
      _emitProgress(
        ImportProgress.error(
          curriculumId: curriculumId,
          message: 'Import failed: $e',
        ),
      );
      rethrow;
    }
  }

  /// Cancel the current import operation.
  void cancelImport() {
    _logger.info('Import cancellation requested');
    _isCancelled = true;
  }

  /// Check if a curriculum has already been imported.
  Future<bool> isCurriculumImported(CurriculumId curriculum) async {
    final count = await _database.contentDao.getContentItemCountByCurriculum(
      curriculum.storageKey,
    );
    return count > 0;
  }

  Future<void> _insertContentBatch(List<models.ContentItem> items) async {
    for (final item in items) {
      await _database.contentDao.insertContentItem(
        ContentItemsCompanion(
          curriculumId: Value(item.curriculumId),
          level1: Value(item.level1),
          level2: Value(item.level2),
          level3: Value(item.level3),
          level4: Value(item.level4),
          displayNameHe: Value(item.displayNameHe),
          displayNameEn: Value(item.displayNameEn),
          sefariaRef: Value(item.sefariaRef),
          sortOrder: Value(item.sortOrder),
          isLeaf: Value(item.isLeaf),
        ),
      );
    }
  }

  Future<void> _insertHierarchyConfig(
    models.CurriculumHierarchyConfig config,
  ) async {
    final labels = config.levelLabels;
    await _database
        .into(_database.curriculumHierarchyConfig)
        .insert(
          CurriculumHierarchyConfigCompanion(
            curriculumId: Value(config.curriculumId),
            level1Label: Value(labels.isNotEmpty ? labels[0] : ''),
            level2Label: Value(labels.length > 1 ? labels[1] : null),
            level3Label: Value(labels.length > 2 ? labels[2] : null),
            level4Label: Value(labels.length > 3 ? labels[3] : null),
            maxLevels: Value(labels.length),
          ),
        );
  }

  Future<void> _deleteHierarchyConfig(String curriculumId) async {
    await (_database.delete(
      _database.curriculumHierarchyConfig,
    )..where((t) => t.curriculumId.equals(curriculumId))).go();
  }

  /// Seed default stage definitions: learn (0 days), chazara1 (1 day), chazara2 (7 days).
  Future<void> _seedDefaultStageDefinitions(String curriculumId) async {
    final defaultStages = [
      StageDefinitionsCompanion(
        curriculumId: Value(curriculumId),
        stageOrder: const Value(0),
        stageName: const Value('learn'),
        delayDays: const Value(0),
        isDefault: const Value(true),
      ),
      StageDefinitionsCompanion(
        curriculumId: Value(curriculumId),
        stageOrder: const Value(1),
        stageName: const Value('chazara1'),
        delayDays: const Value(1),
        isDefault: const Value(true),
      ),
      StageDefinitionsCompanion(
        curriculumId: Value(curriculumId),
        stageOrder: const Value(2),
        stageName: const Value('chazara2'),
        delayDays: const Value(7),
        isDefault: const Value(true),
      ),
    ];

    for (final stage in defaultStages) {
      await _database.stageDao.insertStageDefinition(stage);
    }
  }

  /// Sync import metadata to Firestore for multi-device skip detection.
  Future<void> _syncImportMetadata(String curriculumId, int itemCount) async {
    try {
      // Push metadata to Firestore via sync engine
      // This allows other devices to detect that curriculum was already imported
      await _syncEngine.pushCurriculumImportMetadata(
        curriculumId: curriculumId,
        itemCount: itemCount,
        importedAt: DateTime.now(),
      );
      _logger.info('Synced import metadata for $curriculumId to Firestore');
    } catch (e) {
      _logger.warning('Failed to sync import metadata: $e');
      // Don't fail the import if sync fails - it's non-critical
    }
  }

  void _emitProgress(ImportProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  Future<void> dispose() async {
    await _progressController.close();
  }
}
