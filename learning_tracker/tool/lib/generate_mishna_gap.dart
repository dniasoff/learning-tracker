// ignore_for_file: avoid_print

/// Generates the Mishnah Yomit (Daily Mishnah) sequence for the gap between
/// the end of our Sefaria calendar data (Rosh Hashanah 1:6-7, 2029-05-09)
/// and the start (Ketubot 2:1-2, 2024-01-01).
///
/// The gap covers:
///   - Rosh Hashanah 1:8-9 through 4:9
///   - Ta'anit (full)
///   - Megillah (full)
///   - Moed Katan (full)
///   - Chagigah (full)
///   - Yevamot (full)
///   - Ketubot chapter 1 only
///
/// Usage:
///   dart run tool/lib/generate_mishna_gap.dart
///
/// Output: one ref per line to stdout, matching the format used in
/// the calendar_cycles table (e.g., "Mishnah Rosh Hashanah 1:8-9").
///
/// Mishnah counts per chapter are from the Sefaria hierarchy data
/// (assets/content/hierarchy/mishnayos.json).
library;

import 'dart:io';

/// Chapter structure: tractate name -> list of mishnah counts per chapter.
///
/// Counts verified against Sefaria's Mishnah shape API data stored in
/// assets/content/hierarchy/mishnayos.json.
const _tractates = <String, List<int>>{
  'Rosh Hashanah': [9, 9, 8, 9],
  "Ta'anit": [7, 10, 9, 8],
  'Megillah': [11, 6, 6, 10],
  'Moed Katan': [10, 5, 9],
  'Chagigah': [8, 7, 8],
  'Yevamot': [4, 10, 10, 13, 6, 6, 6, 6, 6, 9, 7, 6, 13, 9, 10, 7],
  'Ketubot': [10, 10, 9, 12, 9, 7, 10, 8, 9, 6, 6, 4, 11],
};

/// A single mishnah reference: tractate, chapter (1-based), verse (1-based).
typedef _Mishna = ({String tractate, int chapter, int verse});

/// Build the flat list of individual mishnayot that form the gap.
List<_Mishna> _buildGapMishnayot() {
  final mishnayot = <_Mishna>[];

  for (final entry in _tractates.entries) {
    final tractate = entry.key;
    final chapters = entry.value;

    for (var chIdx = 0; chIdx < chapters.length; chIdx++) {
      final chNum = chIdx + 1;
      final verseCount = chapters[chIdx];

      // Rosh Hashanah: skip chapter 1 verses 1-7 (already in data).
      // Start from 1:8.
      final startVerse =
          (tractate == 'Rosh Hashanah' && chNum == 1) ? 8 : 1;

      // Ketubot: only chapter 1 is needed (data picks up at 2:1-2).
      if (tractate == 'Ketubot' && chNum > 1) break;

      for (var v = startVerse; v <= verseCount; v++) {
        mishnayot.add((tractate: tractate, chapter: chNum, verse: v));
      }
    }
  }

  return mishnayot;
}

/// Format a ref for a single mishnah.
String _refSingle(_Mishna m) => 'Mishnah ${m.tractate} ${m.chapter}:${m.verse}';

/// Format a ref for a pair of mishnayot.
///
/// Same chapter:  "Mishnah Tractate X:Y-Z"
/// Cross chapter: "Mishnah Tractate X:Y-Z:W"
String _refPair(_Mishna a, _Mishna b) {
  assert(a.tractate == b.tractate, 'Cross-tractate pairs are not allowed');
  if (a.chapter == b.chapter) {
    return 'Mishnah ${a.tractate} ${a.chapter}:${a.verse}-${b.verse}';
  }
  return 'Mishnah ${a.tractate} ${a.chapter}:${a.verse}-${b.chapter}:${b.verse}';
}

/// Compute the total mishnah count for a tractate.
int _tractateTotal(String tractate) {
  final chapters = _tractates[tractate]!;
  return chapters.fold(0, (sum, c) => sum + c);
}

/// Generate the gap sequence following the Sefaria Daily Mishnah pattern:
///
/// The pattern (verified against every tractate in the existing calendar data):
///
/// 1. Tractates with an ODD total mishnah count start with a solo 1:1 entry,
///    then pair all remaining mishnayot (even count) two at a time.
/// 2. Tractates with an EVEN total start with a pair 1:1-2, then pair the
///    rest (even count) two at a time.
/// 3. Cross-chapter pairing occurs when a chapter has an odd remaining count
///    (e.g., "Rosh Hashanah 2:9-3:1").
/// 4. Rosh Hashanah is a continuation (not a new tractate start), so no
///    solo/pair first entry — it picks up at 1:8-9.
List<String> generateMishnaYomitGap() {
  final mishnayot = _buildGapMishnayot();
  final refs = <String>[];

  var i = 0;
  String? currentTractate;

  while (i < mishnayot.length) {
    final m = mishnayot[i];

    // New tractate starting at 1:1?
    final isNewTractate = m.tractate != currentTractate;
    final isFirstOfTractate = m.chapter == 1 && m.verse == 1;

    if (isNewTractate && isFirstOfTractate) {
      currentTractate = m.tractate;
      final total = _tractateTotal(m.tractate);

      if (total.isOdd) {
        // ODD total: solo 1:1, then pairs.
        refs.add(_refSingle(m));
        i++;
      } else {
        // EVEN total: pair 1:1-2, then pairs.
        if (i + 1 < mishnayot.length &&
            mishnayot[i + 1].tractate == m.tractate) {
          refs.add(_refPair(m, mishnayot[i + 1]));
          i += 2;
        } else {
          // Shouldn't happen for even-total tractates, but safety fallback.
          refs.add(_refSingle(m));
          i++;
        }
      }
      continue;
    }

    if (isNewTractate) {
      currentTractate = m.tractate;
    }

    // Pair with next mishnah if available and same tractate.
    if (i + 1 < mishnayot.length &&
        mishnayot[i + 1].tractate == m.tractate) {
      refs.add(_refPair(m, mishnayot[i + 1]));
      i += 2;
    } else {
      // Last mishnah of a tractate — solo entry.
      // This should not happen if the algorithm is correct (all remaining
      // counts after the first entry should be even).
      refs.add(_refSingle(m));
      i++;
    }
  }

  return refs;
}

void main() {
  final refs = generateMishnaYomitGap();
  for (final ref in refs) {
    print(ref);
  }
  // Summary to stderr so it doesn't pollute stdout pipe.
  final total = _buildGapMishnayot().length;
  stderr.writeln('');
  stderr.writeln('Generated ${refs.length} entries covering $total mishnayot.');
}
