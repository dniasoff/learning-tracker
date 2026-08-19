import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/bootstrap/bootstrap.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

void main() {
  test(
    'does not seed a locally restored account without a Firebase session',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      seedRestoredActiveAccount(
        container: container,
        accountId: 'restored-without-session',
        authenticatedUserId: null,
        restoredFirebaseUid: 'restored-without-session',
      );

      expect(container.read(activeAccountIdProvider), isNull);
      expect(
        await container.read(activeAccountFirebaseProvider.future),
        isNull,
      );
      expect(container.read(activeAccountFirebaseProvider).hasError, isFalse);
    },
  );

  test(
    'does not seed a restored account when Firebase belongs to another account',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      seedRestoredActiveAccount(
        container: container,
        accountId: 'account-x',
        authenticatedUserId: 'firebase-user-y',
        restoredFirebaseUid: 'firebase-user-x',
      );

      expect(container.read(activeAccountIdProvider), isNull);
      expect(
        await container.read(activeAccountFirebaseProvider.future),
        isNull,
      );
      expect(container.read(activeAccountFirebaseProvider).hasError, isFalse);
    },
  );
}
