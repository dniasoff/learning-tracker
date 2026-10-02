/// The siyum unit-scope vocabulary per curriculum (the words the siyum
/// granularity labels and the legacy ledger writers use): which hierarchy
/// level names a siyum unit and what that level is called.
///
/// Moved here from the retired siyum detection service (DNI-474): the
/// engine now owns completion (`CurriculumState.completedUnits`); these are
/// only labels.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Resolve the [entryScope] string written to `learning_ledger` for a given
/// [curriculum] and hierarchy [level].
///
/// F2 (W7-A): hardcoded `'masechta'`/`'seder'` strings broke unit-level siyum
/// detection for every curriculum except Mishnayos/Bavli/Yerushalmi. The
/// returned values must match the unit-scope whitelist used by
/// `_detectMilestones` (`{'masechta', 'sefer', 'siman', 'hilchos'}`) for level
/// 2 detection, and the aggregate-scope set (`{'seder', 'chelek', 'sefer'}`)
/// for level 1.
///
///   - `level == 2` (used when the content has a non-null `level2` AND
///     [hasNamedLevel2Unit] says that value names a real unit — see below):
///       * `mishnayos`, `bavli`, `yerushalmi` → `'masechta'`
///       * `mishnaBerurah`                    → `'siman'`
///       * `mishnehTorah`                     → `'hilchos'`
///   - `level == 1` (level-1-only curricula, or aggregate fallback):
///       * `mishnayos`, `bavli`, `yerushalmi` → `'seder'`
///       * `mishnaBerurah`                    → `'chelek'`
///       * `mishnehTorah`, `chumash`, `nach`, `tanach`, `mussar` → `'sefer'`
String unitScopeFor(CurriculumId curriculum, {required int level}) {
  if (level == 2) {
    switch (curriculum) {
      case CurriculumId.mishnayos:
      case CurriculumId.bavli:
      case CurriculumId.yerushalmi:
        return 'masechta';
      case CurriculumId.mishnaBerurah:
        return 'siman';
      case CurriculumId.mishnehTorah:
        return 'hilchos';
      case CurriculumId.chumash:
      case CurriculumId.nach:
      case CurriculumId.tanach:
      case CurriculumId.mussar:
        // P0 (false "Chumash complete!" siyum at 61.6% actual completion):
        // this branch used to be reached with the comment "these curricula
        // have no level-2 in their content data" — that was false. The
        // shipped assets (assets/content/hierarchy/{chumash,nach,mussar}
        // .json) DO carry a level-2 on ~97-99% of leaves: it is the chapter/
        // perek number (e.g. '1'), a bare POSITIONAL label, not a uniquely-
        // named unit like a masechta. Two different sefarim both have a
        // chapter '1', so recording it as `unitIdentifier` without
        // ancestor-qualifying it first collided across sefarim once
        // aggregated in `_detectMilestones` (journey_providers.dart),
        // corrupting the total-units denominator and firing a curriculum-
        // complete milestone after only 3 of 5 sefarim were done.
        //
        // Per product decision, a Chumash/Nach/Tanach/Mussar chapter is NOT
        // its own siyum tier — only the sefer (checked at level 1 below) is.
        // the legacy siyum detector gated the
        // level-2 branch on [hasNamedLevel2Unit], which is false for these
        // four curricula, so this case is never actually reached; it is
        // kept only so the switch stays exhaustive. If a future change
        // wants real per-chapter siyumim, do NOT return a bare chapter
        // number here — ancestor-qualify it first (e.g. `'$level1:$level2'`
        // or similar), mirroring `scopeUnitIdentifier()` in
        // `core/content/content_grouping.dart`, the codebase's existing
        // pattern for this exact sibling-id-collision class.
        return 'masechta';
    }
  }
  // level == 1 (aggregate / level-1-only curricula).
  switch (curriculum) {
    case CurriculumId.mishnayos:
    case CurriculumId.bavli:
    case CurriculumId.yerushalmi:
      return 'seder';
    case CurriculumId.mishnaBerurah:
      return 'chelek';
    case CurriculumId.mishnehTorah:
    case CurriculumId.chumash:
    case CurriculumId.nach:
    case CurriculumId.tanach:
    case CurriculumId.mussar:
      return 'sefer';
  }
}

/// Whether [curriculum]'s level-2 hierarchy value names a real, uniquely-
/// identified siyum unit (a masechta / siman / hilchos) rather than a bare
/// positional label (a chapter/perek number that repeats across sefarim).
///
/// - Mishnayos / Bavli / Yerushalmi / Mishna Berurah / Mishneh Torah: `true`
///   — level-2 IS the masechta/siman/hilchos name, already unique within the
///   curriculum.
/// - Chumash / Nach / Tanach / Mussar: `false` — level-2 is a bare chapter
///   number (e.g. `'1'`), NOT unique across sefarim (Genesis ch. 1 and
///   Shemos ch. 1 both read `'1'`). See [unitScopeFor]'s level-2 doc comment
///   for the P0 this caused when it was treated as a unit identifier.
///
/// The legacy siyum detector used this to skip
/// the level-2 (chapter) check entirely for these four curricula — a
/// chapter is not its own siyum tier here by product decision, so the
/// collision is avoided by never producing the identifier, rather than by
/// trying to qualify it after the fact.
bool hasNamedLevel2Unit(CurriculumId curriculum) {
  switch (curriculum) {
    case CurriculumId.mishnayos:
    case CurriculumId.bavli:
    case CurriculumId.yerushalmi:
    case CurriculumId.mishnaBerurah:
    case CurriculumId.mishnehTorah:
      return true;
    case CurriculumId.chumash:
    case CurriculumId.nach:
    case CurriculumId.tanach:
    case CurriculumId.mussar:
      return false;
  }
}
