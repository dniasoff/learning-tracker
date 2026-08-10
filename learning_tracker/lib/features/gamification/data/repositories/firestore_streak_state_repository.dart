/// Firestore-backed read facade over derived streak state — the
/// gamification-side counterpart to `StreakStateService`
/// (`lib/features/gamification/streak/streak_state_service.dart`), which
/// this class deliberately does NOT `implements` (it is a concrete class,
/// not an interface — see the class doc comment's "Why no interface"
/// section).
///
/// Follows the reference pattern `FirestoreBookmarkRepositoryAdapter`
/// (`lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
/// as closely as a repository with no existing abstract interface can:
/// takes a [Ref], re-resolves the Firestore provider inside every method,
/// keeps construction synchronous. Read that class's doc comment first;
/// this one only calls out what is different.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event_entry.dart';
import 'package:learning_tracker/features/gamification/streak/streak_log_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';

/// Firestore-backed streak-state read facade.
///
/// ## Why no interface
///
/// `StreakService`/`StreakStateService` are concrete classes today, not
/// implementations of an abstract repository interface — there was nothing
/// to `implements` here, unlike [BookmarkRepository] or [ProgressRepository].
/// This class's public methods are shaped to match [StreakStateService]'s
/// own surface (`getStreak`/`watchStreak`/`getRecoveryInfo`/
/// `getStreakCalendar`) so a future caller can swap one for the other
/// mechanically, but there is no shared type binding the two together.
///
/// ## Read-only — the write path lives at the completion-recording call site
///
/// `StreakEventLog.append` (the Drift-era write path) is called when a
/// completion is recorded, not from anywhere in `gamification/`. The
/// Firestore analogue is [FirestoreStreakEventRepository.append] — that
/// belongs to whichever call site records a completion against Firestore
/// (owned by the `learning` feature's rewire, out of this task's scope), not
/// here. This class only derives read state from the log, mirroring
/// [StreakStateService]'s own read-only responsibility.
///
/// ## `StreakLogEvent.profileId` is a placeholder, and never leaves this file
///
/// [StreakReducer.reduce] takes `Iterable<StreakLogEvent>` — the Drift-era
/// value type, which carries an `int profileId` [StreakEventEntry]
/// (Firestore-shaped — see its own class doc comment) deliberately does not
/// have, because the profile is already the collection path segment above
/// `streak_events`. [_asLogEvents] maps [StreakEventEntry] → [StreakLogEvent]
/// with `profileId: 0` — verified by reading [StreakReducer.reduce] that
/// `profileId` is never actually read inside the reduce (only `eventType`
/// and `eventTimestamp` are), so the placeholder never influences the
/// computed [StreakState]. No method on this class returns a
/// [StreakLogEvent] to a caller, so that placeholder never leaks past this
/// file — unlike the `Completion.id`/`profileId`/`trackId` gap
/// `FirestoreProgressRepositoryAdapter` flags, where the same trick would
/// leak fabricated data to a caller and was rejected for exactly that
/// reason.
///
/// ## Full history, not the 500-most-recent — and the flagged exception
///
/// [getStreak], [getRecoveryInfo], and [getStreakCalendar] all read through
/// [FirestoreStreakEventRepository.getAllEvents], which pages internally
/// past the SR-4 500-item `list()` cap (see that method's doc comment) —
/// so `maxStreak` and the calendar are computed over the WHOLE log, exactly
/// matching Drift's unbounded `SELECT * FROM streak_events`. [watchStreak]
/// is the one exception: [FirestoreStreakEventRepository] exposes no
/// "watch the whole log" stream (only [FirestoreStreakEventRepository.
/// watchRecentEvents], bounded at [FirestoreStreakEventRepository]'s own
/// 500-item cap, and [FirestoreStreakEventRepository.watchEvent] for a
/// single document) — building a genuine "watch everything" stream would
/// mean this class reaching into `cloud_firestore` directly, which the
/// Firebase-confinement gate forbids outside `lib/data/repositories/` (see
/// `docs/firestore-rewrite-map.md`'s "Where shared utilities may live"
/// section). [watchStreak] therefore reduces over
/// [FirestoreStreakEventRepository.watchRecentEvents]'s bounded feed —
/// correct for any profile with 500 or fewer lifetime streak events (every
/// realistic profile today), but a profile that eventually accrues more
/// than 500 `streak_events` documents would see its REACTIVE `maxStreak`
/// under-computed (the one-shot [getStreak] stays exactly correct
/// regardless, since it always pages the full log). Flagged, not silently
/// glossed over — the fix is a "watch everything, paginated" stream on
/// [FirestoreStreakEventRepository] itself, out of this class's scope to
/// add (that repository is owned by `lib/data/repositories/`).
/// Thrown when `firestoreStreakEventRepositoryProvider` resolves to `null` —
/// no active account, or no active learner profile, yet.
///
/// Owner ruling D-E: a read path that cannot resolve its backend must fail
/// LOUDLY. For a streak the natural empty value is a streak of ZERO, which
/// looks exactly like a real answer to the learner, to the logs, and to every
/// gate. Mirrors `CompletionRepositoryNotReadyException`'s shape.
class StreakStateRepositoryNotReadyException implements Exception {
  const StreakStateRepositoryNotReadyException();

