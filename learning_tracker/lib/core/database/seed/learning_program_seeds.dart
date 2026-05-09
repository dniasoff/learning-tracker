/// Seed data for all learning program presets.
///
/// Each preset is immutable — never modified, only deprecated and replaced.
///
/// Calendar fields:
/// - `api_source`: 'sefaria' | 'hebcal' | 'local' | null (custom program).
///   Must match the same field on the matching `CalendarProgramDefinition`.
/// - `api_program_key`: must equal a `CalendarProgramDefinition.id` so that
///   `_resolveCalendarProgramKey` resolves on the first lookup. The seed DB's
///   `calendar_cycles` table is keyed by the registry id, not the API key.
/// - `is_calendar_program`: true when the program is date-driven by the
///   bundled `calendar_cycles` table; false for custom programs.
const List<Map<String, Object?>> learningProgramSeeds = [
  {
    'name': 'oraysa',
    'display_name': 'Oraysa',
    'description':
        'Structured learning with daily study, next-day review, weekly review, and rolling back-20 review cycle.',
    'curriculum_type': 'bavli',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"next_day_review","label":"חזרה יומית","delay_days":1},'
        '{"stage":"weekly_review","label":"חזרה שבועית","frequency":"weekly","days":["friday","shabbos"]},'
        '{"stage":"rolling_back_20","label":"חזרה מחזורית","type":"rolling","window":20}'
        ']',
    'test_config': '{}',
    'api_source': null,
    'api_program_key': null,
    'is_calendar_program': false,
  },
  {
    'name': 'dirshu_kinyan_torah',
    'display_name': 'Dirshu Kinyan Torah',
    'description':
        'Daf Yomi pace with 3 chazarah review cycles and monthly tests.',
    'curriculum_type': 'bavli',
    'is_active': false,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7},'
        '{"stage":"chazara_3","label":"חזרה ג׳","delay_days":21}'
        ']',
    'test_config': '{"frequency":"monthly","type":"written"}',
    'api_source': 'local',
    'api_program_key': 'dirshu_kinyan_torah',
    'is_calendar_program': true,
  },
  {
    'name': 'dirshu_amud_hayomi',
    'display_name': 'Dirshu Amud HaYomi',
    'description': 'Half-daf daily pace with review cycles and monthly tests.',
    'curriculum_type': 'bavli',
    'is_active': false,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"half_daf"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7},'
        '{"stage":"chazara_3","label":"חזרה ג׳","delay_days":21}'
        ']',
    'test_config': '{"frequency":"monthly","type":"written"}',
    'api_source': 'hebcal',
    'api_program_key': 'dirshu_amud_hayomi',
    'is_calendar_program': true,
  },
  {
    'name': 'dirshu_kinyan_yerushalmi',
    'display_name': 'Dirshu Kinyan Yerushalmi',
    'description': 'Yerushalmi study with review cycles and monthly tests.',
    'curriculum_type': 'yerushalmi',
    'is_active': false,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7},'
        '{"stage":"chazara_3","label":"חזרה ג׳","delay_days":21}'
        ']',
    'test_config': '{"frequency":"monthly","type":"written"}',
    'api_source': 'local',
    'api_program_key': 'dirshu_kinyan_yerushalmi',
    'is_calendar_program': true,
  },
  {
    'name': 'daf_yomi',
    'display_name': 'Daf Yomi',
    'description': 'One daf per day, no built-in review.',
    'curriculum_type': 'bavli',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"one_daf"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'daf_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'mishnah_yomis',
    'display_name': 'Mishnah Yomis',
    'description': 'Two mishnayos per day, no built-in review.',
    'curriculum_type': 'mishnayos',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"two_mishnayos"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'mishna_yomit',
    'is_calendar_program': true,
  },
  {
    'name': 'nach_yomi',
    'display_name': 'Nach Yomi',
    'description': 'One chapter per day, no built-in review.',
    'curriculum_type': 'nach',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"one_chapter"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'nach_yomi',
    'is_calendar_program': true,
  },
  // ── Calendar-linked programs (no built-in review) ─────────────────────
  {
    'name': 'yerushalmi_yomi',
    'display_name': 'Yerushalmi Yomi',
    'description': 'One daf of Talmud Yerushalmi per day.',
    'curriculum_type': 'yerushalmi',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"one_daf"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'yerushalmi_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'rambam_1_chapter',
    'display_name': 'Rambam - 1 Chapter',
    'description': 'One chapter of Mishneh Torah per day.',
    'curriculum_type': 'mishneh_torah',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"one_chapter"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'rambam_1_chapter',
    'is_calendar_program': true,
  },
  {
    'name': 'rambam_3_chapters',
    'display_name': 'Rambam - 3 Chapters',
    'description': 'Three chapters of Mishneh Torah per day.',
    'curriculum_type': 'mishneh_torah',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"three_chapters"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'rambam_3_chapters',
    'is_calendar_program': true,
  },
  {
    'name': 'daf_a_week',
    'display_name': 'Daf a Week',
    'description': 'One daf of Talmud Bavli per week.',
    'curriculum_type': 'bavli',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"weekly","pace":"one_daf"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'daf_a_week',
    'is_calendar_program': true,
  },
  {
    'name': 'halakhah_yomit',
    'display_name': 'Halakhah Yomit',
    'description': 'Daily halacha study following the Shulchan Aruch cycle.',
    'curriculum_type': 'mishna_berurah',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'sefaria',
    'api_program_key': 'halakhah_yomit',
    'is_calendar_program': true,
  },
  {
    'name': 'arukh_hashulchan_yomi',
    'display_name': 'Arukh HaShulchan Yomi',
    'description': 'Daily study of the Arukh HaShulchan.',
    'curriculum_type': 'mishna_berurah',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'arukh_hashulchan_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'tanakh_yomi',
    'display_name': 'Tanakh Yomi',
    'description': 'Daily Tanakh study cycle.',
    'curriculum_type': 'tanach',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'tanakh_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'chofetz_chaim_daily',
    'display_name': 'Chofetz Chaim Daily',
    'description': 'Daily study of the Chofetz Chaim on Shmirat HaLashon.',
    'curriculum_type': 'mussar',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'chofetz_chaim_daily',
    'is_calendar_program': true,
  },
  {
    'name': 'kitzur_shulchan_aruch_yomi',
    'display_name': 'Kitzur Shulchan Aruch Yomi',
    'description': 'Daily study of the Kitzur Shulchan Aruch.',
    'curriculum_type': 'mishna_berurah',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'kitzur_shulchan_aruch_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'tehillim_yomi',
    'display_name': 'Tehillim Yomi',
    'description': 'Daily Psalms cycle.',
    'curriculum_type': 'tanach',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'tehillim_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'perek_yomi',
    'display_name': 'Perek Yomi',
    'description': 'One Mishnah perek per day.',
    'curriculum_type': 'mishnayos',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"one_perek"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'perek_yomi',
    'is_calendar_program': true,
  },
  {
    'name': 'sefer_hamitzvot',
    'display_name': 'Sefer HaMitzvot',
    'description': 'Daily study of the Rambam\'s Sefer HaMitzvot.',
    'curriculum_type': 'mishneh_torah',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'sefer_hamitzvot',
    'is_calendar_program': true,
  },
  {
    'name': 'shemirat_halashon',
    'display_name': 'Shemirat HaLashon',
    'description':
        'Daily study of the Chofetz Chaim\'s Shemirat HaLashon (companion to '
        'Chofetz Chaim Yomi).',
    'curriculum_type': 'mussar',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'shemirat_halashon',
    'is_calendar_program': true,
  },
  {
    'name': 'pirkei_avot_summer',
    'display_name': 'Pirkei Avot (Summer)',
    'description':
        'One perek of Pirkei Avot each Shabbos between Pesach and Rosh Hashana.',
    'curriculum_type': 'mishnayos',
    'is_active': false,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"weekly","days":["shabbos"]}'
        ']',
    'test_config': '{}',
    'api_source': 'hebcal',
    'api_program_key': 'pirkei_avot_summer',
    'is_calendar_program': true,
  },
];
