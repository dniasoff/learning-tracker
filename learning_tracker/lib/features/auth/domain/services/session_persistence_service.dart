import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dual-write service that keeps SharedPreferences and the device
/// registry in sync for `lastActiveAccountId`.
///
/// SharedPreferences is the fast path (readable before Drift opens).
/// The registry is the authoritative source. If they disagree, the
/// registry wins.
class SessionPersistenceService {
  SessionPersistenceService({
    required SharedPreferences prefs,
    required DeviceRegistryDatabase registry,
  }) : _prefs = prefs,
       _registry = registry;

  final SharedPreferences _prefs;
  final DeviceRegistryDatabase _registry;

  static const _key = 'last_active_account_id';

  /// Set the active account. Writes to BOTH stores and updates
  /// the registry's `lastUsedAt` timestamp.
  Future<void> setActiveAccount(String accountId) async {
    await _prefs.setString(_key, accountId);
    await _registry.setLastActiveAccountId(accountId);
    await _registry.updateLastUsed(accountId, DateTime.now());
  }

  /// Clear the active account (sign-out). The registry entry for
  /// the account is NOT removed — the account still exists on the
  /// device, it's just not the current session.
  Future<void> clearActiveAccount() async {
    await _prefs.remove(_key);
    await _registry.setLastActiveAccountId(null);
  }

  /// Fast read from SharedPreferences. Returns null if no active
  /// account is set (signed out or fresh install).
  String? getActiveAccountId() => _prefs.getString(_key);

  /// Resolve the active account ID with fallback chain:
  /// 1. SharedPreferences (fast)
  /// 2. Registry device_state (authoritative)
  /// 3. First account in registry (graceful fallback)
  /// 4. null (no accounts on device)
  Future<String?> resolveActiveAccountId() async {
    // Fast path
    var id = getActiveAccountId();
    if (id != null) {
      // Validate it still exists in registry
      final account = await _registry.findById(id);
      if (account != null) return id;
      // Stale pointer — clear it
      await _prefs.remove(_key);
    }

    // Registry authoritative
    id = await _registry.getLastActiveAccountId();
    if (id != null) {
      final account = await _registry.findById(id);
      if (account != null) {
        // Sync SharedPreferences
        await _prefs.setString(_key, id);
        return id;
      }
    }

    // Fallback: first account in registry
    final accounts = await _registry.getAllAccounts();
    if (accounts.isNotEmpty) {
      final fallbackId = accounts.first.accountId;
      await setActiveAccount(fallbackId);
      return fallbackId;
    }

    return null; // No accounts on device
  }
}
