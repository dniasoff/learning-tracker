/// Firestore implementation for completions — the largest surface in the
/// Firestore rewrite (`docs/firestore-rewrite-map.md`). Copies the shape
/// `firestore_learning_ledger_repository.dart` established (resolved-handle
/// constructor, `DocIds`-only doc-ids, entity-owned codec, append-only
/// creates, `completed_at` raw-`Timestamp` round-trip, doc-id-ordered
/// pagination past the 500-item `list()` cap, one-shot reads sharing the
/// stream's per-document decode leniency) and replaces the entire Drift-era
/// `PriorCompletionImports` tier apparatus with a plain `source` field. See
/// the class doc comment for what is new here specifically.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';

/// Firestore-backed completions repository: `users/{uid}/learner_profiles/
/// {profileId}/completions/{completionId}` — append-only, deterministic
/// natural-key doc-id (`docs/firestore-rewrite-map.md`, `firestore.rules`
/// `match /completions/{completionId}`).
///
/// **Not wired into the app's production provider yet** — but two adapters
/// under `lib/features/` already read this class:
/// `FirestoreCompletionRepositoryAdapter` and
/// `FirestoreProgressRepositoryAdapter`
/// (`lib/features/learning/data/repositories/completion_repository_impl.dart`,
/// `lib/features/progress/data/repositories/
/// firestore_progress_repository_adapter.dart`). Neither adapter is itself
/// wired to the provider its feature actually uses —
/// `completionRepositoryProvider`/`progressRepositoryProvider` still
/// construct the Drift-backed `CompletionRepositoryImpl`/
/// `ProgressRepositoryImpl` (see those adapters' own doc comments for
/// exactly what is still gating the swap) — so the existing Drift-backed
/// `CompletionRepositoryImpl`
/// (`lib/features/learning/data/repositories/`) and `CompletionDao`
/// (`lib/core/database/daos/completion_dao.dart`) still serve the app.
///
/// **No interface, no `implements`** — same reasoning as
/// `FirestoreBookmarkRepository`'s doc comment: the Drift implementation is
/// being deleted outright, not kept alongside this one.
///
/// ## `source` replaces the entire prior-import tier apparatus
///
/// `docs/firestore-rewrite-map.md`'s "RESOLVED: prior-import tier tracking"
/// section is the design this class implements. Owner invariant: *"if
/// something is marked as learnt in a track it cannot be shown or marked
/// learnt again... globally yes, something can be learnt multiple times."*
///
/// | `source`     | Engagement (streak/points) | Track achievement | Lifetime ledger |
/// |--------------|:---------------------------:|:------------------:|:-----------------:|
/// | `live`       | ✓ | ✓ | ✓ |
/// | `bulkInTrack`| ✗ | ✓ | ✓ |
///
/// [CompletionSource.lifetimeOnly] is deliberately absent from that table —
/// it writes **only** a `learning_ledger` entry (owned by
/// `FirestoreLearningLedgerRepository`), never a `completions` document.
/// [recordCompletion] / [recordCompletionsBatch] both reject it with an
/// [ArgumentError] rather than silently accepting a value that would
/// corrupt this collection's own invariant.
///
/// A completion's `source` is **fixed at creation and never updated** — the
/// once-per-track invariant above makes a `bulkInTrack`→`live` "upgrade"
/// (the Drift-era B8 mechanism) permanently unreachable; see the map doc's
/// "B8 / `_upgradePriorMarkRow` is dead" note. `getCompletionsByTier`'s 8
/// Drift call sites (`CompletionDao`) become the plain field filter in
/// [getCompletionsByTier] below.
///
/// ### A consequence worth being explicit about: `trackAchievement` ==
/// `lifetime` for THIS repository
///
/// Under the old Drift model, `CompletionTierFilter.lifetime` included
/// `lifetimeOnly` rows (imported historical data) that lived in the same
/// table as everything else. Under this model, `lifetimeOnly` rows never
/// enter `completions` at all — so, scoped to this collection alone, every
/// document already qualifies for `trackAchievement` (`live` or
/// `bulkInTrack`), which means [getCompletionsByTier] returns the *same*
/// result set for [CompletionTierFilter.trackAchievement] and
/// [CompletionTierFilter.lifetime] — see that method's doc comment. A
/// caller that needs the OLD `lifetime` semantics (this collection PLUS
/// historical `lifetimeOnly` imports) must separately query
/// `FirestoreLearningLedgerRepository`, whose ledger entries are the only
/// place a `lifetimeOnly` completion is recorded — this repository cannot
/// reach across that collection boundary itself.
///
/// ## No delete method — server-side only, by design
///
/// `firestore.rules` denies `delete` on `completions` unconditionally
/// (`allow delete: if false`). The map doc's owner decision (2026-08-02)
/// permits deleting a `bulkInTrack` completion (the onboarding un-tick,
/// which must also retract the linked `learning_ledger` entry) but
/// EXPLICITLY routes it through a Cloud Function using the Admin SDK — "Both
/// `completions` and `learning_ledger` are SR-1 append-only... Rather than
/// punch the first delete hole into append-only history — which a client
/// could widen by writing `source: 'bulkInTrack'` onto a live completion and
/// then deleting it — this routes server-side." This class therefore has NO
/// delete method at all, not even a `bulkInTrack`-only one; do not add one
/// without re-reading that reasoning.
///
/// ## Doc-id: `DocIds.completionDocIdForProfile`, the `String`-profileId
/// variant
///
/// `DocIds.completionDocId(int profileId, Map data)` mirrors
/// `FirestoreGatewayImpl._completionDocId` byte-for-byte — but that
/// signature takes the Drift-era **local autoincrement** `int profileId`
/// (verified against the live gateway's call sites, `firestore_gateway_impl.
/// dart:212-237`: the same `int profileId` parameter is used BOTH to resolve
/// the path via a device-local registry lookup AND embedded as a raw string
/// inside the doc-id itself). This repository is constructed with the
/// AD-24 learner-profile **ULID `String`** instead (per this migration's
/// binding constraint — never the Drift int), which `completionDocId`'s
/// `int`-typed parameter cannot honestly accept: there is no lossless way to
/// turn a ULID into the specific int the old gateway would have embedded,
/// and inventing one (a hash, a sentinel) would silently diverge from
/// `DocIds.completionDocId`'s actual output anyway, just less visibly than
/// admitting the divergence outright. Given the app is greenfield ("no
/// users, no back-compat" — `docs/firestore-rewrite-map.md`), there is no
/// live document written by the old gateway for this repository to stay
/// byte-compatible with.
///
/// [_docId] / [_docIdFromKey] therefore call
/// [DocIds.completionDocIdForProfile] — the `String`-profileId sibling of
/// `completionDocId`, added specifically so this repository (and any other
/// ULID-`profileId`-keyed caller) can route its doc-ids through `DocIds`
/// rather than reproducing the shape inline. Identical SHAPE to
/// `completionDocId` (four components, [DocIds.encodeKeyComponent]-escaped,
/// `_`-joined, same order) — only the profile-id component's type differs.
/// Embedding the profile ULID here is strictly redundant with the
/// collection path (`.../learner_profiles/{profileId}/completions/...`
/// already scopes by profile) but is kept for maximum fidelity to the
/// four-component shape `firestore.rules`' own `completions` comment
/// describes. `completionDocId` itself is untouched — the live gateway
/// still exists and is still golden-pinned against it.
///
/// ## `trackType` is NOT part of the doc-id's natural key — flagged
///
/// `firestore.rules`' own `completions` comment says the natural key is
/// `(profileId, sefariaRef, stageId, trackType, curriculumId)`, but
/// `docs/firestore-rewrite-map.md` states plainly that comment is stale and
/// `doc_ids.dart` is authoritative — and `DocIds.completionDocId`'s actual
/// code omits `trackType` entirely (only profileId/sefariaRef/stageId/
/// curriculumId). [_docId] mirrors that authoritative four-component
/// formula exactly, which means: **two completions that differ ONLY by
/// `trackType` (same curriculum, same stage, same sefariaRef) collide onto
/// the SAME document.** The second write is not rejected — SR-1's
/// byte-identical-replay rule would deny it in production only if the
/// payloads actually differ, and a different `trackType` value does make
/// them differ, so a genuine second `trackType` completion for the same
/// item+stage would be **rules-denied as an illegal update** in production,
/// not silently merged. This is pre-existing target-schema behavior (the
/// map doc says "the target schema is not new... do not redesign"), not
/// introduced here — flagged because it is easy to miss and not on the
/// existing traps list.
///
/// ## `stageId` is expected to hold `stage_order`, not a Drift row id
///
/// See [CompletionEntity]'s class doc comment. [hasCompletionsForStage]
/// below is the method `FirestoreStageDefinitionRepository`'s class doc
/// comment explicitly flagged as belonging to "whoever builds the Firestore
/// completions repository," keyed by `(curriculumId, stageOrder)` — this is
/// that method.
///
/// ## `completed_at` round-trips through a real `Timestamp`, not a string
///
/// Same handling as `FirestoreLearningLedgerRepository` —
/// [CompletionEntityFirestoreCodec.toFirestore] writes a raw [DateTime] (see
/// that extension's doc comment for why a `String` would rules-deny every
/// write); [_normalizeForDecode] converts the `Timestamp` object read back
/// into a UTC [DateTime] before [completionEntityFromFirestore] (which stays
/// free of any `cloud_firestore` import) ever sees it.
///
/// ## Idempotent retries: `completedAt` is ALWAYS caller-supplied
///
/// [recordCompletion] takes `completedAt` as a required parameter — this
/// repository never mints one internally (no `DateTimeFactory.nowUtc()`
/// fallback anywhere in this file). SR-1's append-only `update` rule permits
/// ONLY a byte-identical replay of the existing document; if this repository
/// stamped a freshly-computed "now" into `completed_at` on every call, a
/// genuine retry of the same logical completion (lost ack, timeout) would
/// recompute a DIFFERENT timestamp and get rules-denied as an illegal
/// update. The caller owns minting `completedAt` once and passing the exact
/// same value back on any retry.
///
/// ## The 500-item `list()` cap (`firestore.rules` SR-4) — zero new
/// composite indexes
///
/// Every `list()` query here is capped at `request.query.limit <= 500` in
/// production; `fake_cloud_firestore` does not enforce this at all (see
/// `firestore_learning_ledger_repository.dart`'s class doc comment for the
/// full reasoning, identical here). [getCompletionsForCurriculum] and
/// [getCompletionsByDateRange] page internally via [_fetchAllPagesByDocId] /
/// a `completed_at`-ordered cursor loop rather than issuing one unbounded
/// `.get()`.
///
/// Every query in this file is deliberately either (a) equality-only
/// (including `whereIn`) across any number of fields, which Firestore
/// serves from single-field indexes with NO composite index — see
/// `FirestoreLearningLedgerRepository._nextCompletionNumber`'s doc comment
/// for the same point — or (b) a single range filter on `completed_at` with
/// no other filter, ordered by that same field, which is also a single-
/// field index. **No method in this repository requires a new composite
/// index.** This was a deliberate design choice, not an accident: an
/// earlier draft considered a `curriculum_id`-equality +
/// `completed_at`-orderBy "recent activity for this curriculum" query (the
/// live analogue of `FirestoreStageDefinitionRepository`'s
/// `curriculum_id`+`stage_order` composite), but it was dropped in favor of
/// the doc-id-ordered (unordered-by-time, but complete and index-free)
/// equivalent — see [watchCompletionsForCurriculum]'s doc comment.
///
/// ## Aggregates are computed client-side
///
/// `CompletionDao` has real `GROUP BY`/`COUNT(DISTINCT)` SQL
/// ([CompletionDao.getTrackBreakdownByProfile],
/// [CompletionDao.getAggregateCountByProfile], etc.) — Firestore has no
/// `GROUP BY`. [getAggregateCountForCurriculum],
/// [getTrackTypeBreakdownForCurriculum], [getReviewCountsByItem], and
/// [getStageBreakdownByItem] all compute their aggregate client-side over a
/// bounded (paginated) query result, not server-side.
///
/// ## Trimmed from the Drift-era `CompletionDao`/`CompletionRepository`
/// surface — not reimplemented
///
/// - **Every `int trackId`-keyed method**
///   (`getCompletionsByTrack`/`getCompletionsByTrackAndProfile`/
///   `getCompletionsByTrackAndProfileSince`/`getAggregateCountByTrack`/
///   `completionExistsByTrack`/`getCompletionsByDateRangeAndTrack`/
///   `getReviewCountsByItemAndTrack`/`getStageBreakdownByItemAndTrack`) is
///   absent — AD-25 retired the per-device track id; `curriculum_id` is the
///   sole canonical stable track key now, so the curriculum-scoped methods
///   below (e.g. [getCompletionsForCurriculum]) are the direct replacements.
/// - **`getCompletionById(int id)` does not exist.** There is no Drift
///   autoincrement id here; the doc-id IS the identity, and it is derived
///   from the natural key, not looked up by a surrogate.
/// - **Every `internal…CrossProfile` method is absent.** This repository is
///   constructed already profile-scoped (constructor-level [profileId], the
///   same structural argument `FirestoreGoalRepository`'s doc comment makes
///   for dropping `GoalProfileMismatchException`) — there is no way to
///   construct a request that reaches another profile's completions through
///   this class. A genuine cross-profile analytics need belongs in a
///   dedicated repository/service that instantiates one of these per
///   profile and aggregates the results, not here.
/// - **`completionExistsByProfile`/`completionExists` do not take
///   `trackType` or `completedAt` parameters.** The doc-id's actual natural
///   key (see "`trackType` is NOT part of the doc-id's natural key" above)
///   is `(profileId, sefariaRef, stageId, curriculumId)` — existence is a
///   direct doc-id `.get()`, not a query, and a parameter this repository
///   would silently ignore is worse than one it never accepts.
/// - **`getExistingSefariaRefsForBulkStage`/`getCompletionsForRefsBulkStage`
///   (chunked `IN` helpers for the Drift bulk-import path) are not ported.**
///   [recordCompletionsBatch] here writes unconditionally (deterministic
///   doc-ids make a duplicate write idempotent via SR-1's byte-identical-
///   replay rule); there is no separate "which of these already exist"
///   pre-check step the way SQLite's `INSERT OR IGNORE` needed one.
class FirestoreCompletionRepository {
  FirestoreCompletionRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  /// Firestore's hard per-`WriteBatch` operation cap, and also exactly
  /// `firestore.rules`' SR-4 `list()` cap for this collection
  /// (`request.query.limit <= 500`) — see the class doc comment.
  static const _maxPageSize = 500;

