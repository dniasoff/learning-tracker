import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Defines subset → superset relationships between curricula.
///
/// A completion recorded under a subset curriculum (e.g. [CurriculumId.chumash])
/// also counts toward any superset listed here (e.g. [CurriculumId.tanach]).
///
/// **Reading direction:** the key is the *subset*; the value set contains the
/// *supersets*. For example, `chumash → {tanach}` means every Chumash ref
/// completed is also credited to Tanach.
///
/// Rule: **subset completions propagate UP to supersets** only.  A Tanach
/// completion does NOT automatically count toward Chumash.
const Map<CurriculumId, Set<CurriculumId>> kCurriculumSupersets = {
  CurriculumId.chumash: {CurriculumId.tanach},
  CurriculumId.nach: {CurriculumId.tanach},
};

/// Returns the set of *subset* curricula whose completions should be merged
/// into [curriculum] when computing its learned-ref count.
///
/// For [CurriculumId.tanach] this returns `{chumash, nach}`.
/// For all other curricula this returns an empty set.
Set<CurriculumId> subsetsOf(CurriculumId curriculum) {
  return kCurriculumSupersets.entries
      .where((e) => e.value.contains(curriculum))
      .map((e) => e.key)
      .toSet();
}
