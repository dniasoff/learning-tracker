// Story 4.4 (DNI-512 T3/T7): the shell listener shows "Access to {name} has
// ended." in a SnackBar, returns to the roster, and acknowledges the notice.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_access_ended_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_access_ended_listener.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<BuildContext> returns,
}) async {
  final container = ProviderContainer(
    overrides: [
      connectivityStreamProvider.overrideWith((ref) => const Stream.empty()),
      tutorRosterReturnProvider.overrideWithValue(returns.add),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(
          body: TutorAccessEndedListener(child: Text('shell content')),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('renders its child and shows nothing without a notice', (
    tester,
  ) async {
    await _pump(tester, returns: []);

    expect(find.text('shell content'), findsOneWidget);
    expect(find.byKey(const Key('tutorAccessEndedSnackBar')), findsNothing);
  });

  testWidgets('a notice shows the named SnackBar, returns to the roster and '
      'is acknowledged', (tester) async {
    final returns = <BuildContext>[];
    final container = await _pump(tester, returns: returns);

    container.read(tutorAccessEndedProvider.notifier).state =
        const TutorAccessEnded(grantId: 'g', learnerName: 'Yossi');
    await tester.pump();

    expect(find.byKey(const Key('tutorAccessEndedSnackBar')), findsOneWidget);
    expect(find.text('Access to Yossi has ended.'), findsOneWidget);
    expect(returns, hasLength(1));
    expect(container.read(tutorAccessEndedProvider), isNull);
  });

  testWidgets('an unnamed notice uses the unnamed copy', (tester) async {
    final container = await _pump(tester, returns: []);
    final l10n = AppLocalizations.of(
      tester.element(find.text('shell content')),
    )!;

    container.read(tutorAccessEndedProvider.notifier).state =
        const TutorAccessEnded(grantId: 'g');
    await tester.pump();

    expect(find.text(l10n.tutorAccessEndedUnnamed), findsOneWidget);
  });

  testWidgets('a second notice replaces the first SnackBar', (tester) async {
    final returns = <BuildContext>[];
    final container = await _pump(tester, returns: returns);
    final notifier = container.read(tutorAccessEndedProvider.notifier);

    notifier.state = const TutorAccessEnded(grantId: 'a', learnerName: 'Yossi');
    await tester.pump();
    notifier.state = const TutorAccessEnded(grantId: 'b', learnerName: 'Dovi');
    await tester.pumpAndSettle();

    expect(find.text('Access to Dovi has ended.'), findsOneWidget);
    expect(returns, hasLength(2));
  });

  group('tutorAccessEndedMessage', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('names the learner when known', () {
      expect(
        tutorAccessEndedMessage(
          l10n,
          const TutorAccessEnded(grantId: 'g', learnerName: 'Yossi'),
        ),
        'Access to Yossi has ended.',
      );
    });

    test('falls back for a null or empty name', () {
      for (final name in [null, '']) {
        expect(
          tutorAccessEndedMessage(
            l10n,
            TutorAccessEnded(grantId: 'g', learnerName: name),
          ),
          l10n.tutorAccessEndedUnnamed,
        );
      }
    });
  });
}
