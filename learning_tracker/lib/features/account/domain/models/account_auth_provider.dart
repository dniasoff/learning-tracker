import 'package:shared_preferences/shared_preferences.dart';

/// The credential family used to establish a saved cloud account.
///
/// This is deliberately kept separate from [AppUser.providers]: the latter is
/// a live FirebaseAuth projection, while this value belongs to the saved
/// device-account entry and must still be available after that live session has
/// been signed out.
enum AccountAuthProvider { emailPassword, google }

extension AccountAuthProviderId on AccountAuthProvider {
  String get persistedValue => switch (this) {
    AccountAuthProvider.emailPassword => 'password',
    AccountAuthProvider.google => 'google.com',
  };

  static AccountAuthProvider? fromProviderIds(Iterable<String> providerIds) {
    if (providerIds.contains('password')) {
      return AccountAuthProvider.emailPassword;
    }
    if (providerIds.contains('google.com')) return AccountAuthProvider.google;
    return null;
  }

  static AccountAuthProvider? fromPersistedValue(String? value) =>
      switch (value) {
        'password' => AccountAuthProvider.emailPassword,
        'google.com' => AccountAuthProvider.google,
        _ => null,
      };
}

/// Persists the provider marker alongside the device-account metadata.
///
/// The registry schema is intentionally not changed here: it is Drift-generated
/// and changing it would require a coordinated code-generation/migration pass.
/// The marker has the same account-id ownership and lifetime, and is safe to
/// read as an optional field for accounts created before this fix.
class AccountAuthProviderStore {
  const AccountAuthProviderStore(this._prefs);

  final SharedPreferences _prefs;

  static String keyFor(String accountId) =>
      'account_auth_provider_${accountId.trim()}';

  AccountAuthProvider? read(String accountId) =>
      AccountAuthProviderId.fromPersistedValue(
        _prefs.getString(keyFor(accountId)),
      );

  Future<bool> write(String accountId, AccountAuthProvider provider) =>
      _prefs.setString(keyFor(accountId), provider.persistedValue);
}
