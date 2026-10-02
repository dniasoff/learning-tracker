/// Display rows for the DNI-513 Change history widget tests: a governed
/// row and a learning row built directly (no mapper), and the overrides
/// and app that render one widget of the history in English.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';

import 'change_history_fixtures.dart';
import 'pump_app.dart';

/// Rav Cohen (tutor) at 2026-11-01 16:10 learner time.
final HistoryStamp historyRowStamp = HistoryStamp(
  actor: historyTutor,
  at: DateTime.utc(2026, 11, 1, 21, 10),
  day: '2026-11-01',
  localTime: DateTime(2026, 11, 1, 16, 10),
);

/// The parent's stamp a day later.
final HistoryStamp historyRowParentStamp = HistoryStamp(
  actor: historyParent,
  at: DateTime.utc(2026, 11, 2, 14),
  day: '2026-11-02',
  localTime: DateTime(2026, 11, 2, 9),
);

/// A governed goal-deadline row with [others] further parts.
ChangeHistoryRow governedHistoryRow({
  HistoryStamp? stamp,
  bool notifiesParent = true,
  bool isRevert = false,
  HistoryStamp? undoneBy,
  List<GovernedPart> others = const [],
}) => ChangeHistoryRow(
  key: 'action:deadline',
  kind: ChangeHistoryRowKind.governed,
  stamp: stamp ?? historyRowStamp,
  summary: GovernedSummary(
    primary: GovernedPart(
      entity: GovernedEntity.goal,
      change: GovernedChangeKind.updated,
      fields: const ['target_date'],
      newDate: '2026-11-03',
    ),
    others: others,
  ),
  notifiesParent: notifiesParent,
  isRevert: isRevert,
  lockIgnored: false,
  eventCount: 1,
  undoneBy: undoneBy,
);

/// A learning row of [refs] on the main track.
ChangeHistoryRow learningHistoryRow({
  List<String> refs = const ['Mishnah Berakhot 1:1'],
  LearningEventKind kind = LearningEventKind.learn,
  DateState dateState = DateState.dated,
  String learnedOn = '2026-11-01',
  bool lockIgnored = false,
  HistoryStamp? voidedBy,
  int voidedCount = 0,
  Actor actor = historyParent,
}) => ChangeHistoryRow(
  key: 'events:learn',
  kind: ChangeHistoryRowKind.learning,
  stamp: HistoryStamp(
    actor: actor,
    at: historyRowStamp.at,
    day: historyRowStamp.day,
    localTime: historyRowStamp.localTime,
  ),
  summary: LearningSummary(
    kind: kind,
    refs: refs,
    source: const MainTrackSource(),
    dateState: dateState,
    learnedOn: learnedOn,
  ),
  notifiesParent: false,
  isRevert: false,
  lockIgnored: lockIgnored,
  eventCount: refs.length,
  voidedBy: voidedBy,
  voidedCount: voidedCount,
);

/// Overrides that label a ref without the content store ("Mishnah " is
/// dropped).
List<Override> historyRowOverrides() => [
  changeHistoryRefLabelProvider.overrideWith(
    (ref, sefariaRef) async => sefariaRef.replaceFirst('Mishnah ', ''),
  ),
];

/// [child] in the app's light theme, English.
Widget historyRowApp(Widget child) => pumpApp(
  child: Scaffold(body: child),
  overrides: historyRowOverrides(),
  theme: AppTheme.themeFor(brightness: Brightness.light),
);
