// Story 1.24 (DNI-486) AC-2 — a tutor with an active grant and
// can_edit_learning, online, ticks Berachos 2:1–2:3 for the talmid in
// Browse. While the tutorRecordLearning callable is pending nothing on
// screen changes (no optimistic tick, no "recorded" notice); only after the
// callable returns success does the row show ticked and the capture notice
// appear. On failure nothing changes.

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/learner_state/learner_state_overrides.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

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

/// Zeraim › Berakhot perakim 1 and 2 (2:1–2:3).
final _items = [
  _c('Zeraim', 0, ['Zeraim']),
  _c('Berakhot', 1, ['Zeraim', 'Berakhot']),
  _c('Berakhot 1', 2, ['Zeraim', 'Berakhot', '1']),
  _c('Berakhot 1:1', 3, ['Zeraim', 'Berakhot', '1', '1'], leaf: true),
  _c('Berakhot 2', 4, ['Zeraim', 'Berakhot', '2']),
  _c('Berakhot 2:1', 5, ['Zeraim', 'Berakhot', '2', '1'], leaf: true),
  _c('Berakhot 2:2', 6, ['Zeraim', 'Berakhot', '2', '2'], leaf: true),
  _c('Berakhot 2:3', 7, ['Zeraim', 'Berakhot', '2', '3'], leaf: true),
];

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

Widget _app(TutorHarness h) {
  final content = _Content();
  final tree = ContentTree.fromCurricula({
    for (final c in CurriculumId.values) c: c == _m ? _items : const [],
  });
  return pumpApp(
    overrides: [
      ...learnerStateOverrides(
        scope: tutorFixtureScope(),
        commands: h.commands,
      ),
      ...tutoredOverrides(selection: h.selection, withScope: false),
      contentRepositoryProvider.overrideWithValue(content),
      contentTreeProvider.overrideWith((ref) async => tree),
      curriculumContentProvider.overrideWith(
        (ref, id) => content.getContentForCurriculum(id),
      ),
      anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
      localDayClockProvider.overrideWithValue(
        FakeLocalDayClock(tutorFixtureNow),
      ),
    ],
    child: const ContentHierarchyScreen(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _ticks => find.byType(Checkbox);

bool? _tick(WidgetTester tester, int row) =>
    tester.widget<Checkbox>(_ticks.at(row)).value;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Berachos 2:1–2:3 shows ticked only after the callable '
      'returns success', (tester) async {
    final pending = Completer<void>();
    final h = TutorHarness();
    addTearDown(h.dispose);
    h.invoker.respond = (call) async {
      await pending.future;
      return h.invoker.successFor(call);
    };

    await tester.pumpWidget(_app(h));
    await _settle(tester);
    expect(_ticks, findsNWidgets(2), reason: 'perakim 1 and 2');
    expect(_tick(tester, 1), isFalse);

    await tester.tap(_ticks.at(1));
    await _settle(tester);
    await tester.tap(find.text('Record 3'));
    await _settle(tester);

    // In flight: one callable, nothing derived or optimistic on screen.
    expect(h.invoker.calls.single.fn, 'tutorRecordLearning');
    expect(
      [
        for (final e in h.invoker.calls.single.args['events'] as List)
          ((e as Map)['fields'] as Map)['ref'],
      ],
      ['Berakhot 2:1', 'Berakhot 2:2', 'Berakhot 2:3'],
    );
    // (The tick boxes rest while a capture is in flight.)
    expect(
      tester.widgetList<Checkbox>(_ticks).where((c) => c.value != false),
      isEmpty,
      reason: 'no optimistic tick',
    );
    expect(find.text('3 recorded'), findsNothing);

    pending.complete();
    await _settle(tester);

    expect(_tick(tester, 1), isTrue);
    expect(find.text('3 recorded'), findsOneWidget);
  });

  testWidgets('a rejected call changes nothing on screen', (tester) async {
    final h = TutorHarness();
    addTearDown(h.dispose);
    h.invoker.respond = (_) => throw FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'Grant lacks can_edit_learning',
    );

    await tester.pumpWidget(_app(h));
    await _settle(tester);
    await tester.tap(_ticks.at(1));
    await _settle(tester);
    await tester.tap(find.text('Record 3'));
    await _settle(tester);

    expect(h.invoker.calls, hasLength(1));
    expect(_tick(tester, 1), isFalse);
    expect(find.text('3 recorded'), findsNothing);
  });
}
