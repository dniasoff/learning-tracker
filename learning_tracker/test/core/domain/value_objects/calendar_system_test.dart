import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/calendar_system.dart';

void main() {
  group('CalendarSystem', () {
    group('storageKey', () {
      test('hebrew → "hebrew"', () {
        expect(CalendarSystem.hebrew.storageKey, 'hebrew');
      });

      test('english → "english"', () {
        expect(CalendarSystem.english.storageKey, 'english');
      });
    });

    group('fromStorageKey', () {
      test('parses "hebrew"', () {
        expect(
          CalendarSystem.fromStorageKey('hebrew'),
          CalendarSystem.hebrew,
        );
      });

      test('parses "english"', () {
        expect(
          CalendarSystem.fromStorageKey('english'),
          CalendarSystem.english,
        );
      });

      test('throws ArgumentError for unknown key', () {
        expect(
          () => CalendarSystem.fromStorageKey('gregorian'),
          throwsArgumentError,
        );
      });
    });

    group('accessors', () {
      test('isHebrew true for hebrew', () {
        expect(CalendarSystem.hebrew.isHebrew, isTrue);
      });

      test('isHebrew false for english', () {
        expect(CalendarSystem.english.isHebrew, isFalse);
      });

      test('isEnglish true for english', () {
        expect(CalendarSystem.english.isEnglish, isTrue);
      });

      test('isEnglish false for hebrew', () {
        expect(CalendarSystem.hebrew.isEnglish, isFalse);
      });
    });

    test('round-trips through storageKey', () {
      for (final system in CalendarSystem.values) {
        expect(CalendarSystem.fromStorageKey(system.storageKey), system);
      }
    });
  });
}
