// Shared lookup helpers for locating and reading `lib/` source files from
// story-acceptance tests.
//
// `flutter test` runs from different working directories depending on how
// it's invoked — sometimes `learning_tracker/` (the app root, where
// `lib/foo.dart` resolves directly), sometimes the repo root (where the
// same file is `learning_tracker/lib/foo.dart`). Every acceptance test that
// inspects a `lib/` source file's existence or contents at runtime has to
// resolve that ambiguity.
//
// Before this helper, 5 story-acceptance files (epic_26_story_26_16, _20,
// _31, _6, _7) reimplemented the same ~10-line "try both roots" lookup 13
// separate times, with inconsistent failure behavior between copies — some
// threw a [StateError] immediately when the file was missing, others
// silently fell back to an empty string and let a later `contains()`
// assertion fail with a confusing message (AUD-t-story-acceptance-08). This
// module is the single place that logic lives now; every call site gets the
// same failure behavior.

import 'dart:io';

/// Returns the project root: the directory (the current working directory
/// or its parent) that contains a `lib/` subdirectory.
///
/// Handles `flutter test` invoked from the repo root, where `lib/` is one
/// level down inside `learning_tracker/`, and from `learning_tracker/`
/// itself, where `lib/` is directly under the cwd.
///
/// Throws a [StateError] if neither the current directory nor its parent
/// contains a `lib/` subdirectory.
Directory projectRoot() {
  for (final c in [Directory.current, Directory.current.parent]) {
    if (Directory('${c.path}/lib').existsSync()) return c;
  }
  throw StateError(
    'cannot locate project root (looked for lib/ under '
    '${Directory.current.path} and ${Directory.current.parent.path})',
  );
}

/// Resolves [relativePath] (rooted at `lib/`, e.g.
/// `'core/widgets/stat_card.dart'`), trying both the app-root cwd
/// (`lib/$relativePath`) and the repo-root cwd
/// (`learning_tracker/lib/$relativePath`).
///
/// Returns the first candidate that exists, or the first candidate
/// (unresolved) if neither does — callers check [File.existsSync] via
/// [libFileExists] or read via [readLibSource], which surfaces the failure.
File _resolveLibFile(String relativePath) {
  final candidates = [
    File('lib/$relativePath'),
    File('learning_tracker/lib/$relativePath'),
  ];
  return candidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () => candidates.first,
  );
}

/// True if [relativePath] (rooted at `lib/`) exists under either candidate
/// root.
bool libFileExists(String relativePath) =>
    _resolveLibFile(relativePath).existsSync();

/// Reads [relativePath] (rooted at `lib/`) as a string, trying both
/// candidate roots.
///
/// Throws a [StateError] naming both searched paths if the file exists
/// under neither root. This is the single consistent failure behavior for
/// every call site — replacing the mix of immediate-throw / fall-back-to-
/// empty-string behaviors this helper consolidates (AUD-t-story-acceptance-08).
String readLibSource(String relativePath) {
  final file = _resolveLibFile(relativePath);
  if (!file.existsSync()) {
    throw StateError(
      'Source file not found: lib/$relativePath '
      '(looked for lib/$relativePath and learning_tracker/lib/$relativePath)',
    );
  }
  return file.readAsStringSync();
}