  @override
  String toString() =>
      'StreakStateRepositoryNotReadyException: '
      'the streak-event repository resolved to null (no active account, or no '
      'active learner profile, yet) — cannot derive streak state.';
}

class FirestoreStreakStateRepository {
  FirestoreStreakStateRepository({required Ref ref, LocalDayClock? clock})
    : _ref = ref,
      _clock = clock ?? const SystemLocalDayClock();

  final Ref _ref;
  final LocalDayClock _clock;

  /// Re-reads `firestoreStreakEventRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreBookmarkRepositoryAdapter`'s class doc comment (point 3).
  /// Like [_resolveOrNull], but throws instead of returning `null`.
  ///
  /// Every read on this class routes through this, per owner ruling D-E: a read
  /// path that cannot reach its backend fails LOUDLY rather than returning a
  /// natural-looking empty value.
  Future<FirestoreStreakEventRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const StreakStateRepositoryNotReadyException();
    }
    return repo;
  }

  Future<FirestoreStreakEventRepository?> _resolveOrNull() {
    return _ref.read(firestoreStreakEventRepositoryProvider.future);
  }

  StreakLogEvent _asLogEvent(StreakEventEntry entry) => StreakLogEvent(
    // Placeholder — see the class doc comment's "StreakLogEvent.profileId
    // is a placeholder" section for why this is safe here specifically.
    profileId: 0,
    eventType: entry.eventType,
    eventTimestamp: entry.eventTimestamp,
    clientDeviceId: entry.clientDeviceId,
  );

  /// Returns the current [StreakState], derived from the FULL event log.
  ///
  /// Throws [StreakStateRepositoryNotReadyException] when the backend cannot
  /// be resolved (owner ruling D-E). It deliberately does NOT reduce an empty
  /// event list: that maps to [StreakState.empty], i.e. a streak of ZERO, which
  /// is indistinguishable from a learner who genuinely has no streak. A child
  /// seeing their streak silently reset to 0 because a provider was not ready
  /// is precisely the failure D-E exists to prevent, and no gate can see it.
  Future<StreakState> getStreak() async {
    final repo = await _resolve();
    final events = await repo.getAllEvents();
    return const StreakReducer().reduce(
      events.map(_asLogEvent),
      today: _clock.today(),
    );
  }

  /// Streak recovery info. W3.20 dropped the grace-period feature (see
  /// [StreakService.getRecoveryInfo]'s doc comment) — `wasRecovered` is
  /// always `false`, matching that method's post-W3.20 shape exactly.
  Future<StreakRecoveryInfo> getRecoveryInfo() async {
    final state = await getStreak();
    return StreakRecoveryInfo(
      wasRecovered: false,
      currentStreak: state.currentStreak,
    );
  }

  /// Set of local dates with at least one `completion` event within
  /// `[startUtc, endUtc]`, scoped to this profile — mirrors
  /// [StreakService.getStreakCalendar] exactly, including its
  /// full-log-not-summary read (Drift's version reads `streak_events`
  /// directly too, not a derived summary).
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    // D-E: an unresolvable backend must not render as "no active days" — an
    // empty calendar is indistinguishable from a learner who has never studied.
    final repo = await _resolve();

    final events = await repo.getAllEvents();
    final startLocal = LocalDayUtils.extractLocalDate(startUtc);
    final endLocal = LocalDayUtils.extractLocalDate(endUtc);

    final activeDates = <DateTime>{};
    for (final event in events) {
      if (event.eventType != 'completion') continue;
      final localDate = LocalDayUtils.extractLocalDate(event.eventTimestamp);
      if (!localDate.isBefore(startLocal) && !localDate.isAfter(endLocal)) {
        activeDates.add(localDate);
      }
    }
    return activeDates;
  }

  /// Reactive [StreakState] — see the class doc comment's "Full history,
  /// not the 500-most-recent" section for the bounded-vs-unbounded caveat
  /// specific to this method. Not-ready (provider resolves `null`) emits a
  /// single [StreakState.empty] and completes, rather than hanging forever —
  /// a caller that needs to react to the provider becoming ready later
  /// should re-watch after observing that.
  Stream<StreakState> watchStreak() async* {
    // D-E: yielding StreakState.empty here would publish a streak of ZERO to
    // every listener whenever the provider was not yet ready. Throwing inside
    // an `async*` surfaces as a stream error, which a consumer can observe and
    // react to — a silent zero cannot be.
    final repo = await _resolve();
    yield* repo
        .watchRecentEvents(limit: 500)
        .map(
          (events) => const StreakReducer().reduce(
            events.map(_asLogEvent),
            today: _clock.today(),
          ),
        );
  }
}
