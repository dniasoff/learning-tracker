import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_bookmark_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';

/// Implementation of [BookmarkRepository] using Drift database and sync engine.
///
/// Scoped to a single profile so bookmarks on the same curriculum+track
/// are independent across profiles on the account.
///
/// Schema v1 (DNI-322): Bookmarks reference curriculumTracks by trackId
/// (integer FK). The [_resolveTrackId] helper looks up the single active track
/// row for the curriculum + profile.
///
/// Story 26.14 (DNI-357): accepts an optional [ContentIndex] for O(1)
/// prev/next leaf lookups in [advanceBookmark] and [initializeBookmark],
/// eliminating the O(N) scan over all curriculum items per call.
class BookmarkRepositoryImpl implements BookmarkRepository {
  final UserDatabase _database;
  final FirestoreGateway? _firestoreGateway;
  final ContentRepository _contentRepository;
  final int _profileId;

  /// Optional [ContentIndex] for O(1) adjacent-item lookups. When provided,
  /// [_getNextItemId] and [_getFirstItemId] skip the O(N) leaf scan and
  /// call [ContentIndex.adjacent] / the indexed leaf list instead.
  final ContentIndex? _contentIndex;

  BookmarkRepositoryImpl({
    required UserDatabase database,
    required ContentRepository contentRepository,
    int profileId = 0,
    ContentIndex? contentIndex,
    FirestoreGateway? firestoreGateway,
  }) : _database = database,
       _firestoreGateway = firestoreGateway,
       _contentRepository = contentRepository,
       _profileId = profileId,
       _contentIndex = contentIndex;

  /// Resolve the integer track ID for [curriculumId] scoped to [_profileId].
  /// Returns null if no matching track exists. One active track per curriculum
  /// per profile.
  Future<int?> _resolveTrackId(CurriculumId curriculumId) async {
    final tracks = await _database.trackDao.getActiveTracks(curriculumId);
    final match = tracks.where((t) => t.profileId == _profileId).firstOrNull;
    return match?.id;
  }

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async {
    final trackId = await _resolveTrackId(curriculumId);
    if (trackId == null) return null;

    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId.storageKey,
          trackId,
          _profileId,
        );

    if (bookmark == null) return null;

