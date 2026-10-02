// Mirror test for `lib/data/firestore/tutor_scope_grant_providers.dart`
// (AG-5), Story 4.2a (DNI-523): the grant source is built only from the
// active account's handle, and "not ready" is null, never an error.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/tutor_scope_grant_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_tutor_scope_grant_source.dart';
import 'package:mocktail/mocktail.dart';

class _MockApp extends Mock implements FirebaseApp {}

class _MockAuth extends Mock implements FirebaseAuth {}

ProviderContainer _container(
  Future<AccountFirebaseHandles?> Function() handles,
) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [activeAccountFirebaseProvider.overrideWith((ref) => handles())],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('no active account resolves null (not ready)', () async {
    final container = _container(() async => null);
    expect(await container.read(tutorScopeGrantSourceProvider.future), isNull);
  });

  test('an unauthenticated account resolves null, not an error', () async {
    final container = _container(
      () async => throw const AccountNotAuthenticatedException('acc-1'),
    );
    expect(await container.read(tutorScopeGrantSourceProvider.future), isNull);
  });

  test('the source listens as the handle\'s live Auth uid', () async {
    final handles = AccountFirebaseHandles(
      app: _MockApp(),
      firestore: FakeFirebaseFirestore(),
      auth: _MockAuth(),
      uid: 'tutor-live-uid',
    );
    final container = _container(() async => handles);
    final source = await container.read(tutorScopeGrantSourceProvider.future);
    expect(
      source,
      isA<FirestoreTutorScopeGrantSource>().having(
        (s) => s.tutorUid,
        'tutorUid',
        'tutor-live-uid',
      ),
    );
  });

  test('any other handle failure surfaces as an error', () async {
    final container = _container(() async => throw StateError('boom'));
    await expectLater(
      container.read(tutorScopeGrantSourceProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  test('re-exports the access-denied classifier', () {
    expect(isLearnerScopeAccessDenied(StateError('x')), isFalse);
  });
}
