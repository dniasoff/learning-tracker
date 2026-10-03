/// The one catch-up reminder scheduler (Story 3.5, DNI-508; FR-25,
/// feature spine "Reminders" convention).
///
/// One local notification per owner profile per lock `L`, at `L.end`,
/// telling the child the catch-up card is available. Every lock comes from
/// [lockWindows] over the profile's settings history in force; the card's
/// locked days and kind come from [catchUpCardWindowsAt] (AD-36 / AD-40).
/// Nothing here computes a lock, a locked day or a catch-up window of its
/// own (AC-1).
///
/// ## Identity (T1.1, AC-2, AC-4)
///
/// A reminder is keyed by profile and lock (`L.start`), never by locked
/// day, so a yom tov chained into Shabbos — one continuous lock — gets
/// exactly one reminder at its final end. Its notification id is a slot in
/// the profile's catch-up id range ([CatchUpReminderNotifications.idFor]),
/// derived from `L.end`'s UTC day and kept in the device-local
/// [CatchUpReminderLedger] so a later run re-derives it to cancel.
///
/// ## One shot (AC-3, AC-4, AC-7)
///
/// A reminder whose `L.end` is not after now is consumed: it fired, or the
/// device was off and it is not sent late. Consumed keys are kept in the
/// ledger, so a stacked card resuming after a later lock, a restart, a
/// boot or a settings edit never schedules it again. Only locks that end
/// after now are ever scheduled.
///
/// ## Reconcile (T1.2, AC-6, AC-7)
///
/// [CatchUpReminderScheduler.reconcile] compares the desired reminders with
/// the ledger's pending ones and is idempotent: it cancels reminders that
/// are no longer desired (a moved lock, a removed profile, a card that
/// would be empty), schedules new ones, and with `rearm` re-schedules every
/// pending one under the same id (app start, resume) so a reminder lost by
/// the OS comes back without a duplicate. It never requests a permission
/// (AC-8): without one it schedules nothing new.
library;

import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// How far ahead reminders are kept scheduled, so they still fire while
/// the app is not opened for a while (AC-7). Two weeks, like the rolling
/// daily-reminder batch.
const Duration catchUpReminderHorizon = Duration(days: 14);

/// How long a consumed key is remembered: past any lock's catch-up window.
const Duration catchUpReminderConsumedRetention = Duration(days: 35);

/// Catch-up id slots per profile ([CatchUpReminderNotifications.idFor]).
const int catchUpReminderSlots = 20;

/// The reminder's ledger key for [lock] of [profileId].
String catchUpReminderKey(String profileId, LockWindow lock) =>
    '$profileId|${lock.startUtc.toIso8601String()}';

/// The visible copy of one reminder (AC-9).
typedef CatchUpReminderCopy = ({String title, String body});

/// Builds the copy for a lock of [kind] for the learner [displayName].
typedef CatchUpReminderCopyBuilder =
    CatchUpReminderCopy Function(ErevKind kind, String displayName);

/// Whether the card of the lock in [card] would list anything (Story 3.2
/// empty rule, AC-3). Null when it cannot be told on this device (only
/// the active learner's plan is loaded); the reminder is then scheduled.
typedef CatchUpCardContentCheck =
    Future<bool?> Function(CatchUpCardWindow card);

/// One owner profile on the device and what its reminders derive from.
final class CatchUpReminderTarget {
  /// Creates the target.
  const CatchUpReminderTarget({
    required this.profileId,
    required this.displayName,
    required this.history,
    this.hasCardContent,
  });

  /// The learner-profile ULID: the only learner data in the payload.
  final String profileId;

  /// The profile's display name: the only learner data in the copy.
  final String displayName;

  /// The profile's `learnerSettings` history (AD-37), or null when it
  /// cannot be read now: the profile's reminders are then left as they
  /// are (never rescheduled from a guess, never dropped as removed).
  final LearnerSettingsHistory? history;

  /// The card-content check, when this device can tell (AC-3).
  final CatchUpCardContentCheck? hasCardContent;
}

