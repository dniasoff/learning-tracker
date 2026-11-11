import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/social/domain/school.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';
import 'package:learning_tracker/features/social/presentation/screens/school_roster_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  testWidgets('staff roster opens the shared summary by summary id', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRosterProvider.overrideWith(
            (ref, query) async => const [
              SchoolRosterEntry(
                summaryId: 'profile-summary-id',
                displayName: 'Learner',
                avatarId: 1,
                mode: ProfileMode.child,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SchoolRosterScreen(
            schoolId: 'school_12345678',
            onOpenSummary: opened.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learner'));
    expect(opened, ['profile-summary-id']);
  });
}
