import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/account_auth_provider.dart';

void main() {
  group('AccountAuthProviderId', () {
    test('serializes email/password and Google providers', () {
      expect(AccountAuthProvider.emailPassword.persistedValue, 'password');
      expect(AccountAuthProvider.google.persistedValue, 'google.com');
    });

    test('maps provider ids to both supported providers', () {
      expect(
        AccountAuthProviderId.fromProviderIds(['password']),
        AccountAuthProvider.emailPassword,
      );
      expect(
        AccountAuthProviderId.fromProviderIds(['google.com']),
        AccountAuthProvider.google,
      );
    });

    test('prefers password when both providers are linked', () {
      expect(
        AccountAuthProviderId.fromProviderIds(['google.com', 'password']),
        AccountAuthProvider.emailPassword,
      );
    });

    test('returns null for unknown or empty provider ids', () {
      expect(AccountAuthProviderId.fromProviderIds(const []), isNull);
      expect(AccountAuthProviderId.fromProviderIds(['phone']), isNull);
    });

    test('maps persisted values and returns null for unknown values', () {
      expect(
        AccountAuthProviderId.fromPersistedValue('password'),
        AccountAuthProvider.emailPassword,
      );
      expect(
        AccountAuthProviderId.fromPersistedValue('google.com'),
        AccountAuthProvider.google,
      );
      expect(AccountAuthProviderId.fromPersistedValue(null), isNull);
      expect(AccountAuthProviderId.fromPersistedValue('phone'), isNull);
    });
  });
}
