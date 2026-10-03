// Story 2.10 (DNI-501) golden: the Up to… picker per screen #02 — phone
// sheet and tablet dialog, light and dark, English and Hebrew at large text.
//
// Baselines live in `goldens/up_to_picker.*.png` next to this file and were
// recorded with `flutter test --update-goldens` on this story's branch.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../helpers/up_to_fixtures.dart';

const _path = [
  'Mishnah Berakhot 1:3',
  'Mishnah Berakhot 1:4',
  'Mishnah Berakhot 1:5',
  'Mishnah Berakhot 2:1',
  'Mishnah Berakhot 2:2',
  'Mishnah Berakhot 2:3',
];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  useSurface(tester, size);
  await tester.pumpWidget(
    pumpApp(
      locale: locale,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      overrides: upToOverrides(
        state: fixtureLearnerState(
          subTracks: {
            schoolId: fixtureSubTrackState(
              schoolId,
              path: _path,
              recordedAhead: {'Mishnah Berakhot 1:5'},
            ),
          },
        ),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: UpToActionButton(
              key: const Key('trigger'),
              semanticsLabel: 'Record up to, School',
              onOpen: () => showUpToPicker(
                context,
                request: SubTrackUpToRequest(
                  subTrackId: schoolId,
                  curriculumId: engineCurriculum,
                  name: 'School',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('trigger')));
  await tester.pumpAndSettle();
  // Target 2:2, untick 2:1: the UJ-1 composition.
  await tester.tap(find.text('Berakhot 2:2'));
  await tester.pump();
  await tester.tap(find.byKey(const Key('upToRowTick-3')));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('phone sheet [${brightness.name}]', (tester) async {
      await _pump(tester, size: phoneSize, brightness: brightness);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/up_to_picker.phone.${brightness.name}.png'),
      );
    });

    testWidgets('tablet dialog [${brightness.name}]', (tester) async {
      await _pump(tester, size: tabletSize, brightness: brightness);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/up_to_picker.tablet.${brightness.name}.png'),
      );
    });
  }

  testWidgets('phone sheet, Hebrew at large text', (tester) async {
    await _pump(
      tester,
      size: phoneSize,
      brightness: Brightness.light,
      locale: const Locale('he'),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/up_to_picker.phone.he.large.png'),
    );
  });
}
