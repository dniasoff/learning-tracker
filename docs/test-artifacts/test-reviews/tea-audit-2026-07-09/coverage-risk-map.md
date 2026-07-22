# Coverage-vs-Risk Map — TEA Audit 2026-07-09

Source: `learning_tracker/coverage/lcov.info` (generated 2026-07-03 on branch `audit-fix/2026-07-03`), cross-referenced against the risk model for this app (children's data privacy, offline-first sync integrity, parent-PIN auth).

## Headline

| Metric | Value |
|---|---|
| Overall line coverage | **81.97%** (LH 47,564 / LF 58,027) |
| CI coverage gate | single global 60% line floor (`.github/workflows/ci.yml:296-315`) — headroom ~62pp |
| `lib/` Dart files on disk | 820 |
| Files instrumented by lcov | 697 |
| Files executed by **no test at all** (absent from lcov) | **123 (15%)** — 95 hand-written + 28 generated |
| Generated drift share of denominator | 12,066 LF (`.g.dart`) = 20.8% of instrumented lines at 75.4% |

The headline number is structurally misleading as a risk signal:

1. **The denominator hides 123 files.** Files no test executes never appear in lcov, so they neither lower the percentage nor trip the floor. That set includes the entire `lib/app/bootstrap/` startup wiring (8 files) and `lib/app/sync_runtime/`.
2. **A flat floor cannot protect small critical modules.** `core/auth` (131 LF) and `core/sync/providers` (165 LF) could both drop to zero covered and global coverage would fall only to 81.77% — a 0.2pp dip, ~62pp clear of the gate (TEA-013).
3. **The risk pattern is bimodal.** The sync merge algorithms (`core/sync/merge`, 94.8%) and hand-written DAOs (88-100%) are genuinely well tested; the composition root that wires them (`core/sync/providers`, 15.8%; `merge_router_provider.dart`, 0/26) is where a mis-binding would silently corrupt child data (TEA-014).
4. **Line % measures execution, not fault tolerance.** The codec dir shows 88.3% while its malformed-input decode branch — confirmed by AUD-core-sync-05 to crash — is unexercised (TEA-015). On-device runs 6/7 found 21+14 real defects behind green coverage.

## Module table (coverage vs risk)

Sorted by risk-gap rank (1 = worst mismatch between risk and coverage).

| Rank | Module | Files | LF | LH | % | Risk | Note |
|---:|---|---:|---:|---:|---:|---|---|
| 1 | lib/app/sync_runtime | 1 | 0 | 0 | 0 | HIGH | sync_lifecycle_observer LIVE, absent from lcov; no test/app/sync_runtime |
| 2 | lib/core/ids | 1 | 20 | 2 | 10.0 | HIGH | sync natural-key dedup identity; no test/core/ids |
| 3 | lib/core/auth | 6 | 131 | 90 | 68.7 | HIGH | lowest real-logic module; google_sign_in_gateway_impl 0% |
| 4 | lib/core/sync | 61 | 2632 | 2204 | 83.7 | HIGH | merge/ 94.8% but providers/ 15.8% |
| 5 | lib/app/bootstrap | 8 | 0 | 0 | 0 | HIGH | ENTIRE dir absent from lcov; startup wiring; no test/app/bootstrap |
| 6 | lib/features/account | 32 | 2362 | 1780 | 75.4 | HIGH | auth + offline/cloud conversion |
| 7 | lib/features/sync | 5 | 426 | 343 | 80.5 | HIGH | understated: device_restore_service/merge_rules/restore_providers absent from lcov |
| 8 | lib/core/database | 94 | 14624 | 11223 | 76.7 | HIGH | hand-written 83% / generated 75.4%; DAOs 88-100% |
| 9 | lib/features/settings | 18 | 2811 | 2162 | 76.9 | MEDIUM | upgrade_to_cloud_screen 28.2% |
| 10 | lib/features/tutoring | 33 | 2573 | 2171 | 84.4 | HIGH | child data-access grants; audit writer dead/0% |
| 11 | lib/core/analytics | 5 | 94 | 79 | 84.0 | HIGH | child-privacy Firestore/Analytics writers |
| 12 | lib/features/profiles | 34 | 2718 | 2312 | 85.1 | HIGH | PIN; pin_flow_machine dead copy 1.1% |
| 13 | lib/core/email | 2 | 55 | 1 | 1.8 | MEDIUM | no-op logging stub; no email provisioned; low real risk |
| 14 | lib/features/onboarding | 28 | 2186 | 1875 | 85.8 | HIGH | |
| 15 | lib/app/restore | 3 | 175 | 151 | 86.3 | HIGH | backup/restore |
| 16 | lib/features/scheduler | 39 | 2918 | 2536 | 86.9 | HIGH | scheduler engine; models + repo_impl absent/dead |
| 17 | lib/core/navigation | 5 | 108 | 102 | 94.4 | MEDIUM | pin_scope/auth_guard absent from lcov |
| 18 | lib/core/network | 4 | 29 | 17 | 58.6 | MEDIUM | |
| 19 | lib/core/time | 2 | 35 | 35 | 100 | MEDIUM | |
| 20 | lib/features/tracks | 59 | 5070 | 4137 | 81.6 | MEDIUM | |
| 21 | lib/features/notifications | 10 | 827 | 681 | 82.3 | MEDIUM | |
| 22 | lib/features/learning | 27 | 1572 | 1300 | 82.7 | MEDIUM | |
| 23 | lib/core/providers | 8 | 112 | 93 | 83.0 | MEDIUM | |
| 24 | lib/features/progress | 38 | 3429 | 2978 | 86.8 | MEDIUM | |
| 25 | lib/core/content | 8 | 290 | 254 | 87.6 | MEDIUM | |
| 26 | lib/app/router | 5 | 469 | 426 | 90.8 | MEDIUM | |
| 27 | lib/core/preferences | 10 | 403 | 370 | 91.8 | MEDIUM | |
| 28 | lib/features/gamification | 38 | 2242 | 2094 | 93.4 | MEDIUM | points integrity but mostly UI |
| 29 | lib/core/domain | 10 | 257 | 241 | 93.8 | MEDIUM | |
| 30 | lib/core/logging | 3 | 173 | 89 | 51.4 | LOW | |
| 31 | lib/features/dashboard | 31 | 1750 | 1432 | 81.8 | LOW | |
| 32 | lib/core/labels | 7 | 460 | 387 | 84.1 | LOW | |
| 33 | lib/features/content_browsing | 19 | 1786 | 1539 | 86.2 | LOW | |
| 34 | lib/l10n | 3 | 3505 | 2817 | 80.4 | LOW | dead-weight denominator |
| 35 | lib/core/theme | 2 | 251 | 218 | 86.9 | LOW | |
| 36 | lib/features/sacred_time | 13 | 588 | 535 | 91.0 | LOW | |
| 37 | lib/core/widgets | 17 | 574 | 535 | 93.2 | LOW | |
| 38 | lib/core/exceptions | 4 | 16 | 15 | 93.8 | LOW | |
| 39 | lib/core/constants | 3 | 124 | 117 | 94.4 | LOW | |
| 40 | lib/core/utils | 8 | 207 | 198 | 95.7 | LOW | |
| 41 | lib/core/enums | 2 | 25 | 25 | 100 | LOW | |

## 15 worst risk-weighted hand-written files

Generated files excluded — the raw lcov worst list is dominated by generated drift code (`learning_ledger_dao.g` 4.8%, `bookmark_dao.g`/`goal_dao.g` 5.3%) whose hand-written counterparts are 88-100% covered (points_balance_dao 94%, completion_dao 98%, goal_dao 100%).

| # | File | LF | % | Risk | Note |
|---:|---|---:|---:|---|---|
| 1 | lib/app/sync_runtime/sync_lifecycle_observer.dart | — | 0 | HIGH | LIVE sync-timing hook, absent from lcov |
| 2 | lib/core/sync/providers/merge_router_provider.dart | 26 | 0 | HIGH | entity→merger routing (TEA-014) |
| 3 | lib/core/auth/google_sign_in_gateway_impl.dart | 19 | 0 | HIGH | live sign-in error mapping (TEA-032) |
| 4 | lib/core/sync/sync_write_facade.dart | — | 0 | HIGH | absent from lcov (abstract) |
| 5 | lib/core/auth/firebase_auth_gateway.dart | — | 0 | HIGH | absent from lcov (abstract) |
| 6 | lib/core/database/seed/learning_program_seeds.dart | — | 0 | MEDIUM | curriculum seed data, absent from lcov |
| 7 | lib/core/navigation/pin_scope.dart | — | 0 | HIGH | PIN gating, absent from lcov |
| 8 | lib/features/settings/presentation/screens/upgrade_to_cloud_screen.dart | 433 | 28.2 | HIGH | offline→cloud data migration (TEA-034) |
| 9 | lib/core/sync/providers/sync_orchestrator_providers.dart | 44 | 11.4 | HIGH | |
| 10 | lib/core/ids/natural_key.dart | 20 | 10.0 | HIGH | sync dedup key factories (TEA-044) |
| 11 | lib/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart | 31 | 19.4 | HIGH | child-access grant logic |
| 12 | lib/core/sync/providers/tutored_pull_providers.dart | 42 | 21.4 | HIGH | tutored child-data pull |
| 13 | lib/core/sync/providers/outbox_providers.dart | 32 | 21.9 | HIGH | |
| 14 | lib/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart | 50 | 24.0 | HIGH | |
| 15 | lib/features/sync/domain/merge_rules.dart | — | 0 | HIGH | absent from lcov |

Note on 0% dead duplicates: several risk-labelled 0% files (`pin_flow_machine.dart` 1/88, `set_parent_pin_use_case.dart`, `verify_parent_pin_use_case.dart`, `tutor_audit_log_writer.dart` 0/33, `StudyDayConfigRepositoryImpl`) are **dead code** already flagged by the standards register (AUD-profiles-06/07, AUD-tutoring-06, AUD-scheduler-06). Their 0% correctly signals dead code — but it also means the *live* PIN and tutor-audit paths have no canonical unit-tested domain layer (TEA-045).

## lib/ directories with no test/ counterpart

| Directory | Risk |
|---|---|
| test/app/bootstrap | HIGH — startup wiring |
| test/app/sync_runtime | HIGH — live sync lifecycle |
| test/core/ids | HIGH — sync natural keys |
| test/core/learning | MEDIUM |
| test/core/email | LOW — stub |
| test/core/enums | LOW |
| test/core/time | LOW |

## Recommendations

1. Replace the flat 60% floor with risk-tiered per-directory floors (e.g. `core/sync`, `core/auth`, `core/database` ≥85%; UI/l10n ≥50%) — TEA-013.
2. Add a gate: every `lib/*.dart` must appear in lcov (executed by ≥1 test), so zero-coverage files hard-fail instead of vanishing from the denominator — TEA-013.
3. Table-driven test asserting `merge_router_provider` binds every registered entity type to its expected merger, plus per-entity push+pull integration through `sync_orchestrator_providers` — TEA-014.
4. Branch/mutation testing (or explicit malformed-payload fixtures) on the merge/codec layer: every codec's `decode()` must survive a null/garbage value in every column — TEA-015.
5. Scenario tests for `upgrade_to_cloud_screen` (success, mid-migration failure/rollback, correct account scoping of every migrated profile row) — TEA-034.
