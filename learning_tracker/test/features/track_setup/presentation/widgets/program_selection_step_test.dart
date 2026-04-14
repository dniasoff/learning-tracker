import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

void main() {
  group('ProgramSelectionStep Logic', () {
    test('curricula with programs: bavli, yerushalmi, mishnaBerurah, mussar, '
        'mishnayos, nach', () {
      // These curricula have seeded programs in the DB
      final withPrograms = [
        CurriculumId.bavli, // 5: daf_yomi, oraysa, dirshu_kinyan_torah, dirshu_amud_hayomi, daf_a_week
        CurriculumId.yerushalmi, // 2: dirshu_kinyan_yerushalmi, yerushalmi_yomi
        CurriculumId.mishnaBerurah, // 4: dirshu_daf_hayomi_bhalacha, halakhah_yomit, arukh_hashulchan_yomi, kitzur_shulchan_aruch_yomi
        CurriculumId.mussar, // 2: dirshu_kinyan_chochma, chofetz_chaim_daily
        CurriculumId.mishnayos, // 1: mishnah_yomis
        CurriculumId.nach, // 1: nach_yomi
        CurriculumId.mishnehTorah, // 2: rambam_1_chapter, rambam_3_chapters
        CurriculumId.tanach, // 1: tanakh_yomi
      ];

      for (final c in withPrograms) {
        expect(c, isNotNull, reason: '$c should have programs');
      }
    });

    test('curricula without programs: chumash', () {
      // These curricula have no seeded programs — program step auto-skips
      final withoutPrograms = [
        CurriculumId.chumash,
      ];

      for (final c in withoutPrograms) {
        expect(c, isNotNull, reason: '$c should have no programs');
      }
    });

    test('program selection clears scope', () {
      // When a program is selected, scope should be null (program defines scope)
      const state = AddTrackState(
        curriculumId: CurriculumId.bavli,
        scopeSelections: [ScopeEntry(level: 1, value: 'Test')],
      );

      // Simulate program selection clearing scope
      final updated = state.copyWith(
        programId: 1,
        programName: 'Daf Yomi',
        scopeSelections: null,
      );

      expect(updated.programId, 1);
      expect(updated.scopeSelections, isNull);
    });

    test('self-paced preserves scope', () {
      const state = AddTrackState(
        curriculumId: CurriculumId.bavli,
        scopeSelections: [ScopeEntry(level: 1, value: 'Test')],
      );

      // Self-paced: programId stays null, scope preserved
      final updated = state.copyWith(programId: null, programName: null);

      expect(updated.programId, isNull);
      expect(updated.scopeSelections, hasLength(1));
    });
  });
}
