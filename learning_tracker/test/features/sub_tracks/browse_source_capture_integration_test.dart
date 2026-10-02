// Story 2.10 (DNI-501) AC-9 / AC-11 integration: the Browse free-tick
// sheet offers Home, each onHome sub-track of the curriculum by name and
// Before tracking; a sub-track choice writes its ULID as source, dated,
// with no stage and no pts_ entry. A tutor device offers no sub-track.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'helpers/capture_harness.dart';
import 'helpers/up_to_fixtures.dart';

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

final _items = [
  _c('Zeraim', 0, ['Zeraim']),
  _c('Berakhot', 1, ['Zeraim', 'Berakhot']),
  _c('Berakhot 1', 2, ['Zeraim', 'Berakhot', '1']),
  _c('Mishnah Berakhot 1:1', 3, ['Zeraim', 'Berakhot', '1', '1'], leaf: true),
  _c('Mishnah Berakhot 1:2', 4, ['Zeraim', 'Berakhot', '1', '2'], leaf: true),
];

/// 460 leaves of one chapter: a free tick of the chapter is two chunks
/// (450 + 10 writes, AD-54) from a sub-track source.
final _long = [for (var i = 1; i <= 460; i++) 'Mishnah Long 1:$i'];

final _longItems = [
  _c('Long', 0, ['Seder', 'Long']),
  _c('Long 1', 1, ['Seder', 'Long', '1']),
  for (final (i, ref) in _long.indexed)
    _c(ref, i + 2, ['Seder', 'Long', '1', '${i + 1}'], leaf: true),
];

class _Content extends Fake implements ContentRepository {
  _Content(this.items);

