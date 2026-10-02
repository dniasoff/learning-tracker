// Mirror test for
// `lib/domain/learner_state/ports/oversized_governed_write_port.dart`
// (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';

import '../../../helpers/learner_state_fixtures.dart';

void main() {
  test('a receipt defaults to a fresh, non-noop write', () {
    const receipt = GovernedWriteReceipt(actionId: ulidD, changeIds: [ulidD]);
    expect(receipt.replayed, isFalse);
    expect(receipt.noop, isFalse);
    expect(receipt.at, isNull);
  });

  test('entries compare by value', () {
    const change = GovernedEntityChange(
      entity: GovernedEntity.mainTrackProgram,
      entityId: 'mishnayos',
      docs: [
        GovernedDocPatch(
          collection: 'profile_programs',
          docId: 'mishnayos',
          fields: {'rate': 2},
        ),
      ],
    );
    expect(
      const OversizedGovernedEntry(entryId: ulidD, change: change),
      const OversizedGovernedEntry(entryId: ulidD, change: change),
    );
  });

  test('OnlineRequiredException is an Exception', () {
    expect(const OnlineRequiredException(), isA<Exception>());
  });
}
