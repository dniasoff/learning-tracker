// Story 2.7 (DNI-498) AC-9: the #08 ground-picker compositions as goldens
// — phone light, phone dark (dark tokens), and the tablet split with the
// picker as a right pane beside the sub-track detail (a stand-in detail:
// Story 2.6's screen is not on the integration branch yet). The rendered
// state: Zeraim expanded, Berakhot perek 1 learnt (Chazara), Peah in use
// by Rebbe, Berakhot perek 2 picked. No class-benchmark sync control
// exists (UX-DR-167).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_ground_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_pane.dart';

import '../../../../helpers/golden_font_loader.dart' show loadFonts;
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

Future<void> _state(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Expand Seder Zeraim'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Expand Mishnah Berakhot'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find
          .ancestor(
            of: find.text('Mishnah Berakhot 2'),
            matching: find.byType(InkWell),
          )
          .first,
      matching: find.byType(Checkbox),
    ),
  );
  await tester.pumpAndSettle();
}

GroundPickerWorld _world() => GroundPickerWorld(
  corpus: mishnayosCorpus(),
  commands: FakeLearningCommands(),
  learnt: {...mishnayosCorpus().leavesUnder(berakhot1)},
  tracks: [
    fixtureTrack(schoolId, 'School', curriculumId: engineCurriculum),
    fixtureTrack(
      rebbeId,
      'Rebbe',
      curriculumId: engineCurriculum,
      ground: const [peah],
    ),
  ],
);

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('School'),
        SizedBox(height: 16),
        AddGroundButton(subTrackId: schoolId, curriculumId: engineCurriculum),
      ],
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required Size size,
  required Widget body,
}) async {
  final world = _world();
  addTearDown(world.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(brightness: brightness),
      child: Scaffold(body: SafeArea(child: body)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => loadFonts());

  for (final brightness in Brightness.values) {
    testWidgets('phone ${brightness.name}', (tester) async {
      // The phone route's body (GroundPickerScreen) is the pane itself.
      await _pump(
        tester,
        brightness: brightness,
        size: phoneSize,
        body: GroundPickerPane(subTrackId: schoolId, onClose: () {}),
      );
      await _state(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/ground_picker_phone.${brightness.name}.png'),
      );
    });
  }

  testWidgets('tablet split', (tester) async {
    await _pump(
      tester,
      brightness: Brightness.light,
      size: tabletSize,
      body: const GroundPickerSplitView(detail: _Detail()),
    );
    await tester.tap(find.text('Add ground'));
    await tester.pumpAndSettle();
    await _state(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ground_picker_tablet.light.png'),
    );
  });
}
