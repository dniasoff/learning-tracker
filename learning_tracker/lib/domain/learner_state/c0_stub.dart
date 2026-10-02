/// C0 (DNI-524) contract stubs.
///
/// Every contract member that has no sensible fake (an engine rule or a
/// production adapter) calls [c0Stub] until its owner spine story fills it.
/// `test/domain/learner_state/c0_stub_inventory_test.dart` pins the exact
/// set of `(owner, what)` call sites under `lib/`; a story that fills a stub
/// deletes the call and its inventory row in the same commit. DNI-490 (the
/// cutover) deletes this file; `tool/retired_symbols/R15.json` tracks it.
library;

/// Throws [UnimplementedError] naming the stubbed member [what] and the
/// story [owner] that fills it.
Never c0Stub(String owner, String what) =>
    throw UnimplementedError('C0 stub: $what (filled by $owner)');
