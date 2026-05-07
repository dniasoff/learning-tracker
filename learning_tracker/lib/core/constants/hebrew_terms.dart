import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Central Hebrew terminology constants for domain-specific terms.
///
/// **In scope:** Stage names (chazara/review), curriculum display names.
/// **Not in scope:** UI labels (buttons, headers), general i18n.
class HebrewTerms {
  HebrewTerms._();

  // ── Stage Name Mappings ──────────────────────────────────────────────────

  /// Maps English default stage names to their Hebrew equivalents.
  ///
  /// Used by the migration to convert existing English defaults → Hebrew,
  /// and by helpers to look up the correct Hebrew term.
  static const Map<String, String> stageNameMap = {
    'Learn': 'לימוד',
    'Chazara 1': 'חזרה א׳',
    'Chazara 2': 'חזרה ב׳',
    'Chazara 3': 'חזרה ג׳',
    'Review': 'חזרה',
    'Review 1': 'חזרה א׳',
    'Review 2': 'חזרה ב׳',
    'Next-Day Review': 'חזרה יומית',
    'Weekly Review': 'חזרה שבועית',
    'Rolling Back-20': 'חזרה מחזורית',
    'Iyun': 'עיון',
    'Bekius': 'בקיאות',
  };

  /// All known English default stage names that the migration should convert.
  static const Set<String> knownEnglishDefaults = {
    'Learn',
    'Chazara 1',
    'Chazara 2',
    'Chazara 3',
    'Review',
    'Review 1',
    'Review 2',
    'Next-Day Review',
    'Weekly Review',
    'Rolling Back-20',
  };

  // ── Default Stage Names (Hebrew) ─────────────────────────────────────────

  /// Default stage name for the learning (first) stage.
  static const String stageLearn = 'לימוד';

  /// Default chazara stage name pattern.
  /// Use [getChazaraStageName] for numbered chazara stages.
  static const String stageChazaraPrefix = 'חזרה';

  // ── UI Term Display (Hebrew script variants) ─────────────────────────────
  //
  // Strings in this section are the *only* ones swapped by the
  // "Hebrew Terms" settings toggle (hebrewTermsScriptProvider).
  // The toggle is independent of the UI locale (en/he):
  //   ON  → use the Hebrew-script string defined here
  //   OFF → use the locale-driven ARB string (English transliteration in en)
  //
  // The toggle deliberately does NOT cover general UI labels such as
  // "Today's Missions", "No tasks in this lane", "URGENT", etc. Those follow
  // the app's locale only.
  //
  // To add a new term to the toggle:
  //   1. Add a `static const String uiXxx = 'עברית';` constant below.
  //   2. At the call site, swap with:
  //        ref.watch(hebrewTermsScriptProvider)
  //          ? HebrewTerms.uiXxx : l10n.xxx
  //   3. Add a row to the table below so the scope stays discoverable.
  //
  // ┌──────────────────────────┬────────────────────┬────────────────────┐
  // │ Constant                 │ Hebrew             │ ARB key (English)  │
  // ├──────────────────────────┼────────────────────┼────────────────────┤
  // │ uiChazaraReview          │ חזרה                │ chazaraReview      │
  // │ uiReviewSection          │ חזרה SECTION         │ reviewSection      │
  // │ uiBubbleChazara          │ חזרה                │ bubbleChazara      │
  // │ uiActiveTrackChazara     │ חזרה                │ activeTrackMetric… │
  // └──────────────────────────┴────────────────────┴────────────────────┘

  /// "Chazara/Review" → Hebrew script.
  static const String uiChazaraReview = 'חזרה';

  /// "REVIEW SECTION" header → Hebrew word + English "SECTION".
  static const String uiReviewSection = 'חזרה SECTION';

  /// "CHAZARA" bubble label → Hebrew script.
  static const String uiBubbleChazara = 'חזרה';

  /// Active-track "Chazara" metric label → Hebrew script.
  static const String uiActiveTrackChazara = 'חזרה';

  // ── Curriculum Display Names ─────────────────────────────────────────────

  /// Maps [CurriculumId.storageKey] to the Hebrew display name.
  ///
  /// These are identical to [CurriculumId.displayNameHe] but provided here
  /// as a flat map for use in migrations and non-enum contexts.
  static const Map<String, String> curriculumDisplayNames = {
    'mishnayos': 'משניות',
    'bavli': 'תלמוד בבלי',
    'yerushalmi': 'תלמוד ירושלמי',
    'chumash': 'חומש',
    'nach': 'נ"ך',
    'tanach': 'תנ"ך',
    'mishna_berurah': 'משנה ברורה',
    'mussar': 'מוסר',
    'mishneh_torah': 'משנה תורה',
  };

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns the Hebrew display name for [id].
  ///
  /// Delegates to [CurriculumId.displayNameHe] — this wrapper exists so
  /// callers that only have an enum value don't need to know which getter
  /// to use.
  static String getCurriculumDisplayName(CurriculumId id) => id.displayNameHe;

  /// Returns the Hebrew stage name for a 0-based [stageIndex].
  ///
  /// Index 0 → "לימוד", index 1 → "חזרה א׳", index 2 → "חזרה ב׳", etc.
  static String getDefaultStageName(int stageIndex) {
    if (stageIndex <= 0) return stageLearn;
    return getChazaraStageName(stageIndex);
  }

  /// Returns a numbered chazara stage name in Hebrew.
  ///
  /// [roundNumber] is 1-based: 1 → "חזרה א׳", 2 → "חזרה ב׳", etc.
  static String getChazaraStageName(int roundNumber) {
    const hebrewNumerals = ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳'];
    if (roundNumber >= 1 && roundNumber <= hebrewNumerals.length) {
      return '$stageChazaraPrefix ${hebrewNumerals[roundNumber - 1]}';
    }
    // Fallback for numbers beyond 5.
    return '$stageChazaraPrefix $roundNumber';
  }

  /// Converts an English default stage name to Hebrew, if it matches a known
  /// default. Returns [null] if the name is user-customized (not a default).
  static String? toHebrew(String englishName) => stageNameMap[englishName];
}
