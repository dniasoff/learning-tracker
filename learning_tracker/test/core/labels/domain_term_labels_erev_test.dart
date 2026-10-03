// DNI-504 T5: the erev banner's lock labels follow the Hebrew Terms
// setting (AC-1, A-2): Latin transliteration with it off (nusach-aware
// Shabbos/Shabbat), Hebrew script with it on.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

void main() {
  const latin = DomainTermLabels(false);
  const hebrew = DomainTermLabels(true);

  test('Shabbos Kodesh', () {
    expect(latin.shabbosKodesh(), 'Shabbos Kodesh');
    expect(
      latin.shabbosKodesh(variant: TransliterationVariant.sephardi),
      'Shabbat Kodesh',
    );
    expect(hebrew.shabbosKodesh(), 'שבת קודש');
  });

  test('Yom Tov, Yom Tov & Shabbos, Yom Kippur', () {
    expect(latin.yomTov, 'Yom Tov');
    expect(hebrew.yomTov, 'יום טוב');
    expect(latin.yomTovAndShabbos(), 'Yom Tov & Shabbos');
    expect(hebrew.yomTovAndShabbos(), 'יום טוב ושבת');
    expect(latin.yomKippur, 'Yom Kippur');
    expect(hebrew.yomKippur, 'יום כיפור');
  });
}
