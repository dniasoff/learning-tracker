// Mirror test for `lib/domain/learner_state/civil_date.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/c0_stub_matcher.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('CivilDate is the YYYY-MM-DD string isCivilDate validates', () {
    bool valid(CivilDate day) => isCivilDate(day);
    expect(valid('2026-09-01'), isTrue);
    expect(valid('2026-9-1'), isFalse);
  });

  test('civilDate is a C0 stub owned by DNI-466', () {
    final history = c0SettingsHistory();
    expect(() => civilDate(t0, history), throwsC0Stub('DNI-466', 'civilDate'));
  });
}
