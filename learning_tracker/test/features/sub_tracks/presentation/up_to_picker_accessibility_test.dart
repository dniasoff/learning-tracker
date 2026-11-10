// Story 2.10 (DNI-501) AC-8 widget: semantics, dark theme, RTL, large text
// and tablet for the Up to… picker.
@Tags(['a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../helpers/up_to_fixtures.dart';

const _path = [
  'Mishnah Berakhot 1:3',
  'Mishnah Berakhot 1:4',
  'Mishnah Berakhot 1:5',
  'Mishnah Berakhot 2:1',
  'Mishnah Berakhot 2:2',
];

Future<void> _open(
  WidgetTester tester, {
  Size size = phoneSize,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  useSurface(tester, size);
  await tester.pumpWidget(
    pumpApp(
      locale: locale,
      theme: AppTheme.themeFor(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      overrides: upToOverrides(
        state: fixtureLearnerState(
          subTracks: {
            schoolId: fixtureSubTrackState(
              schoolId,
              path: _path,
              recordedAhead: {'Mishnah Berakhot 1:5'},
            ),
          },
        ),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: UpToActionButton(
              key: const Key('trigger'),
              semanticsLabel: 'Record up to, School',
              onOpen: () => showUpToPicker(
                context,
                request: SubTrackUpToRequest(
                  subTrackId: schoolId,
                  curriculumId: engineCurriculum,
                  name: 'School',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('trigger')));
  await tester.pumpAndSettle();
}

SemanticsNode _row(WidgetTester tester, int i) =>
    tester.getSemantics(find.byKey(Key('upToRow-$i')));

void main() {
  testWidgets('each row announces its independent selection state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(_row(tester, 0).label, 'Berakhot 1:3, next up');
    expect(_row(tester, 2).label, 'Berakhot 1:5, already recorded');
    expect(_row(tester, 2), isSemantics(isEnabled: false));
    await tester.tap(find.text('Berakhot 2:2'));
    await tester.pump();
    expect(_row(tester, 0).label, 'Berakhot 1:3, next up');
    expect(_row(tester, 3).label, 'Berakhot 2:1, not selected');
    expect(_row(tester, 4).label, 'Berakhot 2:2, included, selected');
    expect(_row(tester, 4), isSemantics(isSelected: true));
    expect(_row(tester, 3), isNot(isSemantics(isSelected: true)));
    handle.dispose();
  });

  testWidgets('screen-reader activation toggles one row and the custom '
      'action explicitly fills a range', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    void act(int i, SemanticsAction action, [Object? args]) {
      final node = _row(tester, i);
      node.owner!.performAction(node.id, action, args);
    }

    // Activating a later row selects only that row.
    act(4, SemanticsAction.tap);
    await tester.pump();
    expect(_row(tester, 0).label, 'Berakhot 1:3, next up');
    expect(_row(tester, 4).label, 'Berakhot 2:2, included, selected');
    expect(find.bySemanticsLabel(RegExp('Record 1 mishna')), findsOneWidget);

    // The explicit action fills through the selected row, skipping recorded.
    const bulk = CustomSemanticsAction(label: 'Tick all up to here');
    expect(_row(tester, 4), isSemantics(customActions: [bulk]));
    act(
      4,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(bulk),
    );
    await tester.pump();
    expect(_row(tester, 0).label, 'Berakhot 1:3, included');
    expect(find.bySemanticsLabel(RegExp('Record 4 mishnayos')), findsOneWidget);

    // Activating an included row unticks only it.
    act(3, SemanticsAction.tap);
    await tester.pump();
    expect(_row(tester, 3).label, 'Berakhot 2:1, unticked, selected');
    expect(_row(tester, 3), isSemantics(isChecked: false));
    expect(find.bySemanticsLabel(RegExp('Record 3 mishnayos')), findsOneWidget);

    // Activating it again re-ticks just that row.
    act(3, SemanticsAction.tap);
    await tester.pump();
    expect(_row(tester, 3).label, 'Berakhot 2:1, included, selected');
    expect(_row(tester, 3), isSemantics(isChecked: true));
    expect(find.bySemanticsLabel(RegExp('Record 4 mishnayos')), findsOneWidget);

    // A second explicit bulk action leaves the already selected later row.
    act(
      1,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(bulk),
    );
    await tester.pump();
    expect(_row(tester, 1).label, 'Berakhot 1:4, included, selected');
    expect(_row(tester, 4).label, 'Berakhot 2:2, included');
    expect(find.bySemanticsLabel(RegExp('Record 4 mishnayos')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the confirm label carries the live count', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    await tester.tap(find.text('Berakhot 2:2'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Record 1 mishna')), findsOneWidget);
    await tester.tap(find.byKey(const Key('upToRowTick-0')));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Record 2 mishnayos')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the title is a heading and the trigger and rows are at least '
      '48dp', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('upToPickerTitle'))),
      isSemantics(isHeader: true),
    );
    for (var i = 0; i < _path.length; i++) {
      expect(
        tester.getSize(find.byKey(Key('upToRow-$i'))).height,
        greaterThanOrEqualTo(48),
      );
    }
    await tester.tap(find.byKey(const Key('upToCancel')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('trigger'))).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });

  testWidgets('dark theme: the sheet follows the dark surface', (tester) async {
    await _open(tester, brightness: Brightness.dark);
    final theme = AppTheme.themeFor(brightness: Brightness.dark);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Material),
          )
          .first,
    );
    final sheetColor = material.color ?? theme.bottomSheetTheme.backgroundColor;
    expect(
      sheetColor == null ||
          ThemeData.estimateBrightnessForColor(sheetColor) == Brightness.dark,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hebrew RTL at maximum text scale on phone and tablet does '
      'not clip', (tester) async {
    for (final size in [phoneSize, tabletSize]) {
      await _open(tester, size: size, locale: const Locale('he'), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(UpToPicker))),
        TextDirection.rtl,
      );
      expect(find.textContaining('מה למדת'), findsOneWidget);
      expect(find.textContaining('לחיצה ממושכת'), findsOneWidget);
      await tester.tap(find.byKey(const Key('upToRowTick-0')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('upToCancel')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('tablet dialog stays within 480px in dark mode', (tester) async {
    await _open(tester, size: tabletSize, brightness: Brightness.dark);
    expect(
      tester.getSize(find.byType(UpToPicker)).width,
      lessThanOrEqualTo(upToDialogMaxWidth),
    );
  });
}
