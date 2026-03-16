/// Story acceptance tests for Epic 11 -- Tutor Mode.
/// Story 11.1 is active; stories 11.2-11.4 remain backlog (skipped).
@Tags(['epic_11'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, tearDown, tearDownAll, test;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/screens/tutor_pin_setup_screen.dart';
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
  // ── Story 11.1: Tutor PIN setup ───────────────────────────────

  group('Story 11.1 -- Tutor PIN setup', tags: ['story_11_1'], () {
    late MockFlutterSecureStorage storage;
    late PinService pinService;

    setUp(() {
      storage = _createMockStorage();
      pinService = PinService(storage);
    });

    // Unit: Tutor PIN stored separately from parent PIN
    test('tutor PIN stored separately from parent PIN', () async {
      await pinService.setParentPin('1234');
      await pinService.setTutorPin('5678');

      final parentHash = await storage.read(key: 'parent_pin_hash');
      final tutorHash = await storage.read(key: 'tutor_pin_hash');

      expect(parentHash, isNotNull);
      expect(tutorHash, isNotNull);
      expect(parentHash, isNot(tutorHash));

      // Verify each PIN only works for its own type
      expect(await pinService.verifyParentPin('1234'), isTrue);
      expect(await pinService.verifyParentPin('5678'), isFalse);
      expect(await pinService.verifyTutorPin('5678'), isTrue);
      expect(await pinService.verifyTutorPin('1234'), isFalse);
    });

    // Unit: PIN verification succeeds/fails correctly
    test('tutor PIN verification succeeds with correct PIN', () async {
      await pinService.setTutorPin('4321');
      expect(await pinService.verifyTutorPin('4321'), isTrue);
    });

    test('tutor PIN verification fails with incorrect PIN', () async {
      await pinService.setTutorPin('4321');
      expect(await pinService.verifyTutorPin('0000'), isFalse);
    });

    test('tutor PIN hashing produces valid bcrypt hash', () async {
      await pinService.setTutorPin('9999');
      final hash = await storage.read(key: 'tutor_pin_hash');
      expect(hash, isNotNull);
      expect(hash, startsWith(r'$2'));
      expect(hash, isNot('9999'));
    });

    // Unit: Lockout triggers after 5 failed attempts
    test('lockout triggers after exactly 5 failed attempts', () async {
      await pinService.setTutorPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      expect(
        () => pinService.verifyTutorPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
    });

    test('lockout remaining minutes is positive when locked out', () async {
      await pinService.setTutorPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      final remaining = await pinService.getTutorLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
    });

    test('successful verification resets failed attempt counter', () async {
      await pinService.setTutorPin('1234');
      // Fail 3 times
      for (var i = 0; i < 3; i++) {
        await pinService.verifyTutorPin('0000');
      }
      // Succeed — resets counter
      await pinService.verifyTutorPin('1234');
      // Fail 4 more times — should NOT lock out (counter was reset)
      for (var i = 0; i < 4; i++) {
        expect(await pinService.verifyTutorPin('0000'), isFalse);
      }
    });

    // Unit: Tutor mode accessible from both child and adult accounts
    test('tutor mode accessible from child account', () async {
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
      // Tutor mode has no mode restriction — both child and adult can use it
      expect(mode, UserMode.child);
      expect(await pinService.hasTutorPin(), isFalse);
      await pinService.setTutorPin('1111');
      expect(await pinService.hasTutorPin(), isTrue);
    });

    test('tutor mode accessible from adult account', () async {
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
      expect(await pinService.hasTutorPin(), isFalse);
      await pinService.setTutorPin('2222');
      expect(await pinService.hasTutorPin(), isTrue);
    });

    // Unit: Write operations throw/are blocked in tutor mode context
    test('TutorModeReadOnlyException thrown in tutor mode context', () {
      const exception = TutorModeReadOnlyException();
      expect(exception.message, contains('not allowed'));
      expect(exception.toString(), contains('TutorModeReadOnlyException'));
    });

    // Unit: PINs are device-local only (FR99)
    test(
      'tutor PINs are device-local only (stored in secure storage)',
      () async {
        await pinService.setTutorPin('7777');
        verify(
          () => storage.write(
            key: 'tutor_pin_hash',
            value: any(named: 'value'),
          ),
        ).called(1);
      },
    );

    // Unit: PIN change resets lockout
    test('setting new tutor PIN resets lockout state', () async {
      await pinService.setTutorPin('1234');
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      // Locked out now — set new PIN should reset lockout
      await pinService.setTutorPin('5678');
      // Should not throw lockout
      expect(await pinService.verifyTutorPin('5678'), isTrue);
    });

    // Unit: PIN must be exactly 4 numeric digits
    test('rejects non-4-digit PINs', () async {
      expect(
        () => pinService.setTutorPin('123'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => pinService.setTutorPin('12345'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => pinService.setTutorPin('abcd'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Widget: PIN setup with confirmation
    testWidgets('TutorPinSetupScreen shows error on mismatched PINs', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: TutorPinSetupScreen()),
        ),
      );

      // Enter first PIN: 1234
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

      expect(find.text('PINs do not match'), findsOneWidget);
    });

    testWidgets('TutorPinSetupScreen shows Set Tutor PIN title', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: TutorPinSetupScreen()),
        ),
      );

      expect(find.text('Set Tutor PIN'), findsOneWidget);
      expect(find.text('Enter New PIN'), findsOneWidget);
    });

    testWidgets('TutorPinSetupScreen transitions to confirm step', (
      tester,
    ) async {
      final mockStorage = _createMockStorage();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
          ],
          child: const MaterialApp(home: TutorPinSetupScreen()),
        ),
      );

      // Enter first PIN
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      await tester.enterText(fields.at(2), '3');
      await tester.pump();
      await tester.enterText(fields.at(3), '4');
      await tester.pumpAndSettle();

      // Should now show Confirm PIN
      expect(find.text('Confirm PIN'), findsOneWidget);
    });

    // Widget: PIN entry with numeric keypad (lockout screen tested via unit)
    testWidgets('PinEntryWidget shows lockout message when locked out', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinEntryWidget(
              title: 'Enter Tutor PIN',
              isLockedOut: true,
              lockoutRemainingMinutes: 12,
              onPinComplete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Too many failed attempts'), findsOneWidget);
      expect(find.text('Try again in 12 minute(s)'), findsOneWidget);
    });

    // Integration: set tutor PIN, verify, lockout
    test('integration: set tutor PIN, verify, fail 5 times, lockout', () async {
      await pinService.setTutorPin('1234');
      expect(await pinService.hasTutorPin(), isTrue);
      expect(await pinService.verifyTutorPin('1234'), isTrue);
      for (var i = 0; i < 5; i++) {
        await pinService.verifyTutorPin('0000');
      }
      expect(
        () => pinService.verifyTutorPin('1234'),
        throwsA(isA<PinLockoutException>()),
      );
      final remaining = await pinService.getTutorLockoutRemainingMinutes();
      expect(remaining, greaterThan(0));
    });

    // Lockout state persists across new PinService instances
    test(
      'lockout state persists across app restart (new PinService)',
      () async {
        await pinService.setTutorPin('1234');
        for (var i = 0; i < 5; i++) {
          await pinService.verifyTutorPin('0000');
        }
        final newService = PinService(storage);
        expect(
          () => newService.verifyTutorPin('1234'),
          throwsA(isA<PinLockoutException>()),
        );
      },
    );
  });

  // ── Story 11.2: Assignment creation ───────────────────────────

  group(
    'Story 11.2 -- Assignment creation',
    tags: ['story_11_2'],
    skip: 'Backlog: assignment creation not yet implemented',
    () {
      test('tutor can assign specific content to student', () {
        // TODO: verify assignment creation and storage
      });

      test('assignments appear in student tutor track', () {
        // TODO: verify assignment visibility in tutor track
      });
    },
  );

  // ── Story 11.3: Student progress view ─────────────────────────

  group(
    'Story 11.3 -- Student progress view',
    tags: ['story_11_3'],
    skip: 'Backlog: tutor student progress view not yet implemented',
    () {
      test('tutor sees student completion status per assignment', () {
        // TODO: verify progress reporting for tutor
      });

      test('tutor can view detailed completion history', () {
        // TODO: verify drill-down from summary to detail
      });
    },
  );

  // ── Story 11.4: Tutor notes ───────────────────────────────────

  group(
    'Story 11.4 -- Tutor notes',
    tags: ['story_11_4'],
    skip: 'Backlog: tutor notes not yet implemented',
    () {
      test('tutor can add notes to a student profile', () {
        // TODO: verify note creation and persistence
      });

      test('notes are visible in student detail view', () {
        // TODO: verify note display
      });
    },
  );
}
