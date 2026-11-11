import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/school_repository.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/join_school_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('child join requires clear progress consent', (tester) async {
    final calls = <Map<String, Object?>>[];
    final repository = SchoolRepository((name, data) async {
      calls.add(data);
      return {'success': true};
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [schoolRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: JoinSchoolScreen(
            inviteCode: 'invite',
            profileId: 'child',
            isChild: true,
            parentSessionId: 'parent-session',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('School staff will be able to view'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(calls.single['progressConsent'], isTrue);
    expect(calls.single['parentSessionId'], 'parent-session');
  });
}
