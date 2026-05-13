import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
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
