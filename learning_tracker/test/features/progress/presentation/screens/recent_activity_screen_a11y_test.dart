/// Regression test for AUD-progress-02 (AX-3): the hand-rolled back-header
/// `IconButton` on [RecentActivityScreen] had no `tooltip`/`semanticLabel`.
/// Unlike an `AppBar`'s automatic leading back button, Flutter supplies no
/// implicit semantics for a custom header row, so TalkBack/VoiceOver users
/// tabbing to this control on a screen reachable from every Progress-hub
/// session heard only "button" with no indication it navigates back.
///
/// Mirrors the AUD-gamification-04 fix/test shape
/// (`reward_config_header_a11y_test.dart`): `IconButton(tooltip: ...)` alone
/// does NOT populate `SemanticsData.label` on the current Flutter SDK
/// (3.44.6) — `Tooltip`/`RawTooltip` now populate `SemanticsData.tooltip`
/// instead (see packages/flutter/lib/src/widgets/raw_tooltip.dart
/// `semanticsTooltip`). `find.bySemanticsLabel` / `SemanticsNode.label` only
/// see the `label` field, so the fix additionally sets
/// `Icon(semanticLabel: ...)`, which the framework surfaces as
/// `Semantics(label: ...)` (AX-3's named mechanism).
///
/// NOTE: each test creates + closes its own in-memory db within the same
/// `testWidgets` body (rather than a shared `setUp`/`tearDown` pair) to
/// satisfy `tool/check_inmemory_db_close.dart` (TQ-6, AUD-t-gamification-04)
/// — see `test/track_setup/clear_overdue_button_test.dart` for the same
/// established shape.
@Tags(['progress', 'a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/recent_activity_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';

/// Test override for [ActiveProfileId] that returns a fixed id.
class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

Widget _buildScreen(UserDatabase db, {Locale locale = const Locale('en')}) =>
    ProviderScope(
      overrides: [
        userDatabaseProvider.overrideWith((ref) => db),
        activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
        useHebrewTermsProvider.overrideWith(
          () => _UseHebrewTermsOverride(useHebrew: false),
        ),
        dashboardUserModeProvider.overrideWith(
          (ref) => Future.value(ProfileMode.adult),
        ),
        dashboardStreakProvider.overrideWith(
          (ref) => Stream.value((currentStreak: 3, maxStreak: 7)),
        ),
        anyActiveTrackHasChazaraProvider.overrideWith(
          (ref) => Future.value(true),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecentActivityScreen(),
      ),
    );

Future<void> _tearDownSemantics(
  WidgetTester tester,
  SemanticsHandle handle,
) async {
  handle.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

void main() {
  group('RecentActivityScreen — AUD-progress-02: back button a11y', () {
    testWidgets('EN: back IconButton exposes a non-empty Semantics label', (
      tester,
    ) async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      await seedTrack(db, profileId: _profileId, curriculumId: _curriculumId);

      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_buildScreen(db));
      await tester.pump();

      final backButton = find.widgetWithIcon(
        IconButton,
        Icons.arrow_back_ios_new_rounded,
      );
      expect(backButton, findsOneWidget);

      // AC (literal): a semantics test confirms the back control announces
      // a localized label.
      final semantics = tester.getSemantics(backButton);
      expect(
        semantics.label,
        isNotEmpty,
        reason:
            'AUD-progress-02: the icon-only back button must expose a '
            'non-empty semantic label so TalkBack/VoiceOver announce its '
            'purpose.',
      );
      expect(semantics.label, 'Back');
      expect(find.bySemanticsLabel('Back'), findsOneWidget);

      await _tearDownSemantics(tester, handle);
    });

    testWidgets(
      'HE: back IconButton exposes the Hebrew MaterialLocalizations label',
      (tester) async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);
        await seedTrack(db, profileId: _profileId, curriculumId: _curriculumId);

        final handle = tester.ensureSemantics();

        await tester.pumpWidget(_buildScreen(db, locale: const Locale('he')));
        await tester.pump();

        expect(
          find.bySemanticsLabel('הקודם'),
          findsOneWidget,
          reason:
              'AUD-progress-02: the Hebrew back-button label must be '
              'exposed on the semantics tree, not an English leak.',
        );

        await _tearDownSemantics(tester, handle);
      },
    );
  });
}
