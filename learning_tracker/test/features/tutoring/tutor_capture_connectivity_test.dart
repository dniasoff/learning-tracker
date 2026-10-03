// Story 1.24 (DNI-486) AC-5 — tutor writes are online-only (AD-53,
// deviation #3). With no connectivity, or a failed connectivity probe, every
// tutor write control is disabled with "Online required", nothing is queued
// and nothing optimistic shows; the controls re-enable when the connection
// returns. A call that times out mid-flight shows the existing retryable
// error ("not saved" with Retry), changes nothing on screen, and the retry
// re-sends the SAME ULIDs.

@Tags(['tutor_mode'])
library;

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_write_gate.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/tutoring/tutor_learning_harness.dart';

Future<CaptureResult> _capture(TutorHarness h) => h.commands.capture(
  curriculumId: 'mishnayos',
  refs: const ['Mishnah Berakhot 2:1', 'Mishnah Berakhot 2:2'],
  source: LearningEvent.sourceMain,
  dateState: DateState.dated,
);

Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('availability follows a POSITIVE probe only', () {
    Future<TutorWriteAvailability> availability({
      bool online = true,
      Object? error,
    }) async {
      final container = ProviderContainer(
        overrides: tutoredOverrides(
          selection: tutorSelection(),
          online: online,
          connectivityError: error,
        ),
      );
      addTearDown(container.dispose);
      final sub = container.listen(tutorWriteAvailabilityProvider, (_, _) {});
      addTearDown(sub.close);
      await _flush();
      return sub.read();
    }

    test('no connectivity disables tutor writes', () async {
      expect(await availability(online: false), TutorWriteAvailability.offline);
    });

    test('a probe failure disables tutor writes', () async {
      expect(
        await availability(error: Exception('probe failed')),
        TutorWriteAvailability.offline,
      );
    });

    test('online, permitted and unlocked enables them', () async {
      expect(await availability(), TutorWriteAvailability.available);
    });
  });

  testWidgets('the note reads "Online required" offline and leaves when the '
      'connection returns', (tester) async {
    final feed = ConnectivityFeed()..emit(false);
    addTearDown(feed.close);
    await tester.pumpWidget(
      pumpApp(
        overrides: tutoredOverrides(
          selection: tutorSelection(),
          connectivity: feed,
        ),
        child: const Scaffold(body: TutorWriteNote()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Online required'), findsOneWidget);

    feed.emit(true);
    await tester.pumpAndSettle();
    expect(find.text('Online required'), findsNothing);
  });

  group('offline: refused, nothing queued', () {
    test('an offline capture returns onlineRequired, calls nothing and '
        'parks nothing for later', () async {
      final h = TutorHarness(online: false);
      addTearDown(h.dispose);

      expect(await _capture(h), const CaptureResult.onlineRequired());
      expect(h.invoker.calls, isEmpty);
      expect(await h.commands.watchPendingFailures().first, isEmpty);

      // Reconnecting replays nothing on its own.
      h.connectivity.online = true;
      await _flush();
      expect(h.invoker.calls, isEmpty);
    });
  });

  group('timeout mid-flight', () {
    test('changes nothing (notSaved), becomes ONE retryable failure, and '
        'Retry re-sends the identical payload with the same ULIDs', () async {
      var attempts = 0;
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (call) {
        attempts++;
        if (attempts == 1) {
          throw FirebaseFunctionsException(
            code: 'deadline-exceeded',
            message: 'timeout',
          );
        }
        return h.invoker.successFor(call, replayed: true);
      };

      final first = await _capture(h);
      expect(
        first,
        const CaptureResult.rejected(CaptureRejection.notSaved),
        reason: 'no success, so no screen state changes',
      );
      final failures = await h.commands.watchPendingFailures().first;
      expect(failures, hasLength(1));
      final sentIds = [
        for (final e in h.invoker.calls.single.args['events'] as List)
          (e as Map)['id'],
      ];
      expect(failures.single.eventIds, sentIds);

      final retried = await h.commands.retry(failures.single.id);

      expect(retried, isA<CaptureSuccess>());
      expect((retried as CaptureSuccess).eventIds, sentIds);
      expect(h.invoker.calls, hasLength(2));
      expect(
        jsonEncode(h.invoker.calls[1].args),
        jsonEncode(h.invoker.calls[0].args),
      );
      expect(await h.commands.watchPendingFailures().first, isEmpty);
      // The replayed action emits no second capture event.
      expect(h.analytics.captures, isEmpty);
    });

    test('a Retry while offline is refused and stays pending', () async {
      final h = TutorHarness();
      addTearDown(h.dispose);
      h.invoker.respond = (_) => throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'no network',
      );
      await _capture(h);
      final failure = (await h.commands.watchPendingFailures().first).single;
      h.connectivity.online = false;

      expect(
        await h.commands.retry(failure.id),
        const CaptureResult.onlineRequired(),
      );
      expect(h.invoker.calls, hasLength(1));
      expect(await h.commands.watchPendingFailures().first, [failure]);
    });
  });
}