    return _bookmarkFromDb(bookmark);
  }

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps

    final trackId = await _resolveTrackId(curriculumId);
    if (trackId == null) {
      throw StateError(
        'No active track found for $curriculumId / profile $_profileId',
      );
    }

    final existing = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId.storageKey,
          trackId,
          _profileId,
        );

    final BookmarkEntity bookmark;

    if (existing != null) {
      await _database.bookmarkDao.updateBookmark(
        BookmarksCompanion(
          id: drift.Value(existing.id),
          profileId: drift.Value(_profileId),
          curriculumId: drift.Value(curriculumId.storageKey),
          trackId: drift.Value(trackId),
          sefariaRef: drift.Value(sefariaRef),
          updatedAt: drift.Value(now),
        ),
      );

      bookmark = BookmarkEntity(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        updatedAt: now,
      );
    } else {
      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: _profileId,
          curriculumId: curriculumId.storageKey,
          trackId: trackId,
          sefariaRef: sefariaRef,
          updatedAt: now,
        ),
      );

      bookmark = BookmarkEntity(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        updatedAt: now,
      );
    }

    return bookmark;
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {
    final trackId = await _resolveTrackId(curriculumId);
    if (trackId == null) return;

    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId.storageKey,
          trackId,
          _profileId,
        );

    if (bookmark == null) {
      // No bookmark exists yet, create one pointing to the next item
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await setBookmark(
          curriculumId: curriculumId,
          sefariaRef: nextSefariaRef,
        );
      }
    } else if (bookmark.sefariaRef == completedSefariaRef) {
      // Bookmark is on this item, advance it
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await setBookmark(
          curriculumId: curriculumId,
          sefariaRef: nextSefariaRef,
        );
      }
    }
    // else: bookmark is on a different item, don't change it
  }

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) async {
    // Get the first item in learning order
    final firstItemId = await _getFirstItemId(curriculumId: curriculumId);

    if (firstItemId == null) {
      throw StateError(
        'Cannot initialize bookmark: no content items found for $curriculumId',
      );
    }

    return await setBookmark(
      curriculumId: curriculumId,
      sefariaRef: firstItemId,
    );
  }

  // No longer part of BookmarkRepository; unreachable from the bookmark
  // providers after the Firestore rewire. Dies with this class in the Drift
  // demolition.
  Future<int> syncFromFirestore() async {
    final remoteBookmarks =
        await _firestoreGateway?.fetchAll(
          profileId: _profileId,
          collection: 'bookmarks',
        ) ??
        [];
    for (final remote in remoteBookmarks) {
      await mergeRemoteBookmark(remote);
    }
    return remoteBookmarks.length;
  }

  /// Get the next content item sefariaRef in learning order.
  ///
  /// Respects custom learning order if it exists, otherwise uses sort_order.
  ///
  /// When a [ContentIndex] was provided at construction time, the default-order
  /// path is O(1) via [ContentIndex.adjacent] — no full-curriculum scan needed
  /// (Story 26.14 / DNI-357).
  Future<String?> _getNextItemId({
    required CurriculumId curriculumId,
    required String currentSefariaRef,
  }) async {
    // Check if custom learning order exists for this curriculum
    final customOrder = await _database.learningOrderDao
        .getLearningOrderByCurriculum(
          curriculumId.storageKey,
          profileId: _profileId,
        );

    if (customOrder.isNotEmpty) {
      // Use custom learning order
      final currentIndex = customOrder.indexWhere(
        (item) => item.sefariaRef == currentSefariaRef,
      );

      if (currentIndex == -1 || currentIndex == customOrder.length - 1) {
        return null; // Current item not found or is the last item
      }

      return customOrder[currentIndex + 1].sefariaRef;
    }

    // Fast path: O(1) adjacent lookup via ContentIndex when available.
    final index = _contentIndex;
    if (index != null) {
      return index.adjacent(currentSefariaRef).next?.sefariaRef;
    }

    // Fallback: O(N) scan (used when ContentIndex is not injected).
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );

    // Filter to only leaf items and sort by sortOrder
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final currentIndex = leafItems.indexWhere(
      (item) => item.sefariaRef == currentSefariaRef,
    );

    if (currentIndex == -1 || currentIndex == leafItems.length - 1) {
      return null; // Current item not found or is the last item
    }

    return leafItems[currentIndex + 1].sefariaRef;
  }

  /// Get the first content item sefariaRef in learning order.
  ///
  /// When a [ContentIndex] was provided at construction time, the default-order
  /// path is O(1) via the indexed leaf list (Story 26.14 / DNI-357).
  Future<String?> _getFirstItemId({required CurriculumId curriculumId}) async {
    // Check if custom learning order exists for this curriculum
    final customOrder = await _database.learningOrderDao
        .getLearningOrderByCurriculum(
          curriculumId.storageKey,
          profileId: _profileId,
        );

    if (customOrder.isNotEmpty) {
      return customOrder.first.sefariaRef;
    }

    // Fast path: O(1) first-leaf lookup via ContentIndex when available.
    final index = _contentIndex;
    if (index != null) {
      return index.firstLeaf(curriculumId);
    }

    // Fallback: O(N) scan (used when ContentIndex is not injected).
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );

    // Filter to only leaf items and sort by sortOrder
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return leafItems.isNotEmpty ? leafItems.first.sefariaRef : null;
  }

  /// Convert database model to domain entity.
  BookmarkEntity _bookmarkFromDb(Bookmark bookmark) {
    return BookmarkEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == bookmark.curriculumId,
        orElse: () => throw ArgumentError(
          'Unknown curriculumId: ${bookmark.curriculumId}',
        ),
      ),
      sefariaRef: bookmark.sefariaRef,
      updatedAt: bookmark.updatedAt,
    );
  }

  /// Merge remote bookmark with local (conflict resolution).
  ///
  /// Uses last-write-wins strategy based on UTC timestamps (P5).
  /// Called by sync engine during pull operations.
  Future<void> mergeRemoteBookmark(Map<String, dynamic> remoteData) async {
    final remote = BookmarkEntity.fromFirestore(remoteData);

    // Get local bookmark
    final local = await getBookmark(curriculumId: remote.curriculumId);

    if (local == null) {
      // No local bookmark for this profile — need to resolve trackId first.
      final trackId = await _resolveTrackId(remote.curriculumId);
      if (trackId == null) return; // Track not yet set up for this profile

      await _database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: _profileId,
          curriculumId: remote.curriculumId.storageKey,
          trackId: trackId,
          sefariaRef: remote.sefariaRef,
          updatedAt: remote.updatedAt,
        ),
      );
    } else {
      if (remote.updatedAt.isAfter(local.updatedAt)) {
        final trackId = await _resolveTrackId(remote.curriculumId);
        if (trackId == null) return;

        await _database.bookmarkDao.upsertBookmarkByProfile(
          profileId: _profileId,
          curriculumId: remote.curriculumId.storageKey,
          trackId: trackId,
          sefariaRef: remote.sefariaRef,
          updatedAt: remote.updatedAt,
        );
      }
    }
  }
}

