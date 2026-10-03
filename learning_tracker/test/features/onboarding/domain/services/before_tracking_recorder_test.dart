// Mirror test for
// `lib/features/onboarding/domain/services/before_tracking_recorder.dart`
// (Story 1.11, DNI-473): bulk mark and lifetime marking are ONE
// `before_tracking` capture — whole nodes as node
// events with their `level`, single leaves as leaf events — and un-ticking
// is `unlearn`.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/onboarding/domain/services/before_tracking_recorder.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _m = CurriculumId.mishnayos;

ContentItem _item(
  String ref,
  int order, {
  required String l1,
  String? l2,
  String? l3,
  String? l4,
  bool leaf = false,
}) => ContentItem(
  curriculumId: 'mishnayos',
  level1: l1,
  level2: l2,
  level3: l3,
  level4: l4,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: order,
  isLeaf: leaf,
);

/// Zeraim › Berakhot › 1 › {1:1, 1:2}; Zeraim › Peah › 1 › {1:1};
/// Moed › Shabbat › 1 › {1:1}.
final _items = [
  _item('Seder Zeraim', 0, l1: 'Zeraim'),
  _item('Mishnah Berakhot', 1, l1: 'Zeraim', l2: 'Berakhot'),
  _item('Mishnah Berakhot 1', 2, l1: 'Zeraim', l2: 'Berakhot', l3: '1'),
  _item(
    'Mishnah Berakhot 1:1',
    3,
    l1: 'Zeraim',
    l2: 'Berakhot',
    l3: '1',
    l4: '1',
    leaf: true,
  ),
  _item(
    'Mishnah Berakhot 1:2',
    4,
    l1: 'Zeraim',
    l2: 'Berakhot',
    l3: '1',
    l4: '2',
    leaf: true,
  ),
  _item('Mishnah Peah', 5, l1: 'Zeraim', l2: 'Peah'),
  _item('Mishnah Peah 1', 6, l1: 'Zeraim', l2: 'Peah', l3: '1'),
  _item(
    'Mishnah Peah 1:1',
    7,
    l1: 'Zeraim',
    l2: 'Peah',
    l3: '1',
    l4: '1',
    leaf: true,
  ),
  _item('Seder Moed', 8, l1: 'Moed'),
  _item('Mishnah Shabbat', 9, l1: 'Moed', l2: 'Shabbat'),
  _item('Mishnah Shabbat 1', 10, l1: 'Moed', l2: 'Shabbat', l3: '1'),
  _item(
    'Mishnah Shabbat 1:1',
    11,
    l1: 'Moed',
    l2: 'Shabbat',
    l3: '1',
    l4: '1',
    leaf: true,
  ),
];

String _level(int depth) =>
    contentLevelName(CurriculumLabels.labelsEn(_m), depth);

class _Content extends Fake implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      _items;
}

LearningEvent _learn(
  String id,
  String ref, {
  DateState state = DateState.beforeTracking,
  String? level,
}) => LearningEvent.learn(
  id: id,
  curriculumId: 'mishnayos',
  ref: ref,
  level: level,
  source: LearningEvent.sourceMain,
  dateState: state,
  learnedOn: state == DateState.beforeTracking ? null : '2026-09-01',
  recordedAt: DateTime.utc(2026, 9, 1),
  actor: parentActor,
);

