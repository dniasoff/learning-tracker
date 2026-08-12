/// T-49 activation-heal race coverage.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'T-49: a late profile activation heal cannot clobber a newer selection',
    () {},
    skip:
        'Intentionally retired contract: Firestore is now the sole profile '
        'store, so selecting an existing profile no longer performs the old '
        'Drift-to-Firestore activation heal. AutoSelectedProfileId still '
        'handles cold-start selection and stale-id recovery, but it does not '
        'write a second copy of an existing profile document. Therefore the '
        'former delayed ensureRemoteProfile race has no live Firestore path.',
  );
}
