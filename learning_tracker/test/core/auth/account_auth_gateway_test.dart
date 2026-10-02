// DNI-520 AC-1 — the AccountAuthGateway seam: the app's only Auth entry
// point. `firebaseAuthGatewayProvider` is the ACTIVE account's named-app
// gateway (`gatewayFor(activeAccountId)`), rebound on every account switch;
// there is no default-app `FirebaseAuth.instance` fallback.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/auth/account_auth_gateway.dart';
import 'package:learning_tracker/core/auth/auth_providers.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockAccountAuthGateway extends Mock implements AccountAuthGateway {}

class _MockFirebaseAuthGateway extends Mock implements FirebaseAuthGateway {}

void main() {
  late _MockAccountAuthGateway accounts;
  late _MockFirebaseAuthGateway signedOut;
  late _MockFirebaseAuthGateway forA;
  late _MockFirebaseAuthGateway forB;
  late ProviderContainer container;

  setUp(() {
    accounts = _MockAccountAuthGateway();
    signedOut = _MockFirebaseAuthGateway();
    forA = _MockFirebaseAuthGateway();
    forB = _MockFirebaseAuthGateway();
    when(() => accounts.gatewayFor(null)).thenReturn(signedOut);
    when(() => accounts.gatewayFor('acc-a')).thenReturn(forA);
    when(() => accounts.gatewayFor('acc-b')).thenReturn(forB);
    container = ProviderContainer(
      overrides: [accountAuthGatewayProvider.overrideWithValue(accounts)],
    );
    addTearDown(container.dispose);
  });

  test('with no active account the gateway is the signed-out one '
      '(gatewayFor(null)), never a default-app instance', () {
    expect(container.read(firebaseAuthGatewayProvider), same(signedOut));
    verify(() => accounts.gatewayFor(null)).called(1);
  });

  test('the gateway is bound to the ACTIVE account and rebinds on every '
      'account switch (cloud <-> anonymous)', () {
    final active = container.read(activeAccountIdProvider.notifier);

    active.set('acc-a');
    expect(container.read(firebaseAuthGatewayProvider), same(forA));

    active.set('acc-b');
    expect(container.read(firebaseAuthGatewayProvider), same(forB));

    active.set('acc-a');
    expect(container.read(firebaseAuthGatewayProvider), same(forA));
    verify(() => accounts.gatewayFor('acc-a')).called(2);
    verify(() => accounts.gatewayFor('acc-b')).called(1);
  });
}
