import 'dart:async';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/pin.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pin_service.g.dart';

/// Service for managing parent PINs with secure storage and bcrypt hashing.
///
/// PINs are device-local only and never synced to Firestore.
/// All PINs are hashed with bcrypt before storage - plaintext is never persisted.
///
/// AUD-core-domain-05: the 4-digit-PIN format invariant is validated via
/// [Pin.tryParse] — the single source of truth for that rule — rather than a
/// private hand-rolled regex.
class PinService {
  PinService(
    this._secureStorage, {
    this.maxFailedAttempts = 5,
    this.lockoutDurationMinutes = 15,
    AnalyticsService? analytics,
  }) : _analytics = analytics ?? const NullAnalyticsService();

  final FlutterSecureStorage _secureStorage;
  final AnalyticsService _analytics;

  /// Maximum number of failed PIN attempts before lockout.
  final int maxFailedAttempts;

  /// Duration of lockout in minutes after max failed attempts.
  final int lockoutDurationMinutes;

  // Storage keys for PINs
  static const _parentPinKey = 'parent_pin_hash';
  static const _parentLockoutKey = 'parent_lockout_count';
  static const _parentLockoutTimestampKey = 'parent_lockout_timestamp';

  // Per-profile parent PIN key builders. Each child profile can have its own
  // 4-digit parent PIN — the hash is keyed by profile id in secure storage.
  static String _profilePinKey(int profileId) =>
      'profile_${profileId}_parent_pin_hash';
  static String _profileLockoutKey(int profileId) =>
      'profile_${profileId}_parent_lockout_count';
  static String _profileLockoutTimestampKey(int profileId) =>
      'profile_${profileId}_parent_lockout_timestamp';

  // Per-profile tutor PIN key builders. Independent namespace from parent —
  // authenticating the parent scope must NOT grant tutor access (and vice
  // versa).
  static String _tutorPinKey(int profileId) =>
      'profile_${profileId}_tutor_pin_hash';
  static String _tutorLockoutKey(int profileId) =>
      'profile_${profileId}_tutor_lockout_count';
  static String _tutorLockoutTimestampKey(int profileId) =>
      'profile_${profileId}_tutor_lockout_timestamp';

  /// Sets the parent PIN by hashing it with bcrypt and storing securely.
  ///
  /// The plaintext PIN is never stored.
  /// Resets any existing lockout state when a new PIN is set.
  Future<void> setParentPin(String pin) async {
    if (Pin.tryParse(pin) == null) {
      throw const InvalidPinFormatException();
    }

    final hash = BCrypt.hashpw(pin, BCrypt.gensalt());
    await _secureStorage.write(key: _parentPinKey, value: hash);

    // Reset lockout state when PIN is changed
    await _secureStorage.delete(key: _parentLockoutKey);
    await _secureStorage.delete(key: _parentLockoutTimestampKey);
  }

  /// Verifies the parent PIN against the stored hash.
  ///
  /// Returns true if the PIN is correct, false otherwise.
  /// Increments failed attempt counter and triggers lockout after max attempts.
  /// Resets failed attempt counter on successful verification.
  ///
  /// Throws [PinLockoutException] if currently locked out.
  Future<bool> verifyParentPin(String pin) async {
    // Check lockout first
    if (await _isLockedOut(_parentLockoutTimestampKey)) {
      final remainingMinutes = await _getRemainingLockoutMinutes(
        _parentLockoutTimestampKey,
      );
      throw PinLockoutException(remainingMinutes);
    }

    final storedHash = await _secureStorage.read(key: _parentPinKey);
    if (storedHash == null) {
      return false; // No PIN set
    }

    final isValid = BCrypt.checkpw(pin, storedHash);

    if (isValid) {
      // Reset lockout counter on successful verification
      await _secureStorage.delete(key: _parentLockoutKey);
      await _secureStorage.delete(key: _parentLockoutTimestampKey);
    } else {
      // Increment failed attempts
      await _incrementFailedAttempts(
        _parentLockoutKey,
        _parentLockoutTimestampKey,
      );
    }

    return isValid;
  }

  /// Returns true if a parent PIN has been set.
  Future<bool> hasParentPin() async {
    final hash = await _secureStorage.read(key: _parentPinKey);
    return hash != null;
  }

  /// Removes the parent PIN and any associated lockout state from secure
  /// storage. Intended for explicit parent-initiated removal from settings.
  Future<void> clearParentPin() async {
    await _secureStorage.delete(key: _parentPinKey);
    await _secureStorage.delete(key: _parentLockoutKey);
    await _secureStorage.delete(key: _parentLockoutTimestampKey);
  }

