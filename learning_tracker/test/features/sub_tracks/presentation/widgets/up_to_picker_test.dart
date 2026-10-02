// Story 2.10 (DNI-501) widget: the Up to… picker (AC-1, AC-2, AC-4, AC-6,
// AC-7).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/up_to_selection.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/up_to_picker_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capture_section.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_row.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/up_to_picker.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';
import '../../helpers/up_to_fixtures.dart';

const _path = [
  'Mishnah Berakhot 1:3',
  'Mishnah Berakhot 1:4',
  'Mishnah Berakhot 1:5',
  'Mishnah Berakhot 2:1',
  'Mishnah Berakhot 2:2',
  'Mishnah Berakhot 2:3',
];

final _request = SubTrackUpToRequest(
  subTrackId: schoolId,
  curriculumId: engineCurriculum,
  name: 'School',
);

/// A host whose Up to… button opens the picker and keeps the result.
class _Host extends StatefulWidget {
  const _Host({required this.request});

  final UpToRequest request;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  UpToSelection? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: UpToActionButton(
        key: const Key('trigger'),
        semanticsLabel: 'Record up to, School',
        onOpen: () async {
          closed = false;
          result = await showUpToPicker(context, request: widget.request);
          closed = true;
        },
      ),
    ),
  );
}

Future<_HostState> _open(
  WidgetTester tester, {
  Size size = phoneSize,
  List<String> path = _path,
  Set<String> recordedAhead = const {},
  bool exhausted = false,
  UpToRequest? request,
}) async {
  useSurface(tester, size);
  await tester.pumpWidget(
    pumpApp(
      overrides: upToOverrides(
        state: fixtureLearnerState(
          subTracks: {
            schoolId: fixtureSubTrackState(
              schoolId,
              path: path,
              recordedAhead: recordedAhead,
              exhausted: exhausted,
            ),
          },
        ),
      ),
      child: _Host(request: request ?? _request),
    ),
  );
  await tester.tap(find.byKey(const Key('trigger')));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

String _recordLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('upToRecord')),
        matching: find.byType(Text),
      ),
    )
    .data!;

bool _recordEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('upToRecord'))).enabled;

