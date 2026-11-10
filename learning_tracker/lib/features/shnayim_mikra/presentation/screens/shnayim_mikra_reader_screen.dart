import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_reading_plan.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/segment_with_glosses.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_reader_data_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The three-pass reader for one weekly Shnayim Mikra assignment.
final class ShnayimMikraReaderScreen extends ConsumerStatefulWidget {
  const ShnayimMikraReaderScreen({super.key, required this.assignment});

  final ShnayimMikraWeeklyAssignment assignment;

  @override
  ConsumerState<ShnayimMikraReaderScreen> createState() =>
      _ShnayimMikraReaderScreenState();
}

class _ShnayimMikraReaderScreenState
    extends ConsumerState<ShnayimMikraReaderScreen> {
  int _taskIndex = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final scopeAsync = ref.watch(activeLearnerScopeProvider);
    final scope = scopeAsync.asData?.value;
    if (scope == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final historyAsync = ref.watch(learnerLockSettingsProvider(scope));
    final settings = historyAsync.asData?.value.current;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final learnerState = ref.watch(learnerStateProvider(scope)).asData?.value;
    if (learnerState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final completed =
        learnerState
            .curricula[CurriculumId.shnayimMikra.storageKey]
            ?.learntLeaves ??
        const <String>{};
    final eventsAsync = ref.watch(shnayimMikraReaderEventsProvider(scope));
    final source = settings.shnayimMikraSource;
    final learnerWallTime = LearnerZone.of(
      settings.timeZone,
    ).wallTimeOf(ref.watch(localDayClockProvider).nowUtc());
    final dataAsync = ref.watch(
      shnayimMikraReaderDataProvider((
        widget.assignment.portionKey,
        widget.assignment.inIsrael,
        source.storageKey,
      )),
    );
    final l10n = AppLocalizations.of(context)!;
    final portionName = _portionName(widget.assignment.portionKey);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shnayimMikraReaderTitle)),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.shnayimMikraReaderLoadFailed),
          ),
        ),
        data: (aliyot) {
          final tasks = _tasks(
            aliyot,
            settings.shnayimMikraMode,
            settings.shnayimMikraPace,
            learnerWallTime.weekday,
            completed,
          );
          if (tasks.isEmpty) {
            final allVerses = aliyot.expand((aliyah) => aliyah.verses);
            final allDone = allVerses.every(
              (verse) => completed.contains(verse.text.sefariaRef),
            );
            final remainingAliyot = remainingShnayimMikraAliyot(
              [for (final aliyah in aliyot) aliyah.verses],
              completed,
              (verse) => verse.text.sefariaRef,
            );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.shnayimMikraPace == ShnayimMikraPace.dailyAliyah &&
                            learnerWallTime.weekday == DateTime.saturday
                        ? l10n.shnayimMikraNoDailyAliyahToday
                        : settings.shnayimMikraPace ==
                                  ShnayimMikraPace.dailyAliyah &&
                              !allDone
                        ? l10n.shnayimMikraTodayAliyahDone(remainingAliyot)
                        : allDone
                        ? l10n.shnayimMikraReaderWeekComplete(portionName)
                        : l10n.shnayimMikraReaderNoUnits,
                  ),
                  if (allDone) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
          final taskIndex = _taskIndex.clamp(0, tasks.length);
          if (taskIndex >= tasks.length) {
            final isDaily =
                settings.shnayimMikraPace == ShnayimMikraPace.dailyAliyah;
            final allDone = aliyot
                .expand((aliyah) => aliyah.verses)
                .every((verse) => completed.contains(verse.text.sefariaRef));
            final remainingAliyot = remainingShnayimMikraAliyot(
              [for (final aliyah in aliyot) aliyah.verses],
              completed,
              (verse) => verse.text.sefariaRef,
            );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    isDaily && !allDone
                        ? l10n.shnayimMikraTodayAliyahDone(remainingAliyot)
                        : l10n.shnayimMikraReaderWeekComplete(portionName),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                  ),
                ],
              ),
            );
          }
          final task = tasks[taskIndex];
          final persistedPass = eventsAsync.asData?.value == null
              ? 0
              : completedShnayimMikraPassCount(
                  refs: [for (final verse in task.items) verse.text.sefariaRef],
                  events: eventsAsync.asData!.value,
                );
          final passIndex = eventsAsync.hasValue ? persistedPass : 0;
          final passLabel = switch (passIndex) {
            0 => l10n.shnayimMikraFirstReading,
            1 => l10n.shnayimMikraSecondReading,
            _ =>
              source == ShnayimMikraSource.onkelos
                  ? l10n.shnayimMikraOnkelosReading
                  : l10n.shnayimMikraRashiReading,
          };
          final textTheme = Theme.of(context).textTheme;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$portionName · ${task.label}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.shnayimMikraUnitProgress(_taskIndex + 1, tasks.length)} · $passLabel',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (_taskIndex + (passIndex / 3)) / tasks.length,
                      color: context.colors.curriculumFor(
                        CurriculumId.shnayimMikra,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                  itemCount: task.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final verse = task.items[index];
                    final glosses = passIndex < 2
                        ? const <SegmentGloss>[]
                        : verse.parallel.isEmpty
                        ? [
                            SegmentGloss(
                              text: l10n.shnayimMikraNoRashi,
                              direction: TextDirection.rtl,
                              style: textTheme.bodyMedium!,
                            ),
                          ]
                        : [
                            for (final text in verse.parallel)
                              SegmentGloss(
                                text: text.hebrewText,
                                direction: TextDirection.rtl,
                                style: textTheme.bodyMedium!,
                              ),
                          ];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: SegmentWithGlosses(
                          segment: verse.text,
                          glosses: glosses,
                          showNumber: true,
                          showNikud: true,
                          hebrewStyle: textTheme.bodyLarge!.copyWith(
                            color: context.colors.brandInk,
                            height: 1.7,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _completePass(task, passIndex, l10n),
                      child: _saving
                          ? const CircularProgressIndicator()
                          : Text(l10n.shnayimMikraMarkReadingComplete),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ShnayimMikraReadingUnit<ShnayimMikraVerseReading>> _tasks(
    List<ShnayimMikraAliyahReading> aliyot,
    ShnayimMikraMode mode,
    ShnayimMikraPace pace,
    int weekday,
    Set<String> completed,
  ) {
    final units = buildShnayimMikraReadingUnits(
      mode: mode,
      pace: pace,
      weekday: weekday,
      aliyahLabels: [
        for (final aliyah in aliyot)
          '${AppLocalizations.of(context)!.shnayimMikraAliyah} ${aliyah.aliyahNumber}',
      ],
      verseLabels: [
        for (final aliyah in aliyot)
          for (final verse in aliyah.verses) verse.text.sefariaRef,
      ],
      aliyot: [for (final aliyah in aliyot) aliyah.verses],
    );
    return [
      for (final unit in units)
        if (unit.items.any(
          (verse) => !completed.contains(verse.text.sefariaRef),
        ))
          ShnayimMikraReadingUnit(
            label: unit.label == 'parsha'
                ? _portionName(widget.assignment.portionKey)
                : unit.label,
            items: [
              for (final verse in unit.items)
                if (!completed.contains(verse.text.sefariaRef)) verse,
            ],
          ),
    ];
  }

  Future<void> _completePass(
    ShnayimMikraReadingUnit<ShnayimMikraVerseReading> task,
    int passIndex,
    AppLocalizations l10n,
  ) async {
    setState(() => _saving = true);
    try {
      final commands = await ref.read(learningCommandsProvider.future);
      if (commands == null) throw StateError('Learning commands unavailable');
      if (passIndex < 3) {
        final source = LearningEvent.shnayimMikraPassSources[passIndex];
        final markerResult = await commands.capture(
          curriculumId: CurriculumId.shnayimMikra.storageKey,
          refs: [for (final verse in task.items) verse.text.sefariaRef],
          source: source,
          dateState: DateState.dated,
          skipRecorded: true,
        );
        if (markerResult is! CaptureSuccess) {
          throw StateError(l10n.shnayimMikraReaderSaveFailed);
        }
        if (passIndex < 2) {
          if (!mounted) return;
          setState(() => _saving = false);
          return;
        }
      }
      final result = await commands.capture(
        curriculumId: CurriculumId.shnayimMikra.storageKey,
        refs: [for (final verse in task.items) verse.text.sefariaRef],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
        skipRecorded: true,
      );
      if (result is! CaptureSuccess) {
        throw StateError(l10n.shnayimMikraReaderSaveFailed);
      }
      if (!mounted) return;
      setState(() {
        _taskIndex = 0;
        _saving = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shnayimMikraReaderSaveFailed)),
      );
    }
  }

  String _portionName(String key) => key
      .split('_')
      .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
      .join('–');
}

final shnayimMikraReaderEventsProvider = StreamProvider.autoDispose
    .family<List<LearningEvent>, LearnerScope>((ref, scope) async* {
      final repository = await ref.watch(
        learningEventRepositoryProvider.future,
      );
      if (repository == null) return;
      await for (final read in repository.watchAll(scope)) {
        if (read is CompleteReadReady<LearningEvent>) {
          if (!read.isClean)
            throw StateError('Learning event log is unreadable');
          yield read.items;
        }
      }
    }, retry: (retryCount, error) => null);
