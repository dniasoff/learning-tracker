/// The `mainTrackStages` and `mainTrackStudyDays` of one curriculum in
/// force at any instant (AD-35 "Complete inputs").
///
/// The value of an entity at instant t is reconstructed from its current
/// docs and the `intentHistory` entries' `before`/`after`, ordered by
/// `original_at ?? at` (then entry id): every entry later than t is undone
/// by restoring its `before` values. A doc whose every field is absent at
/// t did not exist yet; a doc with `ended_at` at t is ended.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

/// `stage_definitions.schedule_type`.
enum StageScheduleType {
  /// Due `delay_days` after the previous stage.
  delay('delay'),

  /// Due on `days_of_week` once the previous stage is done.
  weekly('weekly'),

  /// The last `rolling_window_size` leaves to finish the previous stage.
  rolling('rolling');

  const StageScheduleType(this.storage);

  /// The storage string.
  final String storage;

  /// Storage string → value.
  static final Map<String, StageScheduleType> byStorage = {
    for (final t in values) t.storage: t,
  };
}

/// One review stage of a curriculum (a `stage_definitions` doc), typed.
final class StageSpec {
  /// Creates a stage.
  StageSpec({
    required this.stageOrder,
    this.scheduleType = StageScheduleType.delay,
    this.delayDays = 0,
    Set<int> daysOfWeek = const {},
    this.rollingWindowSize,
  }) : daysOfWeek = Set.unmodifiable(daysOfWeek);

  /// Types a live doc's fields; null without an int `stage_order`.
  ///
  /// A missing or unknown `schedule_type` reads as `delay`, a missing
  /// `delay_days` as 0 (the "Learn" stage shape).
  static StageSpec? fromFields(Map<String, Object?> fields) {
    final order = fields[stageOrderField];
    if (order is! int) return null;
    final type = fields['schedule_type'];
    final delay = fields['delay_days'];
    final dows = fields['days_of_week'];
    final window = fields['rolling_window_size'];
    return StageSpec(
      stageOrder: order,
      scheduleType:
          (type is String ? StageScheduleType.byStorage[type] : null) ??
          StageScheduleType.delay,
      delayDays: delay is int && delay > 0 ? delay : 0,
      daysOfWeek: {
        if (dows is List)
          for (final d in dows)
            if (d is int && d >= 1 && d <= 7) d,
      },
      rollingWindowSize: window is int && window > 0 ? window : null,
    );
  }

  /// Storage key `stage_order`.
  static const stageOrderField = 'stage_order';

  /// The stage order (`stage` on events).
  final int stageOrder;

  /// How the stage is scheduled.
  final StageScheduleType scheduleType;

  /// Days after the previous stage (delay stages).
  final int delayDays;

  /// ISO weekdays (weekly stages).
  final Set<int> daysOfWeek;

  /// Window size (rolling stages).
  final int? rollingWindowSize;

  @override
  bool operator ==(Object other) =>
      other is StageSpec &&
      other.stageOrder == stageOrder &&
      other.scheduleType == scheduleType &&
      other.delayDays == delayDays &&
      other.daysOfWeek.length == daysOfWeek.length &&
      other.daysOfWeek.containsAll(daysOfWeek) &&
      other.rollingWindowSize == rollingWindowSize;

  @override
  int get hashCode => Object.hash(
    stageOrder,
    scheduleType,
    delayDays,
    Object.hashAllUnordered(daysOfWeek),
    rollingWindowSize,
  );

  @override
  String toString() => 'StageSpec($stageOrder, ${scheduleType.storage})';
}

/// The stages and study days in force over one span of time.
final class MainTrackConfig {
  /// Creates a config.
  MainTrackConfig({required List<StageSpec> stages, required this.studyDays})
    : stages = List.unmodifiable(stages);

  /// Live stages, ascending by stage order (one per order).
  final List<StageSpec> stages;

  /// The study days.
  final StudyDays studyDays;

