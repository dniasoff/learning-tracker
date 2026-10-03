// Story 4.3 (DNI-511) My talmidim widget tests: AC-1 (active rows, footer,
// live grant set), AC-2 (status chip text and theme role), AC-3 (groundless
// row and Add ground gating), AC-4 (a locked row is redacted), AC-6 (empty
// and failed loads), AC-7 (only built rows run the engine).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/data/repositories/firestore_tutor_roster_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/talmid_row_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/my_talmidim_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/talmid_row_card.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../../helpers/dashboard/forecast_fixtures.dart';
import '../talmidim_fixtures.dart';

Finder _text(String s) => find.text(s);

AppPalette _palette(WidgetTester tester) =>
    tester.element(find.byType(MyTalmidimScreen)).colors;

Color? _chipFill(WidgetTester tester, String grantId) {
  final chip = find.byKey(Key('talmidStatusChip-$grantId'));
  final box = tester.widget<Container>(
    find.descendant(of: chip, matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color;
}

void main() {
  late FakeTalmidInputs inputs;
  late RecordingTalmidOpener opener;

  setUp(() {
    inputs = FakeTalmidInputs();
    opener = RecordingTalmidOpener();
  });

  group('AC-1: the active-grant roster', () {
    testWidgets('three active and one revoked grant render three outlined '
        'rows, then the access note', (tester) async {
      final repo = FirestoreTutorRosterRepository(
        () async => (
          grants: [
            talmidGrant(1, name: 'Yehuda Klein'),
            talmidGrant(2, name: 'Moshe Levi'),
            talmidGrant(
              3,
              name: 'Revoked Talmid',
              state: TutorGrantState.revokedByParent,
            ),
            talmidGrant(4, name: 'Avraham Stein'),
          ],
          ok: true,
        ),
      );
      for (final n in [1, 2, 4]) {
        inputs.states[talmidScope(n)] = AsyncData(
          talmidState(sub: rebbeTrack()),
        );
      }
      await pumpTalmidim(tester, repo: repo, inputs: inputs, opener: opener);

      for (final grant in ['grant-1', 'grant-2', 'grant-4']) {
        expect(find.byKey(Key('talmidRow-$grant')), findsOneWidget);
      }
      expect(find.byKey(const Key('talmidRow-grant-3')), findsNothing);
      expect(_text('Revoked Talmid'), findsNothing);

      // Initials avatar, name, status chip, detail line and chevron.
      expect(_text('YK'), findsOneWidget);
      expect(_text('Yehuda Klein'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('talmidStatusChip-grant-1')),
          matching: _text('On track'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('talmidRowLine-grant-1')))
            .data,
        'Rebbe: next Beitzah 3:1',
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));

      // Outlined card.
      final card = tester.widget<Material>(
        find.byKey(const Key('talmidRow-grant-1')),
      );
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.side.color, _palette(tester).brandOutline);

      // The footer, exactly, and it is the last item.
      await tester.scrollUntilVisible(
        find.byKey(const Key('talmidimAccessNote')),
        200,
      );
      expect(
        _text('You see only learners whose parents gave you access.'),
        findsOneWidget,
      );
    });

    testWidgets('the footer note is not a focus stop', (tester) async {
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([
          [talmidEntry(1, name: 'A B')],
        ]),
        inputs: inputs,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('talmidimAccessNote')),
          matching: find.byWidgetPredicate(
            (w) => w is ExcludeFocus && w.excluding,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a row whose access ended re-reads the roster and leaves', (
      tester,
    ) async {
      final repo = ScriptedTutorRosterRepository([
        [talmidEntry(1, name: 'Yehuda Klein'), talmidEntry(2, name: 'Moshe')],
        [talmidEntry(2, name: 'Moshe')],
      ]);
      inputs.states[talmidScope(1)] = AsyncData(talmidState());
      inputs.states[talmidScope(2)] = AsyncData(talmidState());
      await pumpTalmidim(tester, repo: repo, inputs: inputs);
      expect(_text('Yehuda Klein'), findsOneWidget);

      // The parent revokes: the grant-validated read path now refuses.
      inputs.states[talmidScope(1)] = AsyncError<LearnerState>(
        TutorScopeAccessDeniedException(
          talmidScope(1),
          TutorScopeDenialReason.grantNotActive,
        ),
        StackTrace.empty,
      );
      ProviderScope.containerOf(
        tester.element(find.byType(MyTalmidimScreen)),
      ).invalidate(talmidLearnerStateProvider(talmidScope(1)));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(repo.loads, 2);
      expect(_text('Yehuda Klein'), findsNothing);
      expect(find.byKey(const Key('talmidRow-grant-1')), findsNothing);
      expect(_text('Moshe'), findsOneWidget);
    });
  });

  group('AC-2: status chip', () {
    Future<void> pumpOne(WidgetTester tester, LearnerState state) async {
      inputs.states[talmidScope(1)] = AsyncData(state);
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([
          [talmidEntry(1, name: 'Yehuda Klein')],
        ]),
        inputs: inputs,
      );
    }

    testWidgets('on track: text on the success role', (tester) async {
      await pumpOne(tester, talmidState(sub: rebbeTrack()));
      expect(_text('On track'), findsOneWidget);
      expect(
        _chipFill(tester, 'grant-1'),
        _palette(tester).statusSuccessSoftBg,
      );
    });

    testWidgets('behind pace: text on the warning role', (tester) async {
      await pumpOne(
        tester,
        talmidState(status: ProjectionStatus.behindPace, sub: rebbeTrack()),
      );
      expect(_text('Behind pace'), findsOneWidget);
      expect(_chipFill(tester, 'grant-1'), _palette(tester).brandWarningSoft);
    });

    testWidgets('under 14 days: too early to tell on the neutral role', (
      tester,
    ) async {
      await pumpOne(
        tester,
        talmidState(status: ProjectionStatus.tooEarly, sub: rebbeTrack()),
      );
      expect(_text('Too early to tell'), findsOneWidget);
      expect(_chipFill(tester, 'grant-1'), _palette(tester).brandCreamSoft);
    });

    testWidgets('no deadline: no chip, the detail line stays', (tester) async {
      await pumpOne(
        tester,
        talmidState(status: ProjectionStatus.noDeadline, sub: rebbeTrack()),
      );
      expect(find.byKey(const Key('talmidStatusChip-grant-1')), findsNothing);
      expect(_text('Rebbe: next Beitzah 3:1'), findsOneWidget);
    });

    testWidgets('the row is read as one label with its status in words', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpOne(tester, talmidState(sub: rebbeTrack()));
      expect(
        find.bySemanticsLabel(
          'Yehuda Klein, On track, Rebbe: next Beitzah 3:1',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('AC-3: groundless row and Add ground', () {
    Future<void> pumpGroundless(
      WidgetTester tester, {
      bool canEdit = true,
      bool online = true,
    }) async {
      inputs.states[talmidScope(1)] = AsyncData(
        talmidState(
          status: ProjectionStatus.noDeadline,
          sub: rebbeTrack(position: null),
        ),
      );
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([
          [talmidEntry(1, name: 'Dovid R', canEditLearning: canEdit)],
        ]),
        inputs: inputs,
        opener: opener,
        online: online,
      );
    }

    final addGround = find.byKey(const Key('talmidAddGround-grant-1'));

    testWidgets('reads no ground yet; Add ground opens that sub-track', (
      tester,
    ) async {
      await pumpGroundless(tester);
      expect(_text('Rebbe: no ground yet'), findsOneWidget);
      final button = tester.widget<TextButton>(addGround);
      expect(button.onPressed, isNotNull);
      await tester.tap(addGround);
      await tester.pump();
      expect(opener.calls, [('grant-1', rebbeSubTrackId)]);
    });

    testWidgets('without can_edit_learning: disabled, no navigation', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpGroundless(tester, canEdit: false);
      expect(tester.widget<TextButton>(addGround).onPressed, isNull);
      expect(
        tester.getSemantics(addGround),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      await tester.tap(addGround, warnIfMissed: false);
      await tester.pump();
      expect(opener.calls, isEmpty);
      handle.dispose();
    });

    testWidgets('offline: disabled, no navigation', (tester) async {
      await pumpGroundless(tester, online: false);
      expect(tester.widget<TextButton>(addGround).onPressed, isNull);
      await tester.tap(addGround, warnIfMissed: false);
      await tester.pump();
      expect(opener.calls, isEmpty);
    });
  });

  testWidgets('AC-4: a locked talmid shows only Shabbos / Yom Tov', (
    tester,
  ) async {
    inputs
      ..states[talmidScope(1)] = AsyncData(talmidState(sub: rebbeTrack()))
      ..states[talmidScope(2)] = AsyncData(talmidState(sub: rebbeTrack()))
      ..locks[talmidScope(1)] = const AsyncData(true);
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [
          talmidEntry(1, name: 'Avraham Stein'),
          talmidEntry(2, name: 'Moshe Levi'),
        ],
      ]),
      inputs: inputs,
      opener: opener,
    );
    expect(_text('Shabbos / Yom Tov'), findsOneWidget);
    expect(_text('Avraham Stein'), findsNothing);
    expect(_text('AS'), findsNothing);
    expect(find.byKey(const Key('talmidStatusChip-grant-1')), findsNothing);
    await tester.tap(find.byKey(const Key('talmidRowLocked')));
    await tester.pump();
    expect(opener.calls, isEmpty);

    await tester.tap(find.byKey(const Key('talmidRow-grant-2')));
    await tester.pump();
    expect(opener.calls, [('grant-2', null)]);
  });

  group('AC-6: empty and failed loads are distinct', () {
    testWidgets('no active grants: the no-talmidim copy', (tester) async {
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([const <TalmidRosterEntry>[]]),
        inputs: inputs,
      );
      expect(
        _text('No talmidim yet — a parent needs to give you access.'),
        findsOneWidget,
      );
      expect(find.byType(AppErrorView), findsNothing);
    });

    testWidgets('a failed load is AppErrorView; Retry loads the rows', (
      tester,
    ) async {
      final repo = ScriptedTutorRosterRepository([
        const TutorRosterLoadException(),
        [talmidEntry(1, name: 'Yehuda Klein')],
      ]);
      inputs.states[talmidScope(1)] = AsyncData(talmidState());
      await pumpTalmidim(tester, repo: repo, inputs: inputs);
      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.byKey(const Key('talmidimEmpty')), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(repo.loads, 2);
      expect(find.byType(AppErrorView), findsNothing);
      expect(_text('Yehuda Klein'), findsOneWidget);
    });
  });

  testWidgets(
    'AC-7: only rows on screen or about to scroll on run the engine',
    (tester) async {
      final entries = [
        for (var n = 1; n <= 20; n++) talmidEntry(n, name: 'Talmid $n'),
      ];
      for (var n = 1; n <= 20; n++) {
        inputs.states[talmidScope(n)] = AsyncData(
          talmidState(sub: rebbeTrack()),
        );
      }
      await pumpTalmidim(
        tester,
        repo: ScriptedTutorRosterRepository([entries]),
        inputs: inputs,
        size: const Size(400, 500),
      );
      final evaluated = inputs.stateReads.keys.toSet();
      expect(evaluated, isNotEmpty);
      expect(evaluated.length, lessThan(20));
      expect(evaluated, contains(talmidScope(1)));
      expect(evaluated, isNot(contains(talmidScope(20))));

      await tester.scrollUntilVisible(
        find.byKey(const Key('talmidRow-grant-20')),
        300,
      );
      expect(inputs.stateReads.keys, contains(talmidScope(20)));
    },
  );

  testWidgets('Hebrew: the row and footer are localized', (tester) async {
    inputs.states[talmidScope(1)] = AsyncData(talmidState(sub: rebbeTrack()));
    await pumpTalmidim(
      tester,
      repo: ScriptedTutorRosterRepository([
        [talmidEntry(1, name: 'יהודה קליין')],
      ]),
      inputs: inputs,
      locale: const Locale('he'),
    );
    expect(_text('התלמידים שלי'), findsOneWidget);
    expect(_text('בקצב הנכון'), findsOneWidget);
    expect(_text('Rebbe: הבא Beitzah 3:1'), findsOneWidget);
    expect(find.byType(TalmidStatusChip), findsOneWidget);
  });
}
