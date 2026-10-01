/// AD-52 `NodeEntry{level, ref}` — one entry of a sub-track's `ground`.
library;

import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// A ContentIndex node at any level, e.g. `{level: masechta, ref: Berakhot}`.
///
/// `level` is the ContentIndex level string and `ref` the sefariaRef; both
/// are opaque, non-empty strings to this codec — resolving them against
/// ContentIndex is the engine's job (`expandGround`, AD-34).
final class NodeEntry {
  /// Creates a node entry.
  const NodeEntry({required this.level, required this.ref});

  /// Strict decode: exactly `level` and `ref`.
  factory NodeEntry.fromStorage(Map<String, Object?> map) {
    final r = StorageReader(_type, map)..requireOnly(storageKeys);
    return NodeEntry(
      level: r.requiredString(kLevel),
      ref: r.requiredString(kRef),
    );
  }

  static const _type = 'NodeEntry';

  /// Storage key `level`.
  static const kLevel = 'level';

  /// Storage key `ref`.
  static const kRef = 'ref';

  /// The AD-52 key set.
  static const Set<String> storageKeys = {kLevel, kRef};

  /// ContentIndex level.
  final String level;

  /// sefariaRef of the node.
  final String ref;

  /// Encodes exactly [storageKeys].
  Map<String, Object?> toStorage() {
    if (level.isEmpty) {
      throw const StorageFormatException(_type, kLevel, 'empty');
    }
    if (ref.isEmpty) throw const StorageFormatException(_type, kRef, 'empty');
    return {kLevel: level, kRef: ref};
  }

  @override
  bool operator ==(Object other) =>
      other is NodeEntry && other.level == level && other.ref == ref;

  @override
  int get hashCode => Object.hash(level, ref);

  @override
  String toString() => 'NodeEntry($level, $ref)';
}
