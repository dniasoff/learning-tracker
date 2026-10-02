/// *Up to…* on the main-track today list (Story 2.10, DNI-501; FR-2a,
/// AC-5).
///
/// Offered in addition to ticking each task: one action per curriculum
/// with new-learning tasks today. Its picker lists the main track's
/// `schedulableRefs` from the main-track position (engine, AD-33), led by
/// today's new-learning tasks, and records `source = main`, `dated`,
/// `stage` = the first stage order of those tasks, each event with its
/// `pts_{eventId}` entry in the same chunk (AD-50; `LearningCommands`).
///
/// [ASSUMPTION] Review / chazara tasks keep individual ticks only (story
/// AC-5). Task generation is untouched: this widget only reads
/// [allDailyTasksProvider]. It is offered only while the session has
/// learning commands ([mainTrackCaptureAllowedProvider]). A tutored session
/// has none until Story 1.24 (DNI-486) binds the talmid's tutor commands
/// (callables, AD-53), so a tutor sees no main-track Up to… today.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Whether [task] is a new-learning task (AC-5 picker lead).
bool isNewLearningTask(DailyTask task) =>
    task.priority == DailyTaskPriority.newLearning ||
    task.priority == DailyTaskPriority.overdueNewLearning;

/// One main-track Up to… request per curriculum with new-learning tasks in
/// [tasks], in task order.
List<MainTrackUpToRequest> mainTrackUpToRequests(List<DailyTask> tasks) {
  final byCurriculum = <CurriculumId, List<DailyTask>>{};
  for (final t in tasks) {
    if (isNewLearningTask(t)) (byCurriculum[t.curriculumId] ??= []).add(t);
  }
  return [
    for (final MapEntry(:key, :value) in byCurriculum.entries)
      MainTrackUpToRequest(
        curriculumId: key.storageKey,
        name: value.first.trackLabel,
        leadRefs: [for (final t in value) t.contentItemSefariaRef],
        stage: value.first.stageOrder,
      ),
  ];
}

/// The main-track Up to… actions under today's tasks.
class MainTrackUpToActions extends ConsumerWidget {
  /// Creates the actions.
  const MainTrackUpToActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mainTrackCaptureAllowedProvider)) {
      return const SizedBox.shrink();
    }
    final tasks = ref.watch(allDailyTasksProvider).asData?.value;
    if (tasks == null) return const SizedBox.shrink();
    final requests = mainTrackUpToRequests(tasks);
    if (requests.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Align(
      key: const Key('mainTrackUpTo'),
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          for (final request in requests)
            UpToActionButton(
              key: Key('mainTrackUpTo-${request.curriculumId}'),
              semanticsLabel: l10n.upToPickerActionSemantics(request.name),
              label: requests.length > 1
                  ? l10n.upToPickerTitle(request.name)
                  : null,
              onOpen: () => openUpToAndRecord(context, ref, request: request),
            ),
        ],
      ),
    );
  }
}
