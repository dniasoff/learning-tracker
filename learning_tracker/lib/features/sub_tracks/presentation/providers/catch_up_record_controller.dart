/// *Yes, all of it* on a catch-up card (Story 3.3, DNI-506 T6; screen #10,
/// UX-DR-37, UX-DR-133, UX-DR-154).
///
/// One tap expands the card ([buildCatchUpAllAction]) and records it
/// through `LearningCommands.recordCatchUp`, which owns every rule (window,
/// events, points, chunking, compensation, analytics). This file is the
/// card's state around that call:
///
/// * **Recording**: the card's actions are disabled until the command
///   returns, so a double tap never writes twice.
/// * **Success** (saved or queued offline, AC-5): the card disappears on
///   its own — the events reach the live learner state at once and the
///   card is complete (A-5). A snackbar offers Undo for exactly the
///   action's events (AC-7); after Undo the card returns while its window
///   is open, because completion is derived from counted events.
/// * **Ended** (AC-3): "This catch-up has ended — you can still tick
///   learning in Browse." and the card's windows are re-read, so it
///   disappears. Nothing was written.
/// * **Not saved** (AC-8): the card stays with "Couldn't save — try again
///   before the card expires."; the command already voided any saved part.
///
/// No copy here mentions a streak or being behind (NFR-18, FR-18).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/catch_up_cards_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/capture_feedback.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/catch_up_action_builder.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Where a card's record action stands.
enum CatchUpRecordPhase {
  /// The command is running; the card's actions are disabled.
  recording,

  /// The last attempt was not saved; the card offers it again.
  failed,
}

/// The record phase of each card, by `CatchUpCardWindow.key`; a card with
/// no entry is idle.
final catchUpRecordStatusProvider =
    NotifierProvider<CatchUpRecordStatus, Map<String, CatchUpRecordPhase>>(
      CatchUpRecordStatus.new,
    );

/// See [catchUpRecordStatusProvider].
class CatchUpRecordStatus extends Notifier<Map<String, CatchUpRecordPhase>> {
  @override
  Map<String, CatchUpRecordPhase> build() => const {};

  /// Sets card [key] to [phase]; null makes it idle.
  void set(String key, CatchUpRecordPhase? phase) {
    final next = {...state};
    if (phase == null) {
      next.remove(key);
    } else {
      next[key] = phase;
    }
    state = next;
  }
}

/// Records every leaf [card] lists (*Yes, all of it*) and shows the
/// outcome. [context] is the card's; the snackbars go to the messenger
/// above it, which outlives the card.
Future<void> recordCatchUpAll(
  BuildContext context,
  Ref ref,
  CatchUpTaskCard card,
) async {
  final key = card.window.key;
  final status = ref.read(catchUpRecordStatusProvider.notifier);
  if (ref.read(catchUpRecordStatusProvider)[key] ==
      CatchUpRecordPhase.recording) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  status.set(key, CatchUpRecordPhase.recording);
  final CaptureResult result;
  final LearningCommands? commands;
  try {
    commands = await ref.read(learningCommandsProvider.future);
    if (commands == null) {
      status.set(key, CatchUpRecordPhase.failed);
      return;
    }
    result = await commands.recordCatchUp(
      buildCatchUpAllAction(
        card,
        refOf: (task) => task.contentItemSefariaRef,
        stageOf: (task) => task.stageOrder,
      ),
    );
  } on Exception {
    status.set(key, CatchUpRecordPhase.failed);
    return;
  }
  switch (result) {
    case CaptureSuccess(:final eventIds):
      status.set(key, null);
      if (messenger == null || !messenger.mounted) return;
      final l10n = AppLocalizations.of(messenger.context)!;
      showCaptureOutcome(
        messenger.context,
        result: result,
        commands: commands,
        messenger: messenger,
        message: l10n.captureRecordedCount(eventIds.length),
      );
    case CaptureRejected(reason: CaptureRejection.catchUpEnded):
      status.set(key, null);
      ref.invalidate(catchUpCardWindowsProvider);
      if (messenger == null || !messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(messenger.context)!.catchUpEnded),
        ),
      );
    case CaptureLocked():
      // The lock overlay covers the app; the card pauses with its window.
      status.set(key, null);
    case CaptureRejected() || CaptureChildLimit() || CaptureOnlineRequired():
      status.set(key, CatchUpRecordPhase.failed);
  }
}

/// The *Yes, all of it* handler the catch-up card plugs in
/// (`catchUpCardActionsProvider`, DNI-505).
void Function(BuildContext context, CatchUpTaskCard card) catchUpRecordAllOf(
  Ref ref,
) =>
    (context, card) => unawaited(recordCatchUpAll(context, ref, card));
