/// The learner-settings history the lock overlay and capture gate read
/// (AD-36, AD-37), keyed by [LearnerScope] (ruling B10).
///
/// C0 (DNI-524) fixes the name and type; DNI-470 (1.8) owns and fills it
/// (ruling B4(d)). It is the ONE settings source for every lock reader:
/// `LearningCommands` (its `CaptureGate` and `lockWindows` checks) and the
/// learning history read it, never the device's Sacred Time preferences.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';

/// The [LearnerSettingsHistory] of [LearnerScope], live (DNI-470 AC-7):
/// the profile's current settings and its complete `learnerSettings`
/// change log, through [LearnerSettingsHistory.reconstruct].
///
/// Loading while the account is not ready or the history is still paging
/// in (never a partial history); an error — and so a fail-closed gate —
/// when the profile's settings or the history cannot be read.
final learnerLockSettingsProvider = StreamProvider.autoDispose
    .family<LearnerSettingsHistory, LearnerScope>((ref, scope) async* {
      final reader = await ref.watch(learnerSettingsReaderProvider.future);
      final changeLog = await ref.watch(changeLogRepositoryProvider.future);
      if (reader == null || changeLog == null) return; // not ready: loading
      yield* watchLearnerSettingsHistory(
        reader.watch(scope),
        changeLog.watchIntentHistory(scope),
      );
    }, retry: (retryCount, error) => null);

/// The learner's intent history holds rows that could not be decoded, so
/// its settings chronology cannot be trusted (AC-7 fails closed).
final class UnreadableSettingsHistoryException implements Exception {
  /// Creates the exception for the [rows] that did not decode.
  UnreadableSettingsHistoryException(List<RejectedRow> rows)
    : rows = List.unmodifiable(rows);

  /// The undecodable rows.
  final List<RejectedRow> rows;

  /// Only document ids, never row contents (PV-1).
  @override
  String toString() =>
      'UnreadableSettingsHistoryException(${rows.map((r) => r.docId)})';
}

/// Combines the latest current [settings] and the latest COMPLETE intent
/// [history] into a [LearnerSettingsHistory], emitting only once both have
/// delivered and only when the result changes.
///
/// A complete history holding rows that did not decode
/// ([CompleteReadReady.rejected]) fails closed (AC-7): a dropped row could
/// be a `learnerSettings` entry, so no settings are reconstructed from it.
/// It is forwarded as an [UnreadableSettingsHistoryException], and nothing
/// is published until a clean complete history arrives. An error on either
/// input, or a [LearnerSettingsHistory.reconstruct] failure, is forwarded
/// as an error event too.
Stream<LearnerSettingsHistory> watchLearnerSettingsHistory(
  Stream<LearnerSettings> settings,
  Stream<CompleteRead<ChangeLogEntry>> history,
) {
  late final StreamController<LearnerSettingsHistory> out;
  StreamSubscription<LearnerSettings>? settingsSub;
  StreamSubscription<CompleteRead<ChangeLogEntry>>? historySub;
  LearnerSettings? current;
  List<ChangeLogEntry>? entries;
  LearnerSettingsHistory? last;

  void publish() {
    final c = current;
    final e = entries;
    if (c == null || e == null) return;
    try {
      final next = LearnerSettingsHistory.reconstruct(current: c, entries: e);
      if (next == last) return;
      last = next;
      out.add(next);
    } catch (error, stackTrace) {
      last = null;
      out.addError(error, stackTrace);
    }
  }

  void forwardError(Object error, StackTrace stackTrace) {
    last = null; // re-publish once the input recovers
    out.addError(error, stackTrace);
  }

  out = StreamController<LearnerSettingsHistory>(
    onListen: () {
      settingsSub = settings.listen((s) {
        current = s;
        publish();
      }, onError: forwardError);
      historySub = history.listen((read) {
        if (read is! CompleteReadReady<ChangeLogEntry>) return;
        if (!read.isClean) {
          entries = null; // no reconstruction from an incomplete chronology
          forwardError(
            UnreadableSettingsHistoryException(read.rejected),
            StackTrace.current,
          );
          return;
        }
        entries = read.items;
        publish();
      }, onError: forwardError);
    },
    onCancel: () async {
      await settingsSub?.cancel();
      await historySub?.cancel();
      await out.close();
    },
  );
  return out.stream;
}
