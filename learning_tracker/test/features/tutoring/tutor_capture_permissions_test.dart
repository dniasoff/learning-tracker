// Story 1.24 (DNI-486) AC-4 + edge AC-4/AC-5 — a grant without
// `can_edit_learning` keeps the tutor's capture, Mishna-history correction
// and main-track controls VISIBLE but disabled (40% opacity, disabled
// semantics) under one note "{learner}'s parent hasn't given you editing
// access"; no callable is invoked. Permission takes precedence over the
// connection and the lock, and no blocked state exposes an enabled control.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart'
    show TriState;
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/learning/domain/models/mishna_history_item.dart';
import 'package:learning_tracker/features/learning/presentation/screens/mishna_history_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_write_gate.dart';

import '../../helpers/learner_state/fake_learning_commands.dart';
import '../../helpers/learner_state/mishna_history_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

const _note = "Yossi's parent hasn't given you editing access";

TutorWriteAvailability _availability(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  final sub = container.listen(tutorWriteAvailabilityProvider, (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}

Future<TutorWriteAvailability> _settled(List<Override> overrides) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  final sub = container.listen(tutorWriteAvailabilityProvider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return sub.read();
}

final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 8),
  DateTime.utc(2026, 10, 2, 20),
);

void main() {
  group('availability precedence (edge AC-4/AC-5)', () {
    test('the owner session is never gated by the tutor rules', () {
      expect(_availability(tutoredOverrides()), TutorWriteAvailability.owner);
    });

    test(
      'can_edit_learning false wins over offline and over the lock',
      () async {
        expect(
          await _settled(
            tutoredOverrides(
              selection: tutorSelection(canEditLearning: false),
              online: false,
              gate: FakeCaptureGate.locked(_lock),
            ),
          ),
          TutorWriteAvailability.noEditAccess,
        );
      },
    );

    test('every blocked state disables writes; only available enables', () {
      for (final a in TutorWriteAvailability.values) {
        expect(
          a.allowsWrite,
          a == TutorWriteAvailability.owner ||
              a == TutorWriteAvailability.available,
          reason: a.name,
        );
      }
    });
  });

  group('AC-4 notes and visible-disabled controls', () {
    testWidgets('the note names the learner and reads the exact copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          overrides: tutoredOverrides(
            selection: tutorSelection(canEditLearning: false),
          ),
          child: const Scaffold(body: TutorWriteNote()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_note), findsOneWidget);
    });

    testWidgets('a disabled control stays visible at 40% opacity and its '
        'own semantics report disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        pumpApp(
          child: const Scaffold(
            body: TutorDisabledControl(
              blocked: true,
              child: FilledButton(onPressed: null, child: Text('Mark')),
            ),
          ),
        ),
      );
      expect(find.text('Mark'), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.byKey(const Key('tutorDisabledControl')),
      );
      expect(opacity.opacity, 0.4);
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });

    testWidgets('a Browse tick for a blocked tutor is visible, disabled and '
        'at 40%', (tester) async {
      var ticked = 0;
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: ContentItemTile(
              item: const ContentItem(
                curriculumId: 'mishnayos',
                level1: 'Zeraim',
                level2: 'Berakhot',
                level3: '2',
                level4: '1',
                displayNameHe: 'Berakhot 2:1',
                displayNameEn: 'Berakhot 2:1',
                sefariaRef: 'Mishnah Berakhot 2:1',
                sortOrder: 6,
                isLeaf: true,
              ),
              curriculum: CurriculumId.mishnayos,
              onTap: () {},
              reviewCount: 0,
              tickState: TriState.empty,
              onTick: () => ticked++,
              tickDisabled: true,
            ),
          ),
        ),
      );
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('contentItemTickDisabled')))
            .opacity,
        0.4,
      );
      await tester.tap(find.byType(Checkbox));
      expect(ticked, 0);
    });
  });

  group('AC-4 Mishna history for a read-only grant', () {
    late HistoryPorts ports;
    setUp(() => ports = HistoryPorts());
    tearDown(() => ports.dispose());

    testWidgets('rows stay readable, the corrections control is disabled at '
        '40% with the note, and a tap invokes nothing', (tester) async {
      ports.events.seed(ports.scope, [
        historyLearn(1, day: 1),
        historyLearn(2, day: 3),
      ]);
      final commands = FakeLearningCommands();
      addTearDown(commands.dispose);
      await tester.pumpWidget(
        pumpApp(
          child: const MishnaHistoryScreen(
            curriculumId: historyCurriculum,
            leafRef: historyLeaf,
          ),
          overrides: [
            ...historyOverrides(
              ports,
              state: historyState(counted: {eid(1), eid(2)}),
              commands: commands,
              viewer: MishnaHistoryViewer.tutor,
            ),
            tutorWriteAvailabilityProvider.overrideWithValue(
              TutorWriteAvailability.noEditAccess,
            ),
            tutorLearnerNameOverride(),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(ValueKey('mishnaHistoryRow-${eid(2)}'));
      expect(row, findsOneWidget);
      expect(find.text(_note), findsOneWidget);
      final disabled = find.descendant(
        of: row,
        matching: find.byKey(const Key('mishnaHistoryActionsDisabled')),
      );
      expect(disabled, findsOneWidget);
      expect(tester.widget<Opacity>(disabled).opacity, 0.4);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mishnaHistoryAction-remove')), findsNothing);
      expect(commands.calls, isEmpty);
    });
  });

  group('AC-4 no callable is invoked', () {
    test('capture, correction and governed writes all stop before the '
        'callable', () async {
      final h = TutorHarness(
        canEditLearning: false,
        events: [
          LearningEvent.learn(
            id: '01ARZ3NDEKTSV4RRFFQ69G0001',
            curriculumId: 'mishnayos',
            ref: 'Mishnah Berakhot 2:1',
            source: LearningEvent.sourceMain,
            dateState: DateState.dated,
            learnedOn: '2026-09-30',
            recordedAt: DateTime.utc(2026, 9, 30),
            actor: parentActor,
          ),
        ],
      );
      addTearDown(h.dispose);

      await h.commands.capture(
        curriculumId: 'mishnayos',
        refs: const ['Mishnah Berakhot 2:1'],
        source: LearningEvent.sourceMain,
        dateState: DateState.dated,
      );
      await h.commands.voidEvent('01ARZ3NDEKTSV4RRFFQ69G0001');
      await expectLater(h.governed.endGoal('g1'), throwsA(anything));
      expect(h.invoker.calls, isEmpty);
    });
  });
}
