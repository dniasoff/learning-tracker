/// Tier-3 record for the retired Drift-only study-day track-id fallback.
@Tags(['scheduler', 'study_day', 'studyday_companion_10'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retired Drift track-id fallback has no Firestore equivalent',
    () {},
    skip:
        'AD-25 removed int trackId and the Firestore study-day adapter is keyed only by CurriculumId; possible production gap only if a legacy caller still depends on the retired FK guard.',
  );
}
