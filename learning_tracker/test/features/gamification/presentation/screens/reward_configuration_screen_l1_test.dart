// L1 widget tests for RewardConfigurationScreen
//
// Coverage:
//   1. Screen renders form fields and Save Reward button.
//   2. Save Reward with empty name → RewardSaveInvalidInput → no dialog shown.
//   3. Save Reward with zero points → RewardSaveInvalidInput → no dialog shown.
//   4. Points field only accepts digit characters (digits-only formatter).
//   5. Valid name + positive points → saveReward called → "Reward created" dialog.
//   6. "Reward created" dialog dismissed via OK button.
//   7. Edit-mode (editingMilestoneId set): valid save → "Reward updated" dialog.
//   8. Duplicate threshold → shows snackbar with l10n string.
//   9. _openManageRewardsSheet: three-dot → popup "Manage rewards" item appears.
//  10. Manage rewards sheet → empty label directs to the form (not "below").
//  11. _confirmDelete: Delete Reward dialog appears with milestone title.
//  12. _confirmDelete confirm → milestone deleted from DB.
//  13. _confirmDelete cancel → milestone NOT deleted.
//  14. Cancel button (clearForm) resets form state.
//  15. Tutor canEditRewards=false: Save Reward tap shows permission-denied snackbar.
//  16. He-RTL smoke: locale=he → screen renders without throwing.
//
// PLURALIZATION:
//   rewardConfigPointsPreview uses ICU plural — count==1 renders the singular
//   "1 Point" (EN) / "נקודה אחת" (HE); other counts render the plural form.
//
// BUG LOG: (none detected; all tests pass)

