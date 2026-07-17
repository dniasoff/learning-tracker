/// SM-5 busy/loading-stuck checker — AUD-profiles-11 (AC3).
///
/// SM-5 ("never hand-manage loading/error with a try/catch that assigns
/// `state`") already has an INFO-severity migration nudge
/// (`no_hand_rolled_async_state_notifier`) for notifiers that should move to
/// `AsyncNotifier`/`AsyncValue.guard` wholesale. This checker targets a
/// narrower, hard-gate-able symptom of the same root cause: a method that
/// sets `busy: true`/`loading: true` on its state right before an `await`
/// has to unconditionally clear it again on EVERY exit path, including an
/// untyped/unexpected exception — otherwise the flag sticks true forever and
/// freezes whatever UI gates on it (the defect AUD-profiles-11 found: only
/// specific typed exceptions were caught, so a stray PinService failure left
/// `busy` stuck true and permanently froze the parent-PIN keypad).
///
/// Heuristic (AUD-profiles-11 AC3's own wording): for every
/// `state = state.copyWith(busy: true` / `state.copyWith(loading: true`
/// (or `_state.copyWith(...)`, this codebase's non-Riverpod domain-layer
/// state-machine convention — see below) assignment found inside a member
/// (method/getter) of a scoped class, the ENCLOSING MEMBER must contain
/// either:
///
///   * a `finally` block (the recommended unconditional backstop — see
///     `pin_entry_machine.dart`'s `_handleVerifyCurrentForChange`/
///     `_handleConfirmAndSave`/`_handleVerify` for the reference fix), or
///   * `AsyncValue.guard` (the SM-5-canonical safe pattern: `guard` funnels
///     every exception, typed or not, into a resolved `AsyncError`, so a
///     hand-rolled `busy`/`loading` flag driven by its result can never be
///     left stuck — see `RewardConfigController` for a clean example that
///     legitimately has no `finally` and is correctly NOT flagged here).
///
/// A member with neither is a `make audit` violation: some exception path
/// through it can leave `busy`/`loading` stuck true.
///
/// Scoped classes: a `@riverpod` Notifier (`class X extends _$X` — this
/// codebase's codegen pattern) OR [PinEntryMachine] — the pure-Dart PIN-entry
/// state machine (AUD-profiles-06) that owns the digit-buffer/busy/lockout
/// transitions shared by PinFlowController and the 3 modal PIN dialogs.
/// AUD-profiles-11 originally scoped this checker to PinFlowController
/// itself, but AUD-profiles-06 (landed independently) later consolidated
/// that controller's hand-rolled transition logic into PinEntryMachine, so
/// the busy-stuck risk (and this checker's target) moved with it — checking
/// PinFlowController today would find nothing, since it now just forwards
/// every gesture into the machine and mirrors its state.
///
/// This is a heuristic, not a full control-flow prover (matching the
/// established style of the other `tool/check_*.dart` scripts in this
/// repo — see `check_empty_catch_blocks.dart`, `check_sm7_analytics_
/// repository_construction.dart`): it looks for CONTAINMENT within the
/// enclosing member's text span, not for the `finally`/`guard` actually
/// covering every `busy: true` call site inside a member with multiple
/// independent try-blocks (e.g. a switch with several cases, each guarding
/// its own async call, as `PinEntryMachine._handleChange` does). That is
/// intentional and sufficient for this finding's shape and remains a strict
/// improvement over no check at all; tightening it to per-try-block
/// precision is future work if a member ever legitimately mixes a guarded
/// and an unguarded busy-true site.
///
/// Structure detection: string/comment-masked source (so a `{`/`}` inside a
/// string or comment never corrupts brace counting — `_maskStringsAndComments`
/// is copied from the same helper in
/// `check_sm7_analytics_repository_construction.dart`), then:
///   1. find every top-level `class X ... { ... }` header (either an
///      `extends _$X` Riverpod-codegen class, or `class PinEntryMachine`)
///      and its brace-matched body span;
///   2. within each such class body, walk at the class's own nesting depth
///      to enumerate each direct member's `{ ... }` span (its method/getter
///      body — nested braces inside a member, e.g. a `switch`/`try`, are
///      skipped over as part of that one member's span, not treated as
///      siblings);
///   3. for each `busy: true`/`loading: true` match, look up which member
///      span contains it and scan that span for `finally`/`AsyncValue.guard`.
///
/// Usage:
///   dart run tool/check_sm5_busy_stuck.dart
///
/// Exit codes:
///   0 — every busy:true/loading:true assignment in a scoped member has a
///       paired `finally` or `AsyncValue.guard` in its enclosing member
///   1 — one or more found without either (prints file:line)
library;

import 'dart:io';

final _busyOrLoadingTrue = RegExp(
  r'\.copyWith\(\s*(?:busy|loading)\s*:\s*true\b',
);

