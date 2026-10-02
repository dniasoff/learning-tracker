/// DNI-479 (AD-40 surfaces): the carousel's visible page is the curriculum
/// in view, whose streak the dashboard shows.
@Tags(['dashboard'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/arrow_button.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYB';

class _ProfileIdOverride extends ActiveProfileId {
  @override
  String build() => _profileId;
}

CurriculumTrackEntity _track(CurriculumId c) => CurriculumTrackEntity(
  curriculumId: c,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

final _tracks = [_track(CurriculumId.mishnayos), _track(CurriculumId.bavli)];

Widget _carousel(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
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
          activeTracks: _tracks,
          allTasks: const [],
          titleStyle: const TextStyle(),
        ),
      ),
    ),
  ),
);

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      trackDualProgressMetricsProvider.overrideWith((ref) async => []),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Unmounts the tree and lets Riverpod's auto-dispose timer run.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('paging the carousel puts that curriculum in view', (
    tester,
  ) async {
    final container = _container();
    await tester.pumpWidget(_carousel(container));
    await tester.pumpAndSettle();
    expect(container.read(dashboardCurriculumInViewProvider), isNull);

    await tester.tap(find.byType(ArrowButton).last);
    await tester.pumpAndSettle();
    expect(
      container.read(dashboardCurriculumInViewProvider),
      CurriculumId.bavli,
    );

    await tester.tap(find.byType(ArrowButton).first);
    await tester.pumpAndSettle();
    expect(
      container.read(dashboardCurriculumInViewProvider),
      CurriculumId.mishnayos,
    );
    await _unmount(tester);
  });

  testWidgets('a rebuilt carousel opens on the curriculum in view', (
    tester,
  ) async {
    final container = _container();
    container
        .read(dashboardCurriculumInViewProvider.notifier)
        .show(CurriculumId.bavli);
    await tester.pumpWidget(_carousel(container));
    await tester.pumpAndSettle();

    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.controller!.initialPage, 1);
    await _unmount(tester);
  });
}
