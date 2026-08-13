import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Shared top counter row used by both Progress hub and Dashboard.
///
/// Renders one counter per tier in the three-tier completion credit policy:
///
///   - Engagement tier — current streak (`tierCounterStreakDays`)
///   - Achievement tier — total siyumim across all three celebration levels
///     (unit + aggregate + curriculum), via [journeyViewModelProvider]
///   - Lifetime tier — distinct items ever touched, via
///     [lifetimeTotalsAcrossAllCurriculaProvider]
///
/// Child-mode adds a fourth ⭐ points counter (via [dashboardGlobalPointsProvider]).
///
/// All labels are routed through `domainTermLabels(ref)` so the Hebrew Terms
/// toggle swaps script live. Caller passes [showPoints] explicitly so the
/// caller's own user-mode lookup is the single source of truth (the row
/// itself doesn't gate on [ProfileMode]).
///
/// See `docs/planning/progress-ia-redesign.md` §2 for the spec.
class ProgressTierCounterRow extends ConsumerWidget {
  const ProgressTierCounterRow({super.key, required this.showPoints});

  /// When true, renders the fourth ⭐ points counter (child mode).
  final bool showPoints;

  /// Placeholder rendered in place of a number while its provider is loading.
  static const String _loadingPlaceholder = '…';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final journeyAsync = ref.watch(journeyViewModelProvider);
    final lifetimeTotalsAsync = ref.watch(
      lifetimeTotalsAcrossAllCurriculaProvider,
    );
    final pointsAsync = ref.watch(dashboardGlobalPointsProvider);

    final currentStreak = streakAsync.asData?.value.currentStreak ?? 0;
    final journey = journeyAsync.asData?.value;
    final totalSiyumim = journey == null
        ? 0
        : journey.unitLevelSiyumimCount +
              journey.aggregateLevelSiyumimCount +
              journey.curriculumLevelSiyumimCount;
    final lifetimeItems =
        lifetimeTotalsAsync.asData?.value.learnedSections ?? 0;
    final points = pointsAsync.asData?.value ?? 0;

    // Locale-aware thousands separator (1336 → "1,336" in en-US,
    // "1,336" in he-IL).  Keeps four-digit counts (and beyond)
    // readable on the dashboard tile row.
    final locale = Localizations.localeOf(context).toString();
    final numberFormat = NumberFormat.decimalPattern(locale);

    final streakValue = streakAsync.hasValue
        ? numberFormat.format(currentStreak)
        : _loadingPlaceholder;
    final siyumimValue = journeyAsync.hasValue
        ? numberFormat.format(totalSiyumim)
        : _loadingPlaceholder;
    final lifetimeValue = lifetimeTotalsAsync.hasValue
        ? numberFormat.format(lifetimeItems)
        : _loadingPlaceholder;
    final pointsValue = pointsAsync.hasValue
        ? numberFormat.format(points)
        : _loadingPlaceholder;

    String semanticLabel(AsyncValue<dynamic> value, String dataLabel) {
      if (value.hasError) return l10n.errorWithMessage;
      if (!value.hasValue) return l10n.loading;
      return dataLabel;
    }

    final counters = <Widget>[
      _Counter(
        emoji: '🔥',
        value: streakValue,
        label: l10n.tierTileLabelStreak,
        semanticLabel: semanticLabel(
          streakAsync,
          l10n.tierCounterStreakDays(currentStreak),
        ),
        accent: context.colors.progressTierStreakAccent,
        error: streakAsync.error,
        onRetry: () => ref.invalidate(dashboardStreakProvider),
      ),
      _Counter(
        emoji: '🏆',
        value: siyumimValue,
        label: l10n.tierTileLabelSiyumim(terms.siyumim),
        semanticLabel: semanticLabel(
          journeyAsync,
          l10n.tierCounterSiyumimEarned(totalSiyumim, terms.siyumim),
        ),
        accent: context.colors.progressTierSiyumimAccent,
        error: journeyAsync.error,
        onRetry: () => ref.invalidate(journeyViewModelProvider),
      ),
      _Counter(
        emoji: '📚',
        value: lifetimeValue,
        label: l10n.tierTileLabelLifetime,
        semanticLabel: semanticLabel(
          lifetimeTotalsAsync,
          l10n.tierCounterLifetimeItems(lifetimeItems),
        ),
        accent: context.colors.brandBlue,
        error: lifetimeTotalsAsync.error,
        onRetry: () => ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider),
      ),
      if (showPoints)
        _Counter(
          emoji: '⭐',
          value: pointsValue,
          label: l10n.tierTileLabelPoints,
          semanticLabel: semanticLabel(
            pointsAsync,
            l10n.tierCounterPoints(points),
          ),
          accent: context.colors.progressTierPointsAccent,
          error: pointsAsync.error,
          onRetry: () => ref.invalidate(dashboardGlobalPointsProvider),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use a Row with equal-flex cells. Each counter sizes itself; the
        // labels wrap to keep the row a fixed height across counter counts.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < counters.length; i++) ...[
              Expanded(child: counters[i]),
              if (i < counters.length - 1) const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

/// One vertical counter cell: emoji + big number + short noun label.
///
/// [label] is the short visible noun (e.g. "Streak"). The big [value]
/// above it already shows the count — the label deliberately doesn't
/// repeat it so the tile width is sufficient to render the noun without
/// ellipsis. [semanticLabel] carries the descriptive form (e.g.
/// "0-day streak") for screen readers.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.emoji,
    required this.value,
    required this.label,
    required this.semanticLabel,
    required this.accent,
    this.error,
    this.onRetry,
  });

  final String emoji;
  final String value;
  final String label;
  final String semanticLabel;
  final Color accent;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$emoji $semanticLabel',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.brandCreamCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.colors.blueNavy.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            // FittedBox scales the value down to one line if a thousands-
            // separated number (e.g. "1,336") would otherwise wrap on the
            // narrower Progress-hub tile width. The Dashboard tile is wider
            // and the value renders at its natural size there.
            if (error != null)
              InlineAsyncError(error: error!, onRetry: onRetry)
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.colors.brandInkMuted,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
