import 'dart:math';

/// Generate a Crockford-base32 ULID (26 chars: 10 timestamp + 16 random).
///
/// Used to give append-only ledger rows a stable, lexicographically-sortable,
/// cross-device id. Story 25.2 (DNI-323) keys the `learning_ledger` UNIQUE
/// composite on `(profileId, ulid)`.
String newUlid([DateTime? now]) {
  final ts = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
  final rng = _rng;

  final sb = StringBuffer();
  // 10 timestamp chars (48 bits encoded in base32, msb-first).
  var t = ts;
  final tsChars = List<int>.filled(10, 0);
  for (var i = 9; i >= 0; i--) {
    tsChars[i] = t & 0x1f;
    t = t >> 5;
  }
  for (final c in tsChars) {
    sb.write(_alphabet[c]);
  }
  // 16 random chars (80 bits).
  for (var i = 0; i < 16; i++) {
    sb.write(_alphabet[rng.nextInt(32)]);
  }
  return sb.toString();
}

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
final Random _rng = Random.secure();
