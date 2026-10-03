/// The one registration path of the catch-up reminder scheduler (Story
/// 3.5, DNI-508 T2): owner devices only, every owner profile on the
/// device, re-run on app start, resume and every `learnerSettings` change.
///
/// * Owner only (AC-5): while a tutored session is active the scheduler is
///   never read, so nothing is scheduled — not even for a learner the
///   tutor can view. A tutor account with no own profile has no scope in
///   [lockDrivingScopesProvider], so it never starts either.
/// * Every owner profile (AC-1): the scopes are
///   [lockDrivingScopesProvider] (the account's learner profiles, the same
///   set the lock overlay reads), each with its own
///   `learnerLockSettingsProvider` history — the ONE settings source
///   (AD-37). The selected profile is not the only one.
/// * Settings changes and removed profiles (AC-6): both are watched, so a
///   change re-runs the reconcile, which cancels before it reschedules.
/// * App start, resume and boot (AC-7): the first run of a process and
///   every resume re-arm the pending reminders under their ids.
///
/// Plain Riverpod providers (no codegen), like `account_lock_provider`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/notifications/notifications.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/shared_prefs_catch_up_reminder_ledger.dart';
import 'package:learning_tracker/features/sacred_time/data/services/catch_up_reminder_gateway_adapter.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/catch_up_reminder_scheduler.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Whether this device may run the catch-up reminder scheduler: no
/// tutored session is active (AC-5).
final catchUpReminderOwnerDeviceProvider = Provider<bool>(
  (ref) => ref.watch(activeTutoredProfileSelectionProvider) == null,
);

/// The device-local reminder ledger.
final catchUpReminderLedgerProvider = Provider<CatchUpReminderLedger>(
  (ref) => SharedPrefsCatchUpReminderLedger(),
);

/// The scheduler's notification port: the shared gateway.
final catchUpReminderNotificationsProvider =
    Provider<CatchUpReminderNotifications>(
      (ref) =>
          GatewayCatchUpReminderNotifications(
            ref.watch(notificationServiceProvider),
          ),
    );

/// The scheduler's clock (UTC).
final catchUpReminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTimeFactory.nowUtc,
);

/// The ONE [CatchUpReminderScheduler] (AC-1). Read only by
/// [catchUpReminderSyncEffectProvider], and only on an owner device.
final catchUpReminderSchedulerProvider = Provider<CatchUpReminderScheduler>(
  (ref) => CatchUpReminderScheduler(
    notifications: ref.watch(catchUpReminderNotificationsProvider),
    ledger: ref.watch(catchUpReminderLedgerProvider),
    clock: ref.watch(catchUpReminderClockProvider),
  ),
);

/// Tells whether the active learner [scope]'s catch-up [card] would list
/// anything (Story 3.2 empty rule, AC-3), watching what it reads through
/// [ref] so a change re-runs the reconcile.
typedef CatchUpCardContentReader =
    Future<bool> Function(Ref ref, LearnerScope scope, CatchUpCardWindow card);

/// The card-content reader; null when no reader is wired (every card then
/// counts as having content).
final catchUpReminderCardContentReaderProvider =
    Provider<CatchUpCardContentReader?>((ref) => null);

/// Counts app resumes, so the reconcile re-runs and re-arms on each
/// (AC-7). Tests override it.
final catchUpReminderResumeCountProvider =
    NotifierProvider<CatchUpReminderResumeCount, int>(
      CatchUpReminderResumeCount.new,
    );

/// The resume counter behind [catchUpReminderResumeCountProvider].
class CatchUpReminderResumeCount extends Notifier<int> {
  @override
  int build() {
    final listener = AppLifecycleListener(onResume: () => state++);
    ref.onDispose(listener.dispose);
    return 0;
  }
}

/// How long the reconcile may go without a re-run when no reminder is
/// due sooner: it rolls the horizon forward and consumes past ends.
const Duration catchUpReminderRecheckInterval = Duration(hours: 6);

/// The last resume count a reconcile ran for, so the first run of a
/// process (app start, or the boot-time launch) and each resume re-arm.
final _lastRearmProvider = Provider<_RearmMark>((ref) => _RearmMark());

final class _RearmMark {
  int? resumes;
}

