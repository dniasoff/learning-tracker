/// Firestore implementation for the streak event log — the second of the
/// two APPEND-ONLY repositories in the Firestore rewrite
/// (`docs/firestore-rewrite-map.md`; the other is
/// `firestore_learning_ledger_repository.dart`, which shares most of this
/// file's reasoning — its class doc comment is the fuller read for the
/// 500-item pagination cap, the `.count()` non-use, and the retry-safety
/// pattern). This file's own doc comment covers only what is genuinely
/// different for `streak_events`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_entry.dart';

/// Firestore-backed streak-event-log repository: `users/{uid}/
/// learner_profiles/{profileId}/streak_events/{ulid}` — append-only,
/// doc-id is the event's own ULID (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /streak_events/{streakEventId}`).
///
/// **Not wired into the app's production provider yet** — but
/// `FirestoreStreakStateRepository`
/// (`lib/features/gamification/data/repositories/firestore_streak_state_repository.dart`)
/// exists and does read this class. That repository itself is not
/// constructed by any real provider (it appears nowhere in `lib/` outside
/// its own definition), so no screen reaches this repository through it
/// yet; the existing Drift-backed `StreakEventLog`
/// (`lib/features/gamification/streak/streak_event_log.dart`, which wraps
/// the `StreakEvents` Drift table) is untouched.
///
/// **No interface, no `implements`** — same reasoning as
/// `FirestoreBookmarkRepository`'s doc comment.
///
/// ## Why this collection exists
///
/// "Each device appends events; state is derived by replaying the log."
/// (`StreakEventLog`'s own doc comment — still true here.) This repository
/// is the log itself: [append] is its only mutation, and current streak
/// state is meant to be derived by a caller replaying [getAllEvents] /
/// [watchRecentEvents], never stored as a counter here (same "derived, not
/// stored" invariant `firestore_learning_ledger_repository.dart` documents
/// for `completionNumber`).
///
/// ## What's different from `LearningLedgerEntry`/the Drift `StreakEvents`
///
/// ### Natural-key dedup is no longer automatic — a real behavior change
///
/// The Drift `StreakEvents` table declares `UNIQUE (profileId, dayUtc,
/// eventType)`, and `StreakEventLog.append` inserts with
/// `InsertMode.insertOrIgnore`, so two calls for the same logical day-event
/// silently collapse to one row. `DocIds.streakEventDocId` — the pinned,
/// golden-tested doc-id formula this repository must use as-is (not
/// redesign) — keys this collection by [StreakEventEntry.ulid] alone, not
/// by `(dayUtc, eventType)`. A Firestore doc-id therefore only makes a
/// RETRY of the *same* [append] call idempotent (the caller reuses the same
/// `ulid`); it does **not** collapse two independently-triggered calls for
/// the same day the way the Drift UNIQUE index did. [getEventsForDay]
/// exists specifically so a caller that needs "have I already logged an
/// event for this day/type?" semantics can check first — see
/// [StreakEventEntry]'s own doc comment for the fuller version of this.
///
/// ### No `completionNumber`-equivalent, so no `.count()`-avoidance dance
///
/// Nothing here derives a numbered field from existing rows, so [append]
/// has none of `recordCompletion`'s "check-exists-before-computing" logic
/// beyond the exists-check itself (still needed — see [append]'s doc
/// comment — but with nothing to get wrong on a retry beyond the write
/// itself).
///
/// ### No `Timestamp`-vs-`String` trap here
///
/// `firestore.rules`' `streak_events` SR-3 guard is on `created_at`, and
/// only when that key is present at all (`!('created_at' in
/// request.resource.data) || (... is timestamp ...)`).
/// [StreakEventEntryFirestoreCodec.toFirestore] never writes a
/// `created_at` key (see [StreakEventEntry]'s doc comment for why — it
/// would be redundant with the ULID's own embedded creation instant), so
/// that guard's "field absent" branch always applies and the fields this
/// repository DOES write (`day_utc`, `event_timestamp`) are not rules-type-
/// checked at all — plain `FirestoreCodec.encodeDateTime` `String`s are
/// safe here, unlike `learning_ledger`'s `completed_at`
/// (`firestore_learning_ledger_repository.dart`'s class doc comment covers
/// that trap in full; it does not apply to this file).
///
/// ## Trimmed from the Drift-era `StreakEventLog` — not reimplemented
///
/// `StreakEventLog` is not `implements`ed (it is a concrete class, not an
/// interface, so there was nothing to implement regardless) and its
/// `int profileId`-carrying `StreakLogEvent` input type is not reused —
/// see [StreakEventEntry]'s doc comment for why a distinct, Firestore-
/// shaped type exists instead.
class FirestoreStreakEventRepository {
  FirestoreStreakEventRepository({
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

  /// `firestore.rules`' SR-4 `list()` cap for this collection
  /// (`request.query.limit <= 500`) — every query this repository issues
  /// stays at or under this. See
  /// `firestore_learning_ledger_repository.dart`'s class doc comment for
  /// why pagination (not `.count()`) is how [getAllEvents] stays correct
  /// past this cap.
  static const _maxPageSize = 500;

  CollectionReference<Map<String, dynamic>> get _events => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('streak_events');

  /// [ulid] is always supplied non-null by every call site below, so
  /// [DocIds.streakEventDocId]'s nullable-payload fallback (`data['ulid']
  /// as String?` being absent) is never reached here. Same explicit-local
  /// reasoning as `FirestoreLearningLedgerRepository._doc` — see that
  /// method's doc comment.
  DocumentReference<Map<String, dynamic>> _doc(String ulid) {
    final docId = DocIds.streakEventDocId({'ulid': ulid})!;
    return _events.doc(docId);
  }

  StreakEventEntry? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return streakEventEntryFromFirestore(data);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the whole read (mirrors
  /// `FirestoreLearningLedgerRepository._decodeAll`).
  List<StreakEventEntry> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <StreakEventEntry>[];
    for (final doc in docs) {
      try {
        results.add(streakEventEntryFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_streak_events_decode_error',
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
  /// shape to
  /// `FirestoreLearningLedgerRepository._fetchAllPages`, including paging
  /// via `startAfterDocument` rather than `startAfter([lastDocId])` (see
  /// that method's doc comment for exactly why — a `fake_cloud_firestore`
  /// 4.1.1 `FieldPath.documentId` handling gap, not duplicated here).
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

  /// Appends one streak event. [eventType] is `'completion'` |
  /// `'day_boundary'` | `'manual_adjust'`; `dayUtc` is derived from
  /// [eventTimestamp] (UTC-midnight-normalised), mirroring
  /// `StreakEventLog.append`'s own derivation exactly — a pure function of
  /// [eventTimestamp], so it stays stable across a retry as long as the
  /// caller passes the same [eventTimestamp] back (never re-derived from
  /// the current wall-clock time).
  ///
  /// Pass the same [ulid] back in on a retry of an ambiguous prior call
  /// (timeout, lost ack) to get that already-committed entry back
  /// idempotently instead of writing a second document — see the class doc
  /// comment's "Natural-key dedup is no longer automatic" section for what
  /// this does and does NOT protect against (a genuinely new call for the
  /// same day/type is a distinct document, unlike the Drift UNIQUE index).
  /// Omit [ulid] to have a fresh one minted.
  Future<StreakEventEntry> append({
    required String eventType,
    required DateTime eventTimestamp,
    String? clientDeviceId,
    String? ulid,
  }) async {
    final id = ulid ?? newUlid();
    final ref = _doc(id);

    final existingSnapshot = await ref.get();
    final existingData = existingSnapshot.data();
    if (existingData != null) {
      return streakEventEntryFromFirestore(existingData);
    }

    final ts = eventTimestamp.toUtc();
    final dayUtc = DateTime.utc(ts.year, ts.month, ts.day);

    final entry = StreakEventEntry(
      ulid: id,
      eventType: eventType,
      dayUtc: dayUtc,
      eventTimestamp: ts,
      clientDeviceId: clientDeviceId,
    );
    await ref.set(entry.toFirestore()).orQueuedOffline;
    return entry;
  }

  /// Returns every event for UTC-midnight-normalised [dayUtc] (any
  /// component beyond year/month/day is ignored — normalised internally the
  /// same way [append] normalises [eventTimestamp]). Equality-only filter —
  /// no composite index required. NOT paginated past [_maxPageSize]: unlike
  /// [getAllEvents], more than 500 events landing on a single UTC day for
  /// one profile is not a realistic scenario for this domain (a handful of
  /// `completion`/`day_boundary`/`manual_adjust` events per day at most) —
  /// flagged as a deliberate assumption, not silently guessed at.
  Future<List<StreakEventEntry>> getEventsForDay(DateTime dayUtc) async {
    final ts = dayUtc.toUtc();
    final normalized = DateTime.utc(ts.year, ts.month, ts.day);
    final snapshot = await _events
        .where('day_utc', isEqualTo: FirestoreCodec.encodeDateTime(normalized))
        .limit(_maxPageSize)
        .get();
    return _decodeAll(snapshot.docs);
  }

  /// Returns the WHOLE event log for this profile — the record state is
  /// meant to be derived from (see the class doc comment). Paginated
  /// internally so a long-lived streak history costs multiple round trips
  /// rather than being silently truncated at the SR-4 cap.
  Future<List<StreakEventEntry>> getAllEvents() async {
    final docs = await _fetchAllPages(_events);
    return _decodeAll(docs);
  }

  /// Live updates for one event by [ulid], or `null` if it does not exist.
  /// Resubscribes with bounded exponential backoff on a stream-level error
  /// (`resilientDocStream`).
  Stream<StreakEventEntry?> watchEvent(String ulid) {
    return resilientDocStream<StreakEventEntry?>(
      openStream: () => _doc(ulid).snapshots(),
      decode: _decode,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_streak_events_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'ulid': ulid},
      ),
    );
  }

  /// Live updates for the most recent [limit] events, most-recent-first — a
  /// bounded "recent activity" feed, NOT a way to page through the whole
  /// log live (see [getAllEvents] for that). [limit] is clamped to
  /// [_maxPageSize]. Resubscribes with bounded exponential backoff on a
  /// stream-level error (`resilientQueryStream`).
  Stream<List<StreakEventEntry>> watchRecentEvents({int limit = 100}) {
    final boundedLimit = limit > _maxPageSize ? _maxPageSize : limit;
    return resilientQueryStream<StreakEventEntry>(
      openStream: () => _events
          .orderBy(FieldPath.documentId, descending: true)
          .limit(boundedLimit)
          .snapshots(),
      decode: (doc) => streakEventEntryFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_streak_events_watch_recent_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'profile_id': _profileId},
      ),
    );
  }
}
