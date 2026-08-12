/// Firestore-native coverage for study-day writes and their invalidation order.
@Tags(['scheduler', 'study_day', 'studyday_toggle_write_09'])
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/services/study_day_toggle_service.dart';

import '../../../helpers/firestore_fake.dart';

const _uid = 'study-day-write-uid';
const _profileId = '01J9V8J5Q2K7M3N6P4R8T1WXYZ';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreStudyDayConfigRepository repo;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    repo = FirestoreStudyDayConfigRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  });

  test('a toggle persists the selected day type in Firestore', () async {
    await repo.setDayConfig(
      curriculumId: CurriculumId.mishnayos,
      dayOfWeek: 1,
      dayType: DayType.review,
    );

    final configs = await repo.getConfigsForCurriculum(CurriculumId.mishnayos);
    expect(configs.single.dayOfWeek, 1);
    expect(configs.single.dayType, DayType.review);
  });

  test('a second write replaces the same curriculum/day document', () async {
    await repo.setDayConfig(
      curriculumId: CurriculumId.mishnayos,
      dayOfWeek: 1,
      dayType: DayType.review,
    );
    await repo.setDayConfig(
      curriculumId: CurriculumId.mishnayos,
      dayOfWeek: 1,
      dayType: DayType.study,
    );

    final configs = await repo.getConfigsForCurriculum(CurriculumId.mishnayos);
    expect(configs.single.dayType, DayType.study);
  });

  test('curriculum document paths remain isolated', () async {
    await repo.setDayConfig(
      curriculumId: CurriculumId.bavli,
      dayOfWeek: 5,
      dayType: DayType.review,
    );

    expect(await repo.getConfigsForCurriculum(CurriculumId.mishnayos), isEmpty);
    expect(
      (await repo.getConfigsForCurriculum(CurriculumId.bavli)).single.dayType,
      DayType.review,
    );
  });

  test(
    'writeThenInvalidate returns only after the Firestore write resolves',
    () async {
      var invalidated = false;
      await writeThenInvalidate(
        write: () => repo.setDayConfig(
          curriculumId: CurriculumId.mishnayos,
          dayOfWeek: 3,
          dayType: DayType.review,
        ),
        invalidate: () => invalidated = true,
      );

      expect(invalidated, isTrue);
      expect(
        (await repo.getConfigsForCurriculum(
          CurriculumId.mishnayos,
        )).single.dayType,
        DayType.review,
      );
    },
  );

  test('invalidation waits for an in-flight write', () async {
    final events = <String>[];
    final completer = Completer<void>();
    final future = writeThenInvalidate(
      write: () async {
        await completer.future;
        events.add('write');
      },
      invalidate: () => events.add('invalidate'),
    );

    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    completer.complete();
    await future;
    expect(events, ['write', 'invalidate']);
  });
}
