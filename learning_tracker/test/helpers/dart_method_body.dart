// Shared depth-matched Dart method-body extraction for tests that assert
// on a method's implementation text (e.g. "this method must/must not
// reference X").
//
// Before this helper, `test/features/tutoring/ws3_3e_dual_role_fix_test.dart`
// grabbed a method's body with a naive
// `source.indexOf('\n  }', methodStart) + 4` search — the first line that is
// exactly two spaces + `}` after the method start — duplicated inline twice
// in that file. That heuristic only worked because the target method
// (`_isTutorSession`) happened to be a single-line body; a nested block
// whose own closing brace lands at that same 2-space indent (which can
// happen with non-`dart format`-clean source, or an embedded doc-comment /
// raw-string literal containing a stray two-space `}`) truncates the
// extracted body early, silently hiding whatever comes after it from an
// `isNot(contains(...))` assertion (AUD-t-tutoring-11).
//
// This mirrors the brace-depth-counting shape of `_extractRuleBlock` in
// `test/features/tutoring/w3_41_tutor_security_rules_test.dart` (that
// helper matches Firestore-rules `match` blocks; this one matches Dart
// method bodies) rather than duplicating it, since the two operate on
// different delimiters (`match /pattern {` vs. a method signature).

/// Extracts a Dart method/function body from [source] by locating
/// [signature] (e.g. `'bool _isTutorSession('`) and then counting brace
/// depth from the first `{` after it to its matching `}` — unlike a naive
/// "next `\n  }`" string search, this is not fooled by a nested block whose
/// own closing brace happens to land at the same indent as the method's.
///
/// Returns the full method text, from the start of [signature] through
/// (and including) its matching closing brace.
///
/// Throws a [StateError] if [signature] is not found in [source], if no
/// `{` follows it, or if the braces are unbalanced.
String extractMethodBody(String source, String signature) {
  final start = source.indexOf(signature);
  if (start == -1) {
    throw StateError('method signature not found: $signature');
  }

  var i = source.indexOf('{', start);
  if (i == -1) {
    throw StateError('no method body ({) found after signature: $signature');
  }

  var depth = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
    i++;
  }

  throw StateError(
    'unbalanced braces extracting method body for signature: $signature',
  );
}
