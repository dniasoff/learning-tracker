/// Per-install salted learner profile hashes for analytics user properties.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage boundary for the install-scoped analytics salt.
abstract interface class AnalyticsSaltStore {
  Future<String?> read();
  Future<void> write(String salt);
}

/// Persisted salt backed by OS-protected storage.
final class SecureAnalyticsSaltStore implements AnalyticsSaltStore {
  SecureAnalyticsSaltStore(this.storage);

  static const key = 'analytics_install_salt_v1';
  final FlutterSecureStorage storage;

  @override
  Future<String?> read() => storage.read(key: key);

  @override
  Future<void> write(String salt) => storage.write(key: key, value: salt);
}

/// Produces a stable HMAC for a profile on this installation only.
final class ProfileAnalyticsHasher {
  ProfileAnalyticsHasher({required this.saltStore, Random? random})
    : _random = random ?? Random.secure();

  final AnalyticsSaltStore saltStore;
  final Random _random;

  Future<String> hash(String profileId) async {
    if (profileId.isEmpty) return '';
    var salt = await saltStore.read();
    if (salt == null || salt.isEmpty) {
      final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
      salt = base64UrlEncode(bytes);
      await saltStore.write(salt);
    }
    final digest = Hmac(
      sha256,
      utf8.encode(salt),
    ).convert(utf8.encode(profileId));
    // Analytics user-property values have a short maximum; 128 bits is still
    // ample for an install-salted pseudonymous key.
    return digest.toString().substring(0, 32);
  }
}
