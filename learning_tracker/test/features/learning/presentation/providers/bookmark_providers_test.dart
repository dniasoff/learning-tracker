/// Unit tests for
/// `lib/features/learning/presentation/providers/bookmark_providers.dart` —
/// the sole Riverpod entry point features use to reach bookmark reads and
/// writes.
///
/// ## What changed, and what this guards
///
/// The bookmark vertical slice's rewire onto Firestore (Epic C) replaced
/// four exports — `bookmarkRepositoryProvider` (Drift-backed, scoped to an
/// `int` active profile), `bookmarkRepositoryFactoryProvider`
/// (`BookmarkRepository Function(int profileId)`, for delegated-profile
/// writes), and the two zero-consumer `bookmarkProvider` /
/// `bookmarkActionsProvider` — with exactly ONE: `bookmarkRepositoryProvider`,
/// now resolving to a Firestore-backed [FirestoreBookmarkRepositoryAdapter]
/// that resolves the active learner profile's ULID internally via
/// `activeProfileDocIdProvider`. The governing decision: to write bookmarks
/// for a profile, that profile must be the ACTIVE one — delegation is
/// expressed by switching the active profile, not by a second per-call
/// profile channel. `syncFromFirestore()` is also gone from the
/// [BookmarkRepository] interface entirely (it was the dead polling-sync
/// pull step).
///
/// The three deleted symbols (`bookmarkRepositoryFactoryProvider`,
/// `bookmarkProvider`, `bookmarkActionsProvider`) are not referenced
/// anywhere in this file — a test that named them would fail to COMPILE,
/// which is a stronger guarantee than any runtime assertion could give, so
/// their absence is enforced by the compiler rather than by a test here.
/// This file instead asserts the surface that DOES exist, positively.
///
/// TQ-6: no wall clock, no shared mutable global state between tests — every
/// test builds its own [ProviderContainer], mirroring
/// `test/data/firestore/repository_providers_test.dart`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_bookmark_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';

import '../../../../mocks/mock_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bookmarkRepositoryProvider', () {
    test(
      'resolves to a FirestoreBookmarkRepositoryAdapter, never the old '
      'Drift-backed BookmarkRepositoryImpl — the load-bearing assertion of '
      'the whole slice: the app must no longer read bookmarks from Drift',
      () {
        final container = ProviderContainer(
          overrides: [
            contentRepositoryProvider.overrideWithValue(
              MockContentRepository(),
            ),
            contentIndexProvider.overrideWith(
              (ref) => Completer<ContentIndex>().future,
            ),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(bookmarkRepositoryProvider);

        expect(repo, isA<FirestoreBookmarkRepositoryAdapter>());
        // The provider must expose the adapter, never bypass it with the
        // concrete Firestore repository resolved inside the adapter.
        expect(repo, isNot(isA<FirestoreBookmarkRepository>()));
      },
    );

    test('construction is synchronous — reading it needs no await, so every '
        'existing plain-Provider watcher (completionOrchestratorProvider, '
        'bulkPriorCompletionServiceProvider) keeps compiling and working '
        'unchanged', () {
      final container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(MockContentRepository()),
          contentIndexProvider.overrideWith(
            (ref) => Completer<ContentIndex>().future,
          ),
        ],
      );
      addTearDown(container.dispose);

      // bookmarkRepositoryProvider is declared as `Provider<BookmarkRepository>`
      // (see bookmark_providers.dart). Assigning `container.read(...)`
      // straight into a `BookmarkRepository`-typed local would fail to
      // COMPILE if it were ever changed to a `FutureProvider` — and this
      // test's body is itself synchronous (no `async`, no `await`, no
      // `pumpEventQueue`), which is part of the proof. The explicit type
      // annotation is load-bearing here, not decorative.
      // ignore: omit_local_variable_types
      final BookmarkRepository repo = container.read(
        bookmarkRepositoryProvider,
      );

      expect(repo, isA<FirestoreBookmarkRepositoryAdapter>());
    });

    test(
      'passes contentIndex: null through to firestoreBookmarkRepositoryProvider '
      'while contentIndexProvider is still loading — proves the adapter '
      'tolerates the warmup window (the repository then falls back to its '
      'own O(N) content scan, covered separately in '
      'firestore_bookmark_repository_test.dart) instead of blocking or '
      'crashing',
      () async {
        final contentRepository = MockContentRepository();
        final neverResolves = Completer<ContentIndex>();
        BookmarkRepositoryDeps? capturedDeps;

        final container = ProviderContainer(
          overrides: [
            contentRepositoryProvider.overrideWithValue(contentRepository),
            contentIndexProvider.overrideWith((ref) => neverResolves.future),
            firestoreBookmarkRepositoryProvider.overrideWith((ref, deps) {
              capturedDeps = deps;
              return Future.value(null);
            }),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(bookmarkRepositoryProvider);
        // Any BookmarkRepository call routes through
        // FirestoreBookmarkRepositoryAdapter's private `_resolveOrNull`,
        // which reads `firestoreBookmarkRepositoryProvider` with the deps
        // captured when `bookmarkRepositoryProvider` itself was built.
        await repo.getBookmark(curriculumId: CurriculumId.chumash);

        expect(capturedDeps, isNotNull);
        expect(capturedDeps!.contentIndex, isNull);
        expect(capturedDeps!.contentRepository, same(contentRepository));
      },
    );

    test('passes the resolved ContentIndex through once contentIndexProvider '
        'has finished loading — contrasts with the loading-state test above '
        'to prove the null pass-through is a deliberate warmup fallback, not '
        'the only value this ever threads through', () async {
      final contentRepository = MockContentRepository();
      final resolvedIndex = ContentIndex.fromCurricula(const {});
      BookmarkRepositoryDeps? capturedDeps;

      final container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(contentRepository),
          contentIndexProvider.overrideWith((ref) async => resolvedIndex),
          firestoreBookmarkRepositoryProvider.overrideWith((ref, deps) {
            capturedDeps = deps;
            return Future.value(null);
          }),
        ],
      );
      addTearDown(container.dispose);

      // Let contentIndexProvider actually resolve to AsyncData before
      // bookmarkRepositoryProvider — a plain synchronous Provider — reads
      // its CURRENT AsyncValue via `.asData?.value`.
      await container.read(contentIndexProvider.future);

      final repo = container.read(bookmarkRepositoryProvider);
      await repo.getBookmark(curriculumId: CurriculumId.chumash);

      expect(capturedDeps, isNotNull);
      expect(capturedDeps!.contentIndex, same(resolvedIndex));
    });
  });
}
