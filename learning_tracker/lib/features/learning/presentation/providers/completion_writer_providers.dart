import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_writer_providers.g.dart';

/// Riverpod entry point for [CompletionWriter] — the single authoritative
/// completion-write path (FR15).
@riverpod
CompletionWriter completionWriter(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  return CompletionWriter(db, analytics: analytics);
}

/// Monotonically-increasing counter that increments once per successfully
/// committed completion (Story 26.13 — DNI-356).
///
/// Providers that depend on completion data watch this counter so they
/// automatically rebuild when a new completion is recorded, without
/// requiring manual [Ref.invalidate] calls at call sites.
///
/// Call sites increment via:
/// ```dart
/// ref.read(completionCommittedProvider.notifier).increment();
/// ```
@Riverpod(keepAlive: true)
class CompletionCommitted extends _$CompletionCommitted {
  @override
  int build() => 0;

  /// Increment the counter to signal a new completion was committed.
  void increment() => state = state + 1;
}
