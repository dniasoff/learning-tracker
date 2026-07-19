import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/track_blueprint_draft_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/track_blueprint_draft_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repo = TrackBlueprintDraftRepositoryImpl();

  setUp(() {
    // Clear SharedPreferences between each test.
    SharedPreferences.setMockInitialValues({});
  });

  // ── W4.13 regression suite ──────────────────────────────────────────────────
  group('TrackBlueprintDraftRepositoryImpl', () {
    test('loadDraft returns null when nothing is saved', () async {
      final draft = await repo.loadDraft();
      expect(draft, isNull);
    });

    test('saveDraft + loadDraft round-trips navStepIndex', () async {
      const draft = AddTrackDraft(navStepIndex: 3);
      await repo.saveDraft(draft);
      final loaded = await repo.loadDraft();
      expect(loaded, isNotNull);
      expect(loaded!.navStepIndex, 3);
    });

    test('saveDraft + loadDraft round-trips all nullable fields', () async {
      const draft = AddTrackDraft(
        navStepIndex: 2,
        curriculumKey: 'bavli',
        programId: 42,
        programName: 'Daf Yomi',
        trackLabel: 'My Track',
      );
      await repo.saveDraft(draft);
      final loaded = await repo.loadDraft();
      expect(loaded!.curriculumKey, 'bavli');
      expect(loaded.programId, 42);
      expect(loaded.programName, 'Daf Yomi');
      expect(loaded.trackLabel, 'My Track');
    });

    test('saveDraft + loadDraft round-trips studyDays map', () async {
      const draft = AddTrackDraft(
        navStepIndex: 4,
        studyDays: {1: 'study', 6: 'skip', 7: 'study'},
      );
      await repo.saveDraft(draft);
      final loaded = await repo.loadDraft();
      expect(loaded!.studyDays, {1: 'study', 6: 'skip', 7: 'study'});
    });

    test('saveDraft + loadDraft round-trips scopeSelectionsJson', () async {
      const json = '[{"level":1,"value":"Seder Zeraim"}]';
      const draft = AddTrackDraft(navStepIndex: 1, scopeSelectionsJson: json);
      await repo.saveDraft(draft);
      final loaded = await repo.loadDraft();
      expect(loaded!.scopeSelectionsJson, json);
    });

    test('clearDraft removes saved draft', () async {
      const draft = AddTrackDraft(navStepIndex: 5, curriculumKey: 'bavli');
      await repo.saveDraft(draft);
      await repo.clearDraft();
      final loaded = await repo.loadDraft();
      expect(loaded, isNull);
    });

    test('saveDraft is idempotent — overwrite with new values', () async {
      const draft1 = AddTrackDraft(navStepIndex: 0, curriculumKey: 'bavli');
      await repo.saveDraft(draft1);
      const draft2 = AddTrackDraft(navStepIndex: 2, curriculumKey: 'mishnayos');
      await repo.saveDraft(draft2);
      final loaded = await repo.loadDraft();
      expect(loaded!.navStepIndex, 2);
      expect(loaded.curriculumKey, 'mishnayos');
    });

    test('null optional fields do not overwrite existing stored values', () async {
      // Save a draft with a programId.
      const draft1 = AddTrackDraft(navStepIndex: 1, programId: 7);
      await repo.saveDraft(draft1);
      // Save again without programId — should NOT clear the stored programId.
      // (This is the current implementation behaviour: null fields are skipped.)
      const draft2 = AddTrackDraft(navStepIndex: 2);
      await repo.saveDraft(draft2);
      final loaded = await repo.loadDraft();
      // programId persists from the first save because draft2 didn't clear it.
      expect(loaded!.navStepIndex, 2);
      expect(loaded.programId, 7);
    });

    test('AddTrackDraft equality on matching fields', () {
      const a = AddTrackDraft(
        navStepIndex: 3,
        curriculumKey: 'bavli',
        programId: 1,
      );
      const b = AddTrackDraft(
        navStepIndex: 3,
        curriculumKey: 'bavli',
        programId: 1,
      );
      expect(a, b);
    });

    test('AddTrackDraft inequality on different navStepIndex', () {
      const a = AddTrackDraft(navStepIndex: 1);
      const b = AddTrackDraft(navStepIndex: 2);
      expect(a == b, isFalse);
    });

    // AUD-tracks-23 regression: the hand-rolled == on AddTrackDraft omitted
    // scopeSelectionsJson and studyDays entirely, so two drafts differing
    // only in one of those fields compared equal.
    test('AddTrackDraft inequality on different scopeSelectionsJson', () {
      const a = AddTrackDraft(
        navStepIndex: 1,
        scopeSelectionsJson: '[{"level":1,"value":"Seder Zeraim"}]',
      );
      const b = AddTrackDraft(
        navStepIndex: 1,
        scopeSelectionsJson: '[{"level":1,"value":"Seder Moed"}]',
      );
      expect(a == b, isFalse);
    });

    test('AddTrackDraft inequality on different studyDays', () {
      const a = AddTrackDraft(navStepIndex: 1, studyDays: {1: 'study'});
      const b = AddTrackDraft(navStepIndex: 1, studyDays: {1: 'skip'});
      expect(a == b, isFalse);
    });
  });
}
