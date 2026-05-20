import 'dart:convert';

import 'package:learning_tracker/features/tracks/setup/domain/repositories/track_blueprint_draft_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Storage keys ──────────────────────────────────────────────────────────────

/// Prefix for all AddTrack-draft keys so they can be cleared in a single pass
/// without hard-coding a list of individual keys. Each key follows the pattern
/// `_kPrefix<Field>`.
const _kPrefix = 'add_track_draft_';

const _kStep = '${_kPrefix}step';
const _kCurriculum = '${_kPrefix}curriculum';
const _kScope = '${_kPrefix}scope';
const _kProgram = '${_kPrefix}program';
const _kProgramName = '${_kPrefix}program_name';
const _kStudyDays = '${_kPrefix}study_days';
const _kLabel = '${_kPrefix}label';

/// All known keys — used by [clearDraft] to remove every key in one loop.
const _allKeys = [
  _kStep,
  _kCurriculum,
  _kScope,
  _kProgram,
  _kProgramName,
  _kStudyDays,
  _kLabel,
];

// ── Implementation ────────────────────────────────────────────────────────────

/// [TrackBlueprintDraftRepository] backed by [SharedPreferences].
///
/// Replaces the 7 ad-hoc SharedPreferences writes scattered through
/// [AddTrackController] with a single, testable repository boundary.
///
/// ### Key naming
/// All keys share the `add_track_draft_` prefix so callers can distinguish
/// draft storage from other SharedPreferences keys without inspecting values.
///
/// ### Serialization
/// * Primitives (int, String) map directly to SharedPreferences get/setInt/String.
/// * [AddTrackDraft.studyDays] is serialised as JSON: the int weekday key is
///   encoded as a String because SharedPreferences maps must have String keys.
/// * [AddTrackDraft.scopeSelectionsJson] is already a JSON string (the
///   encoding is done by the caller).
class TrackBlueprintDraftRepositoryImpl
    implements TrackBlueprintDraftRepository {
  const TrackBlueprintDraftRepositoryImpl();

  @override
  Future<void> saveDraft(AddTrackDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStep, draft.navStepIndex);

    if (draft.curriculumKey != null) {
      await prefs.setString(_kCurriculum, draft.curriculumKey!);
    }
    if (draft.scopeSelectionsJson != null) {
      await prefs.setString(_kScope, draft.scopeSelectionsJson!);
    }
    if (draft.programId != null) {
      await prefs.setInt(_kProgram, draft.programId!);
    }
    if (draft.programName != null) {
      await prefs.setString(_kProgramName, draft.programName!);
    }
    if (draft.studyDays != null) {
      await prefs.setString(
        _kStudyDays,
        jsonEncode(draft.studyDays!.map((k, v) => MapEntry(k.toString(), v))),
      );
    }
    if (draft.trackLabel != null) {
      await prefs.setString(_kLabel, draft.trackLabel!);
    }
  }

  @override
  Future<AddTrackDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final stepIndex = prefs.getInt(_kStep);
    if (stepIndex == null) return null; // No draft saved.

    final curriculumKey = prefs.getString(_kCurriculum);
    final scopeJson = prefs.getString(_kScope);
    final programId = prefs.getInt(_kProgram);
    final programName = prefs.getString(_kProgramName);
    final studyDaysJson = prefs.getString(_kStudyDays);
    final trackLabel = prefs.getString(_kLabel);

    Map<int, String>? studyDays;
    if (studyDaysJson != null) {
      final raw = jsonDecode(studyDaysJson) as Map<String, dynamic>;
      studyDays = raw.map((k, v) => MapEntry(int.parse(k), v as String));
    }

    return AddTrackDraft(
      navStepIndex: stepIndex,
      curriculumKey: curriculumKey,
      scopeSelectionsJson: scopeJson,
      programId: programId,
      programName: programName,
      studyDays: studyDays,
      trackLabel: trackLabel,
    );
  }

  @override
  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _allKeys) {
      await prefs.remove(key);
    }
  }
}
