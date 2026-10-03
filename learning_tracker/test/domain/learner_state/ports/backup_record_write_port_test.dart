// Mirror test for
// `lib/domain/learner_state/ports/backup_record_write_port.dart`
// (DNI-482: the AD-49 replay's non-event records).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';

void main() {
  test('an event points entry is recognised by its pts_ id or event_id', () {
    expect(isEventPointsEntry('pts_X', const {}), isTrue);
    expect(isEventPointsEntry('01ARZ', const {'event_id': 'E'}), isTrue);
    expect(isEventPointsEntry('01ARZ', const {'delta': -5}), isFalse);
  });

  test('a points write may not carry an event entry; a redemption may '
      'carry any fields', () {
    expect(
      () => BackupRecordWrite(
        collection: BackupRecordCollection.pointsLedger,
        docId: 'pts_E',
        fields: const {'delta': 1},
      ),
      throwsArgumentError,
    );
    expect(
      () => BackupRecordWrite(
        collection: BackupRecordCollection.pointsLedger,
        docId: 'A',
        fields: const {'event_id': 'E'},
      ),
      throwsArgumentError,
    );
    final write = BackupRecordWrite(
      collection: BackupRecordCollection.rewardRedemptions,
      docId: 'R',
      fields: {
        'status': 'pending_fulfilment',
        'nested': {'a': 1},
      },
    );
    expect(write.collection.name, 'reward_redemptions');
    expect(() => (write.fields['nested']! as Map)['b'] = 2, throwsA(anything));
  });

  test('a doc id must be a single path segment', () {
    for (final id in ['', 'a/b']) {
      expect(
        () => BackupRecordWrite(
          collection: BackupRecordCollection.pointsLedger,
          docId: id,
          fields: const {},
        ),
        throwsArgumentError,
      );
    }
  });

  test('the AD-54 write budget is 450', () {
    expect(BackupRecordWritePort.maxWrites, 450);
  });
}
