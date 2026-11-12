import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/school_repository.dart';
import 'package:learning_tracker/features/social/domain/school.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/join_school_screen.dart';
import 'package:learning_tracker/features/social/presentation/screens/school_profile_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'join requires explicit progress disclosure consent and sends it',
    (tester) async {
      final calls = <(String, Map<String, Object?>)>[];
      final repo = SchoolRepository((name, data) async {
        calls.add((name, data));
        return {'success': true};
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [schoolRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: JoinSchoolScreen(
              inviteCode: 'invite',
              profileId: 'child',
              isChild: true,
              parentSessionId: 'session',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('School staff will be able to view'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(calls.single.$1, 'joinSchoolWithInvite');
      expect(calls.single.$2['progressConsent'], isTrue);
      expect(calls.single.$2['parentSessionId'], 'session');
    },
  );

  testWidgets(
    'school profile is localized in Hebrew and reports a fixed category',
    (tester) async {
      final calls = <(String, Map<String, Object?>)>[];
      final repo = SchoolRepository((name, data) async {
        calls.add((name, data));
        return {'success': true};
      });
      const profile = SchoolProfile(
        schoolId: 'school_12345678',
        name: 'בית מדרש',
        createdAt: null,
        adminNames: ['רבקה'],
        status: 'active',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            schoolRepositoryProvider.overrideWithValue(repo),
            schoolProfileProvider.overrideWith(
              (ref, schoolId) async => profile,
            ),
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
      expect(find.text('מאומת'), findsNothing);
      expect(find.text('מנהלי בית הספר'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl,
      );
      await tester.tap(find.text('דיווח על בית הספר'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('התחזות'));
      await tester.pumpAndSettle();
      expect(calls.single.$1, 'reportSchool');
      expect(calls.single.$2, {
        'schoolId': profile.schoolId,
        'category': 'impersonation',
      });
      expect(find.text('הדיווח נשלח לבדיקה'), findsOneWidget);
    },
  );
}
