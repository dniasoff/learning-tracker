// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_shrink_wrap_reorderable_list.dart';

const _lintName = 'no_shrink_wrap_reorderable_list';

/// Writes [content] to a path that contains [pathSegment].
///
/// Mirrors the `no_eager_list_in_non_lazy_scroll_container_test.dart`
/// helper — this rule is also path-scoped (only `lib/features/**` is
/// linted), so the fixture must live at a path that satisfies that filter.
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
/// (`ReorderableListView`), which requires the identifier to actually
/// resolve to a class. Declaring a tiny local class with the same
/// name/shape gives the analyzer something real to resolve.
const _prelude = '''
class Widget {}

class Text extends Widget {
  Text(String data);
}

typedef ReorderCallback = void Function(int oldIndex, int newIndex);

class ReorderableListView extends Widget {
  ReorderableListView({
    bool shrinkWrap = false,
    List<Widget>? children,
    ReorderCallback? onReorderItem,
  });
  ReorderableListView.builder({
    bool shrinkWrap = false,
    required int itemCount,
    required Widget Function(Object context, int index) itemBuilder,
    ReorderCallback? onReorderItem,
  });
}

class SingleChildScrollView extends Widget {
  SingleChildScrollView({Widget? child});
}
''';

void main() {
  const rule = NoShrinkWrapReorderableList();

  group('NoShrinkWrapReorderableList', () {
    group('violations', () {
      test(
        'flags the plain ReorderableListView(shrinkWrap: true, children: '
        '[...]) shape (the pre-fix TrackLearningOrderScreen masechtos '
        'section, AUD-tracks-05)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> masechtos) {
  return SingleChildScrollView(
    child: ReorderableListView(
      shrinkWrap: true,
      children: [
        for (final m in masechtos) Text(m),
      ],
      onReorderItem: (oldIndex, newIndex) {},
    ),
  );
}
''',
            'lib/features/tracks/track_order/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'The plain ReorderableListView(...) constructor combined '
                'with shrinkWrap: true must be flagged',
          );
        },
      );

      test(
        'flags shrinkWrap: true even when children: is a short/empty '
        'literal (the rule fires on the shape, not the item count)',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build() {
  return ReorderableListView(
    shrinkWrap: true,
    children: <Widget>[],
    onReorderItem: (oldIndex, newIndex) {},
  );
}
''',
            'lib/features/tracks/track_order/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'shrinkWrap: true on the plain constructor is the '
                'defect regardless of the literal item count at the call '
                'site — the source list is what is unbounded at runtime',
          );
        },
      );
    });

    group('allowed', () {
      test(
        'does not flag ReorderableListView.builder with shrinkWrap: true',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> items) {
  return ReorderableListView.builder(
    shrinkWrap: true,
    itemCount: items.length,
    itemBuilder: (context, index) => Text(items[index]),
    onReorderItem: (oldIndex, newIndex) {},
  );
}
''',
            'lib/features/tracks/track_order/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'This rule is scoped to the exact plain-constructor + '
                'shrinkWrap:true shape named by AUD-tracks-05 — '
                '`.builder` combined with shrinkWrap is a distinct named '
                'constructor call, out of this precise pattern',
          );
        },
      );

      test(
        'does not flag the plain ReorderableListView(...) constructor '
        'when shrinkWrap is false',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> items) {
  return ReorderableListView(
    shrinkWrap: false,
    children: [for (final i in items) Text(i)],
    onReorderItem: (oldIndex, newIndex) {},
  );
}
''',
            'lib/features/tracks/track_order/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'shrinkWrap: false does not force eager realization — '
                'only shrinkWrap: true is the defect',
          );
        },
      );

      test(
        'does not flag the plain ReorderableListView(...) constructor '
        'when shrinkWrap is omitted entirely',
        () async {
          final file = _tmpFileAt(
            '''
$_prelude
Widget build(List<String> items) {
  return ReorderableListView(
    children: [for (final i in items) Text(i)],
    onReorderItem: (oldIndex, newIndex) {},
  );
}
''',
            'lib/features/tracks/track_order/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'No shrinkWrap argument at all means the default '
                '(false) applies — not the flagged shape',
          );
        },
      );

      test('does not flag ReorderableListView(...) outside lib/features/**',
          () async {
        final file = _tmpFileAt(
          '''
$_prelude
Widget build(List<String> items) {
  return ReorderableListView(
    shrinkWrap: true,
    children: [for (final i in items) Text(i)],
    onReorderItem: (oldIndex, newIndex) {},
  );
}
''',
          'lib/core/widgets',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'This rule is path-scoped to lib/features/** only, '
              'matching the AC wording',
        );
      });
    });
  });
}
