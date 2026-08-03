/// Unit tests for [FirestoreCurriculumTrackRepositoryAdapter]
/// (`lib/features/tracks/setup/data/repositories/
/// curriculum_track_repository_impl.dart`) — the Firestore adapter over
/// [FirestoreCurriculumTrackRepository]. Unlike every other adapter in this
/// rewire wave, this one implements no domain interface (none exists for
/// the curriculum-track lifecycle — see the class doc comment), so this
/// file exercises its own method surface directly. Mirrors
/// `bookmark_repository_impl_test.dart`'s `FirestoreBookmarkRepositoryAdapter`
/// group structure (the reference pattern): a "not ready" group (no active
/// account/profile) and a "ready" group (active account/profile, backed by
/// `fake_cloud_firestore`).
///
/// **What these tests cannot see**: `firestore_curriculum_track_repository_
/// test.dart` already documents `fake_cloud_firestore`'s general
/// limitations (no `resource.data` rules evaluation, no delete method to
/// test). This file only proves the adapter DELEGATES correctly (including
/// its not-ready fallback values) — it does not re-prove the underlying
/// repository's own Firestore behavior. The `watch*` methods' one-shot
/// provider-resolution limitation (no re-subscription if the active
/// account/profile changes mid-stream) is documented in the class doc
/// comment, not exercised here — proving it would require simulating a
/// provider-state change after a stream is already open, which adds
/// significant harness complexity for a scenario `activeProfileDocIdProvider`
/// itself flags as "not yet wired into production" (repository_providers.dart
/// library doc comment).
library;

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
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

void main() {
  group('FirestoreCurriculumTrackRepositoryAdapter', () {
    const uid = 'uid-1';
    const profileDocId = 'profile-ulid-1';

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    // Constructing the adapter requires a Ref (Riverpod's Ref is sealed —
    // it can only come from inside a provider callback), so tests obtain
    // one the same way production does: read a throwaway Provider that
    // builds the adapter from the container's ref. Mirrors
    // FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreCurriculumTrackRepositoryAdapter buildAdapter(
      ProviderContainer container,
    ) {
      final adapterProvider =
          Provider<FirestoreCurriculumTrackRepositoryAdapter>(
            (ref) => FirestoreCurriculumTrackRepositoryAdapter(ref: ref),
          );
      return container.read(adapterProvider);
    }

    group('not ready (no active account/profile)', () {
      test('getTrack returns null instead of throwing', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        final result = await adapter.getTrack(CurriculumId.mishnayos);

        expect(result, isNull);
      });

      test('isActive returns false', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        final result = await adapter.isActive(CurriculumId.mishnayos);

        expect(result, isFalse);
      });

      test('getAllTracks / getActiveTracks / getActiveCurriculumIds return '
          'empty lists', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(await adapter.getAllTracks(), isEmpty);
        expect(await adapter.getActiveTracks(), isEmpty);
        expect(await adapter.getActiveCurriculumIds(), isEmpty);
      });

      test('countActiveTracks returns 0', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final adapter = buildAdapter(container);

        expect(await adapter.countActiveTracks(), 0);
      });

      test(
        'watchTrack / watchAllTracks emit a single not-ready value',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            await adapter.watchTrack(CurriculumId.mishnayos).first,
            isNull,
          );
          expect(await adapter.watchAllTracks().first, isEmpty);
        },
      );

      test(
        'activateTrack throws CurriculumTrackRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.activateTrack(CurriculumId.mishnayos),
            throwsA(isA<CurriculumTrackRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'retireTrack throws CurriculumTrackRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.retireTrack(CurriculumId.mishnayos),
            throwsA(isA<CurriculumTrackRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'archiveTrack throws CurriculumTrackRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.archiveTrack(CurriculumId.mishnayos),
            throwsA(isA<CurriculumTrackRepositoryNotReadyException>()),
          );
        },
      );

      test(
        'resetPace throws CurriculumTrackRepositoryNotReadyException',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final adapter = buildAdapter(container);

          expect(
            () => adapter.resetPace(CurriculumId.mishnayos),
            throwsA(isA<CurriculumTrackRepositoryNotReadyException>()),
          );
        },
      );
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreCurriculumTrackRepositoryAdapter adapter;

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

      test('activateTrack delegates to FirestoreCurriculumTrackRepository and '
          'writes a doc reachable at the expected Firestore path', () async {
        final track = await adapter.activateTrack(CurriculumId.mishnayos);

        expect(track.isActive, isTrue);
        final doc = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(profileDocId)
            .collection('curriculum_tracks')
            .doc('mishnayos')
            .get();
        expect(doc.exists, isTrue);
      });

      test(
        'activateTrack then getTrack round-trips through Firestore',
        () async {
          await adapter.activateTrack(CurriculumId.mishnayos);

          final track = await adapter.getTrack(CurriculumId.mishnayos);

          expect(track, isNotNull);
          expect(track!.isActive, isTrue);
        },
      );

      test('isActive reflects the activated state', () async {
        await adapter.activateTrack(CurriculumId.mishnayos);

        expect(await adapter.isActive(CurriculumId.mishnayos), isTrue);
        expect(await adapter.isActive(CurriculumId.bavli), isFalse);
      });

      test(
        'retireTrack throws StateError when it is the only active track',
        () async {
          await adapter.activateTrack(CurriculumId.mishnayos);

          expect(
            () => adapter.retireTrack(CurriculumId.mishnayos),
            throwsA(isA<StateError>()),
          );
        },
      );

      test('retireTrack retires a track when another remains active', () async {
        await adapter.activateTrack(CurriculumId.mishnayos);
        await adapter.activateTrack(CurriculumId.bavli);

        await adapter.retireTrack(CurriculumId.mishnayos);

        expect(await adapter.isActive(CurriculumId.mishnayos), isFalse);
        expect(await adapter.isActive(CurriculumId.bavli), isTrue);
      });

      test(
        'getActiveTracks / countActiveTracks reflect activated tracks',
        () async {
          await adapter.activateTrack(CurriculumId.mishnayos);
          await adapter.activateTrack(CurriculumId.bavli);

          expect(await adapter.countActiveTracks(), 2);
          final active = await adapter.getActiveTracks();
          expect(
            active.map((t) => t.curriculumId),
            containsAll(<CurriculumId>[
              CurriculumId.mishnayos,
              CurriculumId.bavli,
            ]),
          );
        },
      );

      test('resetPace stamps a paceResetDate on the track', () async {
        await adapter.activateTrack(CurriculumId.mishnayos);

        await adapter.resetPace(CurriculumId.mishnayos);

        final track = await adapter.getTrack(CurriculumId.mishnayos);
        expect(track!.paceResetDate, isNotNull);
      });
    });
  });
}