  /// The lowest stage order, or null with no stage.
  int? get firstStageOrder => stages.isEmpty ? null : stages.first.stageOrder;

  /// The stage after [stageOrder], or null when it is the last.
  StageSpec? stageAfter(int stageOrder) {
    for (final s in stages) {
      if (s.stageOrder > stageOrder) return s;
    }
    return null;
  }
}

/// The [MainTrackConfig] of one curriculum through time.
final class MainTrackConfigHistory {
  MainTrackConfigHistory._(this._from, this._configs);

  /// Builds the history of [curriculumId] from its current [intent] docs
  /// and the complete [intentHistory].
  factory MainTrackConfigHistory.build({
    required String curriculumId,
    required MainTrackIntent intent,
    required List<ChangeLogEntry> intentHistory,
  }) {
    final docs = <String, Map<String, Object?>>{
      for (final d in [...intent.stages, ...intent.studyDays])
        '${d.collection}/${d.docId}': {
          ...d.fields,
          if (d.endedAt != null) GovernedKeys.endedAt: d.endedAt,
        },
    };
    final entries = [
      for (final e in intentHistory)
        if (e.entityId == curriculumId &&
            (e.entity == GovernedEntity.mainTrackStages ||
                e.entity == GovernedEntity.mainTrackStudyDays))
          e,
    ]..sort(_byInstantDesc);
    // Newest first: configs[i] is in force from from[i] (inclusive); the
    // last one from the beginning of time (null).
    final from = <DateTime?>[];
    final configs = <MainTrackConfig>[];
    for (final entry in entries) {
      from.add(_instant(entry));
      configs.add(_configOf(docs));
      for (final MapEntry(:key, :value) in entry.before.entries) {
        final parsed = ChangedFieldKey.tryParse(key);
        if (parsed == null) continue;
        final docKey = '${parsed.collection}/${parsed.docId}';
        final doc = docs[docKey] ??= {};
        if (value == null) {
          doc.remove(parsed.field);
        } else {
          doc[parsed.field] = value;
        }
      }
    }
    from.add(null);
    configs.add(_configOf(docs));
    return MainTrackConfigHistory._(
      List.unmodifiable(from.reversed),
      List.unmodifiable(configs.reversed),
    );
  }

  /// Ascending: `_configs[i]` is in force from `_from[i]` (null = always).
  final List<DateTime?> _from;
  final List<MainTrackConfig> _configs;

  /// The config in force at [instantUtc]: every entry at or before it
  /// applied, every later one undone.
  MainTrackConfig at(DateTime instantUtc) {
    for (var i = _configs.length - 1; i > 0; i--) {
      if (!_from[i]!.isAfter(instantUtc)) return _configs[i];
    }
    return _configs.first;
  }

  /// The config in force now (the current docs).
  MainTrackConfig get current => _configs.last;

  static DateTime _instant(ChangeLogEntry e) => e.originalAt ?? e.at;

  static int _byInstantDesc(ChangeLogEntry a, ChangeLogEntry b) {
    final byTime = _instant(b).compareTo(_instant(a));
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  static MainTrackConfig _configOf(Map<String, Map<String, Object?>> docs) {
    final stages = <int, StageSpec>{};
    final studyDays = <Map<String, Object?>>[];
    final keys = docs.keys.toList()..sort();
    for (final key in keys) {
      final fields = docs[key]!;
      if (fields.isEmpty || fields[GovernedKeys.endedAt] != null) continue;
      if (key.startsWith('${MainTrackConfigDoc.stages}/')) {
        final spec = StageSpec.fromFields(fields);
        if (spec != null) stages.putIfAbsent(spec.stageOrder, () => spec);
      } else if (key.startsWith('${MainTrackConfigDoc.studyDays}/')) {
        studyDays.add(fields);
      }
    }
    final ordered = stages.keys.toList()..sort();
    return MainTrackConfig(
      stages: [for (final o in ordered) stages[o]!],
      studyDays: StudyDays.fromFields(studyDays),
    );
  }
}
