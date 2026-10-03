/// Firestore implementation for the points-spend-economy ledger — the third
/// APPEND-ONLY repository in the Firestore rewrite alongside
/// `firestore_learning_ledger_repository.dart` and
/// `firestore_streak_event_repository.dart`, both of which share most of
/// this file's reasoning — their class doc comments are the fuller read for
/// the 500-item pagination cap, the `.count()` non-use, and the ULID
/// retry-safety pattern. This file's own doc comment covers only what is
/// genuinely different for `points_ledger`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/data/repositories/points_ledger_entry.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

/// `users/{ownerUid}/learner_profiles/{profileId}/points_ledger` of
/// [scope] — where the AD-50 `pts_{eventId}` entries land, in the same
/// batch as their learning events (`FirestoreLearningEventRepository
/// .commit`, DNI-469).
CollectionReference<Map<String, dynamic>> pointsLedgerCollectionFor(
  FirebaseFirestore firestore,
  LearnerScope scope,
) => firestore
    .collection('users')
    .doc(scope.ownerUid)
    .collection('learner_profiles')
    .doc(scope.profileId)
    .collection('points_ledger');

/// The AD-50 `points_ledger/pts_{eventId}` document of [award]: the
/// existing entry shape plus `event_id` (`PointsLedgerEntry.forAward`).
Map<String, dynamic> pointsAwardDocument(PointsAward award) =>
    PointsLedgerEntry.forAward(award).toFirestore();

/// The engine-side [PointsLedgerRow] of a stored [entry]: its doc id, its
/// signed delta, its earning event (null for a non-event row) and its kind.
PointsLedgerRow pointsLedgerRowOf(PointsLedgerEntry entry) => PointsLedgerRow(
  id: entry.ulid,
  amount: entry.delta,
  eventId: entry.eventId,
  entryKind: entry.entryKind,
);