void main() {
  group('planBeforeTracking', () {
    test('a ticked container is ONE node event carrying its level; a '
        'ticked leaf is a leaf event', () {
      final batch = planBeforeTracking(
        curriculumId: _m,
        items: _items,
        selections: const [
          HierarchySelection(level1: 'Zeraim', level2: 'Berakhot'),
          HierarchySelection(
            level1: 'Moed',
            level2: 'Shabbat',
            level3: '1',
            level4: '1',
          ),
        ],
      );
      expect(batch.nodes, [
        NodeEntry(level: _level(2), ref: 'Mishnah Berakhot'),
      ]);
      expect(batch.refs, ['Mishnah Shabbat 1:1']);
      expect(batch.leaves.map((l) => l.sefariaRef), [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Shabbat 1:1',
      ]);
    });

    test('a leaf under a ticked node is not repeated', () {
      final batch = planBeforeTracking(
        curriculumId: _m,
        items: _items,
        selections: const [
          HierarchySelection(level1: 'Zeraim'),
          HierarchySelection(
            level1: 'Zeraim',
            level2: 'Peah',
            level3: '1',
            level4: '1',
          ),
        ],
      );
      expect(batch.nodes, [NodeEntry(level: _level(1), ref: 'Seder Zeraim')]);
      expect(batch.refs, isEmpty);
      expect(batch.leaves, hasLength(3));
    });

    test('no selection is an empty batch', () {
      final batch = planBeforeTracking(
        curriculumId: _m,
        items: _items,
        selections: const [],
      );
      expect(batch.isEmpty, isTrue);
      expect(batch.leaves, isEmpty);
    });
  });

  group('planScopeMarks (Lifetime Marking)', () {
    test('a qualified unit id naming a container is a node event with its '
        'level', () {
      final batch = planScopeMarks(
        curriculumId: _m,
        items: _items,
        scopes: const [
          (level: 1, unitId: 'Moed'),
          (level: 2, unitId: 'Zeraim|Peah'),
        ],
      );
      expect(batch.nodes, [
        NodeEntry(level: _level(1), ref: 'Seder Moed'),
        NodeEntry(level: _level(2), ref: 'Mishnah Peah'),
      ]);
      expect(batch.refs, isEmpty);
      expect(batch.leaves.map((l) => l.sefariaRef), [
        'Mishnah Peah 1:1',
        'Mishnah Shabbat 1:1',
      ]);
    });
  });

  group('BeforeTrackingRecorder', () {
    late FakeLearningCommands commands;
    late List<LearningEvent> events;

    BeforeTrackingRecorder recorder({bool noLearner = false}) =>
        BeforeTrackingRecorder(
          contentRepository: _Content(),
          commands: () async => noLearner ? null : commands,
          events: () async => events,
        );

    setUp(() {
      commands = FakeLearningCommands();
      events = [];
    });
    tearDown(() => commands.dispose());

    test(
      'record is ONE before_tracking capture with no learned_on (R10)',
      () async {
        final result = await recorder().record(
          curriculumId: _m,
          selections: const [
            HierarchySelection(level1: 'Zeraim', level2: 'Berakhot'),
          ],
        );
        expect(result.itemCount, 2);
        expect(result.eventCount, 1, reason: 'one node event');
        final capture = commands.calls.single;
        expect(capture.name, 'capture');
        expect(capture.args['curriculumId'], 'mishnayos');
        expect(capture.args['dateState'], DateState.beforeTracking);
        expect(capture.args['learnedOn'], isNull);
        expect(capture.args['source'], LearningEvent.sourceMain);
        expect(capture.args['nodes'], [
          NodeEntry(level: _level(2), ref: 'Mishnah Berakhot'),
        ]);
        expect(capture.args['refs'], isEmpty);
      },
    );

    test('a failed capture is rejected', () async {
      commands.nextResult = const CaptureResult.rejected(
        CaptureRejection.notSaved,
      );
      final result = await recorder().record(
        curriculumId: _m,
        selections: const [HierarchySelection(level1: 'Moed')],
      );
      expect(result.capture, isA<CaptureRejected>());
      expect(result.eventCount, 0);
    });

    test('recordScopes captures a selected node', () async {
      final result = await recorder().recordScopes(
        curriculumId: _m,
        scopes: const [(level: 1, unitId: 'Moed')],
      );
      expect(result.capture, isA<CaptureSuccess>());
      expect(result.itemCount, 1);
      expect(commands.calls.single.args['nodes'], [
        NodeEntry(level: _level(1), ref: 'Seder Moed'),
      ]);
    });

    test('an empty selection writes nothing', () async {
      final result = await recorder().record(
        curriculumId: _m,
        selections: const [],
      );
      expect(result.capture, const CaptureResult.success());
      expect(commands.calls, isEmpty);
    });

    test('no active learner cannot record', () async {
      await expectLater(
        recorder(noLearner: true).record(
          curriculumId: _m,
          selections: const [HierarchySelection(level1: 'Moed')],
        ),
        throwsA(isA<BeforeTrackingUnavailableException>()),
      );
    });

    test(
      'bulk-prior unselect routes exactly the selected leaves to unlearn',
      () async {
        final result = await recorder().unrecord(
          curriculumId: _m,
          sefariaRefs: const ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
        );
        expect(result, isA<CaptureSuccess>());
        expect(commands.calls, hasLength(1));
        final call = commands.calls.single;
        expect(call.name, 'unlearn');
        expect(call.args['curriculumId'], 'mishnayos');
        expect(call.args['leafSet'], {
          'Mishnah Berakhot 1:1',
          'Mishnah Berakhot 1:2',
        });
      },
    );

    test('recordedRefs is the counted before_tracking leaves, node events '
        'expanded, voided and dated events excluded', () async {
      const node = '01ARZ3NDEKTSV4RRFFQ69G0001';
      const voided = '01ARZ3NDEKTSV4RRFFQ69G0002';
      events = [
        _learn(node, 'Mishnah Berakhot', level: _level(2)),
        _learn(voided, 'Mishnah Shabbat 1:1'),
        _learn(
          '01ARZ3NDEKTSV4RRFFQ69G0003',
          'Mishnah Peah 1:1',
          state: DateState.dated,
        ),
        LearningEvent.voidOf(
          id: '01ARZ3NDEKTSV4RRFFQ69G0004',
          targetId: voided,
          recordedAt: DateTime.utc(2026, 9, 2),
          actor: parentActor,
        ),
      ];
      expect(await recorder().recordedRefs(_m), {
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
      });
    });
  });
}
