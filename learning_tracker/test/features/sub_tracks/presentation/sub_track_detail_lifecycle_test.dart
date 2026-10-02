/// Story 2.8 (DNI-499) widget acceptance on the sub-track detail:
/// *Add next year* (AC-1, AC-2), ⋮ Delete / End (AC-3, AC-4) and the
/// read-only ended detail (AC-5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_lifecycle_detail_screen.dart';

import '../../../helpers/pump_app.dart';
import 'sub_track_lifecycle_harness.dart';

Future<void> _openDetail(
  WidgetTester tester,
  LifecycleWorld world,
  String id,
) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      child: LifecycleHubHost(ids: [id], open: openSubTrackLifecycleDetail),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('open:$id')));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

String _field(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

final _pill = find.byKey(const ValueKey('subTrackAddNextYear'));

void main() {
  group('AC-1 Add next year opens a copied school-year form', () {
    testWidgets('prefilled for Y+1 with empty ground; every field editable; '
        'save creates a new ULID and leaves the source unchanged', (
      tester,
    ) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);

      expect(find.text('Add next year (2027–28)'), findsOneWidget);
      await tester.tap(_pill);
      await tester.pumpAndSettle();

      expect(find.text('School year 2027–28'), findsOneWidget);
      expect(_field(tester, 'subTrackNextYearName'), 'School');
      expect(_field(tester, 'subTrackNextYearRate'), '8');
      expect(_field(tester, 'subTrackNextYearWeeks'), '36');
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('subTrackNextYearShabbos')),
            )
            .value,
        isTrue,
      );
      expect(find.text('September'), findsOneWidget);
      expect(find.text('July'), findsOneWidget);

      // Every field stays editable before Save sub-track.
      await _enter(tester, 'subTrackNextYearName', 'School (Rebbe G)');
      await _enter(tester, 'subTrackNextYearRate', '10');
      await _enter(tester, 'subTrackNextYearWeeks', '35');
      await tester.tap(find.byKey(const ValueKey('subTrackNextYearShabbos')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('subTrackNextYearEndMonth')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('June').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('subTrackNextYearSave')),
      );
      await tester.tap(find.byKey(const ValueKey('subTrackNextYearSave')));
      await tester.pumpAndSettle();

      expect(world.commands.calls, ['createSubTrack(addNextYear)']);
      expect(world.stored, hasLength(2));
      final created = world.stored.firstWhere((t) => t.id != source.id);
      expect(created.id, isNot(source.id));
      expect(created.name, 'School (Rebbe G)');
      expect(created.type, SubTrackType.schoolYear);
      expect(created.academicYear, 2027);
      expect(created.windowStart, '2027-09-01');
      expect(created.windowEnd, '2028-06-30');
      expect(created.ratePerWeek, 10);
      expect(created.weeksPerYear, 35);
      expect(created.learnsOnShabbos, isFalse);
      expect(created.ground, isEmpty);
      expect(world.stored.firstWhere((t) => t.id == source.id), source);
      expect(
        world.analytics.lifecycles.single.action,
        SubTrackLifecycleAction.addNextYear,
      );
      // Back on the source's detail, with a confirmation.
      expect(find.text('School (Rebbe G) added for 2027–28'), findsOneWidget);
      expect(
        find.byKey(ValueKey('subTrackLifecycleDetail:${source.id}')),
        findsOneWidget,
      );
    });

    testWidgets('a year another device took after render is refused: no row, '
        'the form keeps its input and says why', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      await tester.tap(_pill);
      await tester.pumpAndSettle();
      await _enter(tester, 'subTrackNextYearName', 'School 2');

      // Another device saves 2027–28 first.
      final other = schoolYear(n: 9, name: 'Elsewhere', academicYear: 2027);
      world.repo.seed(world.scope, [other]);

      await tester.ensureVisible(
        find.byKey(const ValueKey('subTrackNextYearSave')),
      );
      await tester.tap(find.byKey(const ValueKey('subTrackNextYearSave')));
      await tester.pumpAndSettle();

      expect(
        find.text('2027–28 already has a school-year sub-track'),
        findsOneWidget,
      );
      expect(_field(tester, 'subTrackNextYearName'), 'School 2');
      expect(world.stored.map((t) => t.id).toSet(), {source.id, other.id});
      expect(world.repo.entries, isEmpty);
      expect(world.analytics.lifecycles, isEmpty);
    });

    testWidgets('an empty name or a zero rate is not saved', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      await tester.tap(_pill);
      await tester.pumpAndSettle();
      await _enter(tester, 'subTrackNextYearName', '  ');
      await _enter(tester, 'subTrackNextYearRate', '0');
      await tester.ensureVisible(
        find.byKey(const ValueKey('subTrackNextYearSave')),
      );
      await tester.tap(find.byKey(const ValueKey('subTrackNextYearSave')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter a number above 0'), findsOneWidget);
      expect(world.commands.calls, isEmpty);
    });
  });

  group('AC-2 next year unavailable', () {
    Future<void> expectDisabled(
      WidgetTester tester,
      LifecycleWorld world,
      String reason,
    ) async {
      await _openDetail(tester, world, lifecycleId(1));
      expect(_pill, findsOneWidget, reason: 'stays visible');
      final button = tester.widget<OutlinedButton>(_pill);
      expect(button.onPressed, isNull);
      expect(
        tester.getSemantics(_pill),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      expect(find.text(reason), findsOneWidget);
      await tester.tap(_pill, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Next school year'), findsNothing);
      expect(world.commands.calls, isEmpty);
    }

    testWidgets('Y+1 already has a non-ended school year', (tester) async {
      final world = LifecycleWorld([
        schoolYear(),
        schoolYear(n: 3, name: 'Next', academicYear: 2027),
      ]);
      addTearDown(world.dispose);
      await expectDisabled(
        tester,
        world,
        '2027–28 already has a school-year sub-track',
      );
    });

    testWidgets('Y+1 is past the picker range', (tester) async {
      final world = LifecycleWorld([schoolYear()], deadline: '2027-06-30');
      addTearDown(world.dispose);
      await expectDisabled(
        tester,
        world,
        '2027–28 is past the years you can plan',
      );
    });

    testWidgets('an ended Y+1 does not block it', (tester) async {
      final world = LifecycleWorld([
        schoolYear(),
        schoolYear(
          n: 3,
          academicYear: 2027,
          endReason: SubTrackEndReason.deleted,
        ),
      ]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(tester.widget<OutlinedButton>(_pill).onPressed, isNotNull);
    });

    testWidgets('no pill on an ongoing sub-track', (tester) async {
      final world = LifecycleWorld([ongoing()]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(2));
      expect(_pill, findsNothing);
    });

    testWidgets('no pill for a read-only viewer (child, tutor)', (
      tester,
    ) async {
      final child = LifecycleWorld([
        schoolYear(),
      ], viewer: SubTrackLifecycleViewer.readOnly);
      addTearDown(child.dispose);
      await _openDetail(tester, child, lifecycleId(1));
      expect(_pill, findsNothing);
    });
  });

  group('AC-3 / AC-4 overflow Delete and End', () {
    final menu = find.byKey(const ValueKey('subTrackLifecycleMenu'));

    Future<void> choose(WidgetTester tester, String id) async {
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('subTrackMenu:$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('Delete opens the shared dialog: warning icon, copy, '
        'destructive confirm and Cancel', (tester) async {
      final world = LifecycleWorld([schoolYear()]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      await choose(tester, 'delete');
      expect(find.text('Delete School?'), findsOneWidget);
      expect(
        find.text(
          'Its unfinished ground goes back to home learning. Everything '
          'already learnt stays in the lifetime record.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Cancel, a barrier tap and back issue no command', (
      tester,
    ) async {
      final world = LifecycleWorld([schoolYear()]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));

      await choose(tester, 'delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await choose(tester, 'delete');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      await choose(tester, 'end');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Delete School?'), findsNothing);
      expect(find.text('End School now?'), findsNothing);
      expect(world.commands.calls, isEmpty);
      expect(world.repo.calls, isEmpty);
      expect(world.analytics.lifecycles, isEmpty);
      expect(
        find.byKey(ValueKey('subTrackLifecycleDetail:${lifecycleId(1)}')),
        findsOneWidget,
      );
    });

    testWidgets('confirmed Delete tombstones the sub-track, returns to the '
        'hub and confirms', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      await choose(tester, 'delete');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(world.commands.calls, ['deleteSubTrack']);
      final stored = world.stored.single;
      expect(stored.id, source.id);
      expect(stored.endedAt, isNotNull);
      expect(stored.endReason, SubTrackEndReason.deleted);
      expect(stored.name, 'School', reason: 'the source label survives');
      final change = world.repo.calls.single.$2;
      expect(change.changedFields.keys.toSet(), {'ended_at', 'end_reason'});
      expect(world.repo.entries.single.$2.entity, GovernedEntity.subTrack);
      expect(
        find.byKey(const ValueKey('lifecycleHubHost')),
        findsOneWidget,
        reason: 'back on the hub',
      );
      expect(
        find.byKey(ValueKey('subTrackLifecycleDetail:${source.id}')),
        findsNothing,
      );
      expect(find.text('School deleted'), findsOneWidget);
    });

    testWidgets('confirmed End writes end_reason ended and returns to the '
        'hub', (tester) async {
      final track = ongoing();
      final world = LifecycleWorld([track]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, track.id);
      await choose(tester, 'end');
      expect(find.text('End Night seder now?'), findsOneWidget);
      await tester.tap(find.text('End sub-track'));
      await tester.pumpAndSettle();

      expect(world.commands.calls, ['endSubTrack']);
      expect(world.stored.single.endReason, SubTrackEndReason.ended);
      expect(world.repo.entries, hasLength(1));
      expect(find.byKey(const ValueKey('lifecycleHubHost')), findsOneWidget);
      expect(find.text('Night seder ended'), findsOneWidget);
    });

    testWidgets('a refused or offline-required command stays on the detail, '
        'writes nothing and says so', (tester) async {
      final world = LifecycleWorld([schoolYear()]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      world.commands.nextResult = const CaptureResult.onlineRequired();
      await choose(tester, 'delete');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(world.repo.calls, isEmpty);
      expect(world.stored.single.endedAt, isNull);
      expect(find.text("Couldn't save the change. Try again."), findsOneWidget);
      expect(
        find.byKey(ValueKey('subTrackLifecycleDetail:${lifecycleId(1)}')),
        findsOneWidget,
      );
    });

    testWidgets('no ⋮ for a read-only viewer', (tester) async {
      final world = LifecycleWorld([
        schoolYear(),
      ], viewer: SubTrackLifecycleViewer.readOnly);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(menu, findsNothing);
    });
  });
}