  CollectionReference<Map<String, dynamic>> get _completions => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('completions');

  /// See the class doc comment's "Doc-id" section. Routes through
  /// [DocIds.completionDocIdForProfile] — the `String`-profileId variant
  /// added for exactly this repository — rather than reproducing the shape
  /// inline, so the "doc-ids always come from `DocIds`" rule holds.
  String _docId(CompletionEntity entity) =>
      DocIds.completionDocIdForProfile(_profileId, entity.toFirestore());

  DocumentReference<Map<String, dynamic>> _doc(CompletionEntity entity) =>
      _completions.doc(_docId(entity));

  /// Direct doc-id lookup for [completionExists] — same natural-key
  /// components as [_docId], built from raw fields rather than a full
  /// [CompletionEntity] (a caller checking existence usually does not have
  /// one yet).
  String _docIdFromKey({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
  }) => DocIds.completionDocIdForProfile(_profileId, {
    'curriculum_id': curriculumId.storageKey,
    'sefaria_ref': sefariaRef,
    'stage_id': stageId,
  });

  /// Converts a `completed_at` that arrived as a real Firestore [Timestamp]
  /// back into a UTC [DateTime] — see the class doc comment's
  /// "`completed_at` round-trips through a real `Timestamp`" section. Every
  /// read call site routes through this before decoding.
  Map<String, dynamic> _normalizeForDecode(Map<String, dynamic> raw) {
    var out = raw;
    final completedAt = out['completed_at'];
    if (completedAt is Timestamp) {
      out = {...out, 'completed_at': completedAt.toDate().toUtc()};
    }
    // D-L: `purged_at` round-trips as a real Firestore `Timestamp` exactly as
    // `completed_at` does, and `FirestoreCodec.parseDateTime` has NO
    // `Timestamp` branch (firestore_codec.dart:34-51) — handed one it returns
    // null, which would silently decode a PURGED completion as ACTIVE. That is
    // a silent-corruption path no gate can see, so normalize here and never
    // rely on parseDateTime to recognise a raw Timestamp.
    final purgedAt = out['purged_at'];
    if (purgedAt is Timestamp) {
      out = {...out, 'purged_at': purgedAt.toDate().toUtc()};
    }
    return out;
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row fail
  /// the whole read — same treatment as every other repository in this
  /// rewrite.
  List<CompletionEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <CompletionEntity>[];
    for (final doc in docs) {
      try {
        final entity = completionEntityFromFirestore(
          _normalizeForDecode(doc.data()),
        );
        // D-L: a tombstoned completion is invisible to every reader. This is
        // the SINGLE choke point for that rule — every list read and all four
        // client-side aggregates funnel through here, so filtering once covers
        // them all. `getCompletion` deliberately bypasses this helper, because
        // the writer must SEE a tombstone in order to resurrect it.
        if (entity.purgedAt != null) continue;
        results.add(entity);
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_completions_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Runs [baseQuery] to exhaustion via doc-id-ordered pagination — same
  /// technique and same `fake_cloud_firestore`-specific caveats as
  /// `FirestoreLearningLedgerRepository._fetchAllPages` (see that method's
  /// doc comment for the `startAfterDocument`-vs-`startAfter([id])` and
  /// limit-chaining-order pitfalls verified against `fake_cloud_firestore`
  /// 4.1.1). [baseQuery] must carry ONLY equality/`whereIn` filters (no
  /// `orderBy`, no range filter) — see the class doc comment's "zero new
  /// composite indexes" section.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _fetchAllPagesByDocId(Query<Map<String, dynamic>> baseQuery) async {
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var page = baseQuery.orderBy(FieldPath.documentId);
      if (cursor != null) {
        page = page.startAfterDocument(cursor);
      }
      page = page.limit(_maxPageSize);
      final snapshot = await page.get();
      results.addAll(snapshot.docs);
      if (snapshot.docs.length < _maxPageSize) break;
      cursor = snapshot.docs.last;
    }
    return results;
  }

  // ── Writes ────────────────────────────────────────────────────────────

  /// Records one completion. [entity.source] must be [CompletionSource.live]
  /// or [CompletionSource.bulkInTrack] — see the class doc comment.
  ///
  /// Writes unconditionally via `set(..., SetOptions(merge: true))`, mirroring
  /// the old sync gateway's push shape (`docs/firestore-rewrite-map.md`'s
  /// rules comment: "the push uses set(merge:true) on a natural-key doc-id,
  /// so an outbox retry... is an UPDATE"). Idempotency comes entirely from
  /// the deterministic doc-id plus the caller passing byte-identical field
  /// values on any retry — see the class doc comment's "Idempotent retries"
  /// section. There is no pre-write existence check (unlike
  /// `FirestoreLearningLedgerRepository.recordCompletion`'s ulid-exists
  /// short-circuit) because there is no derived field here that a re-query
  /// could recompute wrong — every field this repository writes comes
  /// directly from [entity].
  Future<CompletionEntity> recordCompletion(CompletionEntity entity) async {
    if (entity.source == CompletionSource.lifetimeOnly) {
      throw ArgumentError(
        'CompletionSource.lifetimeOnly must never be written to the '
        'completions collection — it writes only a learning_ledger entry. '
        'See FirestoreCompletionRepository\'s class doc comment.',
      );
    }
    await _doc(entity).set(entity.toFirestore(), SetOptions(merge: true));
    return entity;
  }

  /// Batch-records [entities]. Chunks writes into `WriteBatch`es of at most
  /// [_maxPageSize] (Firestore's hard per-batch operation cap). Every entry
  /// must satisfy the same [CompletionSource] constraint as
  /// [recordCompletion] — validated up front so a batch either writes
  /// entirely or fails before any chunk commits, rather than partially
  /// committing live/bulkInTrack entries ahead of a later rejected one.
  Future<List<CompletionEntity>> recordCompletionsBatch(
    List<CompletionEntity> entities,
  ) async {
    if (entities.isEmpty) return const [];
    for (final entity in entities) {
      if (entity.source == CompletionSource.lifetimeOnly) {
        throw ArgumentError(
          'CompletionSource.lifetimeOnly must never be written to the '
          'completions collection — it writes only a learning_ledger '
          'entry. See FirestoreCompletionRepository\'s class doc comment.',
        );
      }
    }

    for (var offset = 0; offset < entities.length; offset += _maxPageSize) {
      final chunk = entities.skip(offset).take(_maxPageSize);
      final batch = _firestore.batch();
      for (final entity in chunk) {
        batch.set(_doc(entity), entity.toFirestore(), SetOptions(merge: true));
      }
      await batch.commit().orQueuedOffline;
    }
    return entities;
  }

  /// Returns the stored completion for this natural key, or `null` when no
  /// document exists.
  ///
  /// Unlike [completionExists] this DOES return tombstoned completions. The
  /// writer must tell "absent" apart from "purged" in order to resurrect the
  /// latter (owner ruling D-L), and a `bool` cannot carry that distinction —
  /// nor the `source`, which decides whether a bulkInTrack row is being
  /// upgraded to live (B8).
  Future<CompletionEntity?> getCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
  }) async {
    final docId = _docIdFromKey(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
    );
    final snapshot = await _completions.doc(docId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    if (data == null) return null;
    return completionEntityFromFirestore(_normalizeForDecode(data));
  }

  /// Creates the completion document when it is absent, returning `true` when
  /// THIS call created it.
  ///
  /// ## Deliberately NOT a transaction — offline capability wins
  ///
  /// An earlier revision wrapped this in `_firestore.runTransaction` to close
  /// the read-then-write race on the return value. That was the WRONG trade for
  /// this app and was reverted.
  ///
  /// **Firestore transactions require a server round trip and FAIL when the
  /// client is offline**, whereas a plain `set` is queued in the local cache and
  /// replayed on reconnect. Marking a section complete is this app's central
  /// action, and it is performed by children who are frequently offline — on a
  /// bus, in a shul, on a school network. A transaction here meant that marking
  /// work offline threw instead of queueing, which also contradicts this
  /// project's stated design property that "a previously-created account works
  /// fully offline" (`lib/data/firestore/account_firebase.dart`).
  ///
  /// ## What the race actually costs, stated honestly
  ///
  /// `isNew` gates points, streak, siyum detection and bookmark advance (see
  /// `MarkCompletionResult`'s doc comment). Without the transaction, two devices
  /// marking the SAME section for the SAME child at the SAME moment can both
  /// observe "absent" and both report `isNew: true`, double-crediting those four
  /// side effects once.
  ///
  /// That is a rare, cosmetic over-credit. Being unable to record learning while
  /// offline is a core-function failure. The trade is not close, and it is
  /// recorded here so nobody "fixes" this back into a transaction without
  /// weighing the same two costs.
  ///
  /// A tombstoned document counts as PRESENT here and is left untouched —
  /// resurrecting it belongs to [restoreCompletion], so the caller's `isNew`
  /// reports a resurrection rather than a create.
  Future<bool> recordCompletionIfAbsent(CompletionEntity entity) async {
    if (entity.source == CompletionSource.lifetimeOnly) {
      throw ArgumentError(
        'CompletionSource.lifetimeOnly must never be written to the '
        'completions collection — it writes only a learning_ledger entry. '
        "See FirestoreCompletionRepository's class doc comment.",
      );
    }
    final ref = _doc(entity);

    // ── Existence probe, offline-tolerant ────────────────────────────────
    // MEASURED on a real device (cloud_firestore 6.8.0, Android emulator,
    // Firestore emulator): `get()` on a document NOT in the local cache
    // THROWS `FirebaseException(code: 'unavailable')` while offline — it does
    // NOT return a not-exists snapshot. An earlier revision of this method
    // claimed the opposite in a comment; that claim was false and is the reason
    // marking a completion offline still failed after the transaction was
    // removed.
    //
    // Offline we simply cannot know whether the document exists. Treat it as
    // ABSENT and write anyway: the doc-id is deterministic (natural key), so
    // the write is idempotent, and `firestore.rules` accepts an identical
    // replay because `diff().affectedKeys()` is empty for one.
    //
    // Consequence, stated rather than hidden: `isNew` may be reported `true`
    // for a completion that already existed, which can double-credit points /
    // streak / siyum / bookmark-advance once. That is the accepted trade — a
    // child on a bus must be able to record learning, and a rare over-credit
    // is a far smaller harm than a silently discarded completion.
    var exists = false;
    try {
      final snapshot = await ref.get();
      exists = snapshot.exists;
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable') rethrow;
      exists = false;
    }
    if (exists) return false;

    // ── The write itself — NEVER bare-await it ───────────────────────────
    // MEASURED: offline, `await ref.set(...)` never returns, because the
    // Android plugin awaits a Task that completes only on SERVER
    // acknowledgement. The write IS durably queued regardless — the probe
    // confirmed the document was present on the server after reconnecting.
    //
    // So bound the wait and treat a timeout as success-pending-sync. A real
    // failure (permission denied, invalid argument) still surfaces promptly
    // while online, because those return from the server rather than timing
    // out. A bare await here would hang the UI indefinitely on a bus.
    await ref
        .set(entity.toFirestore(), SetOptions(merge: true))
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    return true;
  }

  /// Tombstones an existing completion by stamping `purged_at` — the erasure
  /// path used when a previously bulk-marked item is un-ticked.
  ///
  /// `firestore.rules` denies `delete` on this collection unconditionally, so
  /// erasure is ALWAYS a tombstone (owner ruling D-L, 2026-08-10). Uses
  /// `update` rather than `set` so that exactly one key is affected and D-L's
  /// `affectedKeys().hasOnly([...])` guard is satisfied — a `set` would resend
  /// every field and be denied.
  Future<void> purgeCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime purgedAt,
  }) => _updateStatusFields(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    fields: {'purged_at': purgedAt.toUtc()},
    operation: 'purgeCompletion',
  );

  /// Clears `purged_at` and re-stamps `completed_at` — the re-mark-after-
  /// expunge path, replacing the Drift writer's `_resurrectTombstone`.
  ///
  /// Both keys are inside D-L's mutable allowlist. The caller reports
  /// `isNew = true` for a resurrection, matching the Drift behaviour exactly.
  Future<void> restoreCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime completedAt,
  }) => _updateStatusFields(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    fields: {'purged_at': null, 'completed_at': completedAt.toUtc()},
    operation: 'restoreCompletion',
  );

  /// B8: promotes a bulk-imported completion to real learning by moving
  /// `source` from `bulkInTrack` to `live` and re-stamping `completed_at`
  /// (the bulk sentinel date is replaced by the real moment).
  ///
  /// This replaces the Drift writer's `_upgradePriorMarkRow`, which deleted a
  /// row from the `prior_completion_imports` table. That table is GONE: the
  /// provenance now lives on the completion document itself, so an upgraded
  /// completion is invisible to expunge simply because its `source` is no
  /// longer `bulkInTrack`. Both keys are inside D-L's mutable allowlist.
  Future<void> upgradeSourceToLive({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime completedAt,
  }) => _updateStatusFields(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    fields: {
      'source': CompletionSource.live.name,
      'completed_at': completedAt.toUtc(),
    },
    operation: 'upgradeSourceToLive',
  );

  /// Shared body for the three D-L status transitions above.
  ///
  /// Throws [StateError] when the document is absent: per owner ruling D-E a
  /// path that cannot do its job must fail LOUDLY rather than silently no-op.
  /// A no-op here would leave a user's un-tick looking successful while the
  /// record survived — exactly the silent divergence D-E exists to prevent.
  Future<void> _updateStatusFields({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required Map<String, Object?> fields,
    required String operation,
  }) async {
    final docId = _docIdFromKey(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
    );
    final ref = _completions.doc(docId);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw StateError(
        '$operation: no completion document at $docId. A status change on a '
        'completion that does not exist must fail loudly, never no-op (D-E).',
      );
    }
    await ref.update(fields).orQueuedOffline;
  }

  // ── Reads ─────────────────────────────────────────────────────────────

  /// Returns every completion for [curriculumId] — the direct replacement
  /// for `CompletionDao.getCompletionsByCurriculumAndProfile`. Paginated
  /// internally (see the class doc comment's "500-item list() cap"
  /// section); unordered, matching the Drift query it replaces (which had
  /// no `ORDER BY` either).
  Future<List<CompletionEntity>> getCompletionsForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final docs = await _fetchAllPagesByDocId(
      _completions.where('curriculum_id', isEqualTo: curriculumId.storageKey),
    );
    return _decodeAll(docs);
  }

  /// Live updates for [curriculumId]'s completions, doc-id ordered and
  /// bounded at [_maxPageSize] (`firestore.rules`' SR-4 cap) — a "the first
  /// 500 by doc-id" live view, NOT a "most recent 500" one. An earlier draft
  /// ordered by `completed_at` instead (giving a genuine recency ordering)
  /// but that combination (`curriculum_id` equality + `completed_at`
  /// orderBy, different fields) needs a NEW composite index — dropped in
  /// favor of this index-free equivalent; see the class doc comment's "zero
  /// new composite indexes" section. A caller that genuinely needs
  /// most-recent-first should sort the emitted list client-side by
  /// `completedAt` (every document has one — never nullable here, unlike
  /// `GoalEntity.targetDate`) and treat the 500-cap as a real limit; this
  /// method does not attempt to page a live subscription past it.
  Stream<List<CompletionEntity>> watchCompletionsForCurriculum(
    CurriculumId curriculumId,
  ) {
    return resilientQueryStream<CompletionEntity>(
      openStream: () => _completions
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy(FieldPath.documentId)
          .limit(_maxPageSize)
          .snapshots(),
      decode: (doc) =>
          completionEntityFromFirestore(_normalizeForDecode(doc.data())),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_completions_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map(
      // D-L: tombstoned completions are invisible to readers. This stream
      // decodes per-document and so cannot route through `_decodeAll`; the
      // filter is applied to each emitted list instead.
      (entities) => entities.where((e) => e.purgedAt == null).toList(),
    );
  }

  /// Returns completions for [sefariaRef] — replaces
  /// `CompletionDao.getCompletionsForContentAndProfile`. A single item's
  /// completions across a profile's whole history is expected to stay well
  /// under [_maxPageSize] (at most a handful of stages × a handful of
  /// re-reviews), so this issues one bounded query rather than paginating —
  /// flagged explicitly: a caller that reviews the SAME item hundreds of
  /// times could theoretically exceed the cap and see a truncated list.
  Future<List<CompletionEntity>> getCompletionsForContent(
    String sefariaRef,
  ) async {
    final snapshot = await _completions
        .where('sefaria_ref', isEqualTo: sefariaRef)
        .limit(_maxPageSize)
        .get();
    return _decodeAll(snapshot.docs);
  }

  /// Returns `true` if a completion exists for the natural key
  /// `(curriculumId, sefariaRef, stageId)` for this profile — direct doc-id
  /// `.get()`, not a query. Deliberately does NOT accept `trackType` — see
  /// the class doc comment's "`trackType` is NOT part of the doc-id's
  /// natural key" section for why a parameter this method would silently
  /// ignore is worse than one it never accepts.
  Future<bool> completionExists({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
  }) async {
    final docId = _docIdFromKey(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
    );
    final snapshot = await _completions.doc(docId).get();
    if (!snapshot.exists) return false;
    final data = snapshot.data();
    if (data == null) return false;
    // D-L: a tombstoned completion does NOT exist for idempotency purposes —
    // re-marking it must resurrect it and report isNew = true. This mirrors the
    // Drift writer's H1 fix, where tombstoned rows were deliberately excluded
    // from the pre-insert existence check so a re-mark after expunge was not
    // silently swallowed.
    return _normalizeForDecode(data)['purged_at'] == null;
  }

  /// Returns `true` if any completion references [curriculumId] +
  /// [stageOrder] — the method `FirestoreStageDefinitionRepository`'s class
  /// doc comment flagged as belonging here (`hasCompletionsForStage`, keyed
  /// by `(curriculumId, stageOrder)` rather than a Drift `int stageId`). Two
  /// equality filters on different fields, no `orderBy` — no composite index
  /// needed.
  Future<bool> hasCompletionsForStage({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) async {
    // D-L: `limit(1)` would answer `true` for a purely tombstoned stage, so
    // this can no longer short-circuit — it pages and decodes, because
    // `_decodeAll` is what applies the tombstone filter. Costs a full scan of
    // the stage's completions in exchange for a correct answer.
    final docs = await _fetchAllPagesByDocId(
      _completions
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .where('stage_id', isEqualTo: stageOrder),
    );
    return _decodeAll(docs).isNotEmpty;
  }

  /// Returns completions in `[start, end]` inclusive, across every
  /// curriculum — replaces `CompletionDao.getCompletionsByDateRangeAndProfile`.
  /// A single range filter on `completed_at`, ordered by that SAME field
  /// (Firestore requires the first `orderBy` to match a range-filtered
  /// field) — a single-field index, no composite index needed. Paginated
  /// via `startAfterDocument` (works with any `orderBy` field, unlike
  /// [_fetchAllPagesByDocId], which is hard-coded to doc-id ordering because
  /// none of its callers filter on a range).
  Future<List<CompletionEntity>> getCompletionsByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      // Two CHAINED `.where()` calls, not one call with both
      // `isGreaterThanOrEqualTo`/`isLessThanOrEqualTo` named parameters —
      // verified against `fake_cloud_firestore` 4.1.1: the single-call form
      // silently applies only ONE of the two bounds (observed: it let a
      // document past the upper bound through), while two chained calls
      // filter correctly. Not on `docs/firestore-rewrite-map.md`'s existing
      // `fake_cloud_firestore` quirks list — a new one, flagged here.
      var page = _completions
          .where('completed_at', isGreaterThanOrEqualTo: start.toUtc())
          .where('completed_at', isLessThanOrEqualTo: end.toUtc())
          .orderBy('completed_at');
      if (cursor != null) {
        page = page.startAfterDocument(cursor);
      }
      page = page.limit(_maxPageSize);
      final snapshot = await page.get();
      results.addAll(snapshot.docs);
      if (snapshot.docs.length < _maxPageSize) break;
      cursor = snapshot.docs.last;
    }
    return _decodeAll(results);
  }

  /// Returns `true` if any completion falls in `[start, end]` inclusive —
  /// replaces `CompletionDao.hasCompletionsInDateRangeByProfile`. Same
  /// single-field range+orderBy shape as [getCompletionsByDateRange], capped
  /// at 1 result.
  Future<bool> hasCompletionsInDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    // D-L: `limit(1)` would answer `true` for a range containing only
    // tombstoned completions, so this delegates to the paging read whose
    // `_decodeAll` applies the tombstone filter. Costs a full range scan in
    // exchange for a correct answer; the `fake_cloud_firestore` two-chained-
    // `.where()` shape that [getCompletionsByDateRange]'s doc comment
    // describes is preserved because this now IS that query.
    final inRange = await getCompletionsByDateRange(start: start, end: end);
    return inRange.isNotEmpty;
  }

  /// Returns completions filtered by [tier], optionally narrowed to
  /// [curriculumId] — the plain-field-filter replacement for
  /// `CompletionDao.getCompletionsByTier`'s 8 call sites (see the class doc
  /// comment's "`source` replaces the entire prior-import tier apparatus"
  /// section).
  ///
  /// - [CompletionTierFilter.liveOnly] → `source == 'live'`.
  /// - [CompletionTierFilter.trackAchievement] and
  ///   [CompletionTierFilter.lifetime] → **no source filter at all**, and
  ///   therefore return the SAME result set. Every document in this
  ///   collection already has `source` ∈ {`live`, `bulkInTrack`} (a
  ///   `lifetimeOnly` document can never exist here — enforced by
  ///   [recordCompletion]/[recordCompletionsBatch]), so both tiers already
  ///   include everything this collection can hold. See the class doc
  ///   comment's "A consequence worth being explicit about" section for why
  ///   a caller wanting the historical `lifetime` semantics (this PLUS
  ///   `lifetimeOnly` imports) must separately query
  ///   `FirestoreLearningLedgerRepository`.
  ///
  /// Every filter combination here is equality/`whereIn` only — no
  /// composite index needed (see the class doc comment).
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
  }) async {
    Query<Map<String, dynamic>> query = _completions;
    if (curriculumId != null) {
      query = query.where('curriculum_id', isEqualTo: curriculumId.storageKey);
    }
    if (tier == CompletionTierFilter.liveOnly) {
      query = query.where('source', isEqualTo: CompletionSource.live.name);
    }
    final docs = await _fetchAllPagesByDocId(query);
    return _decodeAll(docs);
  }

  // ── Client-side aggregates ───────────────────────────────────────────
  //
  // Firestore has no `GROUP BY`/`COUNT(DISTINCT)` — every method below
  // computes its aggregate client-side over a bounded (paginated) query
  // result. See the class doc comment's "Aggregates are computed
  // client-side" section.

  /// Count of DISTINCT `sefariaRef`s completed for [curriculumId] — mirrors
  /// `CompletionDao.getAggregateCountByProfile`'s `COUNT(DISTINCT
  /// sefariaRef)` semantics (completing the same ref at multiple stages
  /// counts once).
  Future<int> getAggregateCountForCurriculum(CurriculumId curriculumId) async {
    final completions = await getCompletionsForCurriculum(curriculumId);
    return completions.map((c) => c.sefariaRef).toSet().length;
  }

  /// Completion count per `trackType` for [curriculumId] — mirrors
  /// `CompletionDao.getTrackBreakdownByProfile`.
  Future<Map<String, int>> getTrackTypeBreakdownForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final completions = await getCompletionsForCurriculum(curriculumId);
    final breakdown = <String, int>{};
    for (final completion in completions) {
      breakdown[completion.trackType] =
          (breakdown[completion.trackType] ?? 0) + 1;
    }
    return breakdown;
  }

  /// Total review count per `sefariaRef` for [curriculumId] — mirrors
  /// `CompletionDao.getReviewCountsByItem`.
  Future<Map<String, int>> getReviewCountsByItem(
    CurriculumId curriculumId,
  ) async {
    final completions = await getCompletionsForCurriculum(curriculumId);
    final counts = <String, int>{};
    for (final completion in completions) {
      counts[completion.sefariaRef] = (counts[completion.sefariaRef] ?? 0) + 1;
    }
    return counts;
  }

  /// Per-stage review-count breakdown for one [sefariaRef] within
  /// [curriculumId] — mirrors `CompletionDao.getStageBreakdownByItem`.
  Future<Map<int, int>> getStageBreakdownByItem({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final snapshot = await _completions
        .where('curriculum_id', isEqualTo: curriculumId.storageKey)
        .where('sefaria_ref', isEqualTo: sefariaRef)
        .limit(_maxPageSize)
        .get();
    final completions = _decodeAll(snapshot.docs);
    final breakdown = <int, int>{};
    for (final completion in completions) {
      breakdown[completion.stageId] = (breakdown[completion.stageId] ?? 0) + 1;
    }
    return breakdown;
  }
}
