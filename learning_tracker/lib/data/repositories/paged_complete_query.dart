/// Live, complete, document-id-paged read of one Firestore collection
/// (AD-35 "Complete inputs", AD-46 / SR-4 "≤ 500 per query", AD-9 resilient
/// listeners).
///
/// ## Shape
///
/// The collection is split into a chain of live page listeners, each
/// `orderBy(FieldPath.documentId).startAfterDocument(prev.last).limit(500)`
/// and each wrapped in [resilientQueryStream] so a dead listener
/// resubscribes with backoff. Ordering by document id needs no composite
/// index (AD-54 "Indexes: none added").
///
/// The chain invariant: page `i + 1` always starts right after page `i`'s
/// end cursor (its last document, or its own start cursor when it is
/// empty), so the pages together cover the collection without gaps.
///
/// - A FULL page makes sure its successor exists at that cursor (opening
///   or re-cursoring it), so the chain grows until a page comes back short.
/// - A SHORT page that already has a successor — an established page that
///   shrank, e.g. a delete before its limit window refilled — is NOT taken
///   as end-of-collection: its successor is re-cursored to the new end
///   cursor (or kept, when the cursor did not move) and the chain is
///   rebuilt from there, so rows on later pages are never dropped.
/// - An EMPTY page closes every later page: nothing exists after its
///   cursor, and any later page could only repeat that same query.
///
/// ## Publication
///
/// The returned stream emits [CompleteReadLoading] once, on listen, and
/// then a [CompleteReadReady] only when EVERY page in the chain has
/// delivered and the last one is short (the union of consistent pages is
/// then the whole collection, whatever the earlier pages' sizes). While a later change re-pages the
/// chain (a page's last document shifts, so every later page reopens with
/// the new cursor), nothing is published: the previous complete list stays
/// current until the new assembly is complete again. Identical assemblies
/// are not re-published.
///
/// A collection whose size is an exact multiple of the page size needs one
/// extra (empty) query to prove exhaustion — that probe is never published
/// as data on its own.
///
/// ## Failures
///
/// - A page listener's stream-level error (permission-denied, unavailable)
///   is forwarded to the returned stream as an error event, and that page
///   resubscribes via [resilientQueryStream]. The next complete assembly is
///   then always re-published, so a consumer that went to an error state
///   recovers.
/// - A document that fails [decode] is NOT dropped silently: it is reported
///   in [CompleteReadReady.rejected] alongside the valid rows.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';

/// The SR-4 per-query list cap.
const int kMaxListPageSize = 500;

/// Observes each page query as it is opened and as it delivers — a test
/// seam for asserting page counts and cursors. [afterDocId] is null for
/// the first page; [delivered] is null when the page is opened.
typedef PageProbe =
    void Function({
      required int pageIndex,
      required String? afterDocId,
      required int limit,
      required int? delivered,
    });

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Watches [collection] completely. [decode] receives the document id and
/// its data with every Firestore timestamp already converted to a UTC
/// `DateTime` (see `learner_state_firestore_values.dart`).
Stream<CompleteRead<T>> watchCompletePaged<T>({
  required Query<Map<String, dynamic>> collection,
  required T Function(String id, Map<String, Object?> data) decode,
  int pageSize = kMaxListPageSize,
  Duration backoffBase = const Duration(seconds: 1),
  Duration backoffCap = const Duration(seconds: 30),
  math.Random? random,
  void Function(Object error, StackTrace stackTrace)? onError,
  PageProbe? probe,
}) {
  if (pageSize < 1 || pageSize > kMaxListPageSize) {
    throw ArgumentError.value(pageSize, 'pageSize', 'must be 1..500');
  }
  late _PagedAssembler<T> assembler;
  // Never closed, like `_resilientStream`'s controller: it models a "live
  // while listened to" stream; teardown is the page listeners, which
  // `onCancel` cancels.
  // ignore: close_sinks
  late final StreamController<CompleteRead<T>> controller;
  controller = StreamController<CompleteRead<T>>(
    onListen: () {
      controller.add(CompleteReadLoading<T>());
      assembler = _PagedAssembler<T>(
        collection: collection,
        decode: decode,
        pageSize: pageSize,
        backoffBase: backoffBase,
        backoffCap: backoffCap,
        random: random,
        onError: onError,
        probe: probe,
        emit: controller.add,
        emitError: controller.addError,
      )..start();
    },
    onCancel: () => assembler.dispose(),
  );
  return controller.stream;
}

