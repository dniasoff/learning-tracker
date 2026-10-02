/// Matchers for the C0 (DNI-524) contract stubs.
library;

import 'package:flutter_test/flutter_test.dart';

/// Matches an [UnimplementedError] thrown by `c0Stub(owner, what)`.
Matcher isC0Stub(String owner, String what) => isA<UnimplementedError>().having(
  (e) => e.message,
  'message',
  'C0 stub: $what (filled by $owner)',
);

/// Matches a call that throws `c0Stub(owner, what)`.
Matcher throwsC0Stub(String owner, String what) =>
    throwsA(isC0Stub(owner, what));
