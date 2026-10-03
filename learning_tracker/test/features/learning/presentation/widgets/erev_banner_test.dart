// DNI-504 AC-1 / AC-6 / AC-11: the erev banner's label per lock kind and
// Hebrew Terms setting, and its lock time in the device's clock format.
// Learn-tab placement and window boundaries are covered by
// test/features/learning/presentation/screens/erev_learning_screen_test.dart.
@Tags(['learning'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/erev_banner.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/pump_app.dart';

class _HebrewTerms extends UseHebrewTerms {
  _HebrewTerms(this._on);
  final bool _on;
  @override
  bool build() => _on;
}

/// The erev window at 09:00 New York time on [y]-[m]-[d], Lakewood.
ErevWindow _window(int y, int m, int d) {
  final now = LearnerZone.of(
    'America/New_York',
  ).at(DateTime.utc(y, m, d), hour: 9);
  return erevWindowAt(constantHistory(lakewood), now)!;
}

Future<void> _pump(
  WidgetTester tester,
  ErevWindow window, {
  bool hebrewTerms = false,
  bool use24h = false,
}) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        useHebrewTermsProvider.overrideWith(() => _HebrewTerms(hebrewTerms)),
        currentTransliterationVariantProvider.overrideWithValue(
          TransliterationVariant.ashkenazi,
        ),
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
        child: child!,
      ),
      child: Scaffold(body: ErevBanner(window: window)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a Shabbos lock: Shabbos Kodesh, or שבת קודש with Hebrew '
      'Terms', (tester) async {
    final window = _window(2026, 10, 9);
    expect(window.kind, ErevKind.shabbos);
    await _pump(tester, window);
    expect(find.text('Shabbos Kodesh'), findsOneWidget);
    expect(find.textContaining('Shabbos begins at'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, window, hebrewTerms: true);
    expect(find.text('שבת קודש'), findsOneWidget);
  });

  testWidgets('a chained yom tov and Shabbos lock names both', (tester) async {
    final window = _window(2027, 4, 21);
    expect(window.kind, ErevKind.yomTovAndShabbos);
    await _pump(tester, window);
    expect(find.text('Yom Tov & Shabbos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, window, hebrewTerms: true);
    expect(find.text('יום טוב ושבת'), findsOneWidget);
  });

  testWidgets('the lock time follows the 24-hour setting and is the '
      'window\'s own lock start', (tester) async {
    final window = _window(2026, 10, 9);
    final local = window.lockStartLocal;
    await _pump(tester, window, use24h: true);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    expect(find.textContaining('begins at $hh:$mm'), findsOneWidget);
  });

  testWidgets('one announcement carries the label and the time', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _window(2026, 10, 9));
    final label = tester.getSemantics(find.byType(ErevBanner)).label;
    expect(label, startsWith('Shabbos Kodesh. '));
    expect(label, contains('begins at'));
    semantics.dispose();
  });
}
