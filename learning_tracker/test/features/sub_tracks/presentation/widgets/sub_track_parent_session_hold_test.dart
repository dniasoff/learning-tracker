// DNI-495 (story 2.4) AC-3 — a sub-track write surface shows only while the
// parent session is live; a session that ends hides it without losing what
// was typed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_parent_session_hold.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/sub_track_harness.dart';

const _locked = ValueKey('subTrackParentSessionLocked');
const _field = ValueKey('holdField');

Widget _hold() => const Scaffold(
  body: SubTrackParentSessionHold(child: TextField(key: _field)),
);

void main() {
  testWidgets('shows the loading state while the session resolves', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          subTrackParentSessionProvider.overrideWith((ref) => pending.future),
        ],
        child: _hold(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(_field), findsNothing);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(_field), findsOneWidget);
  });

  testWidgets('a refused session never builds the surface', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          subTrackParentSessionProvider.overrideWith((ref) async => false),
        ],
        child: _hold(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_locked), findsOneWidget);
    expect(find.byKey(_field, skipOffstage: false), findsNothing);
  });

  testWidgets('a session that fails to resolve is refused (fail closed)', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          subTrackParentSessionProvider.overrideWith(
            (ref) async => throw StateError('profile read failed'),
          ),
        ],
        retry: (_, _) => null,
        child: _hold(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_locked), findsOneWidget);
    expect(find.byKey(_field, skipOffstage: false), findsNothing);
  });

  testWidgets(
    'an ended session hides the surface offstage and keeps its values',
    (tester) async {
      await tester.pumpWidget(
        pumpApp(overrides: [switchableParentSessionOverride()], child: _hold()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_field), 'Cheder');

      setParentSession(tester, find.byKey(_field), live: false);
      await tester.pumpAndSettle();
      expect(find.byKey(_locked), findsOneWidget);
      expect(find.byKey(_field), findsNothing, reason: 'offstage');
      expect(find.byKey(_field, skipOffstage: false), findsOneWidget);

      setParentSession(tester, find.byKey(_locked), live: true);
      await tester.pumpAndSettle();
      expect(find.byKey(_locked), findsNothing);
      expect(find.text('Cheder'), findsOneWidget);
    },
  );
}
