# V2-R5 — Cross-Cutting Concerns Adversarial Review

**Date:** 2026-05-20
**Reviewer:** V2-R5 (Sonnet 4.6, post-refactor adversarial pass)
**Branch:** dev
**Scope:** Exception hierarchy, AppLogger, PII redaction, telemetry naming, Crashlytics path, Firebase Analytics, AppErrorView migration, locale-aware dates, custom lint rules

---

## CRITICAL findings (3)

### C1 — `DuplicateEmailException` embeds a live email address in its `message` field; any catch-all logger call will leak PII to Talker/Crashlytics

- **File:** `learning_tracker/lib/features/account/domain/services/local_auth_service.dart:11-13`
- **Issue:** `DuplicateEmailException(this.email)` calls `super('$email is already registered')`. The `AppException.message` field therefore contains the actual email address. Any code path that calls `AppLogger.instance.error(event: …, exception: e)` on a caught `DuplicateEmailException` will stringify the exception (Talker calls `e.toString()` internally → `DuplicateEmailException: test@example.com is already registered`). This bypasses `PiiRedactor.sensitiveKeys` — the key-based redaction only protects structured `fields:` maps, not exception `.toString()` output passed to Talker.
- **Evidence:** `local_auth_service.dart:12` → `super('$email is already registered')`. Talker's `error()` method calls the exception's `toString()` for the log line. The signup screen catches `DuplicateEmailException` by type and replaces the message (safe), but no defence exists at the exception-constructor level. A future catch-all error handler or any site that adds `exception: e` logging would expose the email.
- **Impact:** Email PII leaked to Talker history (in-app diagnostics), and from there to Crashlytics `recordFlutterFatalError` if an uncaught exception propagates past the zone handler. Severity: CRITICAL — direct PII leak pathway exists.
- **Recommended fix:** Remove the email from the exception message: `const DuplicateEmailException() : super('Email is already registered');` Store the raw email in a separate field only if callers genuinely need it, but do not embed it in the `message` that participates in `toString()`.

---

### C2 — `LoggingTransactionalEmailService` logs `to: email.toAddress` in a structured field that is NOT in `PiiRedactor.sensitiveKeys`; the recipient's email address is written unredacted to Talker

- **File:** `learning_tracker/lib/core/email/transactional_email_service.dart:189-195`
- **Issue:** `LoggingTransactionalEmailService.send()` calls `AppLogger.instance.warning(event: '…', fields: {'to': email.toAddress, 'subject': email.subject})` followed by `AppLogger.instance.debug(event: '…', fields: {'body': email.plaintextBody})`. The key `'to'` is not in `PiiRedactor.sensitiveKeys` (which contains `'email'` and `'userEmail'` but not `'to'`). The email address passes through `PiiRedactor.redactFields()` without redaction.
- **Evidence:** `transactional_email_service.dart:191` uses key `'to'`. `logger.dart:203-247` (the full `sensitiveKeys` set) has no entry for `'to'`, `'subject'`, or `'body'`. `PiiRedactor.redactFields()` only redacts keys that match exactly.
- **Impact:** Every call to `TutorInviteEmail`, `TutorInviteAcceptedEmail`, or any future `TransactionalEmail` subclass writes the tutor's (or parent's) email address to Talker history. This is the primary current production path since the real email provider is not yet wired. The `body` field may also contain names and invite links.
- **Recommended fix:** Add `'to'` to `PiiRedactor.sensitiveKeys` (and consider `'subject'`, `'body'`). Alternatively, do not log `toAddress` at all — use a hashed/truncated form for correlation purposes.

---

### C3 — `learning_screen.dart:301` passes `e.toString()` directly as the `subtitle` to `_InfoCard`; the raw exception message reaches the user UI for the `dailyTasksAsync` error state

