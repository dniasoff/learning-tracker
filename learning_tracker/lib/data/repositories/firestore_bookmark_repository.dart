/// Firestore implementation of [BookmarkRepository] — the REFERENCE
/// repository for the Firestore rewrite (`docs/firestore-rewrite-map.md`).
/// Chosen as the smallest complete vertical slice; the other ~13
/// repositories under `lib/features/**/domain/repositories/` should copy
/// this file's shape. See the class doc comment below for what to copy and
/// why.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';

/// Firestore-backed [BookmarkRepository]: `users/{uid}/learner_profiles/
/// {profileId}/bookmarks/{curriculumId}` (one bookmark doc per curriculum —
/// `docs/firestore-rewrite-map.md`, `firestore.rules` `match /bookmarks/
/// {bookmarkId}`).
///
/// **Not wired into the app yet.** This class stands alone, constructed
/// directly with the pieces it needs; nothing under `lib/features/` reads
/// it yet (that rewiring is a later stage — "C" in the migration plan). The
/// existing Drift-backed [BookmarkRepositoryImpl] is untouched and keeps
/// serving the app until then.
///
/// ## The pattern other repositories should copy
///
/// 1. **Constructor takes the resolved handle, not a way to resolve one.**
///    [firestore] and [uid] are the already-authenticated
///    [AccountFirebaseHandles] fields (`lib/data/firestore/
///    active_account_providers.dart` resolves those; this class does not
///    depend on that provider layer directly, so it stays trivially
///    testable against `fake_cloud_firestore` with no Auth/App mocking).
///    [profileId] is the Firestore **learner-profile ULID doc-id**
///    (`learner_profiles/{profileId}`, AD-24) — a `String`, deliberately
///    NOT the Drift-era `int profileId` the old
///    [BookmarkRepositoryImpl] takes. Every Firestore repository should key
///    off this same String profile id, never the local integer.
/// 2. **Doc-ids always come from `DocIds`**, never hand-rolled inline
///    (here: [DocIds.bookmarkDocId]) — never `collection.add()` (append-
///    only / natural-key collections must stay reproducible and idempotent
///    across retries).
/// 3. **The domain entity owns its own Firestore codec.**
///    [BookmarkEntity.toFirestore]/[BookmarkEntity.fromFirestore] already
///    existed before this class (Story 2.3 scaffolding) — this repository
///    is mostly plumbing around them, not a new encode/decode layer. A
///    repository whose entity does not yet have that should add it to the
///    entity, not inline field mapping into the repository.
/// 4. **Writes use `SetOptions(merge: true))`, not a bare `.set()`.**
///    `bookmarks` is one of the 8 collections with two writers (this
///    client, and a tutor proxy Cloud Function — see
///    `functions/src/tutor_writes.ts`'s `tutorUpsertBookmark`, which itself
///    merges and always stamps a server-set `synced_at`). A full-document
///    `.set()` from this client would blow that field away on the next
///    owner write.
/// 5. **A stream-returning method exists ALONGSIDE the interface, not
///    inside it.** [BookmarkRepository] has no stream-returning member,
///    and Dart's `implements` requires every implementing class —
///    including the still-live [BookmarkRepositoryImpl] — to redeclare
///    every interface member itself, even ones with a default body. Adding
///    a new required member to the interface would force a matching (and
///    currently pointless) override onto that Drift class, which the story
///    brief for this work explicitly says not to touch. So [watchBookmark]
///    is extra public API on this concrete class only, exactly the same
///    reasoning already established in this codebase for
///    `LifetimeUnionLeafSource` (`content_repository.dart`) being a
///    separate interface rather than a new method on [ContentRepository].
///    Once every repository has a Firestore implementation, a later story
///    can widen the interface (or add a shared `Watchable<T>` capability
///    interface) — that is a call for whoever does the Epic C rewiring, not
///    guessed at here.
/// 6. **A dead listener resubscribes itself.** [watchBookmark] is built on
///    [resilientDocStream] (`lib/data/firestore/resilient_doc_stream.dart`)
///    rather than a bare `.snapshots()` — see that file's doc comment for
///    why `snapshots()` alone would leave a UI dark forever after one
///    transient error.
///
/// ## Known, deliberate gap — NOT silently guessed at
///
/// [advanceBookmark]/[initializeBookmark] need "the next item in learning
/// order", which the Drift implementation resolves two ways: a custom
/// `learning_order` override (checked first), falling back to natural
/// content order via [ContentIndex]/[ContentRepository]. `learning_order`
/// is itself moving to Firestore (`docs/firestore-rewrite-map.md`) but its
/// repository does not exist yet — building it is out of this (Bookmarks)
/// repository's scope, and reaching into its raw Firestore collection here
/// would duplicate logic the real repository will own. This class
/// therefore only implements the natural-content-order fallback
/// ([ContentIndex]/[ContentRepository] — unchanged from Drift, both are
/// local, non-Firestore concerns) and does NOT check a custom
/// `learning_order` override yet. Flagged, not fixed: wire the real
/// Firestore-backed learning-order lookup in here once it exists.
class FirestoreBookmarkRepository implements BookmarkRepository {
  FirestoreBookmarkRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    required ContentRepository contentRepository,
    ContentIndex? contentIndex,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _contentRepository = contentRepository,
       _contentIndex = contentIndex,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final ContentRepository _contentRepository;
  final ContentIndex? _contentIndex;
  final AppLogger _logger;

