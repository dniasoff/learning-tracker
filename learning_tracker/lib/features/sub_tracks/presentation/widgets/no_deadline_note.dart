import 'package:flutter/material.dart';
import 'package:learning_tracker/core/widgets/info_note.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The inline note both sub-track forms show when the curriculum has no
/// deadline goal (Story 2.4 / DNI-495 AC-6, SPEC CAP-3): without a deadline
/// a sub-track cannot lower the daily target. Its link opens the existing
/// goal setup for the same curriculum ([onOpenGoalSetup]).
///
/// The note is informational only: it never disables saving.
class NoDeadlineNote extends StatelessWidget {
  const NoDeadlineNote({required this.onOpenGoalSetup, super.key});

  /// Opens the curriculum's goal setup.
  final VoidCallback onOpenGoalSetup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InfoNote(
      text: l10n.subTrackNoDeadlineNote,
      action: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: onOpenGoalSetup,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsetsDirectional.zero,
          ),
          child: Text(l10n.subTrackNoDeadlineLink),
        ),
      ),
    );
  }
}