  /// Sets a parent PIN linked to a specific child [profileId].
  ///
  /// Hashed with bcrypt and written to secure storage keyed by profile id —
  /// each child profile can have its own PIN. Resets any existing lockout
  /// state for the profile. Plaintext is never persisted.
  Future<void> setProfilePin(int profileId, String pin) async {
    if (Pin.tryParse(pin) == null) {
      throw const InvalidPinFormatException();
    }
    final hash = BCrypt.hashpw(pin, BCrypt.gensalt());
    await _secureStorage.write(key: _profilePinKey(profileId), value: hash);
    await _secureStorage.delete(key: _profileLockoutKey(profileId));
    await _secureStorage.delete(key: _profileLockoutTimestampKey(profileId));
  }

  /// Verifies [pin] against the hash stored for [profileId].
  ///
  /// Increments the per-profile failed-attempt counter and triggers lockout
  /// after [maxFailedAttempts]. Throws [PinLockoutException] if already
  /// locked out.
  Future<bool> verifyProfilePin(int profileId, String pin) async {
    final timestampKey = _profileLockoutTimestampKey(profileId);
    if (await _isLockedOut(timestampKey)) {
      final remaining = await _getRemainingLockoutMinutes(timestampKey);
      throw PinLockoutException(remaining);
    }

    final storedHash = await _secureStorage.read(
      key: _profilePinKey(profileId),
    );
    if (storedHash == null) return false;

    final isValid = BCrypt.checkpw(pin, storedHash);
    if (isValid) {
      await _secureStorage.delete(key: _profileLockoutKey(profileId));
      await _secureStorage.delete(key: timestampKey);
    } else {
      await _incrementFailedAttempts(
        _profileLockoutKey(profileId),
        timestampKey,
      );
    }
    return isValid;
  }

  /// Returns true if a parent PIN has been set for [profileId].
  Future<bool> hasProfilePin(int profileId) async {
    final hash = await _secureStorage.read(key: _profilePinKey(profileId));
    return hash != null;
  }

  /// Removes the parent PIN and lockout state for [profileId].
  Future<void> clearProfilePin(int profileId) async {
    await _secureStorage.delete(key: _profilePinKey(profileId));
    await _secureStorage.delete(key: _profileLockoutKey(profileId));
    await _secureStorage.delete(key: _profileLockoutTimestampKey(profileId));
  }

  /// Remaining lockout in minutes for [profileId]. Returns 0 if not locked.
  Future<int> getProfileLockoutRemainingMinutes(int profileId) async {
    final key = _profileLockoutTimestampKey(profileId);
    if (!await _isLockedOut(key)) return 0;
    return _getRemainingLockoutMinutes(key);
  }

  /// Sets a tutor PIN linked to a specific child [profileId].
  ///
  /// Stored under an independent namespace from the parent PIN so granting
  /// parent access does not grant tutor access (and vice versa).
  Future<void> setTutorPin(int profileId, String pin) async {
    if (Pin.tryParse(pin) == null) {
      throw const InvalidPinFormatException();
    }
    final hash = BCrypt.hashpw(pin, BCrypt.gensalt());
    await _secureStorage.write(key: _tutorPinKey(profileId), value: hash);
    await _secureStorage.delete(key: _tutorLockoutKey(profileId));
    await _secureStorage.delete(key: _tutorLockoutTimestampKey(profileId));
  }

  /// Verifies [pin] against the tutor PIN hash stored for [profileId].
  Future<bool> verifyTutorPin(int profileId, String pin) async {
    final timestampKey = _tutorLockoutTimestampKey(profileId);
    if (await _isLockedOut(timestampKey)) {
      final remaining = await _getRemainingLockoutMinutes(timestampKey);
      throw PinLockoutException(remaining);
    }

    final storedHash = await _secureStorage.read(key: _tutorPinKey(profileId));
    if (storedHash == null) return false;

    final isValid = BCrypt.checkpw(pin, storedHash);
    if (isValid) {
      await _secureStorage.delete(key: _tutorLockoutKey(profileId));
      await _secureStorage.delete(key: timestampKey);
    } else {
      await _incrementFailedAttempts(_tutorLockoutKey(profileId), timestampKey);
    }
    return isValid;
  }

  /// Returns true if a tutor PIN has been set for [profileId].
  Future<bool> hasTutorPin(int profileId) async {
    final hash = await _secureStorage.read(key: _tutorPinKey(profileId));
    return hash != null;
  }

