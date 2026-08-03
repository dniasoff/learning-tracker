/// Firestore implementation for bookmarks — the REFERENCE repository for
/// the Firestore rewrite (`docs/firestore-rewrite-map.md`). Chosen as the
/// smallest complete vertical slice; the other ~13 repositories under
/// `lib/data/repositories/` should copy this file's shape. See the class
/// doc comment below for what to copy and why.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_order_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';

/// Firestore-backed bookmark repository: `users/{uid}/learner_profiles/
/// {profileId}/bookmarks/{curriculumId}` (one bookmark doc per curriculum —
/// `docs/firestore-rewrite-map.md`, `firestore.rules` `match /bookmarks/
/// {bookmarkId}`).
///
/// **Wired into the app via `FirestoreBookmarkRepositoryAdapter` and
/// `bookmarkRepositoryProvider`.** The existing Drift-backed
/// `BookmarkRepositoryImpl` (`lib/features/learning/data/repositories/`) is
/// untouched and is condemned wholesale in the Drift demolition task.
///
/// ## No interface — deliberate, not an oversight
///
/// `BookmarkRepositoryImpl` implements an abstract `BookmarkRepository`.
/// This class does not implement anything. An interface buys
/// substitutability, and there will never be a second implementation here —
/// the Drift one is being deleted outright once the rewrite lands, not kept
/// alongside this one. Meanwhile Dart's `implements` requires the
/// implementing class to redeclare every interface member itself, even ones
/// with a default body — so retrofitting a stream-returning method onto the
/// old interface would force a matching (and pointless) override onto the
/// Drift class this repository is explicitly not supposed to touch. Testing
/// is also better without it: constructing this class directly over
/// `fake_cloud_firestore` beats maintaining a hand-written fake
/// implementation of an interface. Where a feature later genuinely needs
/// substitutability (e.g. swapping in a test double for a widget test), it
/// can get an interface then — introduced for that reason, not speculatively
/// here.
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
///    `BookmarkRepositoryImpl` takes. Every Firestore repository should key
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
/// 5. **Streams sit right next to the one-shot reads, as ordinary public
///    methods.** [watchBookmark] is not "extra" or "outside" anything —
///    with no interface to redeclare against, it is simply a method on this
///    class, exactly like [getBookmark]. This is the whole reason the
///    interface was dropped: streams are the actual point of moving to
///    Firestore, and forcing them through an `implements`-constrained
///    abstraction was fighting the migration's own goal.
/// 6. **A dead listener resubscribes itself.** [watchBookmark] is built on
///    [resilientDocStream] (`lib/data/firestore/resilient_doc_stream.dart`)
///    rather than a bare `.snapshots()` — see that file's doc comment for
///    why `snapshots()` alone would leave a UI dark forever after one
///    transient error.
///
/// ## Custom learning order is honoured
///
/// [advanceBookmark]/[initializeBookmark] need "the next item in learning
/// order", which the Drift implementation resolves two ways: a custom
/// `learning_order` override (checked first), falling back to natural
/// content order via [ContentIndex]/[ContentRepository]. This class mirrors
/// that exactly via the injected [FirestoreLearningOrderRepository]: both
/// [_getNextItemId] and [_getFirstItemId] first call
/// `_learningOrderRepository.getCustomOrderRefs(curriculumId)` and take the
/// custom-order branch whenever that list is non-empty (see the predicate
/// doc on [getCustomOrderRefs] itself). `getOrder(...).isNotEmpty` would be
/// the WRONG gate here — it always synthesizes a non-empty natural-order
/// list when there are zero stored rows, so it would read as "custom order
/// exists" for every uncustomized profile. [getCustomOrderRefs] returns raw
/// rows only, so its emptiness is a truthful "is there a custom order?"
/// signal, and it needs no `allItems`, which keeps the [ContentIndex] O(1)
/// fast path intact when there is no custom order.
///
/// ## Dropped along with the interface
///
/// The Drift-era `BookmarkRepository` interface also declared
/// `syncFromFirestore()` — a "pull remote updates" step from the old
/// polling sync engine. Firestore listeners + offline persistence replace
/// that entirely; there is no separate pull step for a Firestore-native
/// repository to perform, so this class simply does not have the method
/// (no interface member to satisfy, no reason to keep a permanent no-op
/// around).
class FirestoreBookmarkRepository {
  FirestoreBookmarkRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    required ContentRepository contentRepository,
    required FirestoreLearningOrderRepository learningOrderRepository,
    ContentIndex? contentIndex,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _contentRepository = contentRepository,
       _learningOrderRepository = learningOrderRepository,
       _contentIndex = contentIndex,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final ContentRepository _contentRepository;
  final FirestoreLearningOrderRepository _learningOrderRepository;
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

  /// Get the bookmark for [curriculumId], or `null` if none exists yet.
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async {
    final snapshot = await _doc(curriculumId).get();
    return _decode(snapshot);
  }

  /// Live updates for [curriculumId]'s bookmark. Resubscribes with bounded
  /// exponential backoff if the underlying listener errors
  /// (`resilientDocStream`) — see the class doc comment (point 5) for why
  /// this sits alongside [getBookmark] as an ordinary method rather than
  /// behind any interface.
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

  /// Create or update a bookmark to point to a specific content item. Does
  /// NOT create completion records — it only updates the pointer.
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

  /// Advance the bookmark to the next item in learning order, but only if
  /// it is currently on [completedSefariaRef] (or does not exist yet). Does
  /// nothing if the bookmark is on a different item, or if
  /// [completedSefariaRef] is the last item.
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

  /// Initialize the bookmark for a new curriculum, pointing to the first
  /// item in learning order. Throws [StateError] if the curriculum has no
  /// content.
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

  /// Mirrors `BookmarkRepositoryImpl._getNextItemId` exactly: a custom
  /// `learning_order` override is checked FIRST and, whenever any row
  /// exists for [curriculumId], wins unconditionally — [currentSefariaRef]
  /// not being found in it (or being its last entry) returns `null`, it
  /// does NOT fall through to natural order. Only when there is no custom
  /// order at all does this fall back to the natural-order path
  /// ([ContentIndex]/[ContentRepository] — unchanged from Drift).
  Future<String?> _getNextItemId({
    required CurriculumId curriculumId,
    required String currentSefariaRef,
  }) async {
    final customOrder = await _learningOrderRepository.getCustomOrderRefs(
      curriculumId,
    );
    if (customOrder.isNotEmpty) {
      final currentIndex = customOrder.indexOf(currentSefariaRef);
      if (currentIndex == -1 || currentIndex == customOrder.length - 1) {
        return null;
      }
      return customOrder[currentIndex + 1];
    }

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

  /// Mirrors `BookmarkRepositoryImpl._getFirstItemId` exactly: same custom-
  /// `learning_order`-first gate as [_getNextItemId] — a non-empty custom
  /// order returns its first entry unconditionally, before either the
  /// [ContentIndex] fast path or the O(N) content fallback runs.
  Future<String?> _getFirstItemId(CurriculumId curriculumId) async {
    final customOrder = await _learningOrderRepository.getCustomOrderRefs(
      curriculumId,
    );
    if (customOrder.isNotEmpty) {
      return customOrder.first;
    }

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
