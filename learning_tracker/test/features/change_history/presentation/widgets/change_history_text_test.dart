/// DNI-513 AC-3 / AC-4 / AC-6 / E-2 / E-3: the plain-language copy of a
/// Change history row — built from the entity and its changed fields,
/// never a raw payload or id; a missing actor name falls back to the
/// role; an undo reads "Reverted change: …"; learning names its refs,
/// source and date state; a void says who removed it and when.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_text.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/change_history_rows.dart';

/// Pumps an English app and returns what [read] builds from it.
Future<T> _read<T>(
  WidgetTester tester,
  T Function(AppLocalizations l10n, ChangeHistoryFormats formats, WidgetRef ref)
  read,
) async {
  late T value;
  await tester.pumpWidget(
    historyRowApp(
      Consumer(
        builder: (context, ref, _) {
          value = read(
            AppLocalizations.of(context)!,
            ChangeHistoryFormats.of(context),
            ref,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return value;
}

GovernedPart _part(
  GovernedEntity entity,
  GovernedChangeKind change, {
  List<String> fields = const [],
  String? name,
}) => GovernedPart(
  entity: entity,
  change: change,
  fields: fields,
  subjectName: name,
);

/// intl separates "9:00" and "AM" with a narrow no-break space.
String? _plainSpaces(String? s) => s?.replaceAll('\u202f', ' ');

void main() {
  testWidgets('actor name falls back to the role when it is missing (E-2)', (
    tester,
  ) async {
    final names = await _read(
      tester,
      (l10n, _, _) => [
        changeHistoryActorName(
          l10n,
          const Actor(
            uid: 't',
            role: ActorRole.tutor,
            displayName: 'Rav Cohen',
          ),
        ),
        changeHistoryActorName(
          l10n,
          const Actor(uid: 't', role: ActorRole.tutor, displayName: '  '),
        ),
        changeHistoryRoleLabel(l10n, ActorRole.child),
        changeHistoryRoleLabel(l10n, ActorRole.parent),
      ],
    );
    expect(names, ['Rav Cohen', 'Tutor', 'Child', 'Parent']);
  });

  testWidgets('governed parts read in plain words from entity and fields', (
    tester,
  ) async {
    final sentences = await _read(
      tester,
      (l10n, formats, _) => [
        for (final part in [
          GovernedPart(
            entity: GovernedEntity.goal,
            change: GovernedChangeKind.updated,
            fields: const ['target_date'],
            newDate: '2026-11-03',
          ),
          _part(GovernedEntity.goal, GovernedChangeKind.created),
          _part(GovernedEntity.goal, GovernedChangeKind.removed),
          _part(
            GovernedEntity.subTrack,
            GovernedChangeKind.created,
            name: 'Rebbe track',
          ),
          _part(GovernedEntity.subTrack, GovernedChangeKind.removed),
          _part(
            GovernedEntity.subTrack,
            GovernedChangeKind.updated,
            name: 'Rebbe track',
            fields: const ['window_end', 'window_start', 'rate_per_week'],
          ),
          _part(GovernedEntity.mainTrack, GovernedChangeKind.updated),
          _part(GovernedEntity.mainTrackStudyDays, GovernedChangeKind.updated),
          _part(
            GovernedEntity.learnerSettings,
            GovernedChangeKind.updated,
            fields: const ['latitude', 'longitude', 'time_zone'],
          ),
        ])
          governedPartSentence(l10n, formats, part),
      ],
    );
    expect(sentences, [
      'Changed the deadline to Nov 3',
      'Set a goal',
      'Removed the goal',
      'Added Rebbe track',
      'Removed a sub-track',
      'Changed Rebbe track: dates, pace',
      'Changed the main track',
      'Changed the study days',
      'Changed learner settings: location, time zone',
    ]);
    for (final s in sentences) {
      expect(s, isNot(contains('_')), reason: 'no raw field names: $s');
    }
  });

  testWidgets('an undo reads "Reverted change: …" (AC-4)', (tester) async {
    final sentence = await _read(
      tester,
      (l10n, formats, ref) => changeHistorySentence(
        l10n,
        formats,
        ref,
        governedHistoryRow(isRevert: true),
      ),
    );
    expect(sentence, 'Reverted change: Changed the deadline to Nov 3');
  });

  testWidgets('learning names its refs and source; a range shows its ends '
      'and count', (tester) async {
    final sentences = await _read(
      tester,
      (l10n, formats, ref) => [
        changeHistorySentence(l10n, formats, ref, learningHistoryRow()),
        changeHistorySentence(
          l10n,
          formats,
          ref,
          learningHistoryRow(
            refs: const ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
          ),
        ),
        changeHistorySentence(
          l10n,
          formats,
          ref,
          learningHistoryRow(
            refs: const [
              'Mishnah Berakhot 1:1',
              'Mishnah Berakhot 1:2',
              'Mishnah Berakhot 1:3',
            ],
          ),
        ),
        changeHistorySentence(
          l10n,
          formats,
          ref,
          learningHistoryRow(kind: LearningEventKind.void_, refs: const []),
        ),
        changeHistorySentence(
          l10n,
          formats,
          ref,
          learningHistoryRow(
            kind: LearningEventKind.void_,
            refs: const ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
            source: const SeveralSources(),
          ),
        ),
      ],
    );
    expect(sentences, [
      'Learned Berakhot 1:1 · Main track',
      'Learned Berakhot 1:1, Berakhot 1:2 · Main track',
      'Learned Berakhot 1:1 – Berakhot 1:3 (3) · Main track',
      'Removed an earlier learning record',
      'Removed Berakhot 1:1, Berakhot 1:2 · Several tracks',
    ]);
  });

  testWidgets('date-state tags: catch-up, before tracking, and a learnt '
      'day other than the recorded one', (tester) async {
    final tags = await _read(
      tester,
      (l10n, formats, _) => [
        changeHistoryDateTag(
          l10n,
          formats,
          learningHistoryRow(dateState: DateState.catchUp),
        ),
        changeHistoryDateTag(
          l10n,
          formats,
          learningHistoryRow(dateState: DateState.beforeTracking),
        ),
        changeHistoryDateTag(
          l10n,
          formats,
          learningHistoryRow(learnedOn: '2026-10-30'),
        ),
        changeHistoryDateTag(l10n, formats, learningHistoryRow()),
        changeHistoryDateTag(l10n, formats, governedHistoryRow()),
      ],
    );
    expect(tags, ['catch-up', 'Before tracking', 'Oct 30', null, null]);
  });

  testWidgets('a voided record says who removed it and when (E-3)', (
    tester,
  ) async {
    final lines = await _read(
      tester,
      (l10n, formats, _) => [
        changeHistoryVoidedText(
          l10n,
          formats,
          learningHistoryRow(voidedBy: historyRowParentStamp, voidedCount: 1),
        ),
        changeHistoryVoidedText(
          l10n,
          formats,
          learningHistoryRow(
            refs: const ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
            voidedBy: historyRowParentStamp,
            voidedCount: 1,
          ),
        ),
        changeHistoryVoidedText(l10n, formats, learningHistoryRow()),
      ].map(_plainSpaces).toList(),
    );
    expect(lines[0], 'Removed by Abba · Mon, Nov 2 · 9:00 AM');
    expect(lines[1], '1 of 2 removed by Abba · Mon, Nov 2 · 9:00 AM');
    expect(lines[2], isNull);
  });
}
