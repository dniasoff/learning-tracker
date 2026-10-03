// Story 2.9 (DNI-500) AC-1, AC-3, AC-4, AC-7, AC-9, AC-10 — the sub-track
// row's states and role gating, rendered in isolation.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_home_row.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_read_only.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

const _active = SubTrackHomeItem(
  subTrackId: schoolId,
  curriculumId: mishnayos,
  name: 'School',
  kind: SubTrackRowKind.active,
  position: berachos14,
  ticked: 3,
  remaining: 10,
);

const _groundless = SubTrackHomeItem(
  subTrackId: schoolId,
  curriculumId: mishnayos,
  name: 'School',
  kind: SubTrackRowKind.groundless,
);

const _allRecorded = SubTrackHomeItem(
  subTrackId: schoolId,
  curriculumId: mishnayos,
  name: 'School',
  kind: SubTrackRowKind.allRecorded,
  ticked: 12,
);

final class _Taps {
  int open = 0;
  int plusOne = 0;
  int upTo = 0;
  int addGround = 0;
}

Future<_Taps> _pump(
  WidgetTester tester,
  SubTrackHomeItem item,
  SubTrackViewerRole role, {
  bool capturing = false,
  Locale locale = const Locale('en'),
}) async {
  final taps = _Taps();
  await tester.pumpWidget(
    pumpApp(
      locale: locale,
      overrides: positionLabelOverrides(),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SubTrackHomeRow(
            item: item,
            role: role,
            capturing: capturing,
            onOpen: () => taps.open++,
            onPlusOne: () => taps.plusOne++,
            onUpTo: () => taps.upTo++,
            onAddGround: () => taps.addGround++,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

Finder _plusOne() => find.byKey(const Key('subTrackHomePlusOne-$schoolId'));
Finder _upTo() => find.byKey(const Key('subTrackHomeUpTo-$schoolId'));
Finder _addGround() => find.byKey(const Key('subTrackHomeAddGround-$schoolId'));

/// Whether [finder]'s control renders as a `Disabled action` (40%).
bool _dimmed(WidgetTester tester, Finder finder) {
  final opacity = find.descendant(of: finder, matching: find.byType(Opacity));
  if (opacity.evaluate().isEmpty) return false;
  return tester.widget<Opacity>(opacity.first).opacity ==
      subTrackDisabledOpacity;
}

void main() {
  group('active row (AC-1)', () {
    testWidgets('name, "Next: {position}", exactly Up to… and +1, both '
        '≥ 48dp, no badges', (tester) async {
      await _pump(tester, _active, SubTrackViewerRole.child);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Next: Berachos 1:4'), findsOneWidget);
      expect(find.text('Up to…'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      for (final f in [_plusOne(), _upTo()]) {
        final size = tester.getSize(f);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(_dimmed(tester, f), isFalse);
      }
      // No source, rate or pace badge: only the two texts and two actions.
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('+1, Up to… and the body keep their own handlers (AC-7)', (
      tester,
    ) async {
      final taps = await _pump(tester, _active, SubTrackViewerRole.parent);
      await tester.tap(_plusOne());
      await tester.tap(_upTo());
      await tester.tap(find.text('School'));
      expect(taps.plusOne, 1);
      expect(taps.upTo, 1);
      expect(taps.open, 1);
    });

    testWidgets('while a +1 is in flight a second tap records nothing and '
        'does not open the detail', (tester) async {
      final taps = await _pump(
        tester,
        _active,
        SubTrackViewerRole.child,
        capturing: true,
      );
      await tester.tap(_plusOne());
      expect(taps.plusOne, 0);
      expect(taps.open, 0);
      expect(_dimmed(tester, _plusOne()), isFalse);
    });

    testWidgets('semantics read the row and both actions (AC-10)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _active, SubTrackViewerRole.child);
      expect(
        find.bySemanticsLabel('School, next Berachos 1:4'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Record one mishna for School'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Record up to, School'), findsOneWidget);
      handle.dispose();
    });
  });

  group('groundless row (AC-3)', () {
    testWidgets('child: "No ground yet", +1 and Up to… disabled at 40% and '
        'announced disabled; tapping them does nothing', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = await _pump(tester, _groundless, SubTrackViewerRole.child);
      expect(find.text('No ground yet'), findsOneWidget);
      expect(find.textContaining('Next:'), findsNothing);
      expect(_addGround(), findsNothing);
      for (final f in [_plusOne(), _upTo()]) {
        expect(_dimmed(tester, f), isTrue);
      }
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Record one mishna for School'),
        ),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Record up to, School')),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      await tester.tap(_plusOne(), warnIfMissed: false);
      await tester.tap(_upTo(), warnIfMissed: false);
      expect(taps.plusOne + taps.upTo + taps.open, 0);
      handle.dispose();
    });

    testWidgets('parent: Add ground opens the ground picker; no +1 / Up to…', (
      tester,
    ) async {
      final taps = await _pump(tester, _groundless, SubTrackViewerRole.parent);
      expect(find.text('No ground yet'), findsOneWidget);
      expect(_plusOne(), findsNothing);
      expect(_upTo(), findsNothing);
      expect(_dimmed(tester, _addGround()), isFalse);
      expect(tester.getSize(_addGround()).height, greaterThanOrEqualTo(48));
      await tester.tap(_addGround());
      expect(taps.addGround, 1);
      expect(taps.open, 0);
    });
  });

  group('all ground recorded (AC-4)', () {
    testWidgets('child: assumed copy, both actions disabled', (tester) async {
      await _pump(tester, _allRecorded, SubTrackViewerRole.child);
      expect(find.text('All ground recorded'), findsOneWidget);
      expect(_dimmed(tester, _plusOne()), isTrue);
      expect(_dimmed(tester, _upTo()), isTrue);
      expect(_addGround(), findsNothing);
    });

    testWidgets('parent: Add ground', (tester) async {
      final taps = await _pump(tester, _allRecorded, SubTrackViewerRole.parent);
      expect(find.text('All ground recorded'), findsOneWidget);
      await tester.tap(_addGround());
      expect(taps.addGround, 1);
      expect(_plusOne(), findsNothing);
    });
  });

  testWidgets('the body opens the detail for every role and state (AC-7)', (
    tester,
  ) async {
    for (final item in [_active, _groundless, _allRecorded]) {
      for (final role in SubTrackViewerRole.values) {
        final taps = await _pump(tester, item, role);
        await tester.tap(find.text('School'));
        expect(taps.open, 1, reason: '${item.kind} / $role');
      }
    }
  });

  testWidgets('max text scale in Hebrew: name and position stack above the '
      'actions, nothing clips (AC-10)', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      pumpApp(
        locale: const Locale('he'),
        overrides: positionLabelOverrides(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SubTrackHomeRow(
              item: _active,
              role: SubTrackViewerRole.child,
              onOpen: () {},
              onPlusOne: () {},
              onUpTo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(tester.takeException(), isNull);
    final line = find.byKey(const Key('subTrackHomeRowLine-$schoolId'));
    expect(
      tester.getBottomLeft(line).dy,
      lessThan(tester.getTopLeft(_plusOne()).dy),
    );
    // RTL: the actions sit at the start (left) edge's mirror — the end edge
    // is on the left under Hebrew.
    expect(
      tester.getCenter(_plusOne()).dx,
      lessThan(tester.getCenter(find.text('School')).dx),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('הבא: Berachos 1:4'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
