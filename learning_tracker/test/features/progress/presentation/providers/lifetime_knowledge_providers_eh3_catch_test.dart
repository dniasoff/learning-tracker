/// AUD-progress-06 notes for the retired Drift-only track-dual path.
///
/// The former tests injected integer `trackId` rows, profile-program rows, and
/// curriculum-scope rows into Drift, then overrode a calendar provider keyed by
/// that integer. CurriculumId-keyed track providers do exist, but these
/// particular catch paths require the retired track-dual/calendar-scoped
/// integration: Drift profile-program/scope rows plus its integer `trackId`
/// partition. There is no honest Firestore seed for that missing integration
/// yet.
@Tags(['progress'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AUD-progress-06 retired integer-track catch paths', () {
    markTestSkipped(
      'Not portable to Phase 3 Firestore: the former coverage depends on '
      'Drift profile-program/scope rows and the retired integer trackId '
      'partition inside the track-dual/calendar-scoped integration. '
      'Production gap: that integration still needs to be wired to the '
      'existing CurriculumId-keyed track providers before this logging '
      'coverage can be restored.',
    );
  });
}
