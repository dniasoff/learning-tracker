/// The read composition behind `learnerStateProvider` (DNI-474, AD-35):
/// the profile's complete learning-event, sub-track, intent-history and
/// governed-intent reads plus the calendar inputs, folded through the pure
/// [LearnerStateEngine] once every input is complete.
///
/// Kept free of Riverpod so the paging, error and recompute rules are unit
/// tested on plain streams; the provider only wires the repositories in.
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Loads the AD-35 `calendars` input (`program_id → [(civilDate, node)]`)
/// for the calendar programs [intent] follows, as of [nowUtc].
typedef LearnerCalendarLoader =
    Future<Map<String, List<CalendarAssignment>>> Function(
      LearnerIntent intent,
      LearnerSettingsHistory settingsHistory,
      DateTime nowUtc,
    );

/// The learner's intent history holds rows that could not be decoded, so
/// the engine's settings and main-track chronology cannot be trusted. The
/// composition fails closed instead of computing state from a partial log.
final class UnreadableIntentHistoryException implements Exception {
  /// Creates the exception for the [rows] that did not decode.
  UnreadableIntentHistoryException(List<RejectedRow> rows)
    : rows = List.unmodifiable(rows);

  /// The undecodable rows.
  final List<RejectedRow> rows;

  /// Only document ids, never row contents (PV-1).
  @override
  String toString() =>
      'UnreadableIntentHistoryException(${rows.map((r) => r.docId)})';
}

