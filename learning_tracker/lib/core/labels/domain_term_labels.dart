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
/// provider-side [Ref] closures; the [_DomainTermLabels] object is cheap to
/// construct and is not cached across rebuilds.
_DomainTermLabels domainTermLabels(WidgetRef ref) =>
    _DomainTermLabels(ref.watch(useHebrewTermsProvider));

/// Variant for use from inside provider / notifier closures where the
/// parameter is a provider-side [Ref].
_DomainTermLabels domainTermLabelsFromRef(Ref ref) =>
    _DomainTermLabels(ref.watch(useHebrewTermsProvider));

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
class _DomainTermLabels {
  const _DomainTermLabels(this._useHebrew);

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
  String get chazara =>
      _useHebrew ? HebrewTerms.uiChazara : 'Chazara';

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

  /// Reverse of [HebrewTerms.stageNameMap]: Hebrew → English.
  static final Map<String, String> _hebrewToEnglish = {
    for (final entry in HebrewTerms.stageNameMap.entries)
      entry.value: entry.key,
  };
}
