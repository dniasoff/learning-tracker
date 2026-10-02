/// The parent shortfall warning card (Story 2.11, DNI-502; FR-21,
/// UX-DR-22, UX-DR-68, UX-DR-76).
///
/// One full-width amber card per sub-track whose engine shortfall is
/// positive, directly under the on-track card: "{name} may not reach
/// {ground} before {month}. About {n} {unit} will return to home
/// learning." The count is the engine's de-duplicated FR-19 shortfall for
/// that track ([SubTrackState.shortfall]); the card keeps no state, so it
/// is gone on the first recompute after the shortfall reaches 0.
///
/// Parent-only: the warnings come from [parentForecastProvider], which is
/// empty outside a parent session (NFR-9, UX-DR-97). Amber
/// (`brandWarningSoft` fill, `brandWarningDeep` text and icons) is never
/// used on a child surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Formats the month of an AD-41 civil date ("July 2027").
String formatForecastMonth(BuildContext context, CivilDate date) =>
    DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.parse(date));

/// The shortfall warnings of one curriculum's forecast, in order.
class ShortfallWarningList extends StatelessWidget {
  /// Creates the list.
  const ShortfallWarningList({super.key, required this.forecast});

  /// The forecast whose [CurriculumForecast.shortfalls] to show.
  final CurriculumForecast forecast;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final warning in forecast.shortfalls) ...[
        const SizedBox(height: 10),
        ShortfallWarningCard(
          warning: warning,
          deadline: forecast.projection.deadline,
        ),
      ],
    ],
  );
}

/// One sub-track's shortfall warning.
class ShortfallWarningCard extends ConsumerWidget {
  /// Creates the card.
  const ShortfallWarningCard({
    super.key,
    required this.warning,
    required this.deadline,
  });

  /// The engine values.
  final ShortfallWarning warning;

  /// The deadline, named when the sub-track's window has no end.
  final CivilDate? deadline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final ink = colors.brandWarningDeep;
    final node = warning.lastShortfallNode;
    final ground = node == null
        ? l10n.shortfallCardGroundFallback
        : ref.watch(renderedDisplayForRefProvider(node.ref)).value ?? node.ref;
    // FR-21 names the window end; an open ongoing window runs to the
    // deadline, the end of the capacity interval (AD-44).
    final end = warning.windowEnd ?? deadline;
    final message = l10n.shortfallCardMessage(
      warning.name,
      ground,
      end == null ? '' : formatForecastMonth(context, end),
      formatForecastCount(context, warning.shortfall),
      forecastLeafUnit(
        ref,
        l10n,
        CurriculumId.fromStorageKey(warning.curriculumId),
        count: warning.shortfall,
      ),
    );
    final open = ref.watch(subTrackDetailOpenerProvider);

    return ForecastCardFrame(
      key: Key('shortfallCard-${warning.subTrackId}'),
      color: colors.brandWarningSoft,
      borderColor: colors.brandWarningSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, size: 20, color: ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  key: const Key('shortfallCardMessage'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('shortfallCardView'),
                    onPressed: open == null
                        ? null
                        : () => open(context, warning),
                    style: TextButton.styleFrom(foregroundColor: ink),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(l10n.shortfallCardView(warning.name)),
                        ),
                        const SizedBox(width: 4),
                        // Mirrors under RTL (matchTextDirection).
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