- **File:** `learning_tracker/lib/features/learning/presentation/screens/learning_screen.dart:298-302`
- **Issue:** The `dailyTasksAsync.when(error:)` branch renders `_InfoCard(icon: Icons.error_outline, title: …, subtitle: e.toString())`. This is NOT wrapped by `AppErrorView`. It exposes raw Dart exception text (including any `AppException.message` PII) directly in the visible UI. The W7.18 migration log shows `learning_screen.dart` was migrated for the top-level screen error, but this inline `.when()` error branch for the daily-tasks subsection was missed.
- **Evidence:** `learning_screen.dart:301` → `subtitle: e.toString()`. The S5 log lists `learning_screen.dart` as migrated, but inspection shows only the outer `AsyncValue` was migrated; the `dailyTasksAsync.when` on line 293 was not.
- **Impact:** If `allDailyTasksProvider` throws (e.g. `MissingPaceError`, `DatabaseException`, or any message-carrying `AppException`), the full exception string appears as a visible UI text element. CRITICAL: violates W7.20 lint intent and the no-PII-in-UI contract.
- **Recommended fix:** Replace the inner error branch with `AppErrorView(error: e, stackTrace: _, onRetry: () => ref.invalidate(allDailyTasksProvider))`.

---

## HIGH findings (6)

### H1 — `no_e_to_string_in_ui` lint does not cover the `error` variable name when used as an `AsyncValue.when(error:)` callback parameter; multiple uncaught sites evade enforcement

- **File:** `packages/custom_lints/lib/src/rules/no_e_to_string_in_ui.dart:42-48`
- **Issue:** The lint checks only five identifier names: `e`, `err`, `ex`, `error`, `exception`. However `error` IS listed, so `error.toString()` calls should be caught. In practice, `scheduler_screen.dart:117`, `progress_screen.dart:52`, `learning_journey_screen.dart:50`, `content_hierarchy_screen.dart:294`, `content_search_screen.dart:165`, and `text_display_screen.dart:208` all use `error.toString()` in presentation files and are lint violations. The custom lint is currently run only via `dart run custom_lint` in a separate process (not via the IDE analyzer due to version incompatibility — `analysis_options.yaml:9-12`). These sites either were missed during W7.18 or the lint is not running in CI in a way that blocks merges.
- **Evidence:** `scheduler_screen.dart:117` → `error.toString()`. `progress_screen.dart:52` → `error.toString()`. `learning_journey_screen.dart:50` → `error.toString()`. All in presentation layer; all should be flagged `no_e_to_string_in_ui:WARNING`.
- **Impact:** Raw exception messages (potentially containing internal details or PII from exception `.message` fields) surface in user-visible UI text in at least 6 screens.
- **Recommended fix:** Run `dart run custom_lint` in CI as a blocking gate (add to `Makefile ci` target). Migrate the 6 remaining sites to `AppErrorView`. The plan said "Migrate 20+ screens" — only 14 were done.

---

### H2 — `NotFoundException` has no concrete leaf exceptions anywhere in the codebase; `AppErrorView._configFor` never matches `NotFoundException`

- **File:** `learning_tracker/lib/core/exceptions/app_exception.dart:74-76` + `learning_tracker/lib/core/widgets/app_error_view.dart:166-174`
- **Issue:** `NotFoundException` is declared as an `abstract class`. A grep of the entire `lib/` tree finds zero concrete classes that `extend NotFoundException`. The `AppErrorView._configFor` check `if (error is NotFoundException)` therefore never evaluates to `true`. All "entity not found" scenarios that should show the empty-state + retry affordance will fall through to the generic `bug_report_outlined` + "Something went wrong" catch-all.
- **Evidence:** `grep "extends NotFoundException"` → 0 results. `app_error_view.dart:166` → dead branch.
- **Impact:** The NotFoundException UX bucket in `AppErrorView` is completely unused. Any missing-content scenario shows as a generic bug rather than a friendly "not found" state.
- **Recommended fix:** Either create leaf `NotFoundException` subclasses (e.g. `ContentNotFoundException`, `ProfileNotFoundException`) at the appropriate throw sites, or document that `NotFoundException` is reserved for a future wave and remove the dead branch from `AppErrorView` to avoid false confidence.

---

### H3 — W7.18 migration is incomplete: 6+ screens in `progress/` and `content_browsing/` still use the old `ErrorDisplay` widget and/or raw `error.toString()` pattern

- **Files:**
  - `learning_tracker/lib/features/progress/presentation/screens/progress_screen.dart:52`
  - `learning_tracker/lib/features/progress/presentation/screens/learning_journey_screen.dart:49-50`
  - `learning_tracker/lib/features/progress/presentation/screens/curriculum_progress_screen.dart:151-152`
  - `learning_tracker/lib/features/progress/presentation/screens/items_learned_screen.dart:93-94`
  - `learning_tracker/lib/features/progress/presentation/screens/lifetime_view_screen.dart:77`
  - `learning_tracker/lib/features/progress/presentation/screens/completion_history_screen.dart:68`
  - `learning_tracker/lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart:294`
  - `learning_tracker/lib/features/content_browsing/presentation/screens/content_search_screen.dart:165`
  - `learning_tracker/lib/features/scheduler/presentation/screens/scheduler_screen.dart:117`