@Tags(['needs_flutter', 'gamification', 'reward_config'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_config_controller.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/reward_configuration_screen.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/avatar_picker_row.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

RewardMilestone _fakeMs({
  String id = 'ms-1',
  String title = 'Test Reward',
  int thresholdPoints = 100,
  int iconIndex = 0,
}) => RewardMilestone(
  id: id,
  profileId: 1,
  trackId: RewardMilestone.kGlobalTrackSentinel,
  title: title,
  thresholdPoints: thresholdPoints,
  isEnabled: true,
  iconIndex: iconIndex,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// Stub [RewardConfigController] that extends the real class so Riverpod 3
/// can attach it normally via [overrideWith].
///
/// [build] seeds the Riverpod element with [_initialState].  Mutations from
/// the text-field listeners still work because [setName]/[setPointsText] are
/// inherited from the real notifier.
///
/// [saveReward] returns the pre-configured [_saveResult] instead of hitting
/// the DB.
class _FakeController extends RewardConfigController {
  final RewardForm _initialState;
  final RewardSaveResult _saveResult;

  _FakeController({RewardForm? initialState, RewardSaveResult? saveResult})
    : _initialState = initialState ?? const RewardForm(),
      _saveResult = saveResult ?? const RewardSaveInvalidInput();

  @override
  RewardForm build() => _initialState;

  @override
  Future<void> bootstrap() async {
    // Intentionally empty — build() already seeded the state.
    // Calling `state = …` here (during initState) would violate Riverpod's
    // "do not modify providers while the widget tree is building" invariant.
  }

  @override
  Future<RewardSaveResult> saveReward() async => _saveResult;

  @override
  Future<void> deleteMilestone(RewardMilestone milestone) async {}

  @override
  Future<void> toggleEnabled(RewardMilestone m) async {}

  @override
  Future<List<RewardMilestone>> milestonesForCurrentLadder() async => [];
}

/// [_FakeController] variant with a pre-seeded milestone list and a spy for
/// [deleteMilestone] calls.  Avoids real DB access in fake-async widget tests
/// (Drift isolate queries don't flush inside [testWidgets] fake timers).
class _FakeControllerWithMilestones extends _FakeController {
  final List<RewardMilestone> _milestones;
  final List<RewardMilestone> deletedMilestones = [];

  _FakeControllerWithMilestones({required List<RewardMilestone> milestones})
    : _milestones = List.of(milestones),
      super(saveResult: const RewardSaveInvalidInput());

  @override
  Future<List<RewardMilestone>> milestonesForCurrentLadder() async =>
      List.of(_milestones);

  @override
  Future<void> deleteMilestone(RewardMilestone milestone) async {
    deletedMilestones.add(milestone);
    _milestones.removeWhere((m) => m.id == milestone.id);
  }
}

// ── Widget builders ───────────────────────────────────────────────────────────

/// Builds the screen with a fake (stubbable) controller.
Widget _buildFake({
  Locale locale = const Locale('en'),
  TutorPermissions? tutorPerms,
  required _FakeController fake,
}) {
  final db = inMemoryDb();
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(1),
      activeTutorPermissionsProvider.overrideWithValue(tutorPerms),
      achievementsOverviewProvider.overrideWith(
        (ref) async => const AchievementsOverview(
          rows: [],
          unlockedCount: 0,
          totalMilestones: 0,
          trackFilterOptions: [],
        ),
      ),
      rewardConfigControllerProvider.overrideWith(() => fake),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RewardConfigurationScreen(),
    ),
  );
}

// ── Pump helpers ──────────────────────────────────────────────────────────────

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Sets the test viewport to a phone-like 1080×1920 logical-pixel size so
/// the scrollable screen content fits without clipping the Save/Cancel buttons.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Screen renders form fields and Save Reward button ───────────────────

  testWidgets('renders TextFields, Save Reward button, and avatar picker', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildFake(fake: _FakeController()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Two text fields (name + points).
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    // Save Reward button is present and visible.
    expect(find.text('Save Reward'), findsOneWidget);
    // Points hint is present exactly once.
    expect(find.text('e.g., 500'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 2. Empty name → RewardSaveInvalidInput → no dialog ────────────────────

  testWidgets('empty name: RewardSaveInvalidInput — no created dialog shown', (
    tester,
  ) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: '', pointsText: '100'),
      saveResult: const RewardSaveInvalidInput(),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Save Reward'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward created'), findsNothing);

    await _tearDown(tester);
  });

  // ── 3. Zero points → RewardSaveInvalidInput → no dialog ───────────────────

  testWidgets('zero points: RewardSaveInvalidInput — no created dialog shown', (
    tester,
  ) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'Gold Star', pointsText: '0'),
      saveResult: const RewardSaveInvalidInput(),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Save Reward'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward created'), findsNothing);

    await _tearDown(tester);
  });

  // ── 4. Digits-only formatter ───────────────────────────────────────────────

  testWidgets('points field strips non-digit characters', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildFake(fake: _FakeController()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final pointsField = find.widgetWithText(TextField, 'e.g., 500');
    await tester.enterText(pointsField, '-50abc');
    await tester.pump();

    // FilteringTextInputFormatter.digitsOnly strips everything except digits.
    final tf = tester.widget<TextField>(pointsField);
    final text = tf.controller?.text ?? '';
    expect(text.runes.every((c) => c >= 48 && c <= 57), isTrue);

    await _tearDown(tester);
  });

  // ── 5. Valid save → "Reward created" dialog ───────────────────────────────

  testWidgets('valid save → "Reward created" dialog shown', (tester) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'Gold Star', pointsText: '100'),
      saveResult: const RewardSaved(title: 'Gold Star', wasEditing: false),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Save Reward'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward created'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 6. "Reward created" dialog OK dismisses it ────────────────────────────

  testWidgets('"Reward created" dialog dismissed via OK', (tester) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'Gold Star', pointsText: '100'),
      saveResult: const RewardSaved(title: 'Gold Star', wasEditing: false),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Save Reward'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward created'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward created'), findsNothing);

    await _tearDown(tester);
  });

  // ── 7. Edit-mode save → "Reward updated" dialog ───────────────────────────

  testWidgets('edit-mode save → "Reward updated" dialog', (tester) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(
        name: 'Gold Star',
        pointsText: '200',
        editingMilestoneId: 'existing-id',
      ),
      saveResult: const RewardSaved(title: 'Gold Star', wasEditing: true),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // GA-7: edit mode shows "Update Reward" button (not "Save Reward").
    await tester.tap(find.text('Update Reward'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward updated'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 8. Duplicate threshold → snackbar ─────────────────────────────────────

  testWidgets('duplicate threshold → snackbar with l10n text', (tester) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'Gold Star', pointsText: '100'),
      saveResult: const RewardSaveDuplicateThreshold(),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Save Reward'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Another reward already uses this point value.'),
      findsOneWidget,
    );

    await _tearDown(tester);
  });

  // ── 9. Three-dot menu → "Manage rewards" popup item ──────────────────────

  testWidgets('three-dot menu shows "Manage rewards" popup item', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildFake(fake: _FakeController()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Manage rewards'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 10. Manage rewards sheet shows empty label ────────────────────────────

  testWidgets('manage rewards sheet shows empty label when no rewards', (
    tester,
  ) async {
    _useTallViewport(tester);
    // FakeController.milestonesForCurrentLadder returns [] by default.
    await tester.pumpWidget(_buildFake(fake: _FakeController()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Manage rewards'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The empty-state copy must direct the user to the actual add control —
    // the reward form on the screen — not "below" (there is no add affordance
    // below the text inside the bottom sheet). It must not say "Tap below".
    expect(
      find.text(
        'No rewards yet. Close this menu and use the form above to add one.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Tap below'), findsNothing);

    await _tearDown(tester);
  });

  // ── Preview pluralization: count==1 → singular "1 Point" ──────────────────

  testWidgets('preview shows singular "1 Point" when points is 1', (
    tester,
  ) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'Single', pointsText: '1'),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Singular form — never the broken "1 Points".
    expect(find.text('1 Point'), findsOneWidget);
    expect(find.text('1 Points'), findsNothing);

    await _tearDown(tester);
  });

  // ── Preview pluralization: count!=1 → plural "N Points" ───────────────────

  testWidgets('preview shows plural "5 Points" when points is 5', (
    tester,
  ) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'Many', pointsText: '5'),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('5 Points'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── Hebrew preview pluralization: count==1 → "נקודה אחת" ──────────────────

  testWidgets('he preview shows singular "נקודה אחת" when points is 1', (
    tester,
  ) async {
    _useTallViewport(tester);
    final fake = _FakeController(
      initialState: const RewardForm(name: 'יחיד', pointsText: '1'),
    );
    await tester.pumpWidget(
      _buildFake(fake: fake, locale: const Locale('he')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Hebrew singular: "נקודה אחת" — not "1 נקודות".
    expect(find.text('נקודה אחת'), findsOneWidget);
    expect(find.text('1 נקודות'), findsNothing);

    await _tearDown(tester);
  });

  // ── 11. _confirmDelete: dialog appears with title ─────────────────────────
  //
  // Uses _FakeControllerWithMilestones to avoid real Drift isolate queries in
  // fake-async widget tests (isolate I/O does not flush with pump()).

  testWidgets('manage sheet delete tap → Delete Reward dialog with title', (
    tester,
  ) async {
    _useTallViewport(tester);
    final silver = _fakeMs(id: 'ms-silver', title: 'Silver Star');
    final fake = _FakeControllerWithMilestones(milestones: [silver]);
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open sheet.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Manage rewards'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Silver Star'), findsOneWidget);

    // Tap delete icon.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // _confirmDelete dialog should appear.
    expect(find.text('Delete Reward'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Silver Star'), findsWidgets);

    // Dismiss via the dialog's Cancel button. The form's Cancel is also visible,
    // so we use .last to target the dialog button.
    await tester.tap(find.text('Cancel').last);
    await tester.pump();

    await _tearDown(tester);
  });

  // ── 12. _confirmDelete confirm → deleteMilestone called ──────────────────

  testWidgets('_confirmDelete confirm → deleteMilestone called on notifier', (
    tester,
  ) async {
    _useTallViewport(tester);
    final diamond = _fakeMs(id: 'ms-diamond', title: 'Diamond Star');
    final fake = _FakeControllerWithMilestones(milestones: [diamond]);
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open sheet.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Manage rewards'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap delete icon.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap confirm button ("Delete Reward" — last of two: title + button).
    await tester.tap(find.text('Delete Reward').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The spy tracked the deletion.
    expect(fake.deletedMilestones, hasLength(1));
    expect(fake.deletedMilestones.first.id, equals('ms-diamond'));

    await _tearDown(tester);
  });

  // ── 13. _confirmDelete cancel → deleteMilestone NOT called ───────────────

  testWidgets('_confirmDelete cancel → deleteMilestone NOT called', (
    tester,
  ) async {
    _useTallViewport(tester);
    final bronze = _fakeMs(id: 'ms-bronze', title: 'Bronze Star');
    final fake = _FakeControllerWithMilestones(milestones: [bronze]);
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open sheet.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Manage rewards'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap delete icon.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Cancel — tap the dialog's Cancel button (.last since form's Cancel
    // is also in the tree while the dialog is open).
    await tester.tap(find.text('Cancel').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // No deletion happened.
    expect(fake.deletedMilestones, isEmpty);

    await _tearDown(tester);
  });

  // ── 14. Cancel button → clearForm ─────────────────────────────────────────

  testWidgets('Cancel button calls clearForm — name field is cleared', (
    tester,
  ) async {
    _useTallViewport(tester);
    // seed a non-empty name so we can verify it disappears.
    final fake = _FakeController(
      initialState: const RewardForm(name: 'My Reward', pointsText: '50'),
    );
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap Cancel (l10n: rewardConfigCancel = 'Cancel').
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The inherited clearForm() updates Riverpod state → name = ''.
    // After rebuild the name text field controller is empty.
    final nameField = find.widgetWithText(TextField, 'e.g., Bronze Star');
    // When name is '' the TextField shows the hint, not the text.
    // The controller's text should be empty.
    if (nameField.evaluate().isNotEmpty) {
      final tf = tester.widget<TextField>(nameField);
      expect(tf.controller?.text ?? '', isEmpty);
    }
    // Alternatively, verify the Riverpod state: the notifier is the fake
    // but clearForm() is inherited from the real class so it sets state.name=''.
    // We verify the form is cleared by confirming the name text field hint shows.
    expect(find.text('e.g., Bronze Star'), findsWidgets);

    await _tearDown(tester);
  });

  // ── 15. Tutor canEditRewards=false → permission-denied snackbar ───────────

  testWidgets(
    'tutor canEditRewards=false: Save Reward shows permission-denied snackbar',
    (tester) async {
      _useTallViewport(tester);
      final readOnlyPerms = TutorPermissions.readOnly();
      // Even if save would succeed, the screen short-circuits to snackbar.
      final fake = _FakeController(
        initialState: const RewardForm(
          name: 'Blocked Reward',
          pointsText: '100',
        ),
        saveResult: const RewardSaved(
          title: 'Blocked Reward',
          wasEditing: false,
        ),
      );
      await tester.pumpWidget(
        _buildFake(fake: fake, tutorPerms: readOnlyPerms),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Save Reward'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n: tutorPermissionDenied = "You don't have permission to make this edit"
      expect(find.textContaining("You don't"), findsOneWidget);
      expect(find.text('Reward created'), findsNothing);

      await _tearDown(tester);
    },
  );

  // ── #40. Edit-mode preselects the existing reward's icon tile ─────────────
  //
  // Regression (#40): opening Edit on an existing reward loaded name+points
  // but the avatar picker showed no tile selected — the existing icon was not
  // surfaced (highlighted + scrolled into view). applyMilestoneToForm seeds
  // form.iconIndex, and AvatarPickerRow now scrolls so the selected tile is
  // visible even when its index sits past the first few on-screen tiles.

  testWidgets('edit existing reward → its icon tile is selected', (
    tester,
  ) async {
    _useTallViewport(tester);
    // iconIndex 6 sits past the first visible tiles in the horizontal row.
    final prize = _fakeMs(
      id: 'ms-prize',
      title: 'Prize',
      thresholdPoints: 50,
      iconIndex: 6,
    );
    final fake = _FakeControllerWithMilestones(milestones: [prize]);
    await tester.pumpWidget(_buildFake(fake: fake));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open the Manage rewards sheet.
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Manage rewards'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap the RewardCard's edit button. The name TextField also carries an
    // edit_outlined suffix icon, so the card's edit is the LAST one.
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Exactly one tile is selected, and it is the existing reward's icon (6).
    final tiles = tester
        .widgetList<AvatarTile>(find.byType(AvatarTile))
        .toList();
    final selected = <int>[
      for (var i = 0; i < tiles.length; i++)
        if (tiles[i].selected) i,
    ];
    expect(selected, equals([6]));

    await _tearDown(tester);
  });

  // ── 16. He-RTL smoke ──────────────────────────────────────────────────────

  testWidgets('he locale: screen renders without throwing', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(
      _buildFake(fake: _FakeController(), locale: const Locale('he')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // At minimum the save button renders.
    expect(find.byType(FilledButton), findsAtLeastNWidgets(1));

    await _tearDown(tester);
  });
}
