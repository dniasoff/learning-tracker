// Story 4.3 (DNI-511) T3: the talmid row card's pieces — initials, the
// localized fallback name, the status chip as icon and text, a redacted
// row, and the inline retry of a timed-out row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/talmid_row_card.dart';

import '../../../../helpers/pump_app.dart';
import '../../talmidim_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  TalmidRowState row, {
  TalmidRosterEntry? entry,
  VoidCallback? onRetry,
  VoidCallback? onOpen,
}) async {
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        renderedDisplayForRefProvider.overrideWith(
          (ref, sefariaRef) async => talmidRenderedRef(sefariaRef),
        ),
      ],
      child: Scaffold(
        body: TalmidRowCard(
          entry: entry ?? talmidEntry(1, name: 'Yehuda Klein'),
          row: row,
          onRetry: onRetry,
          onOpen: onOpen,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('initials: up to two, upper-cased, Hebrew included', () {
    expect(talmidInitials('yehuda klein'), 'YK');
    expect(talmidInitials('Moshe'), 'M');
    expect(talmidInitials('Avraham ben Yosef'), 'AB');
    expect(talmidInitials('יהודה קליין'), 'יק');
    expect(talmidInitials('  '), '');
  });

  testWidgets('an unnamed learner reads the localized fallback, never an id', (
    tester,
  ) async {
    await _pump(tester, const TalmidRowReady(), entry: talmidEntry(1));
    expect(find.text('Talmid'), findsOneWidget);
    expect(find.textContaining(talmidProfile(1)), findsNothing);
  });

  testWidgets('each status is an icon and words', (tester) async {
    for (final (status, label, icon) in [
      (TalmidStatus.onTrack, 'On track', Icons.check_circle_rounded),
      (TalmidStatus.behindPace, 'Behind pace', Icons.warning_amber_rounded),
      (
        TalmidStatus.tooEarly,
        'Too early to tell',
        Icons.hourglass_empty_rounded,
      ),
    ]) {
      await _pump(tester, TalmidRowReady(status: status));
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
    }
  });

  testWidgets('a pending row shows nothing of the learner and is inert', (
    tester,
  ) async {
    var opened = false;
    await _pump(tester, const TalmidRowPending(), onOpen: () => opened = true);
    expect(find.text('Yehuda Klein'), findsNothing);
    expect(find.text('YK'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    await tester.tap(find.byKey(const Key('talmidRowPending')));
    expect(opened, isFalse);
  });

  testWidgets('a timed-out row offers Retry and does not open', (tester) async {
    var retried = 0;
    var opened = false;
    await _pump(
      tester,
      const TalmidRowTimedOut(identityVisible: true),
      onRetry: () => retried++,
      onOpen: () => opened = true,
    );
    expect(find.text("Couldn't load this talmid's standing."), findsOneWidget);
    expect(find.text('Yehuda Klein'), findsOneWidget);
    await tester.tap(find.byKey(const Key('talmidRowRetry-grant-1')));
    expect(retried, 1);
    await tester.tap(find.text('Yehuda Klein'));
    expect(opened, isFalse);
  });

  testWidgets('a row for an unaddressable learner has no Retry', (
    tester,
  ) async {
    await _pump(
      tester,
      const TalmidRowFailed(
        TalmidRowFailure.invalidLearner,
        identityVisible: true,
      ),
      onRetry: () {},
    );
    expect(find.byKey(const Key('talmidRowRetry-grant-1')), findsNothing);
  });

  testWidgets('the row is at least 48dp tall (UX-DR-156)', (tester) async {
    await _pump(tester, const TalmidRowReady(status: TalmidStatus.onTrack));
    expect(
      tester.getSize(find.byKey(const Key('talmidRow-grant-1'))).height,
      greaterThanOrEqualTo(48),
    );
  });
}
