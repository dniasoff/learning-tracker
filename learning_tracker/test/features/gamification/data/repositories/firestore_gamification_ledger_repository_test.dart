import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/gamification/data/repositories/firestore_gamification_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  FirestoreGamificationLedgerRepository buildAdapter(
    ProviderContainer container,
  ) {
    final adapterProvider = Provider<FirestoreGamificationLedgerRepository>(
      (ref) => FirestoreGamificationLedgerRepository(ref: ref),
    );
    return container.read(adapterProvider);
  }

  group('not ready (no active account/profile)', () {
    test(
      'getLifetimeLedger throws instead of returning an empty list',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        await expectLater(
          adapter.getLifetimeLedger(),
          throwsA(isA<GamificationLedgerNotReadyException>()),
        );
      },
    );

    test(
      'getCompletionStats throws instead of returning all-zero counts',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        await expectLater(
          adapter.getCompletionStats(CurriculumId.bavli),
          throwsA(isA<GamificationLedgerNotReadyException>()),
        );
      },
    );
  });

  group('ready (active account + profile)', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';

    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    late FirestoreGamificationLedgerRepository adapter;

    AccountFirebaseHandles handles() {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [
          activeAccountFirebaseProvider.overrideWith((ref) async => handles()),
        ],
      );
      container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
      adapter = buildAdapter(container);
    });

    tearDown(() => container.dispose());

    Future<void> writeEntry({
      required String ulid,
      required CurriculumId curriculumId,
      required String unitIdentifier,
      required bool isManual,
      int completionNumber = 1,
    }) async {
      final entry = LearningLedgerEntry(
        ulid: ulid,
        curriculumId: curriculumId,
        entryScope: 'unit',
        unitIdentifier: unitIdentifier,
        unitDisplayNameHe: 'he',
        unitDisplayNameEn: 'en',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 5, 1),
        completionNumber: completionNumber,
        markedBy: 'profile-ulid-1',
        isManual: isManual,
        source: CompletionSource.live,
      );
      await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileDocId)
          .collection('learning_ledger')
          .doc(ulid)
          .set(entry.toFirestore());
    }

    test(
      'getLifetimeLedger delegates to FirestoreLearningLedgerRepository',
      () async {
        await writeEntry(
          ulid: 'l1',
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'Berakhot.2a',
          isManual: false,
        );
        await writeEntry(
          ulid: 'l2',
          curriculumId: CurriculumId.mishnayos,
          unitIdentifier: 'Berakhot.1.1',
          isManual: true,
        );

        final ledger = await adapter.getLifetimeLedger();

        expect(ledger, hasLength(2));
      },
    );

    test(
      'getCompletionStats reports total/manual/auto scoped to one curriculum',
      () async {
        await writeEntry(
          ulid: 'l1',
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'Berakhot.2a',
          isManual: false,
        );
        await writeEntry(
          ulid: 'l2',
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'Berakhot.2b',
          isManual: true,
        );
        await writeEntry(
          ulid: 'l3',
          curriculumId: CurriculumId.mishnayos,
          unitIdentifier: 'Berakhot.1.1',
          isManual: false,
        );

        final stats = await adapter.getCompletionStats(CurriculumId.bavli);

        expect(stats, {'total': 2, 'manual': 1, 'auto': 1});
      },
    );
  });
}
