import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Thrown when a local-born signup is attempted with an email that
/// already has a local-born row. Distinct from a Firebase-level
/// collision (handled by the upgrade flow in 20.9).
///
/// The raw email is stored in [email] for callers that need it (e.g. to
/// pre-fill a sign-in form), but it is NOT included in [message] or
/// [toString] — those paths are safe to pass to loggers.
class DuplicateEmailException extends ConflictException {
  const DuplicateEmailException(this.email) : super('Email already in use');

  /// The conflicting email address.
  ///
  /// Do NOT log this field directly. Use [redactedEmail] for log contexts.
  final String email;

  /// A log-safe representation of the email: "***@<domain>".
  String get redactedEmail {
    final atIndex = email.indexOf('@');
    if (atIndex < 0) return '***';
    return '***${email.substring(atIndex)}';
  }
}

/// Thrown when sign-in fails because the email is unknown *or* does not name
/// a local-born account. The single error type is intentional —
/// distinguishing the two would enable user enumeration.
class InvalidCredentialsException extends PermissionException {
  const InvalidCredentialsException() : super('Invalid email or password');
}

/// Stable, locale-independent identifiers for [InvalidInputException.code].
///
/// Presentation resolves these to a localized message via
/// `AppLocalizations` (EH-5) — [InvalidInputException.reason] is a
/// log-safe, English-only detail for developers and must never be shown
/// to users directly.
enum InvalidInputCode { invalidEmail, displayNameRequired }

/// Thrown when sign-up receives malformed input (invalid email, etc).
/// Callers resolve [code] to a localized message; [reason] is for
/// logs/toString only — never surface it directly in the UI (EH-5).
class InvalidInputException extends ValidationException {
  const InvalidInputException(this.field, this.code, this.reason)
    : super('$field: $reason');
  final String field;
  final InvalidInputCode code;
  final String reason;
}

/// Domain service for local-born account lifecycle.
///
/// Per the 2026-06-14 product decision (`docs/planning/ux-upgrade-flow-spec.md`),
/// offline / local-born accounts are **credential-less** — there is no local
/// password to hash or verify. The device registry
/// ([DeviceRegistryDatabase]) is the on-device account store: a local-born
/// account is a registry row with `tier == 'localBorn'` and no linked
/// Firebase credentials. Cloud-born accounts go through Firebase Auth instead
/// (v2 doc §4.2).
class LocalAuthService {
  LocalAuthService({required DeviceRegistryDatabase registry})
    : _registry = registry;

  final DeviceRegistryDatabase _registry;

  /// Create a new credential-less local-born account in the device registry.
  /// Throws [DuplicateEmailException] if the email is already registered on
  /// this device, [InvalidInputException] on malformed input.
  ///
  /// [accountId] and [dbFileName] are supplied by the caller (generated at
  /// the flow's start, before any I/O — the pre-rewrite flow generated both
  /// in the screen and passed the per-account DB filename through).
  Future<DeviceAccount> signUp({
    required String email,
    required String displayName,
    required String accountId,
    required String dbFileName,
  }) async {
    final normalized = _normalizeEmail(email);
    _validateEmail(normalized);

    final existing = await _registry.findByEmail(normalized);
    if (existing != null) {
      throw DuplicateEmailException(normalized);
    }

    final now = DateTimeFactory.nowUtc();
    await _registry.addAccount(
      DeviceAccountsCompanion.insert(
        accountId: accountId,
        email: normalized,
        displayName: displayName,
        tier: AccountTier.local.storageKey,
        firebaseUid: const Value(null),
        dbFileName: dbFileName,
        createdAt: now,
        lastUsedAt: now,
      ),
    );
    return (await _registry.findById(accountId))!;
  }

  /// Verify that [email] names a local-born account on this device. Returns
  /// the registry row on success; throws [InvalidCredentialsException] if the
  /// email is unknown or the row is not a local-born account.
  Future<DeviceAccount> signIn({required String email}) async {
    final normalized = _normalizeEmail(email);

    final account = await _registry.findByEmail(normalized);
    if (account == null || !account.accountTier.isLocal) {
      throw const InvalidCredentialsException();
    }
    return account;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  void _validateEmail(String email) {
    // Deliberately strict enough to reject the obviously wrong,
    // loose enough to avoid false positives. Real validation is
    // "can you actually deliver a message to it" which we can't do.
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(email)) {
      throw const InvalidInputException(
        'email',
        InvalidInputCode.invalidEmail,
        'invalid format',
      );
    }
  }
}
