import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/version/minimum_app_version_gate.dart';
import 'package:learning_tracker/data/repositories/minimum_app_version_repository.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class _FakeMinimumAppVersionChecker implements MinimumAppVersionChecker {
  _FakeMinimumAppVersionChecker(this.results);

  final List<bool> results;
  int calls = 0;

  @override
  Future<bool> shouldBlockApp() async {
    final index = calls++;
    return results[index.clamp(0, results.length - 1)];
  }
}

Widget _app(_FakeMinimumAppVersionChecker checker, {String language = 'en'}) {
  return ProviderScope(
    overrides: [minimumAppVersionCheckerProvider.overrideWithValue(checker)],
    child: MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MinimumAppVersionGate(
        child: Scaffold(body: Center(child: Text('home'))),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'outdated build is blocked with the localized Play Store action',
    (tester) async {
      await tester.pumpWidget(_app(_FakeMinimumAppVersionChecker([true])));
      await tester.pumpAndSettle();

      expect(find.text('Please update'), findsOneWidget);
      expect(
        find.text(
          'This version is no longer supported. Update the app to continue.',
        ),
        findsOneWidget,
      );
      expect(find.text('Update app'), findsOneWidget);
      expect(find.text('home'), findsNothing);
      expect(MinimumAppVersionScreen.playStoreUri.host, 'play.google.com');
      expect(
        MinimumAppVersionScreen.playStoreUri.queryParameters['id'],
        'com.jcom.torah.learning_tracker',
      );
    },
  );

  testWidgets('missing minimum or offline check leaves the app usable', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeMinimumAppVersionChecker([false])));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('Please update'), findsNothing);
  });

  testWidgets('Hebrew devices get a localized blocking screen', (tester) async {
    await tester.pumpWidget(
      _app(_FakeMinimumAppVersionChecker([true]), language: 'he'),
    );
    await tester.pumpAndSettle();

    expect(find.text('נא לעדכן'), findsOneWidget);
    expect(find.text('עדכון האפליקציה'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  testWidgets('minimum version is checked again when the app resumes', (
    tester,
  ) async {
    final checker = _FakeMinimumAppVersionChecker([false, true]);
    await tester.pumpWidget(_app(checker));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(checker.calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(checker.calls, 2);
    expect(find.text('Please update'), findsOneWidget);
  });
}
