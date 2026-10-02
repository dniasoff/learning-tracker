// DNI-496 (Story 2.5) AC-1 / AC-2: the weeks prefill of the ongoing form.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_state.dart';

void main() {
  group('AC-1: defaults', () {
    test('a new form opens with the switch off and 52 weeks prefilled', () {
      const s = OngoingWeeksPrefill.initial();
      expect(s.notLearningBeinHazmanim, isFalse);
      expect(s.weeksText, '52');
      expect(s.weeksEditedByUser, isFalse);
      expect(s.showsPrefillHelper, isTrue);
    });

    test('the prefill constants are 52 and 44', () {
      expect(kOngoingWeeksPerYearDefault, 52);
      expect(kOngoingWeeksPerYearBeinHazmanim, 44);
    });
  });

  group('AC-2: the switch changes only an untouched weeks value', () {
    test('untouched 52 becomes 44 and back', () {
      const s = OngoingWeeksPrefill.initial();
      final on = s.toggleBeinHazmanim(on: true);
      expect(on.weeksText, '44');
      expect(on.notLearningBeinHazmanim, isTrue);
      expect(on.showsPrefillHelper, isTrue);
      final off = on.toggleBeinHazmanim(on: false);
      expect(off.weeksText, '52');
      expect(off, const OngoingWeeksPrefill.initial());
    });

    test('a typed value survives every later toggle', () {
      final typed = const OngoingWeeksPrefill.initial().editWeeks('47');
      expect(typed.showsPrefillHelper, isFalse);
      final on = typed.toggleBeinHazmanim(on: true);
      expect(on.weeksText, '47');
      expect(on.toggleBeinHazmanim(on: false).weeksText, '47');
    });

    test('typing the prefill value itself still counts as an edit', () {
      final typed = const OngoingWeeksPrefill.initial().editWeeks('52');
      expect(typed.toggleBeinHazmanim(on: true).weeksText, '52');
    });

    test('a cleared field stays cleared when the switch toggles', () {
      final cleared = const OngoingWeeksPrefill.initial()
          .toggleBeinHazmanim(on: true)
          .editWeeks('');
      expect(cleared.toggleBeinHazmanim(on: false).weeksText, '');
    });
  });

  group('edit form of a stored sub-track', () {
    test('opens with the stored weeks, switch off, counted as edited', () {
      final s = OngoingWeeksPrefill.forStored(44);
      expect(s.weeksText, '44');
      expect(s.notLearningBeinHazmanim, isFalse);
      expect(s.weeksEditedByUser, isTrue);
      expect(s.toggleBeinHazmanim(on: true).weeksText, '44');
    });

    test('a fractional stored value keeps its fraction', () {
      expect(OngoingWeeksPrefill.forStored(40.5).weeksText, '40.5');
    });
  });

  test('formatOngoingNumber drops a whole number\'s ".0"', () {
    expect(formatOngoingNumber(7), '7');
    expect(formatOngoingNumber(2.5), '2.5');
  });
}
