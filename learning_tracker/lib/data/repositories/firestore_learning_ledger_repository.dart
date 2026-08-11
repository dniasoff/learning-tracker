/// Firestore implementation for the learning ledger — one of the two
/// APPEND-ONLY repositories in the Firestore rewrite
/// (`docs/firestore-rewrite-map.md`; the other is
/// `firestore_streak_event_repository.dart`). Copies the shape
/// `firestore_bookmark_repository.dart` established (resolved-handle
/// constructor, `DocIds`-only doc-ids, entity-owned codec, streams as
/// ordinary methods, `resilientDocStream`/`resilientQueryStream`) and the
/// composite-index query handling `firestore_stage_definition_repository.dart`
/// added, then layers on what append-only + genuinely-unbounded-over-a-
/// lifetime specifically demands. See the class doc comment for the parts
/// that are new here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';

/// Firestore-backed learning-ledger repository: `users/{uid}/
/// learner_profiles/{profileId}/learning_ledger/{ulid}` — append-only,
/// doc-id is the entry's own ULID (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /learning_ledger/{entryId}`).
///
/// **Not wired into any screen yet** — but
/// `FirestoreGamificationLedgerRepository`
/// (`lib/features/gamification/data/repositories/
/// firestore_gamification_ledger_repository.dart`) already reads this class
/// via `firestoreLearningLedgerRepositoryProvider`, built ahead of a
/// consumer for a future gamification feature (see that file's own doc
/// comment, "Not wired to any current caller"). The `learning` feature's
/// own reads/writes still go through the Drift-backed
/// `LearningLedgerRepositoryImpl`
/// (`lib/features/learning/data/repositories/`), which is untouched.
///
/// **No interface, no `implements`** — same reasoning as
/// `FirestoreBookmarkRepository`'s doc comment: the Drift implementation is
/// being deleted outright, not kept alongside this one.
///
/// ## Why this collection matters — do not weaken it
///
/// The owner flagged lifetime learning statistics as potentially a very
/// important feature: *"it would be nice to track everything I have learnt
/// and how many times I have learnt something over my lifetime."* This
/// collection IS that record: append-only, ULID-keyed, carries
/// [LearningLedgerEntry.completionNumber] (the nth lifetime completion of a
/// unit), and deliberately has no foreign keys to tracks or curricula so
/// entries survive their deletion (see [LearningLedgerEntry]'s doc comment).
/// Every method below is written so a long-lived learner's full history
/// stays reachable — see "The 500-item list cap" below for why that is not
/// automatic.
///
/// ## What's new here, beyond the Bookmarks/StageDefinitions pattern
///
/// ### The 500-item `list()` cap (`firestore.rules` SR-4)
///
/// `firestore.rules` caps every `list()` read on this collection at
/// `request.query.limit <= 500` — a query with NO `.limit()`, or one above
/// 500, is denied outright in production. `fake_cloud_firestore` does not
/// enforce this at all (a test here proves the DATA is correct, never that
/// the cap was respected). This is easy to miss for a collection like
/// `stage_definitions` (a handful of docs per curriculum) but is exactly
/// the failure mode this collection is built for: a learner who has been
/// using the app for years can have a lifetime ledger comfortably past 500
/// entries. [getLifetimeLedger] and [getLedgerForCurriculum] therefore page
/// internally via [_fetchAllPages] (doc-id-ordered, `_maxPageSize`-capped,
/// `startAfter`-chained) rather than issuing one unbounded `.get()` — the
/// Drift-era `getLifetimeLedger`/`getCompletionStats` never had to think
/// about this because SQLite has no such limit.
///
/// ### Why not `.count()` aggregate queries
///
/// Firestore's server-side `count()` aggregation would avoid transferring
/// full documents just to size a list — [_countAll] does not use it.
/// Whether an aggregation query is evaluated under the same `list` rule as
/// a normal read, and whether `request.query.limit` is even populated for
/// one issued with no `.limit()`, is genuinely unclear from the rules text
/// alone, and `fake_cloud_firestore`'s rules companion does not model
/// aggregation queries at all — there is no way to settle this from here.
/// Paginating the underlying documents under an explicit `.limit(500)`
/// sidesteps that ambiguity entirely, at the cost of transferring more
/// data than a `count()` would.
///
/// ### Retry-safe `completionNumber`, without a stored counter
///
/// [recordCompletion] computes `completionNumber` by counting existing
/// entries for `(curriculumId, unitIdentifier)` and adding one — never a
/// stored counter document (`docs/firestore-rewrite-map.md`: "Balances and
/// streaks are derived from append-only ledgers, never stored counters").
/// That count-then-write is not atomic (the Flutter `cloud_firestore`
/// `Transaction` API only supports `get()` on a single `DocumentReference`,
/// never a query — see `package:cloud_firestore`'s `Transaction` class —
/// so a real cross-device race between two independent completions of the
/// same unit at nearly the same instant can still produce a duplicate
/// `completionNumber`; this is a pre-existing, documented limitation, not a
/// regression — the Drift-era implementation had the same non-atomic
/// "read count, then insert" shape). What IS fixed here: a **retry of the
/// same call** (the caller reuses the [recordCompletion] `ulid` parameter
/// after an ambiguous failure — lost ack, timeout, etc.) is safe.
/// [recordCompletion] checks whether a document at that ulid already exists
/// BEFORE computing `completionNumber`; if it does, that already-committed
/// entry is returned as-is with no re-query and no re-write. Without this
/// check, a retry's count query would see its own prior (successful but
/// unacked) write and compute one-too-many — exactly the "do not stamp a
/// client the current wall-clock time into a field on retry" landmine, generalized to
/// "do not recompute a derived field from post-write state on retry".
///
/// ### `recordCompletionsBatch` does NOT get the same retry protection
///
/// A per-item exists-check before a batched write would cost one read per
/// item, largely defeating the point of batching for a bulk import (the
/// primary use case — see `docs/firestore-rewrite-map.md`'s "prior-import
/// tier" discussion). [recordCompletionsBatch] therefore mints (or accepts,
/// via [LedgerEntryDraft.ulid]) each entry's ulid up front and writes
/// directly. A caller that retries an entire batch call with the same
/// drafts (same ulids) after a partial failure and finds some entries
/// already committed will get a **rules-level permission-denied** on those
/// specific docs (the recomputed `completionNumber` no longer matches what
/// SR-1's byte-identical-replay update rule requires) rather than either a
/// silent duplicate or a silently wrong number — a safe failure mode, not a
/// transparent one. Flagged, not silently glossed over.
///
/// ### One-shot reads get the same per-document decode leniency as streams
///
/// [_decodeAll] applies the same "skip a malformed document, do not fail
/// the whole read" treatment as `resilientQueryStream` to every one-shot
/// paginated read too (mirrors `FirestoreStageDefinitionRepository`).
///
/// ### `completed_at` round-trips through a real `Timestamp`, not a string
///
/// [LearningLedgerEntryFirestoreCodec.toFirestore] writes `completed_at` as
/// a raw [DateTime] (not `FirestoreCodec.encodeDateTime`'s ISO-8601
/// `String`) — required so the field lands with real Firestore `timestamp`
/// type and satisfies `firestore.rules`' SR-3 `completed_at is timestamp`
/// guard; see that extension's doc comment for why a `String` would fail
/// rules validation outright. The other side of that same coin: reading
/// the field back hands this repository a `Timestamp` OBJECT (confirmed
/// against `fake_cloud_firestore` — `.data()` never auto-converts it to a
/// plain `DateTime`), which [learningLedgerEntryFromFirestore] cannot
/// decode on its own (it stays free of any `cloud_firestore` import, like
/// `FirestoreCodec` itself). [_normalizeForDecode] is the one place that
/// gap is closed — every call site that decodes a document read from
/// Firestore routes through it first. `Timestamp.toDate()` returns a
/// **local-time** `DateTime`, not UTC (verified empirically — this is easy
/// to get wrong silently), so [_normalizeForDecode] also re-normalizes to
/// UTC.
///
/// ## Trimmed from the Drift-era interface — not reimplemented
///
/// `LearningLedgerRepository` (`lib/features/learning/domain/repositories/`)
/// is not `implements`ed — same reasoning as `FirestoreBookmarkRepository`.
/// Specifically NOT ported:
/// - **The `ChildSelfMarkException` permission check.** It depends on
///   `ProfileMode` and an active parent-PIN session — app-session state,
///   not a Firestore concern. Belongs in the use-case layer that will call
///   this repository (out of scope here — building it is stage "C" of the
///   migration, see `docs/firestore-rewrite-map.md`).
/// - **`CompletionSource`-driven sentinel-date selection.** Deciding
///   whether `completedAt` should be the real time or
///   `kBulkPriorSentinelDate` is a domain policy question, independent of
///   how it is persisted. [recordCompletion]/[recordCompletionsBatch] take
///   `completedAt` as an explicit parameter instead — the caller decides.
class FirestoreLearningLedgerRepository {
  FirestoreLearningLedgerRepository({
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
  /// (`request.query.limit <= 500`) — every query and every batch this
  /// repository issues stays at or under this.
  static const _maxPageSize = 500;

  CollectionReference<Map<String, dynamic>> get _ledger => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('learning_ledger');

  /// [ulid] is always supplied non-null by every call site below, so
  /// [DocIds.learningLedgerDocId]'s nullable-payload fallback (`data['ulid']
  /// as String?` being absent) is never reached here. The explicit `String`
  /// local (rather than `!`-ing straight into `.doc()`) is deliberate:
  /// `CollectionReference.doc([String? path])` itself accepts null (falling
  /// back to a random server-assigned id), so asserting non-null right at
  /// `.doc()` would be silently optional to the type checker — this
  /// collection's append-only idempotency depends on the doc-id always
  /// being this exact ulid, never a random fallback.
  DocumentReference<Map<String, dynamic>> _doc(String ulid) {
    final docId = DocIds.learningLedgerDocId({'ulid': ulid})!;
    return _ledger.doc(docId);
  }

  /// Converts a `completed_at` that arrived as a real Firestore [Timestamp]
  /// back into a UTC [DateTime] so [learningLedgerEntryFromFirestore] (kept
  /// free of any `cloud_firestore` import) can decode it — see the class
  /// doc comment's "`completed_at` round-trips through a real `Timestamp`"
  /// section. Every read call site in this repository routes through this
  /// first; a raw map built directly in a test (already a [DateTime]) is
  /// left untouched.
  Map<String, dynamic> _normalizeForDecode(Map<String, dynamic> raw) {
    var out = raw;
    final completedAt = out['completed_at'];
    if (completedAt is Timestamp) {
      out = {...out, 'completed_at': completedAt.toDate().toUtc()};
    }
    // D-M: `purged_at` round-trips as a real `Timestamp` exactly as
    // `completed_at` does, and `FirestoreCodec.parseDateTime` has NO
    // `Timestamp` branch (firestore_codec.dart:34-51) — handed one it returns
    // null, which would silently decode a RETRACTED siyum as active. Normalize
    // it here for the same reason.
    final purgedAt = out['purged_at'];
    if (purgedAt is Timestamp) {
      out = {...out, 'purged_at': purgedAt.toDate().toUtc()};
    }
    return out;
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the whole read (see the class doc comment).
  List<LearningLedgerEntry> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <LearningLedgerEntry>[];
    for (final doc in docs) {
      try {
        final entry = learningLedgerEntryFromFirestore(
          _normalizeForDecode(doc.data()),
        );
        // D-M: a retracted siyum is invisible to every reader. This is the
        // single choke point — `getLifetimeLedger`, `getLedgerForCurriculum`
        // and `getCompletionStats` all funnel through here.
        //
        // NOTE the deliberate asymmetry: `_countAll` / `_nextCompletionNumber`
        // do NOT filter tombstones. `completionNumber` must stay monotonic, so
        // a retracted entry still consumes its number and no later entry ever
        // reuses one. Do not "fix" that to match this filter.
        if (entry.purgedAt != null) continue;
        results.add(entry);
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_learning_ledger_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Runs [baseQuery] to exhaustion via doc-id-ordered pagination, keeping
  /// every underlying request at or under `firestore.rules`' SR-4 500-item
  /// `list()` cap (see the class doc comment). Ordering by
  /// `FieldPath.documentId` needs no composite index (a single-field order,
  /// always available) and, because doc-ids here are ULIDs, happens to also
  /// be roughly chronological.
  ///
  /// Pages via [Query.startAfterDocument], NOT `startAfter([lastDocId])` —
  /// verified against `fake_cloud_firestore` 4.1.1: its `startAfter`
  /// implementation (`MockQuery._subQueryByKeyValues`) calls
  /// `doc.get(FieldPath.documentId)` on every candidate document, but
  /// `MockDocumentSnapshot.get` only accepts a `String` or a real
  /// `FieldPath` instance — `FieldPath.documentId` is itself a
  /// `FieldPathType` enum value, not an instance of that class, so that
  /// combination throws `Invalid argument(s): key must be String or
  /// FieldPath but found FieldPathType` (`orderBy`'s OWN sort comparator
  /// special-cases this same enum value correctly; `startAfter`'s does
  /// not — an inconsistency inside the fake, not a design choice reachable
  /// from either the real `cloud_firestore` API or the doc comment's own
  /// stated invariants). `startAfterDocument` sidesteps it entirely — it
  /// matches by `snapshot.id` directly, never calling `.get()` at all.
  ///
  /// `.startAfterDocument(cursor)` is chained BEFORE `.limit(_maxPageSize)`,
  /// not after — also verified empirically, and also fake-specific:
  /// `fake_cloud_firestore` evaluates a query chain as a literal sequential
  /// pipeline, each call transforming the PREVIOUS call's already-computed
  /// result list (`MockQuery._operation`), unlike real Firestore's
  /// order-independent query-descriptor builder. Chaining `.limit()`
  /// first would truncate to the top [_maxPageSize] docs from the START of
  /// the whole (unfiltered) ordering BEFORE the cursor filter ever runs —
  /// `cursor` (the previous page's last doc) is always inside that same
  /// top slice, so `startAfterDocument` would find it at the very end and
  /// return an empty remainder every time, silently truncating the result
  /// at exactly [_maxPageSize] regardless of how many documents actually
  /// exist beyond it.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchAllPages(
    Query<Map<String, dynamic>> baseQuery,
  ) async {
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

  /// See the class doc comment's "Why not `.count()` aggregate queries"
  /// section for why this pages full documents rather than aggregating.
  Future<int> _countAll(Query<Map<String, dynamic>> baseQuery) async {
    final docs = await _fetchAllPages(baseQuery);
    return docs.length;
  }

  /// Equality-only filter (`curriculum_id` == , `unit_identifier` ==) — no
  /// composite index required; Firestore serves a pure multi-equality `AND`
  /// from single-field indexes alone (unlike an equality-filter +
  /// `orderBy`-on-a-different-field combination, which
  /// `FirestoreStageDefinitionRepository` needs a composite index for).
  Future<int> _nextCompletionNumber({
    required CurriculumId curriculumId,
    required String unitIdentifier,
  }) async {
    final count = await _countAll(
      _ledger
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .where('unit_identifier', isEqualTo: unitIdentifier),
    );
    return count + 1;
  }

  /// Records one lifetime completion. Auto-calculates
  /// [LearningLedgerEntry.completionNumber] (existing count for this
  /// `(curriculumId, unitIdentifier)` + 1).
  ///
  /// [source] defaults to [CompletionSource.live], mirroring the Drift-era
  /// `LearningLedgerRepository.recordCompletion`'s own default. It is
  /// written verbatim (see [LearningLedgerEntryFirestoreCodec.toFirestore])
  /// and, like every other parameter here, must stay the SAME value across
  /// a retry of the same logical call — this repository never derives it
  /// from anything else, so that is automatic as long as the caller does
  /// not vary it either.
  ///
  /// Pass the same [ulid] back in on a retry of an ambiguous prior call
  /// (timeout, lost ack) to get that already-committed entry back
  /// idempotently instead of a wrongly-recomputed `completionNumber` — see
  /// the class doc comment's "Retry-safe `completionNumber`" section. Omit
  /// [ulid] to have a fresh one minted.
  Future<LearningLedgerEntry> recordCompletion({
    required CurriculumId curriculumId,
    required String entryScope,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    required DateTime completedAt,
    required String markedBy,
    required bool isManual,
    CompletionSource source = CompletionSource.live,
    String? ulid,
  }) async {
    final id = ulid ?? newUlid();
    final ref = _doc(id);

    final existingSnapshot = await ref.get();
    final existingData = existingSnapshot.data();
    if (existingData != null) {
      return learningLedgerEntryFromFirestore(
        _normalizeForDecode(existingData),
      );
    }

    final completionNumber = await _nextCompletionNumber(
      curriculumId: curriculumId,
      unitIdentifier: unitIdentifier,
    );

    final entry = LearningLedgerEntry(
      ulid: id,
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: unitDisplayNameHe,
      unitDisplayNameEn: unitDisplayNameEn,
      trackType: trackType,
      completedAt: completedAt,
      completionNumber: completionNumber,
      markedBy: markedBy,
      isManual: isManual,
      source: source,
    );
    await ref.set(entry.toFirestore()).orQueuedOffline;
    return entry;
  }

  /// Batch-records [items], all stamped with the same [completedAt] AND the
  /// same [source] — mirrors the Drift-era `recordCompletionsBatch`'s
  /// single shared timestamp and single shared `CompletionSource` for the
  /// whole batch (defaulting to [CompletionSource.lifetimeOnly], same as
  /// that Drift-era method). Chunks writes into `WriteBatch`es of at most
  /// [_maxPageSize] (Firestore's hard per-batch operation cap).
  ///
  /// `completionNumber`s for repeated `(curriculumId, unitIdentifier)`
  /// pairs WITHIN [items] are assigned consecutively via an in-memory
  /// running tally seeded by one query per distinct pair — a `WriteBatch`'s
  /// writes are invisible to reads until it commits, so re-querying
  /// mid-batch would see stale counts and hand out duplicates.
  ///
  /// See the class doc comment's "`recordCompletionsBatch` does NOT get the
  /// same retry protection" section before relying on this for a retried
  /// bulk operation.
  Future<List<LearningLedgerEntry>> recordCompletionsBatch(
    List<LedgerEntryDraft> items, {
    required DateTime completedAt,
    CompletionSource source = CompletionSource.lifetimeOnly,
  }) async {
    if (items.isEmpty) return const [];

    final runningCounts = <String, int>{};
    final entries = <LearningLedgerEntry>[];

    for (final item in items) {
      final key =
          '${item.curriculumId.storageKey}\u0000'
          '${item.unitIdentifier}';
      var count = runningCounts[key];
      if (count == null) {
        final startingCount = await _nextCompletionNumber(
          curriculumId: item.curriculumId,
          unitIdentifier: item.unitIdentifier,
        );
        count = startingCount - 1;
      }
      count += 1;
      runningCounts[key] = count;

      entries.add(
        LearningLedgerEntry(
          ulid: item.ulid ?? newUlid(),
          curriculumId: item.curriculumId,
          entryScope: item.entryScope,
          unitIdentifier: item.unitIdentifier,
          unitDisplayNameHe: item.unitDisplayNameHe,
          unitDisplayNameEn: item.unitDisplayNameEn,
          trackType: item.trackType,
          completedAt: completedAt,
          completionNumber: count,
          markedBy: item.markedBy,
          isManual: item.isManual,
          source: source,
        ),
      );
    }

    for (var offset = 0; offset < entries.length; offset += _maxPageSize) {
      final chunk = entries.skip(offset).take(_maxPageSize);
      final batch = _firestore.batch();
      for (final entry in chunk) {
        batch.set(_doc(entry.ulid), entry.toFirestore());
      }
      await batch.commit().orQueuedOffline;
    }

    return entries;
  }

  /// Returns the WHOLE lifetime ledger for this profile, across every
  /// curriculum — the "track everything I have learnt... over my lifetime"
  /// feature itself. Paginated internally (see the class doc comment's
  /// "500-item list cap" section) so a long lifetime history costs multiple
  /// round trips rather than being silently truncated.
  /// Tombstones a ledger entry by stamping `purged_at` (owner ruling D-M,
  /// 2026-08-10).
  ///
  /// Used when a bulk-marked unit is un-ticked: the completions are purged and
  /// the siyum entry they earned must be retracted with them, or the two
  /// collections disagree permanently. `firestore.rules` denies `delete` on
  /// this collection unconditionally, so retraction is a tombstone.
  ///
  /// `purged_at` is the ONLY key the rules permit to change here, so this uses
  /// `update` with exactly that key — a `set` would resend every field and be
  /// denied. Throws [StateError] when the entry is absent: per owner ruling
  /// D-E a retraction that cannot find its target must fail LOUDLY, never
  /// silently no-op.
  Future<void> purgeEntry({
    required String ulid,
    required DateTime purgedAt,
  }) async {
    final ref = _doc(ulid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw StateError(
        'purgeEntry: no learning_ledger entry at $ulid. A retraction that '
        'cannot find its target must fail loudly, never no-op (D-E).',
      );
    }
    await ref.update({'purged_at': purgedAt.toUtc()}).orQueuedOffline;
  }

  Future<List<LearningLedgerEntry>> getLifetimeLedger() async {
    final docs = await _fetchAllPages(_ledger);
    return _decodeAll(docs);
  }

  /// Returns every ledger entry for [curriculumId], across every unit.
  /// Same pagination treatment as [getLifetimeLedger].
  Future<List<LearningLedgerEntry>> getLedgerForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final docs = await _fetchAllPages(
      _ledger.where('curriculum_id', isEqualTo: curriculumId.storageKey),
    );
    return _decodeAll(docs);
  }

  /// Completion stats for [curriculumId] — mirrors the Drift-era
  /// `LearningLedgerRepository.getCompletionStats` return shape exactly:
  /// `{'total': ..., 'manual': ..., 'auto': ...}`.
  Future<Map<String, int>> getCompletionStats(CurriculumId curriculumId) async {
    final entries = await getLedgerForCurriculum(curriculumId);
    final manual = entries.where((e) => e.isManual).length;
    return {
      'total': entries.length,
      'manual': manual,
      'auto': entries.length - manual,
    };
  }

  /// Live updates for the most recent [limit] ledger entries (any
  /// curriculum), most-recent-first — a bounded "recent activity" feed, NOT
  /// a way to page through the whole lifetime history live. [limit] is
  /// clamped to [_maxPageSize] (`firestore.rules`' SR-4 cap). Resubscribes
  /// with bounded exponential backoff on a stream-level error
  /// (`resilientQueryStream`).
  Stream<List<LearningLedgerEntry>> watchRecentLedgerEntries({
    int limit = 100,
  }) {
    final boundedLimit = limit > _maxPageSize ? _maxPageSize : limit;
    return resilientQueryStream<LearningLedgerEntry>(
      openStream: () => _ledger
          .orderBy(FieldPath.documentId, descending: true)
          .limit(boundedLimit)
          .snapshots(),
      decode: (doc) =>
          learningLedgerEntryFromFirestore(_normalizeForDecode(doc.data())),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_learning_ledger_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'profile_id': _profileId},
      ),
    ).map(
      // D-M: retracted siyums are invisible to readers. This stream decodes
      // per-document and so cannot route through `_decodeAll`; the filter is
      // applied to each emitted list instead.
      (entries) => entries.where((e) => e.purgedAt == null).toList(),
    );
  }
}
