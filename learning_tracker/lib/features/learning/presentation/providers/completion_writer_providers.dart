import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_writer_providers.g.dart';

// NOTE: this file no longer provides a completion WRITER. `CompletionWriter`
// was Drift-bound and had zero production consumers — the live write path is
// `FirestoreCompletionRepositoryAdapter.markComplete`
// (`features/learning/data/repositories/completion_repository_impl.dart`).
// The file keeps its name only because 43 call sites import
// `completionCommittedProvider` from this path.

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
///
/// keepAlive: true — must survive across screens so completion-dependent
/// providers can detect a commit that happened while they were unmounted.
/// autoDispose would reset the counter to 0 the moment no watcher is
/// active, silently dropping that signal for the next screen that starts
/// watching.
@Riverpod(keepAlive: true)
class CompletionCommitted extends _$CompletionCommitted {
  @override
  int build() => 0;

  /// Increment the counter to signal a new completion was committed.
  void increment() => state = state + 1;
}
