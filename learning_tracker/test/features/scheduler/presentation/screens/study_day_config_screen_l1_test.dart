/// L1 widget coverage for the study-day configuration screen.
@Tags(['scheduler', 'l1'])
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/pump_app.dart';

const _uid = 'study-day-screen-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

Widget _app({
  required bool hasChazara,
  required FirestoreStudyDayConfigRepository repository,
  Locale locale = const Locale('en'),
  bool useHebrewTerms = false,
  Stream<List<StudyDayConfigEntry>>? configStream,
  TutorPermissions? tutorPermissions,
}) => pumpApp(
  child: const StudyDayConfigScreen(curriculumId: CurriculumId.mishnayos),
  locale: locale,
  overrides: [
    if (configStream != null)
      studyDayConfigsProvider(
        CurriculumId.mishnayos,
      ).overrideWith((ref) => configStream),
    curriculumTrackHasChazaraProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) => Future.value(hasChazara)),
    firestoreStudyDayConfigRepositoryProvider.overrideWith(
      (ref) async => repository,
    ),
    allDailyTasksProvider.overrideWith((ref) => Future.value(const [])),
    activeTutorPermissionsProvider.overrideWithValue(tutorPermissions),
    useHebrewTermsProvider.overrideWithValue(useHebrewTerms),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
  ],
);

FirestoreStudyDayConfigRepository _repository(
  FakeFirebaseFirestore firestore,
) => FirestoreStudyDayConfigRepository(
  firestore: firestore,
  uid: _uid,
  profileId: _profileId,
);

void main() {
  testWidgets('renders all weekday tiles, labels, legend, and summary', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await tester.pumpWidget(_app(hasChazara: true, repository: repository));
    await tester.pump();

    for (final label in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Shabbos']) {
      expect(find.text(label), findsOneWidget, reason: '$label tile missing');
    }
    expect(
      find.text(
        'Choose which days include new learning and which are for review only.',
      ),
      findsOneWidget,
    );
    expect(find.text('Study'), findsAtLeast(1));
    expect(find.text('Review only'), findsNWidgets(1));
    expect(find.text('7 study days per week'), findsOneWidget);
  });

  testWidgets('seeded review-day data changes the summary and tile badge', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await repository.setDayConfig(
      curriculumId: CurriculumId.mishnayos,
      dayOfWeek: 1,
      dayType: DayType.review,
    );
    await tester.pumpWidget(_app(hasChazara: true, repository: repository));
    await tester.pump();

    expect(find.text('6 study days per week'), findsOneWidget);
    expect(find.text('Review only'), findsNWidgets(2));
    expect(find.text('Mon'), findsOneWidget);
  });

  testWidgets('tapping a study day writes review through Firestore', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await tester.pumpWidget(_app(hasChazara: true, repository: repository));
    await tester.pump();
    await tester.tap(find.text('Sun'));
    await tester.pump();

    final configs = await repository.getConfigsForCurriculum(
      CurriculumId.mishnayos,
    );
    expect(configs, hasLength(1));
    expect(configs.single.dayOfWeek, 7);
    expect(configs.single.dayType, DayType.review);
  });

  testWidgets('learn-only tracks show the neutral all-study state', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await tester.pumpWidget(_app(hasChazara: false, repository: repository));
    await tester.pump();

    expect(
      find.text('All days are study days for this track.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Choose which days include new learning and which are for review only.',
      ),
      findsNothing,
    );
    expect(find.text('Sun'), findsNothing);
    expect(find.textContaining('chazara'), findsNothing);
    expect(find.textContaining('Chazara'), findsNothing);
    expect(find.textContaining('review'), findsNothing);
    expect(find.textContaining('Review'), findsNothing);
    for (final label in ['Personal', 'Standard', 'Custom', 'אישי']) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('renders localized Hebrew badges and RTL weekday labels', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await tester.pumpWidget(
      _app(
        hasChazara: true,
        repository: repository,
        locale: const Locale('he'),
        useHebrewTerms: true,
      ),
    );
    await tester.pump();

    expect(find.text('לימוד'), findsAtLeast(1));
    expect(find.text('חזרה בלבד'), findsOneWidget);
    for (final label in ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'שבת']) {
      expect(find.text(label), findsOneWidget, reason: '$label label missing');
    }
    expect(
      Directionality.of(tester.element(find.text('א׳'))),
      TextDirection.rtl,
    );
  });

  testWidgets('read-only tutor cannot write a day, editable tutor can', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await tester.pumpWidget(
      _app(
        hasChazara: true,
        repository: repository,
        tutorPermissions: TutorPermissions.readOnly(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sun'));
    await tester.pump();
    expect(
      await repository.getConfigsForCurriculum(CurriculumId.mishnayos),
      isEmpty,
    );

    await tester.pumpWidget(
      _app(
        hasChazara: true,
        repository: repository,
        tutorPermissions: const TutorPermissions(canEditStudyDays: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Sun'));
    await tester.pump();
    final configs = await repository.getConfigsForCurriculum(
      CurriculumId.mishnayos,
    );
    expect(configs.single.dayOfWeek, 7);
    expect(configs.single.dayType, DayType.review);
  });

  testWidgets('loading state shows a progress indicator', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    final controller = StreamController<List<StudyDayConfigEntry>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _app(
        hasChazara: true,
        repository: repository,
        configStream: controller.stream,
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state shows a retry action', (tester) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    await tester.pumpWidget(
      _app(
        hasChazara: true,
        repository: repository,
        configStream: Stream.error(StateError('study-day read failed')),
      ),
    );
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('zero configured study days show the warning and ordering', (
    tester,
  ) async {
    final firestore = createFakeFirestore(authenticatedUid: _uid);
    final repository = _repository(firestore);
    for (final day in [1, 2, 3, 4, 5, 6, 7]) {
      await repository.setDayConfig(
        curriculumId: CurriculumId.mishnayos,
        dayOfWeek: day,
        dayType: DayType.review,
      );
    }
    await tester.pumpWidget(_app(hasChazara: true, repository: repository));
    await tester.pump();

    expect(find.text('0 study days per week'), findsOneWidget);
    expect(
      find.text(
        'No study days selected — every day is review only and no new learning '
        'will be scheduled.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Sun')).dy,
      lessThan(tester.getTopLeft(find.text('Mon')).dy),
    );
  });
}
