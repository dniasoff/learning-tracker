// Story 4.3 (DNI-511) AC-8 golden: screen #11 My talmidim — phone light,
// phone dark (dark tokens) and the tablet split with a selected learner.
// The rendered roster: on track, too early to tell, behind pace and a
// groundless Rebbe track with Add ground, then the access note.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';

import '../../../helpers/golden_font_loader.dart' show loadFonts;
import '../talmidim_fixtures.dart';

const _phone = Size(412, 915);
const _tablet = Size(1280, 800);

FakeTalmidInputs _inputs() => FakeTalmidInputs()
  ..states[talmidScope(1)] = AsyncData(talmidState(sub: rebbeTrack()))
  ..states[talmidScope(2)] = AsyncData(
    talmidState(
      status: ProjectionStatus.tooEarly,
      sub: rebbeTrack(position: 'Mishnah Berakhot 2:4'),
    ),
  )
  ..states[talmidScope(3)] = AsyncData(
    talmidState(
      status: ProjectionStatus.behindPace,
      sub: rebbeTrack(position: 'Mishnah Shabbat 5:1'),
    ),
  )
  ..states[talmidScope(4)] = AsyncData(
    talmidState(
      status: ProjectionStatus.noDeadline,
      sub: rebbeTrack(position: null),
    ),
  );

ScriptedTutorRosterRepository _roster() => ScriptedTutorRosterRepository([
  [
    talmidEntry(1, name: 'Yehuda K.'),
    talmidEntry(2, name: 'Moshe L.'),
    talmidEntry(3, name: 'Avraham S.'),
    talmidEntry(4, name: 'Dovid R.'),
  ],
]);

void main() {
  setUpAll(() async => loadFonts());

  for (final brightness in Brightness.values) {
    testWidgets('phone ${brightness.name}', (tester) async {
      await pumpTalmidim(
        tester,
        repo: _roster(),
        inputs: _inputs(),
        size: _phone,
        theme: AppTheme.themeFor(brightness: brightness),
        debugBanner: false,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/my_talmidim_phone.${brightness.name}.png'),
      );
    });
  }

  testWidgets('tablet split with a selected learner', (tester) async {
    await pumpTalmidim(
      tester,
      repo: _roster(),
      inputs: _inputs(),
      size: _tablet,
      theme: AppTheme.themeFor(brightness: Brightness.light),
      debugBanner: false,
    );
    await tester.tap(find.byKey(const Key('talmidRow-grant-1')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/my_talmidim_tablet.light.png'),
    );
  });
}
