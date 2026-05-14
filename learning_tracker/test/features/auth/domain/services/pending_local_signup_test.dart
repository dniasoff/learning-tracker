// Tests for PendingLocalRegistration and PendingLocalSignupStore.
// Covers toJson, tryParse, readPayload, writePayload, clearPayload,
// tryReserveEmail, releaseEmail — all SharedPreferences-backed paths.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/auth/domain/services/pending_local_signup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── PendingLocalRegistration ──────────────────────────────────────────────

  group('PendingLocalRegistration', () {
    const _sample = PendingLocalRegistration(
      accountId: 'acc-123',
      dbFileName: 'learning_tracker_abc.db',
      email: 'test@example.com',
      displayName: 'Test User',
    );

    test('toJson serialises all fields', () {
      final json = _sample.toJson();
      expect(json['accountId'], 'acc-123');
      expect(json['dbFileName'], 'learning_tracker_abc.db');
      expect(json['email'], 'test@example.com');
      expect(json['displayName'], 'Test User');
    });

    test('tryParse succeeds with valid JSON', () {
      final raw = jsonEncode(_sample.toJson());
      final parsed = PendingLocalRegistration.tryParse(raw);

      expect(parsed, isNotNull);
      expect(parsed!.accountId, 'acc-123');
      expect(parsed.dbFileName, 'learning_tracker_abc.db');
      expect(parsed.email, 'test@example.com');
      expect(parsed.displayName, 'Test User');
    });

    test('tryParse returns null for null input', () {
      expect(PendingLocalRegistration.tryParse(null), isNull);
    });

    test('tryParse returns null for empty string', () {
      expect(PendingLocalRegistration.tryParse(''), isNull);
    });

    test('tryParse returns null for malformed JSON', () {
      expect(PendingLocalRegistration.tryParse('{not valid}'), isNull);
    });

    test('tryParse returns null for invalid JSON', () {
      expect(PendingLocalRegistration.tryParse('not-json'), isNull);
    });

    test('tryParse returns null when required fields are missing', () {
      final partial = jsonEncode({'accountId': 'acc-123'});
      expect(PendingLocalRegistration.tryParse(partial), isNull);
    });

    test('tryParse returns null when only some required fields present', () {
      final partial = jsonEncode({
        'accountId': 'acc-123',
        'dbFileName': 'file.db',
        // email and displayName missing
      });
      expect(PendingLocalRegistration.tryParse(partial), isNull);
    });

    test('round-trip through JSON encoding preserves all fields', () {
      final raw = jsonEncode(_sample.toJson());
      final decoded = PendingLocalRegistration.tryParse(raw)!;

      expect(decoded.accountId, _sample.accountId);
      expect(decoded.dbFileName, _sample.dbFileName);
      expect(decoded.email, _sample.email);
      expect(decoded.displayName, _sample.displayName);
    });
  });

  group('PendingLocalRegistration.toJson', () {
    test('round-trips through toJson', () {
      const reg = PendingLocalRegistration(
        accountId: 'acc-1',
        dbFileName: 'db.sqlite',
        email: 'alice@example.com',
        displayName: 'Alice',
      );
      final json = reg.toJson();
      expect(json['accountId'], 'acc-1');
      expect(json['dbFileName'], 'db.sqlite');
      expect(json['email'], 'alice@example.com');
      expect(json['displayName'], 'Alice');
    });
  });

  group('PendingLocalRegistration.tryParse', () {
    test('round-trips from valid JSON', () {
      const reg = PendingLocalRegistration(
        accountId: 'acc-2',
        dbFileName: 'tracker.sqlite',
        email: 'bob@example.com',
        displayName: 'Bob',
      );
      final raw = jsonEncode(reg.toJson());
      final parsed = PendingLocalRegistration.tryParse(raw);

      expect(parsed, isNotNull);
      expect(parsed!.accountId, 'acc-2');
      expect(parsed.dbFileName, 'tracker.sqlite');
      expect(parsed.email, 'bob@example.com');
      expect(parsed.displayName, 'Bob');
    });
  });

  // ── PendingLocalSignupStore ───────────────────────────────────────────────

  group('PendingLocalSignupStore — SharedPreferences operations', () {
    test('writePayload and readPayload round-trip', () async {
      final prefs = await SharedPreferences.getInstance();
      const reg = PendingLocalRegistration(
        accountId: 'acc-999',
        dbFileName: 'db.db',
        email: 'x@example.com',
        displayName: 'X',
      );

      await PendingLocalSignupStore.writePayload(prefs, reg);
      final read = await PendingLocalSignupStore.readPayload(prefs);

      expect(read, isNotNull);
      expect(read!.accountId, 'acc-999');
      expect(read.email, 'x@example.com');
    });

    test('readPayload returns null when nothing written', () async {
      final prefs = await SharedPreferences.getInstance();
      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result, isNull);
    });

    test('writePayload then readPayload returns the same registration', () async {
      final prefs = await SharedPreferences.getInstance();
      const reg = PendingLocalRegistration(
        accountId: 'acc-3',
        dbFileName: 'learn.sqlite',
        email: 'carol@example.com',
        displayName: 'Carol',
      );

      await PendingLocalSignupStore.writePayload(prefs, reg);
      final result = await PendingLocalSignupStore.readPayload(prefs);

      expect(result, isNotNull);
      expect(result!.accountId, 'acc-3');
      expect(result.email, 'carol@example.com');
      expect(result.displayName, 'Carol');
    });

    test('clearPayload removes the stored payload', () async {
      final prefs = await SharedPreferences.getInstance();
      const reg = PendingLocalRegistration(
        accountId: 'acc-1',
        dbFileName: 'db.db',
        email: 'a@a.com',
        displayName: 'A',
      );

      await PendingLocalSignupStore.writePayload(prefs, reg);
      await PendingLocalSignupStore.clearPayload(prefs);
      expect(await PendingLocalSignupStore.readPayload(prefs), isNull);
    });
  });

  group('PendingLocalSignupStore.tryReserveEmail / releaseEmail', () {
    test('first reservation succeeds', () async {
      final prefs = await SharedPreferences.getInstance();
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'eve@example.com',
      );
      expect(ok, isTrue);
    });

    test('tryReserveEmail returns true for new email', () async {
      final prefs = await SharedPreferences.getInstance();
      final reserved = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'new@example.com',
      );
      expect(reserved, isTrue);
    });

    test('duplicate reservation fails', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'frank@example.com');
      final second = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'frank@example.com',
      );
      expect(second, isFalse);
    });

    test('tryReserveEmail returns false for already-reserved email', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'dup@example.com');
      final second = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'dup@example.com',
      );
      expect(second, isFalse);
    });

    test('case-insensitive duplicate detection', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'Grace@Example.COM');
      final second = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'grace@example.com',
      );
      expect(second, isFalse);
    });

    test('tryReserveEmail is case-insensitive', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'User@Example.COM');
      final second = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'user@example.com',
      );
      expect(second, isFalse);
    });

    test('can re-reserve after release', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'henry@example.com');
      await PendingLocalSignupStore.releaseEmail(prefs, 'henry@example.com');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'henry@example.com',
      );
      expect(ok, isTrue);
    });

    test('releaseEmail allows re-reservation after release', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'rel@example.com');
      await PendingLocalSignupStore.releaseEmail(prefs, 'rel@example.com');

      final canReserve = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'rel@example.com',
      );
      expect(canReserve, isTrue);
    });

    test('releasing a non-reserved email is a no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      // Should not throw
      await PendingLocalSignupStore.releaseEmail(
        prefs,
        'nobody@example.com',
      );
    });

    test('releaseEmail is case-insensitive', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'Mixed@Case.com');
      await PendingLocalSignupStore.releaseEmail(prefs, 'mixed@case.com');

      final canReserve = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'mixed@case.com',
      );
      expect(canReserve, isTrue);
    });

    test('multiple distinct emails can be reserved', () async {
      final prefs = await SharedPreferences.getInstance();
      final ok1 = await PendingLocalSignupStore.tryReserveEmail(prefs, 'ira@example.com');
      final ok2 = await PendingLocalSignupStore.tryReserveEmail(prefs, 'judy@example.com');
      expect(ok1, isTrue);
      expect(ok2, isTrue);
    });

    test('releasing one email does not affect others', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'kim@example.com');
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'lee@example.com');
      await PendingLocalSignupStore.releaseEmail(prefs, 'kim@example.com');

      // lee should still be reserved
      final leeDuplicate = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'lee@example.com',
      );
      expect(leeDuplicate, isFalse);

      // kim should be free
      final kimAgain = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'kim@example.com',
      );
      expect(kimAgain, isTrue);
    });
  });
}
