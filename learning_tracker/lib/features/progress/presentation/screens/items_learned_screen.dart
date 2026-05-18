import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shows track-only completions broken down by curriculum hierarchy.
///
/// "Track completions" are rows in the completions table with a real study
/// date — i.e. NOT the bulk-prior sentinel `DateTime.utc(2000,1,1)`.
/// Tapping a curriculum row expands a tree view of learned items.
///
/// A [TextButton] in the app-bar links to [LifetimeViewScreen] for the
/// full-history (all completions + ledger bulk-marks) view.
@RoutePage()
class ItemsLearnedScreen extends ConsumerWidget {
  const ItemsLearnedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(activeProfileIdProvider);
    final summariesAsync = ref.watch(itemsLearnedSummariesProvider(profileId));
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
          l10n.itemsLearnedTitle,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.router.push(const LifetimeViewRoute()),
            icon: const Icon(Icons.history_edu_outlined, size: 18),
            label: Text(
              l10n.lifetimeViewTitle,
              style: textTheme.labelMedium?.copyWith(
                color: AppTheme.brandBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
                icon: Icons.menu_book_outlined,
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
                  ref.invalidate(itemsLearnedSummariesProvider(profileId)),
            ),
          ),
        ),
      ),
    );
  }
}
