// Story 1.11 (DNI-473) AC-3 / AC-4 / AC-5 and edges: Browse free tick and
// "Tick up to here", end to end through the real `DefaultLearningCommands`
// over an in-memory write port.
//
// * A tick asks the source ONCE (Home default; Before tracking offered),
//   with a today-default editable date, and records ONE capture.
// * "Tick up to here" (long-press) is inclusive and corpus ordered within
//   the masechta.
// * Undo voids exactly the batch; a permanent rejection rolls the optimistic
//   tick back and offers Retry with the same event ids; a lock writes
//   nothing; Cancel writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';

const _m = CurriculumId.mishnayos;

ContentItem _c(String ref, int order, List<String> path, {bool leaf = false}) =>
    ContentItem(
      curriculumId: 'mishnayos',
      level1: path[0],
      level2: path.length > 1 ? path[1] : null,
      level3: path.length > 2 ? path[2] : null,
      level4: path.length > 3 ? path[3] : null,
      displayNameHe: ref,
      displayNameEn: ref,
      sefariaRef: ref,
      sortOrder: order,
      isLeaf: leaf,
    );

/// Zeraim › Berakhot (perakim 1, 2) and Peah (perek 1).
final _items = [
  _c('Zeraim', 0, ['Zeraim']),
  _c('Berakhot', 1, ['Zeraim', 'Berakhot']),
  _c('Berakhot 1', 2, ['Zeraim', 'Berakhot', '1']),
  _c('Berakhot 1:1', 3, ['Zeraim', 'Berakhot', '1', '1'], leaf: true),
  _c('Berakhot 1:2', 4, ['Zeraim', 'Berakhot', '1', '2'], leaf: true),
  _c('Berakhot 2', 5, ['Zeraim', 'Berakhot', '2']),
  _c('Berakhot 2:1', 6, ['Zeraim', 'Berakhot', '2', '1'], leaf: true),
  _c('Berakhot 2:2', 7, ['Zeraim', 'Berakhot', '2', '2'], leaf: true),
  _c('Peah', 8, ['Zeraim', 'Peah']),
  _c('Peah 1', 9, ['Zeraim', 'Peah', '1']),
  _c('Peah 1:1', 10, ['Zeraim', 'Peah', '1', '1'], leaf: true),
];

/// Tuesday 2026-09-01 10:00Z, unlocked for the UTC fixture learner.
final _tuesday = engineAt(600);

/// Saturday 2026-09-05 10:00Z, inside the fixture Shabbos lock.
final _shabbos = DateTime.utc(2026, 9, 5, 10);

class _Content extends Fake implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      id == _m ? _items : const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId id) async =>
      CurriculumHierarchyConfig(
        curriculumId: id.storageKey,
        levelLabels: CurriculumLabels.labelsEn(_m),
        totalItems: _items.length,
      );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];
}

