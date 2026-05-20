/// The calendar system used to display and interpret dates.
///
/// The two systems supported by the app:
/// - [hebrew] — dates expressed according to the Hebrew (Jewish) lunar calendar.
/// - [english] — dates expressed according to the English (civil) calendar.
///
/// ## Naming convention
/// The term "English" is used throughout the codebase and UI (not "Gregorian")
/// to match the terminology familiar to the target user-base.
enum CalendarSystem {
  /// The Hebrew (Jewish) lunar calendar.
  ///
  /// Dates are displayed as e.g. "י״ז בניסן תשפ״ה". The year starts on Rosh
  /// Hashana (1 Tishri). Leap years add an extra Adar.
  hebrew,

  /// The English (civil/Gregorian) calendar.
  ///
  /// Dates are displayed in the user's locale, e.g. "May 11, 2026" (US) or
  /// "11 May 2026" (UK/IL). Always use [DateFormat.yMMMd(locale)] for
  /// locale-aware formatting — never hard-code the date format.
  english;

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// Storage key used in SharedPreferences and Firestore.
  String get storageKey => name;

  /// Parses [key] from storage.
  ///
  /// Throws [ArgumentError] when [key] is unrecognised.
  static CalendarSystem fromStorageKey(String key) {
    return CalendarSystem.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => throw ArgumentError.value(
        key,
        'key',
        'Unknown CalendarSystem storage key.',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Whether this system is the Hebrew calendar.
  bool get isHebrew => this == CalendarSystem.hebrew;

  /// Whether this system is the English calendar.
  bool get isEnglish => this == CalendarSystem.english;
}
