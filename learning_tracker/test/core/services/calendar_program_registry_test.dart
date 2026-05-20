import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';

void main() {
  group('CalendarProgramRegistry', () {
    test('has exactly 20 programs', () {
      expect(CalendarProgramRegistry.programs.length, 20);
    });

    group('byApiKey - Hebcal programs', () {
      test('mishnayomi maps to mishna_yomit', () {
        final def = CalendarProgramRegistry.byApiKey('mishnayomi');
        expect(def, isNotNull);
        expect(def!.id, 'mishna_yomit');
      });

      test('dailyRambam1 maps to rambam_1_chapter', () {
        final def = CalendarProgramRegistry.byApiKey('dailyRambam1');
        expect(def, isNotNull);
        expect(def!.id, 'rambam_1_chapter');
      });

      test('dailyRambam3 maps to rambam_3_chapters', () {
        final def = CalendarProgramRegistry.byApiKey('dailyRambam3');
        expect(def, isNotNull);
        expect(def!.id, 'rambam_3_chapters');
      });

      test('dafyomi maps correctly (regression check)', () {
        final def = CalendarProgramRegistry.byApiKey('dafyomi');
        expect(def, isNotNull);
        expect(def!.id, 'daf_yomi');
      });

      test('stale Sefaria-style keys return null', () {
        expect(CalendarProgramRegistry.byApiKey('Daily Mishnah'), isNull);
        expect(CalendarProgramRegistry.byApiKey('Daily Rambam'), isNull);
        expect(
          CalendarProgramRegistry.byApiKey('Daily Rambam (3 Chapters)'),
          isNull,
        );
        expect(CalendarProgramRegistry.byApiKey('Daf Yomi'), isNull);
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
        final def = CalendarProgramRegistry.byHebcalCategory(
          'kitzurShulchanAruch',
        );
        expect(def, isNotNull);
        expect(def!.id, 'kitzur_shulchan_aruch_yomi');
      });

      test('unknown category returns null', () {
        expect(CalendarProgramRegistry.byHebcalCategory('unknown'), isNull);
      });
    });

    group('bySource', () {
      test('sefaria returns 1 program (halakhah_yomit only)', () {
        final sefaria = CalendarProgramRegistry.bySource('sefaria');
        expect(sefaria.length, 1);
        expect(sefaria.any((p) => p.id == 'halakhah_yomit'), isTrue);
        expect(sefaria.any((p) => p.id == 'nach_yomi'), isFalse);
      });

      test('hebcal returns 17 programs', () {
        final hebcal = CalendarProgramRegistry.bySource('hebcal');
        expect(hebcal.length, 17);
        expect(hebcal.any((p) => p.id == 'nach_yomi'), isTrue);
        expect(hebcal.any((p) => p.id == 'chofetz_chaim_daily'), isTrue);
        expect(hebcal.any((p) => p.id == 'kitzur_shulchan_aruch_yomi'), isTrue);
      });

      test('local returns 2 programs', () {
        final local = CalendarProgramRegistry.bySource('local');
        expect(local.length, 2);
        expect(local.any((p) => p.id == 'dirshu_kinyan_torah'), isTrue);
        expect(local.any((p) => p.id == 'dirshu_kinyan_yerushalmi'), isTrue);
      });
    });

    group('key programs have correct apiSource and apiKey', () {
      final programs = {
        'daf_yomi': ('hebcal', 'dafyomi'),
        'yerushalmi_yomi': ('hebcal', 'yerushalmi'),
        'daf_a_week': ('hebcal', 'dafWeekly'),
        'halakhah_yomit': ('sefaria', 'Halakhah Yomit'),
        'arukh_hashulchan_yomi': ('hebcal', 'arukhHaShulchanYomi'),
        'tanakh_yomi': ('hebcal', 'tanakhYomi'),
      };

      for (final entry in programs.entries) {
        test('${entry.key} has expected apiSource and apiKey', () {
          final def = CalendarProgramRegistry.byId(entry.key);
          expect(def, isNotNull);
          expect(def!.apiSource, entry.value.$1);
          expect(def.apiKey, entry.value.$2);
        });
      }
    });
  });
}
