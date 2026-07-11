// Regression coverage for AUD-onboarding-16: OnboardingParentPinStep must
// never surface PinService's raw ArgumentError.message English literal as
// its error text. PinService exposes PIN-format validation failures as a
// typed [InvalidPinFormatException] (EH-2/EH-5), and the widget resolves the
// display string through AppLocalizations for both the invalid-format case
// and the PIN-mismatch case, in both en and he locales.
@Tags(['onboarding', 'l10n', 'pin'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_parent_pin_step.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinService extends Mock implements PinService {}

const _kProfileId = 7;

Widget _harness({required PinService pinService, required Locale locale}) {
  return ProviderScope(
    overrides: [pinServiceProvider.overrideWithValue(pinService)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: OnboardingParentPinStep(
          profileId: _kProfileId,
          childName: 'Noa',
          onComplete: () {},
        ),
      ),
    ),
  );
}

/// Types [pin] into the 4 digit TextFields currently on screen.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  assert(pin.length == 4, 'pin must be exactly 4 digits');
  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(4));
  for (var i = 0; i < 4; i++) {
    await tester.enterText(fields.at(i), pin[i]);
    await tester.pump();
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('OnboardingParentPinStep — invalid PIN format error is localized', () {
    testWidgets('en locale shows AppLocalizations text, not the raw '
        'PinService exception message', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();
      when(
        () => svc.setProfilePin(any<int>(), any<String>()),
      ).thenThrow(const InvalidPinFormatException());

      await tester.pumpWidget(
        _harness(pinService: svc, locale: const Locale('en')),
      );
      await _enterPin(tester, '1234');
      await tester.pump();
      await _enterPin(tester, '1234'); // confirm step — triggers setProfilePin
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text(l10n.pinInvalidFormat),
        findsOneWidget,
        reason: 'the error text must come from AppLocalizations',
      );
      expect(
        find.text('PIN must be exactly 4 numeric digits'),
        findsNothing,
        reason: "PinService's raw exception message must never reach the UI",
      );
    });

    testWidgets('he locale shows the Hebrew AppLocalizations text', (
      tester,
    ) async {
      setViewSize(tester);
      final svc = _MockPinService();
      when(
        () => svc.setProfilePin(any<int>(), any<String>()),
      ).thenThrow(const InvalidPinFormatException());

      await tester.pumpWidget(
        _harness(pinService: svc, locale: const Locale('he')),
      );
      await _enterPin(tester, '1234');
      await tester.pump();
      await _enterPin(tester, '1234');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final l10n = await AppLocalizations.delegate.load(const Locale('he'));
      expect(find.text(l10n.pinInvalidFormat), findsOneWidget);
      expect(find.text('PIN must be exactly 4 numeric digits'), findsNothing);
    });
  });

  group('OnboardingParentPinStep — PIN-mismatch error is localized', () {
    testWidgets('en locale shows AppLocalizations text', (tester) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _harness(pinService: svc, locale: const Locale('en')),
      );
      await _enterPin(tester, '1234');
      await tester.pump();
      await _enterPin(tester, '4321'); // mismatched confirm
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.pinsDoNotMatch), findsOneWidget);
      verifyNever(() => svc.setProfilePin(any<int>(), any<String>()));
    });

    testWidgets('he locale shows the Hebrew AppLocalizations text', (
      tester,
    ) async {
      setViewSize(tester);
      final svc = _MockPinService();

      await tester.pumpWidget(
        _harness(pinService: svc, locale: const Locale('he')),
      );
      await _enterPin(tester, '1234');
      await tester.pump();
      await _enterPin(tester, '4321');
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('he'));
      expect(find.text(l10n.pinsDoNotMatch), findsOneWidget);
    });
  });
}
