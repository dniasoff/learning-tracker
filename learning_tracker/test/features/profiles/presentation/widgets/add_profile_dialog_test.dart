// L1 widget test for showAddProfileDialog error handling.
//
// D4 regression: a createProfile failure (e.g. an account_id FK violation when
// currentAccountId doesn't match the active DB's accounts row) must surface an
// error snackbar — it was previously swallowed (dialog closed, no profile, no
// feedback).
@Tags(['l1', 'profiles', 'add_profile_dialog'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
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
        pumpApp(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: Consumer(
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
      pumpApp(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          currentAccountIdProvider.overrideWithValue(1),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
        child: Consumer(
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
        ulid: 'ulid-9',
        accountId: 1,
        displayName: 'TestKid',
        mode: 'adult',
        avatarIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await tester.pumpWidget(
      pumpApp(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          currentAccountIdProvider.overrideWithValue(1),
          profileRepositoryProvider.overrideWithValue(repo),
        ],
        child: Consumer(
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

  // P2-24 (DEFECT 2): creating an ADULT profile must select() it too, not
  // just a child one. **Corrected at P2-30: `repo.createProfile` activates
  // NOTHING (T-49/P2-30) — this dialog's own `select()` call, below, is
  // the ONLY thing that ever moves `selectedProfileIdProvider` or
  // `activeProfileDocIdProvider`, for either mode.** At the time this test
  // was written (P2-24), the real `FirestoreProfileRepositoryAdapter`
  // activated `activeProfileDocIdProvider` to the NEW profile
  // unconditionally whenever a cloud account was active (T-49/P2-23), so
  // gating `select()` on `isChild` alone genuinely split the two
  // providers on every adult creation — that defect and its fix are
  // unchanged. Before this fix, `showAddProfileDialog` only called
  // `select()` — which updates `selectedProfileIdProvider`, the provider
  // every profile-scoped screen actually reads — when
  // `created.profileMode.isChild`. Creating an adult profile therefore
  // left `selectedProfileIdProvider` on the OLD profile while the 13
  // profile-scoped Firestore providers re-keyed to the NEW one: a
  // deterministic mis-key, reachable from `manage_learners_screen`,
  // `profile_switcher_sheet`, and `profile_picker_screen`. This test uses
  // the mock repo (like every other test in this file), so it proves only
  // the dialog's own half of the fix — that `select()` now runs
  // unconditionally on success — not the repo's (now nonexistent)
  // activation, which `profile_repository_impl_t49_activation_ordering_test.dart`'s
  // CONTROL-1/CONTROL-3 cover.
  testWidgets('DEFECT 2: creating an ADULT profile also updates '
      'selectedProfileIdProvider (not just child profiles)', (tester) async {
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
        ulid: 'ulid-9',
        accountId: 1,
        displayName: 'Co-Parent',
        mode: 'adult',
        avatarIndex: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        currentAccountIdProvider.overrideWithValue(1),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    // Sanity: profile 1 is the one currently selected, exactly as it
    // would be before opening "Manage Learners" / the switcher / the
    // picker to add a second (adult) profile.
    container
        .read(selectedProfileIdProvider.notifier)
        .select(1, ulid: 'ulid-1');

    await tester.pumpWidget(
      pumpApp(
        container: container,
        child: Consumer(
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
    );

    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Name non-empty → Create enabled (mode defaults to adult — the
    // dialog's own initial `mode` value, never changed by this test).
    await tester.enterText(find.byType(TextField).first, 'Co-Parent');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Create Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      container.read(selectedProfileIdProvider),
      9,
      reason:
          'DEFECT 2 (P2-24; premise corrected at P2-30): at the time this '
          'defect was found, creating an adult profile left '
          'selectedProfileIdProvider on the OLD profile (1) while the '
          'repo-level activeProfileDocIdProvider had already moved to '
          'the NEW one (9) — every profile-scoped Firestore provider '
          '(bookmarks, learning_order) would silently read/write the '
          "new profile's tree while every selectedProfileIdProvider-"
          'keyed screen kept showing the old one. The repo no longer '
          'activates anything (T-49/P2-30), so today omitting this call '
          'would leave BOTH providers on the OLD profile instead — still '
          'wrong, for a different reason. Either way, select() must run '
          'unconditionally on success.',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // AUD-profiles-16 (EH-3 log-less catch): the live duplicate-name check's
  // `catch (_) { set(() => err = null); }` previously discarded a DB failure
  // with zero AppLogger call. This closes the db *before* pumping so
  // `profileDao.profileExistsByName(...)` throws deterministically when the
  // name field's onChanged handler runs the check — simulating any DB-layer
  // failure during that best-effort live validation.
  testWidgets(
    'AUD-profiles-16: duplicate-name check failure logs via AppLogger '
    'instead of silently discarding the exception',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = createTestDatabase();
      await seedProfileWithIds(db, profileId: 1, accountId: 1);
      // Close the DB before pumping so the duplicate-name check's DAO call
      // throws deterministically once the user types a name.
      await db.close();

      final repo = _MockProfileRepository();

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: Consumer(
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
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Name non-empty → triggers the duplicate-name check against the
      // (closed) db, which must throw.
      await tester.enterText(find.byType(TextField).first, 'TestKid');
      await tester.pump(const Duration(milliseconds: 400)); // debounced check

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any(
          (m) => m.contains('add_profile_dialog_duplicate_check_failed'),
        ),
        isTrue,
        reason:
            'A duplicate-name-check DB failure must be logged via AppLogger '
            'instead of being silently swallowed (EH-3, AUD-profiles-16). '
            'Talker history: $history',
      );

      // Close the dialog and flush the delayed controller-dispose timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(Duration.zero);
    },
  );

  // ── AUD-profiles dark-mode sweep ────────────────────────────────────────
  //
  // Two hardcoded literals here stayed fixed against surfaces that darken
  // (or paired with ink that lightens) in dark mode — see
  // test/core/theme/darkmode_sweep_contrast_test.dart for the WCAG math.

  testWidgets(
    'dark mode: Create Profile button + form labels read the theme-aware '
    'tokens (not the old hardcoded white/0xFF333333 literals)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = createTestDatabase();
      await seedProfileWithIds(db, profileId: 1, accountId: 1);
      addTearDown(() => db.close());

      final repo = _MockProfileRepository();

      await tester.pumpWidget(
        pumpApp(
          theme: AppTheme.darkTheme(),
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: Consumer(
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
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // FilledButton foregroundColor: was hardcoded Colors.white, dropping to
      // 2.52:1 against brandBlue's lightened dark value.
      final onAccent = AppTheme.darkTheme().colorScheme.onPrimary;
      expect(onAccent, isNot(const Color(0xFFFFFFFF)));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style?.foregroundColor?.resolve(<WidgetState>{}), onAccent);

      // "What's your name?" label: was hardcoded Color(0xFF333333), dropping
      // to 1.38:1 against the dialog's darkened brandCreamCard surface.
      final label = tester.widget<Text>(find.text("What's your name?"));
      expect(label.style?.color, AppPalette.dark.addProfileFormLabel);
      expect(label.style?.color, isNot(const Color(0xFF333333)));

      // Close the dialog and flush the delayed controller-dispose timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'light mode: Create Profile button + form labels stay white/0xFF333333 '
    '(no regression)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = createTestDatabase();
      await seedProfileWithIds(db, profileId: 1, accountId: 1);
      addTearDown(() => db.close());

      final repo = _MockProfileRepository();

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: Consumer(
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
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFFFFFFF),
      );

      final label = tester.widget<Text>(find.text("What's your name?"));
      expect(label.style?.color, const Color(0xFF333333));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(Duration.zero);
    },
  );
}
