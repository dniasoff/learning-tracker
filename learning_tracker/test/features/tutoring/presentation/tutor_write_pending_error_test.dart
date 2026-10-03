// Story 4.2 (DNI-510) AC-4 — while a tutor's save is in flight the primary
// action shows progress and is disabled and the form keeps its values; a
// failed callable keeps every value and shows the retryable error snackbar
// (UX-DR-120); nothing is shown as saved. A retry replays the same action
// (the same client ULIDs), and repeated failures never lose the input.

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/tutoring/tutor_sub_track_rig.dart';

Future<void> _settle(WidgetTester tester) async {
  await settleCommands(tester);
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(WidgetTester tester, TutorSubTrackRig rig) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: rig.overrides(),
      retry: (_, _) => null,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SchoolYearSubTrackFormScreen(
                    curriculumId: subTrackTestCurriculum,
                  ),
                ),
              ),
              child: const Text('open-form'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-form'));
  await _settle(tester);
}

Finder get _save => find.byKey(const ValueKey('subTrackFormSave'));

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('subTrackFormName')),
    'Cheder',
  );
  await tester.tap(
    find.ancestor(of: find.text('2026–27'), matching: find.byType(ChoiceChip)),
  );
  await tester.pump();
  await tester.ensureVisible(_save);
}

String _name(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('subTrackFormName')),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

FirebaseFunctionsException _unavailable() =>
    FirebaseFunctionsException(code: 'unavailable', message: 'network');

void main() {
  testWidgets('a save in flight shows progress, holds Save and keeps the '
      'values; nothing is in the mirror until the callable answers', (
    tester,
  ) async {
    final rig = TutorSubTrackRig();
    addTearDown(rig.dispose);
    final gate = Completer<void>();
    rig.hold = gate;
    await _pumpForm(tester, rig);
    await _fill(tester);

    await tester.tap(_save);
    await settleCommands(tester);

    expect(
      rig.subTrackCalls,
      hasLength(1),
      reason: 'the callable is in flight',
    );
    final save = tester.widget<FilledButton>(_save);
    expect(save.onPressed, isNull, reason: 'held while pending');
    expect(
      find.descendant(
        of: _save,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(_name(tester), 'Cheder');
    expect(rig.hub.repo.tracksOf(rig.hub.scope), isEmpty);

    gate.complete();
    await _settle(tester);
    expect(rig.hub.repo.tracksOf(rig.hub.scope), hasLength(1));
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });

  testWidgets('a failed callable keeps every value, shows the retryable '
      'error and nothing as saved; Retry replays the same action', (
    tester,
  ) async {
    final rig = TutorSubTrackRig()..failWith = _unavailable();
    addTearDown(rig.dispose);
    await _pumpForm(tester, rig);
    await _fill(tester);

    await tester.tap(_save);
    await _settle(tester);

    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
    expect(_name(tester), 'Cheder');
    expect(find.text('Retry'), findsOneWidget);
    expect(rig.hub.repo.tracksOf(rig.hub.scope), isEmpty);
    expect(tester.widget<FilledButton>(_save).onPressed, isNotNull);

    rig.failWith = null;
    await tester.tap(find.text('Retry'));
    await _settle(tester);

    final ids = [for (final c in rig.subTrackCalls) c.args['subTrackId']];
    expect(ids, hasLength(2));
    expect(ids.first, ids.last, reason: 'the retry replays the same create');
    expect(rig.hub.repo.tracksOf(rig.hub.scope).single.id, ids.first);
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });

  testWidgets('repeated failures never lose the typed values and never show '
      'them as committed', (tester) async {
    final rig = TutorSubTrackRig()..failWith = _unavailable();
    addTearDown(rig.dispose);
    await _pumpForm(tester, rig);
    await _fill(tester);

    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(_save);
      await _settle(tester);
      expect(_name(tester), 'Cheder', reason: 'attempt $attempt');
      expect(rig.hub.repo.tracksOf(rig.hub.scope), isEmpty);
      // Dismiss the snackbar so the next tap reaches Save.
      ScaffoldMessenger.of(tester.element(_save)).hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    expect(rig.subTrackCalls, hasLength(3));
    expect(
      {for (final c in rig.subTrackCalls) c.args['subTrackId']},
      hasLength(1),
      reason: 'every attempt is the same frozen action',
    );
  });
}
