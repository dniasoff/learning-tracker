// DNI-506 (Story 3.3) T6 / T7: *Yes, all of it* on the Learn-tab catch-up
// card — the action it records (AC-1), the undo snackbar and the card
// returning (AC-7), the ended refusal (AC-3), the not-saved state (AC-8),
// the processing state, and no streak-loss copy for an expired card (AC-4,
// NFR-18). DNI-507 (Story 3.4) T4: the Adjust panel's Record goes through
// the same path as one adjusted action, never empty and never twice.
@Tags(['learning'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/catch_up_card.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/catch_up_adjust_rig.dart';
import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _Owner extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

/// Commands whose `recordCatchUp` settles only when [release] completes.
class _HeldCommands extends Fake implements LearningCommands {
  final release = Completer<CaptureResult>();
  int calls = 0;

  @override
  Future<CaptureResult> recordCatchUp(CatchUpAction action) {
    calls++;
    return release.future;
  }
}

/// Commands that resolve only when [release] completes, like a
/// `learningCommandsProvider` still building after the tap.
final class _SlowCommands {
  final release = Completer<void>();
  final commands = FakeLearningCommands();

  Future<LearningCommands?> resolve() async {
    await release.future;
    return commands;
  }
}

final _card = find.byType(CatchUpCardView);
final _yesAll = find.byKey(const ValueKey('catchUpCardYesAll'));
final _saveFailed = find.byKey(const ValueKey('catchUpCardSaveFailed'));

LearnerState _plain() => fakeLearnerState(
  curricula: {'mishnayos': FakeCurriculumState(curriculumId: 'mishnayos')},
);

/// The learner state once the card's event is counted (A-5).
LearnerState _caughtUp() => fakeLearnerState(
  curricula: {'mishnayos': FakeCurriculumState(curriculumId: 'mishnayos')},
  countedLearns: [
    LearningEvent.learn(
      id: ulidE,
      curriculumId: 'mishnayos',
      ref: 'Mishnah Berakhot 2:1',
      source: LearningEvent.sourceMain,
      dateState: DateState.catchUp,
      learnedOn: catchUpShabbos,
      stage: 1,
      recordedAt: catchUpSunday,
      actor: parentActor,
    ),
  ],
);

final class _Rig {
  final state = LiveSource<LearnerState>(_plain());
  DateTime now = catchUpSunday;
  LearnerScope scope = catchUpScope;

  List<Override> overrides(
    LearningCommands commands, {
    Future<LearningCommands?> Function()? resolve,
  }) => [
    useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
    activeTutoredProfileSelectionProvider.overrideWith(_Owner.new),
    ...catchUpOverrides(
      states: (_) => state.stream(),
      clock: () => now,
      scopeOf: () => scope,
    ),
    learningCommandsProvider.overrideWith(
      (ref) => resolve?.call() ?? Future.value(commands),
    ),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      retry: (_, _) => null,
      overrides: overrides,
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [CatchUpCardsSection(), Text('Below')],
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('AC-1: Yes, all of it records the card as one action', (
    tester,
  ) async {
    final rig = _Rig();
    final commands = FakeLearningCommands();
    await _pump(tester, rig.overrides(commands));
    expect(_card, findsOneWidget);
    await tester.tap(_yesAll);
    await _settle(tester);
    final call = commands.calls.singleWhere((c) => c.name == 'recordCatchUp');
    final action = call.args['action']! as CatchUpAction;
    expect(action.mode, CatchUpMode.all);
    expect(action.lockedDaysOffered, 1);
    expect(action.leaves, const [
      CatchUpLeaf(
        curriculumId: 'mishnayos',
        ref: 'Mishnah Berakhot 2:1',
        source: 'main',
        learnedOn: catchUpShabbos,
        stage: 1,
      ),
    ]);
    await _unmount(tester);
  });

  testWidgets('AC-7: Undo voids the action and the card returns', (
    tester,
  ) async {
    final rig = _Rig();
    final commands = FakeLearningCommands();
    await _pump(tester, rig.overrides(commands));
    await tester.tap(_yesAll);
    await _settle(tester);
    // The events reach the live learner state: the card is complete.
    rig.state.value = _caughtUp();
    await _settle(tester);
    expect(_card, findsNothing);
    expect(find.text('1 recorded'), findsOneWidget);
    final recorded = commands.calls.last;
    expect(recorded.name, 'recordCatchUp');

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    final undo = commands.calls.last;
    expect(undo.name, 'undoEvents');
    expect(undo.args['eventIds'], hasLength(1));

    // The voids reach the learner state: the card is back in its window.
    rig.state.value = _plain();
    await _settle(tester);
    expect(_card, findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('AC-3: a tap after the window says it ended; the card goes', (
    tester,
  ) async {
    final rig = _Rig();
    final commands = FakeLearningCommands()
      ..nextResult = const CaptureResult.rejected(
        CaptureRejection.catchUpEnded,
      );
    await _pump(tester, rig.overrides(commands));
    expect(_card, findsOneWidget);
    // The screen went stale: the window has ended by the time it is tapped.
    rig.now = catchUpZone.at(DateTime.utc(2026, 10, 13), minute: 1);
    await tester.tap(_yesAll);
    await _settle(tester);
    expect(
      find.text(
        'This catch-up has ended — you can still tick learning in Browse.',
      ),
      findsOneWidget,
    );
    expect(_card, findsNothing);
    expect(
      find.textContaining(RegExp('streak', caseSensitive: false)),
      findsNothing,
    );
    await _unmount(tester);
  });

  testWidgets('AC-8: a write that fails keeps the card with a retry note', (
    tester,
  ) async {
    final rig = _Rig();
    final commands = FakeLearningCommands()
      ..nextResult = const CaptureResult.rejected(CaptureRejection.notSaved);
    await _pump(tester, rig.overrides(commands));
    await tester.tap(_yesAll);
    await _settle(tester);
    expect(_card, findsOneWidget);
    expect(_saveFailed, findsOneWidget);
    expect(
      find.text("Couldn't save — try again before the card expires."),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_yesAll).onPressed, isNotNull);

    // Trying again succeeds and clears the note.
    await tester.tap(_yesAll);
    await _settle(tester);
    expect(_saveFailed, findsNothing);
    expect(
      commands.calls.where((c) => c.name == 'recordCatchUp'),
      hasLength(2),
    );
    await _unmount(tester);
  });

  testWidgets('while recording the actions are disabled; one write only', (
    tester,
  ) async {
    final rig = _Rig();
    final commands = _HeldCommands();
    await _pump(tester, rig.overrides(commands));
    await tester.tap(_yesAll);
    await _settle(tester);
    expect(find.byKey(const ValueKey('catchUpCardRecording')), findsOneWidget);
    expect(find.bySemanticsLabel('Recording…'), findsOneWidget);
    expect(tester.widget<FilledButton>(_yesAll).onPressed, isNull);
    await tester.tap(_yesAll, warnIfMissed: false);
    await _settle(tester);
    expect(commands.calls, 1);
    commands.release.complete(const CaptureResult.success());
    await _settle(tester);
    expect(find.byKey(const ValueKey('catchUpCardRecording')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('a learner switch while the commands resolve writes nothing', (
    tester,
  ) async {
    final rig = _Rig();
    final slow = _SlowCommands();
    await _pump(tester, rig.overrides(slow.commands, resolve: slow.resolve));
    expect(_card, findsOneWidget);
    await tester.tap(_yesAll);
    await _settle(tester);
    expect(find.byKey(const ValueKey('catchUpCardRecording')), findsOneWidget);

    // Another profile comes into view before the commands resolve.
    rig.scope = catchUpOtherScope;
    ProviderScope.containerOf(
      tester.element(find.byType(CatchUpCardsSection)),
    ).invalidate(activeLearnerScopeProvider);
    await _settle(tester);
    slow.release.complete();
    await _settle(tester);

    expect(
      slow.commands.calls.where((c) => c.name == 'recordCatchUp'),
      isEmpty,
    );
    expect(find.byKey(const ValueKey('catchUpCardRecording')), findsNothing);
    expect(_saveFailed, findsNothing);
    await _unmount(tester);
  });

  testWidgets('AC-4: an expired card is gone, with no streak-loss copy', (
    tester,
  ) async {
    final rig = _Rig()
      ..now = catchUpZone.at(DateTime.utc(2026, 10, 13), hour: 9);
    await _pump(tester, rig.overrides(FakeLearningCommands()));
    expect(_card, findsNothing);
    expect(
      find.textContaining(RegExp('streak', caseSensitive: false)),
      findsNothing,
    );
    expect(find.text('Below'), findsOneWidget);
    await _unmount(tester);
  });

  group('DNI-507 T4: Record of the Adjust panel', () {
    List<Override> adjustOverrides(
      AdjustRig rig,
      LearningCommands commands,
    ) => [
      ...rig.overrides(realActions: true),
      learningCommandsProvider.overrideWith((ref) => Future.value(commands)),
    ];

    Future<void> untick33AndRecord(WidgetTester tester) async {
      await openAdjust(tester);
      final row = adjustRow(rigRebbe, rigLeaf(3, 3));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settleAdjust(tester);
      await tester.ensureVisible(adjustRecord);
      await tester.tap(adjustRecord);
      await settleAdjust(tester);
    }

    testWidgets('records one adjusted action of the ticked leaves', (
      tester,
    ) async {
      final rig = AdjustRig();
      final commands = FakeLearningCommands();
      await pumpAdjustCard(tester, adjustOverrides(rig, commands));
      await untick33AndRecord(tester);
      final call = commands.calls.singleWhere((c) => c.name == 'recordCatchUp');
      final action = call.args['action']! as CatchUpAction;
      expect(action.mode, CatchUpMode.adjusted);
      expect(action.lockedDaysOffered, 1);
      expect(action.leaves, hasLength(13));
      expect(action.leaves.any((l) => l.ref == rigLeaf(3, 3)), isFalse);
      await unmountAdjust(tester);
    });

    testWidgets('a second tap while recording writes nothing more; a '
        'not-saved result keeps the card and the panel\'s selection', (
      tester,
    ) async {
      final rig = AdjustRig();
      final commands = _HeldCommands();
      await pumpAdjustCard(tester, adjustOverrides(rig, commands));
      await untick33AndRecord(tester);
      expect(commands.calls, 1);
      expect(tester.widget<ButtonStyleButton>(adjustRecord).onPressed, isNull);
      await tester.tap(adjustRecord, warnIfMissed: false);
      await settleAdjust(tester);
      expect(commands.calls, 1);
      commands.release.complete(
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
      await settleAdjust(tester);
      expect(_saveFailed, findsOneWidget);
      expect(adjustPanel, findsOneWidget);
      expect(
        find.descendant(
          of: adjustRecord,
          matching: find.text('Record 13 mishnayos'),
        ),
        findsOneWidget,
      );
      await unmountAdjust(tester);
    });

    testWidgets('an empty adjusted action never reaches the command', (
      tester,
    ) async {
      final rig = AdjustRig();
      final commands = FakeLearningCommands();
      await pumpAdjustCard(tester, adjustOverrides(rig, commands));
      final element = tester.element(_card);
      final card = tester.widget<CatchUpCardView>(_card).card;
      ProviderScope.containerOf(
        element,
      ).read(catchUpCardActionsProvider).recordAdjusted!(
        element,
        card,
        CatchUpAction(
          lock: card.window.lock,
          mode: CatchUpMode.adjusted,
          lockedDaysOffered: 1,
          leaves: const [],
        ),
      );
      await settleAdjust(tester);
      expect(commands.calls, isEmpty);
      expect(_card, findsOneWidget);
      await unmountAdjust(tester);
    });
  });
}
