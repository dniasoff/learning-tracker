/// Regression coverage retained for the blocked per-track progress provider.
///
/// These cases require active-track/program aggregation and the historical
/// integer `trackId` partition. Firestore has no such identity; CurriculumId
/// is the sole track identity (AD-25). The cases therefore remain explicit
/// skips until production exposes a CurriculumId-keyed replacement.
@Tags(['progress', 'migration-gap'])
library;

import 'package:flutter_test/flutter_test.dart';

const _gap =
    'production gap: trackDualProgressMetricsProvider is intentionally blocked; '
    'the old int trackId batching contract has no Firestore equivalent yet '
    '(AD-25).';

void main() {
  group('AUD-progress-03 — trackDualProgressMetricsProvider batching', () {
    test(
      'resolving three active tracks builds each batched provider once',
      () {},
      skip: _gap,
    );

    test(
      'after a completion tick, the batched providers rebuild once more and '
      'lifetimePercentage reflects the new completion',
      () {},
      skip: _gap,
    );
  });
}
