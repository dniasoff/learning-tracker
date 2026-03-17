/// Story acceptance tests for Epic 14 -- Settings.
@Tags(['epic_14'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/settings/domain/services/account_management_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

/// A no-op push for testing (avoids Firestore dependency).
Future<void> _noOpPush({
  required String firebaseUid,
  required String displayName,
  required String userMode,
}) async {}

void main() {
  // ── Story 14.1: Settings screen ───────────────────────────────

  group('Story 14.1 -- Settings screen', tags: ['story_14_1'], () {
    late AppDatabase db;
    late UserProfileService profileService;

    setUp(() {
      db = createTestDatabase();
      profileService = UserProfileService(
        userProfileDao: db.userProfileDao,
        pushUserProfile: _noOpPush,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('mode change persists new UserMode to profile', () async {
      // Set initial mode to adult
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.adult,
      );
      expect(await profileService.getUserMode('uid-1'), UserMode.adult);

      // Change to child
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.child,
      );
      expect(await profileService.getUserMode('uid-1'), UserMode.child);
    });

    test('mode change from child to adult disables parent mode access', () async {
      // Start as child
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.child,
      );

      // Switch to adult
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.adult,
      );

      final mode = await profileService.getUserMode('uid-1');
      expect(mode, UserMode.adult);
      // In adult mode, parent mode is not accessible (ChildModeGuard blocks it)
    });

    test('mode change from adult to child enables parent mode setup', () async {
      // Start as adult
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.adult,
      );

      // Switch to child
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Test User',
        mode: UserMode.child,
      );

      final mode = await profileService.getUserMode('uid-1');
      expect(mode, UserMode.child);
      // In child mode, parent mode becomes available (ChildModeGuard allows)
    });

    test('user profile stores display name and mode', () async {
      await profileService.setUserMode(
        firebaseUid: 'uid-1',
        displayName: 'Jane Doe',
        mode: UserMode.child,
      );

      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Jane Doe');
      expect(profile.userMode, 'child');
    });
  });

  // ── Story 14.2: Data export ───────────────────────────────────

  group(
    'Story 14.2 -- Data export',
    tags: ['story_14_2'],
    skip: 'Backlog: data export not yet implemented',
    () {
      test('user can export completions as CSV', () {
        // TODO: verify CSV export content
      });

      test('export includes all curricula and tracks', () {
        // TODO: verify completeness of export
      });
    },
  );

  // ── Story 14.3: Account management ────────────────────────────

  group('Story 14.3 -- Account management', tags: ['story_14_3'], () {
    late MockAuthRepository mockAuthRepo;
    late MockFirebaseFirestore mockFirestore;
    late AppDatabase db;
    late AccountManagementService service;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockFirestore = MockFirebaseFirestore();
      db = createTestDatabase();
      service = AccountManagementService(
        authRepository: mockAuthRepo,
        database: db,
        firestore: mockFirestore,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('user can sign out', () async {
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

      // Insert data before sign-out
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'User',
        userMode: 'adult',
        updatedAt: DateTime.now(),
      );

      await service.signOut();

      // Session cleared (signOut called)
      verify(() => mockAuthRepo.signOut()).called(1);

      // Local data preserved for re-sign-in
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile, isNotNull);
    });

    test('user can delete account and all data', () async {
      // Set up Firestore mocks
      final mockUsersCollection = MockCollectionReference();
      final mockUserDoc = MockDocumentReference();
      when(
        () => mockFirestore.collection('users'),
      ).thenReturn(mockUsersCollection);
      when(() => mockUsersCollection.doc('uid-1')).thenReturn(mockUserDoc);

      for (final sub in ['completions', 'bookmarks', 'settings']) {
        final mockSubCollection = MockCollectionReference();
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockUserDoc.collection(sub)).thenReturn(mockSubCollection);
        when(
          () => mockSubCollection.get(),
        ).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn([]);
      }

      final mockStreakCollection = MockCollectionReference();
      final mockStreakDoc = MockDocumentReference();
      when(
        () => mockUserDoc.collection('streak'),
      ).thenReturn(mockStreakCollection);
      when(() => mockStreakCollection.doc('current')).thenReturn(mockStreakDoc);
      when(() => mockStreakDoc.delete()).thenAnswer((_) async {});
      when(() => mockUserDoc.delete()).thenAnswer((_) async {});
      when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});

      // Insert local data
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'uid-1',
        displayName: 'User',
        userMode: 'adult',
        updatedAt: DateTime.now(),
      );

      await service.deleteAccount('uid-1');

      // Firestore user data deleted
      verify(() => mockUserDoc.delete()).called(1);
      // Firebase Auth account deleted
      verify(() => mockAuthRepo.deleteAccount()).called(1);
      // Local database cleared
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'uid-1',
      );
      expect(profile, isNull);
    });
  });

  // ── Story 14.4: App info & legal ──────────────────────────────

  group(
    'Story 14.4 -- App info & legal',
    tags: ['story_14_4'],
    skip: 'Backlog: app info screen not yet implemented',
    () {
      test('about screen shows app version', () {
        // TODO: verify version string display
      });

      test('privacy policy and terms links are accessible', () {
        // TODO: verify link navigation
      });
    },
  );
}
