/// Regression coverage retained for the blocked per-track progress provider.
///
/// The old tests depended on Drift's integer `trackId` and the deleted
/// `trackDualProgressMetricsProvider` implementation. The Firestore migration
/// deliberately blocks that provider until active-track/program aggregation is
/// redesigned around [CurriculumId] (AD-25). Keeping the cases here makes the
/// missing production capability visible without fabricating an id or reducing
/// the assertions to a misleading existence check.
@Tags(['progress', 'migration-gap'])
library;

import 'package:flutter_test/flutter_test.dart';

const _gap =
    'production gap: trackDualProgressMetricsProvider is intentionally blocked; '
    'its old int trackId/active-track contract has no Firestore equivalent yet '
    '(AD-25). Re-enable these behavioral cases when CurriculumId-keyed '
    'active-track/program providers exist.';

void main() {
  group('trackDualProgressMetricsProvider — lifetime-only imports', () {
    test(
      'a lifetime-only scope mark covering the whole track content raises '
      'lifetimePercentage to 100% while currentCyclePercentage stays 0%',
      () {},
      skip: _gap,
    );

    test(
      'a lifetime-only import for a different curriculum does not leak into '
      'this track\'s lifetimePercentage',
      () {},
      skip: _gap,
    );
  });

  group('run-10 acceptance sweep — deleted tracks are excluded', () {
    test(
      'a deleted track is excluded from trackDualProgressMetricsProvider',
      () {},
      skip: _gap,
    );
  });
}
