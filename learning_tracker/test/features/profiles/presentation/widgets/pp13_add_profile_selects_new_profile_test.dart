/// PP-13 regression test: After creating a child profile, the active-profile
/// context (selectedProfileIdProvider) must be updated to the new profile's id
/// before the forced Parent PIN setup dialog is shown.
///
/// RED → GREEN cycle:
///   RED:  showAddProfileDialog does NOT call selectedProfileIdProvider.select()
///         before showParentPinSetupDialog — the header behind the PIN dialog
///         still shows the previously-active profile's stale identity.
///   GREEN: selectedProfileIdProvider is set to the new child profile's id
///          before the PIN setup dialog runs.
@Tags(['profiles', 'pp13'])
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

  group('PP-13 selectedProfileId updated before PIN setup', () {
    testWidgets('creates child profile: selectedProfileIdProvider switches to new id '
        'before PIN setup dialog opens', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const kPrevProfileId = 1;
      const kNewProfileId = 99;

      final db = createTestDatabase();
      await seedProfileWithIds(db, profileId: kPrevProfileId, accountId: 1);
      addTearDown(() => db.close());

      final mockRepo = _MockProfileRepository();
      when(
        () => mockRepo.createProfile(
          accountId: any(named: 'accountId'),
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
          avatarIndex: any(named: 'avatarIndex'),
        ),
      ).thenAnswer(
        (_) async => ProfileModel(
          id: kNewProfileId,
          accountId: 1,
          displayName: 'Beni',
          mode: 'child',
          avatarIndex: 0,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      // Capture selected id changes.
      final selectedIds = <int?>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(mockRepo),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(kPrevProfileId),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (ctx, ref, _) {
                final id = ref.watch(selectedProfileIdProvider);
                selectedIds.add(id);
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open'),
                      onPressed: () => showAddProfileDialog(ctx, ref),
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Pre-condition: old profile is active (kPrevProfileId should be in captured list).
      expect(selectedIds.contains(kPrevProfileId), isTrue);

      // Open the dialog via onPressed callback to avoid InkSparkle shader.
      final openBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('open')),
      );
      openBtn.onPressed?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type a profile name.
      await tester.enterText(find.byType(TextField).first, 'Beni');
      await tester.pump(const Duration(milliseconds: 400));

      // Select child mode via GestureDetector (avoids InkSparkle).
      // Look for child mode card: find a GestureDetector near "Learner Mode".
      final childText = find.textContaining('Learner Mode');
      if (childText.evaluate().isNotEmpty) {
        final gestureFinder = find.ancestor(
          of: childText.first,
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector && w.onTap != null,
          ),
        );
        if (gestureFinder.evaluate().isNotEmpty) {
          final gd = tester.widget<GestureDetector>(gestureFinder.first);
          gd.onTap?.call();
          await tester.pump();
        }
      }

      // Submit via Create Profile button callback (avoids InkSparkle).
      final createBtns = find.widgetWithText(FilledButton, 'Create Profile');
      if (createBtns.evaluate().isNotEmpty) {
        final fb = tester.widget<FilledButton>(createBtns.first);
        if (fb.onPressed != null) {
          fb.onPressed!();
        } else {
          // Default mode is 'adult' — just tap directly.
          await tester.tap(find.text('Create Profile'));
        }
      } else {
        await tester.tap(find.text('Create Profile'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // PP-13 fix: selectedProfileIdProvider must be updated to the new child.
      // The captured list should contain kNewProfileId after the create.
      expect(
        selectedIds.any((id) => id == kNewProfileId),
        isTrue,
        reason:
            'PP-13: selectedProfileIdProvider must be set to the newly-created '
            'child profile id ($kNewProfileId) before the PIN setup dialog runs. '
            'Observed ids: $selectedIds',
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}
