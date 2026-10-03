// Story 3.5 (DNI-508) T5/T6, AC-9: the reminder copy is neutral and
// forward-looking in both locales — never the streak, losing anything or
// being behind — and carries no learner data beyond the display name.

import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/catch_up_reminder_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  final pressure = RegExp(
    'streak|lose|lost|losing|behind|miss|late|hurry|רצף|הפסד|פיגור|איחור',
    caseSensitive: false,
  );

  for (final code in ['en', 'he']) {
    group('$code copy', () {
      final copy = catchUpReminderCopy(lookupAppLocalizations(Locale(code)));

      test('every lock kind has its own neutral title', () {
        final titles = {
          for (final kind in ErevKind.values) kind: copy(kind, 'Avi').title,
        };
        expect(titles.values.toSet(), hasLength(ErevKind.values.length));
        for (final title in titles.values) {
          expect(title, isNot(matches(pressure)));
          expect(title, isNotEmpty);
        }
      });

      test('the body carries the display name and nothing else', () {
        final body = copy(ErevKind.shabbos, 'Avi').body;
        expect(body, contains('Avi'));
        expect(body, isNot(matches(pressure)));
        expect(body, isNot(contains(RegExp(r'\d'))));
      });
    });
  }

  test('the English example wording (A-6 default)', () {
    final copy = catchUpReminderCopy(
      lookupAppLocalizations(const Locale('en')),
    );
    expect(copy(ErevKind.shabbos, 'Avi'), (
      title: 'Shabbos is over',
      body: 'Avi, record what you learnt?',
    ));
    expect(
      copy(ErevKind.yomTovAndShabbos, 'Avi').title,
      'Yom Tov and Shabbos are over',
    );
  });
}
