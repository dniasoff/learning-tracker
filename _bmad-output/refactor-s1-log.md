# Refactor S1 Log — Foundation Stream

Stream: S1 (Foundation)
Plan: docs/planning/tech-debt-remediation-plan.md v3.3
Tracker: _bmad-output/refactor-task-tracker.md

---

## [2026-05-20 03:00] task-complete
- task: W1.1
- commit: 4d8363f3
- detail: Created lib/app/ directory tree with four sub-dirs: router/, bootstrap/, restore/, sync_runtime/. Added .gitkeep in each so they appear in git. These are empty scaffolds; files move into them in W1.2-W1.6.
- next: W1.2

## [2026-05-20 09:00] task-complete
- task: W1.9
- commit: 0cdf170f
- detail: Moved language_provider.dart from features/settings/presentation/providers/ to core/preferences/. Old .dart replaced with re-export stub; old .g.dart deleted (orphaned part-of) and untracked from git. New .g.dart lives on disk at core/preferences/ (gitignored consistently). dart analyze: 0 issues on affected dirs.
- next: W1.10

## [2026-05-20 13:30] task-complete
- task: W7.20+W7.21+W7.22+W7.23 (committed together)
- commit: bc327fef
- detail: W7.20: NoEToStringInUi lint (WARNING) — checks common exception identifier names (e/err/ex/error/exception) for .toString() calls in presentation/ files. W7.21: NoRawLogEvent lint (ERROR) — detects direct logEvent() calls outside analytics_service.dart. Both registered in plugin (7 total rules). dart analyze on custom_lints/lib: 0 issues. W7.22: root Makefile was already deleted in a prior commit; working-tree copy removed via git rm. W7.23: CLAUDE.md Rule 3 fixed — lib/features/auth/ → lib/core/auth/ (auth merged into account in W2.11).
- next: all S1 tasks complete

## [2026-05-20 13:15] task-complete
- task: W1.28+W1.29+W1.30 (separate commits)
- commits: dbea6f38 (W1.28), b5edfb69 (W1.29), 01cabef3 (W1.30)
- detail: W1.28: Created core/exceptions/app_exception.dart with AppException abstract root + 6 category bases (Validation, Conflict, Permission, NotFound, Network, Internal). Reparented validation_exception.dart and permission_exception.dart as re-export stubs. TutorWriteForbiddenException kept in permission_exception.dart with import of new base. W1.29: Created core/logging/log_events.dart with 8 subsystem classes (sync, auth, profile, scheduler, track, tutor, content, notification) accessed via LogEvents namespace. W1.30: Updated CLAUDE.md — removed dead link to coding-standards.md, updated Rule 2 to reference barrel file Y/Y.dart (not providers.dart). dart analyze on affected files: 0 errors.
- next: W7.20

## [2026-05-20 12:30] task-complete
- task: W1.25+W1.26+W1.27 (committed together)
- commit: bcc43d9b
- detail: W1.25: AppLogger.instance now returns AppLogger singleton (was Talker). Renamed static Talker getter to rawTalker (conflict with instance member talker). talker_provider updated to AppLogger.rawTalker. W1.26: 24 call sites migrated from positional Talker API to structured named-parameter API (event:, exception:, stackTrace:) — covers core guards, DAO, profiles, account, content_browsing, dashboard, onboarding, progress, scheduler, settings, track_setup/tracks trees. W1.27: 5 AppLogger(AppLogger.instance) defensive wrappers replaced with direct AppLogger.instance. dart analyze on all 24 changed files: 0 errors (4 pre-existing directives_ordering infos in unrelated files).
- next: W1.28

## [2026-05-20 03:30] task-complete
- task: W1.2
- commit: eb9e7fb7
- detail: Moved app_router.dart, app_router.gr.dart, router_provider.dart, app_shell.dart, and guards/auth_guard.dart from lib/core/navigation/ to lib/app/router/. Old locations replaced with re-export stubs so all 42 existing importers compile unchanged. Internal cross-references updated within moved files. Orphaned core/navigation/app_router.gr.dart deleted (the part file is now in app/router/). dart analyze: 0 errors on affected files; existing errors are from S2's in-progress W2.21 work.
- next: W1.3