- **Issue:** The W7.18 log states "Migrate 14 screens" against a plan target of "20+ screens". The above 9 screens were not migrated. They all surface raw exception messages (`error.toString()` or `'Failed to load: $error'`) directly in UI text, bypassing the category-aware `AppErrorView` and the no-PII-in-UI contract. The old `ErrorDisplay` widget in `core/widgets/error_display.dart` receives a `message: String` parameter — it has no knowledge of exception categories and always shows whatever string is passed to it.
- **Impact:** A `MissingPaceError`, `DuplicateCompletionException`, or any exception with a message-carrying payload will render its raw message in these screens.
- **Recommended fix:** Migrate all 9 screens to `AppErrorView`. Delete `ErrorDisplay` once it has no importers, or scope it to non-error-state utility display only.

---

### H4 — `MissingPaceError extends ArgumentError` (not `AppException`); it bypasses the exception hierarchy and `AppErrorView._configFor` renders it as a generic "bug" rather than a validation error

- **File:** `learning_tracker/lib/features/scheduler/domain/projection/overdue_types.dart:142-150`
- **Issue:** `MissingPaceError` extends `dart:core.ArgumentError`, not any `AppException` category. When it propagates to `scheduler_screen.dart` the `_configFor` method tests `is NetworkException` → `is ValidationException` → `is PermissionException` → `is NotFoundException` — all false — and falls to the generic catch-all `bug_report_outlined`. But `MissingPaceError` is a setup configuration error (the user must set a pace) — it should map to `ValidationException` so the UI can show a "check your setup" affordance, not a "report a bug" one.
- **Evidence:** `overdue_types.dart:142` → `class MissingPaceError extends ArgumentError`. `app_error_view.dart:134-185` — no branch for `ArgumentError`.
- **Impact:** A learner who has a misconfigured self-paced track sees "Something went wrong — report a bug" instead of actionable guidance to set a pace. Poor UX and confusing bug reports.
- **Recommended fix:** Change `MissingPaceError extends ValidationException`. Remove the `ArgumentError` dependency.

---

### H5 — `AppErrorView` accepts the stack trace but never forwards it to Crashlytics; `InternalException` and `ConflictException` errors displayed via `AppErrorView` are silently never reported

- **File:** `learning_tracker/lib/core/widgets/app_error_view.dart:51-55` and `119-126`
- **Issue:** `AppErrorView` takes `final StackTrace? stackTrace` but the comment says "unused in UI but reserved for future crash-report affordance." The "Report this issue" `TextButton` has an empty `onPressed: () {}` placeholder. For the categories that reach `AppErrorView` showing `bug_report_outlined` (`ConflictException`, `InternalException`), the error is shown to the user but never forwarded to Crashlytics. The runZonedGuarded + Flutter error handlers catch uncaught exceptions, but caught-and-displayed `InternalException`s (e.g. `MergeException`) routed through `AppErrorView` are invisible to Crashlytics.
- **Evidence:** `app_error_view.dart:120-126` → no-op `onPressed`. `app_error_view.dart:51-55` → `stackTrace` field never read in `build()`.
- **Impact:** `MergeException` and similar internal errors displayed via `AppErrorView` are reported to users but not visible in the Crashlytics dashboard. Developer blind spot for in-production errors.
- **Recommended fix:** In `AppErrorView.build()`, for error categories that show `bug_report_outlined`, call `crashlyticsServiceProvider.recordError(error, stackTrace, fatal: false)` after rendering. This requires the widget to be a `ConsumerWidget` or to receive a `CrashlyticsService` via constructor injection. Alternatively, the `onRetry` callback could carry this responsibility.

---

### H6 — `tutor_audit_log_writer.dart:217` calls `_analytics?.logEvent(…)` without `await` and without `unawaited()`; the Future is silently discarded

