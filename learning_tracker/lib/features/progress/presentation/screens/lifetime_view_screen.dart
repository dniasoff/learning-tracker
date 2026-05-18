import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Full-history view: track completions PLUS all bulk-marked lifetime items.
///
/// Identical layout to [ItemsLearnedScreen] but data comes from
/// [lifetimeViewSummariesProvider] which delegates to [lifetimeDataProvider]
/// and therefore includes both daily-learning completions and ledger-based
/// bulk-mark entries.
@RoutePage()
class LifetimeViewScreen extends ConsumerWidget {
  const LifetimeViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(activeProfileIdProvider);
    final summariesAsync = ref.watch(lifetimeViewSummariesProvider(profileId));
    final l10n = AppLocalizations.of(context)!;
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme);

    return Scaffold(
      backgroundColor: AppTheme.brandCream,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.brandCream,
        foregroundColor: AppTheme.brandInk,
        title: Text(
          l10n.lifetimeViewTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
      ),
      body: Theme(
        data: baseTheme.copyWith(textTheme: textTheme),
        child: summariesAsync.when(
          data: (summaries) {
            // Sort by canonical learning order (CurriculumId enum index).
            final withProgress =
                summaries.where((s) => s.learnedLeafCount > 0).toList()..sort(
                  (a, b) =>
                      a.curriculumId.index.compareTo(b.curriculumId.index),
                );

            if (withProgress.isEmpty) {
              return EmptyState(
                message: l10n.itemsLearnedNoCurricula,
                subtitle: l10n.itemsLearnedNoCurriculaSubtitle,
                icon: Icons.history_edu_outlined,
              );
            }

            return CurriculumBreakdownList(summaries: withProgress);
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 48),
              child: LoadingIndicator(message: 'Loading…'),
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorDisplay(
              message: 'Failed to load: $error',
              onRetry: () =>
                  ref.invalidate(lifetimeViewSummariesProvider(profileId)),
            ),
          ),
        ),
      ),
    );
  }
}
