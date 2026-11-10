import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';
import 'package:learning_tracker/features/shnayim_mikra/presentation/providers/shnayim_mikra_reader_data_provider.dart';

/// The active learner's Shnayim Mikra week and eligible catch-up assignments.
/// Weekly schedule follows the Shnayim Mikra track's stored minhag. The legacy
/// location flag is consulted only for an older track not yet initialized.
final shnayimMikraScheduleProjectionProvider =
    FutureProvider.autoDispose<ShnayimMikraScheduleProjection?>((ref) async {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) return null;
      final history = await ref.watch(
        learnerLockSettingsProvider(scope).future,
      );
      final settings = history.current;
      final nowUtc = ref.watch(localDayClockProvider).nowUtc();
      final nowAtLearnerLocation = LearnerZone.of(
        settings.timeZone,
      ).wallTimeOf(nowUtc);
      final projection = ShnayimMikraWeeklyAssignment.project(
        now: DateTime.utc(
          nowAtLearnerLocation.year,
          nowAtLearnerLocation.month,
          nowAtLearnerLocation.day,
          nowAtLearnerLocation.hour,
          nowAtLearnerLocation.minute,
          nowAtLearnerLocation.second,
          nowAtLearnerLocation.millisecond,
          nowAtLearnerLocation.microsecond,
        ),
        inIsrael:
            (settings.shnayimMikraParshaSchedule ??
                    shnayimMikraScheduleFromLegacyYomTovFlag(
                      yomTovDays: settings.yomTovDays,
                      legacyInIsrael: settings.inIsrael,
                    ))
                .usesEretzYisraelCalendar,
        dueAtForShabbos: (shabbosDate) =>
            shnayimMikraDueAtForShabbos(shabbosDate, history),
      );
      if (projection.catchUp.isEmpty) return projection;
      final learnerState = await ref.watch(learnerStateProvider(scope).future);
      final learnedRefs =
          learnerState.curricula['shnayim_mikra']?.learntLeaves ??
          const <String>{};
      final completedKeys = <String>{};
      for (final assignment in projection.catchUp) {
        final aliyahRefs = await ref.watch(
          shnayimMikraParshaVerseRefsProvider((
            assignment.portionKey,
            assignment.inIsrael,
          )).future,
        );
        if (aliyahRefs.expand((refs) => refs).every(learnedRefs.contains)) {
          completedKeys.add(assignment.key);
        }
      }
      return ShnayimMikraScheduleProjection(
        current: projection.current,
        catchUp: [
          for (final assignment in projection.catchUp)
            if (!completedKeys.contains(assignment.key)) assignment,
        ],
      );
    }, retry: (retryCount, error) => null);
