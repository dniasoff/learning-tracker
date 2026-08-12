/// Story acceptance coverage for I-3 — items learned and lifetime view.
@Tags(['story_i3'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'I-3 — items learned',
    skip:
        'Blocked: the provider under test still reads Drift completion and '
        'prior-completion-import DAOs. Firestore completion/ledger fixtures '
        'cannot be connected without a production provider migration.',
    () {
      test('placeholder for the pending Firestore items-learned seam', () {});
    },
  );
}
