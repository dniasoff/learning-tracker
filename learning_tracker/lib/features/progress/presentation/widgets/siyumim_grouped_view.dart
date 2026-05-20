import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_milestone_label.dart';

/// Hierarchy-aware grouped view of milestones, by curriculum.
///
/// Within each curriculum section the layout follows the IA brief:
///
///   1. **Curriculum-complete card** (if any) — visually distinguished with
///      a gold border and the curriculum-specific siyum label
///      (Siyum HaShas / Siyum HaTorah / etc.).
///   2. **Aggregate rows** (Siyum Seder X / Siyum Chelek X) — expandable to
///      show the contained unit names.
///   3. **Standalone unit rows** — units NOT part of an aggregate already
///      shown, displayed as a flat list at the bottom.
///
/// No provenance label is rendered. The achievedAt date is shown as a
/// timestamp (not as a "live vs bulk" tag).
class SiyumimGroupedView extends ConsumerWidget {
  const SiyumimGroupedView({super.key, required this.viewModel});

  final JourneyViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show curricula that actually have any milestones — pure
    // "no completions" rows are noise on a screen titled "Siyumim &
    // Milestones".
    final visible = viewModel.curricula
        .where((c) => c.milestones.isNotEmpty)
        .toList();
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No siyumim yet — keep learning!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        return _CurriculumSection(journey: visible[index]);
      },
    );
  }
}

/// One curriculum block: optional curriculum-complete hero card →
/// aggregate rows → standalone unit rows.
class _CurriculumSection extends ConsumerWidget {
  const _CurriculumSection({required this.journey});

  final CurriculumJourney journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.getCurriculumColor(journey.curriculumId);
    final terms = domainTermLabels(ref);

    // ── Partition milestones by level ─────────────────────────────────────
    final curriculumMilestones = journey.milestones
        .where((m) => m.level == MilestoneLevel.curriculum)
        .toList();
    final aggregates = journey.milestones
        .where((m) => m.level == MilestoneLevel.aggregate)
        .toList();
    final units = journey.milestones
        .where((m) => m.level == MilestoneLevel.unit)
        .toList();

    // Build the set of unit keys absorbed into an aggregate so the
    // "standalone units" list excludes them — they're shown nested inside
    // the aggregate's expansion tile instead.
    final absorbedUnitKeys = <String>{};
    for (final agg in aggregates) {
      absorbedUnitKeys.addAll(agg.containedUnitKeys);
    }
    final standaloneUnits = units
        .where((m) => !absorbedUnitKeys.contains(m.unitKey))
        .toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    // Aggregates sorted newest first.
    final aggregatesSorted = [...aggregates]
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Curriculum header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: CurriculumLabel.curriculum(
              journey.curriculumId,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),

          // ── 1. Curriculum-complete hero card (gold border) ───────────────
          for (final m in curriculumMilestones)
            _CurriculumCompleteHero(milestone: m, terms: terms),

          // ── 2. Aggregate rows (expandable) ───────────────────────────────
          for (final m in aggregatesSorted)
            _AggregateMilestoneTile(
              milestone: m,
              curriculumId: journey.curriculumId,
              accentColor: color,
              terms: terms,
            ),

          // ── 3. Standalone unit rows ──────────────────────────────────────
          for (final m in standaloneUnits)
            _UnitMilestoneTile(
              milestone: m,
              accentColor: color,
              terms: terms,
            ),
        ],
      ),
    );
  }
}

/// Visually-distinguished hero card for a curriculum-complete siyum.
///
/// Uses a gold border + larger badge per the IA brief's display rules.
class _CurriculumCompleteHero extends StatelessWidget {
  const _CurriculumCompleteHero({
    required this.milestone,
    required this.terms,
  });

  final MilestoneAchievement milestone;
  final DomainTermLabels terms;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFB300);
    final label = curriculumCompleteSiyumLabel(
      curriculumId: milestone.curriculumId,
      terms: terms,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gold.withValues(alpha: 0.18), gold.withValues(alpha: 0.05)],
          ),
          border: Border.all(color: gold, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: gold, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7A4F00),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(milestone.achievedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable row for an aggregate-level milestone (Siyum Seder / Chelek).
///
/// The header shows the localized "Siyum Seder {name}" label; the expansion
/// body lists the contained masechtos so the user can see exactly what
/// rolled up.
class _AggregateMilestoneTile extends StatelessWidget {
  const _AggregateMilestoneTile({
    required this.milestone,
    required this.curriculumId,
    required this.accentColor,
    required this.terms,
  });

  final MilestoneAchievement milestone;
  final CurriculumId curriculumId;
  final Color accentColor;
  final DomainTermLabels terms;

  @override
  Widget build(BuildContext context) {
    final label = aggregateSiyumLabel(
      curriculumId: curriculumId,
      aggregateName: milestone.aggregateKey ?? milestone.displayName,
      terms: terms,
    );
    final containedCount = milestone.containedUnitKeys.length;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
      leading: Icon(Icons.workspace_premium, color: accentColor),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        containedCount > 0
            ? 'All $containedCount complete · ${_formatDate(milestone.achievedAt)}'
            : _formatDate(milestone.achievedAt),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        for (final unitKey in milestone.containedUnitKeys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: accentColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(unitKey, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Row for a standalone unit-level milestone (Siyum Masechta / Sefer /
/// Siman / Hilchos). Used both inside grouped curriculum sections and in
/// the timeline view.
class _UnitMilestoneTile extends StatelessWidget {
  const _UnitMilestoneTile({
    required this.milestone,
    required this.accentColor,
    required this.terms,
  });

  final MilestoneAchievement milestone;
  final Color accentColor;
  final DomainTermLabels terms;

  @override
  Widget build(BuildContext context) {
    final unitName = milestone.unitKey ?? milestone.displayName;
    final scope = milestone.unitScope ?? 'masechta';
    final label = unitSiyumLabel(
      unitName: unitName,
      unitScope: scope,
      terms: terms,
    );
    return ListTile(
      dense: true,
      leading: Icon(Icons.star, color: accentColor),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatDate(milestone.achievedAt),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Format a [DateTime] in the local timezone as `d/M/yyyy`. Centralised so
/// the screen renders dates consistently across hero card, aggregate
/// subtitle, and unit subtitle.
String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
