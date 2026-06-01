// ignore_for_file: avoid_print
import 'lib/sefaria_mongo.dart';

/// Validates the Mongo ref→text resolution on the required sample refs.
Future<void> main() async {
  final m = await SefariaMongo.connect('mongodb://127.0.0.1:27117/sefaria');
  await m.warmTitles();

  final samples = <String>[
    'Genesis 1:1',
    'Berakhot 2a',
    'Mishnah Berakhot 1:1',
    'Psalms 97-103', // English range
    "Arukh HaShulchan, Yoreh De'ah 199:2-11",
    'Mishneh Torah, Sabbath 12:18',
    'Shulchan Arukh, Orach Chayim 352:2',
    'Sefer HaMitzvot, Positive Commandments 194',
    'Kitzur Shulchan Arukh 44:14',
  ];

  bool hasMarkup(String s) =>
      s.contains('<sup') || s.contains('<i ') || s.contains('class="footnote');
  for (final ref in samples) {
    final r = await m.resolve(ref);
    print('--- $ref');
    print('  he(${r.he.length}): ${_clip(r.he)}');
    print('  en(${r.en.length}): ${_clip(r.en)}');
    print('  markup he=${hasMarkup(r.he)} en=${hasMarkup(r.en)}');
  }

  await m.close();
}

String _clip(String s) => s.length <= 110 ? s : '${s.substring(0, 110)}…';
