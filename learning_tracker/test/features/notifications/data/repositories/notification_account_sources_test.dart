import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    as ring;
import 'package:learning_tracker/features/notifications/data/repositories/notification_account_sources.dart';

void main() {
  test('re-exports the account path UID provider from the data ring', () {
    expect(
      identical(ownAccountPathUidProvider, ring.ownAccountPathUidProvider),
      isTrue,
    );
  });
}
