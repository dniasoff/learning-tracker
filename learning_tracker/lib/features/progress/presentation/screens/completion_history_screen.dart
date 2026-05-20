import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_visuals.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/natural_sort.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class CompletionHistoryScreen extends ConsumerStatefulWidget {
  const CompletionHistoryScreen({
    super.key,
    @PathParam('curriculumId') this.curriculumId,
  });

  final String? curriculumId;

  @override
  ConsumerState<CompletionHistoryScreen> createState() =>
      _CompletionHistoryScreenState();
}

class _CompletionHistoryScreenState
    extends ConsumerState<CompletionHistoryScreen> {
  TrackType? _trackFilter;

  void _onTrackFilterChanged(TrackType? trackType) {
    setState(() {
      _trackFilter = trackType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completionsAsync = widget.curriculumId != null
        ? ref.watch(
            completionHistoryForCurriculumProvider(widget.curriculumId!),
          )
        : ref.watch(allCompletionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Completion History'),
        actions: [_buildTrackFilterMenu()],
      ),
      body: Column(
        children: [
          if (_trackFilter != null) _buildActiveFilterChip(),
          Expanded(child: _buildBody(completionsAsync)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Completion>> completionsAsync) {
    return completionsAsync.when(
      loading: () => const LoadingIndicator(message: 'Loading history...'),
      error: (error, _) => ErrorDisplay(
        message: 'Failed to load completion history: $error',
        onRetry: () {
          if (widget.curriculumId != null) {
            ref.invalidate(
              completionHistoryForCurriculumProvider(widget.curriculumId!),
            );
          } else {
            ref.invalidate(allCompletionHistoryProvider);
          }
        },
      ),
      data: (allCompletions) {
        var completions = allCompletions;
        if (_trackFilter != null) {
          completions = completions
              .where((c) => c.trackType == _trackFilter!.storageKey)
              .toList();
        }
        // Primary: completion date descending. Secondary: canonical curriculum
        // order (seder), then natural sefariaRef order so "1:2" sorts before
        // "1:10".
        completions = [...completions]..sort(_compareCompletions);
        return _buildCompletionsList(completions);
      },
    );
  }

  int _compareCompletions(Completion a, Completion b) {
    final byDate = b.completedAt.compareTo(a.completedAt);
    if (byDate != 0) return byDate;
    final byCurriculum = _curriculumOrder(
      a.curriculumId,
    ).compareTo(_curriculumOrder(b.curriculumId));
    if (byCurriculum != 0) return byCurriculum;
    return compareNaturalString(a.sefariaRef, b.sefariaRef);
  }

  static int _curriculumOrder(String storageKey) {
    for (final c in CurriculumId.values) {
      if (c.storageKey == storageKey) return c.index;
    }
    return CurriculumId.values.length;
  }

  Widget _buildTrackFilterMenu() {
    return PopupMenuButton<TrackType?>(
      icon: Icon(
        _trackFilter != null ? Icons.filter_alt : Icons.filter_alt_outlined,
        color: _trackFilter != null ? AppTheme.trackPersonal : null,
      ),
      tooltip: 'Filter by track',
      onSelected: _onTrackFilterChanged,
      itemBuilder: (context) => [
        PopupMenuItem<TrackType?>(
          value: null,
          child: Row(
            children: [
              const Icon(Icons.clear),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.completionHistoryAllTracks),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...TrackType.values.map((trackType) {
          return PopupMenuItem<TrackType>(
            value: trackType,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.getTrackColor(trackType),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                CurriculumLabel.trackType(trackType),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.getTrackColor(_trackFilter!).withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.completionHistoryFilteredBy,
            style: const TextStyle(fontSize: 14),
          ),
          Chip(
            avatar: CircleAvatar(
              backgroundColor: AppTheme.getTrackColor(_trackFilter!),
            ),
            label: CurriculumLabel.trackType(_trackFilter!),
            onDeleted: () => _onTrackFilterChanged(null),
            deleteIcon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionsList(List<Completion> completions) {
    if (completions.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noCompletionsYet,
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completions.length,
      itemBuilder: (context, index) {
        return _buildCompletionCard(completions[index]);
      },
    );
  }

  Widget _buildCompletionCard(Completion completion) {
    final curriculumId = _parseCurriculumId(completion.curriculumId);
    final accentColor = stageAccentColor(context, completion.stageId);
    final stageLabel = domainTermLabels(
      ref,
    ).stageNameFromStageId(completion.stageId);
    final completedDate = completion.completedAt.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final formattedDate = DateFormat.yMMMd(
      locale,
    ).add_jm().format(completedDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Row(
          children: [
            if (curriculumId != null) ...[
              Icon(
                curriculumIcon(curriculumId),
                size: 18,
                color: AppTheme.getCurriculumColor(curriculumId),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: CurriculumLabel.local(
                completion.sefariaRef,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              stageLabel,
              style: TextStyle(color: accentColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: AppTheme.brandGold, size: 20),
            Text(
              '${completion.points}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static CurriculumId? _parseCurriculumId(String storageKey) {
    for (final c in CurriculumId.values) {
      if (c.storageKey == storageKey) return c;
    }
    return null;
  }
}
