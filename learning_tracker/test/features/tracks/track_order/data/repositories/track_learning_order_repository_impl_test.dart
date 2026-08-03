/// Unit tests for [FirestoreTrackLearningOrderRepositoryAdapter]
/// (`lib/features/tracks/track_order/data/repositories/
/// track_learning_order_repository_impl.dart`) — the Firestore adapter over
/// [FirestoreTrackLearningOrderRepository] that implements
/// [TrackLearningOrderRepository]. Mirrors
/// `bookmark_repository_impl_test.dart`'s `FirestoreBookmarkRepositoryAdapter`
/// group structure (the reference pattern): a "not ready" group (no active
/// account/profile) and a "ready" group (active account/profile, backed by
/// `fake_cloud_firestore`).
///
/// Unlike every other adapter in this rewire wave, this one ALSO depends on
/// a real (in-memory) Drift [UserDatabase] — see the class doc comment
/// ("`int trackId` -> `CurriculumId`") for why: the domain interface is
/// keyed by the Drift-local `int trackId`, but the Firestore side is keyed
/// by [CurriculumId] (AD-25), so every method resolves the one via the
/// other before/regardless of Firestore readiness. Every test therefore
/// seeds a `curriculum_tracks` row first, exactly like
/// `TrackLearningOrderRepositoryImpl`'s own existing coverage would.
///
/// **What these tests cannot see**: `firestore_track_learning_order_
/// repository_test.dart` already documents `fake_cloud_firestore`'s general
/// limitations. This file only proves the adapter DELEGATES correctly
/// (including the trackId->curriculumId bridge and the not-ready fallback
/// values) — it does not re-prove the underlying repository's own Firestore
/// behavior (ordering, doc-id collision avoidance, etc).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/test_database.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

/// A level-1, non-leaf "seder" content item (`level2 == null`) — mirrors
/// `firestore_track_learning_order_repository_test.dart`'s `_seder` helper.
ContentItem _seder({
  required String sefariaRef,
  required String he,
  required String en,
  required int sortOrder,
}) => ContentItem(
  curriculumId: 'mishnayos',
  level1: sefariaRef,
  displayNameHe: he,
  displayNameEn: en,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
  isLeaf: false,
);

