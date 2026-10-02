/// Plain-language copy of Change history rows (Story 4.5 / DNI-513 AC-3,
/// UX-DR-69): built from the entity and its changed fields, never from a
/// raw payload, map or id.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Formats dates and times for the current locale.
final class ChangeHistoryFormats {
  /// Formats for [context]'s locale.
  ChangeHistoryFormats.of(BuildContext context)
    : _locale = Localizations.localeOf(context).toLanguageTag();

  final String _locale;

  /// "4:10 PM".
  String time(DateTime localTime) => DateFormat.jm(_locale).format(localTime);

  /// "3 Nov".
  String shortDate(CivilDate day) =>
      DateFormat.MMMd(_locale).format(parseCivilDay(day));

  /// "Thu, 20 Feb".
  String dayDate(CivilDate day) =>
      DateFormat.MMMEd(_locale).format(parseCivilDay(day));

  /// "Thu, 20 Feb · 4:10 PM".
  String stamp(HistoryStamp stamp) =>
      '${dayDate(stamp.day)} · ${time(stamp.localTime)}';
}

/// The role label of [role].
String changeHistoryRoleLabel(AppLocalizations l10n, ActorRole role) =>
    switch (role) {
      ActorRole.parent => l10n.changeHistoryRoleParent,
      ActorRole.child => l10n.changeHistoryRoleChild,
      ActorRole.tutor => l10n.changeHistoryRoleTutor,
    };

/// The name shown for [actor]: its display name, else its role (E-2: a
/// missing name never hides who acted).
String changeHistoryActorName(AppLocalizations l10n, Actor actor) {
  final name = actor.displayName.trim();
  return name.isEmpty ? changeHistoryRoleLabel(l10n, actor.role) : name;
}

/// The fields of [part] in plain words, distinct and in order.
String _fields(AppLocalizations l10n, GovernedPart part) {
  final labels = <String>[];
  for (final field in part.fields) {
    final label = switch (field) {
      'name' => l10n.changeHistoryFieldName,
      'ground' => l10n.changeHistoryFieldGround,
      'window_start' ||
      'window_end' ||
      'academic_year' => l10n.changeHistoryFieldDates,
      'rate_per_week' || 'weeks_per_year' => l10n.changeHistoryFieldPace,
      'learns_on_shabbos' => l10n.changeHistoryFieldShabbos,
      'time_zone' => l10n.changeHistoryFieldTimeZone,
      'latitude' ||
      'longitude' ||
      'in_israel' => l10n.changeHistoryFieldLocation,
      _ => l10n.changeHistoryFieldOther,
    };
    if (!labels.contains(label)) labels.add(label);
  }
  return labels.join(', ');
}

/// One governed part as a sentence.
String governedPartSentence(
  AppLocalizations l10n,
  ChangeHistoryFormats formats,
  GovernedPart part,
) {
  final change = part.change;
  final ending =
      change == GovernedChangeKind.ended ||
      change == GovernedChangeKind.removed;
  switch (part.entity) {
    case GovernedEntity.goal:
      if (part.newDate case final date?) {
        return l10n.changeHistoryDeadlineSet(formats.shortDate(date));
      }
      if (change == GovernedChangeKind.created) {
        return l10n.changeHistoryGoalCreated;
      }
      return ending
          ? l10n.changeHistoryGoalEnded
          : l10n.changeHistoryGoalChanged;
    case GovernedEntity.subTrack:
      final name = part.subjectName ?? l10n.changeHistorySubTrackUnnamed;
      return switch (change) {
        GovernedChangeKind.created => l10n.changeHistorySubTrackCreated(name),
        GovernedChangeKind.ended => l10n.changeHistorySubTrackEnded(name),
        GovernedChangeKind.removed => l10n.changeHistorySubTrackRemoved(name),
        GovernedChangeKind.renamed => l10n.changeHistorySubTrackRenamed(name),
        GovernedChangeKind.updated => l10n.changeHistorySubTrackChanged(
          name,
          _fields(l10n, part),
        ),
      };
    case GovernedEntity.mainTrack:
      if (change == GovernedChangeKind.created) {
        return l10n.changeHistoryMainTrackCreated;
      }
      return ending
          ? l10n.changeHistoryMainTrackEnded
          : l10n.changeHistoryMainTrackChanged;
    case GovernedEntity.mainTrackOrder:
      return l10n.changeHistoryOrderChanged;
    case GovernedEntity.mainTrackProgram:
      return l10n.changeHistoryProgramChanged;
    case GovernedEntity.mainTrackStudyDays:
      return l10n.changeHistoryStudyDaysChanged;
    case GovernedEntity.mainTrackStages:
      return l10n.changeHistoryStagesChanged;
    case GovernedEntity.mainTrackScope:
      return l10n.changeHistoryScopeChanged;
    case GovernedEntity.learnerSettings:
      return l10n.changeHistorySettingsChanged(_fields(l10n, part));
  }
}

