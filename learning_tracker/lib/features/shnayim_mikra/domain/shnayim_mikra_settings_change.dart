import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';

/// Parent edit of the learner's Shnayim Mikra workflow preferences.
final class ShnayimMikraSettingsEdit {
  const ShnayimMikraSettingsEdit({this.mode, this.pace, this.source});

  final ShnayimMikraMode? mode;
  final ShnayimMikraPace? pace;
  final ShnayimMikraSource? source;

  bool get isEmpty => mode == null && pace == null && source == null;
}

/// Creates the single governed learner-settings write for Shnayim Mikra.
///
/// The standard learnerSettings change-log actor/rules govern this edit. The
/// Firestore rules accept only a parent actor for this entity; child sessions
/// can read their assigned preferences and complete learning events.
GovernedAction shnayimMikraSettingsAction(
  String profileId,
  ShnayimMikraSettingsEdit edit,
) {
  if (edit.isEmpty) {
    throw ArgumentError.value(edit, 'edit', 'changes nothing');
  }
  LearnerSettings(
    profileId: profileId,
    timeZone: 'UTC',
    shnayimMikraMode: edit.mode ?? ShnayimMikraMode.pasuk,
    shnayimMikraPace: edit.pace ?? ShnayimMikraPace.self,
    shnayimMikraSource: edit.source ?? ShnayimMikraSource.onkelos,
  ).toStorage();

  return GovernedAction([
    GovernedEntityChange(
      entity: GovernedEntity.learnerSettings,
      entityId: profileId,
      docs: [
        GovernedDocPatch(
          collection: GovernedEntity.learnerSettings.collection,
          docId: profileId,
          mode: DocMode.update,
          fields: {
            if (edit.mode != null)
              LearnerSettings.kShnayimMikraMode: edit.mode!.storageKey,
            if (edit.pace != null)
              LearnerSettings.kShnayimMikraPace: edit.pace!.storageKey,
            if (edit.source != null)
              LearnerSettings.kShnayimMikraSource: edit.source!.storageKey,
          },
        ),
      ],
    ),
  ]);
}
