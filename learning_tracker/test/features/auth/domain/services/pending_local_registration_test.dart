/// Tests for [PendingLocalRegistration] JSON parsing and serialization.
///
/// Only covers the pure-logic surface of pending_local_signup.dart —
/// the parts that do not require platform channels or WidgetRef.
///
/// Covers:
///  - [PendingLocalRegistration.tryParse] with valid JSON
///  - [PendingLocalRegistration.tryParse] with missing fields
///  - [PendingLocalRegistration.tryParse] with null / empty input
///  - [PendingLocalRegistration.tryParse] with invalid JSON
///  - [PendingLocalRegistration.toJson] round-trip
///
/// Also covers [PendingLocalSignupStore] SharedPreferences helpers:
///  - readPayload / writePayload / clearPayload
///  - tryReserveEmail / releaseEmail
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/auth/domain/services/pending_local_signup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

    test('returns null when accountId is missing', () {
      final json = jsonEncode({
        'dbFileName': 'db.sqlite',
        'email': 'a@b.com',
        'displayName': 'Alice',
      });
      expect(PendingLocalRegistration.tryParse(json), isNull);
    });

    test('returns null when dbFileName is missing', () {
      final json = jsonEncode({
        'accountId': 'acc-123',
        'email': 'a@b.com',
        'displayName': 'Alice',
      });
      expect(PendingLocalRegistration.tryParse(json), isNull);
    });

    test('returns null when email is missing', () {
      final json = jsonEncode({
        'accountId': 'acc-123',
        'dbFileName': 'db.sqlite',
        'displayName': 'Alice',
      });
      expect(PendingLocalRegistration.tryParse(json), isNull);
    });

    test('returns null when displayName is missing', () {
      final json = jsonEncode({
        'accountId': 'acc-123',
        'dbFileName': 'db.sqlite',
        'email': 'a@b.com',
      });
      expect(PendingLocalRegistration.tryParse(json), isNull);
    });

    test('returns valid registration for complete JSON', () {
      final json = jsonEncode({
        'accountId': 'acc-123',
        'dbFileName': 'learning_tracker_abc.sqlite',
        'email': 'alice@example.com',
        'displayName': 'Alice',
      });

      final result = PendingLocalRegistration.tryParse(json);
      expect(result, isNotNull);
      expect(result!.accountId, 'acc-123');
      expect(result.dbFileName, 'learning_tracker_abc.sqlite');
      expect(result.email, 'alice@example.com');
      expect(result.displayName, 'Alice');
    });
  });

  group('PendingLocalRegistration.toJson / round-trip', () {
    test('toJson produces parseable JSON', () {
      const reg = PendingLocalRegistration(
        accountId: 'acc-xyz',
        dbFileName: 'db.sqlite',
        email: 'bob@example.com',
        displayName: 'Bob',
      );

      final json = jsonEncode(reg.toJson());
      final restored = PendingLocalRegistration.tryParse(json);

      expect(restored, isNotNull);
      expect(restored!.accountId, reg.accountId);
      expect(restored.dbFileName, reg.dbFileName);
      expect(restored.email, reg.email);
      expect(restored.displayName, reg.displayName);
    });
  });

  // ─── PendingLocalSignupStore SharedPreferences helpers ────────────────────

  group('PendingLocalSignupStore', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('readPayload returns null when nothing stored', () async {
      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result, isNull);
    });

    test(
      'writePayload then readPayload returns the stored registration',
      () async {
        const reg = PendingLocalRegistration(
          accountId: 'acc-123',
          dbFileName: 'lt_abc.sqlite',
          email: 'carol@example.com',
          displayName: 'Carol',
        );

        await PendingLocalSignupStore.writePayload(prefs, reg);
        final result = await PendingLocalSignupStore.readPayload(prefs);

        expect(result, isNotNull);
        expect(result!.accountId, reg.accountId);
        expect(result.email, reg.email);
      },
    );

    test('clearPayload removes the stored registration', () async {
      const reg = PendingLocalRegistration(
        accountId: 'acc-999',
        dbFileName: 'lt_xyz.sqlite',
        email: 'dan@example.com',
        displayName: 'Dan',
      );
      await PendingLocalSignupStore.writePayload(prefs, reg);
      await PendingLocalSignupStore.clearPayload(prefs);

      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result, isNull);
    });

    test('tryReserveEmail succeeds when email not yet reserved', () async {
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'eve@example.com',
      );
      expect(ok, isTrue);
    });

    test('tryReserveEmail fails when email already reserved', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'eve@example.com');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'EVE@example.com',
      );
      expect(ok, isFalse);
    });

    test('tryReserveEmail is case-insensitive', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'Frank@Example.Com');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'frank@example.com',
      );
      expect(ok, isFalse);
    });

    test(
      'releaseEmail allows re-reservation of previously held email',
      () async {
        await PendingLocalSignupStore.tryReserveEmail(
          prefs,
          'grace@example.com',
        );
        await PendingLocalSignupStore.releaseEmail(prefs, 'grace@example.com');
        final ok = await PendingLocalSignupStore.tryReserveEmail(
          prefs,
          'grace@example.com',
        );
        expect(ok, isTrue);
      },
    );

    test('releaseEmail is a no-op for unknown email', () async {
      // Should not throw.
      await PendingLocalSignupStore.releaseEmail(prefs, 'nobody@example.com');
    });

    test('multiple emails can be reserved simultaneously', () async {
      final ok1 = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'alice@x.com',
      );
      final ok2 = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'bob@x.com',
      );
      expect(ok1, isTrue);
      expect(ok2, isTrue);
    });
  });
}
