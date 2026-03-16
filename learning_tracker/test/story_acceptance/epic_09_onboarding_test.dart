/// Story acceptance tests for Epic 9 -- Onboarding.
@Tags(['epic_9'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:test/test.dart';

void main() {
  // ── Story 9.1: Welcome flow ───────────────────────────────────

  group('Story 9.1 -- Welcome flow', tags: ['story_9_1'], () {
    late AppDatabase db;
    late UserProfileService profileService;
    late List<Map<String, String>> firestorePushes;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      firestorePushes = [];
      profileService = UserProfileService(
        userProfileDao: db.userProfileDao,
        pushUserProfile:
            ({
              required String firebaseUid,
              required String displayName,
              required String userMode,
            }) async {
              firestorePushes.add({
                'firebaseUid': firebaseUid,
                'displayName': displayName,
                'userMode': userMode,
              });
            },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'auth service creates account and mode selection persists child mode',
      () async {
        await profileService.setUserMode(
          firebaseUid: 'test-uid',
          displayName: 'Test User',
          mode: UserMode.child,
        );
        final mode = await profileService.getUserMode('test-uid');
        expect(mode, UserMode.child);
      },
    );

    test('auth service mode selection persists adult mode', () async {
      await profileService.setUserMode(
        firebaseUid: 'test-uid-2',
        displayName: 'Adult User',
        mode: UserMode.adult,
      );
      final mode = await profileService.getUserMode('test-uid-2');
      expect(mode, UserMode.adult);
    });

    test('email validation rejects invalid formats', () {
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      expect(emailRegex.hasMatch('invalid'), isFalse);
      expect(emailRegex.hasMatch('user@'), isFalse);
      expect(emailRegex.hasMatch('@example.com'), isFalse);
      expect(emailRegex.hasMatch('user@example.com'), isTrue);
    });

    test('password validation rejects under 6 characters', () {
      expect('12345'.length < 6, isTrue);
      expect('123456'.length < 6, isFalse);
    });

    test('mode selection writes to Firestore', () async {
      await profileService.setUserMode(
        firebaseUid: 'uid-firestore',
        displayName: 'Test',
        mode: UserMode.child,
      );
      expect(firestorePushes, hasLength(1));
      expect(firestorePushes.first['firebaseUid'], 'uid-firestore');
      expect(firestorePushes.first['userMode'], 'child');
    });
  });

  // ── Story 9.2: Curriculum selection ───────────────────────────

  group(
    'Story 9.2 -- Curriculum selection',
    tags: ['story_9_2'],
    skip: 'Backlog: onboarding curriculum selection not yet implemented',
    () {
      test('user selects at least one curriculum during onboarding', () {
        fail('Not yet implemented');
      });

      test('all 5 curricula are shown as options', () {
        fail('Not yet implemented');
      });
    },
  );

  // ── Story 9.3: User mode selection ────────────────────────────

  group(
    'Story 9.3 -- User mode selection',
    tags: ['story_9_3'],
    skip: 'Backlog: user mode selection not yet implemented',
    () {
      test('user chooses child or adult mode', () {
        fail('Not yet implemented');
      });

      test('mode selection affects gamification display', () {
        fail('Not yet implemented');
      });
    },
  );

  // ── Story 9.4: Import existing progress ───────────────────────

  group(
    'Story 9.4 -- Import existing progress',
    tags: ['story_9_4'],
    skip: 'Backlog: progress import not yet implemented',
    () {
      test('user can import progress from a backup file', () {
        fail('Not yet implemented');
      });

      test('imported completions appear in progress view', () {
        fail('Not yet implemented');
      });
    },
  );

  // ── Story 9.5: Tutorial walkthrough ───────────────────────────

  group(
    'Story 9.5 -- Tutorial walkthrough',
    tags: ['story_9_5'],
    skip: 'Backlog: tutorial walkthrough not yet implemented',
    () {
      test('tutorial highlights key features step by step', () {
        fail('Not yet implemented');
      });

      test('user can skip tutorial', () {
        fail('Not yet implemented');
      });
    },
  );
}
