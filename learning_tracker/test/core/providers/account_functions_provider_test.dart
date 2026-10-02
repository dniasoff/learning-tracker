// DNI-520 — the core-layer entry point for account-scoped Cloud Functions is
// a re-export of the data-ring provider: features depend on core, and both
// names resolve to the same active-account resolver.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart'
    show NotAuthenticatedException;
import 'package:learning_tracker/core/providers/account_functions_provider.dart'
    as core;
import 'package:learning_tracker/data/firestore/account_functions.dart' as data;
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

void main() {
  test('re-exports the same provider as the data ring', () {
    expect(
      identical(core.accountFunctionsProvider, data.accountFunctionsProvider),
      isTrue,
    );
  });

  test('resolves through the active account (signed out -> '
      'NotAuthenticatedException)', () async {
    final container = ProviderContainer(
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    final resolve = container.read(core.accountFunctionsProvider);

    await expectLater(resolve(), throwsA(isA<NotAuthenticatedException>()));
  });
}
