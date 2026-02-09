import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

/// Dialog for marking multiple content items as completed in bulk.
///
/// Example use case: "Mark this whole perek as learned"
class BulkCompletionDialog extends ConsumerStatefulWidget {
  final String curriculumId;
  final List<int> contentItemIds;
  final int stageId;
  final String trackType;
  final UserMode userMode;
  final String itemsDescription; // e.g., "Perek 1 (8 mishnas)"

  const BulkCompletionDialog({
    required this.curriculumId,
    required this.contentItemIds,
    required this.stageId,
    required this.trackType,
    required this.userMode,
    required this.itemsDescription,
    super.key,
  });

  @override
  ConsumerState<BulkCompletionDialog> createState() =>
      _BulkCompletionDialogState();
}

class _BulkCompletionDialogState extends ConsumerState<BulkCompletionDialog> {
  bool _isLoading = false;

  Future<void> _handleConfirm() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final useCase = ref.read(bulkMarkCompletionUseCaseProvider);
      final request = BulkCompletionRequest(
        curriculumId: widget.curriculumId,
        contentItemIds: widget.contentItemIds,
        stageId: widget.stageId,
        trackType: widget.trackType,
      );

      final completions = await useCase(request);

      if (mounted) {
        Navigator.of(context).pop(completions);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${completions.length} items as complete',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark complete: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Mark Complete'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mark ${widget.itemsDescription} as complete?',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.contentItemIds.length} items will be marked',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleConfirm,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
