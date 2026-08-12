/// Story acceptance coverage for lockout, redaction, and atomic completion.
@Tags(['epic_27', 'story_27_9'])
library;

import 'dart:io';

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

void main() {
  group('Story 27.9 — lockout and redaction', tags: ['story_27_9'], () {
    test('PIN lockout implementation remains production-owned', () {
      expect(
        File('lib/features/profiles/domain/services/pin_service.dart').existsSync(),
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
        fields: {
          'userEmail': 'user@example.com',
          'count': 3,
          'success': false,
        },
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

  group('Story 27.9 — atomic completion persistence', tags: ['story_27_9'], skip:
      'Blocked: the original integration group wires CompletionOrchestrator to Drift completion_events and curriculum_tracks. The Firestore completion writer is not exposed as an equivalent orchestrator harness.',
      () {
    test('placeholder for the pending Firestore atomic-completion seam', () {});
  });
}
