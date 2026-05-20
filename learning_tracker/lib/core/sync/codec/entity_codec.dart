/// Abstract base for per-entity Firestore ↔ Dart codecs.
///
/// Each concrete codec encodes/decodes a single Firestore collection shape
/// into a normalised [Map<String, dynamic>] that downstream DAOs (via
/// [DriftMergeStore]) can consume without knowing about Firestore types.
///
/// ## Responsibilities
/// - Field extraction from raw Firestore payloads.
/// - `DateTime ↔ Timestamp` conversion via [FirestoreCodec].
/// - Validation (required fields present, correct types).
///
/// ## Non-responsibilities
/// - SQLite writes — those belong to [DriftMergeStore] / DAOs.
/// - LWW comparisons — those belong to [EntityMerger] subclasses.
/// - Push encoding — that is [SyncWriteFacade] territory.
///
/// ## Usage pattern
/// ```dart
/// class MyCodec extends EntityCodec<MyModel> {
///   @override
///   String get kind => EntityKind.myEntity;
///
///   @override
///   MyModel? decode(Map<String, dynamic> raw) {
///     final id = raw['id'] as String?;
///     if (id == null) return null; // required field missing
///     return MyModel(id: id, updatedAt: FirestoreCodec.parseDateTime(raw['updated_at']));
///   }
///
///   @override
///   Map<String, dynamic> encode(MyModel model) => {
///     'id': model.id,
///     'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
///   };
/// }
/// ```
library;

/// Zero-dependency abstract codec for a single Firestore entity type.
///
/// Type parameter [T] is the domain model produced by [decode].
abstract class EntityCodec<T> {
  const EntityCodec();

  /// The [EntityKind] constant this codec handles.
  String get kind;

  /// Decode a raw Firestore row into a domain model.
  ///
  /// Returns `null` when required fields are missing or malformed — the
  /// merger must skip malformed rows rather than crash.
  T? decode(Map<String, dynamic> raw);

  /// Encode a domain model into the Firestore wire format.
  ///
  /// The returned map must only contain JSON-safe values
  /// (String, num, bool, null, List, Map). Timestamps should be encoded
  /// via [FirestoreCodec.encodeDateTime].
  Map<String, dynamic> encode(T model);
}