- **File:** `learning_tracker/lib/features/tutoring/domain/services/tutor_audit_log_writer.dart:217-224`
- **Issue:** The `_log()` method is declared `Future<void>` and ends with `return repository.appendEntry(entry)`. The `_analytics?.logEvent(…)` call on line 217 returns a `Future<void>` which is neither awaited nor wrapped with `unawaited()`. Dart's `unawaited_futures` lint would flag this, but if the analytics call throws (e.g. due to a network issue), the error is silently swallowed with no log, no Crashlytics capture.
- **Evidence:** `tutor_audit_log_writer.dart:217-224` — bare `_analytics?.logEvent(…);` with no `await` or `unawaited()`.
- **Impact:** Any analytics error in the tutor action flow is invisible. Additionally, if `logEvent` takes time, the audit entry is persisted before analytics fires — minor ordering issue. Most importantly: `unawaited` futures are a known source of subtle bugs when the Future eventually rejects.
- **Recommended fix:** Add `unawaited(_analytics?.logEvent(…));` to make the intent explicit and allow linters to verify it.

---

## MEDIUM findings (9)

### M1 — `DateFormat.yMMMd()` without locale parameter at two parallel locations in the duplicated `track_detail_screen.dart` files; goal deadline date shows US format regardless of locale

- **Files:**
  - `learning_tracker/lib/features/tracks/setup/presentation/screens/track_detail_screen.dart:288`
  - `learning_tracker/lib/features/track_setup/presentation/screens/track_detail_screen.dart:287`
- **Issue:** The `_goalSummary()` method returns `DateFormat.yMMMd().format(goal.targetDate!.toLocal())` (no locale argument) for deadline-type goals. The locale is available in the method's `String locale` parameter on the very next call at line 307. This is a copy-paste omission.
- **Evidence:** Both `track_detail_screen.dart` files have `DateFormat.yMMMd()` at the deadline branch and `DateFormat.yMMMd(locale)` at the estimated-finish branch 19 lines later.
- **Impact:** Hebrew/UK/AU users see `May 11, 2026` (US format) for deadline goals instead of `11 May 2026`. Violates the locale-aware date contract (memory: `feedback_calendar_terminology.md`).
- **Recommended fix:** Change both instances to `DateFormat.yMMMd(locale).format(goal.targetDate!.toLocal())`.

---

### M2 — `no_raw_logevent` lint whitelist covers only `analytics_service.dart`; `firebase_analytics_service.dart` calls `_analytics.logEvent(name: …)` through the Firebase SDK — the lint will fire if the whitelist is ever audited more strictly

- **File:** `packages/custom_lints/lib/src/rules/no_raw_logevent.dart:44-50`
- **Issue:** `_isWhitelisted()` permits only `analytics_service.dart`. `firebase_analytics_service.dart` calls `_analytics.logEvent(name: name, …)` on the Firebase SDK object — but the named-parameter form `logEvent(name: …)` has its first argument named (`name:`) rather than positional, so the lint check (`args.first` being `StringLiteral`/`SimpleIdentifier`) will not fire. This is currently harmless but relies on an implicit assumption about the Firebase SDK's parameter order. The whitelist should be explicit rather than relying on the accident of named parameters.
- **Evidence:** `no_raw_logevent.dart:70-71` — `final firstArg = args.first; if (firstArg is! StringLiteral && firstArg is! SimpleIdentifier) return;` — named arguments in Dart AST are `NamedExpression` nodes, which are neither `StringLiteral` nor `SimpleIdentifier`, so the rule silently passes.
- **Impact:** Low risk currently. If the Firebase SDK ever changes its API to positional arguments, or if the lint is tightened, `firebase_analytics_service.dart` would produce a false positive or break silently.
- **Recommended fix:** Add `firebase_analytics_service.dart` to `_isWhitelisted()` for clarity.

---

### M3 — Missing test file for `no_e_to_string_in_ui` and `no_raw_logevent` lint rules; test coverage gap leaves regressions undetected

- **File:** `packages/custom_lints/test/` (directory listing)
- **Issue:** The `test/` directory for the custom lints package contains test files for `no_color_literal_outside_theme`, `no_curriculum_display_name_bypass`, `no_feature_cross_import`, `no_firebase_outside_core`, `no_hardcoded_text_direction`, and `no_raw_talker` — but NOT for `no_e_to_string_in_ui` or `no_raw_logevent`. Both rules were added in W7.20/W7.21 and both are registered in the plugin. Without tests, a future refactor of the rule logic could silently disable enforcement.
- **Evidence:** `ls packages/custom_lints/test/` → no `no_e_to_string_in_ui_test.dart` or `no_raw_logevent_test.dart`.
- **Impact:** The two most security-relevant lint rules (PII-in-UI and raw analytics calls) have no automated regression tests.
- **Recommended fix:** Add `no_e_to_string_in_ui_test.dart` and `no_raw_logevent_test.dart` following the pattern of the existing test files.

