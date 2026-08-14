// Firestore account persistence tests replacing the archived UserProfileService
// and its Drift UserDatabase test double.
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:test/test.dart';

import '../../../../helpers/firestore_fake.dart';

void main() {
  const uid = 'uid-123';
  late FirestoreAccountRepository repository;

  setUp(() {
    repository = FirestoreAccountRepository(
      firestore: createFakeFirestore(authenticatedUid: uid),
      uid: uid,
    );
  });

  group('Firestore account repository', () {
    test('createAccount persists the display name to Firestore', () async {
      await repository.createAccount(
        displayName: 'Alice',
        email: 'alice@example.com',
      );

      final account = await repository.getAccount();
      expect(account, isNotNull);
      expect(account!.displayName, 'Alice');
      expect(account.email, 'alice@example.com');
    });

    test('updateAccount writes the account document to Firestore', () async {
      final account = await repository.createAccount(
        displayName: 'Test User',
      );

      final updated = await repository.updateAccount(
        account: account,
        displayName: 'Bob',
      );

      expect(updated.displayName, 'Bob');
      final snapshot = await repository.getAccount();
      expect(snapshot!.displayName, 'Bob');
      // userMode is intentionally absent: learner mode belongs to profiles.
      expect(await repository.getProfileSnapshot(), isNull);
    });

    test('updateAccount updates the existing account entry', () async {
      final account = await repository.createAccount(
        displayName: 'First Name',
      );

      await repository.updateAccount(
        account: account,
        displayName: 'Updated Name',
      );

      final snapshot = await repository.getAccount();
      expect(snapshot!.displayName, 'Updated Name');
    });
  });
}
