/// Regression tests for R6-17: ArrowButton chevrons mirror in RTL.
///
/// ActiveTracksCarouselSection passes Icons.chevron_left/right to ArrowButton.
/// In RTL the "previous" button must show chevron_right and the "next" button
/// must show chevron_left so they visually point in the correct direction.
@Tags(['dashboard', 'rtl'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/arrow_button.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _profileId = 1;

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => _profileId;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride(this._useHebrew);
  final bool _useHebrew;
  @override
  bool build() => _useHebrew;
}

CurriculumTrack _track(int id) => CurriculumTrack(
  id: id,
  profileId: _profileId,
  curriculumId: CurriculumId.mishnayos.storageKey,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

Widget _buildCarousel({
  required Locale locale,
  required List<CurriculumTrack> tracks,
}) {
  return ProviderScope(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(locale.languageCode == 'he'),
      ),
      // Stub the dual-progress provider to avoid real DB calls.
      trackDualProgressMetricsProvider(
        _profileId,
      ).overrideWith((ref) async => []),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: ActiveTracksCarouselSection(
            title: 'Active Tracks',
            subtitle: 'Your learning',
            activeTracks: tracks,
            allTasks: const [],
            titleStyle: const TextStyle(),
          ),
        ),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // Provide two tracks so both arrow buttons are rendered; when only one track
  // exists the carousel buttons are disabled and only one is rendered.
  final twoTracks = [_track(1), _track(2)];

  group('ActiveTracksCarouselSection — ArrowButton chevron RTL (R6-17)', () {
    testWidgets(
      'LTR: "previous" button shows chevron_left, "next" button shows chevron_right',
      (tester) async {
        await tester.pumpWidget(
          _buildCarousel(locale: const Locale('en'), tracks: twoTracks),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final arrowButtons = find.byType(ArrowButton);
        expect(arrowButtons, findsNWidgets(2));

        final icons = tester
            .widgetList<Icon>(
              find.descendant(of: arrowButtons, matching: find.byType(Icon)),
            )
            .map((i) => i.icon)
            .toList();

        // In LTR: first = chevron_left (previous), second = chevron_right (next).
        expect(icons[0], Icons.chevron_left_rounded);
        expect(icons[1], Icons.chevron_right_rounded);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'RTL: "previous" button shows chevron_right, "next" button shows chevron_left',
      (tester) async {
        await tester.pumpWidget(
          _buildCarousel(locale: const Locale('he'), tracks: twoTracks),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final arrowButtons = find.byType(ArrowButton);
        expect(arrowButtons, findsNWidgets(2));

        final icons = tester
            .widgetList<Icon>(
              find.descendant(of: arrowButtons, matching: find.byType(Icon)),
            )
            .map((i) => i.icon)
            .toList();

        // In RTL: "previous" button visually points right, "next" points left.
        expect(icons[0], Icons.chevron_right_rounded);
        expect(icons[1], Icons.chevron_left_rounded);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
