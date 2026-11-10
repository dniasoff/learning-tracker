import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_weekly_assignment.dart';

/// The active learner's Shnayim Mikra week and eligible catch-up assignments.
/// Region comes from the same governed Shabbat location history as the lock.
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
      return ShnayimMikraWeeklyAssignment.project(
        now: DateTime(
          nowAtLearnerLocation.year,
          nowAtLearnerLocation.month,
          nowAtLearnerLocation.day,
          nowAtLearnerLocation.hour,
        ),
        inIsrael: settings.shnayimMikraInIsrael,
      );
    }, retry: (retryCount, error) => null);
