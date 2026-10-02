// Story 2.7 (DNI-498) AC-9 and the dismissal / narrow-layout edge cases:
// rows announce their learnt tri-state and their selection separately,
// focus lands on the title on open, keyboard-only users reach search, the
// filter, tree rows, Reset changes and confirm, large text and Hebrew RTL
// lay out without overflow or footer overlap, and dark mode uses the dark
// tokens. Focus return to Add ground on close / Escape / back is in
// widgets/add_ground_entry_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double textScale = 1,
  Size size = phoneSize,
}) async {
  final world = GroundPickerWorld(
    corpus: mishnayosCorpus(),
    commands: FakeLearningCommands(),
    learnt: {...mishnayosCorpus().leavesUnder(berakhot1)},
    tracks: [
      fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
      fixtureTrack(
        rebbeId,
        'Rebbe',
        curriculumId: engineCurriculum,
        ground: const [peah],
      ),
    ],
  );
  addTearDown(world.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      locale: locale,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      child: Scaffold(
        body: SafeArea(
          child: GroundPickerPane(subTrackId: schoolId, onClose: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _box(String row) => find.descendant(
  of: find.ancestor(of: find.text(row), matching: find.byType(InkWell)).first,
  matching: find.byType(Checkbox),
);

void main() {
  testWidgets('rows announce progress and selection as separate states', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    // Zeraim: partly learnt (Berakhot 1), nothing picked.
    expect(
      find.bySemanticsLabel(RegExp('^Seder Zeraim, 2 Masechtos, Partial')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(_box('Seder Zeraim')),
      matchesSemantics(
        label: 'Not selected',
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.byTooltip('Expand Seder Zeraim'));
    await tester.pumpAndSettle();
    await tester.tap(_box('Mishnah Berakhot'));
    await tester.pumpAndSettle();
    // Zeraim is now partly picked: the checkbox is mixed and says so.
    expect(
      tester.getSemantics(_box('Seder Zeraim')),
      matchesSemantics(
        label: 'Partly selected',
        hasCheckedState: true,
        isCheckStateMixed: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('^Mishnah Berakhot, 2 Perakim, Partial')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('focus moves to the title on open', (tester) async {
    await _pump(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'groundPickerTitle');
  });

  testWidgets('keyboard only reaches search, filter, rows, reset and '
      'confirm', (tester) async {
    await _pump(tester);
    await tester.tap(_box('Seder Moed'));
    await tester.pumpAndSettle();
    final reached = <Type>{};
    for (var i = 0; i < 40; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) continue;
      for (final type in [
        TextField,
        FilterChip,
        Checkbox,
        TextButton,
        FilledButton,
      ]) {
        var hit = false;
        context.visitAncestorElements((e) {
          if (e.widget.runtimeType == type) hit = true;
          return !hit;
        });
        if (context.widget.runtimeType == type) hit = true;
        if (hit) reached.add(type);
      }
    }
    expect(
      reached,
      containsAll([TextField, FilterChip, Checkbox, TextButton, FilledButton]),
    );
  });

  for (final (label, locale) in [
    ('English', const Locale('en')),
    ('Hebrew RTL', const Locale('he')),
  ]) {
    testWidgets('$label at 2x text: no overflow, footer below the tree', (
      tester,
    ) async {
      await _pump(tester, locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
      final tree = tester.getRect(find.byType(ListView));
      final reset = tester.getRect(
        find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(reset.top, greaterThanOrEqualTo(tree.bottom - 0.5));
      expect(reset.bottom, lessThanOrEqualTo(phoneSize.height));
    });
  }

  testWidgets('Hebrew renders right to left with Hebrew copy', (tester) async {
    await _pump(tester, locale: const Locale('he'));
    expect(find.text('הוספת חומר לSchool'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(GroundPickerPane))),
      TextDirection.rtl,
    );
  });

  testWidgets('dark mode uses the dark tokens', (tester) async {
    await _pump(tester, theme: AppTheme.darkTheme());
    final note = tester.widget<Text>(
      find.text("They'll leave the home schedule while School holds them."),
    );
    final dark = AppPalette.of(tester.element(find.byType(GroundPickerPane)));
    expect(dark.brightness, Brightness.dark);
    expect(note.style?.color, dark.brandInkMuted);
    expect(note.style?.color, isNot(AppPalette.light.brandInkMuted));
  });
}
