/// T-40 activation-heal wiring coverage.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'T-40: cold-start profile selection creates a missing remote document',
    () {},
    skip:
        'Intentionally retired contract: the former test modeled a local '
        'Drift profile whose Firestore document was missing. Firestore is now '
        'the sole profile store, so ProfileGuard/SelectedProfileId.select() '
        'does not need to heal a second remote copy. The live '
        'AutoSelectedProfileId.ensureSelected() path still cold-starts from '
        'Firestore and creates a default profile only when the account has '
        'none; it cannot reproduce the old local-row/missing-remote case.',
  );
}
