import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';

void main() {
  group('CalendarProgramRegistry', () {
    test('has exactly 12 programs', () {
      expect(CalendarProgramRegistry.programs.length, 12);
    });

    group('byApiKey - Sefaria programs', () {
      test('Daily Mishnah maps to mishna_yomit', () {
        final def = CalendarProgramRegistry.byApiKey('Daily Mishnah');
        expect(def, isNotNull);
        expect(def!.id, 'mishna_yomit');
      });

      test('Daily Rambam maps to rambam_1_chapter', () {
        final def = CalendarProgramRegistry.byApiKey('Daily Rambam');
        expect(def, isNotNull);
        expect(def!.id, 'rambam_1_chapter');
      });

      test('Daily Rambam (3 Chapters) maps to rambam_3_chapters', () {
        final def =
            CalendarProgramRegistry.byApiKey('Daily Rambam (3 Chapters)');
        expect(def, isNotNull);
        expect(def!.id, 'rambam_3_chapters');
      });

      test('Daf Yomi maps correctly (regression check)', () {
        final def = CalendarProgramRegistry.byApiKey('Daf Yomi');
        expect(def, isNotNull);
        expect(def!.id, 'daf_yomi');
      });

      test('old mismatched keys return null', () {
        expect(CalendarProgramRegistry.byApiKey('Mishnah Yomit'), isNull);
        expect(
          CalendarProgramRegistry.byApiKey('Daily Rambam 1 Chapter'),
          isNull,
        );
        expect(
          CalendarProgramRegistry.byApiKey('Daily Rambam 3 Chapters'),
          isNull,
        );
      });
    });

    group('byId - Nach Yomi moved to Hebcal', () {
      test('nach_yomi has apiSource hebcal', () {
        final def = CalendarProgramRegistry.byId('nach_yomi');
        expect(def, isNotNull);
        expect(def!.apiSource, 'hebcal');
      });

      test('nach_yomi has hebcalCategory nachyomi', () {
        final def = CalendarProgramRegistry.byId('nach_yomi');
        expect(def!.hebcalCategory, 'nachyomi');
      });
    });

    group('byHebcalCategory', () {
      test('nachyomi maps to nach_yomi', () {
        final def = CalendarProgramRegistry.byHebcalCategory('nachyomi');
        expect(def, isNotNull);
        expect(def!.id, 'nach_yomi');
      });

      test('chofetzChaim maps to chofetz_chaim_daily', () {
        final def = CalendarProgramRegistry.byHebcalCategory('chofetzChaim');
        expect(def, isNotNull);
        expect(def!.id, 'chofetz_chaim_daily');
      });

      test('kitzurShulchanAruch maps to kitzur_shulchan_aruch_yomi', () {
        final def =
            CalendarProgramRegistry.byHebcalCategory('kitzurShulchanAruch');
        expect(def, isNotNull);
        expect(def!.id, 'kitzur_shulchan_aruch_yomi');
      });

      test('unknown category returns null', () {
        expect(CalendarProgramRegistry.byHebcalCategory('unknown'), isNull);
      });
    });

    group('bySource', () {
      test('sefaria returns 9 programs (nach_yomi moved to hebcal)', () {
        final sefaria = CalendarProgramRegistry.bySource('sefaria');
        expect(sefaria.length, 9);
        expect(sefaria.any((p) => p.id == 'nach_yomi'), isFalse);
      });

      test('hebcal returns 3 programs (includes nach_yomi)', () {
        final hebcal = CalendarProgramRegistry.bySource('hebcal');
        expect(hebcal.length, 3);
        expect(hebcal.any((p) => p.id == 'nach_yomi'), isTrue);
        expect(hebcal.any((p) => p.id == 'chofetz_chaim_daily'), isTrue);
        expect(
          hebcal.any((p) => p.id == 'kitzur_shulchan_aruch_yomi'),
          isTrue,
        );
      });
    });

    group('all 6 previously working programs unchanged', () {
      final workingPrograms = {
        'daf_yomi': 'Daf Yomi',
        'yerushalmi_yomi': 'Yerushalmi Yomi',
        'daf_a_week': 'Daf a Week',
        'halakhah_yomit': 'Halakhah Yomit',
        'arukh_hashulchan_yomi': 'Arukh HaShulchan Yomi',
        'tanakh_yomi': 'Tanakh Yomi',
      };

      for (final entry in workingPrograms.entries) {
        test('${entry.key} still has apiKey "${entry.value}"', () {
          final def = CalendarProgramRegistry.byId(entry.key);
          expect(def, isNotNull);
          expect(def!.apiKey, entry.value);
          expect(def.apiSource, 'sefaria');
        });
      }
    });
  });
}