final class _Page {
  _Page(this.index, this.after);

  final int index;
  final _Doc? after;
  List<_Doc>? docs;

  /// Cancelled by `_PagedAssembler._truncateAfter` (page closed or
  /// re-cursored) and on dispose.
  // ignore: cancel_subscriptions
  StreamSubscription<List<_Doc>>? subscription;
}

final class _PagedAssembler<T> {
  _PagedAssembler({
    required this.collection,
    required this.decode,
    required this.pageSize,
    required this.backoffBase,
    required this.backoffCap,
    required this.random,
    required this.onError,
    required this.probe,
    required this.emit,
    required this.emitError,
  });

  final Query<Map<String, dynamic>> collection;
  final T Function(String id, Map<String, Object?> data) decode;
  final int pageSize;
  final Duration backoffBase;
  final Duration backoffCap;
  final math.Random? random;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final PageProbe? probe;
  final void Function(CompleteRead<T>) emit;
  final void Function(Object error, StackTrace stackTrace) emitError;

  final List<_Page> _pages = [];
  CompleteReadReady<T>? _lastPublished;
  bool _disposed = false;

  void start() => _open(0, null);

  void dispose() {
    _disposed = true;
    _truncateAfter(-1);
  }

  void _open(int index, _Doc? after) {
    final page = _Page(index, after);
    _pages.add(page);
    probe?.call(
      pageIndex: index,
      afterDocId: after?.id,
      limit: pageSize,
      delivered: null,
    );
    page.subscription =
        resilientQueryStream<_Doc>(
          openStream: () {
            var query = collection.orderBy(FieldPath.documentId);
            // startAfterDocument BEFORE limit — see
            // FirestoreLearningLedgerRepository._fetchAllPages for why the
            // order matters to the test fake (real Firestore is
            // order-independent).
            if (after != null) query = query.startAfterDocument(after);
            return query.limit(pageSize).snapshots();
          },
          decode: (doc) => doc,
          backoffBase: backoffBase,
          backoffCap: backoffCap,
          random: random,
          onError: onError,
        ).listen(
          (docs) => _onPage(page, docs),
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) return;
            // Force the next complete assembly to be re-published so a
            // consumer that surfaced this error recovers.
            _lastPublished = null;
            emitError(error, stackTrace);
          },
        );
  }

  void _truncateAfter(int index) {
    while (_pages.length > index + 1) {
      final removed = _pages.removeLast();
      unawaited(removed.subscription?.cancel());
    }
  }

  void _onPage(_Page page, List<_Doc> docs) {
    if (_disposed || !_pages.contains(page)) return;
    page.docs = docs;
    probe?.call(
      pageIndex: page.index,
      afterDocId: page.after?.id,
      limit: pageSize,
      delivered: docs.length,
    );
    final next = page.index + 1 < _pages.length ? _pages[page.index + 1] : null;
    if (docs.isEmpty) {
      // Nothing after this page's cursor: a successor could only re-run
      // the same (empty) query.
      _truncateAfter(page.index);
    } else if (docs.length >= pageSize || next != null) {
      // A full page needs a successor; a short page that HAD one keeps the
      // chain alive from its new end cursor rather than declaring the
      // collection exhausted (an earlier page shrinking must never drop the
      // rows that later pages hold).
      final cursor = docs.last;
      if (next == null || next.after?.id != cursor.id) {
        _truncateAfter(page.index);
        _open(page.index + 1, cursor);
      }
    }
    _tryPublish();
  }

  void _tryPublish() {
    if (_pages.isEmpty) return;
    for (final page in _pages) {
      if (page.docs == null) return;
    }
    if (_pages.last.docs!.length >= pageSize) return;

    final seen = <String>{};
    final items = <T>[];
    final rejected = <RejectedRow>[];
    for (final page in _pages) {
      for (final doc in page.docs!) {
        if (!seen.add(doc.id)) continue;
        try {
          items.add(decode(doc.id, fromFirestoreMap(doc.data())));
        } catch (error) {
          rejected.add(RejectedRow(doc.id, error));
        }
      }
    }
    final ready = CompleteReadReady<T>(items, rejected: rejected);
    if (ready == _lastPublished) return;
    _lastPublished = ready;
    emit(ready);
  }
}
