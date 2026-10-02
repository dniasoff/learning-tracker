// DNI-496 (Story 2.5) — the DNI-495 seam Sub-tracks group on Manage
// tracks: parent-only and non-calendar (AD-45), rows with "Starts {date}"
// for a future start (AC-4, UX-DR-89), Add sub-track → Ongoing → form
// (AC-1), edit from a row (AC-6) and the rejected-sync rollback snackbar
// with retry (AC-5 concurrent offline creates, AC-7, UX-DR-121).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ongoing_sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ongoing_sub_track_hub_seam.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
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

/// The learner the parent session grants; tests switch it.
LearnerScope? _initialGrant;

class _Grant extends Notifier<LearnerScope?> {
  @override
  LearnerScope? build() => _initialGrant;

  void set(LearnerScope? scope) => state = scope;
}

final _grant = NotifierProvider<_Grant, LearnerScope?>(_Grant.new);

/// The active commands instance; tests replace it.
class _Commands extends Notifier<FakeLearningCommands> {
  @override
  FakeLearningCommands build() => _commands;

  void set(FakeLearningCommands commands) => state = commands;
}

final _activeCommands = NotifierProvider<_Commands, FakeLearningCommands>(
  _Commands.new,
);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(OngoingSubTrackHubSeam)),
);

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
    ongoingSubTrackWriteScopeProvider.overrideWith(
      (ref) async => parent ? ref.watch(_grant) : null,
    ),
    ongoingSubTrackContextProvider(_curriculum).overrideWith(
      (ref) async => OngoingSubTrackContext(
        scope: c0Scope(),
        curriculumId: _curriculum,
        today: _today,
        timeZone: 'UTC',
        subTracks: tracks,
        calendarProgram: calendarProgram,
      ),
    ),
    learningCommandsProvider.overrideWith(
      (ref) async => ref.watch(_activeCommands),
    ),
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
  setUp(() {
    _commands = FakeLearningCommands();
    _initialGrant = c0Scope();
  });

  /// Saves a new ongoing sub-track that is queued offline as [changeId],
  /// then clears the "saved offline" notice.
  Future<void> queueCreate(WidgetTester tester, String changeId) async {
    _commands.nextResult = CaptureResult.success(
      changeIds: [changeId],
      queued: true,
    );
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
    ScaffoldMessenger.of(
      tester.element(find.byType(OngoingSubTrackHubSeam)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
  }

  PendingFailure rejected(String id, String changeId) => PendingFailure(
    id: id,
    eventIds: const [],
    changeIds: [changeId],
    reason: PendingFailureReason.failedPrecondition,
  );

  group('the pending-failure watch is bound to its learner', () {
    const changeId = '01JQUEUED00000000000000009';

    testWidgets('a profile switch drops the old learner\'s rejection', (
      tester,
    ) async {
      await _pump(tester);
      await queueCreate(tester, changeId);
      expect(_commands.pendingFailures.hasListener, isTrue);
      _container(tester).read(_grant.notifier).set(c0Scope(ownerUid: 'other'));
      await tester.pumpAndSettle();
      expect(_commands.pendingFailures.hasListener, isFalse);
      _commands.pendingFailures.add([rejected('pf-9', changeId)]);
      await tester.pumpAndSettle();
      expect(find.text("Your change couldn't be saved."), findsNothing);
    });

    testWidgets('a lost parent session drops the watch', (tester) async {
      await _pump(tester);
      await queueCreate(tester, changeId);
      _container(tester).read(_grant.notifier).set(null);
      await tester.pumpAndSettle();
      expect(_commands.pendingFailures.hasListener, isFalse);
    });

    testWidgets('an open rejection notice closes at a switch, no retry', (
      tester,
    ) async {
      await _pump(tester);
      await queueCreate(tester, changeId);
      _commands.pendingFailures.add([rejected('pf-9', changeId)]);
      await tester.pumpAndSettle();
      expect(find.text("Your change couldn't be saved."), findsOneWidget);
      _container(tester).read(_grant.notifier).set(c0Scope(ownerUid: 'other'));
      await tester.pumpAndSettle();
      expect(find.text("Your change couldn't be saved."), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(_commands.calls.where((c) => c.name == 'retry'), isEmpty);
    });

    testWidgets('a new commands instance drops the old one\'s feed', (
      tester,
    ) async {
      await _pump(tester);
      await queueCreate(tester, changeId);
      final old = _commands;
      _container(
        tester,
      ).read(_activeCommands.notifier).set(FakeLearningCommands());
      await tester.pumpAndSettle();
      expect(old.pendingFailures.hasListener, isFalse);
      old.pendingFailures.add([rejected('pf-9', changeId)]);
      await tester.pumpAndSettle();
      expect(find.text("Your change couldn't be saved."), findsNothing);
    });

    testWidgets('a re-read of the same learner keeps the watch', (
      tester,
    ) async {
      await _pump(tester);
      await queueCreate(tester, changeId);
      _container(tester).read(_grant.notifier).set(c0Scope());
      await tester.pumpAndSettle();
      _commands.pendingFailures.add([rejected('pf-9', changeId)]);
      await tester.pumpAndSettle();
      expect(find.text("Your change couldn't be saved."), findsOneWidget);
    });
  });

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

  group('a refused Retry keeps the recovery path (AC-7)', () {
    const changeId = '01JQUEUED00000000000000011';
    final notice = find.text("Your change couldn't be saved.");
    int retries() => _commands.calls.where((c) => c.name == 'retry').length;

    Future<void> announceRejection(WidgetTester tester) async {
      await _pump(tester);
      await queueCreate(tester, changeId);
      _commands.pendingFailures.add([rejected('pf-11', changeId)]);
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
    }

    void hideNotice(WidgetTester tester) => ScaffoldMessenger.of(
      tester.element(find.byType(OngoingSubTrackHubSeam)),
    ).hideCurrentSnackBar();

    testWidgets('a retry refused again at once shows the notice again; the '
        'next Retry saves it', (tester) async {
      await announceRejection(tester);
      // The server refuses the retry again, and the commands do not (yet)
      // re-publish the failure.
      _commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.notSaved,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retries(), 2);
      expect(notice, findsNothing, reason: 'saved');
    });

    testWidgets('a refusal both answered and re-published is announced '
        'once', (tester) async {
      await announceRejection(tester);
      _commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.notSaved,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      _commands.pendingFailures.add([rejected('pf-11', changeId)]);
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      hideNotice(tester);
      await tester.pumpAndSettle();
      expect(notice, findsNothing, reason: 'no second notice queued');
    });

    testWidgets('a retry that throws still offers Retry', (tester) async {
      await announceRejection(tester);
      _commands.retryError = Exception('transport');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a queued retry the server refuses later is announced', (
      tester,
    ) async {
      await announceRejection(tester);
      _commands.nextResult = const CaptureResult.success(
        changeIds: [changeId],
        queued: true,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      _commands.pendingFailures.add([rejected('pf-11', changeId)]);
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
    });
  });

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
