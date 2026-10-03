// Story 2.7 (DNI-498) AC-6 on the main-track browse view (UX-DR-63,
// UX-DR-93): ground a `holdsGround` sub-track holds stays listed, is greyed
// when wholly held, and carries the holder's name as a tag; partly held
// ground is tagged but not greyed; unheld ground — including leaves
// returned when a holder ends — renders normally. The engine side (not
// scheduled, returned on end, overlap kept) is in
// test/domain/learner_state/ground_holds_main_track_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/content_hierarchy_screen.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/held_ground_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
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

final _items = [
  _c('Zeraim', 0, ['Zeraim']),
  _c('Berakhot', 1, ['Zeraim', 'Berakhot']),
  _c('Berakhot 1', 2, ['Zeraim', 'Berakhot', '1']),
  _c('Berakhot 1:1', 3, ['Zeraim', 'Berakhot', '1', '1'], leaf: true),
  _c('Berakhot 1:2', 4, ['Zeraim', 'Berakhot', '1', '2'], leaf: true),
  _c('Berakhot 2', 5, ['Zeraim', 'Berakhot', '2']),
  _c('Berakhot 2:1', 6, ['Zeraim', 'Berakhot', '2', '1'], leaf: true),
  _c('Berakhot 2:2', 7, ['Zeraim', 'Berakhot', '2', '2'], leaf: true),
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

Future<void> _pump(WidgetTester tester, Map<String, List<String>> held) async {
  final content = _Content();
  final tree = ContentTree.fromCurricula({
    for (final c in CurriculumId.values) c: c == _m ? _items : const [],
  });
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...learnerStateOverrides(
          scope: c0Scope(),
          commands: FakeLearningCommands(),
        ),
        contentRepositoryProvider.overrideWithValue(content),
        contentTreeProvider.overrideWith((ref) async => tree),
        curriculumContentProvider.overrideWith(
          (ref, id) => content.getContentForCurriculum(id),
        ),
        anyActiveTrackHasChazaraProvider.overrideWith((ref) async => false),
        mainTrackHeldGroundProvider.overrideWith((ref, _) => AsyncData(held)),
      ],
      child: const ContentHierarchyScreen(
        curriculumId: 'mishnayos',
        level1: 'Zeraim',
        level2: 'Berakhot',
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _tileOf(String ref) => find.byWidgetPredicate(
  (w) => w is ContentItemTile && w.item.sefariaRef == ref,
);

ContentItemTile _tile(WidgetTester tester, String ref) =>
    tester.widget(_tileOf(ref));

Finder _greyed(String ref) => find.descendant(
  of: _tileOf(ref),
  matching: find.byKey(const ValueKey('heldGroundGreyed')),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('wholly held ground stays visible, greyed and tagged with its '
      'holder; partly held ground is tagged only', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, {
      'Berakhot 2:1': ['School'],
      'Berakhot 2:2': ['School'],
      'Berakhot 1:1': ['Rebbe'],
    });
    // Both perakim stay listed.
    expect(_tile(tester, 'Berakhot 1').heldBy, ['Rebbe']);
    expect(_tile(tester, 'Berakhot 1').heldWhole, isFalse);
    expect(_tile(tester, 'Berakhot 2').heldBy, ['School']);
    expect(_tile(tester, 'Berakhot 2').heldWhole, isTrue);
    expect(_greyed('Berakhot 2'), findsOneWidget);
    expect(_greyed('Berakhot 1'), findsNothing);
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Rebbe'), findsOneWidget);
    // A screen reader hears why the greyed row is not scheduled.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.hint == 'Held by School. Not on the home schedule.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('after the holder ends nothing is held: rows render normally', (
    tester,
  ) async {
    await _pump(tester, const {});
    expect(_tile(tester, 'Berakhot 2').heldBy, isEmpty);
    expect(_greyed('Berakhot 2'), findsNothing);
    expect(find.text('School'), findsNothing);
  });
}
