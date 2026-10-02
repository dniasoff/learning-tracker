/// Story 2.8 (DNI-499) T5: the lifecycle copy exists in English and Hebrew
/// and keeps the UX-DR-70 wording ("Ended", never "Completed").
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

Map<String, Object?> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, Object?>;

void main() {
  final en = _arb('en');
  final he = _arb('he');
  final keys = [
    for (final k in en.keys)
      if (k.startsWith('subTrackLifecycle')) k,
  ];

  test('every lifecycle key has English and Hebrew copy', () {
    expect(keys, isNotEmpty);
    for (final key in keys) {
      expect(he[key], isA<String>(), reason: key);
      expect((he[key]! as String).trim(), isNotEmpty, reason: key);
      expect(en['@$key'], isA<Map<String, Object?>>(), reason: key);
    }
  });

  test('the ended group says Ended, never Completed (UX-DR-70)', () {
    final english = AppLocalizationsEn();
    expect(english.subTrackLifecycleEndedGroup(2), 'Ended sub-tracks (2)');
    for (final key in keys) {
      expect(en[key].toString().toLowerCase(), isNot(contains('complete')));
    }
    expect(
      AppLocalizationsHe().subTrackLifecycleEndedGroup(2),
      contains('(2)'),
    );
  });

  test('Add next year carries the academic-year label', () {
    expect(
      AppLocalizationsEn().subTrackLifecycleAddNextYear('2027–28'),
      'Add next year (2027–28)',
    );
    expect(
      AppLocalizationsHe().subTrackLifecycleAddNextYear('2027–28'),
      contains('2027–28'),
    );
  });
}
