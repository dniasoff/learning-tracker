import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/account_firebase_registry_provider.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart'
    as account_firebase_providers;

/// This file exists purely to re-export `accountFirebaseRegistryProvider`
/// for `lib/features/**` call sites, which cannot import
/// `package:learning_tracker/data/firestore/...` directly (audit check 102,
/// AD-23/AD-28) — see its library doc comment.
///
/// The only behavior worth asserting is that the export IS the same
/// top-level provider instance declared in `account_firebase_providers.dart`,
/// not a copy. A mismatch would silently split "the account-Firebase
/// registry" into two disconnected instances: sign-in/signup call sites
/// would establish sessions on one registry while every repository resolved
/// through the other, so every Firestore read would see
/// AccountNotAuthenticatedException regardless of a successful sign-in.
void main() {
  test('accountFirebaseRegistryProvider re-exports the same provider '
      'instance as account_firebase_providers.dart', () {
    expect(
      identical(
        accountFirebaseRegistryProvider,
        account_firebase_providers.accountFirebaseRegistryProvider,
      ),
      isTrue,
    );
  });

  test('resolves to the same AccountFirebase instance through either import '
      'path', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final viaReexport = container.read(accountFirebaseRegistryProvider);
    final viaOriginal = container.read(
      account_firebase_providers.accountFirebaseRegistryProvider,
    );
    expect(
      identical(viaReexport, viaOriginal),
      isTrue,
      reason:
          'Reading through either import path must see the same '
          'AccountFirebase instance.',
    );
  });
}
