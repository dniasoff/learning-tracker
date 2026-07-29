// AUDIT FIXTURE - DO NOT COMMIT (AUD-guardrails-16 / AG-6 check regression test)
// TODO(DNI-999999): carries a Linear id, must NOT be flagged
// TODO: has no Linear id, MUST be flagged
// XXX(DNI-999999): carries a Linear id, must NOT be flagged
// XXX: has no Linear id, MUST be flagged
const zzzTrailingMarker = 1; // TODO: trailing marker, not line-start, no Linear id, MUST be flagged
/// TODO: doc-comment marker, no Linear id, MUST be flagged
/* TODO: block-comment marker, no Linear id, MUST be flagged */
const zzzAuditFixtureDoNotCommit = true;
