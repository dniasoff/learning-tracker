/// Regression tests for AUD-dashboard-01: ArrowButton carousel controls
/// must expose a non-empty, direction-specific semantic label so
/// TalkBack/VoiceOver users know what each icon-only control does and
/// which direction it moves.
///
/// The EN test exercises the AC1 "widget test using tester.getSemantics"
/// requirement directly. The HE test exercises the AC2 "manual TalkBack/
/// VoiceOver pass ... Hebrew ARB equivalents" requirement by pumping the
/// real `AppLocalizations` Hebrew delegate and asserting the semantics
/// tree — the exact data TalkBack/VoiceOver read from — carries the
/// Hebrew ARB strings. A literal on-device screen-reader session is
/// outside what this agent can execute in a headless worktree; asserting
/// against the semantics tree is the standard automated proxy for it,
/// since that tree is what the assistive services consume verbatim.
@Tags(['dashboard', 'a11y'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  // Provide two tracks so both arrow buttons are rendered and enabled; when
  // only one track exists one of the two controls is disabled.
  final twoTracks = [_track(1), _track(2)];

  group('ActiveTracksCarouselSection — AUD-dashboard-01: accessibility', () {
    testWidgets('EN: previous/next ArrowButton controls expose non-empty, '
        'direction-specific semantic labels', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildCarousel(locale: const Locale('en'), tracks: twoTracks),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final arrowButtons = find.byType(ArrowButton);
      expect(arrowButtons, findsNWidgets(2));

      // AC1 (literal): use tester.getSemantics on ActiveTracksCarouselSection's
      // arrow controls to confirm each exposes a non-empty, direction-specific
      // label (first = previous, second = next per the widget's build order).
      final previousSemantics = tester.getSemantics(arrowButtons.at(0));
      final nextSemantics = tester.getSemantics(arrowButtons.at(1));

      expect(
        previousSemantics.label,
        isNotEmpty,
        reason:
            'AUD-dashboard-01: the "previous" arrow control must expose a '
            'non-empty semantic label',
      );
      expect(
        nextSemantics.label,
        isNotEmpty,
        reason:
            'AUD-dashboard-01: the "next" arrow control must expose a '
            'non-empty semantic label',
      );
      expect(
        previousSemantics.label,
        isNot(equals(nextSemantics.label)),
        reason:
            'AUD-dashboard-01: the two arrow controls must carry '
            'direction-specific (distinct) labels, not a shared generic one',
      );
      expect(previousSemantics.label, 'Previous track');
      expect(nextSemantics.label, 'Next track');

      // Cross-check via the semantics-tree-wide finder too.
      expect(find.bySemanticsLabel('Previous track'), findsOneWidget);
      expect(find.bySemanticsLabel('Next track'), findsOneWidget);

      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'HE: previous/next ArrowButton controls announce the Hebrew ARB '
      'equivalents (proxy for a TalkBack/VoiceOver device pass)',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildCarousel(locale: const Locale('he'), tracks: twoTracks),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ArrowButton), findsNWidgets(2));

        expect(
          find.bySemanticsLabel('המסלול הקודם'),
          findsOneWidget,
          reason:
              'AUD-dashboard-01: the Hebrew ARB label for the "previous" '
              'arrow control must be exposed on the semantics tree',
        );
        expect(
          find.bySemanticsLabel('המסלול הבא'),
          findsOneWidget,
          reason:
              'AUD-dashboard-01: the Hebrew ARB label for the "next" arrow '
              'control must be exposed on the semantics tree',
        );

        handle.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
