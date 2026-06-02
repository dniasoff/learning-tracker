// L1 widget test for showAddProfileDialog error handling.
//
// D4 regression: a createProfile failure (e.g. an account_id FK violation when
// currentAccountId doesn't match the active DB's accounts row) must surface an
// error snackbar — it was previously swallowed (dialog closed, no profile, no
// feedback).
@Tags(['l1', 'profiles', 'add_profile_dialog'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'D4: createProfile failure surfaces an error snackbar (not a silent no-op)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = createTestDatabase();
      await seedProfileWithIds(db, profileId: 1, accountId: 1);
      addTearDown(() => db.close());

      final repo = _MockProfileRepository();
      when(
        () => repo.createProfile(
          accountId: any(named: 'accountId'),
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
          avatarIndex: any(named: 'avatarIndex'),
        ),
      ).thenThrow(Exception('FOREIGN KEY constraint failed'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => showAddProfileDialog(ctx, ref),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Name non-empty → Create enabled (mode defaults to adult).
      await tester.enterText(find.byType(TextField).first, 'TestKid');
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // debounced name check

      await tester.tap(find.text('Create Profile'));
      await tester
          .pump(); // dialog pops → createProfile awaited → throws → catch
      await tester.pump(const Duration(milliseconds: 100));

      // The failure is surfaced, not silently swallowed.
      expect(find.text('An unexpected error occurred.'), findsOneWidget);

      // Flush the delayed controller-dispose timer, then tear down.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // Autocorrect regression: typing a profile name like "Talmid1" was being
  // mangled by the soft-keyboard autocorrect (e.g. into "Talmid16"). The name
  // field must store the typed text verbatim — autocorrect and keyboard
  // suggestions disabled.
  testWidgets('name field disables autocorrect and keyboard suggestions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = createTestDatabase();
    await seedProfileWithIds(db, profileId: 1, accountId: 1);
    addTearDown(() => db.close());

    final repo = _MockProfileRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          currentAccountIdProvider.overrideWithValue(1),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (ctx, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showAddProfileDialog(ctx, ref),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);

    // Close the dialog and flush the delayed controller-dispose timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(Duration.zero);
  });

  // Sanity: a successful create returns the model and does NOT show the error.
  testWidgets('successful createProfile shows no error snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final db = createTestDatabase();
    await seedProfileWithIds(db, profileId: 1, accountId: 1);
    addTearDown(() => db.close());

    final repo = _MockProfileRepository();
    when(
      () => repo.createProfile(
        accountId: any(named: 'accountId'),
        displayName: any(named: 'displayName'),
        mode: any(named: 'mode'),
        avatarIndex: any(named: 'avatarIndex'),
      ),
    ).thenAnswer(
      (_) async => ProfileModel(
        id: 9,
        accountId: 1,
        displayName: 'TestKid',
        mode: 'adult',
        avatarIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          currentAccountIdProvider.overrideWithValue(1),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (ctx, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showAddProfileDialog(ctx, ref),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'TestKid');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Create Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('An unexpected error occurred.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
