/// The tier of a user account, reflecting how it was created.
///
/// ## Storage keys
/// The Drift `accounts.tier` column and Firestore store the original
/// snake-cased keys: `'cloudBorn'` and `'localBorn'`. The enum names are the
/// shorter, intent-focused forms used in domain code.
///
/// | Enum value | Storage key | Meaning |
/// |---|---|---|
/// | [cloud] | `'cloudBorn'` | Created with an email/Firebase account |
/// | [local] | `'localBorn'` | Created offline, device-only |
///
/// ## Migration note
/// Direct string comparisons (`account.tier == 'cloudBorn'`) should be
/// replaced with typed comparisons (`account.accountTier == AccountTier.cloud`)
/// as part of the W5.11 primitive-obsession sweep.
enum AccountTier {
  /// Cloud account — created with email/Firebase authentication.
  ///
  /// Can sync across devices; supports multi-device workflows.
  cloud,

  /// Local account — created offline, no cloud identity.
  ///
  /// Data lives on-device only until the account is upgraded to cloud.
  local;

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// The storage key as used in the Drift `accounts.tier` column.
  String get storageKey => switch (this) {
    AccountTier.cloud => 'cloudBorn',
    AccountTier.local => 'localBorn',
  };

  /// Parses [key] from storage.
  ///
  /// Accepts both `'cloudBorn'` and `'localBorn'`. Throws [ArgumentError]
  /// for unrecognised keys.
  static AccountTier fromStorageKey(String key) {
    return switch (key) {
      'cloudBorn' => AccountTier.cloud,
      'localBorn' => AccountTier.local,
      _ => throw ArgumentError.value(
        key,
        'key',
        'Unknown AccountTier storage key. Expected "cloudBorn" or "localBorn".',
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Whether this account has a cloud identity (email, Firebase auth).
  bool get isCloud => this == AccountTier.cloud;

  /// Whether this account is device-local only (no cloud sync).
  bool get isLocal => this == AccountTier.local;
}