/// Firestore-backed points-ledger repository: `users/{uid}/
/// learner_profiles/{profileId}/points_ledger/{ulid}` — append-only,
/// doc-id is the entry's own ULID (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /points_ledger/{entryId}`).
///
/// **Readers (DNI-480, AD-50).** Every balance and lifetime-earned reader
/// goes through [getTotals] with the engine's `earningEventIds`
/// (`EnginePointsReader`, `lib/features/gamification/data/repositories/`),
/// and redemption affordability through [getBalance]; there is no unfiltered
/// sum left.
///
/// **No interface, no `implements`** — same reasoning as
/// `Firestore repository`'s doc comment: the Drift implementation is
/// being deleted outright, not kept alongside this one.
///
/// ## Owner decision 5 — the balance is DERIVED and CLAMPED, never stored
///
/// `docs/firestore-rewrite-map.md`, "Owner decisions (2026-08-03)", #5:
/// *"Points balance is derived and clamped at zero. Sum the append-only
/// `points_ledger`, then clamp to `[0, 2^30)` exactly as the Drift code
/// does, so nothing a user sees changes... The balance is never stored — a
/// stored counter drifting from its ledger is one of the two dangerous-class
/// defects the ledger design exists to prevent."* [getTotals] is that
/// derivation: it sums the counted entries' [PointsLedgerEntry.delta] on every call
/// — there is no cached/stored counter anywhere in this class, deliberately
/// (mirrors `PointsBalanceDao._applyDeltaInTransaction`/
/// `.reDeriveBalanceFromLedger`'s clamp, `[0, 1 << 30]`, exactly).
///
/// **The negative-raw-sum warning is a real logged warning, not a
/// comment.** A raw (pre-clamp) sum below zero means more deductions than
/// credits were ever recorded for this profile — always an app bug (a
/// `redemption_debit` without a matching balance check, a double-deduct,
/// etc.). The clamp in [getTotals]' return value keeps the child's own
/// screen sane (never shows a negative balance), but must not silently hide
/// that defect from us — so [getTotals] calls [AppLogger.warning] with the
/// raw sum whenever it is negative, before clamping.
///
/// ## What's new here, beyond the learning-ledger/streak-event pattern
///
/// ### No computed field, so no "retry recomputes a stale count" trap
///
/// Unlike `FirestoreLearningLedgerRepository.recordCompletion`'s
/// `completionNumber` (derived from a count query at write time — the whole
/// reason that repository needs an exists-check BEFORE computing anything),
/// nothing [append] writes here is ever derived from existing Firestore
/// state: [PointsLedgerEntry.entryKind]/[PointsLedgerEntry.delta]/
/// [PointsLedgerEntry.note]/[PointsLedgerEntry.redemptionUlid]/
/// [PointsLedgerEntry.source] are all caller-supplied, unchanged verbatim.
/// [append] still checks for an existing document at the target ulid before
/// writing — same as `FirestoreStreakEventRepository.append` — purely so a
/// retry returns the already-committed entry instead of re-issuing an
/// identical write, not because a retry could otherwise compute something
/// wrong.
///
/// ### `createdAt` is caller-supplied, never the current wall-clock time
///
/// Mirrors `FirestoreLearningLedgerRepository.recordCompletion`'s
/// `completedAt` parameter and `FirestoreStreakEventRepository.append`'s
/// `eventTimestamp` parameter: a field this repository itself stamped with
/// the current wall-clock time on every call would silently break the
/// append-only "byte-identical replay" idempotency rule (`firestore.rules`,
/// SR-1) the moment a caller retries the same logical write after a lost
/// ack. The caller decides the instant; this repository just carries it.
///
/// ### `created_at` round-trips through a real `Timestamp`, not a string
///
/// Same SR-3 trap `firestore_learning_ledger_repository.dart`'s class doc
/// comment documents in full for `completed_at` — see
/// [PointsLedgerEntryFirestoreCodec.toFirestore]'s doc comment for the
/// points-ledger-specific version, and [_normalizeForDecode] below for the
/// matching read-side fix (`Timestamp.toDate()` returns LOCAL time, not
/// UTC — re-normalized to UTC here, same as every other append-only
/// repository in this rewrite).
///
/// ### `RewardRedemptions` is explicitly out of scope
///
/// `docs/firestore-rewrite-map.md`: `RewardRedemptions` is "a separate,
/// mutable state machine, not a ledger." This repository never reads or
/// writes that collection — [PointsLedgerEntry.redemptionUlid] carries only
/// a reference (that redemption's own stable ulid), exactly like
/// `PointsBalanceDao._redemptionUlidFor`'s resolution on the Drift side.
class FirestorePointsLedgerRepository {
  FirestorePointsLedgerRepository({
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
  /// (`request.query.limit <= 500`) — every query this repository issues
  /// stays at or under this. See
  /// `firestore_learning_ledger_repository.dart`'s class doc comment for why
  /// pagination (not `.count()`) is how [getLedger]/[getTotals] stay
  /// correct past this cap for a long-lived profile.
  static const _maxPageSize = 500;

  CollectionReference<Map<String, dynamic>> get _ledger => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('points_ledger');

  /// [ulid] is always supplied non-null by every call site below, so
  /// [DocIds.pointsLedgerDocId]'s nullable-payload fallback (`data['ulid']
  /// as String?` being absent) is never reached here. Same explicit-local
  /// reasoning as `FirestoreLearningLedgerRepository._doc` /
  /// `FirestoreStreakEventRepository._doc`.
  DocumentReference<Map<String, dynamic>> _doc(String ulid) {
    final docId = DocIds.pointsLedgerDocId({'ulid': ulid})!;
    return _ledger.doc(docId);
  }

  /// Converts a `created_at` that arrived as a real Firestore [Timestamp]
  /// back into a UTC [DateTime] so [pointsLedgerEntryFromFirestore] (kept
  /// free of any `cloud_firestore` import) can decode it — see the class
  /// doc comment's "`created_at` round-trips through a real `Timestamp`"
  /// section. Every read call site in this repository routes through this
  /// first; a raw map built directly in a test (already a [DateTime]) is
  /// left untouched.
  Map<String, dynamic> _normalizeForDecode(Map<String, dynamic> raw) {
    final createdAt = raw['created_at'];
    if (createdAt is Timestamp) {
      return {...raw, 'created_at': createdAt.toDate().toUtc()};
    }
    return raw;
  }

  PointsLedgerEntry? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return pointsLedgerEntryFromFirestore(
      _normalizeForDecode(data),
      docId: snapshot.id,
    );
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row fail
  /// the whole read (mirrors `FirestoreLearningLedgerRepository._decodeAll`
  /// / `FirestoreStreakEventRepository._decodeAll`).
  List<PointsLedgerEntry> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <PointsLedgerEntry>[];
    for (final doc in docs) {
      try {
        results.add(
          pointsLedgerEntryFromFirestore(
            _normalizeForDecode(doc.data()),
            docId: doc.id,
          ),
        );
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_points_ledger_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Runs [baseQuery] to exhaustion via doc-id-ordered pagination, keeping
  /// every underlying request at or under the SR-4 500-item cap — identical
  /// shape (including the `startAfterDocument`-before-`.limit()` ordering
  /// and the reasons for both) to
  /// `FirestoreLearningLedgerRepository._fetchAllPages` /
  /// `FirestoreStreakEventRepository._fetchAllPages`; see either's doc
  /// comment for the full `fake_cloud_firestore` 4.1.1 rationale, not
  /// repeated here.
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

  /// Appends one points-ledger entry. [entryKind] is `'completion'` |
  /// `'redemption_debit'` | `'redemption_refund'` | `'parent_add'` |
  /// `'parent_deduct'` (`PointsLedger.entryKind`'s Drift-era vocabulary,
  /// unchanged); [delta] is the signed amount applied to the derived
  /// balance.
  ///
  /// Pass the same [ulid] back in on a retry of an ambiguous prior call
  /// (timeout, lost ack) to get that already-committed entry back
  /// idempotently instead of writing a second document — see the class doc
  /// comment's "No computed field" section for why this repository needs no
  /// further retry protection beyond the exists-check itself. Omit [ulid]
  /// to have a fresh one minted.
  ///
  /// [createdAt] must be the SAME value across a retry of the same logical
  /// call — never re-derived from the current wall-clock time on retry, see
  /// the class doc comment's "`createdAt` is caller-supplied" section.
  ///
  /// [source] defaults to [CompletionSource.live] — see
  /// [PointsLedgerEntry]'s doc comment for what it is for.
  Future<PointsLedgerEntry> append({
    required String entryKind,
    required int delta,
    required DateTime createdAt,
    String? note,
    String? redemptionUlid,
    CompletionSource source = CompletionSource.live,
    String? ulid,
  }) async {
    final id = ulid ?? newUlid();
    final ref = _doc(id);

    final existingSnapshot = await ref.get();
    final existingData = existingSnapshot.data();
    if (existingData != null) {
      return pointsLedgerEntryFromFirestore(
        _normalizeForDecode(existingData),
        docId: existingSnapshot.id,
      );
    }

    final entry = PointsLedgerEntry(
      ulid: id,
      entryKind: entryKind,
      delta: delta,
      note: note,
      redemptionUlid: redemptionUlid,
      createdAt: createdAt,
      source: source,
    );
    await ref.set(entry.toFirestore()).orQueuedOffline;
    return entry;
  }

  /// Returns the WHOLE points-ledger history for this profile. Paginated
  /// internally (see the class doc comment's parent-file references for the
  /// 500-item pagination cap) so a long-lived profile's history costs
  /// multiple round trips rather than being silently truncated. [getTotals]
  /// is built directly on this.
  Future<List<PointsLedgerEntry>> getLedger() async {
    final docs = await _fetchAllPages(_ledger);
    return _decodeAll(docs);
  }

  /// The AD-50 filtered totals of this profile: the WHOLE paged ledger
  /// ([getLedger]) summed by `pointsTotals` against the engine's
  /// [earningEventIds] (`LearnerState.earningEventIds`).
  ///
  /// * A `pts_{eventId}` row counts only while its event earns; a voided,
  ///   ineligible or orphan event row counts nothing. No reversal rows
  ///   exist, so a void lowers both totals. A `pts_` row missing its
  ///   `event_id` is keyed by its doc id (`pointsLedgerEntryFromFirestore`),
  ///   so it too counts only while that event earns.
  /// * A non-event row (spend, refund, parent adjustment) always counts
  ///   toward the balance, and toward lifetime only when it is a positive
  ///   `completion`/`parent_add` row: spends and refunds never raise it.
  /// * Both totals are clamped to `[0, 1 << 30]` (owner decision 5); a
  ///   negative raw balance logs `firestore_points_ledger_negative_raw_sum`
  ///   before the clamp.
  ///
  /// Lifetime earned is the same filtered sum and is not monotonic (AD-50).
  Future<PointsTotals> getTotals({
    required Set<String> earningEventIds,
  }) async => _totalsOf(await getLedger(), earningEventIds);

  /// [getTotals] with the earning set resolved only when the ledger holds an
  /// event row: a ledger of spends and adjustments alone is summed without
  /// waiting for the learner state, which it does not depend on.
  Future<PointsTotals> resolveTotals(
    Future<Set<String>> Function() earningEventIds,
  ) async {
    final entries = await getLedger();
    final hasEventRows = entries.any((e) => e.eventId != null);
    return _totalsOf(
      entries,
      hasEventRows ? await earningEventIds() : const <String>{},
    );
  }

  PointsTotals _totalsOf(
    List<PointsLedgerEntry> entries,
    Set<String> earningEventIds,
  ) {
    final rows = [for (final e in entries) pointsLedgerRowOf(e)];
    final seen = <String>{};
    var rawSum = 0;
    for (final row in rows) {
      final eventId = row.eventId;
      if (!seen.add(row.id)) continue;
      if (eventId != null && !earningEventIds.contains(eventId)) continue;
      rawSum += row.amount;
    }
    if (rawSum < 0) {
      _logger.warning(
        event: 'firestore_points_ledger_negative_raw_sum',
        fields: {'profile_id': _profileId, 'raw_sum': rawSum},
      );
    }
    return pointsTotals(rows, earningEventIds);
  }

  /// Completes once every write this client has pending (queued in this
  /// session or persisted from an earlier one) has been acknowledged or
  /// rejected by the server, so a read after it no longer counts a local
  /// write the server may roll back. Never completes while offline; callers
  /// bound it. The achievement latch waits on it before judging totals
  /// (DNI-480).
  Future<void> waitForPendingWrites() => _firestore.waitForPendingWrites();

  /// The debitable balance of [getTotals]: what redemption affordability
  /// checks against.
  Future<int> getBalance({required Set<String> earningEventIds}) async =>
      (await getTotals(earningEventIds: earningEventIds)).balance;

  /// Live updates for one entry by [ulid], or `null` if it does not exist.
  /// Resubscribes with bounded exponential backoff on a stream-level error
  /// (`resilientDocStream`).
  Stream<PointsLedgerEntry?> watchEntry(String ulid) {
    return resilientDocStream<PointsLedgerEntry?>(
      openStream: () => _doc(ulid).snapshots(),
      decode: _decode,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_points_ledger_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'ulid': ulid},
      ),
    );
  }

  /// Live updates for the most recent [limit] ledger entries, most-recent-
  /// first — a bounded "recent activity" feed, NOT a way to page through the
  /// whole history live (use [getLedger] for that). [limit] is clamped to
  /// [_maxPageSize]. Resubscribes with bounded exponential backoff on a
  /// stream-level error (`resilientQueryStream`).
  Stream<List<PointsLedgerEntry>> watchRecentLedgerEntries({int limit = 100}) {
    final boundedLimit = limit > _maxPageSize ? _maxPageSize : limit;
    return resilientQueryStream<PointsLedgerEntry>(
      openStream: () => _ledger
          .orderBy(FieldPath.documentId, descending: true)
          .limit(boundedLimit)
          .snapshots(),
      decode: (doc) => pointsLedgerEntryFromFirestore(
        _normalizeForDecode(doc.data()),
        docId: doc.id,
      ),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_points_ledger_watch_recent_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'profile_id': _profileId},
      ),
    );
  }
}
