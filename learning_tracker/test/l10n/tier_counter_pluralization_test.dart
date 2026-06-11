/// Regression test: TIER-COUNTER-PLURAL-R2 — the engagement/achievement/
/// lifetime/points tier-counter strings must be grammatical for count==1.
///
/// Before the fix the ARB values were fixed templates (e.g. "{count} items in
/// lifetime", "{count} pts", he "{count} פריטים"), so count==1 rendered the
/// plural noun ("1 items in lifetime", "1 pts", "1 פריטים"). The fix converts
/// each to an ICU plural with a singular =1/one branch (and the Hebrew dual
/// two branch), keeping every existing placeholder — notably {siyumimTerm}.
///
/// Call sites are unchanged (same getter + count arg), so this is verified
/// purely through the generated AppLocalizations.
@Tags(['l10n', 'tier_counter_plural_r2'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations he;

  setUp(() {
    en = AppLocalizationsEn();
    he = AppLocalizationsHe();
  });

  group('TIER-COUNTER-PLURAL-R2: English count==1 is grammatical', () {
    test('tierCounterLifetimeItems singular reads "1 item in lifetime"', () {
      expect(en.tierCounterLifetimeItems(1), '1 item in lifetime');
      expect(en.tierCounterLifetimeItems(5), '5 items in lifetime');
    });

    test('tierCounterPoints singular reads "1 pt"', () {
      expect(en.tierCounterPoints(1), '1 pt');
      expect(en.tierCounterPoints(7), '7 pts');
    });

    test('tierCounterStreakDays stays "N-day streak" for 1 and many', () {
      expect(en.tierCounterStreakDays(1), '1-day streak');
      expect(en.tierCounterStreakDays(9), '9-day streak');
    });

    test('tierCounterSiyumimEarned keeps the {siyumimTerm} placeholder', () {
      expect(en.tierCounterSiyumimEarned(1, 'Siyumim'), '1 Siyumim earned');
      expect(en.tierCounterSiyumimEarned(4, 'Siyumim'), '4 Siyumim earned');
    });
  });

  group('TIER-COUNTER-PLURAL-R2: Hebrew dual forms', () {
    test('tierCounterLifetimeItems one/two/other', () {
      expect(he.tierCounterLifetimeItems(1), 'פריט אחד');
      expect(he.tierCounterLifetimeItems(2), 'שני פריטים');
      expect(he.tierCounterLifetimeItems(5), '5 פריטים');
    });

    test('tierCounterPoints one/two/other', () {
      expect(he.tierCounterPoints(1), 'נקודה אחת');
      expect(he.tierCounterPoints(2), 'שתי נקודות');
      expect(he.tierCounterPoints(8), '8 נקודות');
    });

    test('tierCounterStreakDays one/two/other', () {
      expect(he.tierCounterStreakDays(1), 'רצף של יום אחד');
      expect(he.tierCounterStreakDays(2), 'רצף של יומיים');
      expect(he.tierCounterStreakDays(9), 'רצף של 9 ימים');
    });

    test('tierCounterSiyumimEarned keeps {siyumimTerm} across all forms', () {
      expect(he.tierCounterSiyumimEarned(1, 'סיומים'), 'סיומים אחד');
      expect(he.tierCounterSiyumimEarned(2, 'סיומים'), 'שני סיומים');
      expect(he.tierCounterSiyumimEarned(6, 'סיומים'), '6 סיומים');
    });
  });
}
