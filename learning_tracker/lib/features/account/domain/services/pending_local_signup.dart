import 'dart:convert';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences keys for offline signup that is not yet listed in the
/// device registry (waiting for the first learner [Profile] row).
const _kPendingPayload = 'pending_local_registration_v1';
const _kReservedEmails = 'pending_local_signup_emails_v1';

/// JSON payload written after [LocalAuthService.signUp] succeeds and cleared
/// after [SessionPersistenceService.registerAccount] runs.
class PendingLocalRegistration {
  const PendingLocalRegistration({
    required this.accountId,
    required this.dbFileName,
    required this.email,
    required this.displayName,
  });

  final String accountId;
  final String dbFileName;
  final String email;
  final String displayName;

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'dbFileName': dbFileName,
    'email': email,
    'displayName': displayName,
  };

  static PendingLocalRegistration? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final accountId = m['accountId'] as String?;
      final dbFileName = m['dbFileName'] as String?;
      final email = m['email'] as String?;
      final displayName = m['displayName'] as String?;
      if (accountId == null ||
          dbFileName == null ||
          email == null ||
          displayName == null) {
        return null;
      }
      return PendingLocalRegistration(
        accountId: accountId,
        dbFileName: dbFileName,
        email: email,
        displayName: displayName,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Offline signup reservation + completion helpers (Epic 21 local-born).
class PendingLocalSignupStore {
  PendingLocalSignupStore._();

  static Future<PendingLocalRegistration?> readPayload(
    SharedPreferences prefs,
  ) async {
    return PendingLocalRegistration.tryParse(prefs.getString(_kPendingPayload));
  }

  static Future<void> writePayload(
    SharedPreferences prefs,
    PendingLocalRegistration data,
  ) async {
    await prefs.setString(_kPendingPayload, jsonEncode(data.toJson()));
  }

  static Future<void> clearPayload(SharedPreferences prefs) async {
    await prefs.remove(_kPendingPayload);
  }

  static List<String> _reservedList(SharedPreferences prefs) =>
      List<String>.from(prefs.getStringList(_kReservedEmails) ?? []);

  static Future<void> _setReservedList(
    SharedPreferences prefs,
    List<String> emails,
  ) async {
    if (emails.isEmpty) {
      await prefs.remove(_kReservedEmails);
    } else {
      await prefs.setStringList(_kReservedEmails, emails);
    }
  }

  /// Returns false if [normalizedEmail] is already reserved for another
  /// in-progress offline signup on this device.
  static Future<bool> tryReserveEmail(
    SharedPreferences prefs,
    String normalizedEmail,
  ) async {
    final n = normalizedEmail.trim().toLowerCase();
    final list = _reservedList(prefs);
    final lower = list.map((e) => e.toLowerCase()).toList();
    if (lower.contains(n)) return false;
    list.add(normalizedEmail.trim());
    await _setReservedList(prefs, list);
    return true;
  }

  static Future<void> releaseEmail(
    SharedPreferences prefs,
    String normalizedEmail,
  ) async {
    final n = normalizedEmail.trim().toLowerCase();
    final next = _reservedList(
      prefs,
    ).where((e) => e.trim().toLowerCase() != n).toList();
    await _setReservedList(prefs, next);
  }

  /// After the first learner profile is created, add the account to the
  /// device registry and clear pending state.
  static Future<void> finalizeAfterFirstProfile(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await readPayload(prefs);
    if (pending == null) return;

    final registry = ref.read(deviceRegistryProvider);
    if (await registry.findById(pending.accountId) != null) {
      await releaseEmail(prefs, pending.email);
      await clearPayload(prefs);
      return;
    }
    final session = SessionPersistenceService(prefs: prefs, registry: registry);
    await session.registerAccount(
      accountId: pending.accountId,
      email: pending.email.trim().toLowerCase(),
      displayName: pending.displayName,
      tier: 'localBorn',
      dbFileName: pending.dbFileName,
    );
    await releaseEmail(prefs, pending.email);
    await clearPayload(prefs);
  }

  /// Deletes the new-account DB file and clears session + prefs when the user
  /// leaves onboarding (or the app) before creating a learner profile.
  static Future<void> rollbackIfIncomplete({
    required WidgetRef ref,
    required String databasesPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await readPayload(prefs);
    if (pending == null) return;

    final db = ref.read(userDatabaseProvider);
    final count = await db.profileDao.countProfilesForAccount(
      ref.read(currentAccountIdProvider),
    );
    if (count > 0) {
      // First profile exists — registration should have finalized; repair
      // prefs if we still have a stale payload.
      await clearPayload(prefs);
      await releaseEmail(prefs, pending.email);
      return;
    }

    _deleteDbFile(databasesPath, pending.dbFileName);
    await clearPayload(prefs);
    await releaseEmail(prefs, pending.email);

    activeDbFileName = 'learning_tracker';
    ref.invalidate(userDatabaseProvider);
    ref.read(authStateProvider.notifier).signOut();
  }

  /// Cold-start cleanup when the app was killed mid-onboarding (no registry
  /// row yet, but a payload and/or DB file may remain).
  static Future<void> cleanupStaleOnStartup({
    required SharedPreferences prefs,
    required String databasesPath,
  }) async {
    final pending = await readPayload(prefs);
    if (pending == null) {
      return;
    }

    final registry = DeviceRegistryDatabase(
      driftDatabase(name: 'device_registry'),
    );
    try {
      final existing = await registry.findById(pending.accountId);
      if (existing != null) {
        await clearPayload(prefs);
        await releaseEmail(prefs, pending.email);
        return;
      }
    } finally {
      await registry.close();
    }

    _deleteDbFile(databasesPath, pending.dbFileName);
    await clearPayload(prefs);
    await releaseEmail(prefs, pending.email);
  }

  static void _deleteDbFile(String databasesPath, String dbFileName) {
    final file = File('$databasesPath/$dbFileName');
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// Removes a per-account DB file during a failed signup attempt.
  static void deleteOrphanDbFile(String databasesPath, String dbFileName) {
    _deleteDbFile(databasesPath, dbFileName);
  }
}