---

### M4 — `Exception('Data pull failed: $message')` thrown in `device_restore_service.dart` bypasses the `AppException` hierarchy; the raw `Exception` class carries the sync-status message string to the `restoreStatusProvider` error handler

- **File:** `learning_tracker/lib/app/restore/device_restore_service.dart:175`
- **Issue:** When `pullOnLaunch` completes with `SyncStatusError`, `DeviceRestoreService` throws a bare `Exception('Data pull failed: $message')`. This reaches `restore_providers.dart:60` → `RestoreStatus.error(message: error.toString())`. The `error.toString()` of a bare `Exception` is its message string verbatim. The `DeviceRestoreScreen` then renders `message` directly in a `Text(message)` widget (line 128). This bypasses both `AppException` hierarchy and `AppErrorView` — the raw sync error string appears in the device-restore UI.
- **Evidence:** `device_restore_service.dart:175` → `throw Exception(…)`. `restore_providers.dart:60` → `error.toString()`. `device_restore_screen.dart:128` → `Text(message)`.
- **Impact:** If the sync error contains internal details (e.g. a Firestore error message), they are shown in the restore UI. Not as severe as C1/C2 but still violates the no-raw-error-in-UI contract.
- **Recommended fix:** Replace `throw Exception(…)` with `throw InternalException('Sync pull failed during restore')` or a new `RestoreFailedException extends InternalException`. The restore screen should receive a typed error and render a fixed user-friendly string.

---

### M5 — 100+ AppLogger call sites use raw string literals for the `event:` parameter rather than `LogEvents.*` constants; the `log_events.dart` constant file is underused

- **File:** Multiple — representative: `magic_link_service.dart:70,77,102,107,202,208,217`; `cloud_content_service.dart:209,228,258,306`; `sync_orchestrator.dart:312,327,338,470`; approximately 100 sites total
- **Issue:** The W1.29 task created `core/logging/log_events.dart` with typed constant classes and states "All AppLogger call sites MUST use a constant from this file." However, roughly 100 sites use ad-hoc string literals like `event: 'MagicLinkService initialized'`, `event: 'sync_orchestrator_pull_on_launch_start'`, etc. No lint rule enforces the use of `LogEvents.*` constants for `AppLogger` calls — `no_raw_logevent` only covers `analyticsService.logEvent()`, not `AppLogger.info(event: …)`.
- **Evidence:** `grep "event: '" lib/ | grep -v "LogEvents." | wc -l` → ~100 occurrences.
- **Impact:** Ad-hoc string literals mean event names drift, typos go undetected, and event name consistency is not enforceable. The telemetry naming convention `<subsystem>_<action>` cannot be machine-validated.
- **Recommended fix:** Add constants for the missing subsystems (`content`, `app`, `restore`, `navigation`, `email`) to `log_events.dart` and migrate the remaining call sites. Long-term: add a lint rule `no_raw_log_event_string` analogous to `no_raw_logevent` but targeting `AppLogger.info/debug/warning/error(event: <StringLiteral>)`.

---

### M6 — `ValidationException.message` is rendered directly as user-visible `subtitle` text in `AppErrorView`; future exception constructors embedding field values (as `DuplicateEmailException` does) would leak PII to the UI

- **File:** `learning_tracker/lib/core/widgets/app_error_view.dart:149`
- **Issue:** `_configFor(ValidationException e)` returns `_ErrorConfig(subtitle: error.message, …)`. The `message` field is the `AppException.message` string, which for `InvalidInputException` is `'$field: $reason'` and for `DuplicateEmailException` is `'$email is already registered'`. The `InvalidInputException` is currently caught specifically in the signup screen so `error.message` only reaches this path for other `ValidationException` leaves. But the pattern creates a systemic risk: any `ValidationException` that reaches a migrated `AppErrorView` screen will have its `message` field shown verbatim.
- **Evidence:** `app_error_view.dart:149` → `subtitle: error.message`. `local_auth_service.dart:11-12` → email in message.
- **Impact:** As the exception hierarchy matures and more leaves are added, new `ValidationException` constructors that follow the `DuplicateEmailException` pattern (embedding user-supplied data in `message`) will silently expose that data via `AppErrorView`.
- **Recommended fix:** For the `ValidationException` branch in `AppErrorView`, use a fixed localised string (e.g., `l10n.errorValidationGeneric`) rather than `error.message`. If the caller genuinely needs to show the exception message, pass it explicitly via a `customMessage:` parameter.

