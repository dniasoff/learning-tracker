// DNI-507 (Story 3.4) T6, AC-8: the Adjust panel for screen-reader and
// large-text users — rows announce their ref and included / skipped
// state, sections announce their day, Record carries the live count,
// targets are at least 48dp, Hebrew marks never clip at large text, the
// layout mirrors in RTL, focus moves into the picker and back to its
// Up to… trigger, platform back records nothing, the tablet picker is a
// centred dialog, and dark mode uses the screen #10 dark tokens.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state/catch_up_adjust_rig.dart';
import '../../../../helpers/learner_state/catch_up_card_harness.dart';

const _main = LearningEvent.sourceMain;

/// The UpToActionButton's TextButton inside [source]'s group.
Finder _upToButton(String source) =>
    find.descendant(of: adjustUpTo(source), matching: find.byType(TextButton));

Future<void> _openUpTo(WidgetTester tester, String source) async {
  await tester.ensureVisible(_upToButton(source));
  await tester.tap(_upToButton(source));
  await tester.pumpAndSettle();
}

/// A Hebrew leaf label with nikud and cantillation-height marks.
String _hebrewLabel(String leaf) {
  final m = RegExp(r'(\d+):(\d+)$').firstMatch(leaf)!;
  return 'בֵּיצָה ${m[1]}:${m[2]} — מִשְׁנָה שְׁלֵמָה בְּעִיּוּן';
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('semantics', () {
    testWidgets('rows announce ref and state, sections their day, Record '
        'its live count', (tester) async {
      final semantics = tester.ensureSemantics();
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      expect(
        tester.getSemantics(adjustButton),
        isSemantics(label: 'Adjust…', isButton: true, isExpanded: false),
      );
      await openAdjust(tester);
      expect(
        tester.getSemantics(adjustButton),
        isSemantics(label: 'Adjust…', isButton: true, isExpanded: true),
      );
      final row = adjustRow(rigRebbe, rigLeaf(3, 1));
      expect(
        tester.getSemantics(row),
        isSemantics(
          label: 'Beitzah 3:1, included',
          isButton: true,
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Shabbos$')), findsWidgets);
      final dayHeader = tester.getSemantics(
        find.byKey(const ValueKey('catchUpAdjustDayTitle-$catchUpShabbos')),
      );
      expect(dayHeader.label, 'Shabbos');
      expect(dayHeader.flagsCollection.isHeader, isTrue);
      expect(
        tester.getSemantics(adjustRecord).label,
        contains('Record 14 mishnayos'),
      );
      // A screen-reader activation unticks the row.
      tester.semantics.tap(find.semantics.byLabel('Beitzah 3:1, included'));
      await settleAdjust(tester);
      expect(
        tester.getSemantics(row),
        isSemantics(label: 'Beitzah 3:1, skipped', isChecked: false),
      );
      expect(
        tester.getSemantics(adjustRecord).label,
        contains('Record 13 mishnayos'),
      );
      expect(
        tester.getSemantics(_upToButton(rigRebbe)).label,
        'Record up to, Rebbe (learns on shabbos)',
      );
      semantics.dispose();
      await unmountAdjust(tester);
    });

    testWidgets('every target is at least 48dp', (tester) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      for (final f in [
        adjustButton,
        adjustRecord,
        adjustCancel,
        _upToButton(_main),
        _upToButton(rigRebbe),
        adjustRow(_main, rigLeaf(2, 7)),
        adjustRow(rigRebbe, rigLeaf(3, 10)),
      ]) {
        final size = tester.getSize(f);
        expect(size.height, greaterThanOrEqualTo(48), reason: '$f');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$f');
      }
      await unmountAdjust(tester);
    });
  });

  group('focus and dismissal', () {
    testWidgets('focus enters the picker title and returns to Up to…; '
        'platform back records nothing', (tester) async {
      final rig = AdjustRig();
      await pumpAdjustCard(tester, rig.overrides());
      await openAdjust(tester);
      await _openUpTo(tester, rigRebbe);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'upToPickerTitle');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upToPickerSheet')), findsNothing);
      final trigger = tester.widget<TextButton>(_upToButton(rigRebbe));
      expect(trigger.focusNode!.hasPrimaryFocus, isTrue);
      expect(rig.recorded, isEmpty);
      expect(adjustPanel, findsOneWidget);
      await unmountAdjust(tester);
    });
  });

  group('tablet', () {
    testWidgets('the picker is a centred dialog; the card lays out', (
      tester,
    ) async {
      final rig = AdjustRig();
      const size = Size(1024, 1366);
      await pumpAdjustCard(tester, rig.overrides(), size: size);
      await openAdjust(tester);
      expect(tester.takeException(), isNull);
      await _openUpTo(tester, rigRebbe);
      final dialog = find.byKey(const Key('upToPickerDialog'));
      expect(dialog, findsOneWidget);
      expect(find.byKey(const Key('upToPickerSheet')), findsNothing);
      final rect = tester.getRect(
        find
            .descendant(of: dialog, matching: find.byType(ConstrainedBox))
            .first,
      );
      expect(rect.width, lessThanOrEqualTo(480));
      expect(rect.center.dx, closeTo(size.width / 2, 1));
      await tester.tap(find.byKey(const Key('upToCancel')));
      await tester.pumpAndSettle();
      expect(rig.recorded, isEmpty);
      await unmountAdjust(tester);
    });
  });

  group('Hebrew, RTL and large text', () {
    testWidgets('rows mirror and Hebrew marks never clip at 2x text', (
      tester,
    ) async {
      final rig = AdjustRig();
      await pumpAdjustCard(
        tester,
        rig.overrides(hebrewTerms: true, labelOf: _hebrewLabel),
        locale: const Locale('he'),
        textScale: 2,
        size: const Size(360, 4000),
      );
      await openAdjust(tester);
      expect(tester.takeException(), isNull);
      final row = adjustRow(rigRebbe, rigLeaf(3, 1));
      await tester.ensureVisible(row);
      expect(Directionality.of(tester.element(row)), TextDirection.rtl);
      final tick = find.descendant(of: row, matching: find.byType(Checkbox));
      final label = find.descendant(
        of: row,
        matching: find.text(_hebrewLabel(rigLeaf(3, 1))),
      );
      // RTL: the tick sits at the start (right), the label after it.
      expect(
        tester.getCenter(tick).dx,
        greaterThan(tester.getCenter(label).dx),
      );
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.maxLines, isNull);
      expect(paragraph.overflow, TextOverflow.clip);
      // The row grows with its text instead of clipping it.
      expect(
        tester.getSize(row).height,
        greaterThanOrEqualTo(tester.getSize(label).height),
      );
      await unmountAdjust(tester);
    });
  });

  group('dark mode', () {
    testWidgets('the panel uses the #10 dark tokens', (tester) async {
      final rig = AdjustRig();
      await pumpAdjustCard(
        tester,
        rig.overrides(),
        theme: AppTheme.themeFor(brightness: Brightness.dark),
      );
      await openAdjust(tester);
      final decoration =
          tester.widget<Container>(adjustPanel).decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF151A26));
      expect((decoration.border! as Border).top.color, const Color(0xFF263041));
      final label = tester.widget<Text>(
        find.descendant(
          of: adjustRow(rigRebbe, rigLeaf(3, 1)),
          matching: find.text('Beitzah 3:1'),
        ),
      );
      expect(label.style!.color, const Color(0xFFEAEEF5));
      final record = tester.widget<ButtonStyleButton>(adjustRecord);
      expect(
        record.style!.backgroundColor!.resolve(<WidgetState>{}),
        const Color(0xFF7CA0FF),
      );
      expect(tester.takeException(), isNull);
      await unmountAdjust(tester);
    });
  });
}
