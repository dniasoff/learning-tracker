// Story 5.2 (DNI-517) AC-1/AC-2: the Report entry shows only in a parent
// session (fail closed while resolving) and opens the report for the
// curriculum in view.
@Tags(['progress', 'lifetime', 'story_5_2'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_report_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

final _entry = find.byKey(const ValueKey('lifetimeReportEntry'));

Future<_MockStackRouter> _pump(
  WidgetTester tester, {
  required Future<bool> Function() session,
  String? curriculumId,
}) async {
  final router = _MockStackRouter();
  when(() => router.push(any())).thenAnswer((_) async => null);
  await tester.pumpWidget(
    pumpApp(
      child: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: Scaffold(body: LifetimeReportEntry(curriculumId: curriculumId)),
      ),
      overrides: [parentSessionProvider.overrideWith((ref) => session())],
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  setUpAll(() => registerFallbackValue(_FakePageRouteInfo()));

  testWidgets('a parent session sees the entry with its label', (tester) async {
    await _pump(tester, session: () async => true);
    expect(_entry, findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.byIcon(Icons.assessment_outlined), findsOneWidget);
  });

  testWidgets('a non-parent session sees nothing', (tester) async {
    await _pump(tester, session: () async => false);
    expect(_entry, findsNothing);
  });

  testWidgets('shows nothing while the session is still resolving', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await _pump(tester, session: () => pending.future);
    expect(_entry, findsNothing);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(_entry, findsOneWidget);
  });

  testWidgets('shows nothing when the session fails to resolve', (
    tester,
  ) async {
    await _pump(tester, session: () async => throw StateError('boom'));
    expect(_entry, findsNothing);
  });

  testWidgets('tapping opens the report for the curriculum in view', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      session: () async => true,
      curriculumId: 'mishnayos',
    );
    await tester.tap(_entry);
    await tester.pump();
    final route =
        verify(() => router.push(captureAny())).captured.single
            as PageRouteInfo;
    expect(route, isA<LifetimeReportRoute>());
    expect((route.args! as LifetimeReportRouteArgs).curriculumId, 'mishnayos');
  });

  testWidgets('the tap target is at least 48 dp', (tester) async {
    await _pump(tester, session: () async => true);
    final size = tester.getSize(_entry);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
}