/// The ref label of [sefariaRef] for display (the ref itself until its
/// label resolves).
String changeHistoryRefLabel(WidgetRef ref, String sefariaRef) =>
    ref.watch(changeHistoryRefLabelProvider(sefariaRef)).asData?.value ??
    sefariaRef;

/// [refs] as one label, a pair, or a first – last range with a count.
String changeHistoryRefsText(
  AppLocalizations l10n,
  WidgetRef ref,
  List<String> refs,
) {
  if (refs.isEmpty) return '';
  final first = changeHistoryRefLabel(ref, refs.first);
  if (refs.length == 1) return first;
  final last = changeHistoryRefLabel(ref, refs.last);
  if (refs.length == 2) return l10n.changeHistoryRefList(first, last);
  return l10n.changeHistoryRefRange(first, last, refs.length);
}

String _source(AppLocalizations l10n, HistorySourceLabel? source) =>
    switch (source) {
      MainTrackSource() => l10n.changeHistorySourceMain,
      SubTrackSource(:final name) => name ?? l10n.changeHistorySubTrackUnnamed,
      null => l10n.changeHistorySubTrackUnnamed,
    };

/// The main sentence of [row].
String changeHistorySentence(
  AppLocalizations l10n,
  ChangeHistoryFormats formats,
  WidgetRef ref,
  ChangeHistoryRow row,
) {
  final summary = row.summary;
  final sentence = switch (summary) {
    GovernedSummary(:final primary) => governedPartSentence(
      l10n,
      formats,
      primary,
    ),
    LearningSummary(kind: LearningEventKind.learn) => l10n.changeHistoryLearned(
      changeHistoryRefsText(l10n, ref, summary.refs),
      _source(l10n, summary.source),
    ),
    LearningSummary() =>
      summary.refs.isEmpty
          ? l10n.changeHistoryRemovedUnknown
          : l10n.changeHistoryRemovedLearning(
              changeHistoryRefsText(l10n, ref, summary.refs),
              _source(l10n, summary.source),
            ),
  };
  return row.isRevert ? l10n.changeHistoryReverted(sentence) : sentence;
}

/// The date-state tag of a learning row, if it has one: catch-up, before
/// tracking, or the learnt date when it is not the recorded day.
String? changeHistoryDateTag(
  AppLocalizations l10n,
  ChangeHistoryFormats formats,
  ChangeHistoryRow row,
) {
  final summary = row.summary;
  if (summary is! LearningSummary) return null;
  return switch (summary.dateState) {
    DateState.catchUp => l10n.changeHistoryDateCatchUp,
    DateState.beforeTracking => l10n.changeHistoryBeforeTracking,
    DateState.dated || null =>
      summary.learnedOn != null && summary.learnedOn != row.stamp.day
          ? formats.shortDate(summary.learnedOn!)
          : null,
  };
}

/// The "removed by …" line of a voided learning row.
String? changeHistoryVoidedText(
  AppLocalizations l10n,
  ChangeHistoryFormats formats,
  ChangeHistoryRow row,
) {
  final by = row.voidedBy;
  if (by == null) return null;
  final name = changeHistoryActorName(l10n, by.actor);
  final when = formats.stamp(by);
  return row.voidedCount < row.eventCount
      ? l10n.changeHistoryVoidedSome(
          row.voidedCount,
          row.eventCount,
          name,
          when,
        )
      : l10n.changeHistoryVoidedBy(name, when);
}
