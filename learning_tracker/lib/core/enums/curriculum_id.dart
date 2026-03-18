/// Identifies each curriculum tracked in the app.
///
/// [storageKey] is used as the canonical identifier in the database
/// and API layers. All curriculum_id columns use this value.
enum CurriculumId {
  mishnayos('mishnayos'),
  bavli('bavli'),
  yerushalmi('yerushalmi'),
  mishnaBerurah('mishna_berurah'),
  chumash('chumash'),
  torah('torah'),
  tanach('tanach'),
  nach('nach'),
  mussar('mussar');

  const CurriculumId(this.storageKey);

  /// Canonical string key used in database and content_items table.
  final String storageKey;

  /// Display name in English.
  String get displayNameEn => switch (this) {
    CurriculumId.mishnayos => 'Mishnayos',
    CurriculumId.bavli => 'Talmud Bavli',
    CurriculumId.yerushalmi => 'Talmud Yerushalmi',
    CurriculumId.mishnaBerurah => 'Mishna Berurah',
    CurriculumId.chumash => 'Chumash',
    CurriculumId.torah => 'Torah',
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
    CurriculumId.torah => '\u05EA\u05D5\u05E8\u05D4',
    CurriculumId.tanach => '\u05EA\u05E0"\u05DA',
    CurriculumId.nach => '\u05E0"\u05DA',
    CurriculumId.mussar => '\u05DE\u05D5\u05E1\u05E8',
  };
}
