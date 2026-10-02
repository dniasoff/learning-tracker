/// Shared widget-test rig for the DNI-513 Change history screen: provider
/// overrides over [FakeChangeHistoryRepository], a fixed clock, New York
/// learner settings and no lock unless asked.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/change_history/data/repositories/change_history_sources.dart';
import 'package:learning_tracker/features/change_history/domain/repositories/change_history_repository.dart';
import 'package:learning_tracker/features/change_history/presentation/providers/change_history_providers.dart';
import 'package:learning_tracker/features/change_history/presentation/screens/change_history_screen.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';

import '../../../helpers/learner_state/lock_fixtures.dart';
import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/pump_app.dart';

/// The learner of the tests.
final historyScope = LearnerScope(
  ownerUid: 'owner-uid',
  profileId: profileUlid,
);

/// "Now" in the tests: 2026-09-02 12:00 UTC (08:00 in New York).
final historyNow = DateTime.utc(2026, 9, 2, 12);

/// The overrides of the screen.
List<Override> changeHistoryOverrides({
  required ChangeHistoryRepository repository,
  LearnerScope? scope,
  bool access = true,
  LearnerSettingsHistory? settings,
  SacredWindow? lock,
  ChangeHistoryUndoHandler? undo,
  Future<LearnerScope?> Function(Ref ref)? scopeOf,
  DateTime? now,
  DateTime Function()? clock,
  bool settingsPending = false,
}) => [
  changeHistoryAccessProvider.overrideWithValue(access),
  activeLearnerScopeProvider.overrideWith(
    scopeOf ?? (ref) async => scope ?? historyScope,
  ),
  changeHistoryRepositoryProvider.overrideWith((ref) async => repository),
  learnerLockSettingsProvider.overrideWith(
    (ref, scope) => settingsPending
        // Never emits: the learner's lock stays unknown.
        ? Completer<LearnerSettingsHistory>().future.asStream()
        : Stream.value(settings ?? constantHistory(newYorkNoLocation)),
  ),
  changeHistorySubTrackNamesProvider.overrideWith(
    (ref, scope) => Stream.value(const <String, String>{}),
  ),
  changeHistoryRefLabelProvider.overrideWith((ref, sefariaRef) async {
    return sefariaRef.replaceFirst('Mishnah ', '');
  }),
  changeHistoryClockProvider.overrideWithValue(
    clock ?? () => now ?? historyNow,
  ),
  currentSacredWindowProvider.overrideWithValue(lock),
  changeHistoryUndoHandlerProvider.overrideWithValue(undo),
];

/// Pumps the screen at [size] (a phone by default).
Future<void> pumpChangeHistory(
  WidgetTester tester,
  List<Override> overrides, {
  Size size = const Size(400, 900),
  Brightness brightness = Brightness.light,
  ProviderContainer? container,
  bool settle = true,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    pumpApp(
      child: const ChangeHistoryScreen(),
      overrides: overrides,
      container: container,
      locale: locale,
      theme: AppTheme.themeFor(brightness: brightness),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}
