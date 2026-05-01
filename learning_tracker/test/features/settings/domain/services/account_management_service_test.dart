import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/settings/domain/services/account_management_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockFirebaseFirestore mockFirestore;
  late UserDatabase db;
  late AccountManagementService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
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

  group('signOut', () {
    test('clears onboarding state from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
        'add_track_step': '1',
      });

      await service.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('onboarding_complete'), isFalse);
      expect(prefs.containsKey('add_track_step'), isFalse);
    });

    test('preserves local database data after sign out', () async {
      // Insert test profile
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'test-uid',
        displayName: 'Test User',
        userMode: 'adult',
        updatedAt: DateTime.now(),
      );

      await service.signOut();

      // Verify local data is still there
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'test-uid',
      );
      expect(profile, isNotNull);
      expect(profile!.displayName, 'Test User');
    });
  });

  group('deleteAccount', () {
    late MockCollectionReference mockUsersCollection;
    late MockDocumentReference mockUserDoc;

    setUp(() {
      mockUsersCollection = MockCollectionReference();
      mockUserDoc = MockDocumentReference();

      when(
        () => mockFirestore.collection('users'),
      ).thenReturn(mockUsersCollection);
      when(() => mockUsersCollection.doc('test-uid')).thenReturn(mockUserDoc);

      // Mock all subcollections queried by _deleteFirestoreUserData as empty
      for (final sub in [
        'learner_profiles',
        'profiles',
        'completions',
        'bookmarks',
        'settings',
        'goals',
        'rewards',
        'learning_ledger',
        'active_curricula',
        'curriculum_imports',
        'curriculum_tracks',
        'profile_programs',
        'notification_settings',
        'gamification_settings',
        'profile',
      ]) {
        final mockSubCollection = MockCollectionReference();
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockUserDoc.collection(sub)).thenReturn(mockSubCollection);
        when(
          () => mockSubCollection.get(),
        ).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.docs).thenReturn([]);
      }

      // Mock streak subcollection
      final mockStreakCollection = MockCollectionReference();
      final mockStreakDoc = MockDocumentReference();
      when(
        () => mockUserDoc.collection('streak'),
      ).thenReturn(mockStreakCollection);
      when(() => mockStreakCollection.doc('current')).thenReturn(mockStreakDoc);
      when(() => mockStreakDoc.delete()).thenAnswer((_) async {});

      when(() => mockUserDoc.delete()).thenAnswer((_) async {});
      when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});
    });

    test('deletes Firestore user data', () async {
      await service.deleteAccount('test-uid');

      verify(() => mockUserDoc.delete()).called(1);
    });

    test('deletes Firebase Auth account', () async {
      await service.deleteAccount('test-uid');

      verify(() => mockAuthRepo.deleteAccount()).called(1);
    });

    test('clears local database', () async {
      // Insert test data
      await db.userProfileDao.upsertProfile(
        firebaseUid: 'test-uid',
        displayName: 'Test User',
        userMode: 'adult',
        updatedAt: DateTime.now(),
      );

      await service.deleteAccount('test-uid');

      // Verify local data is gone
      final profile = await db.userProfileDao.getUserProfileByFirebaseUid(
        'test-uid',
      );
      expect(profile, isNull);
    });
  });

  group('changePassword', () {
    test('calls authRepository.changePassword', () async {
      when(
        () => mockAuthRepo.changePassword('newPass'),
      ).thenAnswer((_) async {});

      await service.changePassword('newPass');

      verify(() => mockAuthRepo.changePassword('newPass')).called(1);
    });
  });

  group('reauthenticateWithEmail', () {
    test('calls authRepository.reauthenticateWithEmail', () async {
      when(
        () => mockAuthRepo.reauthenticateWithEmail('a@b.com', 'pass'),
      ).thenAnswer((_) async {});

      await service.reauthenticateWithEmail('a@b.com', 'pass');

      verify(
        () => mockAuthRepo.reauthenticateWithEmail('a@b.com', 'pass'),
      ).called(1);
    });
  });

  group('linkGoogleProvider', () {
    test('calls authRepository.linkGoogleProvider', () async {
      when(() => mockAuthRepo.linkGoogleProvider()).thenAnswer((_) async {});

      await service.linkGoogleProvider();

      verify(() => mockAuthRepo.linkGoogleProvider()).called(1);
    });
  });

  group('linkEmailProvider', () {
    test('calls authRepository.linkEmailProvider', () async {
      when(
        () => mockAuthRepo.linkEmailProvider('a@b.com', 'pass'),
      ).thenAnswer((_) async {});

      await service.linkEmailProvider('a@b.com', 'pass');

      verify(() => mockAuthRepo.linkEmailProvider('a@b.com', 'pass')).called(1);
    });
  });

  group('getLinkedProviders', () {
    test('returns providers from authRepository', () {
      when(
        () => mockAuthRepo.getLinkedProviders(),
      ).thenReturn(['password', 'google.com']);

      final providers = service.getLinkedProviders();

      expect(providers, ['password', 'google.com']);
    });
  });
}
