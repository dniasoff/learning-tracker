// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_eager_list_in_non_lazy_scroll_container.dart';

const _lintName = 'no_eager_list_in_non_lazy_scroll_container';

/// Writes [content] to a path that contains [pathSegment].
///
/// Mirrors the `no_feature_cross_import_test.dart` helper — this rule is
/// also path-scoped (only `lib/features/**` is linted), so the fixture must
/// live at a path that satisfies that filter.
File _tmpFileAt(String content, String pathSegment) {
  final dir = Directory('${Directory.systemTemp.path}/$pathSegment');
  dir.createSync(recursive: true);
  final file = File(
    '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

/// Minimal local stand-ins for the Flutter widgets this rule inspects.
///
/// `packages/custom_lints` is a plain Dart package (no Flutter dependency —
/// see its pubspec.yaml), so `package:flutter/material.dart` cannot resolve
/// in these fixtures. The rule keys off the *resolved* constructor name
/// (`ListView` / `Column` / `SingleChildScrollView`), which requires the
/// identifier to actually resolve to a class — an unresolved call stays a
/// bare `MethodInvocation` and would never reach the rule's
/// `addInstanceCreationExpression` callback. Declaring tiny local classes
/// with the same names/shape gives the analyzer something real to resolve.
const _prelude = '''
class Widget {}

class Text extends Widget {
  Text(String data);
}

class ListView extends Widget {
  ListView({List<Widget>? children});
  ListView.builder({
    required int itemCount,
    required Widget Function(Object context, int index) itemBuilder,
  });
}

class Column extends Widget {
  Column({List<Widget>? children});
}

class SingleChildScrollView extends Widget {
  SingleChildScrollView({Widget? child});
}
''';

void main() {
  const rule = NoEagerListInNonLazyScrollContainer();

  group('NoEagerListInNonLazyScrollContainer', () {
    group('violations — eager for/.map() expansion into ListView(children:)',
        () {
      test(
        'flags a for-loop element feeding a plain ListView(children:) '
        '(the ManageGrantsScreen pre-fix AUD-tutoring-08 shape)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> activeGrants) {
  return ListView(
    children: [
      Text('Active'),
      for (final grant in activeGrants) Text(grant),
    ],
  );
}
''',
            'lib/features/tutoring/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A for-loop feeding a non-lazy ListView(children:) over '
                'an unbounded (non-enum, non-take-capped) collection must '
                'be flagged',
          );
        },
      );

      test(
        'flags a `.map(...).toList()` spread element feeding '
        'ListView(children:)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> pendingGrants) {
  return ListView(
    children: [
      ...pendingGrants.map((grant) => Text(grant)),
    ],
  );
}
''',
            'lib/features/settings/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A `.map()` spread element feeding a non-lazy '
                'ListView(children:) must be flagged',
          );
        },
      );

      test(
        'flags `children: xs.map(...).toList()` with no list-literal '
        'wrapper',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> grants) {
  return ListView(
    children: grants.map((grant) => Text(grant)).toList(),
  );
}
''',
            'lib/features/tutoring/presentation/widgets',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'children: bound directly to a `.map().toList()` chain '
                'must be flagged',
          );
        },
      );

      test(
        'flags a for-loop feeding a Column wrapped in '
        'SingleChildScrollView (the "scrollable Column" shape)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> grants) {
  return SingleChildScrollView(
    child: Column(
      children: [
        for (final grant in grants) Text(grant),
      ],
    ),
  );
}
''',
            'lib/features/tutoring/presentation/widgets',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A for-loop feeding a Column that is itself the '
                'scrolling child of a SingleChildScrollView must be '
                'flagged',
          );
        },
      );

      test(
        'flags a C-style counter loop bounded by an unbounded '
        'collection\'s `.length` (the program_selection_step.dart shape)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> programs) {
  return ListView(
    children: [
      for (var i = 0; i < programs.length; i++) Text(programs[i]),
    ],
  );
}
''',
            'lib/features/tracks/setup/presentation/widgets',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A C-style counter loop bounded by a non-provably-'
                'bounded collection\'s `.length` must be flagged',
          );
        },
      );
    });

    group('allowed — already-lazy ListView.builder', () {
      test('does not flag ListView.builder', () async {
        final file = _tmpFileAt(
          '''
$_prelude
Widget build(List<String> grants) {
  return ListView.builder(
    itemCount: grants.length,
    itemBuilder: (context, index) => Text(grants[index]),
  );
}
''',
          'lib/features/tutoring/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'ListView.builder is already lazy and must never be '
              'flagged',
        );
      });
    });

    group('allowed — provably bounded sources', () {
      test('does not flag a for-loop over `SomeEnum.values`', () async {
        final file = _tmpFileAt(
          '''
$_prelude
enum SomeEnum { a, b, c }
Widget build() {
  return ListView(
    children: [
      for (final e in SomeEnum.values) Text(e.toString()),
    ],
  );
}
''',
          'lib/features/tutoring/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A compile-time-bounded enum `.values` iteration must '
              'not be flagged',
        );
      });

      test(
        'does not flag a C-style counter loop bounded by '
        '`SomeEnum.values.length` (the lifetime_marking_screen.dart shape)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
enum SomeEnum { a, b, c }
Widget build() {
  return ListView(
    children: [
      for (var i = 0; i < SomeEnum.values.length; i++) Text(i.toString()),
    ],
  );
}
''',
            'lib/features/settings/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'A C-style counter loop capped at a compile-time-bounded '
                'enum\'s `.values.length` must not be flagged',
          );
        },
      );

      test('does not flag a `.map()` chain over an explicitly `.take(n)`-'
          'capped iterable', () async {
        final file = _tmpFileAt(
          '''
$_prelude
Widget build(List<String> grants) {
  return ListView(
    children: grants.take(5).map((grant) => Text(grant)).toList(),
  );
}
''',
          'lib/features/tutoring/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'An explicitly `.take(n)`-capped preview must not be '
              'flagged',
        );
      });
    });

    group('allowed — a non-scrolling Column is not the flagged shape', () {
      test(
        'does not flag a for-loop feeding a plain Column that is NOT '
        'wrapped in SingleChildScrollView (the fixed Settings '
        '_PendingInvitesSection shape — embedded, non-scrolling, inside '
        'an outer ListView)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> grants) {
  return Column(
    children: [
      for (final grant in grants) Text(grant),
    ],
  );
}
''',
            'lib/features/settings/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'A Column that does not itself scroll (not wrapped in '
                'SingleChildScrollView) is not the anti-pattern this rule '
                'targets',
          );
        },
      );
    });

    group('allowed — files outside lib/features/ are not linted', () {
      test('does not flag a violation-shaped ListView in lib/core/', () async {
        final file = _tmpFileAt(
          '''
$_prelude
Widget build(List<String> grants) {
  return ListView(
    children: [
      for (final grant in grants) Text(grant),
    ],
  );
}
''',
          'lib/core/widgets',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'Files outside lib/features/ are not subject to this rule',
        );
      });
    });
  });
}
