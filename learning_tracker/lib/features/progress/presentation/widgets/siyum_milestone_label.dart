import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

/// Resolve a localized label for a curriculum-complete milestone.
///
/// Centralised so the screen never spells out the curriculum→label mapping
/// inline. The mapping mirrors the table in `docs/planning/progress-ia-redesign.md`
/// §4.
String curriculumCompleteSiyumLabel({
  required CurriculumId curriculumId,
  required DomainTermLabels terms,
}) {
  switch (curriculumId) {
    case CurriculumId.bavli:
      return terms.siyumHaShas;
    case CurriculumId.yerushalmi:
      return terms.siyumHaYerushalmi;
    case CurriculumId.mishnayos:
      return terms.siyumHaMishnayos;
    case CurriculumId.chumash:
      return terms.siyumHaTorah;
    case CurriculumId.nach:
      return terms.siyumNach;
    case CurriculumId.tanach:
      return terms.siyumTanach;
    case CurriculumId.mishnaBerurah:
      return terms.siyumMishnaBerurah;
    case CurriculumId.mishnehTorah:
      return terms.siyumMishnehTorah;
    case CurriculumId.mussar:
      return terms.siyumMussar;
  }
}

/// Resolve a localized label for an aggregate-level milestone (seder/chelek).
///
/// [aggregateName] is the level-1 key for the aggregate — either the raw
/// content-data key (e.g. `'Seder Zeraim'`) or a variant-resolved display
/// name.  When the key already contains the level word (Bavli / Mishnayos /
/// Yerushalmi store level-1 as `'Seder Zeraim'`, `'Seder Moed'`, etc.),
/// the leading `'Seder '` prefix is stripped before framing the label so the
/// composed string does not duplicate the word ("Siyum Seder Seder Zeraim"
/// → "Siyum Seder Zeraim").  A bare key (e.g. `'Zeraim'`) is passed through
/// unchanged.
String aggregateSiyumLabel({
  required CurriculumId curriculumId,
  required String aggregateName,
  required DomainTermLabels terms,
}) {
  // Mishnayos / Bavli / Yerushalmi use the "Seder" prefix.
  // Mishna Berurah / Mishneh Torah use "Chelek" if they ever expose an
  // aggregate tier — none do today, but the helper keeps the option open.
  switch (curriculumId) {
    case CurriculumId.mishnaBerurah:
    case CurriculumId.mishnehTorah:
      return '${terms.siyumChelek} $aggregateName';
    case CurriculumId.bavli:
    case CurriculumId.yerushalmi:
    case CurriculumId.mishnayos:
    case CurriculumId.chumash:
    case CurriculumId.nach:
    case CurriculumId.tanach:
    case CurriculumId.mussar:
      // TS-12: strip the leading "Seder " level word when the content data
      // already embeds it in the key (e.g. "Seder Zeraim" → "Zeraim"), then
      // re-prepend through [terms.siyumSeder] so the label is always exactly
      // "Siyum Seder {name}" regardless of how the key was stored.
      final bare = aggregateName.startsWith('Seder ')
          ? aggregateName.substring('Seder '.length)
          : aggregateName;
      return '${terms.siyumSeder} $bare';
  }
}

/// Resolve a localized label for a unit-level milestone.
///
/// [unitName] is the raw unit key (e.g. masechta name); [unitScope] is the
/// ledger's entry scope which selects the per-scope template
/// (`siyumMasechta`, `siyumSefer`, `siyumSiman`, `siyumHilchos`).
String unitSiyumLabel({
  required String unitName,
  required String unitScope,
  required DomainTermLabels terms,
}) {
  switch (unitScope) {
    case 'masechta':
      return terms.siyumMasechta(unitName);
    case 'sefer':
      return terms.siyumSefer(unitName);
    case 'siman':
      return terms.siyumSiman(unitName);
    case 'hilchos':
      return terms.siyumHilchos(unitName);
    default:
      // Fall back to the generic "Siyum {name}" form for unknown scopes —
      // shouldn't happen, but the screen should never render an empty row.
      return '${terms.siyum} $unitName';
  }
}
