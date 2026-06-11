import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_milestone_label.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_grouped_view.dart'
    show formatMilestoneDate, renderMilestoneName, unitScopeContentLevel;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Chronological view of all siyumim (unit + aggregate + curriculum) across
/// every curriculum, newest first, grouped by month.
///
/// Per the IA brief: timeline mode "flattens the hierarchy" — each
/// milestone is a peer row. The screen still distinguishes the three levels
/// via icon (star / workspace_premium / emoji_events) and the
/// per-curriculum accent colour.
class SiyumimTimelineView extends ConsumerWidget {
  const SiyumimTimelineView({super.key, required this.viewModel});

  final JourneyViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flatten every milestone, paired with its curriculum context.
    final entries = <_TimelineEntry>[];
    for (final curriculum in viewModel.curricula) {
      for (final milestone in curriculum.milestones) {
        entries.add(
          _TimelineEntry(
            milestone: milestone,
            curriculumId: curriculum.curriculumId,
          ),
        );
      }
    }

    if (entries.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          l10n.siyumimEmptyState,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Newest first.
    entries.sort(
      (a, b) => b.milestone.achievedAt.compareTo(a.milestone.achievedAt),
    );

    // Group by month using a locale-aware formatter (TS-13: replaced the
    // hardcoded English month array with DateFormat.yMMM so month headers
    // adapt to the active locale instead of always rendering English).
    final locale = Localizations.localeOf(context).toString();
    final monthFormatter = DateFormat.yMMM(locale);
    final byMonth = <String, List<_TimelineEntry>>{};
    for (final entry in entries) {
      final key = monthFormatter.format(entry.milestone.achievedAt);
      byMonth.putIfAbsent(key, () => []).add(entry);
    }

    final months = byMonth.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      itemBuilder: (context, idx) {
        final month = months[idx];
        final monthEntries = byMonth[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                month,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final e in monthEntries) _TimelineCard(entry: e),
          ],
        );
      },
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.milestone, required this.curriculumId});

  final MilestoneAchievement milestone;
  final CurriculumId curriculumId;
}

class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.getCurriculumColor(entry.curriculumId);
    final terms = domainTermLabels(ref);
    final m = entry.milestone;

    // Pick icon by level.
    late final IconData icon;
    late final String label;
    switch (m.level) {
      case MilestoneLevel.curriculum:
        icon = Icons.emoji_events;
        label = curriculumCompleteSiyumLabel(
          curriculumId: entry.curriculumId,
          terms: terms,
        );
      case MilestoneLevel.aggregate:
        icon = Icons.workspace_premium;
        // Resolve the seder/chelek name (a level-1 named value) to its
        // variant-aware display form before framing it as "Siyum Seder {name}",
        // mirroring the grouped view so the timeline follows the Hebrew-terms
        // toggle and Ashkenazi/Sephardi nusach instead of leaking the raw
        // Sefaria key (e.g. "Tahorot" vs "Tahoros").
        final aggregateRaw = m.aggregateKey ?? m.displayName;
        final aggregateName = m.aggregateKey != null
            ? renderMilestoneName(
                ref,
                curriculumId: entry.curriculumId,
                level: 1,
                rawValue: aggregateRaw,
              )
            : aggregateRaw;
        label = aggregateSiyumLabel(
          curriculumId: entry.curriculumId,
          aggregateName: aggregateName,
          terms: terms,
        );
      case MilestoneLevel.unit:
        icon = Icons.star;
        // Resolve the masechta/sefer/siman/hilchos name to its variant-aware
        // display form before framing it as "Siyum Masechta {name}", so the
        // raw key (e.g. "Shabbat") switches to "Shabbos" / "Shabbat" / "שבת"
        // per the active toggle + nusach. Only structural named scopes are
        // resolved; unknown scopes keep the raw value (generic fallback frame).
        final scope = m.unitScope ?? 'masechta';
        final unitRaw = m.unitKey ?? m.displayName;
        final contentLevel = unitScopeContentLevel[scope];
        final unitName = (contentLevel != null && m.unitKey != null)
            ? renderMilestoneName(
                ref,
                curriculumId: entry.curriculumId,
                level: contentLevel,
                rawValue: unitRaw,
              )
            : unitRaw;
        label = unitSiyumLabel(
          unitName: unitName,
          unitScope: scope,
          terms: terms,
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: CurriculumLabel.curriculum(
                entry.curriculumId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: Text(
                ' · ${formatMilestoneDate(context, m.achievedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
