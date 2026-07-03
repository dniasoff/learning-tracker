## 4. Roadmap — sequenced by risk retired per unit effort

Waves are ordered so each one makes the next cheaper to verify. Tidy-first waves (0, 4) change no behavior; behavioral waves (1–3) ride on the guardrails wave 0 restores. Every item cites register IDs; the ticket pass should lift them 1:1.

### Wave 0 — Repair the enforcement machinery (do first; small, high leverage)
The fence gets its wire back. Nothing else in this roadmap can be trusted "done" until the checkers that prove it run again.
- Repair custom_lint toolchain (analyzer-9 compat) and make CI run it hard-fail — AUD-guardrails-03.
- Fix the dead check-15 awk; align Rule 2's barrel convention doc↔code — AUD-guardrails-02, AUD-learning-* (barrel reconcile).
- Add `Goals` to `tool/schema_check.dart`; wire `packages/custom_lints/test/` into CI; add the AG-7 codegen freshness gate; commit the 3 stale `.g.dart` — AUD-guardrails-01, AUD-guardrails-17, AUD-core-labels-03.
- Kill the dead error-handler twin; one canonical bootstrap installation path — AUD-core-logging-01.
- Repo hygiene sweep: root `coding-standards.md`, `build/`, `clear`, `_bmad-output/` — AUD-docs-04, AUD-repo-*.

### Wave 1 — Data integrity & privacy (the P0 band; behavioral, test-first)
Every fix lands with its red-first regression test (TQ-8) and, where checkable, its Rule-0 checker.
- profileId scoping: `LearningOrderDao` scoping, FK+CASCADE on the 6 tables, `UNIQUE(profileId, ulid)` on points tables, export/import scoped deletes — AUD-core-database-02, AUD-core-database-01, AUD-core-database-03, AUD-settings-03.
- Privacy: constrain `logEvent` to the `AnalyticsEvent` catalog; strip `entity_key` from dead-letter events; redact email bodies — AUD-core-analytics-01, AUD-core-sync-* (dead-letter), AUD-core-email-01.
- Tutor trust chain: verify `emailVerified`/invite token in `inviteTutor`; check `TutorGrantResult` before reporting success; surface swallowed tutor-write failures — AUD-firebase-01, AUD-tutoring-*, AUD-profiles-02.
- The archive-wipes-data flow and its test — AUD-profiles-01.
- Offline-account lifecycle: outbox-drain guard before `removeCloudFromDevice`; the AU-family supplemental set — AUD-account-01, AUD-account-*.
- Firestore rules: SR-1 append-only deny-tests, SR-2 value validation, SR-4 list caps — AUD-docs-01 (rules-tests), AUD-firebase-*.

### Wave 2 — Sync correctness under failure (behavioral)
- Server timestamps for LWW ordering; `hasPendingWrites`/`isFromCache` echo guards — AUD-core-sync-13, AUD-core-sync-* (FB-3).
- Outbox resilience: per-row decode isolation, single-flight generation token, atomic merge-store upsert+timestamp — AUD-core-sync-* (outbox/merge cluster).
- Fix `deleteUserData`'s wrong Firestore paths; codec safety (`as int?` casts, ISO-string dates) — AUD-core-sync-* (gateway/codec).
- Error-as-values at the boundary: stable codes on `SyncStatus.error`/`RestoreStatus.error`; stop surfacing `e.toString()` (BulkMark, restore, sacred_time, tracks hub) — AUD-sync-*, AUD-app-*, AUD-onboarding-*.

### Wave 3 — i18n & state-management debt (mechanical, high count)
- The 21 AX-2 localization clusters (onboarding, content_browsing, settings, tracks wizard, core widgets, scheduler picker…) — AUD-*-AX-2 set; land the AX-2 string-literal lint with the sweep.
- SM-4 `ref.mounted` guards (14 clusters) and SM-2 build-side-effect providers (7) — AUD-notifications-*, AUD-gamification-*, AUD-account-*, AUD-dashboard-*; land the SM-4 custom lint with it.
- DB-2 transaction wraps (7) and DB-3 batch conversions (4) — AUD-core-database-*, AUD-learning-*, AUD-onboarding-*.

### Wave 4 — Test-suite hardening & structure (tidy-first)
- TQ-8 register: rewrite tautological/stale-copy/dead-code-pinning tests (102 findings, start with the ones guarding Wave-1 fixes) — AUD-t-* set.
- TQ-6: clock injection + the 377-site wall-clock backlog as a ratchet; kill real sleeps/network in tests — AUD-t-*, meta TQ-6.
- AG-3 (327 files) and AG-5 (537 unmirrored) as warn→fail ratchets; AG-4 renames (7 dup names + provider dup) — meta-recommendations, AUD-tutoring-* (dup provider).
- Docs refresh wave: architecture graph + schema/version claims, firestore-collection-layout, AG-8 pairing checker — AUD-docs-15, AUD-docs-*, meta AG-8.

### Defer (file, don't schedule)
PF polish beyond the lazy-list P1s, theme-token `Colors.*` statics (extend the lint first or document statics-allowed), naming-convention drift, `_codec.dart` suffix documentation, remaining P3 hygiene. They're in the register with IDs; they should ride along with area work, not lead it.
