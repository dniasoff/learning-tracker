import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/school_repository.dart';
import 'package:learning_tracker/features/social/domain/school.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/school_profile_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('school profile shows admins and submits reports', (
    tester,
  ) async {
    final calls = <Map<String, Object?>>[];
    final repository = SchoolRepository((name, data) async {
      calls.add(data);
      return {'success': true};
    });
    const profile = SchoolProfile(
      schoolId: 'school_12345678',
      name: 'North School',
      createdAt: null,
      adminNames: ['Admin'],
      status: 'active',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(repository),
          schoolProfileProvider.overrideWith((ref, id) async => profile),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SchoolProfileScreen(schoolId: 'school_12345678'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Admin'), findsOneWidget);
    expect(
      find.text(
        'School administrators must remove or transfer their admin role before leaving or being removed as a member.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Report school'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impersonation'));
    await tester.pumpAndSettle();
    expect(calls.single, {
      'schoolId': profile.schoolId,
      'category': 'impersonation',
    });
  });

  testWidgets('admin membership guidance is localized in Hebrew', (
    tester,
  ) async {
    const profile = SchoolProfile(
      schoolId: 'school_12345678',
      name: 'בית ספר צפון',
      createdAt: null,
      adminNames: ['מנהל'],
      status: 'active',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolProfileProvider.overrideWith((ref, id) async => profile),
        ],
        child: const MaterialApp(
          locale: Locale('he'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SchoolProfileScreen(schoolId: 'school_12345678'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'מנהלי בית הספר צריכים להסיר או להעביר את תפקיד הניהול לפני עזיבה או הסרה כחברים.',
      ),
      findsOneWidget,
    );
  });
}
