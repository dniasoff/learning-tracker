import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/features/social/domain/social_summary.dart';
import 'package:learning_tracker/features/social/domain/social_summary_visibility.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Renders the shared progress sections in follower profiles and owner previews.
class SocialSummarySections extends ConsumerWidget {
  const SocialSummarySections({
    required this.summary,
    this.visibility = const SocialSummaryVisibility.allOn(),
    this.showEmptyMessage = false,
    super.key,
  });

  final SocialSummary summary;
  final SocialSummaryVisibility visibility;
  final bool showEmptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[];

    if (summary.streak case final streak?) {
      final overallVisible = visibility.overallStreak && streak.overall != null;
      if (visibility.overallStreak || visibility.perTrackStreaks) {
        children.add(_SectionTitle(l10n.communityStreak));
        if (overallVisible) {
          final overall = streak.overall!;
          children.add(
            ListTile(
              title: Text(l10n.communityOverall),
              subtitle: Text(
                l10n.communityStreakValues(
                  overall.currentDays,
                  overall.bestDays,
                ),
              ),
              leading: const Icon(Icons.local_fire_department_outlined),
            ),
          );
        }
        if (visibility.perTrackStreaks) {
          for (final trackStreak in streak.byCurriculum) {
            children.add(
              ListTile(
                title: Text(_curriculumLabel(ref, trackStreak.curriculumId)),
                subtitle: Text(
                  l10n.communityStreakValues(
                    trackStreak.currentDays,
                    trackStreak.bestDays,
                  ),
                ),
                leading: const Icon(Icons.local_fire_department_outlined),
              ),
            );
          }
        }
      }
    }

    final tracks = summary.currentTracks;
    if (visibility.currentTracks && tracks != null) {
      children.add(_SectionTitle(l10n.communityCurrentTracks));
      for (final track in tracks) {
        children.add(
          ListTile(
            title: Text(_curriculumLabel(ref, track.curriculumId)),
            subtitle: track.positionRef == null
                ? null
                : _SummaryRefLabel(track.positionRef!),
            leading: const Icon(Icons.menu_book_outlined),
          ),
        );
      }
    }

    if (summary.weeklyLearning case final weekly?) {
      final overallVisible = visibility.overallWeekly && weekly.overall != null;
      if (visibility.overallWeekly || visibility.perTrackWeekly) {
        children.add(_SectionTitle(l10n.communityThisWeek));
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, bottom: 4),
            child: Text(
              l10n.communityWeekOf(
                MaterialLocalizations.of(context).formatMediumDate(
                  DateTime.parse('${weekly.weekStart}T00:00:00Z'),
                ),
              ),
            ),
          ),
        );
        if (overallVisible) {
          final overall = weekly.overall!;
          children.add(
            ListTile(
              title: Text(l10n.communityOverall),
              subtitle: Text(
                l10n.communityWeeklyCounts(overall.limudim, overall.chazaros),
              ),
              leading: const Icon(Icons.calendar_view_week_outlined),
            ),
          );
        }
        if (visibility.perTrackWeekly) {
          for (final activity in weekly.byCurriculum) {
            children.add(
              ListTile(
                title: Text(_curriculumLabel(ref, activity.curriculumId)),
                subtitle: Text(
                  l10n.communityWeeklyCounts(
                    activity.limudim,
                    activity.chazaros,
                  ),
                ),
                leading: const Icon(Icons.calendar_view_week_outlined),
              ),
            );
          }
        }
      }
    }

    final siyumim = summary.siyumim;
    if (visibility.siyumim && siyumim != null) {
      children.add(_SectionTitle(l10n.communitySiyumim));
      if (siyumim.isEmpty) {
        children.add(ListTile(title: Text(l10n.communityNoSiyumim)));
      } else {
        for (final siyum in siyumim) {
          children.add(
            ListTile(
              title: _SummaryRefLabel(siyum.ref),
              leading: const Icon(Icons.emoji_events_outlined),
            ),
          );
        }
      }
    }

    if (children.isEmpty && showEmptyMessage) {
      return Text(l10n.communityVisibilityPreviewEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
