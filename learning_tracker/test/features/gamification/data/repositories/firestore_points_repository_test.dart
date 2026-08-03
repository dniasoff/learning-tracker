import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  FirestorePointsRepository buildAdapter(ProviderContainer container) {
    final adapterProvider = Provider<FirestorePointsRepository>(
      (ref) => FirestorePointsRepository(ref: ref),
    );
    return container.read(adapterProvider);
  }

  group('deriveBalance — pure, ready for the future ledger reader', () {
    test('sums positive deltas', () {
      expect(FirestorePointsRepository.deriveBalance([10, 5, 3]), 18);
    });

    test('returns 0 for an empty ledger', () {
      expect(FirestorePointsRepository.deriveBalance(const []), 0);
    });

    test('clamps at 0 — mirrors PointsBalanceDao._applyDeltaInTransaction / '
        '.reDeriveBalanceFromLedger\'s "balance is never negative" rule', () {
      expect(FirestorePointsRepository.deriveBalance([10, -30]), 0);
    });

    test('clamps at the upper bound (1 << 30), matching the Drift rule', () {
      expect(FirestorePointsRepository.deriveBalance([1 << 31]), 1 << 30);
    });

    test('a net-zero ledger derives a 0 balance without going negative', () {
      expect(FirestorePointsRepository.deriveBalance([5, -5]), 0);
    });
  });

  group('every read method — unavailable regardless of readiness', () {
    // No FirestorePointsLedgerRepository exists yet under
    // lib/data/repositories/ (see PointsRepositoryUnavailableException's
    // doc comment) — every method throws unconditionally, whether or not
    // an active account/profile is resolved.

    test('not ready: getGlobalTotal throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      expect(
        () => adapter.getGlobalTotal(),
        throwsA(isA<PointsRepositoryUnavailableException>()),
      );
    });

    test('not ready: getCurriculumTotal throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      expect(
        () => adapter.getCurriculumTotal('bavli'),
        throwsA(isA<PointsRepositoryUnavailableException>()),
      );
    });

    test('not ready: getDerivedTotal throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      expect(
        () => adapter.getDerivedTotal(),
        throwsA(isA<PointsRepositoryUnavailableException>()),
      );
    });

    test('not ready: getCurriculumBreakdown throws', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final adapter = buildAdapter(container);

      expect(
        () => adapter.getCurriculumBreakdown(),
        throwsA(isA<PointsRepositoryUnavailableException>()),
      );
    });

    group('ready (active account + profile) — still throws', () {
      const uid = 'uid-1';
      const profileDocId = 'profile-ulid-1';

      late ProviderContainer container;
      late FirestorePointsRepository adapter;

      AccountFirebaseHandles handles() {
        return AccountFirebaseHandles(
          app: MockFirebaseApp(),
          firestore: FakeFirebaseFirestore(),
          auth: MockFirebaseAuthHandle(),
          uid: uid,
        );
      }

      setUp(() {
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(),
            ),
          ],
        );
        container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
        adapter = buildAdapter(container);
      });

      tearDown(() => container.dispose());

      test('getGlobalTotal still throws — a missing-dependency gap, not a '
          'readiness gap', () async {
        expect(
          () => adapter.getGlobalTotal(),
          throwsA(isA<PointsRepositoryUnavailableException>()),
        );
      });

      test('getCurriculumTotal still throws', () async {
        expect(
          () => adapter.getCurriculumTotal('bavli'),
          throwsA(isA<PointsRepositoryUnavailableException>()),
        );
      });
    });
  });
}
