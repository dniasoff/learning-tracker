// Mirror test for
// `lib/features/settings/domain/services/backup_learning_port.dart`
// (DNI-482): the backup service reaches the learning record only through
// this port.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/domain/services/backup_learning_port.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';

void main() {
  test('the production port implements the interface the service takes', () {
    final BackupLearningPort port = firestoreBackupLearningPort(
      FakeFirebaseFirestore(),
    );
    expect(port, isA<BackupLearningPort>());
  });
}
