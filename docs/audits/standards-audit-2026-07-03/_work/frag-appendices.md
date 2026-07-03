## 5. Appendices

### A. Killed-findings log

Raw findings that did not survive adversarial verification (or chair adjudication). A finding here is not necessarily false — it failed the evidence bar.

- **[P0|KILLED]** Add a schema-version floor guard for UserDatabase — onUpgrade has no path below v25  
  _Refutation:_ Code quotes are accurate (schemaVersion=32, onUpgrade only handles from<25, database_provider.dart opens UserDatabase with no floor guard), and the git-archaeology on 9612d7a0 is correct. But the P0 "real device data corruption" claim rests on a premise the finding never checked: docs/linear-status. / The evidence quotes check out (schemaVersion=32, onUpgrade starts at from&lt;25, no floor guard i
- **[P3|KILLED]** Move core/database test files onto their AG-5-mirrored lib/ paths  
  _Refutation:_ All 3 'quotes' are fabricated: none exist at the cited lines — actual line 1 in each file is an unrelated import/doc-comment, verified by direct read. The underlying AG-5 gap (no test/core/database/content|user dirs; device_registry split not named device_registry_database_test.dart) is independentl
- **[P2|KILLED]** Fix copy-pasted stageDefinitionsRefs tests so completionEventsRefs is actually covered in user_database_managers_refs_test.dart  
  _Refutation:_ False premise: $$CurriculumTracksTableReferences (user_database.g.dart:15472-16403) has exactly 7 ref getters, no completions member — verified by reading the full class. The 'completionEventsRefs' grep hit belongs to a different class, $$LearnerProfilesTableReferences (13851-15472), keyed by profil
- **[P3|KILLED]** Add test coverage for ProgramStartingPosition.toLegacyGrammar  
  _Refutation:_ Central risk claim is false: CI already covers toLegacyGrammar. step_starting_position_l1_test.dart:891-899 asserts exact 'offset:7' sign encoding; provision_track_use_case_test.dart:381-458 round-trips N=5 and asserts exact 'offset:1' via the real production path. Also misattributes the caller: pro
- **[P3|KILLED]** Rename the three core/utils/*_utils.dart files off the banned _utils.dart suffix  
  _Refutation:_ Rule misread. coding-standards.md:582 bans literally naming a file 'utils.dart' (unfocused god-file) and gives 'hebrew_calendar_utils.dart' as the CORRECT compliant example — one of the three files this finding wants renamed. The File Placement Guide (line 655) explicitly directs all new utility fil
- **[P2|KILLED]** Delete streak_service_extended_test.dart — fully superseded by streak_service_recovery_test.dart  
  _Refutation:_ Refuted: streak_service_extended_test.dart:63 asserts `maxStreak >= currentStreak` on POPULATED data; recovery_test.dart's equivalent getStreak test (lines 108-114) only checks currentStreak==12, never maxStreak. The core claim 'extended_test.dart contributes nothing recovery_test.dart lacks' is fac
- **[P3|KILLED]** Convert CompletionRequest/BulkCompletionRequest to @freezed to match sibling CompletionCommand  
  _Refutation:_ Facts check out (plain final-field classes, no ==/hashCode, unused for equality anywhere) but 'match sibling CompletionCommand' is backwards: BookmarkEntity and MarkCompletionResult, the actual other files in domain/entities/, are also plain non-freezed classes — CompletionCommand is the directory's
- **[P2|KILLED]** Expand pin_setup_screen_test.dart beyond a single render smoke test and rename to match PinFlowScreen  
  _Refutation:_ Central premise is false, killing the finding as stated.
- **[P3|KILLED]** Set driftRuntimeOptions.dontWarnAboutMultipleDatabases in two_device_sync_test.dart's setUp, matching every other multi-device test  
  _Refutation:_ Quotes and warning are real (reproduced via flutter test). But the 'one file in the codebase that skips it' claim is false: running flutter test on data_export_roundtrip_test.dart fires the identical warning, also missing the flag. Finding also concedes the warning is a false positive (no shared Que
- **[P2|KILLED]** Write real coverage for ProgramSelectionStep — program_selection_step_test.dart never imports or renders the widget it's mirrored to  
  _Refutation:_ Refuted by a sibling file the finding missed: test/features/tracks/setup/presentation/widgets/program_selection_step_test.dart (the TRUE AG-5 path — 'track_setup' has no lib/ counterpart, it's a pre-flagged unmirrored dir) already red-first-tests programStartsLabel against the exact TS-1 regression 
- **[P3|KILLED]** Convert hand-written Provider/StreamProvider/FutureProvider.family declarations in tracks/setup to @riverpod codegen  
  _Refutation:_ All 6 evidence lines git-blame to May 13–Jun 11 2026, weeks before this audit — pre-existing, not new/changed. Repo-wide count of non-codegen Provider/Stream/FutureProvider ctors (~109) closely matches the standards doc's '~121 legacy usages' SM-1 baseline, explicitly listed as known gap #8 ('do NOT
- **[P2|KILLED]** Replace source-text-grep assertions with real widget tests in t3_readonly_surfaces_gating_test.dart and r3_shell_revocation_exit_test.dart  
  _Refutation:_ Central claim ('Repo-wide grep confirms... this is the SOLE regression coverage') is factually false. Real widget tests exist for the exact illustrated mutations: learning_screen_l1_test.dart:360-402 tests canEditStages true/false Add-Track-CTA gating (the flip scenario cited); settings_p1_test.dart / Chair: central claim ('sole regression coverage') factually false - second verifier located real 
- **[P2|KILLED]** Replace source-grep assertions with real widget/behavior tests in tutoring WS3.3*/V3C suite  
  _Refutation:_ Central claim disproven: test/features/settings/settings_screen_and_point_config_l1_test.dart:1148-1206 already pumps the real PointConfigScreen with tutorPerms.readOnly(), taps Save, and asserts the permission-denied snackbar plus disabled button opacity — contradicts 'ZERO other test'/'sole safety
- **[P1|KILLED]** Wire the profileId-in-PK schema-check invariant into the CI-invoked Makefile  
  _Refutation:_ Evidence checks out factually: root Makefile:99/228 wires schema-check into its `ci`, learning_tracker/Makefile:218 `ci: analyze validate-calendar test` has no schema-check, and there is no learning_tracker/tool/schema_check.dart (only root tool/schema_check.dart). CI (.github/workflows/ci.yml) runs / The three Makefile quotes are accurate at the cited lines, but the finding's central causal claim
- **[P2|KILLED]** Give ParentDashboardAggregator's streak test a fixed/injectable clock instead of mixing UTC-anchored seed data with SystemLocalDayClock's local-day read  
  _Refutation:_ Traced the actual mechanism and it doesn't reproduce: extractLocalDate() converts UTC-tagged event timestamps via .toLocal() while SystemLocalDayClock.today() is already local; worked numeric examples at UTC-5 and UTC+9 both correctly yield currentStreak=5. Code comments show 'D16' already fixed exa
- **[P3|KILLED]** Deduplicate the MockBookmarkRepository class defined identically in two test files  
  _Refutation:_ Duplicate class confirmed byte-identical at both lines. But AG-4's exact text (coding-standards.md:516) scopes 'unique across lib/' for production-code discovery; both evidence sites are test/ files, outside the rule's literal scope. Real minor duplication, wrong rule tag — not a valid AG-4 violatio
- **[P3|KILLED]** Add a Locale('he') RTL coverage variant for the Sacred-Time lock overlay test  
  _Refutation:_ File genuinely lacks Locale('he') (confirmed), but the claimed consequence is false: SacredTimeLockOverlay already gets real Hebrew-locale rendering coverage in test/features/sacred_time/presentation/widgets/sacred_time_lock_overlay_l10n_test.dart:108 (locale: Locale('he'), asserts real שבת text) an
- **[P2|KILLED]** Fix nonexistent example make targets in learning_tracker/README.md and CLAUDE.md  
  _Refutation:_ Evidence fabricated: README.md:23-25 are Tech-Stack bullets (Calendar/Logging/Testing), not the quoted table. That 'Key Targets' table (test-story-1.2/test-epic-1/test-all-stories) is verbatim at learning_tracker/CLAUDE.md:23-25, not README.md. README.md's real make refs (lines 54-55) are generic X.
- **[P3|KILLED]** Commit gradle-wrapper.jar instead of excluding it in android/.gitignore  
  _Refutation:_ Core premise false: reproduced `flutter create` with the same Flutter 3.44.1 SDK in this env — output android/.gitignore is byte-identical (gradle-wrapper.jar, /gradlew, /gradlew.bat all excluded). This IS the standard Flutter convention, not a deviation. Recommendation to 'match vanilla template' i

### B. Coverage & method statistics

- Manifest: 4,431 git-tracked files → Tier 1: 1,640 · Tier 2: 184 · Tier 3 (generated): 80 · Tier 4 (docs): 239 · Excluded: 2,288. Every file has a ledger row (`_LEDGER.md`); **zero UNAUDITED**.
- Per-file verdicts (audited tiers): 783 SOUND · 957 ISSUES · 157 DEFECTIVE · 166 POINT-IN-TIME.
- Find phase: 120 batch finders + 5 critic-triggered supplemental finders (Sonnet), full-file reads, ~556k lines audited. 1,008 raw findings incl. 7 orchestrator-seeded.
- Verification: every finding adversarially verified. P0/P1: 3 skeptics each (evidence-fidelity / behavior / novelty-severity lenses), majority to survive, 116 findings × 3 votes. P2/P3: grouped single skeptic (174 chunks) **plus** a 150-finding second-opinion sweep: 147/150 re-upheld (98% inter-verifier agreement); 33 severities revised downward/upward by verifiers; 19 killed overall (~2%).
- Calibration note (Part G expects 20–40% kills): the raw stream was pre-filtered by a strict novelty filter, a clean `flutter analyze` baseline, and schema-forced evidence — the 98% second-opinion agreement and a manual chair re-read of all 10 P0s support finder precision over verifier leniency. Disclosed rather than tuned.
- Completeness critic: independently reconciled all 2,368 non-audited tracked files to legitimate exclusion reasons; flagged 5 under-covered rule families → supplemental round (25 additional verified findings, incl. 1 P0 + 3 P1).
- Quota resilience: two mid-run quota outages; all completed work harvested from workflow journals, zero loss, ~1,140 agents total.

### C. Excluded files by reason

| Reason | Files |
|---|---|
| vendored-agent-tooling | 2094 |
| binary asset | 70 |
| archived/test-artifact per Part C | 59 |
| superseded-output-dir (hygiene finding) | 29 |
| content/data asset or cache | 25 |
| lockfile/license | 6 |
| accidental/binary artifact (hygiene finding) | 5 |

Full per-file list in `_LEDGER.md`.

### D. Mechanical baseline (novelty filter) digest

Run 2026-07-03 on clean tree at 4018a91c, before any agent spawned:
- `make audit` (inner, 22 checks): **PASS** — checks 14/15 warn-only; 32 known core→features import edges baselined.
- `flutter analyze`: **No issues found.**
- root `make arb-parity`: **OK — 1,421 EN keys all present in HE.**
- `dart run custom_lint`: **BROKEN** (custom_lint_core 0.8.1 vs analyzer 9.0.0, exit 255) — the nine custom lints enforce nothing anywhere; filed as AUD finding (P1).
- Tier-3 regen check: `build_runner` + `gen-l10n` on clean tree dirtied 3 committed `.g.dart` files (AG-7 finding).
- The 10 'Current Compliance Gaps' from docs/coding-standards.md were treated as baselined and NOT re-reported.
