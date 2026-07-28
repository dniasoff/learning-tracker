import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// White ink on the always-saturated brand-blue gradient below.
///
/// The card's gradient (`progressOverallStatsGradient*`) is pinned deep in
/// BOTH light and dark themes (run-11 legibility sweep — see the gradient
/// doc in [AppPalette]), so white foreground text is the correct,
/// brightness-safe colour here regardless of the system theme. Collapsing
/// every white reference in this file onto this single named literal keeps
/// the run-9 raw-color-literal ratchet honest — one legitimate
/// white-on-saturated-brand-surface site, not one per text run
/// (`tool/check_raw_color_literal_ratchet.dart`, exemption #2).
const _onGradient = Colors.white;

/// Card displaying overall curriculum statistics (brand blue surface).
///
/// Reworked (owner decision 2026-07-28,
/// `docs/planning/post-sweep-decisions.md` item #3) into TWO clearly-headed
/// scope sections so the track-scoped counts never read as contradictory
/// beside the whole-curriculum lifetime figure — both numbers are correct,
/// they answer different questions, and each now sits under an explicit
/// scope header:
///
/// * **Section A — "This track · this cycle":** the time-gated
///   [trackProgressFraction] (current-cycle achievement) plus the
///   track/scope-scoped count breakdown carried by [stats]
///   (total items / completed-all-stages / in-progress / not-started). Every
///   value here is computed from the ACTIVE track's own scope
///   (`scopedCurriculumContentProvider` → `CurriculumProgressService`), NOT
///   the full curriculum.
/// * **Section B — "Whole [curriculum] · lifetime":** the whole-curriculum
///   [lifetimeFraction] (distinct items ever touched ÷ total, unscoped)
///   plus an "items touched X / total" line. Rendered only when lifetime
///   data is available; omitted (with its divider) while it loads.
///
/// DO NOT equalise the two percentages — they are deliberately different
/// metrics (see `docs/test-artifacts/run10/progress-percentage-divergence.md`
/// and its run-11 amendment).
class OverallStatsCard extends ConsumerWidget {
  const OverallStatsCard({
    super.key,
    required this.stats,
    this.trackProgressFraction,
    this.lifetimeFraction,
    this.lifetimeLearnedCount,
    this.lifetimeTotalCount,
    this.curriculumName,
  });

  /// Track/scope-scoped overall counts (total / completed-all-stages /
  /// in-progress / not-started) for the ACTIVE track — Section A.
  final OverallCurriculumStats stats;

  /// Current-cycle achievement fraction (time-gated
  /// `currentCyclePercentage`, track-scoped) — the Section A headline
  /// percentage. Null hides the percentage (e.g. while loading / no track).
  final double? trackProgressFraction;

  /// Whole-curriculum lifetime fraction (distinct items ever touched ÷
  /// total, unscoped) — the Section B headline percentage. Null (together
  /// with the counts below) hides Section B entirely.
  final double? lifetimeFraction;

  /// Whole-curriculum count of distinct items ever touched — Section B's
  /// "items touched X / total" line (numerator).
  final int? lifetimeLearnedCount;

  /// Whole-curriculum total item count — Section B's "items touched
  /// X / total" line (denominator).
  final int? lifetimeTotalCount;

  /// Display name of the curriculum, already resolved through the shared
  /// [CurriculumLabelRenderer] by the caller (Rule 5). Interpolated into the
  /// Section B scope header ("Whole [curriculum] · lifetime"); when null a
  /// generic header is used instead.
  final String? curriculumName;

  bool get _showLifetime =>
      lifetimeFraction != null ||
      (lifetimeLearnedCount != null && lifetimeTotalCount != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final sectionBHeader = curriculumName == null
        ? l10n.overallProgressSectionWholeLifetimeGeneric
        : l10n.overallProgressSectionWholeLifetime(curriculumName!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // Deep-hero-fixed tokens (NOT brandBlueDeep/brandBlue/brandBlueBright
        // — those LIGHTEN in dark mode for their normal ink-on-dark-surface
        // role and washed this card out to pale sky-blue when misused as a
        // fill; see AppPalette.progressOverallStatsGradientStart's doc,
        // run-11 progress-area sweep).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colors.progressOverallStatsGradientStart,
            context.colors.progressOverallStatsGradientMid,
            context.colors.progressOverallStatsGradientEnd,
          ],
        ),
        border: Border.all(color: _onGradient.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandBlue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.overallProgressCardTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: _onGradient,
            ),
          ),

          // ── Section A — This track · this cycle ───────────────────────────
          const SizedBox(height: 14),
          _ScopeHeader(text: l10n.overallProgressSectionThisTrackCycle),
          if (trackProgressFraction != null) ...[
            const SizedBox(height: 8),
            _HeadlinePercent(
              label: l10n.trackProgress,
              fraction: trackProgressFraction!,
            ),
          ],
          const SizedBox(height: 6),
          _StatRow(
            label: l10n.overallProgressStatTotalItems,
            value: '${stats.totalItems}',
          ),
          _StatRow(
            label: l10n.overallProgressStatCompletedAllStages,
            value: '${stats.completedAllStages}',
            leadingDot: true,
          ),
          _StatRow(
            label: l10n.overallProgressStatInProgress,
            value: '${stats.inProgress}',
            leadingDot: true,
          ),
          _StatRow(
            label: l10n.overallProgressStatNotStarted,
            value: '${stats.notStarted}',
            leadingDot: true,
          ),

          // ── Section B — Whole [curriculum] · lifetime ─────────────────────
          if (_showLifetime) ...[
            Divider(
              color: _onGradient.withValues(alpha: 0.22),
              height: 26,
              thickness: 1,
            ),
            _ScopeHeader(text: sectionBHeader),
            if (lifetimeFraction != null) ...[
              const SizedBox(height: 8),
              _HeadlinePercent(
                label: l10n.lifetimeLabel,
                fraction: lifetimeFraction!,
              ),
            ],
            if (lifetimeLearnedCount != null && lifetimeTotalCount != null) ...[
              const SizedBox(height: 6),
              _StatRow(
                label: l10n.overallProgressStatLifetimeItemsTouched,
                value: l10n.itemsLearnedOf(
                  lifetimeLearnedCount!,
                  lifetimeTotalCount!,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A section scope header (e.g. "This track · this cycle") — the label that
/// disambiguates which numbers below it belong to which scope.
class _ScopeHeader extends StatelessWidget {
  const _ScopeHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: _onGradient.withValues(alpha: 0.82),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        height: 1.2,
      ),
    );
  }
}

/// A headline percentage for one section: a small metric label above a large
/// percentage value. Either the current-cycle "Track progress" figure
/// (Section A) or the whole-curriculum "Lifetime" figure (Section B).
class _HeadlinePercent extends StatelessWidget {
  const _HeadlinePercent({required this.label, required this.fraction});

  final String label;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Adaptive precision (matches the Lifetime Knowledge curriculum
    // breakdown): small non-zero fractions render "0.1%" instead of being
    // floored to "0%", so the same fraction reads consistently across the
    // Progress hub, track-detail and Lifetime Knowledge surfaces (Bug 3).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: _onGradient.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatFractionAsPercent(fraction),
          maxLines: 1,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: _onGradient,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.leadingDot = false,
  });

  final String label;
  final String value;
  final bool leadingDot;

  static final _dotColor = _onGradient.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (leadingDot) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _onGradient.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _onGradient,
            ),
          ),
        ],
      ),
    );
  }
}
