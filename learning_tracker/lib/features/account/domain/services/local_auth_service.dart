import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/services/password_hasher.dart';

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

/// Thrown when sign-in fails because the email is unknown *or* the
/// password does not match. The single error type is intentional —
/// distinguishing the two would enable user enumeration.
class InvalidCredentialsException extends PermissionException {
  const InvalidCredentialsException() : super('Invalid email or password');
}

/// Thrown when sign-up receives malformed input (invalid email,
/// password too short, etc). Caller surfaces a friendly message.
class InvalidInputException extends ValidationException {
  const InvalidInputException(this.field, this.reason)
    : super('$field: $reason');
  final String field;
  final String reason;
}

/// Domain service for local-born account authentication.
///
/// Cloud-born accounts go through Firebase Auth instead — see
/// v2 doc §4.2. This service is only invoked for accounts with
/// `tier == localBorn`.
class LocalAuthService {
  LocalAuthService({required UserProfileDao dao, PasswordHasher? hasher})
    : _dao = dao,
      _hasher = hasher ?? PasswordHasher();

  final UserProfileDao _dao;
  final PasswordHasher _hasher;

  static const int _minPasswordLength = 8;

  /// Create a new local-born account. Throws
  /// [DuplicateEmailException] if the email already has a local-born
  /// row, [InvalidInputException] on malformed input.
  ///
  /// WS9.flows: [userMode] parameter removed — mode belongs to
  /// [LearnerProfiles], not to an account.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = _normalizeEmail(email);
    _validateEmail(normalized);
    _validatePassword(password);

    final existing = await _dao.findLocalBornByEmail(normalized);
    if (existing != null) {
      throw DuplicateEmailException(normalized);
    }

    final hash = await _hasher.hash(password);
    final now = DateTimeFactory.nowUtc();
    final id = await _dao.insertUserProfile(
      UserProfilesCompanion.insert(
        email: normalized,
        firebaseUid: const Value(null),
        tier: UserTier.localBorn.dbValue,
        passwordHash: Value(hash),
        displayName: displayName,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await _dao.getUserProfileById(id))!;
  }

  /// Verify a local-born account's credentials. Returns the profile
  /// on success; throws [InvalidCredentialsException] on any failure.
  ///
  /// The dummy-verify branch keeps timing constant when the email
  /// does not exist so attackers cannot enumerate accounts.
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = _normalizeEmail(email);

    final profile = await _dao.findLocalBornByEmail(normalized);
    if (profile == null || profile.passwordHash == null) {
      await _hasher.dummyVerify();
      throw const InvalidCredentialsException();
    }

    final ok = await _hasher.verify(password, profile.passwordHash!);
    if (!ok) {
      throw const InvalidCredentialsException();
    }
    return profile;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  void _validateEmail(String email) {
    // Deliberately strict enough to reject the obviously wrong,
    // loose enough to avoid false positives. Real validation is
    // "can you actually deliver a message to it" which we can't do.
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(email)) {
      throw const InvalidInputException('email', 'invalid format');
    }
  }

  void _validatePassword(String password) {
    if (password.length < _minPasswordLength) {
      throw const InvalidInputException(
        'password',
        'must be at least 8 characters',
      );
    }
  }
}
