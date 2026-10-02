// DNI-496 (Story 2.5) — the DNI-495 seam Sub-tracks group on Manage
// tracks: parent-only and non-calendar (AD-45), rows with "Starts {date}"
// for a future start (AC-4, UX-DR-89), Add sub-track → Ongoing → form
// (AC-1), edit from a row (AC-6) and the rejected-sync rollback snackbar
// with retry (AC-5 concurrent offline creates, AC-7, UX-DR-121).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ongoing_sub_track_hub_seam.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';

const _curriculum = 'mishnayos';
const _today = '2026-09-07';

String _ulid(int n) => '01J${n.toString().padLeft(23, '0')}';

SubTrack _track(
  int id, {
  String name = 'Rebbe Cohen',
  String start = '2026-09-01',
  SubTrackType type = SubTrackType.ongoing,
  bool ended = false,
}) => SubTrack(
  id: _ulid(id),
  curriculumId: _curriculum,
  name: name,
  type: type,
  academicYear: type == SubTrackType.schoolYear ? 2026 : null,
  windowStart: start,
  windowEnd: type == SubTrackType.schoolYear ? '2027-07-31' : null,
  ratePerWeek: 5,
  weeksPerYear: 52,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: _ulid(id + 500),
  endedAt: ended ? DateTime.utc(2026, 9, 2) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

late FakeLearningCommands _commands;

Future<void> _pump(
  WidgetTester tester, {
  List<SubTrack> tracks = const [],
  bool parent = true,
  bool calendarProgram = false,
}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = <Override>[
    useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
    ongoingSubTrackParentSessionProvider.overrideWith((ref) async => parent),
    ongoingSubTrackContextProvider(_curriculum).overrideWith(
      (ref) async => OngoingSubTrackContext(
        curriculumId: _curriculum,
        today: _today,
        timeZone: 'UTC',
        subTracks: tracks,
        calendarProgram: calendarProgram,
      ),
    ),
    learningCommandsProvider.overrideWith((ref) async => _commands),
  ];
  await tester.pumpWidget(
    pumpApp(
      overrides: overrides,
      child: Scaffold(
        body: ListView(
          children: const [OngoingSubTrackHubSeam(curriculumId: _curriculum)],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  setUp(() => _commands = FakeLearningCommands());

  testWidgets('AC-4: a future-start row reads "Starts {date}"', (tester) async {
    await _pump(
      tester,
      tracks: [
        _track(1, name: 'Summer shiur', start: '2026-12-01'),
        _track(2, name: 'Rebbe Cohen'),
      ],
    );
    expect(find.text('Sub-tracks'), findsOneWidget);
    expect(find.text('Summer shiur'), findsOneWidget);
    expect(find.text('Starts Dec 1, 2026'), findsOneWidget);
    expect(find.text('5/wk × 52 weeks'), findsOneWidget);
  });

  testWidgets('ended sub-tracks are not listed (UX-DR-82)', (tester) async {
    await _pump(tester, tracks: [_track(1, name: 'Old rebbe', ended: true)]);
    expect(find.text('Old rebbe'), findsNothing);
    expect(find.text('Add sub-track'), findsOneWidget);
  });

  testWidgets('hidden without a parent session', (tester) async {
    await _pump(tester, tracks: [_track(1)], parent: false);
    expect(find.text('Sub-tracks'), findsNothing);
    expect(find.text('Add sub-track'), findsNothing);
    expect(find.text('Rebbe Cohen'), findsNothing);
  });

  testWidgets('hidden on a calendar-program curriculum', (tester) async {
    await _pump(tester, calendarProgram: true);
    expect(find.text('Add sub-track'), findsNothing);
  });

  testWidgets('Add sub-track → Ongoing opens the ongoing form', (tester) async {
    await _pump(tester);
    await tester.tap(_key('ongoingSubTrackHubAdd'));
    await tester.pumpAndSettle();
    expect(find.text('Ongoing'), findsOneWidget);
    // The school-year form (DNI-495) is not on the branch: not offered.
    expect(find.text('School year'), findsNothing);
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Ongoing sub-track'), findsOneWidget);
  });

  testWidgets('AC-5: at five in use the chooser disables Ongoing', (
    tester,
  ) async {
    await _pump(
      tester,
      tracks: [
        for (var i = 1; i <= 5; i++) _track(i, name: 'Rebbe $i'),
        _track(9, name: 'Old', ended: true),
      ],
    );
    await tester.tap(_key('ongoingSubTrackHubAdd'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can have up to 5 ongoing sub-tracks. 5 in use.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Ongoing sub-track'), findsNothing);
  });

  testWidgets(
    'AC-6: an ongoing row opens its edit form; school-year does not',
    (tester) async {
      await _pump(
        tester,
        tracks: [
          _track(1, name: 'Rebbe Cohen'),
          _track(2, name: 'School', type: SubTrackType.schoolYear),
        ],
      );
      await tester.tap(find.text('School'));
      await tester.pumpAndSettle();
      expect(find.text('Edit ongoing sub-track'), findsNothing);
      await tester.tap(find.text('Rebbe Cohen'));
      await tester.pumpAndSettle();
      expect(find.text('Edit ongoing sub-track'), findsOneWidget);
    },
  );

  testWidgets(
    'AC-5/AC-7: a queued create the server later refuses is announced with '
    'a retry',
    (tester) async {
      const changeId = '01JQUEUED00000000000000001';
      _commands.nextResult = const CaptureResult.success(
        changeIds: [changeId],
        queued: true,
      );
      await _pump(tester);
      await tester.tap(_key('ongoingSubTrackHubAdd'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ongoing'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('ongoingSubTrackName'), 'Sixth rebbe');
      await tester.dragUntilVisible(
        _key('ongoingSubTrackSave'),
        find.byType(ListView).last,
        const Offset(0, -150),
      );
      await tester.tap(_key('ongoingSubTrackSave'));
      await tester.pumpAndSettle();
      expect(
        find.text("Saved. It will sync when you're back online."),
        findsOneWidget,
      );
      // Another device's create reached the cap first: AD-45 rejects this
      // one at sync, the cache rolls it back and the hub says so.
      _commands.pendingFailures.add(const [
        PendingFailure(
          id: 'pf-1',
          eventIds: [],
          changeIds: [changeId],
          reason: PendingFailureReason.failedPrecondition,
        ),
      ]);
      await tester.pump();
      ScaffoldMessenger.of(
        tester.element(find.byType(OngoingSubTrackHubSeam)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(find.text("Your change couldn't be saved."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(_commands.calls.where((c) => c.name == 'retry').single.args, {
        'pendingFailureId': 'pf-1',
      });
    },
  );

  testWidgets('an unrelated pending failure is not announced', (tester) async {
    _commands.nextResult = const CaptureResult.success(
      changeIds: ['01JQUEUED00000000000000001'],
      queued: true,
    );
    await _pump(tester, tracks: [_track(1)]);
    await tester.tap(find.text('Rebbe Cohen'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('ongoingSubTrackName'), 'Renamed');
    await tester.dragUntilVisible(
      _key('ongoingSubTrackSave'),
      find.byType(ListView).last,
      const Offset(0, -150),
    );
    await tester.tap(_key('ongoingSubTrackSave'));
    await tester.pumpAndSettle();
    _commands.pendingFailures.add(const [
      PendingFailure(
        id: 'pf-2',
        eventIds: ['01JEVENT000000000000000001'],
        changeIds: [],
        reason: PendingFailureReason.permissionDenied,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text("Your change couldn't be saved."), findsNothing);
  });
}
