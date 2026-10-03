/// The Learn tab's "kept, not counted" notice (Story 3.1, DNI-504 AC-9;
/// UX-DR-107, prd-deviations #2).
///
/// An owner device whose clock or offline queue produced a learning event
/// whose effective instant falls inside a lock has it stored, not
/// rejected; the engine ignores it in every derived number
/// (`LearnerState.lockIgnoredEventIds`, AD-36), history labels it, and
/// `LearningCommands` refuses to undo it. When the active learner's state
/// first shows lock-ignored events this device has not announced yet, the
/// Learn tab says so once: "Some learning was kept, not counted — it was
/// recorded during Shabbos." The announced ids are remembered per learner
/// on this device ([LockIgnoredNoticeStore]).
///
/// It keeps itself alive inside the Learn tab's lazy list, like
/// `PendingCaptureRollback`, so scrolling never unmounts it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/data/repositories/lock_ignored_notice_store.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Announces newly lock-ignored learning once while mounted.
class LockIgnoredNotice extends ConsumerStatefulWidget {
  /// Creates the notice around [child] (nothing by default).
  const LockIgnoredNotice({super.key, this.child = const SizedBox.shrink()});

  /// What it wraps.
  final Widget child;

  @override
  ConsumerState<LockIgnoredNotice> createState() => _LockIgnoredNoticeState();
}

class _LockIgnoredNoticeState extends ConsumerState<LockIgnoredNotice>
    with AutomaticKeepAliveClientMixin {
  /// Checks run one at a time, so one event is never announced twice.
  Future<void> _checks = Future.value();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<LearnerState?>>(activeLearnerStateProvider, (
      _,
      next,
    ) {
      final state = next.asData?.value;
      if (state == null || state.lockIgnoredEventIds.isEmpty) return;
      final ids = state.lockIgnoredEventIds;
      _checks = _checks.then((_) => _check(ids));
    }, fireImmediately: true);
  }

  Future<void> _check(Set<String> ids) async {
    if (!mounted) return;
    final scope = ref.read(activeLearnerScopeProvider).asData?.value;
    if (scope == null) return;
    final store = ref.read(lockIgnoredNoticeStoreProvider);
    final announced = await store.announced(scope);
    if (announced.containsAll(ids)) return;
    await store.setAnnounced(scope, ids);
    if (!mounted) return;
    // The learner may have switched while the store answered.
    if (ref.read(activeLearnerScopeProvider).asData?.value != scope) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.erevLockIgnoredSnackbar)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
