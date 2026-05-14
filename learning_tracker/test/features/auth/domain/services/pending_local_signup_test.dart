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

  // =========================================================================
  // PendingLocalRegistration
  // =========================================================================

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
    test('returns null for null input', () {
      expect(PendingLocalRegistration.tryParse(null), isNull);
    });

    test('returns null for empty string', () {
      expect(PendingLocalRegistration.tryParse(''), isNull);
    });

    test('returns null for invalid JSON', () {
      expect(PendingLocalRegistration.tryParse('not-json'), isNull);
    });

    test('returns null when required fields are missing', () {
      // Missing displayName
      const missingField =
          '{"accountId":"a","dbFileName":"f","email":"e@e.com"}';
      expect(PendingLocalRegistration.tryParse(missingField), isNull);
    });

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

  // =========================================================================
  // PendingLocalSignupStore — SharedPreferences-backed methods
  // =========================================================================

  group('PendingLocalSignupStore.readPayload / writePayload / clearPayload',
      () {
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

    test('clearPayload removes the written payload', () async {
      final prefs = await SharedPreferences.getInstance();
      const reg = PendingLocalRegistration(
        accountId: 'acc-4',
        dbFileName: 'lt.sqlite',
        email: 'dave@example.com',
        displayName: 'Dave',
      );

      await PendingLocalSignupStore.writePayload(prefs, reg);
      await PendingLocalSignupStore.clearPayload(prefs);
      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result, isNull);
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

    test('duplicate reservation fails', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'frank@example.com',
      );
      final second = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'frank@example.com',
      );
      expect(second, isFalse);
    });

    test('case-insensitive duplicate detection', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'Grace@Example.COM',
      );
      final second = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'grace@example.com',
      );
      expect(second, isFalse);
    });

    test('can re-reserve after release', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'henry@example.com',
      );
      await PendingLocalSignupStore.releaseEmail(
        prefs,
        'henry@example.com',
      );
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'henry@example.com',
      );
      expect(ok, isTrue);
    });

    test('releasing a non-reserved email is a no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      // Should not throw
      await PendingLocalSignupStore.releaseEmail(
        prefs,
        'nobody@example.com',
      );
    });

    test('multiple distinct emails can be reserved', () async {
      final prefs = await SharedPreferences.getInstance();
      final ok1 = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'ira@example.com',
      );
      final ok2 = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'judy@example.com',
      );
      expect(ok1, isTrue);
      expect(ok2, isTrue);
    });

    test('releasing one email does not affect others', () async {
      final prefs = await SharedPreferences.getInstance();
      await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'kim@example.com',
      );
      await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'lee@example.com',
      );
      await PendingLocalSignupStore.releaseEmail(
        prefs,
        'kim@example.com',
      );

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
