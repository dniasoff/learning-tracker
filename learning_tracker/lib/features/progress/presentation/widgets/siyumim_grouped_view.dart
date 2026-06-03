import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/labels/curriculum_level_name.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_milestone_label.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.siyumimEmptyState,
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
    final standaloneUnits =
        units.where((m) => !absorbedUnitKeys.contains(m.unitKey)).toList()
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
            _UnitMilestoneTile(milestone: m, accentColor: color, terms: terms),
        ],
      ),
    );
  }
}

/// Visually-distinguished hero card for a curriculum-complete siyum.
///
/// Uses a gold border + larger badge per the IA brief's display rules.
class _CurriculumCompleteHero extends StatelessWidget {
  const _CurriculumCompleteHero({required this.milestone, required this.terms});

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
            colors: [
              gold.withValues(alpha: 0.18),
              gold.withValues(alpha: 0.05),
            ],
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
                    formatMilestoneDate(context, milestone.achievedAt),
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
class _AggregateMilestoneTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Contained units are masechta names stored as raw content keys
    // (e.g. "Berakhos"); these are level-2 *named* values, so the renderer
    // needs each unit's Hebrew name to render it in Hebrew rather than fall
    // back to the raw key. Resolve a level-2-key → Hebrew-name map from the
    // curriculum's content; null while loading so the renderer transliterates
    // (English) until the names arrive.
    final hebrewByUnitKey = ref
        .watch(curriculumContentProvider(curriculumId))
        .maybeWhen(
          data: (items) {
            final map = <String, String>{};
            for (final item in items) {
              final key = item.level2;
              if (key != null && !map.containsKey(key)) {
                // DNI-386: route the Hebrew name through the core/labels accessor.
                final hebrewName = CurriculumLabelRenderer.hebrewNameOf(item);
                if (hebrewName != null) map[key] = hebrewName;
              }
            }
            return map;
          },
          orElse: () => const <String, String>{},
        );
    final label = aggregateSiyumLabel(
      curriculumId: curriculumId,
      aggregateName: milestone.aggregateKey ?? milestone.displayName,
      terms: terms,
    );
    final containedCount = milestone.containedUnitKeys.length;
    final dateText = formatMilestoneDate(context, milestone.achievedAt);
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
            ? l10n.siyumimAggregateSubtitle(containedCount, dateText)
            : dateText,
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
                  // Render through the shared CurriculumLabel.level control
                  // (masechta = level 2) so the name switches across
                  // Hebrew / Ashkenazi / Sephardi instead of leaking the raw
                  // storage key. hebrewName lets the renderer produce the
                  // Hebrew masechta name when the Hebrew Terms toggle is on.
                  child: CurriculumLabel.level(
                    curriculumId: curriculumId,
                    level: 2,
                    rawValue: unitKey,
                    hebrewName: hebrewByUnitKey[unitKey],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The curriculum-structural unit scopes whose `unitKey` is a *named* value
/// (masechta / sefer / siman / hilchos) that must be transliterated or shown
/// in Hebrew per the active variant — rather than leaking the raw Sefaria
/// storage key into the "Siyum Masechta {name}" frame. Maps each scope to the
/// content level its key lives at (masechta/siman/hilchos are level-2; a sefer
/// is the level-1 unit in two-tier curricula), so the renderer fetches the
/// right level metadata. Both levels are *named*, so even a level mismatch
/// transliterates the name identically.
const Map<String, int> unitScopeContentLevel = {
  'masechta': 2,
  'siman': 2,
  'hilchos': 2,
  'sefer': 1,
};

/// Row for a standalone unit-level milestone (Siyum Masechta / Sefer /
/// Siman / Hilchos). Used both inside grouped curriculum sections and in
/// the timeline view.
class _UnitMilestoneTile extends ConsumerWidget {
  const _UnitMilestoneTile({
    required this.milestone,
    required this.accentColor,
    required this.terms,
  });

  final MilestoneAchievement milestone;
  final Color accentColor;
  final DomainTermLabels terms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = milestone.unitScope ?? 'masechta';
    final rawName = milestone.unitKey ?? milestone.displayName;

    // Resolve the unit name to its variant-aware DISPLAY form before building
    // the "Siyum Masechta {name}" label, mirroring the sibling aggregate tile:
    // the storage key (e.g. "Shabbat") must switch to "Shabbos" (Ashkenazi) /
    // "Shabbat" (Sephardi) / "שבת" (Hebrew) per the active toggle + nusach,
    // while the "Siyum Masechta " frame stays under `terms`/[unitSiyumLabel].
    // Only structural named scopes are transliterated; unknown scopes (which
    // hit [unitSiyumLabel]'s generic fallback) keep the raw value.
    final contentLevel = unitScopeContentLevel[scope];
    final unitName = (contentLevel != null && milestone.unitKey != null)
        ? renderMilestoneName(
            ref,
            curriculumId: milestone.curriculumId,
            level: contentLevel,
            rawValue: rawName,
          )
        : rawName;

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
        formatMilestoneDate(context, milestone.achievedAt),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Resolve a milestone's raw storage key (masechta/sefer/siman/hilchos at a
/// unit level, or a seder/chelek at the aggregate level) to its variant-aware
/// display name.
///
/// Thin delegate to the shared [renderCurriculumLevelName] in the core/labels
/// layer so this surface and the Progress "Breakdown by Level" cards resolve
/// names through ONE implementation (content lookup → Hebrew-name accessor →
/// variant-aware render). Kept as a named helper so the existing timeline /
/// grouped-view call sites stay unchanged.
String renderMilestoneName(
  WidgetRef ref, {
  required CurriculumId curriculumId,
  required int level,
  required String rawValue,
}) => renderCurriculumLevelName(
  ref,
  curriculumId: curriculumId,
  level: level,
  rawValue: rawValue,
);

/// Format a milestone [date] using [DateFormat.yMMMd] for the active locale —
/// US English renders "May 11, 2026" while UK/IL and Hebrew render
/// "11 May 2026" (or the Hebrew equivalent). The bare `d/M/yyyy` numeric
/// form used previously ignored locale conventions, which violated the
/// project's standing date-format rule. Exposed (not `_`-prefixed) so the
/// chronological timeline view can share the same formatter and the two
/// surfaces stay visually consistent.
String formatMilestoneDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(date.toLocal());
}
