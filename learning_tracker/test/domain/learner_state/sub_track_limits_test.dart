/// Story 2.1 (DNI-492) AC-3 / AC-4: the shared AD-45 fixture suite
/// (`test/fixtures/sub_track_limits/*.json`) through the Dart validator.
/// `functions/test/sub_track_limits.test.mjs` runs the same files through
/// the TypeScript validator; both must agree on every case.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';

import '../../helpers/sub_track_limit_fixtures.dart';

void main() {
  final cases = loadSubTrackLimitCases();

  test('the fixture suite covers every shared wire code', () {
    expect(cases.length, greaterThanOrEqualTo(40));
    final expected = {
      for (final c in cases) ...(c.json['expect']! as List<Object?>),
    };
    expect(expected, {
      for (final l in SubTrackLimit.values)
        // Cross-curriculum ground needs the ContentIndex corpus: Dart only
        // (sub_track_validation_test.dart).
        if (l != SubTrackLimit.crossCurriculumGround) l.code,
    });
  });

  for (final c in cases) {
    test('${c.file}: ${c.json['name']}', () {
      expect(runSubTrackLimitCase(c), c.json['expect']);
    });
  }
}
