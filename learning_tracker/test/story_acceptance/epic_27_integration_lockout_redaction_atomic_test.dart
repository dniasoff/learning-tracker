/// Story acceptance coverage for lockout, redaction, and atomic completion.
@Tags(['epic_27', 'story_27_9'])
library;

import 'dart:io';

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/learner_state/c0_fixtures.dart';
import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state/fake_learning_commands.dart';
import '../helpers/learner_state/in_memory_ports.dart';

void main() {
  group('Story 27.9 — lockout and redaction', tags: ['story_27_9'], () {
    test('PIN lockout implementation remains production-owned', () {
      expect(
        File(
          'lib/features/profiles/domain/services/pin_service.dart',
        ).existsSync(),
        isTrue,
      );
    });

    late Talker talker;
    late AppLogger logger;

    setUp(() {
      talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
      logger = AppLogger(talker);
    });

    test('preserves event names while redacting sensitive fields', () {
      logger.info(
        event: 'auth_login_attempt',
        fields: {'userEmail': 'user@example.com', 'count': 3, 'success': false},
      );
      final message = talker.history.last.generateTextMessage();
      expect(message, contains('auth_login_attempt'));
      expect(message, contains('[REDACTED]'));
      expect(message, isNot(contains('user@example.com')));
      expect(message, contains('count'));
      expect(message, contains('3'));
      expect(message, contains('success'));
    });

    test('redacts every registered sensitive key', () {
      final fields = {
        for (final key in PiiRedactor.sensitiveKeys) key: 'SENSITIVE_$key',
      };
      logger.info(event: 'sensitive_field_sweep', fields: fields);
      final message = talker.history.last.generateTextMessage();
      expect(message, contains('sensitive_field_sweep'));
      for (final key in fields.keys) {
        expect(message, isNot(contains('SENSITIVE_$key')), reason: key);
      }
    });

    test('legacy plain messages redact bare email addresses', () {
      logger.infoMsg('Logged in as user@example.com');
      final message = talker.history.last.generateTextMessage();
      expect(message, contains('[REDACTED]'));
      expect(message, isNot(contains('user@example.com')));
    });
  });

  // Story 1.11 (DNI-473, R15 port): the atomic unit of a completion is now
  // one learning-write chunk — the learn event and its pts_ entry commit
  // together, and a rejected chunk writes neither.
  group('Story 27.9 — atomic completion persistence', tags: ['story_27_9'], () {
    late InMemoryLearningWritePort port;
    late DefaultLearningCommands commands;

    setUp(() {
      port = InMemoryLearningWritePort();
      var seq = 71000;
      commands = DefaultLearningCommands(
        scope: c0Scope(),
        actor: const Actor(
          uid: 'owner-uid',
          role: ActorRole.parent,
          displayName: '',
        ),
        reads: FakeLearningCommandReads(history: c0SettingsHistory()),
        writePort: port,
        gate: const LockWindowCaptureGate(),
        analytics: RecordingLearningAnalytics(),
        failureReporter: RecordingLearningFailureReporter(),
        clock: () => engineAt(600),
        newUlid: (_) => engineUlid(seq++),
        ackWait: const Duration(milliseconds: 40),
        pointsWait: const Duration(milliseconds: 40),
      );
      addTearDown(commands.dispose);
    });

    Future<void> captureOne() => commands.capture(
      curriculumId: engineCurriculum,
      refs: const ['Mishnah Berakhot 1:1'],
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
    );

    test('the learn event and its pts_ entry are one chunk', () async {
      await captureOne();
      final chunk = port.chunks.single;
      expect(chunk.events.single.ref, 'Mishnah Berakhot 1:1');
      expect(chunk.awards.single.eventId, chunk.events.single.id);
    });

    test('a rejected chunk writes neither the event nor its entry', () async {
      port.failNextWith(const PermanentWriteRejection('permission-denied'));
      await captureOne();
      expect(port.chunks, isEmpty);
      expect(port.attempts.single.awards, hasLength(1));
    });
  });
}
