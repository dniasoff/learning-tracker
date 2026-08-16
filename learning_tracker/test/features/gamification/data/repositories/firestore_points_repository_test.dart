import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/data_export_firestore_test_support.dart';

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

  group(
    'getGlobalTotal — wired to FirestorePointsLedgerRepository.getBalance',
    () {
      // FirestorePointsLedgerRepository landed since this class was first
      // built as a stub — getGlobalTotal now delegates to it (see the class
      // doc comment). getCurriculumTotal / getDerivedTotal / getCurriculumBreakdown
      // remain unavailable (points_ledger carries no curriculumId field) and
      // are covered in the group below.

      test(
        'not ready (no active account/profile): throws instead of returning 0',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          await expectLater(
            adapter.getGlobalTotal(),
            throwsA(isA<PointsRepositoryNotReadyException>()),
          );
        },
      );

      group('ready (active account + profile)', () {
        const uid = 'uid-1';
        const profileDocId = testProfileId;

        late FakeFirebaseFirestore firestore;
        late ProviderContainer container;
        late FirestorePointsRepository adapter;

        setUp(() {
          firestore = FakeFirebaseFirestore();
          container = ProviderContainer(
            overrides: [
              activeAccountFirebaseProvider.overrideWith(
                (ref) async => AccountFirebaseHandles(
                  app: MockFirebaseApp(),
                  firestore: firestore,
                  auth: MockFirebaseAuthHandle(),
                  uid: uid,
                ),
              ),
            ],
          );
          container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
          adapter = buildAdapter(container);
        });

        tearDown(() => container.dispose());

        test('sums and clamps the ledger — mirrors PointsBalanceDao\'s stored '
            'balance for the same ledger contents', () async {
          final ledger = FirestorePointsLedgerRepository(
            firestore: firestore,
            uid: uid,
            profileId: profileDocId,
          );
          await ledger.append(
            entryKind: 'completion',
            delta: 10,
            createdAt: DateTime.utc(2026, 4, 10, 9),
          );
          await ledger.append(
            entryKind: 'redemption_debit',
            delta: -3,
            createdAt: DateTime.utc(2026, 4, 11, 9),
          );

          expect(await adapter.getGlobalTotal(), 7);
        });

        test('empty ledger derives a 0 balance', () async {
          expect(await adapter.getGlobalTotal(), 0);
        });

        test(
          'clamps a net-negative ledger at 0 rather than going negative',
          () async {
            final ledger = FirestorePointsLedgerRepository(
              firestore: firestore,
              uid: uid,
              profileId: profileDocId,
            );
            await ledger.append(
              entryKind: 'redemption_debit',
              delta: -5,
              createdAt: DateTime.utc(2026, 4, 10, 9),
            );

            expect(await adapter.getGlobalTotal(), 0);
          },
        );
      });
    },
  );

  group('every other read method — unavailable regardless of readiness', () {
    // points_ledger carries no curriculumId field (see
    // PointsRepositoryUnavailableException's doc comment) — every
    // per-curriculum method throws unconditionally, whether or not an
    // active account/profile is resolved.

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

    group(
      'ready (active account + profile) — per-curriculum methods still throw',
      () {
        const uid = 'uid-1';
        const profileDocId = testProfileId;

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

        test('getCurriculumTotal still throws — a schema gap (no curriculumId '
            'field on points_ledger), not a readiness gap', () async {
          expect(
            () => adapter.getCurriculumTotal('bavli'),
            throwsA(isA<PointsRepositoryUnavailableException>()),
          );
        });
      },
    );
  });
}
