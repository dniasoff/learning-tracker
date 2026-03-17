/// Story acceptance tests for Epic 14 -- Settings.
@Tags(['epic_14'])
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
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

void main() {
  // ── Story 14.1: Settings screen ───────────────────────────────

  group(
    'Story 14.1 -- Settings screen',
    tags: ['story_14_1'],
    skip: 'Backlog: settings screen not yet implemented',
    () {
      test('settings screen displays all preference categories', () {
        // TODO: verify settings screen structure
      });

      test('user can change user mode (child/adult)', () {
        // TODO: verify mode toggle persists
      });

      test('user can manage active curricula from settings', () {
        // TODO: verify curriculum activation from settings
      });
    },
  );

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
