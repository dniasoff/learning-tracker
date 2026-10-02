// Story 5.3 (DNI-518) AC-11: the Dashboard and the lifetime report show
// one status, projected finish and daily target for one `LearnerState`.
//
// The fixture is a real `LearnerStateEngine` run. The report screen reads
// it through the shared learner-state provider; the Dashboard surface is
// the on-track block over the same curriculum state, selected the way the
// report selects it (`OnTrackView.of`). Story 2.11 (DNI-502) builds the
// Dashboard's own on-track card on that same state; when it lands, its
// card joins this test (follow-up bead filed under learning-tracker-fyh).
@Tags(['progress', 'lifetime', 'story_5_3'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/pace_report_view.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_report_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/on_track_report_block.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/pump_app.dart';

/// Three weeks of dated learning since 2026-09-01, evaluated on Thursday
/// 2026-10-08, with a deadline on [targetDate].
LearnerState _fixture(String targetDate) => const LearnerStateEngine().run(
  engineInputs(
    nowUtc: DateTime.utc(2026, 10, 8, 12),
    intents: {
      engineCurriculum: MainTrackIntent(
        curriculumId: engineCurriculum,
        track: MainTrack(
          curriculumId: engineCurriculum,
          state: MainTrackState.active,
        ),
        program: MainTrackProgram(
          curriculumId: engineCurriculum,
          trackingStartDate: '2026-09-01',
        ),
      ),
    },
    goals: {
      engineCurriculum: CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: engineCurriculum,
          targetDate: targetDate,
        ),
      ),
    },
    events: [
      engineLearn(1, 'Mishnah Berakhot 1:1', learnedOn: '2026-09-15'),
      engineLearn(2, 'Mishnah Berakhot 1:2', learnedOn: '2026-09-22'),
      engineLearn(3, 'Mishnah Berakhot 1:3', learnedOn: '2026-09-29'),
      engineLearn(4, 'Mishnah Berakhot 2:1', learnedOn: '2026-10-06'),
    ],
  ),
);

/// The status, projected finish and daily target painted under [scope].
({String status, String? finish, String? target}) _shown(
  WidgetTester tester,
  Finder scope,
) {
  String? text(String key) {
    final f = find.descendant(of: scope, matching: find.byKey(ValueKey(key)));
    if (f.evaluate().isEmpty) return null;
    return tester.widget<Text>(f).data;
  }

  final status = find.descendant(
    of: find.descendant(
      of: scope,
      matching: find.byKey(const ValueKey('reportOnTrackStatus')),
    ),
    matching: find.byType(Text),
  );
  return (
    status: tester.widget<Text>(status).data!,
    finish: text('reportOnTrackFinish'),
    target: text('reportOnTrackDailyTarget'),
  );
}

void main() {
  for (final (label, target, expected) in [
    ('on track', '2027-09-01', ProjectionStatus.onTrack),
    ('behind pace', '2026-10-20', ProjectionStatus.behindPace),
  ]) {
    testWidgets('$label: dashboard and report show the state\'s status, '
        'projected finish and daily target', (tester) async {
      final state = _fixture(target);
      final curriculum = state[engineCurriculum]!;
      final projection = curriculum.projection!;
      expect(projection.status, expected);
      expect(curriculum.dailyTarget, isNotNull);

      await tester.binding.setSurfaceSize(const Size(400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The report, through the shared learner-state provider.
      await tester.pumpWidget(
        pumpApp(
          child: const LifetimeReportScreen(curriculumId: engineCurriculum),
          overrides: [
            parentSessionProvider.overrideWith((ref) async => true),
            effectiveUseHebrewTermsProvider.overrideWithValue(false),
            activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
            learnerStateProvider.overrideWith((ref, _) => Stream.value(state)),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final report = _shown(tester, find.byType(LifetimeReportScreen));

      // The Dashboard surface over the same state, in a fresh scope.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: OnTrackReportBlock(
              view: OnTrackView.of(curriculum, curriculum.report)!,
              curriculum: CurriculumId.mishnayos,
            ),
          ),
          overrides: [effectiveUseHebrewTermsProvider.overrideWithValue(false)],
        ),
      );
      await tester.pumpAndSettle();
      final dashboard = _shown(tester, find.byType(Scaffold));

      expect(report, dashboard);
      // And both are the state's own values.
      expect(
        report.status,
        expected == ProjectionStatus.onTrack ? 'On track' : 'Behind pace',
      );
      final finish = projection.projectedFinish;
      expect(
        report.finish,
        finish == null
            ? 'Projected finish: not enough recent learning to project'
            : 'Projected finish: '
                  '${DateFormat.yMMMd('en').format(parseCivilDay(finish))}',
      );
      final n = curriculum.dailyTarget!;
      expect(
        report.target,
        'Daily target: $n ${n == 1 ? 'Mishna' : 'Mishnayos'}/day',
      );
    });
  }
}
