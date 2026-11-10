import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/features/settings/domain/app_credits.dart';
import 'package:learning_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Learning Tracker',
      packageName: 'learning_tracker',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  test('production router registers About as an app-shell child route', () {
    final router = AppRouter(
      authGuard: _MockGuard(),
      profileGuard: _MockProfileGuard(),
      childModeGuard: _MockChildModeGuard(),
      pinGuard: _MockPinGuard(),
      sacredTimeLocationGuard: _MockGuard(),
    );
    final shell = router.routes.firstWhere((route) => route.path == '/');
    final about = shell.children!.firstWhere((route) => route.path == 'about');

    expect(about.name, AboutRoute.name);
    expect(about.guards, isEmpty);
  });

  testWidgets('renders app information and creator names in the given order', (
    tester,
  ) async {
    await tester.pumpWidget(pumpApp(child: const AboutScreenContent()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Torah Learning Tracker'), findsOneWidget);
    expect(find.text('Plan and track your Torah learning.'), findsOneWidget);
    expect(find.text('Version 1.2.3 (build 42)'), findsOneWidget);
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('Daniel Niasoff'), findsOneWidget);
    expect(find.text('Josh Heimann'), findsNWidgets(2));
  });

  testWidgets('contact rows display for Josh and launch their URIs', (
    tester,
  ) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      pumpApp(
        child: AboutScreenContent(
          launchUri: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text('heimannshua@gmail.com'), findsOneWidget);
    expect(find.text('+447464408299'), findsOneWidget);
    expect(find.text('Daniel Niasoff'), findsOneWidget);
    expect(find.text('Josh Heimann'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ListTile, 'Email'));
    await tester.tap(find.widgetWithText(ListTile, 'WhatsApp'));
    expect(launched, [
      Uri(scheme: 'mailto', path: 'heimannshua@gmail.com'),
      Uri.https('wa.me', '/447464408299'),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows only configured contact rows and hides empty section', (
    tester,
  ) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      pumpApp(
        child: AboutScreenContent(
          creators: const [
            AppCreator(
              name: 'Creator With Contact',
              email: 'one@example.com',
              phone: '+12125550123',
              whatsAppDigits: '442079460123',
              website: 'https://example.com',
            ),
            AppCreator(name: 'Creator Without Contact'),
          ],
          launchUri: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text('one@example.com'), findsOneWidget);
    expect(find.text('+12125550123'), findsOneWidget);
    expect(find.text('+442079460123'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('Creator Without Contact'), findsOneWidget);
    for (final label in ['Email', 'Phone', 'WhatsApp', 'Website']) {
      final row = find.widgetWithText(ListTile, label);
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
    }
    expect(launched, [
      Uri(scheme: 'mailto', path: 'one@example.com'),
      Uri(scheme: 'tel', path: '+12125550123'),
      Uri.https('wa.me', '/442079460123'),
      Uri.parse('https://example.com'),
    ]);

    await tester.pumpWidget(
      pumpApp(
        child: const AboutScreenContent(
          creators: [AppCreator(name: 'No Contact Creator')],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Contact us'), findsNothing);
    expect(find.text('No Contact Creator'), findsOneWidget);
  });

  testWidgets('uses Hebrew for the About UI copy', (tester) async {
    await tester.pumpWidget(
      pumpApp(child: const AboutScreenContent(), locale: const Locale('he')),
    );
    await tester.pump();

    expect(find.text('מידע על האפליקציה'), findsOneWidget);
    expect(find.text('Daniel Niasoff'), findsOneWidget);
    expect(find.text('Josh Heimann'), findsNWidgets(2));
  });
}

class _MockGuard extends Mock implements AutoRouteGuard {}

class _MockProfileGuard extends Mock implements ProfileGuard {}

class _MockChildModeGuard extends Mock implements ChildModeGuard {}

class _MockPinGuard extends Mock implements PinGuard {}
