/// Story 2.8 (DNI-499) widget acceptance on the real sub-track detail
/// (DNI-497) and school-year form (DNI-495): *Add next year* (AC-1, AC-2),
/// ⋮ Delete / End (AC-3, AC-4) and the read-only ended detail (AC-5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';

import '../../../helpers/pump_app.dart';
import 'sub_track_lifecycle_harness.dart';

Future<void> _openDetail(
  WidgetTester tester,
  LifecycleWorld world,
  String id,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: world.overrides,
      retry: (_, _) => null,
      child: LifecycleHubHost(ids: [id]),
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

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('subTrackFormSave')));
  await tester.tap(find.byKey(const ValueKey('subTrackFormSave')));
  await tester.pumpAndSettle();
}

final _pill = find.byKey(const ValueKey('subTrackAddNextYear'));
final _menu = find.byKey(const ValueKey('subTrackDetailMenu'));
Finder _detail(String id) => find.byKey(ValueKey('subTrackDetail:$id'));
final _readOnly = find.byKey(const ValueKey('subTrackLifecycleReadOnly'));

void main() {
  group('AC-1 Add next year opens the copied school-year form', () {
    testWidgets('prefilled for Y+1 with empty ground; every field editable; '
        'save creates a new ULID and leaves the source unchanged', (
      tester,
    ) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);

      expect(find.text('Add next year (2027–28)'), findsOneWidget);
      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();

      // DNI-495's school-year form, in its next-year mode.
      expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
      expect(find.text('Next school year'), findsOneWidget);
      expect(_field(tester, 'subTrackFormName'), 'School');
      expect(_field(tester, 'subTrackFormRate'), '8');
      expect(_field(tester, 'subTrackFormWeeks'), '36');
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text('2027–28'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      expect(find.text('September'), findsOneWidget);
      expect(find.text('July'), findsOneWidget);

      // Every field stays editable before Save sub-track.
      await _enter(tester, 'subTrackFormName', 'School (Rebbe G)');
      await _enter(tester, 'subTrackFormRate', '10');
      await _enter(tester, 'subTrackFormWeeks', '35');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.text('July'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('June').last);
      await tester.pumpAndSettle();
      await _save(tester);

      expect(world.commands.calls, [
        'createSubTrack(nextYearOf: ${source.id})',
      ]);
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
      expect(_detail(source.id), findsOneWidget);
    });

    testWidgets('a year another device took after render is refused: no row, '
        'the form keeps its input and says why', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();
      await _enter(tester, 'subTrackFormName', 'School 2');

      // Another device saves 2027–28 first; the form's render-time read
      // has not seen it, the command's save-time AD-45 check does.
      final other = schoolYear(n: 9, name: 'Elsewhere', academicYear: 2027);
      world.repo.seed(world.scope, [other]);
      await _save(tester);

      expect(world.commands.calls, [
        'createSubTrack(nextYearOf: ${source.id})',
      ]);
      expect(
        find.text('This academic year already has a school sub-track'),
        findsOneWidget,
      );
      expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
      expect(_field(tester, 'subTrackFormName'), 'School 2');
      expect(world.stored.map((t) => t.id).toSet(), {source.id, other.id});
      expect(world.repo.entries, isEmpty);
      expect(world.analytics.lifecycles, isEmpty);
    });

    testWidgets('a source another device ended after the form opened is '
        'refused at save: no row, the tombstone stays, and the parent is '
        'told why', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);

      // Another device ends the source between render and save; the
      // command re-reads it at save time.
      final ended = schoolYear(endReason: SubTrackEndReason.ended);
      world.commands.beforeNext = () => world.repo.seed(world.scope, [ended]);
      await _save(tester);

      expect(world.commands.calls, [
        'createSubTrack(nextYearOf: ${source.id})',
      ]);
      expect(
        find.text("School was ended or deleted, so next year wasn't added."),
        findsOneWidget,
      );
      expect(world.stored.single, ended);
      expect(world.repo.entries, isEmpty);
      expect(world.analytics.lifecycles, isEmpty);
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
      await tester.ensureVisible(_pill);
      await tester.tap(_pill, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolYearSubTrackForm), findsNothing);
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
      expect(_detail(lifecycleId(2)), findsOneWidget);
      expect(_pill, findsNothing);
    });

    testWidgets('no pill for the read-only child', (tester) async {
      final world = LifecycleWorld([
        schoolYear(),
      ], role: SubTrackDetailRole.child);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(_detail(lifecycleId(1)), findsOneWidget);
      expect(_pill, findsNothing);
    });

    testWidgets('a tutor in tutor mode gets the pill (Story 4.2, DNI-510)', (
      tester,
    ) async {
      final world = LifecycleWorld([
        schoolYear(),
      ], role: SubTrackDetailRole.tutor);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(_pill, findsOneWidget);
    });
  });

  group('AC-3 / AC-4 overflow Delete and End', () {
    Future<void> choose(WidgetTester tester, String id) async {
      await tester.tap(_menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('subTrackMenu:$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('the parent ⋮ lists End and Delete after Edit', (tester) async {
      final world = LifecycleWorld([schoolYear()]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      await tester.tap(_menu);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subTrackMenu:edit')), findsOneWidget);
      expect(find.text('End sub-track now'), findsOneWidget);
      expect(find.text('Delete track'), findsOneWidget);
      final top = tester.getTopLeft;
      expect(
        top(find.byKey(const ValueKey('subTrackMenu:edit'))).dy,
        lessThan(top(find.byKey(const ValueKey('subTrackMenu:end'))).dy),
      );
      expect(
        top(find.byKey(const ValueKey('subTrackMenu:end'))).dy,
        lessThan(top(find.byKey(const ValueKey('subTrackMenu:delete'))).dy),
      );
    });

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
      expect(_detail(lifecycleId(1)), findsOneWidget);
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
      expect(_detail(source.id), findsNothing);
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
      expect(_detail(lifecycleId(1)), findsOneWidget);
    });

    testWidgets('no ⋮ for the read-only child', (tester) async {
      final world = LifecycleWorld([
        schoolYear(),
      ], role: SubTrackDetailRole.child);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(_detail(lifecycleId(1)), findsOneWidget);
      expect(_menu, findsNothing);
    });

    testWidgets('a tutor in tutor mode gets the ⋮ (Story 4.2, DNI-510)', (
      tester,
    ) async {
      final world = LifecycleWorld([
        schoolYear(),
      ], role: SubTrackDetailRole.tutor);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(_menu, findsOneWidget);
    });
  });

  group('AC-5 an ended sub-track opens read-only', () {
    // School 2026–27 is live; Shiur was ended and School 2025–26's window
    // passed on 31 Jul 2026 with no write.
    List<SubTrack> tracks() => [
      schoolYear(),
      ongoing(n: 3, name: 'Shiur', endReason: SubTrackEndReason.ended),
      schoolYear(n: 5, academicYear: 2025),
    ];

    void expectNoMutatingAction(WidgetTester tester) {
      expect(_readOnly, findsOneWidget);
      expect(_menu, findsNothing, reason: 'no edit, end or delete');
      expect(
        find.byKey(const ValueKey('subTrackGroundReorderable')),
        findsNothing,
        reason: 'no reorder',
      );
      expect(
        find.byKey(
          ValueKey('subTrackDragHandle:${lifecycleGround.single.ref}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('subTrackEntryMenu:${lifecycleGround.single.ref}')),
        findsNothing,
        reason: 'no ground move or remove',
      );
    }

    testWidgets('a tombstoned sub-track: no ⋮, no ground action, no pill', (
      tester,
    ) async {
      final world = LifecycleWorld(tracks());
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(3));
      expect(_detail(lifecycleId(3)), findsOneWidget);
      expectNoMutatingAction(tester);
      expect(_pill, findsNothing);
    });

    testWidgets('an elapsed window (no ended_at) is read-only for the parent '
        'too, but can still roll into next year (UJ-3)', (tester) async {
      final world = LifecycleWorld(tracks());
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(5));
      expectNoMutatingAction(tester);
      // 2026–27 is held by the live School: visible but disabled.
      expect(find.text('Add next year (2026–27)'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(_pill).onPressed, isNull);
      expect(world.repo.calls, isEmpty, reason: 'expiry writes nothing');
    });

    testWidgets('a live sub-track keeps its ⋮ and ground actions', (
      tester,
    ) async {
      final world = LifecycleWorld(tracks());
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      expect(_menu, findsOneWidget);
      expect(_readOnly, findsNothing);
      expect(
        find.byKey(const ValueKey('subTrackGroundReorderable')),
        findsOneWidget,
      );
    });
  });

  group('AD-54 a queued End, Delete or Add next year is pending, not done', () {
    const queuedCopy =
        "Saved on this device. It will sync when you're back online.";

    Future<void> confirm(WidgetTester tester, String id, String label) async {
      await tester.tap(_menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('subTrackMenu:$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Finder syncRow(String text) => find.descendant(
      of: find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
      matching: find.text(text),
    );

    testWidgets('a queued End returns to the hub as waiting to sync, and is '
        'confirmed and reported only when the server accepts it', (
      tester,
    ) async {
      final track = ongoing();
      final world = LifecycleWorld([track]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, track.id);
      world.repo.offline = true;
      await confirm(tester, 'end', 'End sub-track');

      expect(find.byKey(const ValueKey('lifecycleHubHost')), findsOneWidget);
      expect(find.text(queuedCopy), findsOneWidget);
      expect(find.text('Night seder ended'), findsNothing);
      expect(syncRow('Ending Night seder: waiting to sync'), findsOneWidget);
      expect(world.analytics.lifecycles, isEmpty);

      world.repo.settleHeld();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
        findsNothing,
      );
      expect(find.text('Night seder ended'), findsOneWidget);
      expect(
        world.analytics.lifecycles.single.action,
        SubTrackLifecycleAction.end,
      );
      expect(world.stored.single.endReason, SubTrackEndReason.ended);
    });

    testWidgets('a queued Delete the server refuses shows not saved with '
        'Retry; the retry saves it once and confirms', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      world.repo
        ..offline = true
        ..failNextWith(const PermanentWriteRejection('permission-denied'));
      await confirm(tester, 'delete', 'Delete');
      expect(syncRow('Deleting School: waiting to sync'), findsOneWidget);

      world.repo.settleHeld();
      await tester.pumpAndSettle();
      expect(world.stored.single.endedAt, isNull, reason: 'reverted');
      expect(syncRow('Deleting School: not saved'), findsOneWidget);
      expect(find.text('School deleted'), findsNothing);
      expect(world.analytics.lifecycles, isEmpty);

      world.repo.offline = false;
      final changeId = world.repo.calls.single.$2.entry.id;
      await tester.tap(find.byKey(ValueKey('subTrackSyncRetry:$changeId')));
      await tester.pumpAndSettle();
      expect(world.commands.calls, ['deleteSubTrack', 'retry']);
      expect(world.stored.single.endReason, SubTrackEndReason.deleted);
      expect(world.repo.entries, hasLength(1));
      expect(
        find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
        findsNothing,
      );
      expect(find.text('School deleted'), findsOneWidget);
      expect(world.analytics.lifecycles, hasLength(1));
    });

    testWidgets('a refused write can be closed without a retry', (
      tester,
    ) async {
      final world = LifecycleWorld([schoolYear()]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, lifecycleId(1));
      world.repo
        ..offline = true
        ..failNextWith(const PermanentWriteRejection('permission-denied'));
      await confirm(tester, 'delete', 'Delete');
      world.repo.settleHeld();
      await tester.pumpAndSettle();
      final changeId = world.repo.calls.single.$2.entry.id;
      await tester.tap(find.byKey(ValueKey('subTrackSyncClose:$changeId')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subTrackLifecycleSyncPanel')),
        findsNothing,
      );
      expect(world.commands.calls, ['deleteSubTrack']);
    });

    testWidgets('a queued Add next year closes the form as waiting to sync '
        'on the source detail and confirms on the server ack', (tester) async {
      final source = schoolYear();
      final world = LifecycleWorld([source]);
      addTearDown(world.dispose);
      await _openDetail(tester, world, source.id);
      world.repo.offline = true;
      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();
      await _save(tester);

      expect(_detail(source.id), findsOneWidget);
      expect(find.text(queuedCopy), findsOneWidget);
      expect(find.text('School added for 2027–28'), findsNothing);
      expect(
        syncRow('Adding School for 2027–28: waiting to sync'),
        findsOneWidget,
      );
      expect(world.analytics.lifecycles, isEmpty);

      world.repo.settleHeld();
      await tester.pumpAndSettle();
      expect(find.text('School added for 2027–28'), findsOneWidget);
      expect(
        world.analytics.lifecycles.single.action,
        SubTrackLifecycleAction.addNextYear,
      );
    });
  });
}
