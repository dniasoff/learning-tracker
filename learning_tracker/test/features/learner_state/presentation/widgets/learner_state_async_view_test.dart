// Mirror test for
// `lib/features/learner_state/presentation/widgets/learner_state_async_view.dart`
// (DNI-474 AC-1: loading, source failure and retry).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/widgets/learner_state_async_view.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/pump_app.dart';

/// A [LocalCalendarEngine] serving [program] one Berakhot mishnah a day.
final class _FakeCalendarEngine implements LocalCalendarEngine {
  _FakeCalendarEngine(this.ranges);

  final List<String> ranges;

  @override
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    ranges.add(programId);
    return [
      CalendarProgramEntry(
        programId: programId,
        displayNameEn: 'Mishna Yomit',
        displayNameHe: 'משנה יומית',
        todayRef: 'Mishnah Berakhot 1:1',
        apiSource: 'fake',
        date: startDate,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ContentItem _leaf(String ref, int order) => ContentItem(
  curriculumId: engineCurriculum,
  level1: 'Zeraim',
  level2: 'Berakhot',
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: true,
);

Widget _content(BuildContext context, LearnerState? state) =>
    Text('curricula: ${state?.curricula.length}');

void main() {
  testWidgets('loading uses the shared LoadingIndicator', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, scope) => const Stream.empty(),
          ),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingIndicator), findsOneWidget);
  });

  testWidgets('a source failure renders AppErrorView; retry re-reads the '
      'failed dependency and recovers', (tester) async {
    var reads = 0;
    final now = DateTime.utc(2026, 9, 1);
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learningEventRepositoryProvider.overrideWith((ref) async {
            reads++;
            if (reads == 1) throw StateError('events unreadable');
            return null;
          }),
          learnerStateProvider.overrideWith((ref, scope) async* {
            await ref.watch(learningEventRepositoryProvider.future);
            yield LearnerState.empty(now);
          }),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(reads, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(reads, 2, reason: 'retry re-read the failed repository');
    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text('curricula: 0'), findsOneWidget);
  });

  testWidgets('a calendar input failure in the production loader is '
      'recovered by retry; a built corpus set is kept', (tester) async {
    final events = InMemoryLearningEventRepository()..seed(c0Scope(), []);
    final subTracks = InMemorySubTrackRepository()..seed(c0Scope(), []);
    final changeLog = InMemoryChangeLogRepository()..seed(c0Scope(), []);
    final intent = InMemoryGovernedIntentRepository()
      ..emit(
        c0Scope(),
        LearnerIntent(
          settings: c0Settings,
          mainTracks: {
            engineCurriculum: MainTrackIntent(
              curriculumId: engineCurriculum,
              track: MainTrack(
                curriculumId: engineCurriculum,
                state: MainTrackState.active,
              ),
              program: MainTrackProgram(
                curriculumId: engineCurriculum,
                programId: 'mishna_yomit',
              ),
            ),
          },
          goals: const {},
        ),
      );
    addTearDown(() async {
      await events.dispose();
      await subTracks.dispose();
      await changeLog.dispose();
      await intent.dispose();
    });
    var calendarReads = 0;
    var corporaBuilds = 0;
    final ranges = <String>[];
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learningEventRepositoryProvider.overrideWith((ref) async => events),
          subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
          changeLogRepositoryProvider.overrideWith((ref) async => changeLog),
          governedIntentRepositoryProvider.overrideWith((ref) async => intent),
          corporaProvider.overrideWith((ref) async {
            corporaBuilds++;
            return <String, Corpus>{engineCurriculum: mishnayosCorpus()};
          }),
          // The content database under the calendar service: unreadable on
          // the first read only. learnerCalendarLoaderProvider is NOT
          // overridden, so the production loader reads the real
          // calendarProgramServiceProvider over it.
          localCalendarEngineProvider.overrideWith((ref) async {
            calendarReads++;
            if (calendarReads == 1) throw StateError('content db');
            return _FakeCalendarEngine(ranges);
          }),
          curriculumContentProvider.overrideWith(
            (ref, curriculum) async => [
              _leaf('Mishnah Berakhot 1:1', 1),
              _leaf('Mishnah Berakhot 1:2', 2),
            ],
          ),
          localDayClockProvider.overrideWithValue(
            FakeLocalDayClock(engineAt(10000)),
          ),
          learnerStateDayTickProvider.overrideWithValue(const Stream.empty()),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(calendarReads, 1);
    expect(ranges, isEmpty);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(calendarReads, 2, reason: 'retry re-read the failed calendar');
    expect(ranges, ['mishna_yomit']);
    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text('curricula: 1'), findsOneWidget);
    expect(corporaBuilds, 1, reason: 'a built corpus set is not rebuilt');
  });

  testWidgets('inline sections use InlineAsyncError', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, scope) => Stream.error(StateError('engine failed')),
          ),
        ],
        child: const Scaffold(
          body: LearnerStateAsyncView(inline: true, builder: _content),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InlineAsyncError), findsOneWidget);
  });

  testWidgets('no active learner builds with null', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
        child: const Scaffold(body: LearnerStateAsyncView(builder: _content)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('curricula: null'), findsOneWidget);
  });
}