---

### M7 — `sync_orchestrator.dart:519` embeds `e.toString()` in an analytics event parameter; internal exception details flow into Firebase Analytics

- **File:** `learning_tracker/lib/core/sync/sync_orchestrator.dart:515-521`
- **Issue:** The `sync_pull_failed` analytics event is fired with `'error': e.toString()` in the parameters map. If `e` is a `FirestorePermissionDeniedException` or `MergeException`, its `message` field (and for network errors, `cause.toString()`) is serialised into the Firebase Analytics event. Analytics parameters are not PII-filtered and are visible in the Firebase console.
- **Evidence:** `sync_orchestrator.dart:519` → `'error': e.toString()`. Similarly `sync_orchestrator.dart:651` → `'error': error.toString()` in the listener-error event.
- **Impact:** Internal exception details (paths, Firestore collection names, error codes) appear in Firebase Analytics event parameters. If an exception wraps a lower-level error that contains user data (e.g. a UID in a permissions error message), that data would surface in the analytics console.
- **Recommended fix:** Replace `e.toString()` with a typed error code string. For example: `'error_type': e.runtimeType.toString()` or a short categorisation function `_errorCode(e)` that returns `'permission_denied'`, `'timeout'`, `'merge_failed'` etc. Avoid full exception messages in analytics parameters.

---

### M8 — `AppLogger.setupFlutterErrorHandlers()` exists as a public static method but is never called; it sets Talker-only handlers that would silently override the Crashlytics handlers set by `bootstrapCrashlyticsHandlers()` if called

- **File:** `learning_tracker/lib/core/logging/logger.dart:85-94`
- **Issue:** `AppLogger.setupFlutterErrorHandlers()` sets `FlutterError.onError` and `PlatformDispatcher.instance.onError` to Talker-only handlers (no Crashlytics). `bootstrapCrashlyticsHandlers()` also sets these same two handlers, and is the one actually called at startup. If `setupFlutterErrorHandlers()` is ever called by a developer (e.g. in tests or a new code path), it would silently replace the Crashlytics handlers, breaking W7.14/W7.15. The method is only referenced in tests.
- **Evidence:** `logger.dart:85-94` — the method exists. `main.dart` — does not call `setupFlutterErrorHandlers()`. `crashlytics_bootstrap.dart:26-33` — sets the same handlers.
- **Impact:** Latent footgun: calling `AppLogger.setupFlutterErrorHandlers()` (e.g. in a test that forgets to also wire Crashlytics) silently disables Crashlytics for Flutter framework errors.
- **Recommended fix:** Either delete `setupFlutterErrorHandlers()` (it duplicates what `bootstrapCrashlyticsHandlers` does, Talker-only), or add a `@Deprecated` annotation with a clear message explaining that `bootstrapCrashlyticsHandlers` is the canonical registration point.

---

### M9 — `FirebaseCrashlyticsService.recordError()` fires `logCrashReported(fatal: fatal)` for every non-fatal error (e.g. listener errors, W7.16); `crash_reported` analytics events will be over-reported

- **File:** `learning_tracker/lib/core/logging/crashlytics_service.dart:57-63`
- **Issue:** `FirebaseCrashlyticsService.recordError()` always calls `unawaited(_analytics.logCrashReported(fatal: fatal))` regardless of whether `fatal` is `true` or `false`. W7.16 routes every `ListenerSupervisor` error to `recordError(fatal: false)`. Each Firestore listener error (which can be transient and frequent, e.g. on poor connectivity) will fire a `crash_reported` analytics event. The `crash_reported` event will be inflated by non-crash events.
- **Evidence:** `crashlytics_service.dart:58-59` → `unawaited(_analytics.logCrashReported(fatal: fatal))` always fires. W7.16 sends listener errors with `fatal: false` → still fires the event.
- **Impact:** `crash_reported` in Firebase Analytics will be unreliable as a signal for actual crashes if non-fatal listener errors fire the same event name. Dashboards built on `crash_reported` will see inflated numbers.
- **Recommended fix:** Only fire `logCrashReported` when `fatal == true`: `if (fatal) unawaited(_analytics.logCrashReported(fatal: true));`. Non-fatal errors are already tracked in the Crashlytics non-fatal dashboard and don't need a separate analytics event.

