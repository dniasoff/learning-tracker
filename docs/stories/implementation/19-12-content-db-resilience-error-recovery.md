# Story 19.12: Content DB Resilience & Error Recovery

Status: done

## Story

As a user,
I want the app to automatically recover from Content DB errors,
So that I never lose access to my learning progress due to content database issues.

## Acceptance Criteria

**AC-1: Corrupted content.db detected on open and automatically re-extracted from seed**
**Given** the `content.db` file exists but is corrupted (invalid SQLite header, schema mismatch, or `PRAGMA integrity_check` failure)
**When** the app attempts to open ContentDatabase during startup
**Then** the corrupted file is deleted and re-extracted from bundled `seed.db.gz`
**And** the app starts normally with a fresh ContentDatabase
**And** no user data in UserDatabase is affected

**AC-2: Missing content.db file triggers automatic re-extraction (no crash)**
**Given** the `content.db` file has been deleted (e.g., by a cache-cleaning app or filesystem issue)
**When** the app starts and `SeedManager.ensureContentDatabase()` runs
**Then** the file is decompressed from bundled `seed.db.gz`
**And** the app starts normally as if it were a first launch
**And** the user is never shown an error

**AC-3: PRAGMA integrity_check runs when corruption suspected**
**Given** a content DAO query throws a `SqliteException` at runtime (not during startup)
**When** the error is caught by the resilience layer
**Then** `PRAGMA integrity_check` is executed on the content.db connection
**And** if the check fails, the recovery flow (close, delete, re-extract, reopen) is triggered
**And** the original query is retried once after recovery

**AC-4: ContentResult<T> sealed type used for all cross-DB lookups**
**Given** any provider or service performs a cross-DB lookup (User DB data referencing Content DB data via `sefariaRef`, `programId`, or `dateKey`)
**When** the content lookup executes
**Then** it returns `ContentResult<T>` (either `ContentLoaded<T>` or `ContentNotFound<T>`)
**And** no cross-DB lookup returns a raw nullable `T?` or throws on missing content

**AC-5: Completions with stale refs display ref string + "Content unavailable"**
**Given** a user has Completions rows whose `sefariaRef` does not exist in the current TextCache
**When** the completion history is displayed
**Then** the completion row shows the date and raw `sefariaRef` string (e.g., "Berakhot 2a")
**And** a subtitle reads "Content unavailable"
**And** the completion is NOT hidden or deleted

**AC-6: Bookmarks with stale refs shown with fallback subtitle (not hidden, not crash)**
**Given** a user has Bookmarks whose `sefariaRef` does not exist in the current TextCache
**When** the bookmark list is displayed
**Then** the bookmark shows the raw `sefariaRef` string
**And** a subtitle reads "Content not available in current version"
**And** the bookmark is NOT removed from the database

**AC-7: LearningOrder filters missing refs from active list without deleting from DB**
**Given** a user has LearningOrder rows whose `sefariaRef` does not exist in the current TextCache
**When** the active learning order list is computed
**Then** items with missing content are excluded from the active/displayed list
**And** the rows remain in the LearningOrder table (they may become valid in a future seed update)

**AC-8: Calendar lookup returns graceful "Schedule not available" for missing dates**
**Given** a CalendarCycles lookup for a specific `programKey + dateKey` returns no rows
**When** the UI displays today's assignment for that program
**Then** the UI shows "Schedule not available" (not a crash or blank screen)
**And** other programs with valid data continue to display normally

**AC-9: Automatic recovery is silent to user (optional success toast)**
**Given** the content DB recovery flow runs successfully (re-extraction from seed)
**When** recovery completes
**Then** no error dialog is shown to the user
**And** an optional toast/snackbar "Content updated" may be displayed
**And** the incident is logged for analytics

**AC-10: Failed recovery shows user-friendly dialog with retry**
**Given** the content DB recovery flow fails (seed asset cannot be read, decompression fails, disk full)
**When** re-extraction is attempted and fails
**Then** a dialog is shown: "Content data needs to be restored. This may take a moment."
**And** the dialog has a "Retry" button that re-attempts extraction
**And** if retry also fails, the dialog shows: "Content data unavailable. Please reinstall the app."

**AC-11: All recovery paths logged for analytics**
**Given** any content DB error detection or recovery path executes
**When** the operation completes (success or failure)
**Then** a structured log entry is created via the app logger (Talker)
**And** the log includes: event type (corruption_detected, missing_file, recovery_success, recovery_failed), timestamp, and error details if applicable

**AC-12: Unit tests for each failure mode and recovery path**
**Given** the implementation is complete
**When** the test suite runs
**Then** unit tests cover: corrupted DB detection, missing file detection, PRAGMA integrity_check flow, ContentResult usage in each affected repository, SeedManager recovery paths, and widget tests for all fallback UI states

