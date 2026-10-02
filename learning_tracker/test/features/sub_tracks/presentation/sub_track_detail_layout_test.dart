// DNI-497 (Story 2.6) AC-8 and AC-5 RTL: the tablet list-detail split
// keeps the hub selection while the detail updates in place; dark tokens;
// tri-state announcements; mirrored handles and chevrons.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_actions.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_list_detail_layout.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../sub_track_detail_harness.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo<Object?> {}

/// A stand-in hub list: one row per sub-track, the selected one marked.
class _HubList extends ConsumerWidget {
  const _HubList(this.ids);

  final Map<String, String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(subTrackHubSelectionProvider);
    return Scaffold(
      body: ListView(
        children: [
          for (final MapEntry(key: id, value: name) in ids.entries)
            ListTile(
              key: ValueKey('hubRow:$id'),
              selected: id == selected,
              title: Text('Hub $name'),
              onTap: () => openSubTrackDetail(context, ref, id),
            ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  late DetailHarness h;
  late _MockStackRouter router;
  final school = detailSubTrack(10, 'School', const [berakhot, peah, shabbat]);
  final rebbe = detailSubTrack(20, 'Rebbe', const [shabbat]);

  setUp(() {
    h = DetailHarness()
      ..seed(
        subTracks: [school, rebbe],
        learnEvents: [
          engineLearn(1, 'Mishnah Berakhot 1:1', source: school.id),
          engineLearn(2, 'Mishnah Berakhot 2:1'),
          engineLearn(3, 'Mishnah Peah 1:1'),
          engineLearn(4, 'Mishnah Peah 1:2'),
        ],
      );
    router = _MockStackRouter();
    when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
  });
  tearDown(() => h.dispose());

  Future<void> pumpHub(
    WidgetTester tester, {
    required double width,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
  }) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      pumpApp(
        overrides: h.overrides(),
        locale: locale,
        theme: AppTheme.themeFor(brightness: brightness),
        child: StackRouterScope(
          controller: router,
          stateHash: 0,
          child: SubTrackListDetailLayout(
            list: _HubList({school.id: 'School', rebbe.id: 'Rebbe'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String id) =>
      tester.widget<ListTile>(find.byKey(ValueKey('hubRow:$id'))).selected;

  testWidgets('from 840dp the hub list and detail sit in two panes; the '
      'list keeps its selection and the detail updates in place', (
    tester,
  ) async {
    await pumpHub(tester, width: 1000);
    expect(find.byType(SubTrackDetailView), findsNothing);

    await tester.tap(find.byKey(ValueKey('hubRow:${school.id}')));
    await tester.pumpAndSettle();
    final pane = find.byKey(const ValueKey('subTrackSplitDetail'));
    expect(pane, findsOneWidget);
    expect(find.text('Hub School'), findsOneWidget, reason: 'list stays');
    expect(
      find.descendant(of: pane, matching: find.text('School')),
      findsOneWidget,
    );
    expect(isSelected(tester, school.id), isTrue);
    final paneLeft = tester.getTopLeft(pane).dx;
    expect(paneLeft, greaterThanOrEqualTo(subTrackSplitListWidth));

    await tester.tap(find.byKey(ValueKey('hubRow:${rebbe.id}')));
    await tester.pumpAndSettle();
    expect(pane, findsOneWidget, reason: 'the same pane, updated in place');
    expect(
      find.descendant(of: pane, matching: find.text('Rebbe')),
      findsOneWidget,
    );
    expect(isSelected(tester, rebbe.id), isTrue);
    expect(isSelected(tester, school.id), isFalse);
    verifyNever(() => router.push<Object?>(any()));
  });

  testWidgets('below 840dp a row tap pushes the detail route and there is '
      'no split', (tester) async {
    await pumpHub(tester, width: 600);
    await tester.tap(find.byKey(ValueKey('hubRow:${school.id}')));
    await tester.pumpAndSettle();
    verify(() => router.push<Object?>(any())).called(1);
    expect(find.byType(SubTrackDetailView), findsNothing);
  });

  testWidgets('dark mode applies the dark tokens to the detail', (
    tester,
  ) async {
    await pumpHub(tester, width: 1000, brightness: Brightness.dark);
    await tester.tap(find.byKey(ValueKey('hubRow:${school.id}')));
    await tester.pumpAndSettle();
    final row = find.byKey(
      const ValueKey('subTrackGroundRow:0:Mishnah Shabbat'),
    );
    final colors = tester.element(row).colors;
    expect(colors.brightness, Brightness.dark);
    final box = tester.widget<Container>(row).decoration! as BoxDecoration;
    expect(box.color, AppPalette.dark.brandCreamCard);
    expect(box.color, isNot(AppPalette.light.brandCreamCard));
    expect(box.border!.top.color, AppPalette.dark.brandOutline);
  });

  testWidgets('screen readers hear "complete", "partially learnt, {n} of '
      '{total}" and "not learnt"', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHub(tester, width: 1000);
    await tester.tap(find.byKey(ValueKey('hubRow:${school.id}')));
    await tester.pumpAndSettle();
    String label(String ref) => tester
        .getSemantics(find.byKey(ValueKey('subTrackTriState:$ref')))
        .label;
    expect(label('Mishnah Peah'), 'complete');
    expect(label('Mishnah Berakhot'), 'partially learnt, 2 of 5');
    expect(label('Mishnah Shabbat'), 'not learnt');
    semantics.dispose();
  });

  testWidgets('in Hebrew (RTL) the drag handle sits at the start (right) '
      'and the chevron mirrors', (tester) async {
    await pumpHub(tester, width: 1000, locale: const Locale('he'));
    await tester.tap(find.byKey(ValueKey('hubRow:${school.id}')));
    await tester.pumpAndSettle();
    final handle = tester.getCenter(
      find.byKey(const ValueKey('subTrackDragHandle:Mishnah Peah')),
    );
    final label = tester.getCenter(
      find.byKey(const ValueKey('subTrackGroundLabel:Mishnah Peah')),
    );
    final chevronFinder = find.byKey(
      const ValueKey('subTrackGroundChevron:Mishnah Peah'),
    );
    final chevron = tester.getCenter(chevronFinder);
    expect(handle.dx, greaterThan(label.dx), reason: 'start = right in RTL');
    expect(chevron.dx, lessThan(label.dx), reason: 'end = left in RTL');
    final icon = tester.widget<Icon>(chevronFinder);
    expect(icon.icon!.matchTextDirection, isTrue);
    expect(Directionality.of(tester.element(chevronFinder)), TextDirection.rtl);
    expect(find.text('חומר (לפי הסדר)'), findsOneWidget);
  });
}
