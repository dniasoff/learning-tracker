// Mirror test for `lib/features/progress/domain/siyum_unit_scope.dart`
// (moved from the retired siyum detection service, DNI-474).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/domain/siyum_unit_scope.dart';

void main() {
  test('level-2 unit scopes name the named unit per curriculum', () {
    expect(unitScopeFor(CurriculumId.mishnayos, level: 2), 'masechta');
    expect(unitScopeFor(CurriculumId.mishnaBerurah, level: 2), 'siman');
    expect(unitScopeFor(CurriculumId.mishnehTorah, level: 2), 'hilchos');
  });

  test('level-1 scopes are the aggregate / sefer words', () {
    expect(unitScopeFor(CurriculumId.mishnayos, level: 1), 'seder');
    expect(unitScopeFor(CurriculumId.mishnaBerurah, level: 1), 'chelek');
    expect(unitScopeFor(CurriculumId.chumash, level: 1), 'sefer');
  });

  test('only curricula whose level 2 names a unit have one', () {
    expect(hasNamedLevel2Unit(CurriculumId.mishnayos), isTrue);
    expect(hasNamedLevel2Unit(CurriculumId.bavli), isTrue);
    expect(hasNamedLevel2Unit(CurriculumId.chumash), isFalse);
    expect(hasNamedLevel2Unit(CurriculumId.tanach), isFalse);
  });
}