## Tasks / Subtasks

### Phase 1: ContentResult<T> Sealed Type and Content Lookup Abstraction (AC: 4)

#### T1.1: Create ContentResult<T> sealed class

- [ ] Create `lib/core/database/content/content_result.dart`:
  ```dart
  /// Sealed result type for all cross-DB content lookups.
  /// Forces callers to handle both loaded and not-found cases.
  sealed class ContentResult<T> {
    const ContentResult();
  }

  /// Content was found in ContentDatabase.
  class ContentLoaded<T> extends ContentResult<T> {
    final T data;
    const ContentLoaded(this.data);
  }

  /// Content reference exists in UserDB but the corresponding
  /// ContentDB entry is missing (stale ref after seed update).
  class ContentNotFound<T> extends ContentResult<T> {
    /// The raw reference string (sefariaRef, programId, dateKey)
    /// for display as a fallback.
    final String ref;
    const ContentNotFound(this.ref);
  }
  ```
- [ ] Export from `lib/core/database/content/content_database.dart` barrel (or a shared barrel if the content directory is not yet created)

#### T1.2: Create ContentLookupService

- [ ] Create `lib/core/database/content/content_lookup_service.dart`:
  ```dart
  /// Centralized service for all Content DB lookups that may fail
  /// due to stale cross-DB references. Wraps raw DAO calls in
  /// ContentResult<T> return types.
  class ContentLookupService {
    final TextCacheDao _textCacheDao;
    final CalendarCycleDao _calendarCycleDao;
    final LearningProgramDao _learningProgramDao;

    ContentLookupService({
      required TextCacheDao textCacheDao,
      required CalendarCycleDao calendarCycleDao,
      required LearningProgramDao learningProgramDao,
    })  : _textCacheDao = textCacheDao,
          _calendarCycleDao = calendarCycleDao,
          _learningProgramDao = learningProgramDao;

    /// Look up text content by sefariaRef.
    Future<ContentResult<TextCacheData>> getText(String sefariaRef) async {
      final result = await _textCacheDao.getText(sefariaRef);
      if (result != null) return ContentLoaded(result);
      return ContentNotFound(sefariaRef);
    }

    /// Look up calendar cycle for a program on a date.
    Future<ContentResult<CalendarCycleData>> getCalendarCycle(
      String programKey,
      String dateKey,
    ) async {
      final result = await _calendarCycleDao
          .getCycleForProgramAndDate(programKey, dateKey);
      if (result != null) return ContentLoaded(result);
      return ContentNotFound('$programKey/$dateKey');
    }

    /// Look up a learning program by ID.
    Future<ContentResult<LearningProgramData>> getProgram(
      int programId,
    ) async {
      final result = await _learningProgramDao.getProgramById(programId);
      if (result != null) return ContentLoaded(result);
      return ContentNotFound('programId:$programId');
    }
  }
  ```

#### T1.3: Create ContentLookupService Riverpod provider

