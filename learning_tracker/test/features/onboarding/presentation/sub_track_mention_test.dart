/// Story 2.4 (DNI-495) AC-9: the one passive onboarding sub-track mention on
/// the existing main-track goal step, and no sub-track prompt anywhere else.
@Tags(['sub_tracks', 'onboarding'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart'
    show TransliterationVariant;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/info_note.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart'
    show ActiveProfileId, activeProfileIdProvider;
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/pump_app.dart';

const _mention =
    'School and rebbe sub-tracks can be added later from Settings → Manage '
    'tracks.';

class _ContentRepo extends Mock implements ContentRepository {}

class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _GregorianDates extends UseHebrewDate {
  @override
  bool build() => false;
}

class _Profile extends ActiveProfileId {
  @override
  String? build() => '01J6Q2H4A8M7K3P9R5T6V8WXYC';
}

class _Ashkenazi extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

List<Override> _overrides() {
  final content = _ContentRepo();
  when(
    () => content.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);
  return [
    contentRepositoryProvider.overrideWith((ref) => content),
    useHebrewTermsProvider.overrideWith(_EnglishTerms.new),
    useHebrewDateProvider.overrideWith(_GregorianDates.new),
    activeProfileIdProvider.overrideWith(_Profile.new),
    currentTransliterationVariantProvider.overrideWith(_Ashkenazi.new),
    scopedCurriculumContentProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => const <ContentItem>[]),
    scopedItemCountProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => 30),
  ];
}

Future<void> _pumpStep(WidgetTester tester, {required bool onboarding}) async {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: _overrides(),
      retry: (_, _) => null,
      child: Scaffold(
        body: SelfPacedGoalStep(
          curriculumId: CurriculumId.mishnayos,
          studyDays: const {1: 'study', 2: 'study', 3: 'study'},
          onComplete: (_) {},
          showSubTrackMention: onboarding,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => registerFallbackValue(CurriculumId.mishnayos));

  testWidgets('onboarding: exactly one static note on the goal step', (
    tester,
  ) async {
    await _pumpStep(tester, onboarding: true);
    expect(find.text(_mention), findsOneWidget);
    expect(find.byType(InfoNote), findsOneWidget);
    final note = find.byType(InfoNote);
    for (final interactive in [
      TextButton,
      ElevatedButton,
      FilledButton,
      OutlinedButton,
      InkWell,
      GestureDetector,
      TextField,
    ]) {
      expect(
        find.descendant(of: note, matching: find.byType(interactive)),
        findsNothing,
        reason: 'the mention has no $interactive',
      );
    }
    // It adds no step: the goal step's own Continue is still the only action.
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('outside onboarding (Add track later) there is no note', (
    tester,
  ) async {
    await _pumpStep(tester, onboarding: false);
    expect(find.text(_mention), findsNothing);
    expect(find.byType(InfoNote), findsNothing);
  });

  test('only onboarding passes the mention, and nothing else prompts '
      'sub-track creation (UX-DR-66, UX-DR-167)', () {
    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('/l10n/'))
        .toList();
    List<String> using(String symbol) => [
      for (final f in libFiles)
        if (f.readAsStringSync().contains(symbol)) f.path.replaceAll(r'\', '/'),
    ];
    expect(using('l10n.onboardingSubTrackMention'), [
      'lib/features/tracks/setup/presentation/steps/step_goal.dart',
    ]);
    expect(using('showSubTrackMention: widget.isOnboarding'), [
      'lib/features/tracks/setup/presentation/screens/add_track_flow_screen.dart',
    ]);
    // The only create entry point is the hub's Add sub-track.
    expect(using('l10n.subTrackHubAdd'), [
      'lib/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart',
    ]);
  });
}