/// Folds the complete inputs into [LearnerState]s.
///
/// * Nothing is emitted until [events], [subTracks] and [intentHistory] have
///   each delivered a [CompleteReadReady], [intent] has emitted, and the
///   calendars for that intent have loaded. A source that goes back to
///   [CompleteReadLoading] (re-paging) holds every emission until it is
///   complete again, so a partial `LearnerState` never escapes (AD-35
///   "Complete inputs").
/// * Each later input change re-runs [engine] once over the latest complete
///   inputs, at [nowUtc]; so does each [recompute] tick (a day rollover).
/// * Undecodable event and sub-track rows are carried on
///   [LearnerState.rejectedRows]; undecodable intent-history rows fail the
///   read with [UnreadableIntentHistoryException].
/// * An error on any input, a calendar load failure or an engine failure is
///   forwarded as an error event; the next complete input recovers.
/// * Only the curricula the learner touches (events, sub-tracks, main-track
///   intent or goals) get their corpus passed in, so an untouched
///   curriculum has no [CurriculumState] (read it as all-empty).
Stream<LearnerState> composeLearnerState({
  required Stream<CompleteRead<LearningEvent>> events,
  required Stream<CompleteRead<SubTrack>> subTracks,
  required Stream<CompleteRead<ChangeLogEntry>> intentHistory,
  required Stream<LearnerIntent> intent,
  required Map<String, Corpus> corpora,
  required LearnerCalendarLoader loadCalendars,
  required DateTime Function() nowUtc,
  Stream<void>? recompute,
  LearnerStateEngine engine = const LearnerStateEngine(),
  void Function(String input, bool pending)? onInputStatusChanged,
}) {
  late final StreamController<LearnerState> out;
  final subscriptions = <StreamSubscription<Object?>>[];

  CompleteReadReady<LearningEvent>? latestEvents;
  CompleteReadReady<SubTrack>? latestSubTracks;
  List<ChangeLogEntry>? latestHistory;
  LearnerIntent? latestIntent;
  var eventsPaging = true;
  var subTracksPaging = true;
  var historyPaging = true;

  // Calendars are reloaded only when the intent or the day changes.
  LearnerIntent? calendarsFor;
  Map<String, List<CalendarAssignment>>? calendars;
  var calendarGeneration = 0;

  void forwardError(Object error, StackTrace stackTrace) {
    if (!out.isClosed) out.addError(error, stackTrace);
  }

  bool complete() =>
      !eventsPaging &&
      !subTracksPaging &&
      !historyPaging &&
      latestEvents != null &&
      latestSubTracks != null &&
      latestHistory != null &&
      latestIntent != null;

  void run(LearnerSettingsHistory settingsHistory, DateTime now) {
    final evts = latestEvents!;
    final tracks = latestSubTracks!;
    final learner = latestIntent!;
    try {
      final touched = <String>{
        for (final e in evts.items) ?e.curriculumId,
        for (final s in tracks.items) s.curriculumId,
        ...learner.mainTracks.keys,
        ...learner.goals.keys,
      };
      final state = engine.run(
        LearnerStateInputs(
          events: evts.items,
          subTracks: tracks.items,
          mainTrackIntent: learner.mainTracks,
          goals: learner.goals,
          intentHistory: latestHistory!,
          settingsHistory: settingsHistory,
          calendars: calendars!,
          corpora: {
            for (final c in touched)
              if (corpora[c] case final corpus?) c: corpus,
          },
          nowUtc: now,
        ),
      );
      final rejected = [...evts.rejected, ...tracks.rejected];
      if (!out.isClosed) {
        out.add(
          rejected.isEmpty
              ? state
              : LearnerState(
                  nowUtc: state.nowUtc,
                  today: state.today,
                  curricula: state.curricula,
                  countedEventIds: state.countedEventIds,
                  earningEventIds: state.earningEventIds,
                  lockIgnoredEventIds: state.lockIgnoredEventIds,
                  rejectedRows: [...state.rejectedRows, ...rejected],
                  countedLearns: state.countedLearns,
                ),
        );
      }
    } catch (error, stackTrace) {
      forwardError(error, stackTrace);
    }
  }

  void publish({bool dayChanged = false}) {
    if (!complete()) return;
    final LearnerSettingsHistory settingsHistory;
    try {
      settingsHistory = LearnerSettingsHistory.reconstruct(
        current: latestIntent!.settings,
        entries: latestHistory!,
      );
    } catch (error, stackTrace) {
      forwardError(error, stackTrace);
      return;
    }
    final now = nowUtc();
    final learner = latestIntent!;
    if (!dayChanged && calendars != null && identical(calendarsFor, learner)) {
      run(settingsHistory, now);
      return;
    }
    final generation = ++calendarGeneration;
    onInputStatusChanged?.call('calendar', true);
    loadCalendars(learner, settingsHistory, now).then(
      (loaded) {
        if (generation != calendarGeneration || out.isClosed) return;
        onInputStatusChanged?.call('calendar', false);
        calendarsFor = learner;
        calendars = loaded;
        // Inputs may have moved on while the calendars loaded; the engine
        // always runs over the latest complete inputs.
        if (!complete()) return;
        final LearnerSettingsHistory latestSettings;
        try {
          latestSettings = LearnerSettingsHistory.reconstruct(
            current: latestIntent!.settings,
            entries: latestHistory!,
          );
        } catch (error, stackTrace) {
          forwardError(error, stackTrace);
          return;
        }
        if (!identical(latestIntent, learner)) {
          publish();
          return;
        }
        run(latestSettings, nowUtc());
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != calendarGeneration || out.isClosed) return;
        onInputStatusChanged?.call('calendar', false);
        calendars = null;
        calendarsFor = null;
        forwardError(error, stackTrace);
      },
    );
  }

  out = StreamController<LearnerState>(
    onListen: () {
      onInputStatusChanged?.call('events', true);
      onInputStatusChanged?.call('sub_tracks', true);
      onInputStatusChanged?.call('change_log', true);
      onInputStatusChanged?.call('intents', true);
      subscriptions
        ..add(
          events.listen((read) {
            switch (read) {
              case CompleteReadLoading():
                eventsPaging = true;
                if (latestEvents == null) {
                  onInputStatusChanged?.call('events', true);
                }
              case CompleteReadReady():
                eventsPaging = false;
                latestEvents = read;
                onInputStatusChanged?.call('events', false);
                publish();
            }
          }, onError: forwardError),
        )
        ..add(
          subTracks.listen((read) {
            switch (read) {
              case CompleteReadLoading():
                subTracksPaging = true;
                if (latestSubTracks == null) {
                  onInputStatusChanged?.call('sub_tracks', true);
                }
              case CompleteReadReady():
                subTracksPaging = false;
                latestSubTracks = read;
                onInputStatusChanged?.call('sub_tracks', false);
                publish();
            }
          }, onError: forwardError),
        )
        ..add(
          intentHistory.listen((read) {
            switch (read) {
              case CompleteReadLoading():
                historyPaging = true;
                if (latestHistory == null) {
                  onInputStatusChanged?.call('change_log', true);
                }
              case CompleteReadReady():
                if (!read.isClean) {
                  historyPaging = true; // nothing computed from a partial log
                  onInputStatusChanged?.call('change_log', true);
                  forwardError(
                    UnreadableIntentHistoryException(read.rejected),
                    StackTrace.current,
                  );
                  return;
                }
                historyPaging = false;
                latestHistory = read.items;
                onInputStatusChanged?.call('change_log', false);
                publish();
            }
          }, onError: forwardError),
        )
        ..add(
          intent.listen((value) {
            latestIntent = value;
            onInputStatusChanged?.call('intents', false);
            publish();
          }, onError: forwardError),
        );
      if (recompute != null) {
        subscriptions.add(recompute.listen((_) => publish(dayChanged: true)));
      }
    },
    onCancel: () async {
      calendarGeneration++;
      for (final s in subscriptions) {
        await s.cancel();
      }
      await out.close();
    },
  );
  return out.stream;
}
