/// AD-37 learner-settings history: which governed settings were in force
/// at any instant.
///
/// The lock rules (AD-36), civil dates (AD-41), `streakDay` / catch-up
/// (AD-40), `CaptureGate` and the engine all read settings through this one
/// value, so a past instant is always judged by the settings in force then.
/// Only [LearnerSettingsHistory.reconstruct] (DNI-470) builds it from the
/// change log.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

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
  /// - Only `learnerSettings` entries of [current]'s profile count; any
  ///   other entry is ignored, so the whole intent history can be passed.
  /// - They are ordered by `original_at ?? at` (an import keeps its
  ///   original chronology), ties by entry id. A seed (`before` all null)
  ///   that is not already first leads, as the state from the beginning
  ///   of time: an AD-49 import replays history older than the
  ///   destination's import-time seed (DNI-482).
  /// - No entry: [current] holds from the beginning of time.
  /// - Otherwise the settings after the LAST entry are [current], and the
  ///   settings after each earlier entry are rebuilt backwards by applying
  ///   the next entry's `before` (a `null` field = absent). Each entry's
  ///   settings start at its instant; instants before the first entry use
  ///   that entry's `after` state (the first span starts at the beginning
  ///   of time). Entries at the same instant collapse to the later one.
  ///
  /// Throws [StorageFormatException] when an entry holds a settings value
  /// of the wrong type, so readers fail closed (AD-36) instead of judging
  /// an instant by guessed settings.
  factory LearnerSettingsHistory.reconstruct({
    required LearnerSettings current,
    required List<ChangeLogEntry> entries,
  }) => _reconstruct(current, entries);

  static DateTime _effectiveAt(ChangeLogEntry e) => e.originalAt ?? e.at;

  static LearnerSettingsHistory _reconstruct(
    LearnerSettings current,
    List<ChangeLogEntry> entries,
  ) {
    final mine =
        entries
            .where(
              (e) =>
                  e.entity == GovernedEntity.learnerSettings &&
                  e.entityId == current.profileId,
            )
            .toList()
          ..sort((a, b) {
            final byTime = _effectiveAt(a).compareTo(_effectiveAt(b));
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
    if (mine.isEmpty) return LearnerSettingsHistory.constant(current);
    // An AD-49 import replays the source history with `original_at`
    // instants that predate the destination's own seed (the import-time
    // settings, written when the profile was created). A seed is the
    // learner's state from the beginning of time, so it leads wherever its
    // instant falls; every replayed entry then starts its own span.
    final seeds = mine.where(_isSeed).toList();
    final seedMoved = seeds.isNotEmpty && !identical(seeds.first, mine.first);
    if (seedMoved) {
      mine
        ..removeWhere(_isSeed)
        ..insertAll(0, seeds);
    }
    final firstFrom = seedMoved ? null : _effectiveAt(mine.first);

    // states[k]: the settings in force right after mine[k].
    final states = List<LearnerSettings>.filled(mine.length, current);
    for (var k = mine.length - 1; k > 0; k--) {
      states[k - 1] = _applyBefore(states[k], mine[k], mine[k - 1].id);
    }
    final spans = <SettingsSpan>[
      SettingsSpan(fromUtc: null, settings: states.first),
    ];
    for (var k = 1; k < mine.length; k++) {
      final from = _effectiveAt(mine[k]);
      if (spans.last.fromUtc == from ||
          (spans.length == 1 &&
              firstFrom != null &&
              !from.isAfter(firstFrom))) {
        // Same instant as the previous span's start: the later one wins.
        spans[spans.length - 1] = SettingsSpan(
          fromUtc: spans.last.fromUtc,
          settings: states[k],
        );
        continue;
      }
      spans.add(SettingsSpan(fromUtc: from, settings: states[k]));
    }
    return LearnerSettingsHistory(spans);
  }

  /// Whether [e] is a seed (AD-37): it sets `time_zone`, which is
  /// required once seeded, and every `before` value is null. A later
  /// change that only fills an absent optional field is not one.
  static bool _isSeed(ChangeLogEntry e) =>
      e.before.values.every((v) => v == null) &&
      e.after.keys.any(
        (k) => ChangedFieldKey.tryParse(k)?.field == LearnerSettings.kTimeZone,
      );

  /// [after] with [entry]'s `before` values applied: the settings in force
  /// before [entry], last changed by [previousEntryId].
  static LearnerSettings _applyBefore(
    LearnerSettings after,
    ChangeLogEntry entry,
    String previousEntryId,
  ) {
    var latitude = after.latitude;
    var longitude = after.longitude;
    var timeZone = after.timeZone;
    var inIsrael = after.inIsrael;
    Never bad(String field) => throw StorageFormatException(
      'LearnerSettingsHistory',
      field,
      'change-log ${entry.id} holds a value of the wrong type',
    );
    for (final MapEntry(:key, :value) in entry.before.entries) {
      final k = ChangedFieldKey.tryParse(key);
      if (k == null ||
          k.collection != GovernedEntity.learnerSettings.collection ||
          k.docId != after.profileId) {
        continue;
      }
      switch (k.field) {
        case LearnerSettings.kLatitude:
          if (value != null && value is! num) bad(k.field);
          latitude = (value as num?)?.toDouble();
        case LearnerSettings.kLongitude:
          if (value != null && value is! num) bad(k.field);
          longitude = (value as num?)?.toDouble();
        case LearnerSettings.kTimeZone:
          // `time_zone` is required once seeded: a null `before` (the seed
          // itself) keeps the later zone rather than inventing one.
          if (value != null && value is! String) bad(k.field);
          timeZone = value as String? ?? timeZone;
        case LearnerSettings.kInIsrael:
          if (value != null && value is! bool) bad(k.field);
          inIsrael = value as bool?;
      }
    }
    return LearnerSettings(
      profileId: after.profileId,
      timeZone: timeZone,
      latitude: latitude,
      longitude: longitude,
      inIsrael: inIsrael,
      lastChangeId: previousEntryId,
    );
  }

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