/// Thrown by [FirestoreBookmarkRepositoryAdapter]'s write methods
/// (`setBookmark`, `initializeBookmark`, `advanceBookmark`) when
/// `firestoreBookmarkRepositoryProvider` resolves to `null` — i.e. no
/// account is active yet, or no learner profile is active yet (see that
/// provider's doc comment in
/// `lib/data/firestore/repository_providers.dart` for the null-vs-AsyncError
/// contract this exception sits on top of).
///
/// [FirestoreBookmarkRepositoryAdapter.getBookmark] deliberately does NOT
/// throw this: its return type is already nullable, and the provider
/// layer's own contract already treats `null` as "not ready yet — show a
/// loading/empty state" for exactly this condition, so reusing that same
/// `null` for a read costs nothing new and matches the rest of the app. A
/// *write* has no such channel to reuse: silently doing nothing on
/// `setBookmark` (a direct user action) or `advanceBookmark` (an automatic
/// post-completion advance) would look identical to success while quietly
/// dropping the user's bookmark progress, so those three throw instead —
/// loud and catchable by name, the same shape as
/// [AccountNotAuthenticatedException] (`lib/data/firestore/
/// account_firebase.dart`) uses for the analogous "seam exists but nothing
/// has activated it yet" condition one layer down.
class BookmarkRepositoryNotReadyException implements Exception {
  const BookmarkRepositoryNotReadyException();

  @override
  String toString() =>
      'BookmarkRepositoryNotReadyException: firestoreBookmarkRepositoryProvider '
      'resolved to null (no active account, or no active learner profile, '
      'yet) — cannot complete a bookmark write until one is active.';
}

