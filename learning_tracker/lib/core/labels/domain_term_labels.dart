import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';

/// Toggle-aware accessors for every Torah domain term controlled by the
/// "Hebrew Terms" setting.
///
/// Usage (in a [ConsumerWidget]):
/// ```dart
/// final terms = domainTermLabels(ref);
/// Text(terms.chazara)          // "Chazara"  or  "חזרה"
/// Text(terms.bubbleChazara)    // "CHAZARA"  or  "חזרה"
/// Text(terms.daf)              // "Daf"      or  "דף"
/// Text(terms.stageName(stage)) // "Learn" / "Chazara 1"  or  "לימוד" / "חזרה א׳"
/// ```
///
/// This is the **single point of access** for resolved domain terms in
/// `lib/core/`.  Feature widgets must read terms here — not by inlining the
/// `useHebrewTermsProvider` toggle check themselves.
///
/// The function may be called from both [WidgetRef] (widget layer) and
/// provider-side [Ref] closures; the [DomainTermLabels] object is cheap to
/// construct and is not cached across rebuilds.
DomainTermLabels domainTermLabels(WidgetRef ref) =>
    DomainTermLabels(ref.watch(useHebrewTermsProvider));

/// Variant for use from inside provider / notifier closures where the
/// parameter is a provider-side [Ref].
DomainTermLabels domainTermLabelsFromRef(Ref ref) =>
    DomainTermLabels(ref.watch(useHebrewTermsProvider));

/// Resolved domain term strings for the current Hebrew Terms toggle state.
///
/// All strings come from one of two authoritative sources:
///   - Hebrew mode  → [HebrewTerms] constants (the `ui*` fields).
///   - English mode → the caller supplies the ARB-derived transliteration
///     (passed in at construction time via [_useHebrew]).
///
/// The ARB keys for each term are documented next to the corresponding field
/// so the connection between this class, the constants file, and the ARBs is
/// traceable in one place.
class DomainTermLabels {
  const DomainTermLabels(this._useHebrew);

  final bool _useHebrew;

  /// Whether the Hebrew Terms toggle is currently on.
  ///
  /// Exposed so call sites that must forward a [bool] to existing core APIs
  /// (e.g. [CurriculumLabelRenderer.renderBreadcrumb], [CurriculumLabels])
  /// can do so without re-reading [useHebrewTermsProvider] directly.
  bool get isHebrew => _useHebrew;

  // ── Chazara / Review ─────────────────────────────────────────────────────

  /// "Chazara" (review concept).
  /// ARB en: termChazara  |  he: termChazara
  String get chazara => _useHebrew ? HebrewTerms.uiChazara : 'Chazara';

  /// "CHAZARA" — all-caps bubble label.
  /// ARB en: termBubbleChazara  |  he: termBubbleChazara
  ///
  /// Wires the previously-dead [HebrewTerms.uiBubbleChazara] constant to the
  /// toggle so bubble widgets can call `terms.bubbleChazara` and the bubble
  /// will switch live between "CHAZARA" and "חזרה".
  String get bubbleChazara =>
      _useHebrew ? HebrewTerms.uiBubbleChazara : 'CHAZARA';

  /// "REVIEW SECTION" header label.
  /// ARB en: termReviewSection  |  he: termReviewSection
  String get reviewSection =>
      _useHebrew ? HebrewTerms.uiReviewSection : 'REVIEW SECTION';

  // ── Structural Torah units ───────────────────────────────────────────────

  /// "Daf" (two-sided Talmud leaf).
  /// ARB en: termDaf  |  he: termDaf
  String get daf => _useHebrew ? HebrewTerms.uiDaf : 'Daf';

  /// "Amud" (one side of a Talmud daf).
  /// ARB en: termAmud  |  he: termAmud
  String get amud => _useHebrew ? HebrewTerms.uiAmud : 'Amud';

  /// "Perek" (chapter).
  /// ARB en: termPerek  |  he: termPerek
  String get perek => _useHebrew ? HebrewTerms.uiPerek : 'Perek';

