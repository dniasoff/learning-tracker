/// Hebrew gematriya number conversion.
///
/// Converts Arabic integers to/from Hebrew letter representations using the
/// standard Jewish numerical system (א=1, י=10, ק=100). Handles the
/// conventional 15/16 substitutions (טו, טז) to avoid spelling the divine
/// name.
class Gematriya {
  Gematriya._();

  static const _ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
  static const _tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
  static const _hundreds = ['', 'ק', 'ר', 'ש', 'ת'];

  /// Convert [n] (1..999) to its Hebrew gematriya representation.
  ///
  /// Examples:
  ///   1 → 'א', 11 → 'יא', 15 → 'טו', 16 → 'טז', 100 → 'ק', 115 → 'קטו',
  ///   400 → 'ת', 500 → 'תק', 999 → 'תתקצט'.
  ///
  /// Throws [ArgumentError] for n < 1 or n > 999.
  static String forNumber(int n) {
    if (n < 1 || n > 999) {
      throw ArgumentError.value(n, 'n', 'must be 1..999');
    }

    final buf = StringBuffer();

    var remaining = n;

    // Hundreds: 100..400 = ק..ת. 500..999 composed additively as repeated ת
    // (=400) plus the remaining hundreds digit.
    while (remaining >= 400) {
      buf.write('ת');
      remaining -= 400;
    }
    final hundredsDigit = remaining ~/ 100;
    if (hundredsDigit > 0) {
      buf.write(_hundreds[hundredsDigit]);
      remaining -= hundredsDigit * 100;
    }

    // 15 and 16 use טו / טז instead of יה / יו to avoid divine name spellings.
    if (remaining == 15) {
      buf.write('טו');
      return buf.toString();
    }
    if (remaining == 16) {
      buf.write('טז');
      return buf.toString();
    }

    final tensDigit = remaining ~/ 10;
    if (tensDigit > 0) {
      buf.write(_tens[tensDigit]);
      remaining -= tensDigit * 10;
    }
    if (remaining > 0) {
      buf.write(_ones[remaining]);
    }

    return buf.toString();
  }

  /// Convert a Hebrew year [hebrewYear] (≥ 1) to its gematriya representation
  /// with the correct punctuation for display.
  ///
  /// **Current-era convention (years 1..5999):** the thousands component is
  /// omitted by tradition; only the sub-1000 remainder is rendered with
  /// standard gershayim punctuation inserted before the last letter.
  ///
  ///   5786 → "תשפ״ו"   (786 with gershayim, thousands ה omitted)
  ///   5000 → ""         (no sub-1000 remainder — empty string returned for
  ///                       pure-millennium abbreviated years; callers may
  ///                       substitute a placeholder such as "תק״ב" for 5002)
  ///
  /// **Years ≥ 6000:** the thousands component is included as a geresh-marked
  /// letter (U+05F3 ׳) so the year reads unambiguously.
  ///
  ///   6000 → "ו׳"
  ///   6120 → "ו׳ק״כ"
  ///   7000 → "ז׳"
  ///
  /// Gershayim (U+05F4 ״) is inserted before the last letter of the sub-1000
  /// part when that part has two or more letters.  Single-letter sub-1000
  /// parts receive a geresh instead.
  ///
  /// Throws [ArgumentError] for [hebrewYear] < 1.
  ///
  /// TS-6 fix: this method replaces any ad-hoc `forNumber(year % 1000)` call
  /// that silently dropped the thousands component for years ≥ 6000.
  static String forYear(int hebrewYear) {
    if (hebrewYear < 1) {
      throw ArgumentError.value(hebrewYear, 'hebrewYear', 'must be >= 1');
    }

    final thousands = hebrewYear ~/ 1000;
    final remainder = hebrewYear % 1000;

    // Sub-1000 part (may be empty if remainder == 0).
    final String subPart;
    if (remainder == 0) {
      subPart = '';
    } else {
      subPart = _withGershayim(forNumber(remainder));
    }

    // For years with no thousands digit (1..999) or current era (thousands
    // 1..5): omit the thousands letter by convention — only the sub-1000 part
    // is shown.
    if (thousands == 0 || (thousands >= 1 && thousands <= 5)) {
      return subPart;
    }

    // For years in the 6th millennium and beyond the thousands letter is
    // required so the year is unambiguous. Use a single geresh (׳, U+05F3).
    final thousandsLetter = _thousandsLetter(thousands);
    return '$thousandsLetter׳$subPart';
  }

  /// Insert gershayim (״, U+05F4) before the last rune of [s] when [s] has
  /// two or more characters.  Single-character strings get a geresh (׳).
  static String _withGershayim(String s) {
    if (s.isEmpty) return s;
    final runes = s.runes.toList();
    if (runes.length == 1) {
      return '$s׳'; // single letter — use geresh
    }
    // Insert gershayim before the last character.
    final prefix = String.fromCharCodes(runes.sublist(0, runes.length - 1));
    final last = String.fromCharCode(runes.last);
    return '$prefix״$last';
  }

  /// Hebrew letter for the thousands place (1 → א, 2 → ב, …, 9 → ט).
  /// Returns the ones letter since Hebrew years have thousands ≤ 9 for
  /// any year in the range of interest.
  static String _thousandsLetter(int n) {
    assert(n >= 1 && n <= 9, 'Thousands digit out of range: $n');
    return _ones[n];
  }

  /// Parse a Hebrew gematriya string back to its integer value, or null if
  /// the input doesn't look like valid gematriya.
  ///
  /// Strips geresh/gershayim punctuation (׳ ״ ' ") before parsing.
  static int? parse(String hebrew) {
    final cleaned = hebrew
        .replaceAll('׳', '')
        .replaceAll('״', '')
        .replaceAll("'", '')
        .replaceAll('"', '')
        .trim();
    if (cleaned.isEmpty) return null;

    var total = 0;
    for (final rune in cleaned.runes) {
      final letter = String.fromCharCode(rune);
      final value = _letterValue(letter);
      if (value == null) return null;
      total += value;
    }
    return total == 0 ? null : total;
  }

  static int? _letterValue(String letter) {
    switch (letter) {
      case 'א':
        return 1;
      case 'ב':
        return 2;
      case 'ג':
        return 3;
      case 'ד':
        return 4;
      case 'ה':
        return 5;
      case 'ו':
        return 6;
      case 'ז':
        return 7;
      case 'ח':
        return 8;
      case 'ט':
        return 9;
      case 'י':
        return 10;
      case 'כ':
      case 'ך':
        return 20;
      case 'ל':
        return 30;
      case 'מ':
      case 'ם':
        return 40;
      case 'נ':
      case 'ן':
        return 50;
      case 'ס':
        return 60;
      case 'ע':
        return 70;
      case 'פ':
      case 'ף':
        return 80;
      case 'צ':
      case 'ץ':
        return 90;
      case 'ק':
        return 100;
      case 'ר':
        return 200;
      case 'ש':
        return 300;
      case 'ת':
        return 400;
      default:
        return null;
    }
  }
}