/// The reminder copy in the app locale (AC-9): the lock's kind as the
/// title and the learner's display name in the body — no other learner
/// data, no streak, nothing about being behind.
CatchUpReminderCopyBuilder catchUpReminderCopy(AppLocalizations l10n) =>
    (kind, name) => (
      title: switch (kind) {
        ErevKind.shabbos => l10n.catchUpReminderTitleShabbos,
        ErevKind.yomTov => l10n.catchUpReminderTitleYomTov,
        ErevKind.yomTovAndShabbos => l10n.catchUpReminderTitleYomTovAndShabbos,
        ErevKind.yomKippur => l10n.catchUpReminderTitleYomKippur,
      },
      body: l10n.catchUpReminderBody(name),
    );

/// Reconciles the device's catch-up reminders with every owner profile's
/// lock windows (T2). Kept alive and started at bootstrap; every input is
/// watched, so app start, resume, a settings change, a profile added or
/// removed, a locale change and (for the active learner) a plan change
/// each re-run it. A failure is logged; the next re-run retries.
final catchUpReminderSyncEffectProvider = FutureProvider<void>((ref) async {
  // AC-5: a tutored session never constructs or runs the scheduler.
  if (!ref.watch(catchUpReminderOwnerDeviceProvider)) return;
  final resumes = ref.watch(catchUpReminderResumeCountProvider);
  final scopes = ref.watch(lockDrivingScopesProvider);
  // Not ready (loading, unreadable): leave every reminder as it is.
  if (scopes.hasError || !scopes.hasValue) return;
  final owned = scopes.requireValue;
  // Signed out, or a tutor account with no own profile: nothing to run.
  if (owned.isEmpty) return;
  final profiles = ref.watch(profileListStreamProvider).value;
  if (profiles == null) return;
  final names = {for (final p in profiles) p.profileId: p.displayName};
  final active = ref.watch(activeLearnerScopeProvider).value;
  final contentReader = ref.watch(catchUpReminderCardContentReaderProvider);
  final clock = ref.watch(catchUpReminderClockProvider);
  final copy = catchUpReminderCopy(
    lookupAppLocalizations(ref.watch(currentAppLocaleProvider)),
  );

  // Every dependency is watched before the first await.
  final histories = {
    for (final scope in owned)
      scope: switch (ref.watch(learnerLockSettingsProvider(scope))) {
        AsyncValue(hasError: true) => null,
        AsyncValue(:final value) => value,
      },
  };
  final targets = <CatchUpReminderTarget>[];
  for (final scope in owned) {
    final history = histories[scope];
    Map<String, bool>? content;
    if (history != null && contentReader != null && scope == active) {
      // Only the active learner's plan is loaded on this device; the
      // other profiles' cards count as having content (A-6 default).
      content = {};
      for (final card in upcomingCatchUpCards(history, clock())) {
        try {
          content[card.key] = await contentReader(ref, scope, card);
        } on Object catch (e, st) {
          AppLogger.instance.warning(
            event: 'catch_up_reminder_content_unknown',
            exception: e,
            stackTrace: st,
          );
        }
        if (!ref.mounted) return;
      }
    }
    final known = content;
    targets.add(
      CatchUpReminderTarget(
        profileId: scope.profileId,
        displayName: names[scope.profileId] ?? '',
        history: history,
        hasCardContent: known == null ? null : (card) async => known[card.key],
      ),
    );
  }
  if (!ref.mounted) return;

  final mark = ref.read(_lastRearmProvider);
  final rearm = mark.resumes != resumes;
  mark.resumes = resumes;
  final scheduler = ref.read(catchUpReminderSchedulerProvider);
  try {
    await scheduler.reconcile(
      targets: targets,
      onDeviceProfileIds: {for (final s in owned) s.profileId},
      copy: copy,
      rearm: rearm,
    );
  } on Object catch (e, st) {
    mark.resumes = null; // re-arm on the next run
    AppLogger.instance.error(
      event: 'catch_up_reminder_reconcile_failed',
      exception: e,
      stackTrace: st,
    );
  }
  if (!ref.mounted) return;

  // Re-run just after the next reminder is due (it is then consumed) and
  // at least every [catchUpReminderRecheckInterval] (horizon roll).
  final now = clock().toUtc();
  var delay = catchUpReminderRecheckInterval;
  for (final t in targets) {
    final history = t.history;
    if (history == null) continue;
    for (final card in upcomingCatchUpCards(history, now)) {
      final until = card.lock.endUtc.difference(now);
      if (until < delay) delay = until;
    }
  }
  final timer = Timer(
    delay + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
});
