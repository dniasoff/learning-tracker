/// Port for governed actions too large for one client batch (AD-54): the
/// `ownerOversizedGovernedWrite` callable (DNI-472).
///
/// Filled by DNI-470 (1.8) with the callable adapter.
library;

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// One entity change with its pre-allocated change-log entry id.
final class OversizedGovernedEntry {
  /// Creates an entry.
  const OversizedGovernedEntry({required this.entryId, required this.change});

  /// The `change_log/{ulid}` id.
  final String entryId;

  /// The entity change.
  final GovernedEntityChange change;

  @override
  bool operator ==(Object other) =>
      other is OversizedGovernedEntry &&
      other.entryId == entryId &&
      other.change == change;

  @override
  int get hashCode => Object.hash(entryId, change);

  @override
  String toString() => 'OversizedGovernedEntry($entryId)';
}

/// The callable request.
final class OversizedGovernedWrite {
  /// Creates a request.
  const OversizedGovernedWrite({
    required this.actionId,
    required this.actorRole,
    required this.entries,
    this.revertsActionId,
  });

  /// The action ULID.
  final String actionId;

  /// The asserted owner role.
  final ActorRole actorRole;

  /// The entries, in action order.
  final List<OversizedGovernedEntry> entries;

  /// The action this one undoes, if any.
  final String? revertsActionId;

  @override
  String toString() =>
      'OversizedGovernedWrite($actionId, ${entries.length} entries)';
}

/// The callable's receipt.
final class GovernedWriteReceipt {
  /// Creates a receipt.
  const GovernedWriteReceipt({
    required this.actionId,
    required this.changeIds,
    this.at,
    this.replayed = false,
    this.noop = false,
  });

  /// The action ULID.
  final String actionId;

  /// The change-log entry ids written.
  final List<String> changeIds;

  /// The server instant of the write (UTC), if reported.
  final DateTime? at;

  /// Whether the request was an identical replay.
  final bool replayed;

  /// Whether nothing changed.
  final bool noop;

  @override
  String toString() =>
      'GovernedWriteReceipt($actionId, ${changeIds.length} changes)';
}

/// The device is offline, so an online-only write cannot run.
final class OnlineRequiredException implements Exception {
  /// Creates the exception.
  const OnlineRequiredException();

  @override
  String toString() => 'OnlineRequiredException';
}

/// The callable failed without saying whether the server committed (for
/// example `deadline-exceeded` or `internal`). Re-sending the IDENTICAL
/// request is safe: the callable is idempotent on its `actionId`, so a
/// committed request replays its stored result.
final class GovernedWriteOutcomeUnknown implements Exception {
  /// Creates the failure with the callable error [code].
  const GovernedWriteOutcomeUnknown(this.code);

  /// The callable error code.
  final String code;

  @override
  String toString() => 'GovernedWriteOutcomeUnknown($code)';
}

/// Writes an oversized governed action through the callable.
abstract interface class OversizedGovernedWritePort {
  /// Sends [request] for [scope]. Throws [OnlineRequiredException] when
  /// offline (nothing was sent), a `PermanentWriteRejection` for a terminal
  /// contract error, and [GovernedWriteOutcomeUnknown] when the server may
  /// have committed.
  Future<GovernedWriteReceipt> write(
    LearnerScope scope,
    OversizedGovernedWrite request,
  );
}
