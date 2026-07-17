/// Canonical DB-stored sentinel for the "Learn" stage's Hebrew name
/// (AUD-onboarding-14).
///
/// [DomainTermLabels.resolveStoredStageName] matches this exact literal via
/// [HebrewTerms.stageNameMap] to resolve the correct localized stage name at
/// render time — it is load-bearing, not decorative. Every write site that
/// creates the "Learn" stage row must reference this constant rather than
/// retyping the literal, so a typo can never silently desync one write path
/// from the lookup.
///
/// Exposed as a bare top-level constant (equal to [HebrewTerms.stageLearn])
/// rather than requiring callers to write `HebrewTerms.stageLearn` directly,
/// because audit check 13 (docs/coding-standards.md, "Hebrew Terms and
/// domainTermLabels") forbids any `HebrewTerms.` reference inside
/// `lib/features/` — this constant is the sanctioned way for feature-layer
/// stage-creation code to reach the same value.
const kLimudStageName = HebrewTerms.stageLearn;

/// Central Hebrew terminology constants for domain-specific terms.
///
/// **In scope:** Stage names (chazara/review), domain term constants,
/// curriculum helpers.
/// **Not in scope:** UI labels (buttons, headers), general i18n.
///
/// ## Toggle pattern
///
/// Every domain term has:
///   - A `uiXxx` Hebrew-script constant (Hebrew mode, this file).
///   - A matching ARB key in `app_en.arb` (transliteration / English mode).
///   - A matching ARB key in `app_he.arb` (Hebrew script, same as the constant).
///
/// Call sites and `lib/core/labels/` helpers resolve the two forms via
/// `useHebrewTermsProvider`.  No domain term may be hardcoded at a call site.
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
    'Review': stageChazaraPrefix,
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

  /// Default chazara stage name prefix (Hebrew).
  /// Use [getChazaraStageName] for numbered chazara stages.
  static const String stageChazaraPrefix = 'חזרה';

  // ── English (transliteration) stage name equivalents ────────────────────
  //
  // These are used by the stage-label helpers in `lib/core/labels/` to
  // return the correct form in English / transliteration mode.

  /// English transliteration: first (learn) stage.
  static const String stageLearnEn = 'Learn';

  /// English transliteration prefix for numbered chazara stages.
  static const String stageChazaraPrefixEn = 'Chazara';

  // ── UI Term Display (Hebrew script variants) ─────────────────────────────
  //
  // Strings in this section are swapped by the "Hebrew Terms" settings toggle
  // (useHebrewTermsProvider).  The toggle is independent of the UI locale
  // (en/he):
  //   ON  → use the Hebrew-script constant defined here
  //   OFF → use the locale-driven ARB string (English transliteration in en)
  //
  // The toggle does NOT cover general UI labels such as "Today's Missions",
  // "No tasks in this lane", "URGENT", etc. Those follow the app's locale.
  //
  // To add a new term to the toggle:
  //   1. Add a `static const String uiXxx = 'עברית';` constant below.
  //   2. Add matching ARB keys `termXxx` to app_en.arb (transliteration) and
  //      app_he.arb (Hebrew script).
  //   3. In `lib/core/labels/domain_term_labels.dart`, expose a resolved
  //      helper so call sites never inline the toggle check.
  //
  // ┌──────────────────────────┬────────────────────┬────────────────────────┐
  // │ Constant                 │ Hebrew             │ ARB key (en)           │
  // ├──────────────────────────┼────────────────────┼────────────────────────┤
  // │ uiChazara                │ חזרה                │ termChazara            │
  // │ uiReviewSection          │ חזרה                │ termReviewSection      │
  // │ uiBubbleChazara          │ חזרה                │ termBubbleChazara      │
  // │ uiDaf                    │ דף                  │ termDaf                │
  // │ uiAmud                   │ עמוד                │ termAmud               │
  // │ uiPerek                  │ פרק                 │ termPerek              │
  // │ uiMishnah                │ משנה                │ termMishnah            │
  // │ uiSeder                  │ סדר                 │ termSeder              │
  // │ uiMasechta               │ מסכת                │ termMasechta           │
  // │ uiChumash                │ חומש                │ termChumash            │
  // │ uiTalmidChochom          │ תלמיד חכם            │ termTalmidChochom      │
  // │ uiTalmidChochomCaps      │ תלמיד חכם            │ termTalmidChochomCaps  │
  // └──────────────────────────┴────────────────────┴────────────────────────┘

  // ── Chazara / Review terms ───────────────────────────────────────────────
  //
  // All three constants reference [stageChazaraPrefix] — the single source for
  // the Hebrew string 'חזרה' — so the value is defined exactly once (§11.8).

  /// "Chazara" (the review concept) → Hebrew script.
  ///
  /// Use the [domainTermLabels.chazara] helper in `lib/core/labels/` to get
  /// the toggle-resolved form. This constant is the Hebrew half.
  static const String uiChazara = stageChazaraPrefix;

  /// "REVIEW SECTION" header → Hebrew.
  static const String uiReviewSection = stageChazaraPrefix;

  /// "CHAZARA" bubble label → Hebrew script.
  ///
  /// Wired to the toggle via [domainTermLabels.bubbleChazara].
  static const String uiBubbleChazara = stageChazaraPrefix;

  // ── Structural Torah unit terms ──────────────────────────────────────────

  /// "Daf" (two-sided Talmud leaf) → Hebrew script.
  static const String uiDaf = 'דף';

  /// "Amud" (one side of a Talmud daf) → Hebrew script.
  static const String uiAmud = 'עמוד';

  /// "Perek" (chapter) → Hebrew script.
  static const String uiPerek = 'פרק';

  /// "Mishna" (a single mishna within a perek) → Hebrew script.
  static const String uiMishnah = 'משנה';

  /// "Seder" (order of Mishnah / Talmud) → Hebrew script.
  static const String uiSeder = 'סדר';

  /// "Masechta" (tractate) → Hebrew script.
  static const String uiMasechta = 'מסכת';

  /// "Chumash" (one of the five books of Torah) → Hebrew script.
  static const String uiChumash = 'חומש';

  /// "Shabbos" / "Shabbat" (the Sabbath) → Hebrew script.
  static const String uiShabbos = 'שבת';

  /// "Havdalah" / "Havdala" (the close-of-Shabbos ceremony) → Hebrew script.
  static const String uiHavdalah = 'הבדלה';

  // ── Scholar tier / honorific terms ──────────────────────────────────────

  /// "Talmid Chochom" (highest scholar tier) → Hebrew script.
  static const String uiTalmidChochom = 'תלמיד חכם';

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  /// Returns the English transliteration for a numbered chazara stage.
  ///
  /// [roundNumber] is 1-based: 1 → "Chazara 1", 2 → "Chazara 2", etc.
  static String getChazaraStageNameEn(int roundNumber) =>
      '$stageChazaraPrefixEn $roundNumber';

  /// Converts an English default stage name to Hebrew, if it matches a known
  /// default. Returns [null] if the name is user-customized (not a default).
  static String? toHebrew(String englishName) => stageNameMap[englishName];
}
