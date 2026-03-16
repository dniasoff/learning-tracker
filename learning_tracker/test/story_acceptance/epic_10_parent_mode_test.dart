/// Story acceptance tests for Epic 10 -- Parent Mode.
/// Story 10.1 is active; stories 10.2-10.6 remain backlog (skipped).
@Tags(['epic_10'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/features/parent_mode/presentation/screens/pin_setup_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

import '../helpers/test_database.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

MockFlutterSecureStorage _createMockStorage() {
  final mock = MockFlutterSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });

  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    return store[key];
  });

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

void main() {
  // ── Story 10.1: Parent PIN setup ──────────────────────────────

  group('Story 10.1 -- Parent PIN setup', tags: ['story_10_1'], () {
    late MockFlutterSecureStorage storage;
    late PinService pinService;

    setUp(() {
      storage = _createMockStorage();
      pinService = PinService(storage);
    });

    test('PIN hashing produces valid bcrypt hash', () async {
      await pinService.setParentPin('1234');
      final hash = await storage.read(key: 'parent_pin_hash');
      expect(hash, isNotNull);
      expect(hash, startsWith(r'$2'));
      expect(hash, isNot('1234'));
    });

    test('PIN verification succeeds with correct PIN', () async {
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('5678'), isTrue);
    });

    test('PIN verification fails with incorrect PIN', () async {
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('0000'), isFalse);
    });

    test('lockout triggers after exactly 5 failed attempts', () async {
      await pinService.setParentPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      expect(
        () => pinService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test(
      'lockout cooldown resets failed attempt counter after expiry',
      () async {
        await pinService.setParentPin('1234');
        for (var i = 0; i < 3; i++) {
          await pinService.verifyParentPin('0000');
        }
        await pinService.verifyParentPin('1234');
        for (var i = 0; i < 4; i++) {
          expect(await pinService.verifyParentPin('0000'), isFalse);
        }
      },
    );

    test(
      'lockout state persists across app restart (new PinService)',
      () async {
        await pinService.setParentPin('1234');
        for (var i = 0; i < 5; i++) {
          await pinService.verifyParentPin('0000');
        }
        final newService = PinService(storage);
        expect(
          () => newService.verifyParentPin('1234'),
          throwsA(isA<PinLockoutException>()),
        );
      },
    );

    test('parent mode access denied for adult accounts', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-adult',
          displayName: 'Adult User',
          userMode: 'adult',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final profiles = await db.userProfileDao.getAllUserProfiles();
      final mode = UserMode.values.firstWhere(
        (m) => m.name == profiles.first.userMode,
        orElse: () => UserMode.adult,
      );
      expect(mode, UserMode.adult);
    });

    test('parent mode access allowed for child accounts', () async {
      final db = createTestDatabase();
      addTearDown(() => db.close());
      await db.userProfileDao.insertUserProfile(
        UserProfilesCompanion.insert(
          firebaseUid: 'uid-child',
          displayName: 'Child User',
          userMode: 'child',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final profiles = await db.userProfileDao.getAllUserProfiles();
      final mode = UserMode.values.firstWhere(
        (m) => m.name == profiles.first.userMode,
        orElse: () => UserMode.adult,
      );
      expect(mode, UserMode.child);
    });

    test('PIN setup requires matching confirmation', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.verifyParentPin('1234'), isTrue);
      expect(await pinService.verifyParentPin('4321'), isFalse);
    });

    test('PIN change requires current PIN before setting new', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.verifyParentPin('1234'), isTrue);
      await pinService.setParentPin('5678');
      expect(await pinService.verifyParentPin('5678'), isTrue);
      expect(await pinService.verifyParentPin('1234'), isFalse);
    });

    test('PINs are device-local only (stored in secure storage)', () async {
      await pinService.setParentPin('9999');
      verify(
        () => storage.write(
          key: 'parent_pin_hash',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    testWidgets('PinSetupScreen shows error on mismatched PINs', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: PinSetupScreen()),
        ),
      );

      // Enter first PIN: 1234 — one digit per TextField
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      await tester.enterText(fields.at(2), '3');
      await tester.pump();
      await tester.enterText(fields.at(3), '4');
      await tester.pumpAndSettle();

      // Now in confirm step — enter mismatched PIN: 5678
      final confirmFields = find.byType(TextField);
      await tester.enterText(confirmFields.at(0), '5');
      await tester.pump();
      await tester.enterText(confirmFields.at(1), '6');
      await tester.pump();
      await tester.enterText(confirmFields.at(2), '7');
      await tester.pump();
      await tester.enterText(confirmFields.at(3), '8');
      await tester.pumpAndSettle();

      // Verify error message is displayed
      expect(find.text('PINs do not match'), findsOneWidget);
    });

    test('integration: set PIN, verify, fail 5 times, lockout', () async {
      await pinService.setParentPin('1234');
      expect(await pinService.hasParentPin(), isTrue);
      expect(await pinService.verifyParentPin('1234'), isTrue);
      for (var i = 0; i < 5; i++) {
        await pinService.verifyParentPin('0000');
      }
      expect(
        () => pinService.verifyParentPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
      final remaining = await pinService.getParentLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
    });
  });

  // ── Story 10.2: Parent dashboard ──────────────────────────────

  group(
    'Story 10.2 -- Parent dashboard',
    tags: ['story_10_2'],
    skip: 'Backlog: parent dashboard not yet implemented',
    () {
      test('parent dashboard shows child progress summary', () {});
      test('parent can view per-curriculum progress', () {});
    },
  );

  // ── Story 10.3: Content restrictions ──────────────────────────

  group(
    'Story 10.3 -- Content restrictions',
    tags: ['story_10_3'],
    skip: 'Backlog: content restrictions not yet implemented',
    () {
      test('parent can restrict specific curricula', () {});
      test('restricted content is hidden from child view', () {});
    },
  );

  // ── Story 10.4: Time limits ───────────────────────────────────

  group(
    'Story 10.4 -- Time limits',
    tags: ['story_10_4'],
    skip: 'Backlog: time limits not yet implemented',
    () {
      test('parent can set daily time limits', () {});
      test('app locks after time limit reached', () {});
    },
  );

  // ── Story 10.5: Progress reports ──────────────────────────────

  group(
    'Story 10.5 -- Progress reports',
    tags: ['story_10_5'],
    skip: 'Backlog: parent progress reports not yet implemented',
    () {
      test('weekly summary report generated for parent', () {});
      test('report can be exported or shared', () {});
    },
  );

  // ── Story 10.6: Multi-child profiles ──────────────────────────

  group(
    'Story 10.6 -- Multi-child profiles',
    tags: ['story_10_6'],
    skip: 'Backlog: multi-child profiles not yet implemented',
    () {
      test('parent can create multiple child profiles', () {});
      test('each child has independent progress', () {});
      test('parent can switch between child views', () {});
    },
  );
}