/// One reminder the ledger knows is scheduled with the OS.
final class CatchUpReminderEntry {
  /// Creates the entry.
  const CatchUpReminderEntry({
    required this.key,
    required this.profileId,
    required this.id,
    required this.fireAtUtc,
    required this.copyHash,
  });

  /// [catchUpReminderKey] of the profile and lock.
  final String key;

  /// The learner-profile ULID.
  final String profileId;

  /// The OS notification id.
  final int id;

  /// `L.end`.
  final DateTime fireAtUtc;

  /// A hash of the scheduled copy, so a locale or name change re-schedules
  /// it (the copy itself is not stored).
  final int copyHash;

  @override
  bool operator ==(Object other) =>
      other is CatchUpReminderEntry &&
      other.key == key &&
      other.profileId == profileId &&
      other.id == id &&
      other.fireAtUtc == fireAtUtc &&
      other.copyHash == copyHash;

  @override
  int get hashCode => Object.hash(key, profileId, id, fireAtUtc, copyHash);

  @override
  String toString() =>
      'CatchUpReminderEntry($key, id $id, ${fireAtUtc.toIso8601String()})';
}

/// The device-local reminder state: what is scheduled, and which
/// reminders are consumed (with their `L.end`, for pruning).
final class CatchUpReminderLedgerState {
  /// Creates the state.
  CatchUpReminderLedgerState({
    List<CatchUpReminderEntry> pending = const [],
    Map<String, DateTime> consumed = const {},
  }) : pending = List.unmodifiable(pending),
       consumed = Map.unmodifiable(consumed);

  /// The reminders scheduled with the OS.
  final List<CatchUpReminderEntry> pending;

  /// Consumed reminder keys and their `L.end`.
  final Map<String, DateTime> consumed;
}

/// Where the reminder state is kept on the device (no Firestore, no new
/// schema field).
abstract interface class CatchUpReminderLedger {
  /// The stored state; an empty one when nothing is stored.
  Future<CatchUpReminderLedgerState> read();

  /// Replaces the stored state.
  Future<void> write(CatchUpReminderLedgerState state);
}

/// The local-notification calls the scheduler makes. It has no
/// permission request (AC-8).
abstract interface class CatchUpReminderNotifications {
  /// The notification id of [profileId]'s catch-up [slot]
  /// (`0 <= slot < catchUpReminderSlots`), clear of every other id.
  int idFor(String profileId, int slot);

  /// Whether notifications may be shown now. Never prompts.
  Future<bool> canNotify();

  /// Schedules one one-shot reminder (replacing any with the same [id]).
  /// Its payload names only [profileId].
  Future<void> schedule({
    required int id,
    required String profileId,
    required DateTime fireAtUtc,
    required String title,
    required String body,
  });

  /// Cancels the reminder [id].
  Future<void> cancel(int id);
}

/// What one [CatchUpReminderScheduler.reconcile] did.
final class CatchUpReminderReconcileResult {
  /// Creates the result.
  const CatchUpReminderReconcileResult({
    required this.scheduled,
    required this.cancelled,
    required this.consumed,
  });

  /// The entries scheduled (new, changed or re-armed).
  final List<CatchUpReminderEntry> scheduled;

  /// The ids cancelled.
  final List<int> cancelled;

  /// The keys newly consumed (their `L.end` passed).
  final List<String> consumed;
}

/// A reminder the device should have pending.
typedef _Desired = ({String key, DateTime fireAtUtc, CatchUpReminderCopy copy});

/// The one catch-up reminder scheduler (AC-1). Owner devices only: the
/// caller never constructs it on a tutor device (AC-5).
class CatchUpReminderScheduler {
  /// Creates the scheduler.
  CatchUpReminderScheduler({
    required CatchUpReminderNotifications notifications,
    required CatchUpReminderLedger ledger,
    required DateTime Function() clock,
  }) : _notifications = notifications,
       _ledger = ledger,
       _clock = clock;

  final CatchUpReminderNotifications _notifications;
  final CatchUpReminderLedger _ledger;
  final DateTime Function() _clock;

  Future<void> _tail = Future<void>.value();

