/// Domain-owned load state for a complete paged read (AD-35 "Complete
/// inputs").
///
/// A repository emits [CompleteReadLoading] until EVERY page of the
/// collection has arrived, then [CompleteReadReady] with the full list. It
/// never emits a partial list: while a later live change re-pages the
/// collection, the last complete list stays current and the next
/// [CompleteReadReady] is published only once the new assembly is complete
/// again.
library;

/// The state of a complete read of `T` rows.
sealed class CompleteRead<T> {
  const CompleteRead();
}

/// Not every page has arrived yet. Consumers must not run the engine.
final class CompleteReadLoading<T> extends CompleteRead<T> {
  /// Creates the loading state.
  const CompleteReadLoading();

  @override
  bool operator ==(Object other) => other is CompleteReadLoading<T>;

  @override
  int get hashCode => (CompleteReadLoading<T>).hashCode;

  @override
  String toString() => 'CompleteReadLoading<$T>()';
}

/// A document that was read but failed strict decode.
final class RejectedRow {
  /// Creates a rejected-row record.
  const RejectedRow(this.docId, this.error);

  /// The document id.
  final String docId;

  /// The decode failure (typically a `StorageFormatException`).
  final Object error;

  @override
  bool operator ==(Object other) =>
      other is RejectedRow && other.docId == docId;

  @override
  int get hashCode => docId.hashCode;

  @override
  String toString() => 'RejectedRow($docId)';
}

/// Every page arrived. [items] holds every valid row in document-id order.
///
/// [rejected] lists rows that were read but failed strict decode. They are
/// never silently converted into data and never silently dropped: a
/// non-empty [rejected] means the log is complete but contains rows the
/// app cannot interpret, and the consumer must surface that.
final class CompleteReadReady<T> extends CompleteRead<T> {
  /// Creates the complete state.
  CompleteReadReady(List<T> items, {List<RejectedRow> rejected = const []})
    : items = List.unmodifiable(items),
      rejected = List.unmodifiable(rejected);

  /// All valid rows.
  final List<T> items;

  /// Rows that failed decode.
  final List<RejectedRow> rejected;

  /// Whether every row decoded.
  bool get isClean => rejected.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is CompleteReadReady<T> &&
      _listEquals(other.items, items) &&
      _listEquals(other.rejected, rejected);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), Object.hashAll(rejected));

  @override
  String toString() =>
      'CompleteReadReady<$T>(${items.length} items, ${rejected.length} rejected)';
}

bool _listEquals<E>(List<E> a, List<E> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