  /// Removes the tutor PIN and lockout state for [profileId].
  Future<void> clearTutorPin(int profileId) async {
    await _secureStorage.delete(key: _tutorPinKey(profileId));
    await _secureStorage.delete(key: _tutorLockoutKey(profileId));
    await _secureStorage.delete(key: _tutorLockoutTimestampKey(profileId));
  }

  /// Remaining tutor-PIN lockout in minutes for [profileId]. Returns 0 if not
  /// locked.
  Future<int> getTutorLockoutRemainingMinutes(int profileId) async {
    final key = _tutorLockoutTimestampKey(profileId);
    if (!await _isLockedOut(key)) return 0;
    return _getRemainingLockoutMinutes(key);
  }

  /// Returns the remaining lockout time in minutes for parent PIN.
  ///
  /// Returns 0 if not locked out.
  Future<int> getParentLockoutRemainingMinutes() async {
    if (!await _isLockedOut(_parentLockoutTimestampKey)) {
      return 0;
    }
    return await _getRemainingLockoutMinutes(_parentLockoutTimestampKey);
  }

  // Private helper methods

  Future<void> _incrementFailedAttempts(
    String countKey,
    String timestampKey,
  ) async {
    final countStr = await _secureStorage.read(key: countKey);
    final count = countStr != null ? int.parse(countStr) : 0;
    final newCount = count + 1;

    await _secureStorage.write(key: countKey, value: newCount.toString());

    if (newCount >= maxFailedAttempts) {
      // Write lockout timestamp FIRST so that if the app is killed between
      // writes the lockout is still preserved (TOCTOU safety).
      final lockoutTimestamp = DateTimeFactory.nowLocal().millisecondsSinceEpoch
          .toString();
      await _secureStorage.write(key: timestampKey, value: lockoutTimestamp);
      await _secureStorage.write(key: countKey, value: '0');
      // Story 27.14 (DNI-390): fire analytics event when lockout triggers.
      // profileId is not known at this layer — use 0 as sentinel (profileId=0
      // convention per coding standards).
      unawaited(_analytics.logPinLockedOut(profileId: 0));
    }
  }

  Future<bool> _isLockedOut(String timestampKey) async {
    final timestampStr = await _secureStorage.read(key: timestampKey);
    if (timestampStr == null) {
      return false;
    }

    final lockoutTimestamp = int.parse(timestampStr);
    final lockoutEnd = DateTime.fromMillisecondsSinceEpoch(
      lockoutTimestamp,
    ).add(Duration(minutes: lockoutDurationMinutes));

    return DateTimeFactory.nowLocal().isBefore(lockoutEnd);
  }

  Future<int> _getRemainingLockoutMinutes(String timestampKey) async {
    final timestampStr = await _secureStorage.read(key: timestampKey);
    if (timestampStr == null) {
      return 0;
    }

    final lockoutTimestamp = int.parse(timestampStr);
    final lockoutEnd = DateTime.fromMillisecondsSinceEpoch(
      lockoutTimestamp,
    ).add(Duration(minutes: lockoutDurationMinutes));

    final remaining = lockoutEnd.difference(DateTimeFactory.nowLocal());
    if (remaining.inSeconds <= 0) {
      return 0;
    }
    // Round up so users see at least 1 minute while time is still remaining.
    return (remaining.inSeconds / 60).ceil();
  }
}

/// Exception thrown when PIN verification is attempted during lockout.
class PinLockoutException extends PermissionException {
  const PinLockoutException(this.remainingMinutes)
    : super(
        'Too many failed attempts. Try again in $remainingMinutes minute(s).',
      );

  final int remainingMinutes;
}

/// Thrown when a PIN fails the 4-digit numeric format validation
/// ([setParentPin], [setProfilePin], [setTutorPin]).
///
/// AUD-onboarding-16 (EH-2/EH-5): this replaces a bare `ArgumentError` whose
/// `.message` (typed `Object?`) used to be cast straight into UI error text
/// by callers — an unlocalized English literal reaching Hebrew-locale users,
/// and a brittle cast that would have become an unhandled `TypeError` the
/// moment any throw site stopped passing a `String`. [message] is a stable,
/// English, developer-facing description for logs/`toString()` only —
/// presentation code MUST catch this type and resolve the user-facing string
/// via `AppLocalizations`, never read [message] directly.
class InvalidPinFormatException extends ValidationException {
  const InvalidPinFormatException()
    : super('PIN must be exactly 4 numeric digits');
}

/// Provider for FlutterSecureStorage instance.
///
/// Exposed as a separate provider so tests can override it with a mock.
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Provider for the PIN service.
@riverpod
PinService pinService(Ref ref) {
  final storage = ref.watch(flutterSecureStorageProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  return PinService(storage, analytics: analytics);
}
