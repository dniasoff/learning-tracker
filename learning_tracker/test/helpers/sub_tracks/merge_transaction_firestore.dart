/// A [FakeFirebaseFirestore] whose transactions keep the real `set`
/// merge semantics (the fake's own transaction drops `SetOptions`), record
/// every transaction op, and can simulate a concurrent server write or a
/// transaction failure (Story 2.7 / DNI-498).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Applies transaction writes with their real merge semantics and records
/// them in [ops].
final class RecordingMergeTransaction implements Transaction {
  /// Creates a transaction recording into [ops].
  RecordingMergeTransaction(this.ops);

  /// `get <path>` / `set <path> merge=<bool>`, in order.
  final List<String> ops;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> document,
  ) {
    ops.add('get ${document.path}');
    return document.get();
  }

  @override
  Transaction set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    ops.add('set ${document.path} merge=${options?.merge ?? false}');
    document.set(data, options);
    return this;
  }

  @override
  Transaction update(DocumentReference document, Map<Object, Object?> data) =>
      throw UnsupportedError('update');

  @override
  Transaction delete(DocumentReference document) =>
      throw UnsupportedError('delete');
}

/// A fake Firestore whose `runTransaction` runs the handler once over a
/// [RecordingMergeTransaction].
final class MergeTransactionFirestore extends FakeFirebaseFirestore {
  /// Every transaction op, in order.
  final List<String> ops = [];

  /// A transaction failure to throw instead of running the handler.
  FirebaseException? failWith;

  /// Runs before each handler attempt (a concurrent server write).
  Future<void> Function()? beforeAttempt;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    await beforeAttempt?.call();
    return transactionHandler(RecordingMergeTransaction(ops));
  }
}
