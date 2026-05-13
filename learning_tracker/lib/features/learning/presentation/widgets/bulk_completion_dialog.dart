import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

/// Dialog for marking multiple content items as completed in bulk.
///
/// Example use case: "Mark this whole perek as learned"
class BulkCompletionDialog extends ConsumerStatefulWidget {
  final String curriculumId;
  final List<String> sefariaRefs;
  final int stageId;
  final String trackType;
  final UserMode userMode;
  final String itemsDescription; // e.g., "Perek 1 (8 mishnas)"

  const BulkCompletionDialog({
    required this.curriculumId,
    required this.sefariaRefs,
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
        sefariaRefs: widget.sefariaRefs,
        stageId: widget.stageId,
        trackType: widget.trackType,
      );

      final completions = await useCase(request);

      if (mounted) {
        Navigator.of(context).pop(completions);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.bulkMarkedComplete(completions.length)),
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
            content: Text(AppLocalizations.of(context)!.errorMarkCompleteFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.bulkMarkCompleteTitle),
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
            '${widget.sefariaRefs.length} items will be marked',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.actionCancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleConfirm,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.actionConfirm),
        ),
      ],
    );
  }
}
