// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_raw_logevent.dart';

/// Writes [content] to a temp file at a path containing [pathSegment],
/// with [fileName] as the basename — matching the path-scoping the rule
/// checks (`_isWhitelisted` inspects the trailing path segments).
File _tmpFileAt(
  String content,
  String pathSegment, {
  String fileName = 'file.dart',
}) {
  final dir = Directory(
    '${Directory.systemTemp.path}/'
    'no_raw_logevent_${DateTime.now().microsecondsSinceEpoch}/'
    '$pathSegment',
  );
  dir.createSync(recursive: true);
  final file = File('${dir.path}/$fileName');
  file.writeAsStringSync(content);
  return file;
}

const _codeName = 'no_raw_logevent';

void main() {
  const rule = NoRawLogEvent();

  group('NoRawLogEvent', () {
    group('violations — outside analytics_service.dart', () {
      test('flags a raw logEvent(...) call with a string literal name',
          () async {
        final file = _tmpFileAt(
          '''
class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {}
}

Future<void> build(AnalyticsService analyticsService) async {
  await analyticsService.logEvent('custom_event', parameters: {'key': 'value'});
}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'A raw logEvent(...) call with a literal event name '
              'outside analytics_service.dart must be flagged',
        );
      });

      test('flags a raw logEvent(...) call with an identifier event name',
          () async {
        final file = _tmpFileAt(
          '''
class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {}
}

Future<void> build(AnalyticsService analyticsService, String eventName) async {
  await analyticsService.logEvent(eventName);
}
''',
          'lib/features/scheduler/domain',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'A raw logEvent(...) call with an identifier event name '
              'outside analytics_service.dart must be flagged',
        );
      });
    });

    group('allowed — negatives', () {
      test('does NOT flag logEvent(...) with zero arguments', () async {
        final file = _tmpFileAt(
          '''
class Foo {
  void logEvent() {}
}

void build(Foo foo) => foo.logEvent();
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'logEvent() with no arguments does not match the '
              'raw-event-name shape and must not be flagged',
        );
      });

      test(
          'does NOT flag logEvent(...) whose first argument is neither a '
          'string literal nor a simple identifier', () async {
        final file = _tmpFileAt(
          '''
class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {}
}

String eventName() => 'x';

Future<void> build(AnalyticsService analyticsService) async {
  await analyticsService.logEvent(eventName());
}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'A non-literal, non-identifier first argument falls '
              'outside the raw-event-name pattern this rule targets',
        );
      });
    });

    group('whitelist — analytics_service.dart and generated files', () {
      test('does NOT flag logEvent(...) inside analytics_service.dart',
          () async {
        final file = _tmpFileAt(
          '''
class AnalyticsService {
  Future<void> logAppLaunch() => logEvent('app_launch');

  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {}
}
''',
          'lib/core/analytics',
          fileName: 'analytics_service.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'analytics_service.dart owns logEvent and must be exempt',
        );
      });

      test('does NOT flag logEvent(...) inside a .g.dart file', () async {
        final file = _tmpFileAt(
          '''
class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {}
}

Future<void> build(AnalyticsService analyticsService) async {
  await analyticsService.logEvent('generated_event');
}
''',
          'lib/features/dashboard/presentation',
          fileName: 'dashboard_screen.g.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'generated .g.dart files are exempt from this rule',
        );
      });

      test('does NOT flag logEvent(...) inside a .freezed.dart file', () async {
        final file = _tmpFileAt(
          '''
class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {}
}

Future<void> build(AnalyticsService analyticsService) async {
  await analyticsService.logEvent('generated_event');
}
''',
          'lib/features/dashboard/presentation',
          fileName: 'dashboard_state.freezed.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'generated .freezed.dart files are exempt from this rule',
        );
      });
    });
  });
}
