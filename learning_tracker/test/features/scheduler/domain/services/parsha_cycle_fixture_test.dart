import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kosher_dart/kosher_dart.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/calendar/parsha_cycle_5787_5788.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('kosher_dart parsha cycle against Hebcal fixture', () {
    final rows = fixture['calendar'] as List<dynamic>;

    test('matches every Shabbat in Hebrew years 5787 and 5788 by region', () {
      expect(rows, hasLength(212));

      for (final value in rows) {
        final row = value as Map<String, dynamic>;
        final date = DateTime.parse('${row['date']}T00:00:00Z');
        final calendar = JewishCalendar.fromDateTime(date)
          ..inIsrael = row['israel'] as bool;

        expect(
          calendar.getJewishYear(),
          row['hebrewYear'],
          reason: 'Hebrew year for ${row['date']}',
        );
        expect(
          calendar.getParshah().name,
          row['expected'],
          reason:
              '${row['date']} (Israel=${row['israel']}) should match Hebcal',
        );
      }
    });

    test(
      'fixture exercises festival Shabbat, divergence, reunion, and doubles',
      () {
        final actual = {
          for (final value in rows)
            (
              (value as Map<String, dynamic>)['date'] as String,
              value['israel'] as bool,
            ): value['expected'] as String,
        };

        expect(actual[('2027-04-24', true)], 'NONE');
        expect(actual[('2027-04-24', false)], 'NONE');
        expect(actual[('2027-06-12', true)], 'NASSO');
        expect(actual[('2027-06-12', false)], 'NONE');
        expect(actual[('2027-06-19', true)], 'BEHAALOSCHA');
        expect(actual[('2027-06-19', false)], 'NASSO');
        expect(actual[('2027-07-17', true)], 'BALAK');
        expect(actual[('2027-07-17', false)], 'CHUKAS_BALAK');
        expect(actual[('2027-07-24', true)], 'PINCHAS');
        expect(actual[('2027-07-24', false)], 'PINCHAS');
        expect(actual[('2027-10-02', true)], 'NONE');
        expect(actual[('2027-10-02', false)], 'NONE');
        expect(actual[('2028-03-25', true)], 'VAYAKHEL_PEKUDEI');
        expect(actual[('2028-03-25', false)], 'VAYAKHEL_PEKUDEI');
      },
    );
  });

  test('all fixture aliyot resolve to contiguous Chumash verse ranges', () {
    final manifest =
        jsonDecode(File('tool/data/curriculum_books.json').readAsStringSync())
            as Map<String, dynamic>;
    final chumash = manifest['chumash'] as Map<String, dynamic>;
    const torahOrder = [
      'Genesis',
      'Exodus',
      'Leviticus',
      'Numbers',
      'Deuteronomy',
    ];
    final verses = [
      for (final book in torahOrder)
        ...(chumash[book] as List<dynamic>).cast<String>(),
    ];
    final indexByRef = {for (var i = 0; i < verses.length; i++) verses[i]: i};
    final covered = <int>{};
    final aliyot = fixture['aliyot'] as List<dynamic>;

    expect(aliyot, hasLength(56));

    for (final value in aliyot) {
      final parsha = value as Map<String, dynamic>;
      final ranges = (parsha['aliyot'] as List<dynamic>).cast<String>();
      expect(ranges, hasLength(7), reason: parsha['name'] as String);
      int? previousEnd;
      for (final range in ranges) {
        final (start, end) = _rangeEndpoints(range);
        final startIndex = indexByRef[start];
        final endIndex = indexByRef[end];
        expect(startIndex, isNotNull, reason: '${parsha['name']}: $start');
        expect(endIndex, isNotNull, reason: '${parsha['name']}: $end');
        expect(startIndex!, lessThanOrEqualTo(endIndex!));
        if (previousEnd != null) {
          expect(
            startIndex,
            previousEnd + 1,
            reason: '${parsha['name']} aliyah ranges must be contiguous',
          );
        }
        previousEnd = endIndex;
        covered.addAll(
          List<int>.generate(
            endIndex! - startIndex! + 1,
            (i) => startIndex! + i,
          ),
        );
      }
    }

    final festivalAliyot = fixture['festivalAliyot'] as List<dynamic>;
    expect(festivalAliyot, hasLength(2));
    for (final value in festivalAliyot) {
      final reading = value as Map<String, dynamic>;
      final ranges = (reading['aliyot'] as List<dynamic>).cast<String>();
      expect(
        ranges,
        hasLength(reading['israel'] == true ? 7 : 6),
        reason: '${reading['occasion']} Vezot Haberachah',
      );
      int? previousEnd;
      for (final range in ranges) {
        final (start, end) = _rangeEndpoints(range);
        final startIndex = indexByRef[start];
        final endIndex = indexByRef[end];
        expect(startIndex, isNotNull, reason: '${reading['occasion']}: $start');
        expect(endIndex, isNotNull, reason: '${reading['occasion']}: $end');
        expect(startIndex!, lessThanOrEqualTo(endIndex!));
        if (previousEnd != null) {
          expect(
            startIndex,
            previousEnd + 1,
            reason: '${reading['occasion']} aliyot must be contiguous',
          );
        }
        previousEnd = endIndex;
        covered.addAll(
          List<int>.generate(
            endIndex! - startIndex! + 1,
            (i) => startIndex! + i,
          ),
        );
      }
    }

    expect(covered, hasLength(verses.length));
  });
}

(String, String) _rangeEndpoints(String range) {
  final parts = range.split('-');
  expect(parts.length, anyOf(1, 2), reason: range);
  final start = parts.first.trim();
  if (parts.length == 1) return (start, start);

  var end = parts.last.trim();
  if (!end.contains(' ')) {
    final book = start.substring(0, start.lastIndexOf(' '));
    end = '$book $end';
  }
  return (start, end);
}
