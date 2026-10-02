/// AD-37 learner-settings history: which governed settings were in force
/// at any instant.
///
/// The lock rules (AD-36), civil dates (AD-41), `streakDay` / catch-up
/// (AD-40), `CaptureGate` and the engine all read settings through this one
/// value, so a past instant is always judged by the settings in force then.
/// Only [LearnerSettingsHistory.reconstruct] (DNI-470) builds it from the
/// change log.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';

/// The [settings] in force from [fromUtc] until the next span starts.
final class SettingsSpan {
  /// Creates a span; a null [fromUtc] means the beginning of time.
  const SettingsSpan({required this.fromUtc, required this.settings});

  /// First instant (UTC) this span covers, or null for the beginning of
  /// time.
  final DateTime? fromUtc;

  /// The settings in force during the span.
  final LearnerSettings settings;

  @override
  bool operator ==(Object other) =>
      other is SettingsSpan &&
      other.fromUtc == fromUtc &&
      other.settings == settings;

  @override
  int get hashCode => Object.hash(fromUtc, settings);

  @override
  String toString() => 'SettingsSpan(${fromUtc?.toIso8601String()}, $settings)';
}

/// The ordered settings spans of one learner (AD-37).
final class LearnerSettingsHistory {
  /// Creates a history from [spans].
  ///
  /// Throws [ArgumentError] unless [spans] is non-empty, strictly ascending
  /// by `fromUtc`, and only the first span has a null `fromUtc`.
  LearnerSettingsHistory(List<SettingsSpan> spans)
    : spans = List.unmodifiable(spans) {
    if (spans.isEmpty) {
      throw ArgumentError.value(spans, 'spans', 'must not be empty');
    }
    for (var i = 1; i < spans.length; i++) {
      final from = spans[i].fromUtc;
      if (from == null) {
        throw ArgumentError.value(
          spans,
          'spans',
          'only the first span may start at the beginning of time',
        );
      }
      final previous = spans[i - 1].fromUtc;
      if (previous != null && !previous.isBefore(from)) {
        throw ArgumentError.value(spans, 'spans', 'must be strictly ascending');
      }
    }
  }

  /// One span holding [s] for all time.
  factory LearnerSettingsHistory.constant(LearnerSettings s) =>
      LearnerSettingsHistory([SettingsSpan(fromUtc: null, settings: s)]);

  /// Rebuilds the history from the [current] settings and the
  /// `learnerSettings` change-log [entries] (AD-37, DNI-470 AC-7).
  ///
  /// C0 stub, filled by DNI-470 (1.8).
  factory LearnerSettingsHistory.reconstruct({
    required LearnerSettings current,
    required List<ChangeLogEntry> entries,
  }) => _reconstruct(current, entries);

  static LearnerSettingsHistory _reconstruct(
    LearnerSettings current,
    List<ChangeLogEntry> entries,
  ) => c0Stub('DNI-470', 'LearnerSettingsHistory.reconstruct');

  /// The spans, ascending.
  final List<SettingsSpan> spans;

  /// The settings in force at [instantUtc]: the last span whose `fromUtc`
  /// is null or not after [instantUtc]. An instant before the first span's
  /// `fromUtc` gets the first span (the earliest settings known).
  LearnerSettings at(DateTime instantUtc) {
    final t = instantUtc.toUtc();
    var found = spans.first;
    for (final span in spans.skip(1)) {
      if (span.fromUtc!.isAfter(t)) break;
      found = span;
    }
    return found.settings;
  }

  /// The settings in force now (the last span).
  LearnerSettings get current => spans.last.settings;

  @override
  bool operator ==(Object other) {
    if (other is! LearnerSettingsHistory) return false;
    if (other.spans.length != spans.length) return false;
    for (var i = 0; i < spans.length; i++) {
      if (other.spans[i] != spans[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(spans);

  @override
  String toString() => 'LearnerSettingsHistory(${spans.length} spans)';
}
