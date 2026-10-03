import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/academic_year_picker.dart';

import '../../../../helpers/pump_app.dart';

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

void main() {
  test('labels a year as "Y–YY"', () {
    expect(academicYearLabel(2026), '2026–27');
    expect(academicYearLabel(2099), '2099–00');
  });

  testWidgets('shows each state, selects free years, keeps Used disabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final picked = <int>[];
    await tester.pumpWidget(
      pumpApp(
        child: Scaffold(
          body: AcademicYearPicker(
            years: const [2025, 2026, 2027],
            states: const {
              2025: AcademicYearState.used,
              2026: AcademicYearState.active,
              2027: AcademicYearState.open,
            },
            selected: 2026,
            onSelected: picked.add,
            errorText: 'Pick one',
          ),
        ),
      ),
    );
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(_chip('2026–27')).selected, isTrue);

    await tester.tap(_chip('2027–28'));
    await tester.tap(_chip('2025–26'), warnIfMissed: false);
    expect(picked, [2027]);

    final used = tester.getSemantics(_chip('2025–26')).getSemanticsData();
    expect(used.flagsCollection.isEnabled, Tristate.isFalse);
    expect(
      find.ancestor(of: _chip('2025–26'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(tester.getSize(_chip('2025–26')).height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });
}
