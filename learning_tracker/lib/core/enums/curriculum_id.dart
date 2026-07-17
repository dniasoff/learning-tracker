/// Identifies each curriculum tracked in the app.
///
/// [storageKey] is used as the canonical identifier in the database
/// and API layers. All curriculum_id columns use this value.
///
/// **Declaration order is the canonical learning order** the UI uses
/// everywhere a list of curricula is shown. Order follows traditional
/// Jewish-learning sequence:
///   Tanakh (Chumash → Nach → Tanach combined)
///   → Mishnah (Mishnayos)
///   → Talmud (Bavli → Yerushalmi)
///   → Halakhah codes (Mishneh Torah → Mishna Berurah)
///   → Mussar
/// Do NOT sort by `displayNameEn` / `storageKey` — those are alphabetical
/// and put e.g. Bavli before Chumash, which is wrong.
enum CurriculumId {
  chumash('chumash'),
  nach('nach'),
  tanach('tanach'),
  mishnayos('mishnayos'),
  bavli('bavli'),
  yerushalmi('yerushalmi'),
  mishnehTorah('mishneh_torah'),
  mishnaBerurah('mishna_berurah'),
  mussar('mussar');

  const CurriculumId(this.storageKey);

  /// Canonical string key used in the database and in `ContentItem.curriculumId`
  /// (loaded from the bundled JSON hierarchy assets — there is no
  /// `content_items` database table).
  final String storageKey;

  /// Resolve a [CurriculumId] from its [storageKey] string — the raw
  /// value read from the database or a `ContentItem.curriculumId`. Returns
  /// null when [key] does not match any known curriculum.
  ///
  /// This is the single canonical storageKey→enum lookup; call sites
  /// must not re-implement the linear scan themselves.
  static CurriculumId? fromStorageKey(String key) {
    for (final id in CurriculumId.values) {
      if (id.storageKey == key) return id;
    }
    return null;
  }

  /// Every curriculum id, in the canonical learning order (declaration
  /// order — see this class's doc comment for the rationale).
  ///
  /// Call sites that need "every curriculum" (build a per-curriculum map,
  /// invalidate a provider for each curriculum, etc.) should read through
  /// this accessor rather than referencing `CurriculumId.values` directly,
  /// so the enumeration has a single named seam — mirroring
  /// [fromStorageKey] being the single seam for storageKey resolution.
  static List<CurriculumId> get all => values;

  /// Display name in English.
  String get displayNameEn => switch (this) {
    CurriculumId.mishnayos => 'Mishnayos',
    CurriculumId.bavli => 'Talmud Bavli',
    CurriculumId.yerushalmi => 'Talmud Yerushalmi',
    CurriculumId.mishnaBerurah => 'Mishna Berurah',
    CurriculumId.chumash => 'Chumash',
    CurriculumId.mishnehTorah => 'Mishneh Torah',
    CurriculumId.tanach => 'Tanach',
    CurriculumId.nach => 'Nach',
    CurriculumId.mussar => 'Mussar',
  };

  /// Display name in Hebrew.
  String get displayNameHe => switch (this) {
    CurriculumId.mishnayos => '\u05DE\u05E9\u05E0\u05D9\u05D5\u05EA',
    CurriculumId.bavli =>
      '\u05EA\u05DC\u05DE\u05D5\u05D3 \u05D1\u05D1\u05DC\u05D9',
    CurriculumId.yerushalmi =>
      '\u05EA\u05DC\u05DE\u05D5\u05D3 \u05D9\u05E8\u05D5\u05E9\u05DC\u05DE\u05D9',
    CurriculumId.mishnaBerurah =>
      '\u05DE\u05E9\u05E0\u05D4 \u05D1\u05E8\u05D5\u05E8\u05D4',
    CurriculumId.chumash => '\u05D7\u05D5\u05DE\u05E9',
    CurriculumId.mishnehTorah =>
      '\u05DE\u05E9\u05E0\u05D4 \u05EA\u05D5\u05E8\u05D4',
    CurriculumId.tanach => '\u05EA\u05E0"\u05DA',
    CurriculumId.nach => '\u05E0"\u05DA',
    CurriculumId.mussar => '\u05DE\u05D5\u05E1\u05E8',
  };
}