  /// "Mishna" (a single mishna within a perek).
  /// ARB en: termMishnah  |  he: termMishnah
  String get mishnah => _useHebrew ? HebrewTerms.uiMishnah : 'Mishna';

  /// "Seder" (order of Mishnah / Talmud).
  /// ARB en: termSeder  |  he: termSeder
  String get seder => _useHebrew ? HebrewTerms.uiSeder : 'Seder';

  /// "Masechta" (tractate).
  /// ARB en: termMasechta  |  he: termMasechta
  String get masechta => _useHebrew ? HebrewTerms.uiMasechta : 'Masechta';

  /// "Chumash" (one of the five books of Torah).
  /// ARB en: termChumash  |  he: termChumash
  String get chumash => _useHebrew ? HebrewTerms.uiChumash : 'Chumash';

  // ── Scholar tier / honorific ─────────────────────────────────────────────

  /// "Talmid Chochom" — title-case.
  /// ARB en: termTalmidChochom  |  he: termTalmidChochom
  String get talmidChochom =>
      _useHebrew ? HebrewTerms.uiTalmidChochom : 'Talmid Chochom';

  /// "TALMID CHOCHOM" — all-caps.
  /// ARB en: termTalmidChochomCaps  |  he: termTalmidChochomCaps
  String get talmidChochomCaps =>
      _useHebrew ? HebrewTerms.uiTalmidChochom : 'TALMID CHOCHOM';

  // ── Stage name resolution (live, toggle-aware) ───────────────────────────
  //
  // Stage labels must be computed at render time from the current toggle so
  // they re-render live when the setting changes (§8 of hebrew-terms.md).

  /// Returns the display name for stage 0 ("Learn" / "לימוד").
  String get stageLearn =>
      _useHebrew ? HebrewTerms.stageLearn : HebrewTerms.stageLearnEn;

  /// Returns a numbered chazara stage name, 1-based.
  ///
  /// [roundNumber] 1 → "Chazara 1" / "חזרה א׳"
  /// [roundNumber] 2 → "Chazara 2" / "חזרה ב׳"
  String chazaraStage(int roundNumber) => _useHebrew
      ? HebrewTerms.getChazaraStageName(roundNumber)
      : HebrewTerms.getChazaraStageNameEn(roundNumber);

  /// Returns the display name for a stage by 0-based [stageIndex].
  ///
  /// Index 0 → "Learn" / "לימוד"
  /// Index 1 → "Chazara 1" / "חזרה א׳"
  /// Index 2 → "Chazara 2" / "חזרה ב׳"
  String stageName(int stageIndex) {
    if (stageIndex <= 0) return stageLearn;
    return chazaraStage(stageIndex);
  }

  /// Returns the display name for a DB-stored stage id (1-based).
  ///
  /// `stage_definitions.stage_order` and `completions.stage_id` both store
  /// 1-based stage numbers: 1 → Learn, 2 → Chazara 1, 3 → Chazara 2, …
  /// (see `stage_definition_repository_impl.dart` seed defaults). This is
  /// the right entry point for any screen that has a `stageId` int —
  /// e.g. the Completion History row.
  String stageNameFromStageId(int stageId) => stageName(stageId - 1);

  /// Resolves an existing stored stage name to the correct display form for
  /// the current toggle state.
  ///
  /// The stored name may be in Hebrew (as stored by [HebrewTerms]) or in
  /// English (legacy). This function looks the name up in [HebrewTerms.stageNameMap]
  /// to identify the canonical pair and returns the correct form.
  ///
  /// If the name is unrecognised (user-customised), it is returned unchanged —
  /// custom names are always displayed as-is regardless of the toggle.
  String resolveStoredStageName(String storedName) {
    if (_useHebrew) {
      // If already in Hebrew or maps to Hebrew, use HebrewTerms.
      final fromEnglish = HebrewTerms.stageNameMap[storedName];
      if (fromEnglish != null) return fromEnglish;
      // May already be a Hebrew value — check the reverse map.
      if (_hebrewToEnglish.containsKey(storedName)) return storedName;
      return storedName; // Custom name — keep as-is.
    } else {
      // English mode: if stored in Hebrew, convert back to English form.
      final toEnglish = _hebrewToEnglish[storedName];
      if (toEnglish != null) return toEnglish;
      // May already be English — check the forward map.
      if (HebrewTerms.stageNameMap.containsKey(storedName)) return storedName;
      return storedName; // Custom name — keep as-is.
    }
  }

