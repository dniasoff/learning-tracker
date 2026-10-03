// Mirror test for
// `lib/features/sub_tracks/presentation/widgets/ground_picker_pane.dart`
// (Story 2.7 / DNI-498 AC-2, AC-4 rollback, AC-7/AC-8 fail-closed body):
// the picker composition over a Mishnayos and a non-Mishnayos ContentIndex,
// the live count, confirm, rejection rollback and load-failure retry.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';

import '../../../../helpers/learner_state/chumash_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  GroundPickerWorld world, {
  VoidCallback? onClose,
}) async {
  tester.view.physicalSize = phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      child: Scaffold(
        body: GroundPickerPane(subTrackId: schoolId, onClose: onClose ?? () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _rowCheckbox(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(InkWell)),
  matching: find.byType(Checkbox),
);

void main() {
  group('AC-2 composition (Mishnayos)', () {
    late GroundPickerWorld world;
    late FakeLearningCommands commands;

    setUp(() {
      commands = FakeLearningCommands();
      world = GroundPickerWorld(
        corpus: mishnayosCorpus(),
        commands: commands,
        tracks: [
          fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
        ],
      );
    });

    tearDown(() => world.dispose());

    testWidgets('title, search, Available only, legend, tree, footer pill '
        'and note', (tester) async {
      await _pump(tester, world);
      expect(find.text('Add ground to School'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Search'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Available only'), findsOneWidget);
      for (final legend in ['Complete', 'Partial', 'Empty']) {
        expect(find.text(legend), findsOneWidget);
      }
      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(find.text('Seder Moed'), findsOneWidget);
      expect(find.text('Reset changes'), findsOneWidget);
      expect(find.text('Add to School'), findsOneWidget);
      expect(
        find.text("They'll leave the home schedule while School holds them."),
        findsOneWidget,
      );
    });

    testWidgets('every ContentIndex level expands, counted in its own unit', (
      tester,
    ) async {
      await _pump(tester, world);
      // Seder → 2 masechtos, masechta → 2 perakim, perek → 3 mishnayos.
      expect(find.text('2 Masechtos'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand Seder Zeraim'));
      await tester.pumpAndSettle();
      expect(find.text('Mishnah Berakhot'), findsOneWidget);
      expect(find.text('2 Perakim'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand Mishnah Berakhot'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand Mishnah Berakhot 1'));
      await tester.pumpAndSettle();
      expect(find.text('3 Mishnayos'), findsOneWidget);
      expect(find.text('Mishnah Berakhot 1:3'), findsOneWidget);
    });

    testWidgets('the pill counts live in the picked level', (tester) async {
      await _pump(tester, world);
      await tester.tap(find.byTooltip('Expand Seder Zeraim'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expand Mishnah Berakhot'));
      await tester.pumpAndSettle();
      await tester.tap(_rowCheckbox('Mishnah Berakhot 1'));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 Perek to School'), findsOneWidget);
      await tester.tap(_rowCheckbox('Mishnah Berakhot 2'));
      await tester.pumpAndSettle();
      expect(find.text('Add 2 Perakim to School'), findsOneWidget);
    });

    testWidgets('confirm appends the picks through editSubTrack and closes', (
      tester,
    ) async {
      var closed = 0;
      await _pump(tester, world, onClose: () => closed++);
      await tester.tap(_rowCheckbox('Seder Moed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 Seder to School'));
      await tester.pumpAndSettle();
      expect(commands.calls, hasLength(1));
      final call = commands.calls.single;
      expect(call.name, 'editSubTrack');
      expect(call.args['subTrackId'], schoolId);
      final edit = call.args['edit']! as SubTrackEdit;
      expect(edit.appendGround, [moed]);
      expect(edit.ground, isNull);
      expect(closed, 1);
    });

    testWidgets('a rejected assignment rolls back with a snackbar and keeps '
        'the picks', (tester) async {
      var closed = 0;
      commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.invalid,
      );
      await _pump(tester, world, onClose: () => closed++);
      await tester.tap(_rowCheckbox('Seder Moed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 Seder to School'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't add the ground. Nothing was changed."),
        findsOneWidget,
      );
      expect(closed, 0);
      // Back at the last accepted ground: Moed is a pick, not stored ground.
      expect(find.text('Already in School'), findsNothing);
      expect(find.text('Add 1 Seder to School'), findsOneWidget);
      expect(world.subTracks.calls, isEmpty);
    });

    testWidgets('offline (online required) says so, keeps the picks and '
        'stays open', (tester) async {
      var closed = 0;
      commands.nextResult = const CaptureResult.onlineRequired();
      await _pump(tester, world, onClose: () => closed++);
      await tester.tap(_rowCheckbox('Seder Moed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 Seder to School'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "You're offline. Ground can be added once you're back online. "
          'Nothing was changed.',
        ),
        findsOneWidget,
      );
      expect(closed, 0);
      expect(find.text('Add 1 Seder to School'), findsOneWidget);
      expect(world.subTracks.calls, isEmpty);
    });

    testWidgets('the parent session ending mid-confirm (PIN lock while the '
        'commands load) writes nothing', (tester) async {
      final gate = Completer<void>();
      final slow = GroundPickerWorld(
        corpus: mishnayosCorpus(),
        commands: commands,
        commandsGate: gate.future,
        tracks: [
          fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
        ],
      );
      addTearDown(slow.dispose);
      var closed = 0;
      await _pump(tester, slow, onClose: () => closed++);
      await tester.tap(_rowCheckbox('Seder Moed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 Seder to School'));
      await tester.pump();
      // The PIN locks while the confirm waits for its commands.
      slow.parent = false;
      ProviderScope.containerOf(
        tester.element(find.byType(GroundPickerPane)),
      ).invalidate(parentSessionProvider);
      gate.complete();
      await tester.pumpAndSettle();
      expect(commands.calls, isEmpty);
      expect(slow.subTracks.calls, isEmpty);
      expect(closed, 0);
      expect(
        find.text("Couldn't add the ground. Nothing was changed."),
        findsOneWidget,
      );
    });

    testWidgets('no commands (not ready) is a rejection, not a crash', (
      tester,
    ) async {
      final noCommands = GroundPickerWorld(
        corpus: mishnayosCorpus(),
        tracks: [
          fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
        ],
      );
      addTearDown(noCommands.dispose);
      await _pump(tester, noCommands);
      await tester.tap(_rowCheckbox('Seder Moed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add 1 Seder to School'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't add the ground. Nothing was changed."),
        findsOneWidget,
      );
    });

    testWidgets('a load failure shows AppErrorView and Retry recovers', (
      tester,
    ) async {
      world.failCorpusReads = 1;
      await _pump(tester, world);
      expect(find.text("Couldn't load the curriculum."), findsOneWidget);
      expect(find.text('Seder Zeraim'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Seder Zeraim'), findsOneWidget);
      expect(world.corpusReads, 2);
    });
  });

  group('AC-2 generic levels (prd-deviations #12)', () {
    testWidgets('a non-Mishnayos curriculum shows its own names, levels and '
        'units, never Mishnayos words', (tester) async {
      final corpus = chumashCorpus();
      final world = GroundPickerWorld(
        corpus: corpus,
        commands: FakeLearningCommands(),
        tracks: [
          fixtureTrack(
            schoolId,
            'Chumash class',
            curriculumId: corpus.curriculumId,
          ),
        ],
        labelItems: {CurriculumId.chumash: contentItemsOf(corpus)},
      );
      addTearDown(world.dispose);
      await _pump(tester, world);
      expect(find.text('Add ground to Chumash class'), findsOneWidget);
      // ContentIndex names, rendered by the curriculum's own label rules.
      expect(find.text('Bereishis'), findsOneWidget);
      expect(find.text('Shemos'), findsOneWidget);
      expect(find.text('2 Perakim'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand Bereishis'));
      await tester.pumpAndSettle();
      expect(find.text('3 Pesukim'), findsOneWidget);
      await tester.tap(_rowCheckbox('Shemos'));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 Sefer to Chumash class'), findsOneWidget);
      for (final word in ['Masechta', 'Masechtos', 'Mishna', 'Mishnayos']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });

    testWidgets('an unknown curriculum falls back to its raw level keys', (
      tester,
    ) async {
      final corpus = _unknownCurriculum();
      final world = GroundPickerWorld(
        corpus: corpus,
        commands: FakeLearningCommands(),
        tracks: [
          fixtureTrack(schoolId, 'Shiur', curriculumId: corpus.curriculumId),
        ],
      );
      addTearDown(world.dispose);
      await _pump(tester, world);
      expect(find.text('Book A'), findsOneWidget);
      expect(find.text('2 section'), findsOneWidget);
    });
  });

  group('AC-7 / AC-8 fail closed', () {
    for (final (label, build) in <(String, GroundPickerWorld Function())>[
      (
        'child session',
        () => GroundPickerWorld(
          corpus: mishnayosCorpus(),
          parent: false,
          tracks: [
            fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
          ],
        ),
      ),
      (
        'calendar-program curriculum',
        () => GroundPickerWorld(
          corpus: mishnayosCorpus(),
          calendarProgram: true,
          tracks: [
            fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
          ],
        ),
      ),
      (
        'ended sub-track',
        () => GroundPickerWorld(
          corpus: mishnayosCorpus(),
          tracks: [
            fixtureTrack(
              schoolId,
              'School',
              curriculumId: engineCurriculum,
              ended: true,
            ),
          ],
        ),
      ),
      ('unknown sub-track', () => GroundPickerWorld(corpus: mishnayosCorpus())),
    ]) {
      testWidgets('$label: no editable control', (tester) async {
        final world = build();
        addTearDown(world.dispose);
        await _pump(tester, world);
        expect(find.text("Ground can't be added here."), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.byType(TextField), findsNothing);
      });
    }
  });
}

/// A curriculum the app does not know, with unrecognised level keys:
/// `custom`, Book A → two sections → one line each.
InMemoryCorpus _unknownCurriculum() => InMemoryCorpus('custom', const [
  CorpusNode(NodeEntry(level: 'book', ref: 'Book A'), [
    CorpusNode(NodeEntry(level: 'section', ref: 'Book A 1'), [
      CorpusNode(NodeEntry(level: 'line', ref: 'Book A 1:1')),
    ]),
    CorpusNode(NodeEntry(level: 'section', ref: 'Book A 2'), [
      CorpusNode(NodeEntry(level: 'line', ref: 'Book A 2:1')),
    ]),
  ]),
]);