void main() {
  group('FirestoreTrackLearningOrderRepositoryAdapter', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';
    final now = DateTime.utc(2026, 5, 1);

    final allItems = [
      _seder(sefariaRef: 'Zeraim', he: 'זרעים', en: 'Zeraim', sortOrder: 1),
      _seder(sefariaRef: 'Moed', he: 'מועד', en: 'Moed', sortOrder: 2),
    ];

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    late UserDatabase database;
    late int trackId;

    setUp(() async {
      database = createTestDatabase();
      await seedProfileZero(database);
      final track = await database
          .into(database.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: 0,
              curriculumId: 'mishnayos',
              stateChangedAt: now,
              activatedAt: now,
            ),
          );
      trackId = track.id;
    });

    tearDown(() async {
      await database.close();
    });

    // Constructing the adapter requires a Ref (Riverpod's Ref is sealed —
    // it can only come from inside a provider callback), so tests obtain
    // one the same way production does: read a throwaway Provider that
    // builds the adapter from the container's ref. Mirrors
    // FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreTrackLearningOrderRepositoryAdapter buildAdapter(
      ProviderContainer container,
    ) {
      final adapterProvider =
          Provider<FirestoreTrackLearningOrderRepositoryAdapter>(
            (ref) => FirestoreTrackLearningOrderRepositoryAdapter(
              ref: ref,
              database: database,
            ),
          );
      return container.read(adapterProvider);
    }

    group('trackId -> curriculumId resolution', () {
      test(
        'an unknown trackId throws StateError regardless of readiness',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.getSedarimOrder(999999, allItems),
            throwsA(isA<StateError>()),
          );
        },
      );
    });

    group('not ready (no active account/profile)', () {
      test(
        'getSedarimOrder returns an empty list instead of throwing',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          final result = await adapter.getSedarimOrder(trackId, allItems);

          expect(result, isEmpty);
        },
      );

      test(
        'getMasechtosOrder returns an empty list instead of throwing',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          final result = await adapter.getMasechtosOrder(trackId, allItems);

          expect(result, isEmpty);
        },
      );

      test(
        'saveSedarimOrder throws TrackLearningOrderRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.saveSedarimOrder(trackId, [
              const LearningOrderItem(
                sefariaRef: 'Zeraim',
                displayNameHe: 'זרעים',
                displayNameEn: 'Zeraim',
                userSortOrder: 0,
                isCustomOrdered: true,
              ),
            ]),
            throwsA(isA<TrackLearningOrderRepositoryNotReadyException>()),
          );
        },
      );

      test('saveMasechtosOrder throws '
          'TrackLearningOrderRepositoryNotReadyException', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(
          () => adapter.saveMasechtosOrder(trackId, [
            const LearningOrderItem(
              sefariaRef: 'Zeraim',
              displayNameHe: 'זרעים',
              displayNameEn: 'Zeraim',
              userSortOrder: 0,
              isCustomOrdered: true,
            ),
          ]),
          throwsA(isA<TrackLearningOrderRepositoryNotReadyException>()),
        );
      });

      test(
        'resetToDefault throws TrackLearningOrderRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.resetToDefault(trackId),
            throwsA(isA<TrackLearningOrderRepositoryNotReadyException>()),
          );
        },
      );
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreTrackLearningOrderRepositoryAdapter adapter;

      setUp(() {
        firestore = FakeFirebaseFirestore();
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        container.read(activeProfileDocIdProvider.notifier).set(profileDocId);
        adapter = buildAdapter(container);
      });

      tearDown(() => container.dispose());

      test(
        'saveSedarimOrder delegates to FirestoreTrackLearningOrderRepository '
        'and writes a doc reachable at the expected Firestore path',
        () async {
          await adapter.saveSedarimOrder(trackId, [
            const LearningOrderItem(
              sefariaRef: 'Moed',
              displayNameHe: 'מועד',
              displayNameEn: 'Moed',
              userSortOrder: 0,
              isCustomOrdered: true,
            ),
            const LearningOrderItem(
              sefariaRef: 'Zeraim',
              displayNameHe: 'זרעים',
              displayNameEn: 'Zeraim',
              userSortOrder: 1,
              isCustomOrdered: true,
            ),
          ]);

          final doc = await firestore
              .collection('users')
              .doc(uid)
              .collection('learner_profiles')
              .doc(profileDocId)
              .collection('track_learning_order')
              .doc('mishnayos_Moed')
              .get();
          expect(doc.exists, isTrue);
        },
      );

      test(
        // Guards the exact risk the class doc comment's "int trackId ->
        // CurriculumId" section does not cover but
        // `DocIds.trackLearningOrderDocId`'s doc comment does:
        // `trackLearningOrderDocId` and `learningOrderDocId` compute the
        // IDENTICAL string for the same (curriculumId, sefariaRef) pair —
        // only the collection path disambiguates the two orderings. If this
        // adapter (or a future edit to it) ever routed a write through the
        // curriculum-level `learning_order` repository/collection instead
        // of `track_learning_order`, it would silently clobber rather than
        // fail. This proves the write never lands there.
        'saveSedarimOrder never writes into the curriculum-level '
        'learning_order collection, despite the identical doc-id string',
        () async {
          await adapter.saveSedarimOrder(trackId, [
            const LearningOrderItem(
              sefariaRef: 'Moed',
              displayNameHe: 'מועד',
              displayNameEn: 'Moed',
              userSortOrder: 0,
              isCustomOrdered: true,
            ),
          ]);

          final collidingDoc = await firestore
              .collection('users')
              .doc(uid)
              .collection('learner_profiles')
              .doc(profileDocId)
              .collection('learning_order')
              .doc('mishnayos_Moed')
              .get();
          expect(collidingDoc.exists, isFalse);
        },
      );

      test('saveSedarimOrder then getSedarimOrder round-trips the custom order '
          'through Firestore', () async {
        await adapter.saveSedarimOrder(trackId, [
          const LearningOrderItem(
            sefariaRef: 'Moed',
            displayNameHe: 'מועד',
            displayNameEn: 'Moed',
            userSortOrder: 0,
            isCustomOrdered: true,
          ),
          const LearningOrderItem(
            sefariaRef: 'Zeraim',
            displayNameHe: 'זרעים',
            displayNameEn: 'Zeraim',
            userSortOrder: 1,
            isCustomOrdered: true,
          ),
        ]);

        final result = await adapter.getSedarimOrder(trackId, allItems);

        expect(result.map((i) => i.sefariaRef), ['Moed', 'Zeraim']);
      });

      test('getSedarimOrder falls back to natural content order when no custom '
          'order is saved', () async {
        final result = await adapter.getSedarimOrder(trackId, allItems);

        expect(result.map((i) => i.sefariaRef), ['Zeraim', 'Moed']);
      });

      test('resetToDefault still throws UnimplementedError once ready '
          '(propagated, not re-solved)', () async {
        expect(
          () => adapter.resetToDefault(trackId),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });
  });
}