  // Program-label resolution (per-LearningProgramData / per-CalendarProgramEntry)
  // lives in `features/scheduler/domain/labels/program_label_resolver.dart`.
  // `lib/core/` MUST NOT import `lib/features/` (Rule 1 / DNI-386), so
  // scheduler types stay on the feature side; the toggle source-of-truth
  // remains here via [isHebrew]. Scheduler callers read this boolean through
  // [ProgramLabelResolver] and apply it to their own types.

  // ── B1 three-tier vocabulary (canonical, toggle-aware) ───────────────────
  //
  // These fields expose the canonical "lean-hard Hebrew" vocabulary used by
  // the B1 three-tier completion-credit IA (engagement / achievement /
  // lifetime — see `docs/planning/progress-ia-redesign.md`).
  //
  // English-default: transliterated Latin form ("Siyum", "Chazara", "Limud").
  // Hebrew Terms ON: native Hebrew script ("סיום", "חזרה", "לימוד").
  //
  // The toggle controls **script**, not concept — irrespective of the
  // device's `Localizations.localeOf(context)`. Each field's ARB key is
  // documented next to it so the connection between this class and the
  // ARBs is traceable.

  /// Canonical "Limud" — initial study (stage 1) of one item.
  /// ARB en: limud  |  he: limud
  String get limud => _useHebrew ? 'לימוד' : 'Limud';

  /// Canonical "Chazaros" — plural of chazara (total review events).
  /// ARB en: chazaros  |  he: chazaros
  ///
  /// Distinct from [chazara] (singular). Use this in lifetime totals such
  /// as "1,200 total chazaros".
  String get chazaros => _useHebrew ? 'חזרות' : 'Chazaros';

  /// Canonical "Siyum" — finish-celebration of a whole unit.
  /// ARB en: siyum  |  he: siyum
  String get siyum => _useHebrew ? 'סיום' : 'Siyum';

  /// Canonical "Siyumim" — plural of siyum.
  /// ARB en: siyumim  |  he: siyumim
  String get siyumim => _useHebrew ? 'סיומים' : 'Siyumim';

  /// "{count} items learned" / "{count} פריטים נלמדו" — NEW sense: distinct
  /// items ever touched (lifetime tier). Distinct from the legacy
  /// `itemsLearnedTitle` screen-title key.
  /// ARB en: itemsLearnedCount  |  he: itemsLearnedCount
  String itemsLearnedCount(int count) =>
      _useHebrew ? '$count פריטים נלמדו' : '$count items learned';

  /// "{count} total chazaros" / "{count} חזרות סה״כ" — lifetime-tier total
  /// review count.
  /// ARB en: totalChazaros  |  he: totalChazaros
  String totalChazaros(int count) =>
      _useHebrew ? '$count חזרות סה״כ' : '$count total chazaros';

  // ── Per-curriculum siyum labels (toggle-aware) ───────────────────────────
  //
  // Top-level: curriculum complete. Mid-level: aggregate (seder/chelek).
  // Unit-level: masechta / sefer / siman / hilchos (parameterised).
  //
  // Each label is a fixed template — the Hebrew form is preferred when the
  // toggle is on, the Latin transliteration otherwise. These mirror the
  // ARB strings so screens that do not have a `BuildContext` (or want to
  // honour the toggle irrespective of device locale) can resolve them
  // through `DomainTermLabels` instead.

  /// "Siyum HaShas" / "סיום הש״ס" — curriculum complete: Bavli.
  /// ARB: siyumHaShas
  String get siyumHaShas => _useHebrew ? 'סיום הש״ס' : 'Siyum HaShas';

