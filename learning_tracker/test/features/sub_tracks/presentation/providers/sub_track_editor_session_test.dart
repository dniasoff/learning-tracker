// Story 4.2 (DNI-510) T1 — one gate for every sub-track editor surface:
// a parent session or any tutored session may open them; a tutor's write
// controls are disabled exactly when `tutorWriteAvailabilityProvider`
// blocks him (no can_edit_learning, offline, talmid locked), derived from
// can_edit_learning alone.

@Tags(['tutor_mode'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_editor_session.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

Future<T> _settled<T>(
  List<Override> overrides,
  ProviderListenable<T> provider,
) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return sub.read();
}

final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 8),
  DateTime.utc(2026, 10, 2, 20),
);

void main() {
  group('subTrackEditorSessionProvider', () {
    test('a tutored session opens the editor surfaces, with or without '
        'editing access', () async {
      for (final canEdit in [true, false]) {
        final open = await _settled(
          tutoredOverrides(selection: tutorSelection(canEditLearning: canEdit)),
          subTrackEditorSessionProvider.future,
        );
        expect(await open, isTrue, reason: 'canEditLearning: $canEdit');
      }
    });

    test('an owner session follows the parent session', () async {
      for (final parent in [true, false]) {
        final open = await _settled([
          ...tutoredOverrides(),
          parentSessionProvider.overrideWith((ref) async => parent),
        ], subTrackEditorSessionProvider.future);
        expect(await open, parent);
      }
    });

    test('a failing parent session read fails closed', () async {
      final open = await _settled([
        ...tutoredOverrides(),
        parentSessionProvider.overrideWith(
          (ref) async => throw StateError('profile'),
        ),
      ], subTrackEditorSessionProvider.future);
      expect(await open, isFalse);
    });
  });

  group('subTrackWritesBlockedProvider', () {
    test('never blocks an owner session', () async {
      expect(
        await _settled(tutoredOverrides(), subTrackWritesBlockedProvider),
        isFalse,
      );
      expect(
        await _settled(tutoredOverrides(), subTrackWritesAllowedProvider),
        isTrue,
      );
    });

    test('a permitted, online tutor outside a lock may write', () async {
      final overrides = tutoredOverrides(selection: tutorSelection());
      expect(await _settled(overrides, subTrackWritesBlockedProvider), isFalse);
      expect(await _settled(overrides, subTrackWritesAllowedProvider), isTrue);
    });

    for (final (label, overrides) in <(String, List<Override>)>[
      (
        'can_edit_learning false',
        tutoredOverrides(selection: tutorSelection(canEditLearning: false)),
      ),
      ('offline', tutoredOverrides(selection: tutorSelection(), online: false)),
      (
        'connectivity unknown (error)',
        tutoredOverrides(
          selection: tutorSelection(),
          connectivityError: Exception('probe'),
        ),
      ),
      (
        'the talmid locked',
        tutoredOverrides(
          selection: tutorSelection(),
          gate: FakeCaptureGate.locked(_lock),
        ),
      ),
    ]) {
      test('blocks a tutor when $label', () async {
        expect(
          await _settled(overrides, subTrackWritesBlockedProvider),
          isTrue,
        );
        expect(
          await _settled(overrides, subTrackWritesAllowedProvider),
          isFalse,
        );
      });
    }

    test('connectivity loss and recovery flip the gate live', () async {
      final feed = ConnectivityFeed()..emit(true);
      addTearDown(feed.close);
      final container = ProviderContainer(
        overrides: tutoredOverrides(
          selection: tutorSelection(),
          connectivity: feed,
        ),
      );
      addTearDown(container.dispose);
      final seen = <bool>[];
      final sub = container.listen(
        subTrackWritesBlockedProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      Future<void> settle() async {
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      await settle();
      expect(sub.read(), isFalse);
      feed.emit(false);
      await settle();
      expect(sub.read(), isTrue);
      feed.emit(true);
      await settle();
      expect(sub.read(), isFalse);
    });
  });
}