final class _Browse {
  _Browse({DateTime? now, List<LearningEvent> prior = const []}) {
    final at = now ?? _tuesday;
    reads = FakeLearningCommandReads(
      history: c0SettingsHistory(),
      log: [...prior],
    );
    var seq = 60000;
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: const Actor(
        uid: 'owner-uid',
        role: ActorRole.parent,
        displayName: '',
      ),
      reads: reads,
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => at,
      newUlid: (_) => engineUlid(seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
    clock = FakeLocalDayClock(at);
  }

  final port = InMemoryLearningWritePort();
  late final FakeLearningCommandReads reads;
  late final DefaultLearningCommands commands;
  late final FakeLocalDayClock clock;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  /// Makes the committed events visible to the command reads (the SDK
  /// cache), so an Undo can find its targets.
  void sync() {
    final ids = {for (final e in reads.eventLog) e.id};
    reads.eventLog.addAll(written.where((e) => ids.add(e.id)));
  }

  Widget app({List<String> stack = const ['Zeraim', 'Berakhot']}) {
    final content = _Content();
    final tree = ContentTree.fromCurricula({
      for (final c in CurriculumId.values) c: c == _m ? _items : const [],
    });
    return pumpApp(
      overrides: [
        ...learnerStateOverrides(scope: c0Scope(), commands: commands),
        contentRepositoryProvider.overrideWithValue(content),
        contentTreeProvider.overrideWith((ref) async => tree),
        curriculumContentProvider.overrideWith(
          (ref, id) => content.getContentForCurriculum(id),
        ),
        completionCountProvider.overrideWith(
          (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
        ),
        anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
        localDayClockProvider.overrideWithValue(clock),
      ],
      child: ContentHierarchyScreen(
        curriculumId: 'mishnayos',
        level1: stack.isNotEmpty ? stack[0] : null,
        level2: stack.length > 1 ? stack[1] : null,
      ),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _ticks => find.byType(Checkbox);

bool? _tickValue(WidgetTester tester, int row) =>
    tester.widget<Checkbox>(_ticks.at(row)).value;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('AC-3: ticking a perek asks the source once (Home default), '
      'records ONE capture of its mishnayos dated today, and shows the row '
      'ticked', (tester) async {
    final flow = _Browse();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    expect(_ticks, findsNWidgets(2), reason: 'perakim 1 and 2 of Berakhot');
    expect(_tickValue(tester, 0), isFalse);

    await tester.tap(_ticks.at(0));
    await _settle(tester);
    expect(find.text('Record 2'), findsOneWidget);
    await tester.tap(find.text('Record 2'));
    await _settle(tester);

    expect(flow.port.chunks, hasLength(1), reason: 'one capture');
    expect(flow.written.map((e) => e.ref), ['Berakhot 1:1', 'Berakhot 1:2']);
    for (final e in flow.written) {
      expect(e.source, LearningEvent.sourceMain);
      expect(e.dateState, DateState.dated);
      expect(e.learnedOn, '2026-09-01');
    }
    expect(_tickValue(tester, 0), isTrue, reason: 'optimistic tick');
    expect(find.text('2 recorded'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('AC-3: a Home tick dated to an earlier day is stored dated with '
      'that learned_on', (tester) async {
    final flow = _Browse();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(_ticks.at(1));
    await _settle(tester);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('28'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record 2'));
    await _settle(tester);

    expect(flow.written.map((e) => (e.dateState, e.learnedOn)).toSet(), {
      (DateState.dated, '2026-08-28'),
    });
  });

  testWidgets('AC-3: Before tracking on a whole node records that node '
      'exactly once, with its level and no learned_on', (tester) async {
    final flow = _Browse();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app(stack: const ['Zeraim']));
    await _settle(tester);

    // Rows: Berakhot, Peah.
    await tester.tap(_ticks.at(1));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('freeTickSourceBeforeTracking')));
    await _settle(tester);
    await tester.tap(find.text('Record 1'));
    await _settle(tester);

    final event = flow.written.single;
    expect(event.ref, 'Peah');
    expect(event.level, contentLevelName(CurriculumLabels.labelsEn(_m), 2));
    expect(event.dateState, DateState.beforeTracking);
    expect(event.toStorage()['learned_on'], isNull);
    expect([for (final c in flow.port.chunks) ...c.awards], isEmpty);
  });

  testWidgets('AC-3: long-press "Tick up to here" records the row and every '
      'earlier mishna of its masechta, inclusive, in corpus order, as ONE '
      'capture', (tester) async {
    final flow = _Browse();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.longPress(find.byType(ListTile).at(1)); // perek 2
    await _settle(tester);
    expect(find.text('Tick up to here'), findsOneWidget);
    await tester.tap(find.text('Record 4'));
    await _settle(tester);

    expect(flow.port.chunks, hasLength(1));
    expect(flow.written.map((e) => e.ref), [
      'Berakhot 1:1',
      'Berakhot 1:2',
      'Berakhot 2:1',
      'Berakhot 2:2',
    ]);
    expect(flow.written.map((e) => e.ref), isNot(contains('Peah 1:1')));
  });

  testWidgets('Edge: Cancel writes nothing', (tester) async {
    final flow = _Browse();
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(_ticks.at(0));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(flow.port.attempts, isEmpty);
    expect(_tickValue(tester, 0), isFalse);
  });

  testWidgets('AC-4: Undo voids exactly the batch just written; an unrelated '
      'earlier event stays counted', (tester) async {
    final prior = engineLearn(1, 'Peah 1:1');
    final flow = _Browse(prior: [prior]);
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(_ticks.at(0));
    await _settle(tester);
    await tester.tap(find.text('Record 2'));
    await _settle(tester);
    final batch = [for (final e in flow.written) e.id];
    flow.sync();

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    final voids = flow.written.where((e) => e.isVoid).toList();
    expect(voids.map((e) => e.targetId), unorderedEquals(batch));
    expect(voids.map((e) => e.targetId), isNot(contains(prior.id)));
    expect(_tickValue(tester, 0), isFalse, reason: 'tick rolled back');
  });

  testWidgets('AC-5: during a lock the tick returns locked and writes '
      'nothing', (tester) async {
    final flow = _Browse(now: _shabbos);
    addTearDown(flow.commands.dispose);
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(_ticks.at(0));
    await _settle(tester);
    await tester.tap(find.text('Record 2'));
    await _settle(tester);
    expect(flow.port.attempts, isEmpty);
    expect(_tickValue(tester, 0), isFalse);
    expect(
      find.text('Not recorded — the app is closed for Shabbos and Yom Tov.'),
      findsOneWidget,
    );
  });

  testWidgets('AC-5: a permanent rejection is "not saved" with Retry, the '
      'tick rolls back, and Retry re-sends the same event ids', (tester) async {
    final flow = _Browse();
    addTearDown(flow.commands.dispose);
    flow.port.holdNext();
    await tester.pumpWidget(flow.app());
    await _settle(tester);

    await tester.tap(_ticks.at(0));
    await _settle(tester);
    await tester.tap(find.text('Record 2'));
    await _settle(tester); // the ack window passes: queued offline
    expect(_tickValue(tester, 0), isTrue, reason: 'optimistic while queued');
    final attempted = [for (final e in flow.port.attempts.single.events) e.id];

    flow.port.reject(const PermanentWriteRejection('permission-denied'));
    await _settle(tester);
    expect(
      find.text('Not saved — your learning was not recorded.'),
      findsOneWidget,
    );
    expect(_tickValue(tester, 0), isFalse, reason: 'rolled back');

    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect([for (final e in flow.written) e.id], attempted);
    expect(_tickValue(tester, 0), isTrue, reason: 're-applied');
  });
}
