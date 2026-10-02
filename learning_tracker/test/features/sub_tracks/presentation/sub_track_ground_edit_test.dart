// DNI-497 (Story 2.6) AC-5 / AC-6 integration: reorder (drag and ⋮) and
// confirmed removal go through LearningCommands.editSubTrack (the real
// Story 2.1 SubTrackCommands over in-memory repositories) and the real
// engine recomputes; a rejected edit rolls back with a snackbar.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';

import '../../../helpers/learner_state/c0_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/in_memory_ports.dart';
import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../sub_track_detail_harness.dart';

/// A [LearningCommands] whose sub-track commands are the real Story 2.1
/// [SubTrackCommands]; every call is recorded.
final class _SubTrackOnlyCommands implements LearningCommands {
  _SubTrackOnlyCommands(this.inner);

  final SubTrackCommands inner;
  final List<(String, SubTrackEdit)> edits = [];

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) {
    edits.add((subTrackId, edit));
    return inner.editSubTrack(subTrackId, edit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

void main() {
  late DetailHarness h;
  late InMemoryGovernedIntentRepository intent;
  late _SubTrackOnlyCommands commands;
  var ids = 0;

  final school = detailSubTrack(10, 'School', const [
    berakhot1,
    peah,
    berakhot2,
  ]);
  final rebbe = detailSubTrack(20, 'Rebbe', const [berakhot2]);
  // Ticks in School: 1:1 (here); Peah 1:1 learnt at home.
  final events = <LearningEvent>[
    engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
    engineLearn(2, 'Mishnah Peah 1:1'),
  ];

  // Built inside each test body: the in-memory streams must live in the
  // widget tester's fake-async zone, or their events never arrive.
  void init() {
    h = DetailHarness()..seed(subTracks: [school, rebbe], learnEvents: events);
    intent = InMemoryGovernedIntentRepository()
      ..emit(
        h.scope,
        LearnerIntent(
          settings: c0Settings,
          mainTracks: {engineCurriculum: engineIntent()},
          goals: const <String, CurriculumGoals>{},
        ),
      );
    commands = _SubTrackOnlyCommands(
      SubTrackCommands(
        scope: h.scope,
        actor: parentActor,
        subTracks: h.repository,
        intent: intent,
        today: () => '2026-09-07',
        nowUtc: () => engineAt(10000),
        newId: () => engineUlid(5000 + ++ids),
        ackTimeout: const Duration(milliseconds: 20),
      ),
    );
    addTearDown(() async {
      await commands.inner.dispose();
      await intent.dispose();
      await h.dispose();
    });
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(commands: commands),
        child: SubTrackDetailScreen(subTrackId: school.id),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> rowOrder(WidgetTester tester) {
    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('subTrackGroundRow:0:'),
    );
    final found = [
      for (final e in rows.evaluate())
        (
          tester.getTopLeft(find.byWidget(e.widget)).dy,
          (e.widget.key! as ValueKey<String>).value.substring(
            'subTrackGroundRow:0:'.length,
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, ref) in found) ref];
  }

  SubTrack stored() =>
      h.tracks.tracksOf(h.scope).firstWhere((t) => t.id == school.id);

  /// The engine re-run from scratch on the stored state: what "no stale
  /// tasks" must match.
  void expectEngineRecomputed() {
    final fresh = const LearnerStateEngine().run(
      engineInputs(events: events, subTracks: h.tracks.tracksOf(h.scope)),
    )[engineCurriculum]!;
    final shown = h.curriculum;
    expect(
      shown.subTracks[school.id]!.position,
      fresh.subTracks[school.id]!.position,
    );
    expect(shown.schedulableRefs, fresh.schedulableRefs);
    expect(shown.mainTrackPosition, fresh.mainTrackPosition);
    expect(shown.projection, fresh.projection);
  }

  testWidgets('drag: the whole reordered ground is written once with one '
      'change-log entry; ticks are kept and the position is the first '
      'unticked leaf of the new order', (tester) async {
    init();
    await pump(tester);
    expect(rowOrder(tester), [
      'Mishnah Berakhot 1',
      'Mishnah Peah',
      'Mishnah Berakhot 2',
    ]);
    expect(h.curriculum.subTracks[school.id]!.position, 'Mishnah Berakhot 1:2');

    // Drag Peah (index 1) above Berakhot 1 (index 0).
    final handle = find.byKey(
      const ValueKey('subTrackDragHandle:Mishnah Peah'),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(commands.edits, hasLength(1));
    expect(commands.edits.single.$2.ground, const [peah, berakhot1, berakhot2]);
    expect(h.tracks.entries, hasLength(1), reason: 'one change_log entry');
    expect(stored().ground, const [peah, berakhot1, berakhot2]);
    expect(h.events.eventsOf(h.scope), events, reason: 'ticks are kept');
    expect(rowOrder(tester), [
      'Mishnah Peah',
      'Mishnah Berakhot 1',
      'Mishnah Berakhot 2',
    ]);
    // Peah 1:1 was learnt at home, not ticked here: still the position.
    expect(h.curriculum.subTracks[school.id]!.position, 'Mishnah Peah 1:1');
    expect(find.text('Mishnah Peah 1:1'), findsOneWidget, reason: 'Up next');
    expect(find.text('1 ticked'), findsOneWidget);
    expectEngineRecomputed();
  });

  testWidgets('⋮ → Move down is the non-drag equivalent', (tester) async {
    init();
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('subTrackEntryMenu:Mishnah Berakhot 1')),
    );
    await tester.pumpAndSettle();
    final up = tester.widget<PopupMenuItem<Object?>>(
      find.byKey(const ValueKey('subTrackMoveUp')),
    );
    expect(up.enabled, isFalse, reason: 'already first');
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(commands.edits.single.$2.ground, const [peah, berakhot1, berakhot2]);
    expect(h.tracks.entries, hasLength(1));
    expect(rowOrder(tester).first, 'Mishnah Peah');
    expectEngineRecomputed();
  });

  testWidgets('⋮ → Move up on the last entry', (tester) async {
    init();
    await pump(tester);
    final menu = find.byKey(
      const ValueKey('subTrackEntryMenu:Mishnah Berakhot 2'),
    );
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.pumpAndSettle();
    expect(commands.edits.single.$2.ground, const [berakhot1, berakhot2, peah]);
  });

  testWidgets('confirmed removal writes the ground without the entry; only '
      'leaves unlearnt everywhere and held by no other holdsGround track '
      'return to the main track, in main-track order', (tester) async {
    init();
    await pump(tester);
    final before = h.curriculum.schedulableRefs;
    expect(before, isNot(contains('Mishnah Berakhot 1:2')));

    await tester.tap(
      find.byKey(const ValueKey('subTrackEntryMenu:Mishnah Berakhot 1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from School'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Mishnah Berakhot 1 from School?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('subTrackRemoveConfirm')));
    await tester.pumpAndSettle();

    expect(commands.edits.single.$2.ground, const [peah, berakhot2]);
    expect(h.tracks.entries, hasLength(1));
    expect(h.events.eventsOf(h.scope), events);
    final after = h.curriculum.schedulableRefs;
    // 1:2 and 1:3 return (unlearnt, held by nobody); 1:1 is learnt.
    expect(
      after,
      containsAllInOrder(['Mishnah Berakhot 1:2', 'Mishnah Berakhot 1:3']),
    );
    expect(after, isNot(contains('Mishnah Berakhot 1:1')));
    // Berakhot 2 stays held (School and Rebbe both hold it).
    expect(after, isNot(contains('Mishnah Berakhot 2:1')));
    expect(
      after.indexOf('Mishnah Berakhot 1:3'),
      lessThan(after.indexOf('Mishnah Shabbat 1:1')),
    );
    expect(rowOrder(tester), ['Mishnah Peah', 'Mishnah Berakhot 2']);
    expectEngineRecomputed();
  });

  testWidgets('cancelling the removal writes nothing', (tester) async {
    init();
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('subTrackEntryMenu:Mishnah Peah')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from School'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(commands.edits, isEmpty);
    expect(h.tracks.entries, isEmpty);
  });

  testWidgets('a rejected reorder rolls back to the prior order with a '
      'snackbar', (tester) async {
    init();
    h.tracks.failNextWith(const PermanentWriteRejection('permission-denied'));
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('subTrackEntryMenu:Mishnah Berakhot 1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();

    expect(commands.edits, hasLength(1));
    expect(h.tracks.entries, isEmpty);
    expect(stored().ground, school.ground);
    expect(rowOrder(tester), [
      'Mishnah Berakhot 1',
      'Mishnah Peah',
      'Mishnah Berakhot 2',
    ]);
    expect(
      find.text("Couldn't save the new order. It's back as it was."),
      findsOneWidget,
    );
    expectEngineRecomputed();
  });

  testWidgets('a rejected removal rolls back with its snackbar', (
    tester,
  ) async {
    init();
    h.tracks.failNextWith(const PermanentWriteRejection('permission-denied'));
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('subTrackEntryMenu:Mishnah Peah')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from School'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subTrackRemoveConfirm')));
    await tester.pumpAndSettle();
    expect(rowOrder(tester), [
      'Mishnah Berakhot 1',
      'Mishnah Peah',
      'Mishnah Berakhot 2',
    ]);
    expect(
      find.text("Couldn't remove it. The ground is back as it was."),
      findsOneWidget,
    );
  });

  testWidgets('the reorder shows at once, before the command returns '
      '(optimistic)', (tester) async {
    init();
    final gate = Completer<void>();
    final slow = _GatedCommands(commands, gate.future);
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(commands: slow),
        child: SubTrackDetailScreen(subTrackId: school.id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('subTrackEntryMenu:Mishnah Berakhot 1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move down'));
    await tester.pump();
    await tester.pump();
    expect(rowOrder(tester).first, 'Mishnah Peah');
    gate.complete();
    await tester.pumpAndSettle();
    expect(rowOrder(tester).first, 'Mishnah Peah');
  });
}

/// Holds every edit until [gate] completes.
final class _GatedCommands implements LearningCommands {
  _GatedCommands(this.inner, this.gate);

  final LearningCommands inner;
  final Future<void> gate;

  @override
  Future<CaptureResult> editSubTrack(String id, SubTrackEdit edit) async {
    await gate;
    return inner.editSubTrack(id, edit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