  CollectionReference<Map<String, dynamic>> get _bookmarks => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('bookmarks');

  DocumentReference<Map<String, dynamic>> _doc(CurriculumId curriculumId) =>
      _bookmarks.doc(
        DocIds.bookmarkDocId({'curriculum_id': curriculumId.storageKey}),
      );

  BookmarkEntity? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return BookmarkEntity.fromFirestore(data);
  }

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async {
    final snapshot = await _doc(curriculumId).get();
    return _decode(snapshot);
  }

  /// Live updates for [curriculumId]'s bookmark. See the class doc
  /// comment (point 5) for why this is not part of [BookmarkRepository]
  /// itself. Resubscribes with bounded exponential backoff if the
  /// underlying listener errors (`resilientDocStream`).
  Stream<BookmarkEntity?> watchBookmark({required CurriculumId curriculumId}) {
    return resilientDocStream<BookmarkEntity?>(
      openStream: () => _doc(curriculumId).snapshots(),
      decode: _decode,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_bookmark_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    );
  }

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final entity = BookmarkEntity(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      updatedAt: DateTimeFactory.nowUtc(), // P5: UTC timestamps
    );
    await _doc(curriculumId).set(entity.toFirestore(), SetOptions(merge: true));
    return entity;
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {
    final bookmark = await getBookmark(curriculumId: curriculumId);

    // No bookmark yet, or the bookmark is on a different item than the one
    // just completed: only the "no bookmark yet" case still advances (mirrors
    // BookmarkRepositoryImpl.advanceBookmark exactly).
    if (bookmark != null && bookmark.sefariaRef != completedSefariaRef) {
      return;
    }

    final next = await _getNextItemId(
      curriculumId: curriculumId,
      currentSefariaRef: completedSefariaRef,
    );
    if (next != null) {
      await setBookmark(curriculumId: curriculumId, sefariaRef: next);
    }
  }

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) async {
    final first = await _getFirstItemId(curriculumId);
    if (first == null) {
      throw StateError(
        'Cannot initialize bookmark: no content items found for '
        '$curriculumId',
      );
    }
    return setBookmark(curriculumId: curriculumId, sefariaRef: first);
  }

  /// Firestore listeners + offline persistence replace pull-based sync —
  /// there is no separate "pull remote updates" step left to perform, so
  /// this always returns 0. Kept only because [BookmarkRepository]
  /// declares it and [BookmarkRepositoryImpl] (Drift + the old sync engine)
  /// still needs it; no production code calls this method through the
  /// interface today (verified: the only two references in `lib/` are the
  /// interface declaration and the Drift implementation's own definition).
  @override
  Future<int> syncFromFirestore() async => 0;

  /// Mirrors `BookmarkRepositoryImpl._getNextItemId`'s natural-order path
  /// exactly (see the class doc comment's "Known, deliberate gap" section
  /// for what is NOT mirrored — the custom `learning_order` override).
  Future<String?> _getNextItemId({
    required CurriculumId curriculumId,
    required String currentSefariaRef,
  }) async {
    final index = _contentIndex;
    if (index != null) {
      return index.adjacent(currentSefariaRef).next?.sefariaRef;
    }

    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final currentIndex = leafItems.indexWhere(
      (item) => item.sefariaRef == currentSefariaRef,
    );
    if (currentIndex == -1 || currentIndex == leafItems.length - 1) {
      return null;
    }
    return leafItems[currentIndex + 1].sefariaRef;
  }

  /// Mirrors `BookmarkRepositoryImpl._getFirstItemId`'s natural-order path
  /// exactly (same caveat as [_getNextItemId]).
  Future<String?> _getFirstItemId(CurriculumId curriculumId) async {
    final index = _contentIndex;
    if (index != null) {
      return index.firstLeaf(curriculumId);
    }

    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return leafItems.isNotEmpty ? leafItems.first.sefariaRef : null;
  }
}