/// Firestore-backed [BookmarkRepository] adapter — the reference pattern
/// for Epic C's feature-by-feature rewire onto Firestore (see
/// `lib/data/firestore/repository_providers.dart`'s library doc comment,
/// "Reaching this file from lib/features/** — audit check 102", and
/// `lib/data/repositories/firestore_bookmark_repository.dart`'s class doc
/// comment for what THIS class wraps).
///
/// ## The pattern to copy for the other ~13 repositories
///
/// 1. **Import `data/firestore/repository_providers.dart` right here.**
///    This file's own path contains `/data/repositories/`, which is the
///    one exemption `tool/check_dependency_direction.dart` (check 102)
///    grants — the feature's own `data/repositories/*_impl.dart` is the
///    sanctioned seam between `lib/features/**` and the data-access ring.
///    Nothing outside this directory (screens, notifiers, presentation
///    providers) may import `data/firestore/**` directly; they keep
///    depending on [BookmarkRepository] exactly as before.
/// 2. **Take a [Ref], not a resolved repository.** The Firestore provider
///    (`firestoreBookmarkRepositoryProvider`) is an async, nullable
///    `FutureProvider.family` — it depends on an active account AND an
///    active learner profile that may not exist yet when this adapter is
///    constructed. Holding a [Ref] and re-reading the provider inside every
///    method (see [_resolve]) means construction itself stays synchronous
///    and cheap, which matters because [BookmarkRepository]'s existing
///    callers (`bookmarkRepositoryProvider`, in
///    `lib/features/learning/presentation/providers/bookmark_providers.dart`)
///    are themselves plain, synchronous `Provider`s. Making construction
///    async would force those — and everything that watches them — to
///    become async too, an interface-shape change touching every current
///    caller instead of just this file.
/// 3. **Every method re-resolves via [_resolve]; nothing is cached on
///    `this`.** The active account/profile can change between calls (e.g.
///    profile switch mid-session); re-reading `ref.read(...future)` each
///    time picks that up for free, at the cost of one extra `Future` per
///    call — cheap relative to the network round-trip the call itself
///    already makes.
/// 4. **`null` from the provider means "not ready", not "found nothing" —
///    decide deliberately how each interface method expresses that**, per
///    method's return shape. See [BookmarkRepositoryNotReadyException]'s
///    doc comment for the read-vs-write split this class lands on
///    (`getBookmark` returns `null`; the three write methods throw). A
///    repository whose interface methods are ALL non-nullable (no natural
///    "empty" value to reuse) should default to throwing for all of them
///    rather than inventing a sentinel value.
/// 5. **A genuine resolution failure is never swallowed.** [_resolve] does
///    not catch anything — if `ref.read(...future)` completes with an
///    error (e.g. [AccountNotAuthenticatedException]), it propagates
///    unchanged out of whichever [BookmarkRepository] method called
///    [_resolve], exactly as reading the provider directly would.
/// 6. **A tutored session is refused outright, not served from the owner
///    path — enforced upstream, not here.**
///    `_watchActiveAccountAndProfile` (`repository_providers.dart`)
///    resolves to `null` whenever a tutor is acting inside a talmid's
///    context, before this or any of the other 12 profile-scoped
///    providers gets a chance to resolve the TUTOR's own profile document
///    — which is what serving one would silently corrupt (T-35; see
///    `docs/planning/firestore-cutover-log.md`). This class no longer
///    carries its own copy of that check: `_resolveOrNull`/`_resolve`
///    already see the hoisted `null` and handle it exactly like any other
///    not-ready state (point 4 above). A tutored session and "no account/
///    profile active yet" are therefore indistinguishable from this
///    class's callers — both read as [BookmarkRepositoryNotReadyException]
///    on write, `null` on read.
class FirestoreBookmarkRepositoryAdapter implements BookmarkRepository {
  FirestoreBookmarkRepositoryAdapter({
    required Ref ref,
    required ContentRepository contentRepository,
    ContentIndex? contentIndex,
  }) : _ref = ref,
       _contentRepository = contentRepository,
       _contentIndex = contentIndex;

  final Ref _ref;
  final ContentRepository _contentRepository;
  final ContentIndex? _contentIndex;

  /// Re-reads `firestoreBookmarkRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). See the class doc comment (point 3) for why this re-reads
  /// on every call rather than caching, and (point 5) for why a genuine
  /// resolution failure is left to propagate as-is rather than being
  /// caught here.
  Future<FirestoreBookmarkRepository?> _resolveOrNull() {
    return _ref.read(
      firestoreBookmarkRepositoryProvider((
        contentRepository: _contentRepository,
        contentIndex: _contentIndex,
      )).future,
    );
  }

  /// Like [_resolveOrNull], but throws [BookmarkRepositoryNotReadyException]
  /// instead of returning `null` — for the three write methods, which have
  /// no nullable "not ready" value of their own to return. See
  /// [BookmarkRepositoryNotReadyException]'s doc comment for why.
  Future<FirestoreBookmarkRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const BookmarkRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async {
    // Not-ready — including a tutored session, hoisted upstream into
    // `_watchActiveAccountAndProfile` (point 6 above) — reads as "nothing
    // to show yet" rather than an exception. See
    // BookmarkRepositoryNotReadyException's doc comment for why reads and
    // writes are treated differently here.
    final repo = await _resolveOrNull();
    if (repo == null) return null;
    return repo.getBookmark(curriculumId: curriculumId);
  }

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final repo = await _resolve();
    return repo.setBookmark(curriculumId: curriculumId, sefariaRef: sefariaRef);
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {
    final repo = await _resolve();
    await repo.advanceBookmark(
      curriculumId: curriculumId,
      completedSefariaRef: completedSefariaRef,
    );
  }

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) async {
    final repo = await _resolve();
    return repo.initializeBookmark(curriculumId: curriculumId);
  }
}
