import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class SocialSummaryProfileScreen extends ConsumerWidget {
  const SocialSummaryProfileScreen({
    super.key,
    @PathParam('summaryId') required this.summaryId,
  });

  final String summaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summary = ref.watch(socialSummaryProvider(summaryId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityProfile)),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.communitySummaryUnavailable)),
        data: (value) => value == null
            ? Center(child: Text(l10n.communitySummaryUnavailable))
            : _SummaryContent(summary: value),
      ),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent({required this.summary});

  final SocialSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Text(summary.displayName.characters.first.toUpperCase()),
          ),
          title: Text(
            summary.displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(
            l10n.communityUpdatedAt(
              MaterialLocalizations.of(
                context,
              ).formatMediumDate(summary.computedAt),
            ),
          ),
        ),
        const Divider(),
        _SectionTitle(l10n.communityStreak),
        for (final streak in summary.streak.byCurriculum)
          ListTile(
            title: Text(_curriculumLabel(ref, streak.curriculumId)),
            subtitle: Text(
              l10n.communityStreakValues(streak.currentDays, streak.bestDays),
            ),
            leading: const Icon(Icons.local_fire_department_outlined),
          ),
        _SectionTitle(l10n.communityCurrentTracks),
        for (final track in summary.currentTracks)
          ListTile(
            title: Text(_curriculumLabel(ref, track.curriculumId)),
            subtitle: track.positionRef == null
                ? null
                : _SummaryRefLabel(track.positionRef!),
            leading: const Icon(Icons.menu_book_outlined),
          ),
        _SectionTitle(l10n.communityThisWeek),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, bottom: 4),
          child: Text(
            l10n.communityWeekOf(
              MaterialLocalizations.of(context).formatMediumDate(
                DateTime.parse('${summary.weeklyLearning.weekStart}T00:00:00Z'),
              ),
            ),
          ),
        ),
        for (final activity in summary.weeklyLearning.byCurriculum)
          ListTile(
            title: Text(_curriculumLabel(ref, activity.curriculumId)),
            subtitle: Text(
              l10n.communityWeeklyCounts(activity.limudim, activity.chazaros),
            ),
            leading: const Icon(Icons.calendar_view_week_outlined),
          ),
        _SectionTitle(l10n.communitySiyumim),
        if (summary.siyumim.isEmpty)
          ListTile(title: Text(l10n.communityNoSiyumim))
        else
          for (final siyum in summary.siyumim)
            ListTile(
              title: _SummaryRefLabel(siyum.ref),
              leading: const Icon(Icons.emoji_events_outlined),
            ),
      ],
    );
  }
}

String _curriculumLabel(WidgetRef ref, String key) {
  final curriculum = CurriculumId.fromStorageKey(key);
  if (curriculum == null) return key;
  return curriculumLabelText(ref, curriculum: curriculum);
}

class _SummaryRefLabel extends ConsumerWidget {
  const _SummaryRefLabel(this.refValue);

  final String refValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rendered = ref.watch(renderedDisplayForRefProvider(refValue));
    return rendered.when(
      loading: () => Text(refValue),
      error: (_, __) => Text(refValue),
      data: Text.new,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}