/// Matches a top-level `class Name ... {` header up to (and including) its
/// own opening brace. `[^{]*` deliberately spans newlines (it excludes only
/// `{`, unlike `.`) so a header wrapped across multiple lines still matches.
final _classHeader = RegExp(r'\bclass\s+(\w+)[^{]*\{');

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln(
      'ERROR: lib/ not found — run from the learning_tracker/ package root.',
    );
    exit(1);
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;

    final raw = entity.readAsStringSync();
    // Fast pre-filter: skip files that can't possibly match.
    if (!raw.contains('busy: true') && !raw.contains('loading: true')) {
      continue;
    }

    final masked = _maskStringsAndComments(raw);
    violations.addAll(_checkFile(path, raw, masked));
  }

  if (violations.isNotEmpty) {
    stderr.writeln('SM-5 busy/loading-stuck check FAILED (AUD-profiles-11):');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'SM-5 busy/loading-stuck check passed (AUD-profiles-11) — every '
    'busy:true/loading:true assignment in a scoped Notifier/PinEntryMachine '
    'member has a paired finally or AsyncValue.guard in its enclosing '
    'member.',
  );
}

List<String> _checkFile(String path, String raw, String masked) {
  final violations = <String>[];

  // 1. Collect every scoped class's body span: a Riverpod-notifier class
  //    (`extends _$` is this codebase's @riverpod codegen marker) or the
  //    PinEntryMachine domain state machine (AUD-profiles-06/AUD-profiles-11
  //    — see file-level doc comment above for why the scope includes it).
  final memberSpans = <(int start, int end)>[];
  for (final classMatch in _classHeader.allMatches(masked)) {
    final header = classMatch.group(0)!;
    final className = classMatch.group(1)!;
    if (!header.contains(r'extends _$') && className != 'PinEntryMachine') {
      continue;
    }

    final classBodyStart = classMatch.end - 1; // index of the `{`
    final classBodyEnd = _matchingClose(masked, classBodyStart);
    if (classBodyEnd == null) continue; // malformed — leave to the analyzer

    // 2. Walk the class body at ITS OWN nesting depth to find each direct
    //    member's `{ ... }` span, skipping over the member's own internals.
    var i = classBodyStart + 1;
    while (i < classBodyEnd) {
      if (masked[i] == '{') {
        final memberEnd = _matchingClose(masked, i);
        if (memberEnd == null) break; // malformed — leave to the analyzer
        memberSpans.add((i, memberEnd));
        i = memberEnd + 1;
      } else {
        i++;
      }
    }
  }

  // 3. For each busy/loading:true hit, find its enclosing member span (if
  //    any — a class-level field initializer wouldn't have one) and check
  //    it for a finally/AsyncValue.guard backstop.
  for (final match in _busyOrLoadingTrue.allMatches(masked)) {
    final span = memberSpans
        .where((s) => s.$1 <= match.start && match.start < s.$2)
        .fold<(int, int)?>(
          null,
          // Innermost (smallest) enclosing span, in case of nesting.
          (best, s) =>
              best == null || (s.$2 - s.$1) < (best.$2 - best.$1) ? s : best,
        );
    if (span == null) continue; // not inside any scoped member — skip

    final memberBody = masked.substring(span.$1, span.$2 + 1);
    final hasFinally = RegExp(r'\bfinally\b').hasMatch(memberBody);
    final hasAsyncGuard = memberBody.contains('AsyncValue.guard');
    if (hasFinally || hasAsyncGuard) continue;

    final line = _lineNumber(raw, match.start);
    violations.add(
      '$path:$line: state.copyWith(busy|loading: true) with no `finally` '
      'or `AsyncValue.guard` in the enclosing method — an untyped '
      'exception can leave the flag stuck true forever and freeze the UI '
      'gated on it (SM-5, AUD-profiles-11). Add a `finally { if '
      '(state.busy) state = state.copyWith(busy: false); }` backstop '
      '(guarded on ref.mounted/isActive() per SM-4), or migrate to '
      'AsyncValue.guard.',
    );
  }

  return violations;
}

/// Returns the byte offset of the `}` matching the `{` at [openIndex] in
/// [masked] (already string/comment-masked, so plain counting is safe).
int? _matchingClose(String masked, int openIndex) {
  var depth = 0;
  for (var i = openIndex; i < masked.length; i++) {
    if (masked[i] == '{') depth++;
    if (masked[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

int _lineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}

/// Replaces `//`/`/* */` comment bodies AND string-literal interiors with
/// spaces (preserving length and line breaks) so brace-depth scanning never
/// trips on a `{`/`}` that only appears inside a comment or a string.
/// Copied from the identical helper in
/// `check_sm7_analytics_repository_construction.dart` (kept local so each
/// checker script stays a single, independently-runnable file, matching
/// this repo's established convention).
String _maskStringsAndComments(String source) {
  final buffer = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';

    if (c == "'" || c == '"') {
      final quote = c;
      final triple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final closer = triple ? quote * 3 : quote;
      buffer.write(closer);
      i += closer.length;
      while (i < n && !source.startsWith(closer, i)) {
        if (source[i] == r'\' && i + 1 < n) {
          buffer.write(source[i] == '\n' ? '\n' : ' ');
          buffer.write(source[i + 1] == '\n' ? '\n' : ' ');
          i += 2;
          continue;
        }
        buffer.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < n) {
        buffer.write(closer);
        i += closer.length;
      }
      continue;
    }

    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        buffer.write(' ');
        i++;
      }
      continue;
    }

    if (c == '/' && next == '*') {
      i += 2;
      while (i < n &&
          !(source[i] == '*' && i + 1 < n && source[i + 1] == '/')) {
        buffer.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      i += 2;
      buffer.write('  ');
      continue;
    }

    buffer.write(c);
    i++;
  }
  return buffer.toString();
}
