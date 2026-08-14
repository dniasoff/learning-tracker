/// Widget tests for [ActiveTrackCard] layout + prominence (UI-1, UI-2).
///
///   - UI-1: the card never overflows even in a short fixed-height viewport,
///     for both a caught-up track and a behind track (overdue present).
///   - UI-2: today's unit is rendered as the prominent primary pill (white
///     text on the brand accent), distinct from the muted "NEXT TASK" pill;
///     when caught up only the single Today pill shows.
@Tags(['dashboard'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_focus_pill.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

class _ProfileIdOverride extends ActiveProfileId {
  @override
  String build() => _profileId;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride(this.useHebrew);
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.bavli,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

DailyTask _programTask({
  required DailyTaskPriority priority,
  required bool isOverdue,
  required String ref,
  required String he,
  required String en,
}) => DailyTask(
  curriculumId: CurriculumId.bavli,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: priority,
  isOverdue: isOverdue,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'personal',
  estimatedEffortMinutes: 5,
  unitDisplayHe: he,
  unitDisplayEn: en,
);

Widget _harness(List<DailyTask> tasks) {
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      useHebrewTermsProvider.overrideWith(() => _UseHebrewTermsOverride(false)),
      dashboardHasProgramEnrollmentProvider(
        CurriculumId.bavli,
      ).overrideWith((ref) async => true),
      trackHasChazaraProvider(
        CurriculumId.bavli,
      ).overrideWith((ref) async => false),
      trackDualProgressMetricsProvider.overrideWith(
        (ref) async => const <TrackDualProgressMetric>[],
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          // Deliberately short viewport to stress the layout (UI-1).
          child: SizedBox(
            width: 360,
            height: 300,
            child: ActiveTrackCard(track: _track(), allTasks: tasks),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('UI-1: caught-up track renders without overflow', (tester) async {
    await tester.pumpWidget(
      _harness([
        _programTask(
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          ref: 'Chullin 25a',
          he: 'חולין דף כ״ה',
          en: 'Chullin 25',
        ),
      ]),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI-1: behind track (overdue present) renders without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        _programTask(
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          ref: 'Chullin 23a',
          he: 'חולין דף כ״ג',
          en: 'Chullin 23',
        ),
        _programTask(
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          ref: 'Chullin 25a',
          he: 'חולין דף כ״ה',
          en: 'Chullin 25',
        ),
      ]),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI-2: behind track shows prominent Today + secondary Next', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        _programTask(
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          ref: 'Chullin 23a',
          he: 'חולין דף כ״ג',
          en: 'Chullin 23',
        ),
        _programTask(
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          ref: 'Chullin 25a',
          he: 'חולין דף כ״ה',
          en: 'Chullin 25',
        ),
      ]),
    );
    await tester.pump();

    final pills = tester
        .widgetList<ActiveTrackFocusPill>(find.byType(ActiveTrackFocusPill))
        .toList();
    // Behind: both pills present; exactly one prominent (Today).
    expect(pills.length, 2);
    expect(pills.where((p) => p.prominent).length, 1);
    final today = pills.firstWhere((p) => p.prominent);
    expect(today.value, 'Chullin 25');
    final next = pills.firstWhere((p) => !p.prominent);
    expect(next.value, 'Chullin 23');
  });

  testWidgets('UI-2: caught up shows a single prominent Today pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness([
        _programTask(
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          ref: 'Chullin 25a',
          he: 'חולין דף כ״ה',
          en: 'Chullin 25',
        ),
      ]),
    );
    await tester.pump();

    final pills = tester
        .widgetList<ActiveTrackFocusPill>(find.byType(ActiveTrackFocusPill))
        .toList();
    // Caught up: the focus pill duplicates today, so only Today shows.
    expect(pills.length, 1);
    expect(pills.single.prominent, isTrue);
    expect(pills.single.value, 'Chullin 25');
  });
}