- [ ] Create or add to `lib/core/providers/content_lookup_provider.dart`:
  ```dart
  @Riverpod(keepAlive: true)
  ContentLookupService contentLookupService(Ref ref) {
    final contentDb = ref.watch(contentDatabaseProvider);
    return ContentLookupService(
      textCacheDao: contentDb.textCacheDao,
      calendarCycleDao: contentDb.calendarCycleDao,
      learningProgramDao: contentDb.learningProgramDao,
    );
  }
  ```
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`

### Phase 2: Update Cross-DB Providers to Use ContentResult<T> (AC: 4, 5, 6, 7, 8)

#### T2.1: Update text display provider for ContentResult

- [ ] In `lib/features/content_browsing/presentation/providers/text_display_providers.dart`:
  - Change `textContent` provider to return `ContentResult<TextCacheData>` instead of `TextContent?`
  - Use `ContentLookupService.getText()` instead of raw `TextCacheRepository.getText()`
  - Alternatively, if `TextCacheRepository` is the right abstraction layer, update `TextCacheRepository.getText()` to return `ContentResult<TextContent>`:
    ```dart
    Future<ContentResult<TextContent>> getText(String sefariaRef) async {
      final cached = await _textCacheDao.getText(sefariaRef);
      if (cached != null) {
        return ContentLoaded(TextContent(
          hebrewText: cached.hebrewText,
          englishText: cached.englishText,
        ));
      }
      return ContentNotFound(sefariaRef);
    }
    ```

#### T2.2: Update completion display providers for stale ref handling

- [ ] Identify the provider(s) that build completion history UI data (likely in `lib/features/learning/presentation/providers/completion_providers.dart` or `lib/features/progress/presentation/providers/progress_providers.dart`)
- [ ] For each completion row, look up the text content via `ContentLookupService.getText(completion.sefariaRef)`
- [ ] Map to a display model that includes both the completion data and the content result:
  ```dart
  class CompletionDisplayItem {
    final Completion completion;
    final ContentResult<TextCacheData> content;
    CompletionDisplayItem({required this.completion, required this.content});
  }
  ```
- [ ] Ensure the provider never throws or filters out completions with missing content

#### T2.3: Update bookmark display providers for stale ref handling

- [ ] Identify the provider(s) that build bookmark list UI data (likely in `lib/features/learning/presentation/providers/bookmark_providers.dart`)
- [ ] For each bookmark row, look up text content via `ContentLookupService.getText(bookmark.sefariaRef)`
- [ ] Map to a display model:
  ```dart
  class BookmarkDisplayItem {
    final Bookmark bookmark;
    final ContentResult<TextCacheData> content;
    BookmarkDisplayItem({required this.bookmark, required this.content});
  }
  ```
- [ ] Ensure bookmarks with `ContentNotFound` are included in the list (not filtered out)

#### T2.4: Update learning order provider for stale ref filtering

- [ ] Identify the provider that computes the active learning order (likely in `lib/features/learning_order/presentation/providers/learning_order_providers.dart`)
- [ ] For each LearningOrder row, check content existence via `ContentLookupService.getText(order.sefariaRef)`
- [ ] Filter items where result is `ContentNotFound` from the active/displayed list
- [ ] Do NOT delete the filtered rows from the LearningOrder table
- [ ] Log filtered items for debugging: `logger.debug('LearningOrder item filtered: ${order.sefariaRef} not in ContentDB')`

#### T2.5: Update calendar assignment provider for missing date handling

- [ ] Identify the provider that displays today's calendar assignment (likely in `lib/core/providers/calendar_providers.dart` or `lib/features/dashboard/presentation/providers/dashboard_providers.dart`)
- [ ] Use `ContentLookupService.getCalendarCycle(programKey, todayDateKey)` instead of raw DAO call
- [ ] When result is `ContentNotFound`, map to a display state showing "Schedule not available" for that program
- [ ] Other programs in the list that have valid data should still display normally

#### T2.6: Update ProfilePrograms lookup for stale programId

- [ ] In providers that look up LearningProgram by `profileProgram.programId` (e.g., settings screens, track management):
  - Use `ContentLookupService.getProgram(profileProgram.programId)`
  - On `ContentNotFound`: show the curriculumType as fallback label, or "Unknown Program"
  - This is very low risk (program IDs are stable seed data) but the safety net must exist

### Phase 3: Fallback UI Widgets (AC: 5, 6, 7, 8)

#### T3.1: Create ContentUnavailableTile widget

- [ ] Create `lib/core/widgets/content_unavailable_tile.dart`:
  ```dart
  /// Reusable tile shown when a User DB record references content
  /// that doesn't exist in the current Content DB.
  class ContentUnavailableTile extends StatelessWidget {
    final String refString;
    final String message;
    final Widget? leading;
    final VoidCallback? onTap;

    const ContentUnavailableTile({
      super.key,
      required this.refString,
      this.message = 'Content unavailable',
      this.leading,
      this.onTap,
    });

    @override
    Widget build(BuildContext context) {
      return ListTile(
        leading: leading ?? Icon(
          Icons.text_snippet_outlined,
          color: Theme.of(context).colorScheme.outline,
        ),
        title: Text(
          refString,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
        ),
        onTap: onTap,
      );
    }
  }
  ```

#### T3.2: Create ScheduleUnavailableCard widget

- [ ] Create `lib/core/widgets/schedule_unavailable_card.dart`:
  ```dart
  /// Shown in place of a calendar program assignment when CalendarCycles
  /// has no entry for the requested programKey + dateKey.
  class ScheduleUnavailableCard extends StatelessWidget {
    final String programName;

    const ScheduleUnavailableCard({
      super.key,
      required this.programName,
    });

    @override
    Widget build(BuildContext context) {
      return Card(
        child: ListTile(
          leading: Icon(
            Icons.calendar_today_outlined,
            color: Theme.of(context).colorScheme.outline,
          ),
          title: Text(programName),
          subtitle: Text(
            'Schedule not available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
  }
  ```

#### T3.3: Update TextDisplayScreen for ContentNotFound

- [ ] In `lib/features/content_browsing/presentation/screens/text_display_screen.dart`:
  - Currently shows `_OfflineMessage()` when `textContent == null` (line 48-49)
  - Update to handle `ContentResult<T>`:
    - On `ContentLoaded`: show text as before
    - On `ContentNotFound`: show a distinct "content not found" view with the ref string and a message like "This content is not available in the current version"
  - The "not found" view should differ from the "loading" and "error" views

#### T3.4: Update completion history screen for ContentNotFound

- [ ] In the screen/widget that displays completion history:
  - Use `switch` on `ContentResult` to render either the full content tile or `ContentUnavailableTile`
  - The completion date and ref string must always be visible
  - Example pattern:
    ```dart
    switch (item.content) {
      case ContentLoaded(:final data):
        return CompletionTile(completion: item.completion, text: data);
      case ContentNotFound(:final ref):
        return ContentUnavailableTile(
          refString: ref,
          message: 'Content unavailable',
          leading: Icon(Icons.check_circle_outline),
        );
    }
    ```

#### T3.5: Update bookmark list screen for ContentNotFound

- [ ] In the screen/widget that displays bookmarks:
  - Use `switch` on `ContentResult` to render either the full bookmark tile or a fallback
  - Fallback: `ContentUnavailableTile(refString: ref, message: 'Content not available in current version')`

#### T3.6: Update ContentRecoveryDialog widget

- [ ] Create `lib/core/widgets/content_recovery_dialog.dart`:
  ```dart
  /// Shown when automatic Content DB recovery fails.
  class ContentRecoveryDialog extends StatelessWidget {
    final VoidCallback onRetry;
    final bool isPersistentFailure;

    const ContentRecoveryDialog({
      super.key,
      required this.onRetry,
      this.isPersistentFailure = false,
    });

    @override
    Widget build(BuildContext context) {
      return AlertDialog(
        title: const Text('Content Data Issue'),
        content: Text(
          isPersistentFailure
              ? 'Content data unavailable. Please reinstall the app.'
              : 'Content data needs to be restored. This may take a moment.',
        ),
        actions: [
          if (!isPersistentFailure)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          if (isPersistentFailure)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
        ],
      );
    }
  }
  ```

### Phase 4: Content DB Resilience in SeedManager (AC: 1, 2, 3, 9, 10, 11)

#### T4.1: Enhance SeedManager.ensureContentDatabase() with corruption detection

- [ ] In `lib/core/database/seed_manager.dart`, update `ensureContentDatabase()`:
  - Current algorithm (from 19.2b) checks file existence and version comparison
  - Add a try/catch around the "open content.db and read SeedMetadata" step
  - If opening throws (`SqliteException`, `DriftWrappedException`, or generic exception): treat as corruption
  - On corruption detection:
    1. Log: `logger.warning('Content DB corrupted, triggering recovery', error)`
    2. Close the connection if partially opened
    3. Delete the corrupted `content.db` file
    4. Fall through to the decompression step (same as first-launch path)

  ```dart
  Future<String> ensureContentDatabase() async {
    final contentDbPath = join(appDatabaseDir, 'content.db');
    final dbFile = File(contentDbPath);

    if (dbFile.existsSync()) {
      try {
        // Attempt to open and verify existing content.db
        final db = _openRawDatabase(contentDbPath);
        final installedVersion = _readSeedVersion(db);
        final bundledVersion = await _readBundledVersion();

        if (installedVersion >= bundledVersion) {
          db.dispose(); // Close raw sqlite3 connection
          return contentDbPath; // Up to date
        }
        db.dispose();
        dbFile.deleteSync();
        // Fall through to decompress new version
      } catch (e, stack) {
        _logger.warning('Content DB corrupt or unreadable, recovering', e, stack);
        _tryDeleteFile(dbFile);
        // Fall through to decompress
      }
    }

    // First launch, upgrade, or recovery: decompress from bundled asset
    await _extractSeedDb(contentDbPath);
    return contentDbPath;
  }
  ```

#### T4.2: Add PRAGMA integrity_check for runtime corruption detection

- [ ] Create `lib/core/database/content/content_db_health_checker.dart`:
  ```dart
  /// Checks Content DB integrity. Called when a content DAO
  /// query throws an unexpected SqliteException at runtime.
  class ContentDbHealthChecker {
    final ContentDatabase _db;
    final Logger _logger;

    ContentDbHealthChecker(this._db, this._logger);

    /// Returns true if the database passes integrity check.
    Future<bool> isHealthy() async {
      try {
        final result = await _db.customSelect(
          'PRAGMA integrity_check',
        ).get();
        final status = result.first.read<String>('integrity_check');
        return status == 'ok';
      } catch (e) {
        _logger.error('PRAGMA integrity_check itself failed', e);
        return false;
      }
    }
  }
  ```

#### T4.3: Create ContentDbRecoveryService

- [ ] Create `lib/core/database/content/content_db_recovery_service.dart`:
  ```dart
  /// Orchestrates Content DB error recovery at runtime.
  /// Called when a content query fails and integrity check fails.
  class ContentDbRecoveryService {
    final SeedManager _seedManager;
    final Logger _logger;

    ContentDbRecoveryService({
      required SeedManager seedManager,
      required Logger logger,
    })  : _seedManager = seedManager,
          _logger = logger;

    /// Attempt to recover the Content DB.
    /// Returns the new content DB path on success, null on failure.
    Future<String?> attemptRecovery() async {
      _logger.info('Content DB recovery started');

      try {
        // Step 1: Close existing ContentDatabase connection
        // (handled by caller — provider invalidation)

        // Step 2: Delete corrupted file and re-extract
        final path = await _seedManager.ensureContentDatabase(
          forceReExtract: true,
        );

        _logger.info('Content DB recovery succeeded');
        return path;
      } catch (e, stack) {
        _logger.error('Content DB recovery FAILED', e, stack);
        return null;
      }
    }
  }
  ```

#### T4.4: Add forceReExtract parameter to SeedManager

- [ ] In `lib/core/database/seed_manager.dart`:
  - Add optional `bool forceReExtract = false` parameter to `ensureContentDatabase()`
  - When `forceReExtract` is true, skip the version check and delete + re-extract unconditionally
  - This is used by the recovery service to force a fresh extraction

  ```dart
  Future<String> ensureContentDatabase({bool forceReExtract = false}) async {
    final contentDbPath = join(appDatabaseDir, 'content.db');
    final dbFile = File(contentDbPath);

    if (forceReExtract) {
      _logger.info('Force re-extract requested');
      _tryDeleteFile(dbFile);
    } else if (dbFile.existsSync()) {
      // ... existing version check logic ...
    }

    await _extractSeedDb(contentDbPath);
    return contentDbPath;
  }
  ```

#### T4.5: Wire recovery into ContentDatabase provider with retry

- [ ] Create `lib/core/providers/content_db_recovery_provider.dart`:
  ```dart
  @Riverpod(keepAlive: true)
  ContentDbRecoveryService contentDbRecoveryService(Ref ref) {
    return ContentDbRecoveryService(
      seedManager: SeedManager(),
      logger: ref.watch(loggerProvider),
    );
  }
  ```

- [ ] Create a wrapper around ContentDatabase access that catches `SqliteException` and triggers recovery:
  - Option A: Implement a `ResilientContentDatabase` proxy that wraps all DAO access
  - Option B (preferred): Add error handling at the provider layer — if a content query provider throws, catch it, run health check, trigger recovery if needed, and invalidate the `contentDatabaseProvider` to force reopen
  - The recovery flow:
    1. Content query throws `SqliteException`
    2. Run `ContentDbHealthChecker.isHealthy()` on the current connection
    3. If unhealthy: call `ContentDbRecoveryService.attemptRecovery()`
    4. If recovery succeeds: invalidate `contentDatabaseProvider` so Riverpod reopens the DB
    5. Retry the original query once
    6. If recovery fails: show `ContentRecoveryDialog`

#### T4.6: Add structured logging for all recovery events

- [ ] Define log event constants in `lib/core/database/content/content_db_events.dart`:
  ```dart
  abstract class ContentDbEvents {
    static const corruptionDetected = 'content_db.corruption_detected';
    static const missingFileDetected = 'content_db.missing_file_detected';
    static const integrityCheckFailed = 'content_db.integrity_check_failed';
    static const integrityCheckPassed = 'content_db.integrity_check_passed';
    static const recoveryStarted = 'content_db.recovery_started';
    static const recoverySuccess = 'content_db.recovery_success';
    static const recoveryFailed = 'content_db.recovery_failed';
    static const staleRefDetected = 'content_db.stale_ref_detected';
  }
  ```
- [ ] Use these in all SeedManager, HealthChecker, and RecoveryService log calls
- [ ] Log via Talker (existing app logger) so they appear in the in-app log viewer and can be filtered

### Phase 5: Startup Integration and Recovery Dialog (AC: 1, 2, 9, 10)

#### T5.1: Update main.dart startup to handle SeedManager failure

- [ ] In `main()` (after 19.6 restructures startup), wrap `SeedManager.ensureContentDatabase()` in try/catch:
  ```dart
  String? contentDbPath;
  try {
    contentDbPath = await seedManager.ensureContentDatabase();
  } catch (e, stack) {
    talker.error('SeedManager failed on startup', e, stack);
    // contentDbPath remains null — app will show recovery dialog
  }
  ```
- [ ] If `contentDbPath` is null, still call `runApp()` but with a flag indicating content DB is unavailable
- [ ] The app shell should check this flag and show `ContentRecoveryDialog` as a modal barrier

#### T5.2: Create ContentDbStatusNotifier for app-wide recovery state

- [ ] Create `lib/core/providers/content_db_status_provider.dart`:
  ```dart
  enum ContentDbStatus {
    ready,
    recovering,
    failed,
  }

  @Riverpod(keepAlive: true)
  class ContentDbStatusNotifier extends _$ContentDbStatusNotifier {
    @override
    ContentDbStatus build() => ContentDbStatus.ready;

    void setRecovering() => state = ContentDbStatus.recovering;
    void setReady() => state = ContentDbStatus.ready;
    void setFailed() => state = ContentDbStatus.failed;
  }
  ```
- [ ] App shell widget watches `contentDbStatusProvider` and overlays `ContentRecoveryDialog` when status is `failed`

#### T5.3: Show optional success toast after silent recovery

- [ ] When recovery succeeds (either at startup or runtime), show a brief snackbar:
  ```dart
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Content updated'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
  ```
- [ ] This toast is optional (can be feature-flagged or removed) but helps reassure users if they noticed a brief delay

### Phase 6: Testing (AC: 12)

#### T6.1: Unit tests for ContentResult<T>

- [ ] Create `test/core/database/content/content_result_test.dart`:
  - Test `ContentLoaded` construction and data access
  - Test `ContentNotFound` construction and ref access
  - Test exhaustive switch pattern matching (compile-time safety)
  - Test equality behavior

#### T6.2: Unit tests for ContentLookupService

- [ ] Create `test/core/database/content/content_lookup_service_test.dart`:
  - Test `getText()` returns `ContentLoaded` when TextCache has the ref
  - Test `getText()` returns `ContentNotFound` when TextCache lacks the ref
  - Test `getCalendarCycle()` returns `ContentLoaded` for valid programKey+dateKey
  - Test `getCalendarCycle()` returns `ContentNotFound` for missing entry
  - Test `getProgram()` returns `ContentLoaded` for valid programId
  - Test `getProgram()` returns `ContentNotFound` for invalid programId
  - Use in-memory ContentDatabase with selective seeding

#### T6.3: Unit tests for SeedManager recovery paths

- [ ] Create or update `test/core/database/seed_manager_recovery_test.dart`:
  - Test: existing valid content.db -> no recovery needed, returns path
  - Test: missing content.db -> extracts from seed, returns path
  - Test: corrupted content.db (invalid SQLite header) -> deletes and re-extracts
  - Test: content.db with stale version -> deletes and re-extracts
  - Test: `forceReExtract: true` -> always re-extracts regardless of state
  - Test: extraction failure (simulate missing asset) -> throws, logs error
  - Mock the asset bundle for test isolation

#### T6.4: Unit tests for ContentDbHealthChecker

- [ ] Create `test/core/database/content/content_db_health_checker_test.dart`:
  - Test: healthy DB -> `isHealthy()` returns true
  - Test: corrupted DB (simulate by writing garbage to file) -> `isHealthy()` returns false
  - Test: DB connection already closed -> `isHealthy()` returns false, does not throw

#### T6.5: Unit tests for ContentDbRecoveryService

- [ ] Create `test/core/database/content/content_db_recovery_service_test.dart`:
  - Test: `attemptRecovery()` succeeds -> returns new path
  - Test: `attemptRecovery()` fails (SeedManager throws) -> returns null
  - Test: logging events are emitted in correct order
  - Mock SeedManager for isolation

#### T6.6: Widget tests for fallback UI states

- [ ] Create `test/core/widgets/content_unavailable_tile_test.dart`:
  - Test: renders ref string and message
  - Test: custom message override works
  - Test: custom leading widget works
  - Test: onTap callback fires

- [ ] Create `test/core/widgets/schedule_unavailable_card_test.dart`:
  - Test: renders program name and "Schedule not available" message

- [ ] Create `test/core/widgets/content_recovery_dialog_test.dart`:
  - Test: non-persistent failure shows retry button
  - Test: persistent failure shows OK button and reinstall message
  - Test: retry button calls onRetry callback

#### T6.7: Widget tests for screens with ContentResult handling

- [ ] Update `test/features/content_browsing/presentation/screens/text_display_screen_test.dart`:
  - Test: `ContentLoaded` renders text content as before
  - Test: `ContentNotFound` renders "not available" message with ref string

- [ ] Create or update completion history widget tests:
  - Test: completions with `ContentLoaded` render full content
  - Test: completions with `ContentNotFound` render `ContentUnavailableTile`
  - Test: mix of loaded and not-found completions renders correctly

- [ ] Create or update bookmark list widget tests:
  - Test: bookmarks with `ContentNotFound` render fallback tile
  - Test: bookmarks are NOT hidden when content is missing

#### T6.8: Integration test for runtime corruption recovery

- [ ] Create `test/core/database/content/content_db_resilience_integration_test.dart`:
  - Test: start with valid ContentDB, corrupt the file mid-test, trigger a content query, verify recovery kicks in, verify query succeeds on retry
  - This test exercises the full flow: query fails -> health check -> recovery -> provider invalidation -> retry
  - Use a real in-memory DB for this test, simulating corruption by closing and replacing

## Dev Notes

### Architecture

| Aspect | Detail |
|--------|--------|
| Pattern | Resilience layer wrapping read-only Content DB with sealed result types |
| Core type | `ContentResult<T>` sealed class (ContentLoaded / ContentNotFound) |
| Recovery mechanism | SeedManager re-extracts from bundled `seed.db.gz` |
| Corruption detection | try/catch on open + `PRAGMA integrity_check` on runtime query failures |
| UI pattern | `switch` exhaustive matching on `ContentResult` in all display widgets |
| Dependencies | 19.2 (Two-Database Split), 19.2b (Content DB Runtime Upgrade Flow) |
| Should follow | 19.4 (Local Calendar Engine) so all content paths exist |

### Key Design Decisions

1. **ContentResult<T> is a sealed class, not a Result/Either type.** Using Dart 3 sealed classes with pattern matching provides compile-time exhaustiveness checking. Every `switch` on `ContentResult` must handle both `ContentLoaded` and `ContentNotFound`, making it impossible to forget the error case.

2. **ContentLookupService centralizes all cross-DB lookups.** Rather than wrapping each DAO individually, a single service provides all content lookups that may fail due to stale references. This creates a single place to add logging, retry logic, or caching.

3. **Recovery is at the SeedManager level, not the DAO level.** Content DB recovery always means "delete and re-extract from bundled seed." There is no partial repair. This is safe because the Content DB contains zero user data.

4. **User DB rows with stale content refs are NEVER deleted automatically.** A future seed update may restore the referenced content. The UI degrades gracefully, the data persists. Only the user can explicitly delete bookmarks or learning order items.

5. **Silent recovery by default.** Users should never know the Content DB was corrupted and recovered. The optional toast is minimal and reassuring, not alarming.

6. **PRAGMA integrity_check is only run on suspected corruption** (i.e., after a query throws), not on every startup. It takes ~100ms on a 300MB database and is unnecessary when queries succeed.

### Project Structure Notes

Files created in this story:

```
lib/core/database/content/
  content_result.dart                    # ContentResult<T> sealed class
  content_lookup_service.dart            # Centralized content lookup wrapper
  content_db_health_checker.dart         # PRAGMA integrity_check wrapper
  content_db_recovery_service.dart       # Recovery orchestration
  content_db_events.dart                 # Structured log event constants

lib/core/providers/
  content_lookup_provider.dart           # Riverpod provider for ContentLookupService
  content_db_recovery_provider.dart      # Riverpod provider for RecoveryService
  content_db_status_provider.dart        # App-wide recovery state

lib/core/widgets/
  content_unavailable_tile.dart          # Fallback tile for stale refs
  schedule_unavailable_card.dart         # Fallback card for missing calendar data
  content_recovery_dialog.dart           # Recovery failure dialog

test/core/database/content/
  content_result_test.dart
  content_lookup_service_test.dart
  content_db_health_checker_test.dart
  content_db_recovery_service_test.dart
  content_db_resilience_integration_test.dart

test/core/database/
  seed_manager_recovery_test.dart

test/core/widgets/
  content_unavailable_tile_test.dart
  schedule_unavailable_card_test.dart
  content_recovery_dialog_test.dart
```

Files modified in this story:

```
lib/core/database/seed_manager.dart                    # Add forceReExtract, corruption detection
lib/main.dart                                          # Wrap SeedManager in try/catch, recovery dialog
lib/features/content_browsing/presentation/
  providers/text_display_providers.dart                 # ContentResult return type
  screens/text_display_screen.dart                      # Handle ContentNotFound
lib/features/learning/presentation/
  providers/completion_providers.dart                   # ContentResult for completions
  providers/bookmark_providers.dart                     # ContentResult for bookmarks
lib/features/learning_order/presentation/
  providers/learning_order_providers.dart               # Filter stale refs
lib/core/providers/calendar_providers.dart              # ContentResult for calendar lookups
lib/features/dashboard/presentation/
  providers/dashboard_providers.dart                    # Calendar fallback
```

### Cross-DB Reference Map (Critical Context)

| User DB Table | Field | Content DB Table | Content DB Field | Lookup Pattern |
|---|---|---|---|---|
| Completions | `sefariaRef` | TextCache | `sefariaRef` (PK) | `ContentLookupService.getText(completion.sefariaRef)` |
| Bookmarks | `sefariaRef` | TextCache | `sefariaRef` (PK) | `ContentLookupService.getText(bookmark.sefariaRef)` |
| LearningOrder | `sefariaRef` | TextCache | `sefariaRef` (PK) | `ContentLookupService.getText(order.sefariaRef)` |
| ProfilePrograms | `programId` | LearningPrograms | `id` (autoincrement) | `ContentLookupService.getProgram(profileProgram.programId)` |
| (Calendar display) | `programKey + dateKey` | CalendarCycles | `{programKey, dateKey}` (composite PK) | `ContentLookupService.getCalendarCycle(programKey, dateKey)` |

### Constraints and Guardrails

1. **Never delete User DB data due to Content DB issues.** Completions are append-only. Bookmarks and LearningOrder rows persist even when their content references are stale.

2. **Never run PRAGMA integrity_check on startup.** Only on suspected corruption (query failure). It is a heavy operation on large databases.

3. **Recovery must not block the UI thread for more than 500ms.** Seed decompression runs on an isolate or uses streaming I/O. The UI shows a non-blocking indicator if recovery takes longer.

4. **ContentResult<T> must be used for ALL cross-DB lookups.** No provider should return a raw `T?` where the null might mean "content not found" versus "query error." The sealed type makes the distinction explicit.

5. **The recovery dialog's "Retry" should attempt recovery at most 3 times before showing the persistent failure message.** Implement a retry counter in the dialog or the recovery service.

6. **All Content DB errors and recovery events must be logged with structured event names** from `ContentDbEvents` for future analytics integration.

7. **Do not use `PRAGMA query_only = ON` in recovery scenarios** -- the integrity_check and cleanup operations need write access. The `query_only` pragma should only be applied after successful health verification.

### References

- Two-Database Architecture: `docs/planning/two-database-drift-architecture.md`
- Offline-First Architecture v2: `docs/planning/architecture-offline-v2.md`
- 19.2 Story Spec: `docs/stories/implementation/19-2-two-database-split.md`
- 19.6 Startup Hardening: `docs/stories/implementation/19-6-startup-sequence-hardening.md`
- Seed Database Build Tool Design: `docs/stories/implementation/seed-database-build-tool-design.md` (Section 11: SeedManager)
- Linear Issue: [DNI-209](https://linear.app/dniasoff/issue/DNI-209/1912-content-db-resilience-and-error-recovery)
- Git Branch: `yafetesfaye11/dni-209-1912-content-db-resilience-error-recovery`
- Current `TextCacheDao`: `learning_tracker/lib/core/database/daos/text_cache_dao.dart`
- Current `BookmarkDao`: `learning_tracker/lib/core/database/daos/bookmark_dao.dart`
- Current `CompletionDao`: `learning_tracker/lib/core/database/daos/completion_dao.dart`
- Current `LearningOrderDao`: `learning_tracker/lib/core/database/daos/learning_order_dao.dart`
- Current `ProfilePrograms` table: `learning_tracker/lib/core/database/tables/profile_programs.dart`
- Current `TextDisplayScreen`: `learning_tracker/lib/features/content_browsing/presentation/screens/text_display_screen.dart`
- Current text display providers: `learning_tracker/lib/features/content_browsing/presentation/providers/text_display_providers.dart`

## Dev Agent Record

### Agent Model Used

_Retroactively reconciled 2026-07-13 (AUD-docs-06) — this record was never backfilled at implementation time; sprint-status.yaml already showed `done` while this header still read the template default. No contemporaneous dev-agent record exists for the original implementation._

### Debug Log References

### Completion Notes List

- Re-verified 2026-07-13 against the live tree: `ContentDbHealthChecker` is shipped at `lib/core/database/content_db_health_checker.dart`, running `PRAGMA integrity_check` and re-extracting from the bundled `seed.db.gz` on detected corruption.
- Test coverage was re-homed under Epic 25's schema rebuild: `test/story_acceptance/epic_25_schema_core_test.dart` references `ContentDbHealthChecker` directly.
- Status header + sprint-status.yaml were inconsistent (header said `ready-for-dev`, tracker said `done`) — header corrected to match verified reality, not the other way around.

### File List

- `learning_tracker/lib/core/database/content_db_health_checker.dart`
- `learning_tracker/test/story_acceptance/epic_25_schema_core_test.dart`
