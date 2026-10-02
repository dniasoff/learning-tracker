// DNI-520 AC-1 — callable Cloud Functions run on the ACTIVE account's named
// app (`FirebaseFunctions.instanceFor(app: handles.app)`), never the default
// app. With no authenticated active account there is no app to call from.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart'
    show NotAuthenticatedException;
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_functions.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

void main() {
  test('no active account -> NotAuthenticatedException (no default-app '
      'fallback)', () async {
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    final resolve = container.read(accountFunctionsProvider);

    await expectLater(resolve(), throwsA(isA<NotAuthenticatedException>()));
  });

  test('an unauthenticated active account surfaces its resolution error '
      'instead of calling functions on another app', () async {
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => throw const AccountNotAuthenticatedException('acc-1'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final resolve = container.read(accountFunctionsProvider);

    await expectLater(
      resolve(),
      throwsA(isA<AccountNotAuthenticatedException>()),
    );
  });
}
