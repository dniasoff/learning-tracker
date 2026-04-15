import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// argon2id production parameters.
///
/// Values chosen conservatively for the Android API 21 target device
/// (20.1 benchmark not yet run — OWASP low-end floor). Tune in one
/// place once the benchmark lands.
class Argon2idParams {
  const Argon2idParams({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
    required this.hashLengthBytes,
    required this.saltLengthBytes,
  });

  final int memoryKib;
  final int iterations;
  final int parallelism;
  final int hashLengthBytes;
  final int saltLengthBytes;

  /// Production default — OWASP low-end floor (m=19MiB, t=2, p=1).
  /// Replace with 20.1 benchmark result.
  static const production = Argon2idParams(
    memoryKib: 19456,
    iterations: 2,
    parallelism: 1,
    hashLengthBytes: 32,
    saltLengthBytes: 16,
  );

  /// Test-only params — tiny to keep unit tests fast.
  static const test = Argon2idParams(
    memoryKib: 256,
    iterations: 1,
    parallelism: 1,
    hashLengthBytes: 32,
    saltLengthBytes: 16,
  );
}

/// Thin wrapper around `package:cryptography`'s argon2id so the rest
/// of the codebase depends on one call surface. Swap the impl here
/// without touching callers.
class PasswordHasher {
  PasswordHasher({Argon2idParams? params, Random? rng})
    : _params = params ?? Argon2idParams.production,
      _rng = rng ?? Random.secure();

  final Argon2idParams _params;
  final Random _rng;

  Argon2id _algorithm() => Argon2id(
    memory: _params.memoryKib,
    parallelism: _params.parallelism,
    iterations: _params.iterations,
    hashLength: _params.hashLengthBytes,
  );

  /// Returns an encoded hash string: `$argon2id$m=..,t=..,p=..$salt$hash`
  /// (our own compact encoding — we control both sides).
  Future<String> hash(String password) async {
    final salt = _randomSalt();
    final key = await _algorithm().deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final hashBytes = await key.extractBytes();
    return _encode(salt, hashBytes);
  }

  /// Verify [password] against a stored [encodedHash]. Always runs a
  /// real argon2id computation even on format errors so the caller
  /// cannot distinguish "bad hash" from "bad password" via timing.
  Future<bool> verify(String password, String encodedHash) async {
    final parts = _tryDecode(encodedHash);
    if (parts == null) {
      // Dummy verify to keep timing flat.
      await _algorithm().deriveKeyFromPassword(
        password: password,
        nonce: List<int>.filled(_params.saltLengthBytes, 0),
      );
      return false;
    }
    final (salt, expected) = parts;
    final key = await _algorithm().deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final actual = await key.extractBytes();
    return _constantTimeEquals(actual, expected);
  }

  /// Runs a real hash against a throwaway input. Used by
  /// [LocalAuthService.signIn] when the email doesn't exist so timing
  /// matches the success path.
  Future<void> dummyVerify() async {
    await _algorithm().deriveKeyFromPassword(
      password: 'dummy-password-for-timing',
      nonce: List<int>.filled(_params.saltLengthBytes, 0),
    );
  }

  List<int> _randomSalt() =>
      List<int>.generate(_params.saltLengthBytes, (_) => _rng.nextInt(256));

  String _encode(List<int> salt, List<int> hash) {
    final p = _params;
    final saltB64 = base64Url.encode(salt);
    final hashB64 = base64Url.encode(hash);
    final header = 'm=${p.memoryKib},t=${p.iterations},p=${p.parallelism}';
    return ['argon2id', header, saltB64, hashB64].join(r'$');
  }

  (List<int>, List<int>)? _tryDecode(String encoded) {
    try {
      final parts = encoded.split(r'$');
      if (parts.length != 4 || parts[0] != 'argon2id') return null;
      final salt = base64Url.decode(parts[2]);
      final hash = base64Url.decode(parts[3]);
      return (salt, hash);
    } catch (_) {
      return null;
    }
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
