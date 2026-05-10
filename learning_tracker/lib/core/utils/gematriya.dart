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