  /// "Siyum HaTorah" / "סיום התורה" — curriculum complete: Chumash.
  /// ARB: siyumHaTorah
  String get siyumHaTorah => _useHebrew ? 'סיום התורה' : 'Siyum HaTorah';

  /// "Siyum HaMishnayos" / "סיום המשניות" — curriculum complete: Mishnayos.
  /// ARB: siyumHaMishnayos
  String get siyumHaMishnayos =>
      _useHebrew ? 'סיום המשניות' : 'Siyum HaMishnayos';

  /// "Siyum HaYerushalmi" / "סיום הירושלמי" — curriculum complete: Yerushalmi.
  /// ARB: siyumHaYerushalmi
  String get siyumHaYerushalmi =>
      _useHebrew ? 'סיום הירושלמי' : 'Siyum HaYerushalmi';

  /// "Siyum Mishna Berurah" / "סיום משנה ברורה" — curriculum complete.
  /// ARB: siyumMishnaBerurah
  String get siyumMishnaBerurah =>
      _useHebrew ? 'סיום משנה ברורה' : 'Siyum Mishna Berurah';

  /// "Siyum Mishneh Torah" / "סיום משנה תורה" — curriculum complete: Rambam.
  /// ARB: siyumMishnehTorah
  String get siyumMishnehTorah =>
      _useHebrew ? 'סיום משנה תורה' : 'Siyum Mishneh Torah';

  /// "Siyum Nach" / "סיום נ״ך" — curriculum complete: Nach.
  /// ARB: siyumNach
  String get siyumNach => _useHebrew ? 'סיום נ״ך' : 'Siyum Nach';

  /// "Siyum Tanach" / "סיום תנ״ך" — curriculum complete: Tanach.
  /// ARB: siyumTanach
  String get siyumTanach => _useHebrew ? 'סיום תנ״ך' : 'Siyum Tanach';

  /// "Siyum Mussar" / "סיום מוסר" — curriculum complete: Mussar.
  /// ARB: siyumMussar
  String get siyumMussar => _useHebrew ? 'סיום מוסר' : 'Siyum Mussar';

  /// "Siyum Seder" / "סיום סדר" — mid-level aggregate siyum.
  /// ARB: siyumSeder
  String get siyumSeder => _useHebrew ? 'סיום סדר' : 'Siyum Seder';

  /// "Siyum Chelek" / "סיום חלק" — mid-level aggregate siyum.
  /// ARB: siyumChelek
  String get siyumChelek => _useHebrew ? 'סיום חלק' : 'Siyum Chelek';

  /// "Siyum Masechta {name}" / "סיום מסכת {name}" — unit-level siyum.
  /// ARB: siyumMasechta
  ///
  /// [name] is the masechta name as it should appear in the label (typically
  /// already in the locale-appropriate form — callers that want the masechta
  /// name itself rendered in Hebrew should resolve that through the
  /// curriculum label renderer first).
  String siyumMasechta(String name) =>
      _useHebrew ? 'סיום מסכת $name' : 'Siyum Masechta $name';

  /// "Siyum Sefer {name}" / "סיום ספר {name}" — unit-level siyum.
  /// ARB: siyumSefer
  String siyumSefer(String name) =>
      _useHebrew ? 'סיום ספר $name' : 'Siyum Sefer $name';

  /// "Siyum Siman {name}" / "סיום סימן {name}" — unit-level siyum.
  /// ARB: siyumSiman
  String siyumSiman(String name) =>
      _useHebrew ? 'סיום סימן $name' : 'Siyum Siman $name';

  /// "Siyum Hilchos {name}" / "סיום הלכות {name}" — unit-level siyum.
  /// ARB: siyumHilchos
  String siyumHilchos(String name) =>
      _useHebrew ? 'סיום הלכות $name' : 'Siyum Hilchos $name';

  /// Reverse of [HebrewTerms.stageNameMap]: Hebrew → English.
  static final Map<String, String> _hebrewToEnglish = {
    for (final entry in HebrewTerms.stageNameMap.entries)
      entry.value: entry.key,
  };
}
