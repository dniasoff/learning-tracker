import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'optimistic_completion_provider.g.dart';

/// Generates a unique key for an optimistic completion entry.
String optimisticKey({
  required String sefariaRef,
  required int stageId,
  required String trackType,
}) => '$sefariaRef|$stageId|$trackType';

/// Holds a set of completion keys that have been optimistically marked as
/// complete but not yet persisted to the database.
///
/// This enables sub-100ms perceived response when tapping "Mark Complete":
/// the UI reads from this set first, then falls back to the DB query.
@Riverpod(keepAlive: true)
class OptimisticCompletionState extends _$OptimisticCompletionState {
  @override
  Set<String> build() => {};

  /// Mark a completion as optimistically complete (before DB write).
  void add(String key) {
    state = {...state, key};
  }

  /// Remove a key on DB write failure (rollback).
  void remove(String key) {
    state = {...state}..remove(key);
  }
}
