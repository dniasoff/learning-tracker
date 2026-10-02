import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The Lifetime screen's *Report* entry (Story 5.2, DNI-517; UX-DR-61).
///
/// Shown only in a parent session ([parentSessionProvider]); a child,
/// PIN-locked or tutor session sees nothing here (AC-2) and keeps the rest
/// of the Lifetime screen unchanged. While the session resolves nothing is
/// shown (fail closed).
///
/// The report opens for [curriculumId], the curriculum the Lifetime screen
/// has in view (AC-1); null leaves the choice to the report.
class LifetimeReportEntry extends ConsumerWidget {
  /// Creates the entry.
  const LifetimeReportEntry({super.key, this.curriculumId});

  /// The curriculum in view on Lifetime (a storage key), or null.
  final String? curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = ref.watch(parentSessionProvider).value ?? false;
    if (!parent) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Tooltip(
        message: l10n.reportEntryTooltip,
        child: TextButton.icon(
          key: const ValueKey('lifetimeReportEntry'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.assessment_outlined),
          label: Text(l10n.reportEntry),
          onPressed: () => context.router.push(
            LifetimeReportRoute(curriculumId: curriculumId),
          ),
        ),
      ),
    );
  }
}
