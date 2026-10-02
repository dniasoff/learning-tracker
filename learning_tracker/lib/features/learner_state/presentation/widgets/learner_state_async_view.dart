/// The one loading/error shell for surfaces that read the active learner's
/// [LearnerState] (DNI-474 AC-1): the existing [LoadingIndicator] while any
/// input is still paging, and [AppErrorView] (full screen) or
/// [InlineAsyncError] (a card or section) with a retry that re-reads every
/// failed dependency.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

/// Builds [builder] over the active learner's state, with the shared
/// loading and retryable error states around it.
///
/// [builder] receives null when no learner is active. [inline] picks the
/// compact [InlineAsyncError] (sections inside a scrolling screen) over the
/// full [AppErrorView].
class LearnerStateAsyncView extends ConsumerWidget {
  /// Creates the view.
  const LearnerStateAsyncView({
    required this.builder,
    this.inline = false,
    super.key,
  });

  /// Builds the content from a complete state.
  final Widget Function(BuildContext context, LearnerState? state) builder;

  /// Whether errors render inline instead of full-screen.
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LearnerAsyncValueView<LearnerState?>(
      value: ref.watch(activeLearnerStateProvider),
      inline: inline,
      builder: builder,
    );
  }
}

/// The same loading/error shell for a value derived from the learner state
/// (a projection provider): [onRetry] defaults to [retryLearnerState].
class LearnerAsyncValueView<T> extends ConsumerWidget {
  /// Creates the view.
  const LearnerAsyncValueView({
    required this.value,
    required this.builder,
    this.inline = false,
    this.onRetry,
    super.key,
  });

  /// The value to render.
  final AsyncValue<T> value;

  /// Builds the content from the data.
  final Widget Function(BuildContext context, T data) builder;

  /// Whether errors render inline instead of full-screen.
  final bool inline;

  /// Extra retry work; [retryLearnerState] always runs.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() {
      retryLearnerState(ref);
      onRetry?.call();
    }

    return value.when(
      data: (data) => builder(context, data),
      loading: () => const LoadingIndicator(),
      error: (error, stackTrace) => inline
          ? InlineAsyncError(error: error, onRetry: retry)
          : AppErrorView(error: error, stackTrace: stackTrace, onRetry: retry),
    );
  }
}
