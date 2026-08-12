/// Regression coverage retained for the blocked per-track progress provider.
///
/// The old implementation partitioned Drift rows by integer `trackId`.
/// [CurriculumId] is now the only valid track identity (AD-25), and the
/// production provider explicitly reports that its active-track/program
/// replacement is not wired. These tests stay visible as precise skips.
@Tags(['progress', 'migration-gap'])
library;

import 'package:flutter_test/flutter_test.dart';

const _gap =
    'production gap: trackDualProgressMetricsProvider is intentionally blocked; '
    'its old int trackId/active-track contract has no Firestore equivalent yet '
    '(AD-25).';

void main() {
  group('trackDualProgressMetricsProvider — reactivity', () {
    test(
      'current-cycle percentage reflects a new completion after a commit tick',
      () {},
      skip: _gap,
    );

    test(
      'lifetime percentage reflects a new completion after a commit tick',
      () {},
      skip: _gap,
    );
  });
}
