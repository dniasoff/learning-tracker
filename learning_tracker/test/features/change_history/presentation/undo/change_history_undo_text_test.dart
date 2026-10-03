/// DNI-514 T5: the undo copy — field labels, "changed since by <actor>"
/// lines and the snackbar text of each outcome (AC-1, AC-3, AC-8, AC-9).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/change_history/presentation/undo/change_history_undo_text.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/learner_state_fixtures.dart';

const _rav = Actor(uid: 'rav', role: ActorRole.tutor, displayName: 'Rav Cohen');
const _nameless = Actor(uid: '', role: ActorRole.parent, displayName: '');
const _deadline = ChangedFieldKey('goals', 'g', 'target_date');
const _goalType = ChangedFieldKey('goals', 'g', 'goal_type');
const _ground = ChangedFieldKey('sub_tracks', ulidA, 'ground');

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final he = lookupAppLocalizations(const Locale('he'));

  test('field labels name the field, else the entity', () {
    expect(undoFieldLabel(en, _deadline), 'Deadline');
    expect(undoFieldLabel(en, _goalType), 'Goal');
    expect(undoFieldLabel(en, _ground), 'Sub-track ground');
    expect(
      undoFieldLabel(en, const ChangedFieldKey('sub_tracks', ulidA, 'name')),
      'Sub-track name',
    );
    expect(
      undoFieldLabel(
        en,
        const ChangedFieldKey('track_learning_order', 'o', 'user_sort_order'),
      ),
      'Learning order',
    );
    expect(
      undoFieldLabel(
        en,
        const ChangedFieldKey('learner_profiles', profileUlid, 'time_zone'),
      ),
      'Location and time zone',
    );
    expect(undoFieldLabel(he, _deadline), isNotEmpty);
  });

  test('AC-3: one line per label and actor, e.g. "Deadline — changed since '
      'by Rav Cohen"; an unknown actor is left out', () {
    expect(
      changedSinceLines(en, const [
        ChangedSinceField(_deadline, _rav),
        ChangedSinceField(_goalType, _rav),
        ChangedSinceField(_ground, _nameless),
      ]),
      [
        'Deadline — changed since by Rav Cohen',
        'Goal — changed since by Rav Cohen',
        'Sub-track ground — changed since',
      ],
    );
  });

  test('the snackbar text of each outcome', () {
    expect(undoOutcomeMessage(en, const UndoApplied()), 'Change undone');
    expect(
      undoOutcomeMessage(
        en,
        const UndoApplied(changedSince: [ChangedSinceField(_deadline, _rav)]),
      ),
      'Undone, except: Deadline — changed since by Rav Cohen',
    );
    const nothing = UndoNothingToUndo([ChangedSinceField(_deadline, _rav)]);
    expect(undoOutcomeMessage(en, nothing), 'Nothing to undo — changed since');
    expect(undoOutcomeDetails(en, nothing), [
      'Deadline — changed since by Rav Cohen',
    ]);
    expect(
      undoOutcomeMessage(en, const UndoOnlineRequired()),
      'Online required',
    );
    expect(undoOutcomeMessage(en, const UndoNotSaved()), isNull);
    expect(
      undoOutcomeMessage(en, UndoLocked(LockWindow(t0, t1))),
      en.captureLockedNotice,
    );
    expect(
      undoOutcomeMessage(en, const UndoRefused(CaptureRejection.undoIsFinal)),
      "This change can't be undone",
    );
    expect(undoOutcomeDetails(en, const UndoApplied()), isEmpty);
  });
}
