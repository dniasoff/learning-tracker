/// The tutor write-control affordances (Story 1.24, DNI-486, AC-4 / AC-5):
/// a write control the tutor may not use right now stays VISIBLE, is drawn
/// at 40% opacity and is disabled (the caller passes a null handler, so the
/// control itself reports disabled semantics), with one plain-text note
/// saying why — never colour alone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The opacity of a visible-but-disabled tutor write control.
const double tutorDisabledControlOpacity = 0.4;

/// Draws [child] at [tutorDisabledControlOpacity] while [blocked], with
/// pointer input absorbed and its semantics marked disabled. The caller
/// still nulls the control's handler, so the control's own semantics agree.
class TutorDisabledControl extends StatelessWidget {
  /// Creates the wrapper.
  const TutorDisabledControl({
    super.key,
    required this.blocked,
    required this.child,
  });

  /// Whether the control is disabled for the tutor.
  final bool blocked;

  /// The control.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!blocked) return child;
    return Opacity(
      key: const Key('tutorDisabledControl'),
      opacity: tutorDisabledControlOpacity,
      child: AbsorbPointer(child: Semantics(enabled: false, child: child)),
    );
  }
}

/// The one note under a tutor's disabled write controls: the parent-access
/// note without `can_edit_learning`, "Online required" offline, nothing
/// otherwise (a locked learner is covered by the lock overlay).
class TutorWriteNote extends ConsumerWidget {
  /// Creates the note.
  const TutorWriteNote({super.key, this.padding = EdgeInsets.zero});

  /// Space around the note when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = tutorWriteNoteText(
      AppLocalizations.of(context)!,
      ref.watch(tutorWriteAvailabilityProvider),
      learnerName: ref
          .watch(activeProfileProvider)
          .asData
          ?.value
          ?.displayName
          .trim(),
    );
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.colors.brandInkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: const Key('tutorWriteNote'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.brandInkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The note text for [availability]; null when no note shows. An unknown
/// learner name falls back to the generic permission copy.
String? tutorWriteNoteText(
  AppLocalizations l10n,
  TutorWriteAvailability availability, {
  String? learnerName,
}) => switch (availability) {
  TutorWriteAvailability.noEditAccess =>
    learnerName == null || learnerName.isEmpty
        ? l10n.tutorPermissionDenied
        : l10n.tutorCaptureNoEditAccess(learnerName),
  TutorWriteAvailability.offline => l10n.tutorCaptureOnlineRequired,
  TutorWriteAvailability.owner ||
  TutorWriteAvailability.available ||
  TutorWriteAvailability.locked => null,
};
