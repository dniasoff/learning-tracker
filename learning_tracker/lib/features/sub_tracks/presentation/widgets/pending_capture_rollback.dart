/// The Learn tab's rollback and retry for this device's Up to… and +1
/// captures (Story 2.10, DNI-501; AD-54 Recovery, UX-DR-110).
///
/// Mounted once on the Learn tab, independent of the sub-track rows: the
/// main-track Up to… writes through the same overlay when the learner has
/// no sub-track at all. Every pending failure (a chunk the server rejected
/// for good, within the ack window or later) rolls back exactly its
/// leaves in `pendingCapturesProvider` and is announced once with Retry
/// ([PendingCaptureFailureListener]); a saved retry lets the engine show
/// them again. It keeps itself alive inside a lazy list, so scrolling the
/// Learn tab never unmounts it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';

/// Rolls back and announces failed Up to… / +1 captures while mounted.
class PendingCaptureRollback extends ConsumerStatefulWidget {
  /// Creates the listener around [child] (nothing by default).
  const PendingCaptureRollback({
    super.key,
    this.child = const SizedBox.shrink(),
  });

  /// What it wraps.
  final Widget child;

  @override
  ConsumerState<PendingCaptureRollback> createState() =>
      _PendingCaptureRollbackState();
}

class _PendingCaptureRollbackState extends ConsumerState<PendingCaptureRollback>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PendingCaptureFailureListener(
      onFailure: (failure) =>
          ref.read(pendingCapturesProvider.notifier).rollBack(failure.eventIds),
      onRetried: (failure) =>
          ref.read(pendingCapturesProvider.notifier).retried(failure.eventIds),
      child: widget.child,
    );
  }
}