  final List<ContentItem> items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      id == _m ? items : const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId id) async =>
      CurriculumHierarchyConfig(
        curriculumId: id.storageKey,
        levelLabels: CurriculumLabels.labelsEn(_m),
        totalItems: items.length,
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

/// Tuesday 2026-09-01 10:00Z.
final _tuesday = engineAt(600);

final _school = fixtureSubTrack(schoolId, 'School');
final _rebbe = fixtureSubTrack(rebbeId, 'Rebbe');

Future<CaptureRig> _pump(
  WidgetTester tester, {
  bool tutor = false,
  bool long = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final rig = long
      ? CaptureRig(
          now: _tuesday,
          corpus: longCorpus(_long),
          subTracks: [
            fixtureSubTrack(
              schoolId,
              'School',
              ground: const [NodeEntry(level: 'masechta', ref: 'Mishnah Long')],
            ),
            _rebbe,
          ],
        )
      : CaptureRig(now: _tuesday, subTracks: [_school, _rebbe]);
  addTearDown(rig.dispose);
  final items = long ? _longItems : _items;
  final content = _Content(items);
  final tree = ContentTree.fromCurricula({
    for (final c in CurriculumId.values) c: c == _m ? items : const [],
  });
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...rig.overrides(),
        // A curriculum of another learner's track is never offered: only
        // this curriculum's onHome rows are.
        onHomeSubTracksProvider.overrideWith(
          (ref) => AsyncData([
            for (final t in [_rebbe, _school])
              OnHomeSubTrack(
                track: t,
                state: fixtureSubTrackState(t.id, path: const ['x']),
              ),
          ]),
        ),
        subTrackWritesAllowedProvider.overrideWithValue(!tutor),
        contentRepositoryProvider.overrideWithValue(content),
        contentTreeProvider.overrideWith((ref) async => tree),
        curriculumContentProvider.overrideWith(
          (ref, id) => content.getContentForCurriculum(id),
        ),
        completionCountProvider.overrideWith(
          (ref, ({String curriculumId, String sefariaRef}) arg) async => 0,
        ),
        anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
        localDayClockProvider.overrideWithValue(FakeLocalDayClock(_tuesday)),
      ],
      child: ContentHierarchyScreen(
        curriculumId: 'mishnayos',
        level1: long ? 'Seder' : 'Zeraim',
        level2: long ? 'Long' : 'Berakhot',
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return rig;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the sheet lists Home (default), each onHome sub-track by '
      'name, then Before tracking', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(Checkbox).first);
    await _settle(tester);
    final home = tester.getTopLeft(find.byKey(const Key('freeTickSourceHome')));
    final rebbe = tester.getTopLeft(find.byKey(Key('freeTickSource-$rebbeId')));
    final school = tester.getTopLeft(
      find.byKey(Key('freeTickSource-$schoolId')),
    );
    final before = tester.getTopLeft(
      find.byKey(const Key('freeTickSourceBeforeTracking')),
    );
    expect(home.dy < rebbe.dy, isTrue);
    expect(rebbe.dy < school.dy, isTrue, reason: 'hub order');
    expect(school.dy < before.dy, isTrue);
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Rebbe'), findsOneWidget);
  });

  testWidgets('choosing a sub-track writes its ULID as source, dated, no '
      'stage and no pts_ entry', (tester) async {
    final rig = await _pump(tester);
    await tester.tap(find.byType(Checkbox).first);
    await _settle(tester);
    await tester.tap(find.byKey(Key('freeTickSource-$schoolId')));
    await _settle(tester);
    await tester.tap(find.text('Record 2'));
    await _settle(tester);
    expect(rig.written.map((e) => e.ref), [
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
    ]);
    for (final e in rig.written) {
      expect(e.source, schoolId);
      expect(e.dateState, DateState.dated);
      expect(e.learnedOn, '2026-09-01');
      expect(e.stage, isNull);
    }
    expect(rig.awards, isEmpty);
    // The engine moves School only (FR-13).
    final state = rig.state.curricula[engineCurriculum]!;
    expect(state.subTracks[schoolId]!.position, 'Mishnah Berakhot 1:3');
    expect(state.subTracks[rebbeId]!.position, 'Mishnah Berakhot 1:1');
  });

  testWidgets('AC-11: a tutor device offers no sub-track source', (
    tester,
  ) async {
    await _pump(tester, tutor: true);
    await tester.tap(find.byType(Checkbox).first);
    await _settle(tester);
    expect(find.byKey(const Key('freeTickSourceHome')), findsOneWidget);
    expect(
      find.byKey(const Key('freeTickSourceBeforeTracking')),
      findsOneWidget,
    );
    expect(find.byKey(Key('freeTickSource-$schoolId')), findsNothing);
    expect(find.byKey(Key('freeTickSource-$rebbeId')), findsNothing);
  });

  test('the choices are only the curriculum\'s onHome rows, and none in a '
      'tutored session', () {
    final c = ProviderContainer(
      overrides: [
        onHomeSubTracksProvider.overrideWith(
          (ref) => AsyncData([
            OnHomeSubTrack(
              track: _school,
              state: fixtureSubTrackState(schoolId),
            ),
          ]),
        ),
        subTrackWritesAllowedProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(subTrackSourceChoicesProvider(engineCurriculum)), [
      (id: schoolId, name: 'School'),
    ]);
    expect(c.read(subTrackSourceChoicesProvider('bavli')), isEmpty);
    final tutor = ProviderContainer(
      overrides: [
        onHomeSubTracksProvider.overrideWith(
          (ref) => AsyncData([
            OnHomeSubTrack(
              track: _school,
              state: fixtureSubTrackState(schoolId),
            ),
          ]),
        ),
        subTrackWritesAllowedProvider.overrideWithValue(false),
      ],
    );
    addTearDown(tutor.dispose);
    expect(
      tutor.read(subTrackSourceChoicesProvider(engineCurriculum)),
      isEmpty,
    );
  });

  testWidgets('a two-chunk free tick whose first chunk is rejected ticks '
      'only the saved leaves, claims only them, and a Retry ticks the '
      'rest', (tester) async {
    final rig = await _pump(tester, long: true);
    bool? chapterTick() => tester.widget<Checkbox>(find.byType(Checkbox)).value;
    expect(chapterTick(), isFalse);

    rig.port.failNextWith(const PermanentWriteRejection('permission-denied'));
    await tester.tap(find.byType(Checkbox));
    await _settle(tester);
    await tester.tap(find.byKey(Key('freeTickSource-$schoolId')));
    await _settle(tester);
    await tester.tap(find.text('Record 460'));
    await _settle(tester);

    expect(rig.port.attempts, hasLength(2));
    expect([for (final e in rig.written) e.ref], _long.sublist(450));
    expect(
      chapterTick(),
      isNull,
      reason: 'the rejected chunk is not shown as learnt (partial)',
    );
    expect(find.text('460 recorded'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(rig.written, hasLength(460));
    expect(chapterTick(), isTrue);
  });

  group('recordedBatch', () {
    final refs = ['a', 'b', 'c'];

    test('keys every planned event to its leaf, ticks only saved ones', () {
      final r = recordedBatch(
        refs: refs,
        nodeRefs: refs,
        eventIds: ['E3'],
        rejectedEventIds: ['E1', 'E2'],
        failed: const {},
      );
      expect(r.byEvent, {
        'E1': ['a'],
        'E2': ['b'],
        'E3': ['c'],
      });
      expect(r.ticked, {'c'});
    });

    test('a failure reported before the result is never ticked', () {
      final r = recordedBatch(
        refs: refs,
        nodeRefs: refs,
        eventIds: ['E1', 'E2', 'E3'],
        rejectedEventIds: const [],
        failed: {'E2'},
      );
      expect(r.ticked, {'a', 'c'});
    });

    test('a plan that does not line up ticks nothing', () {
      final r = recordedBatch(
        refs: refs,
        nodeRefs: refs,
        eventIds: ['E1'],
        rejectedEventIds: const [],
        failed: const {},
      );
      expect(r.byEvent, isEmpty);
      expect(r.ticked, isEmpty);
    });

    test('a node event covers every leaf; a failed one ticks none', () {
      final saved = recordedBatch(
        refs: null,
        nodeRefs: refs,
        eventIds: ['N1'],
        rejectedEventIds: const [],
        failed: const {},
      );
      expect(saved.byEvent, {'N1': refs});
      expect(saved.ticked, refs.toSet());
      final failed = recordedBatch(
        refs: null,
        nodeRefs: refs,
        eventIds: ['N1'],
        rejectedEventIds: const [],
        failed: {'N1'},
      );
      expect(failed.ticked, isEmpty);
    });
  });
}
