/// Seed data for all 9 learning program presets.
///
/// Each preset is immutable — never modified, only deprecated and replaced.
///
/// Calendar fields (Story 19.3 T11):
/// - `api_source`: 'sefaria' | 'hebcal' | null (custom program)
/// - `api_program_key`: API response key (e.g. 'Daf Yomi', 'nachyomi')
/// - `is_calendar_program`: true when the program is date-driven by an
///   external API / CalendarCycles table; false for custom programs.
const List<Map<String, Object?>> learningProgramSeeds = [
  {
    'name': 'oraysa',
    'display_name': 'Oraysa',
    'description':
        'Structured learning with daily study, next-day review, weekly review, and rolling back-20 review cycle.',
    'curriculum_type': 'bavli',
    'is_active': true,
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
    'is_active': true,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7},'
        '{"stage":"chazara_3","label":"חזרה ג׳","delay_days":21}'
        ']',
    'test_config': '{"frequency":"monthly","type":"written"}',
  },
  {
    'name': 'dirshu_amud_hayomi',
    'display_name': 'Dirshu Amud HaYomi',
    'description': 'Half-daf daily pace with review cycles and monthly tests.',
    'curriculum_type': 'bavli',
    'is_active': true,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily","pace":"half_daf"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7},'
        '{"stage":"chazara_3","label":"חזרה ג׳","delay_days":21}'
        ']',
    'test_config': '{"frequency":"monthly","type":"written"}',
  },
  {
    'name': 'dirshu_kinyan_yerushalmi',
    'display_name': 'Dirshu Kinyan Yerushalmi',
    'description': 'Yerushalmi study with review cycles and monthly tests.',
    'curriculum_type': 'yerushalmi',
    'is_active': true,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7},'
        '{"stage":"chazara_3","label":"חזרה ג׳","delay_days":21}'
        ']',
    'test_config': '{"frequency":"monthly","type":"written"}',
  },
  {
    'name': 'dirshu_daf_hayomi_bhalacha',
    'display_name': 'Dirshu Daf HaYomi B\'Halacha',
    'description': 'Mishna Berurah study with review and bimonthly tests.',
    'curriculum_type': 'mishna_berurah',
    'is_active': true,
    'has_tests': true,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"review","label":"חזרה","delay_days":7}'
        ']',
    'test_config': '{"frequency":"bimonthly","type":"written"}',
  },
  {
    'name': 'dirshu_kinyan_chochma',
    'display_name': 'Dirshu Kinyan Chochma',
    'description': 'Mussar study with structured review cycles.',
    'curriculum_type': 'mussar',
    'is_active': true,
    'has_tests': false,
    'stages_config':
        '['
        '{"stage":"learn","label":"לימוד","frequency":"daily"},'
        '{"stage":"chazara_1","label":"חזרה א׳","delay_days":1},'
        '{"stage":"chazara_2","label":"חזרה ב׳","delay_days":7}'
        ']',
    'test_config': '{}',
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
  },
];