void main() {
  group('AC-1 presentation', () {
    testWidgets('phone: a rounded-top sheet with title, instruction, the '
        'ordered leaves from the position, Cancel and a unit-aware Record', (
      tester,
    ) async {
      await _open(tester);
      expect(find.byKey(const Key('upToPickerSheet')), findsOneWidget);
      expect(find.byKey(const Key('upToPickerDialog')), findsNothing);
      expect(find.text('School · up to…'), findsOneWidget);
      expect(find.text('Tap the last mishna you learnt'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Berakhot 1:3')).dy;
      final second = tester.getTopLeft(find.text('Berakhot 1:4')).dy;
      expect(first, lessThan(second));
      expect(find.byKey(const Key('upToCancel')), findsOneWidget);
      expect(_recordLabel(tester), 'Record 0 mishnayos');
      expect(_recordEnabled(tester), isFalse);
      // No source badge or picker in the sheet (screens.md drift note).
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.text('Home'), findsNothing);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(
        sheet.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      );
    });

    testWidgets('tablet: a centred dialog at most 480px wide', (tester) async {
      await _open(tester, size: tabletSize);
      expect(find.byKey(const Key('upToPickerDialog')), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final width = tester.getSize(find.byType(UpToPicker)).width;
      expect(width, lessThanOrEqualTo(upToDialogMaxWidth));
      final center = tester.getCenter(find.byType(UpToPicker)).dx;
      expect(center, closeTo(tabletSize.width / 2, 1));
    });

    testWidgets('rows load lazily: a long ground builds only what is '
        'visible', (tester) async {
      final long = [for (var i = 1; i <= 400; i++) 'Mishnah Long $i'];
      await _open(tester, path: long);
      expect(find.text('Long 1'), findsOneWidget);
      expect(find.text('Long 400'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Long 120'),
        400,
        scrollable: find.descendant(
          of: find.byKey(const Key('upToPickerList')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Long 120'), findsOneWidget);
    });

    testWidgets('focus moves to the title, and closing returns it to the '
        'Up to… button (UX-DR-160)', (tester) async {
      await _open(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'upToPickerTitle');
      await tester.tap(find.byKey(const Key('upToCancel')));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'upToAction');
    });
  });

  group('AC-2 selection', () {
    testWidgets('a target includes the run; untick and re-tick update the '
        'live count', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Berakhot 2:2'));
      await tester.pump();
      expect(_recordLabel(tester), 'Record 5 mishnayos');
      expect(_recordEnabled(tester), isTrue);
      await tester.tap(find.byKey(const Key('upToRowTick-3')));
      await tester.pump();
      expect(_recordLabel(tester), 'Record 4 mishnayos');
      expect(find.text('skipped'), findsOneWidget);
      await tester.tap(find.byKey(const Key('upToRowTick-3')));
      await tester.pump();
      expect(_recordLabel(tester), 'Record 5 mishnayos');
    });

    testWidgets('one included row uses the singular unit', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Berakhot 1:3'));
      await tester.pump();
      expect(_recordLabel(tester), 'Record 1 mishna');
    });

    testWidgets('already-recorded rows are labelled, not selectable and '
        'never counted', (tester) async {
      await _open(tester, recordedAhead: {'Mishnah Berakhot 1:5'});
      expect(find.text('already recorded'), findsOneWidget);
      final tick = tester.widget<Checkbox>(
        find.byKey(const Key('upToRowTick-2')),
      );
      expect(tick.onChanged, isNull);
      await tester.tap(find.text('Berakhot 1:5'));
      await tester.pump();
      expect(_recordLabel(tester), 'Record 0 mishnayos');
      await tester.tap(find.text('Berakhot 2:1'));
      await tester.pump();
      expect(_recordLabel(tester), 'Record 3 mishnayos');
    });

    testWidgets('Record pops the included leaves in track order', (
      tester,
    ) async {
      final host = await _open(tester);
      await tester.tap(find.text('Berakhot 2:2'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('upToRowTick-3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('upToRecord')));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.result!.includedRefs, [
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 1:4',
        'Mishnah Berakhot 1:5',
        'Mishnah Berakhot 2:2',
      ]);
      expect(host.result!.positionAfterRecord, 'Mishnah Berakhot 2:1');
    });
  });

  group('AC-4 dismissal records nothing', () {
    testWidgets('Cancel', (tester) async {
      final host = await _open(tester);
      await tester.tap(find.text('Berakhot 2:2'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('upToCancel')));
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.result, isNull);
    });

    testWidgets('swipe down', (tester) async {
      final host = await _open(tester);
      await tester.tap(find.text('Berakhot 2:2'));
      await tester.pump();
      await tester.fling(
        find.byKey(const Key('upToPickerTitle')),
        const Offset(0, 600),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(UpToPicker), findsNothing);
      expect(host.closed, isTrue);
      expect(host.result, isNull);
    });

    testWidgets('platform back, on phone and tablet', (tester) async {
      for (final size in [phoneSize, tabletSize]) {
        final host = await _open(tester, size: size);
        await tester.tap(find.text('Berakhot 2:2'));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(UpToPicker), findsNothing);
        expect(host.result, isNull);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'upToAction');
      }
    });
  });

  group('AC-6 groundless and exhausted', () {
    testWidgets('a groundless row keeps Up to… disabled', (tester) async {
      var opened = false;
      final track = fixtureSubTrack(schoolId, 'School', ground: const []);
      await tester.pumpWidget(
        pumpApp(
          overrides: upToLabelOverrides(),
          child: Scaffold(
            body: SubTrackRow(
              item: OnHomeSubTrack(
                track: track,
                state: fixtureSubTrackState(schoolId),
              ),
              position: null,
              onUpTo: () async => opened = true,
              onPlusOne: () => opened = true,
            ),
          ),
        ),
      );
      expect(find.text('No ground yet'), findsOneWidget);
      await tester.tap(find.byKey(Key('subTrackUpTo-$schoolId')));
      await tester.tap(find.byKey(Key('subTrackPlusOne-$schoolId')));
      await tester.pump();
      expect(opened, isFalse);
    });

    testWidgets('an exhausted track shows the exact message and no '
        'actionable list', (tester) async {
      await _open(tester, exhausted: true, path: const []);
      expect(
        find.text("No more mishnayos in School's ground."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('upToPickerList')), findsNothing);
      expect(find.byKey(const Key('upToRecord')), findsNothing);
      expect(find.text('Tap the last mishna you learnt'), findsNothing);
    });

    testWidgets('every leaf after the position already recorded counts as '
        'exhausted', (tester) async {
      await _open(
        tester,
        path: const ['Mishnah Berakhot 2:2'],
        recordedAhead: const {'Mishnah Berakhot 2:2'},
      );
      expect(
        find.text("No more mishnayos in School's ground."),
        findsOneWidget,
      );
    });
  });

  group('AC-7 load failure', () {
    testWidgets('an inline error with retry inside the sheet; Record '
        'disabled', (tester) async {
      var attempts = 0;
      useSurface(tester, phoneSize);
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ...learnerStateOverrides(scope: c0Scope()),
            ...upToLabelOverrides(),
            learnerStateProvider.overrideWith((ref, _) {
              attempts++;
              return Stream.error(StateError('offline'));
            }),
          ],
          child: _Host(request: _request),
        ),
      );
      await tester.tap(find.byKey(const Key('trigger')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upToPickerError')), findsOneWidget);
      expect(_recordEnabled(tester), isFalse);
      final before = attempts;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, greaterThan(before));
      expect(_recordEnabled(tester), isFalse);
    });
  });

  group('AC-11 tutor device', () {
    testWidgets('sub-track Up to… and +1 are visible but disabled; no '
        'sub-track write reaches LearningCommands', (tester) async {
      final commands = FakeLearningCommands();
      useSurface(tester, phoneSize);
      await tester.pumpWidget(
        pumpApp(
          overrides: [
            ...learnerStateOverrides(scope: c0Scope(), commands: commands),
            ...upToLabelOverrides(),
            onHomeSubTracksProvider.overrideWith(
              (ref) => AsyncData([
                OnHomeSubTrack(
                  track: fixtureSubTrack(schoolId, 'School'),
                  state: fixtureSubTrackState(schoolId, path: _path),
                ),
              ]),
            ),
            subTrackWritesAllowedProvider.overrideWithValue(false),
          ],
          child: const Scaffold(body: SubTrackCaptureSection()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key('subTrackUpTo-$schoolId')), findsOneWidget);
      expect(find.byKey(Key('subTrackPlusOne-$schoolId')), findsOneWidget);
      await tester.tap(find.byKey(Key('subTrackUpTo-$schoolId')));
      await tester.tap(find.byKey(Key('subTrackPlusOne-$schoolId')));
      await tester.pumpAndSettle();
      expect(find.byType(UpToPicker), findsNothing);
      expect(
        commands.calls.where((c) => c.name != 'watchPendingFailures'),
        isEmpty,
      );
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(Key('subTrackPlusOne-$schoolId')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.4);
    });
  });
}