---

## LOW findings (2)

### L1 — `SensitiveDataPatterns` class is marked `@Deprecated` but is still referenced in test code; no migration path provided

- **File:** `learning_tracker/lib/core/logging/logger.dart:277-310` + `learning_tracker/test/core/logging/logger_test.dart:96-115`
- **Issue:** `SensitiveDataPatterns` was superseded by `PiiRedactor` but is kept for "backward-compatibility with existing tests." The test file still calls `SensitiveDataPatterns.containsSensitiveData(…)` and `SensitiveDataPatterns.sensitiveFields`. No migration task or timeline is defined. The deprecated class has a different key set than `PiiRedactor.sensitiveKeys` (e.g. it lacks `displayName`, `tutor_email`, `invite_token`).
- **Evidence:** `logger.dart:278` → `@Deprecated Use PiiRedactor instead.` Test: `logger_test.dart:99` → `SensitiveDataPatterns.containsSensitiveData(…)`.
- **Impact:** Low — the deprecated class is only used in tests. But its key set is stale and diverges from the production `PiiRedactor.sensitiveKeys`, meaning test assertions about PII coverage are testing the wrong set.
- **Recommended fix:** Migrate `logger_test.dart` to use `PiiRedactor.sensitiveKeys` / `PiiRedactor.redactFields()`. Delete `SensitiveDataPatterns`.

---

### L2 — `AppErrorView` strings ("No connection", "Access denied", "Not found", "Invalid data", "Something went wrong", "Report this issue", "Retry") are hardcoded English; not in l10n

- **File:** `learning_tracker/lib/core/widgets/app_error_view.dart:138-185`
- **Issue:** All user-visible strings in `AppErrorView` are hardcoded English string literals, not l10n keys. The app supports Hebrew (`app_localizations_he.dart`). Hebrew-locale users will see English error messages.
- **Evidence:** `app_error_view.dart:139` → `title: 'No connection'`; `159` → `title: 'Access denied'`; etc. No `AppLocalizations.of(context)` call in `AppErrorView.build()`.
- **Impact:** Hebrew UI users see English error strings. The app otherwise fully supports Hebrew. This is a regression from the language-support contract.
- **Recommended fix:** Add l10n keys for each error category string and call `AppLocalizations.of(context)!.errorNetworkTitle` etc. in `build()`. Note: `AppErrorView` is a `StatelessWidget` not `ConsumerWidget`, so `BuildContext` is already available via `build(context)`.

---

## Summary

| Severity | Count |
|---|---|
| CRITICAL | 3 |
| HIGH | 6 |
| MEDIUM | 9 |
| LOW | 2 |
| **Total** | **20** |

### Key themes

1. **PII in exception messages**: `DuplicateEmailException` embeds a real email in its `message` field (C1); `LoggingTransactionalEmailService` logs email addresses with an unredacted key (C2); `ValidationException.message` is rendered verbatim in `AppErrorView` (M6).

2. **AppErrorView migration incomplete**: The plan called for 20+ screens; 14 were done. 9 additional screens remain on `error.toString()` or the old `ErrorDisplay` widget (C3, H3). The `no_e_to_string_in_ui` lint exists but is not running in CI as a blocking gate (H1).

3. **Exception hierarchy gaps**: `NotFoundException` has no concrete leaves — its `AppErrorView` branch is dead code (H2). `MissingPaceError` extends `ArgumentError` instead of `ValidationException` (H4). `Exception(…)` thrown in device restore bypasses the hierarchy (M4).

4. **Crashlytics / analytics correctness**: `AppErrorView` silently drops `InternalException`/`ConflictException` errors without reporting to Crashlytics (H5). `recordError(non-fatal)` fires `crash_reported` analytics events, inflating the signal (M9). `e.toString()` in analytics parameters sends internal exception details to Firebase (M7).

5. **`LogEvents` constants underused**: ~100 `AppLogger` call sites still use raw string literals (M5). The `log_events.dart` constant file was created (W1.29) but no lint enforces its use for `AppLogger` calls.
