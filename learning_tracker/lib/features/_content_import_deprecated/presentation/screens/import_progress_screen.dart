import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_import/domain/models/import_progress.dart';
import 'package:learning_tracker/features/content_import/presentation/providers/import_providers.dart';

/// Screen displaying curriculum import progress with retry/cancel options.
class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({required this.curriculum, super.key});

  final CurriculumId curriculum;

  @override
  ConsumerState<ImportProgressScreen> createState() =>
      _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    if (_isImporting) return;

    setState(() => _isImporting = true);

    try {
      final service = ref.read(curriculumImportServiceProvider);
      await service.importCurriculum(widget.curriculum);
    } catch (e) {
      // Error will be shown via progress stream
    } finally {
      setState(() => _isImporting = false);
    }
  }

  void _cancelImport() {
    final service = ref.read(curriculumImportServiceProvider);
    service.cancelImport();
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(importProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Importing ${widget.curriculum.displayNameEn}'),
      ),
      body: progressAsync.when(
        data: (progress) => _buildProgressBody(context, progress),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error.toString()),
      ),
    );
  }

  Widget _buildProgressBody(BuildContext context, ImportProgress progress) {
    return progress.when(
      idle: () => const Center(child: Text('Ready to import')),
      fetching: (curriculumId) => _buildProgressState(
        context,
        'Fetching…',
        'Downloading curriculum structure from Sefaria',
        null,
      ),
      parsing: (curriculumId, itemsFetched) => _buildProgressState(
        context,
        'Parsing…',
        'Processing $itemsFetched items',
        null,
      ),
      storing: (curriculumId, totalItems, storedItems) => _buildProgressState(
        context,
        'Storing…',
        'Saving to database',
        storedItems / totalItems,
      ),
      completed: (curriculumId, totalItems) =>
          _buildCompletedState(context, totalItems),
      error: (curriculumId, message, errorCode) => _buildErrorState(
        context,
        message,
        showRetry: errorCode == 'NETWORK_ERROR',
      ),
      cancelled: (curriculumId) => _buildCancelledState(context),
    );
  }

  Widget _buildProgressState(
    BuildContext context,
    String title,
    String subtitle,
    double? progress,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (progress != null)
            LinearProgressIndicator(value: progress)
          else
            const LinearProgressIndicator(),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: _cancelImport,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState(BuildContext context, int totalItems) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Import Complete!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '$totalItems items imported successfully',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String message, {
    bool showRetry = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Import Failed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (showRetry)
              ElevatedButton.icon(
                onPressed: _startImport,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'Import Cancelled',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