  /// Reconciles the device's reminders with [targets], one run at a time.
  ///
  /// [onDeviceProfileIds] is every owner profile on the device: a pending
  /// reminder of any other profile is cancelled (AC-6). A target whose
  /// history is null keeps its reminders. [rearm] re-schedules every
  /// pending future reminder under its id (app start, resume, boot).
  Future<CatchUpReminderReconcileResult> reconcile({
    required List<CatchUpReminderTarget> targets,
    required Set<String> onDeviceProfileIds,
    required CatchUpReminderCopyBuilder copy,
    bool rearm = false,
  }) {
    final run = _tail.then(
      (_) => _reconcile(
        targets: targets,
        onDeviceProfileIds: onDeviceProfileIds,
        copy: copy,
        rearm: rearm,
      ),
    );
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// The reminders [target] should have pending at [nowUtc]: one per lock
  /// that ends after [nowUtc] within [catchUpReminderHorizon], has locked
  /// days, is not [consumed], and whose card would not be empty.
  Future<List<_Desired>> _desired(
    CatchUpReminderTarget target,
    LearnerSettingsHistory history,
    DateTime nowUtc,
    Map<String, DateTime> consumed,
    CatchUpReminderCopyBuilder copy,
  ) async {
    final out = <_Desired>[];
    for (final card in upcomingCatchUpCards(history, nowUtc)) {
      final key = catchUpReminderKey(target.profileId, card.lock);
      if (consumed.containsKey(key)) continue; // AC-4
      final lock = card.lock;
      final check = target.hasCardContent;
      if (check != null && await check(card) == false) continue; // AC-3
      out.add((
        key: key,
        fireAtUtc: lock.endUtc,
        copy: copy(card.kind, target.displayName),
      ));
    }
    return out;
  }

  Future<CatchUpReminderReconcileResult> _reconcile({
    required List<CatchUpReminderTarget> targets,
    required Set<String> onDeviceProfileIds,
    required CatchUpReminderCopyBuilder copy,
    required bool rearm,
  }) async {
    final now = _clock().toUtc();
    final state = await _ledger.read();
    final consumed = <String, DateTime>{
      for (final MapEntry(:key, :value) in state.consumed.entries)
        if (now.difference(value) < catchUpReminderConsumedRetention)
          key: value,
    };
    final newlyConsumed = <String>[];
    final cancelled = <int>[];
    final scheduled = <CatchUpReminderEntry>[];

    // 1. A reminder whose `L.end` passed fired (or was missed): consumed,
    // never re-sent. Its id is not cancelled, so a shown one stays in the
    // tray.
    final live = <CatchUpReminderEntry>[];
    for (final e in state.pending) {
      if (e.fireAtUtc.isAfter(now)) {
        live.add(e);
      } else {
        consumed[e.key] = e.fireAtUtc;
        newlyConsumed.add(e.key);
      }
    }

    // 2. A profile no longer on the device loses every reminder (AC-6).
    final kept = <CatchUpReminderEntry>[];
    for (final e in live) {
      if (onDeviceProfileIds.contains(e.profileId)) {
        kept.add(e);
      } else {
        await _notifications.cancel(e.id);
        cancelled.add(e.id);
      }
    }

    // 3. Each resolved profile: desired vs pending.
    final canNotify = await _notifications.canNotify();
    final pending = <CatchUpReminderEntry>[];
    final resolved = {
      for (final t in targets)
        if (t.history != null && onDeviceProfileIds.contains(t.profileId))
          t.profileId: t,
    };
    pending.addAll(kept.where((e) => !resolved.containsKey(e.profileId)));
    for (final target in resolved.values) {
      final mine = [
        for (final e in kept)
          if (e.profileId == target.profileId) e,
      ];
      final desired = await _desired(
        target,
        target.history!,
        now,
        consumed,
        copy,
      );
      final desiredKeys = {for (final d in desired) d.key};
      final byKey = {for (final e in mine) e.key: e};
      // Cancel first: what is no longer desired (AC-6, AC-3).
      for (final e in mine) {
        if (!desiredKeys.contains(e.key)) {
          await _notifications.cancel(e.id);
          cancelled.add(e.id);
        }
      }
      final usedSlots = <int>{
        for (final e in mine)
          if (desiredKeys.contains(e.key)) _slotOf(target.profileId, e.id),
      };
      for (final d in desired) {
        final copyHash = _copyHash(d.copy);
        final existing = byKey[d.key];
        final int id;
        if (existing != null) {
          id = existing.id;
        } else {
          final slot = _freeSlot(d.fireAtUtc, usedSlots);
          if (slot == null) continue; // more locks than slots: next run
          usedSlots.add(slot);
          id = _notifications.idFor(target.profileId, slot);
        }
        final entry = CatchUpReminderEntry(
          key: d.key,
          profileId: target.profileId,
          id: id,
          fireAtUtc: d.fireAtUtc,
          copyHash: copyHash,
        );
        final unchanged = existing == entry;
        if (unchanged && !rearm) {
          pending.add(entry);
          continue;
        }
        if (!canNotify) {
          // No permission (AC-8): nothing new is scheduled and nothing is
          // requested. A changed reminder is withdrawn; an unchanged one
          // stays as the OS has it.
          if (existing != null && !unchanged) {
            await _notifications.cancel(existing.id);
            cancelled.add(existing.id);
          } else if (existing != null) {
            pending.add(existing);
          }
          continue;
        }
        await _notifications.schedule(
          id: id,
          profileId: target.profileId,
          fireAtUtc: d.fireAtUtc,
          title: d.copy.title,
          body: d.copy.body,
        );
        scheduled.add(entry);
        pending.add(entry);
      }
    }

    await _ledger.write(
      CatchUpReminderLedgerState(pending: pending, consumed: consumed),
    );
    return CatchUpReminderReconcileResult(
      scheduled: scheduled,
      cancelled: cancelled,
      consumed: newlyConsumed,
    );
  }

  /// The slot [id] holds in [profileId]'s range, or -1 outside it.
  int _slotOf(String profileId, int id) {
    for (var s = 0; s < catchUpReminderSlots; s++) {
      if (_notifications.idFor(profileId, s) == id) return s;
    }
    return -1;
  }

  /// The slot for a reminder at [fireAtUtc]: its UTC day in the ring of
  /// [catchUpReminderSlots], or the next free one. Two locks never end on
  /// one UTC day in practice, and a horizon shorter than the ring keeps
  /// the derived slots of pending reminders apart.
  static int? _freeSlot(DateTime fireAtUtc, Set<int> used) {
    final day =
        fireAtUtc.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    for (var i = 0; i < catchUpReminderSlots; i++) {
      final slot = (day + i) % catchUpReminderSlots;
      if (!used.contains(slot)) return slot;
    }
    return null;
  }

  /// A stable hash of [copy] (FNV-1a over its UTF-16 code units).
  static int _copyHash(CatchUpReminderCopy copy) {
    var hash = 0x811c9dc5;
    for (final unit in '${copy.title}\u0000${copy.body}'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}

/// The catch-up card of every lock that ends after [nowUtc] within
/// [catchUpReminderHorizon], oldest first: the card each lock leaves
/// behind, as the AD-40 projection sees it just after `L.end`. A lock that
/// has ended is consumed and absent (AC-4, AC-7); a lock with no locked
/// day leaves no card and is absent. Locks come from [lockWindows] only.
List<CatchUpCardWindow> upcomingCatchUpCards(
  LearnerSettingsHistory history,
  DateTime nowUtc,
) {
  final now = nowUtc.toUtc();
  return [
    for (final lock in lockWindows(
      history,
      now,
      now.add(catchUpReminderHorizon),
    ))
      if (lock.endUtc.isAfter(now)) ?_cardOf(history, lock),
  ];
}

/// The catch-up card [lock] leaves behind, as the AD-40 projection sees
/// it just after `L.end`; null when the lock has no locked day.
CatchUpCardWindow? _cardOf(LearnerSettingsHistory history, LockWindow lock) {
  for (final card in catchUpCardWindowsAt(
    history,
    lock.endUtc.add(civilTick),
  )) {
    if (card.lock == lock) return card;
  }
  return null;
}
