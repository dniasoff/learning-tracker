# Story 15.10 — Dirshu Test Tracking (DNI-118)

## Story Overview

Dirshu learning programs include monthly tests (typically the first Sunday of each month). Users following a Dirshu program need visibility into upcoming test dates, configurable reminders, the ability to log scores after each test, and motivational feedback based on score trends. This story adds test date management, a dashboard card with countdown, reminder notifications, a score-entry flow, and trend-based motivational notifications.

**Depends on:** Existing notification infrastructure (Story 12.x), dashboard (Story 5.x), Drift database (core), SharedPreferences pattern for toggle settings.

---

## Acceptance Criteria

### AC1 — Test Date Data
- A bundled set of Dirshu test dates is seeded into the `dirshu_test_dates` table on first launch or app upgrade.
- Each test date row includes the program ID, scheduled date, and an optional material description.
- Test dates follow the "first Sunday of each month" rule by default.
- Test dates are updateable via schema migration on app release (new rows inserted, future dates updated, past dates left unchanged).

### AC2 — Test Reminders
- When a user activates a Dirshu-affiliated curriculum, the system prompts: "Enable test reminders?" with Yes/No.
- Default reminder schedule: 1 week before and 1 day before each test.
- Reminders use the existing `flutter_local_notifications` infrastructure and respect Shabbos quiet mode.
- Reminder timing is configurable from the Notifications settings screen.
- Reminders are cancelled if the user deactivates the Dirshu curriculum.

### AC3 — Score Logging
- After a test date passes, the app prompts the user (via dashboard card or notification tap) to log their score.
- Score entry: percentage slider or input (0-100%), date auto-filled to the test date, optional free-text notes field.
- Scores are persisted in the `dirshu_test_scores` table.
- Duplicate score entry for the same test date is prevented (upsert behavior).

### AC4 — Dashboard Card
- A "Next Dirshu Test" card appears on the dashboard **only** for users with an active Dirshu-affiliated curriculum.
- Card displays: next test date, countdown ("in X days"), and material description if available.
- After a test passes without a logged score, the card changes to "Log your score for [date]" with a tap action to open score entry.
- Card is inserted between the streak widget and today's tasks widget in the dashboard ListView.

### AC5 — Motivational Notifications
- After logging a score, the system evaluates the user's last 3 scores for a trend.
- If improving (each score >= previous): show notification like "78% -> 82% -> 87% -- You're on fire!"
- If stable (variation <= 3%): "Consistent at ~83% -- solid work!"
- If declining: "Keep pushing -- you've got this!"
- Motivational notifications use the existing `showRewardMilestone` pattern (immediate show, not scheduled).
- Respects the reward notification enabled toggle and Shabbos quiet mode.

### AC6 — Settings Integration
- Notification settings screen gains a "Dirshu Test Reminders" section (visible only when a Dirshu curriculum is active).
- Toggle: enabled/disabled (default: enabled when Dirshu is active).
- Configurable lead times: list of reminder offsets (default: [7 days, 1 day]).
- SharedPreferences keys: `dirshu_test_reminder_enabled`, `dirshu_test_reminder_offsets`.

### AC7 — Score History
- User can view past test scores in a simple list (date, score %, notes).
- Accessible from the dashboard card ("View history") or from curriculum settings.
- Sorted by test date descending.

---

## Data Model Details

### Table: `dirshu_test_dates`

```dart
/// Bundled Dirshu test dates, seeded on app install/upgrade.
class DirshuTestDates extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Which Dirshu program (maps to CurriculumId.storageKey, e.g. 'mishna_berurah')
  TextColumn get programId => text()();
  /// Scheduled test date
  DateTimeColumn get testDate => dateTime()();
  /// Optional description of material covered
  TextColumn get materialDescription => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [{programId, testDate}];
}
```

### Table: `dirshu_test_scores`

```dart
/// User-logged scores for Dirshu tests.
class DirshuTestScores extends Table {
  IntColumn get id => integer().autoIncrement()();
  /// Firebase UID of the user (from UserProfiles.firebaseUid)
  TextColumn get profileId => text()();
  /// Which Dirshu program
  TextColumn get programId => text()();
  /// FK to dirshu_test_dates.id
  IntColumn get testDateId => integer()();
  /// Score as integer 0-100
  IntColumn get scorePercentage => integer()();
  /// Optional notes
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{profileId, testDateId}];
}
```

### Schema Migration (v9 -> v10)

In `app_database.dart`, add:
```dart
if (from < 10) {
  await m.createTable($DirshuTestDatesTable(attachedDatabase));
  await m.createTable($DirshuTestScoresTable(attachedDatabase));
}
```

Bump `schemaVersion` to `10`.

---

## Screen Specifications

### Dashboard Card: `DirshuTestCard`

**Location:** `lib/features/dashboard/presentation/widgets/dirshu_test_card.dart`

**Layout:**
```
+-----------------------------------------------+
| [calendar icon]  Next Dirshu Test              |
|                                                |
|  Sunday, April 5, 2026                         |
|  in 19 days                                    |
|  Material: Siman 302-310                       |
|                                                |
|  [View History]              [Log Score]       |
+-----------------------------------------------+
```

**States:**
1. **Upcoming test** — shows date, countdown, material
2. **Score pending** — test date passed, no score logged; primary CTA is "Log Score"
3. **Hidden** — no active Dirshu curriculum

**Insertion point in dashboard:** Between `StreakWidget` and `TodaysTasksWidget` in `_DashboardBody.build()`.

### Score Entry: `DirshuScoreEntryScreen`

**Location:** `lib/features/dirshu/presentation/screens/dirshu_score_entry_screen.dart`

**Layout:**
- AppBar: "Log Test Score"
- Date field (pre-filled, read-only showing test date)
- Score slider (0-100%) with large numeric display
- Notes text field (optional, multiline)
- "Save" FilledButton
- On save: persist to DB, evaluate trend, show motivational notification if applicable, pop back

**Route:** `DirshuScoreEntryRoute(testDateId: int)`

### Score History: `DirshuScoreHistoryScreen`

**Location:** `lib/features/dirshu/presentation/screens/dirshu_score_history_screen.dart`

**Layout:**
- AppBar: "Test Score History"
- ListView of score entries, each showing:
  - Test date (formatted)
  - Score percentage (with color coding: green >= 80, amber >= 60, red < 60)
  - Notes (if any)
  - Trend arrow compared to previous entry
- Empty state: "No scores logged yet"

**Route:** `DirshuScoreHistoryRoute(programId: String)`

---

## Architecture & Design Notes

### Feature Structure

```
lib/features/dirshu/
  domain/
    services/
      dirshu_test_service.dart          # Business logic: seed dates, compute next test, trend analysis
      dirshu_reminder_scheduler.dart    # Schedule/cancel test reminders
  presentation/
    providers/
      dirshu_providers.dart             # Riverpod providers
      dirshu_providers.g.dart           # Generated
    screens/
      dirshu_score_entry_screen.dart
      dirshu_score_history_screen.dart
    widgets/
      dirshu_test_card.dart             # Dashboard card widget
```

### Core Database Additions

```
lib/core/database/
  tables/
    dirshu_test_dates.dart
    dirshu_test_scores.dart
  daos/
    dirshu_test_dao.dart
    dirshu_test_dao.g.dart              # Generated
```

### Provider Design (Riverpod, codegen style)

```dart
// dirshu_providers.dart

/// Whether user has an active Dirshu-affiliated curriculum.
@riverpod
Future<bool> isDirshuActive(Ref ref) async { ... }

/// Next upcoming test date for the active Dirshu program.
@riverpod
Future<DirshuTestDate?> nextDirshuTest(Ref ref) async { ... }

/// Test dates with pending score entry (past dates, no score logged).
@riverpod
Future<List<DirshuTestDate>> pendingDirshuScores(Ref ref) async { ... }

/// All scores for a program, ordered by test date desc.
@riverpod
Future<List<DirshuTestScore>> dirshuScoreHistory(Ref ref, String programId) async { ... }

/// Reminder enabled toggle (SharedPreferences-backed, same pattern as ReminderEnabled).
@riverpod
class DirshuReminderEnabled extends _$DirshuReminderEnabled { ... }

/// Reminder offset days (SharedPreferences-backed).
@riverpod
class DirshuReminderOffsets extends _$DirshuReminderOffsets { ... }

/// Sync effect: watches settings + test dates, schedules/cancels notifications.
@riverpod
Future<void> dirshuReminderSyncEffect(Ref ref) async { ... }
```

### Dirshu Program Mapping

The current `CurriculumId` enum does not explicitly mark which curricula are Dirshu-affiliated. Add a getter:

```dart
// In CurriculumId enum
bool get isDirshuProgram => switch (this) {
  CurriculumId.mishnaBerurah => true,
  // Add others as Dirshu programs are added
  _ => false,
};
```

This keeps the mapping centralized and avoids scattering Dirshu checks throughout the codebase.

### Notification Channels

Add to `notification_service.dart`:

```dart
const String dirshuTestReminderPayload = 'dirshu_test_reminder';
const String _dirshuChannelId = 'dirshu_test_reminders';
const String _dirshuChannelName = 'Dirshu Test Reminders';
const String _dirshuChannelDescription = 'Reminders for upcoming Dirshu tests';

/// Base ID for Dirshu test reminders (200-299 range).
const int _dirshuReminderBaseId = 200;
```

Add `scheduleDirshuTestReminder` and `cancelDirshuTestReminders` methods following the existing `scheduleDailyReminder` / `scheduleStreakAlert` pattern, but using `zonedSchedule` with a specific date (not `matchDateTimeComponents`).

### Notification Initializer Update

In `notification_initializer.dart`, add handling for `dirshuTestReminderPayload` to navigate to the score entry screen (if test date has passed) or dashboard (if upcoming).

---

## Implementation Steps

### Step 1: Data Model & Migration
1. Create `lib/core/database/tables/dirshu_test_dates.dart`
2. Create `lib/core/database/tables/dirshu_test_scores.dart`
3. Create `lib/core/database/daos/dirshu_test_dao.dart` with methods:
   - `getTestDatesByProgram(String programId)`
   - `getNextTestDate(String programId)` — next date >= today
   - `getPastTestDatesWithoutScore(String programId, String profileId)` — for pending prompts
   - `insertTestDate(DirshuTestDatesCompanion entry)`
   - `upsertTestDate({required String programId, required DateTime testDate, ...})` — for seeding
   - `getScoresByProgram(String programId, String profileId)`
   - `getScoreByTestDateId(int testDateId, String profileId)`
   - `upsertScore({required String profileId, required int testDateId, required int score, ...})`
   - `getRecentScores(String programId, String profileId, {int limit = 3})` — for trend
   - `watchNextTestDate(String programId)` — Stream for dashboard reactivity
4. Register tables and DAO in `app_database.dart`
5. Add migration block for schema v10
6. Run `dart run build_runner build --delete-conflicting-outputs`

### Step 2: CurriculumId Extension
1. Add `bool get isDirshuProgram` to `CurriculumId` enum
2. Verify no existing code breaks with `make analyze`

### Step 3: Test Date Seeding Service
1. Create `lib/features/dirshu/domain/services/dirshu_test_service.dart`
2. Implement `seedTestDates(String programId, {int monthsAhead = 12})`:
   - Generate first-Sunday-of-month dates for the next N months
   - Upsert into DB (idempotent — safe to call on every app launch)
3. Implement `getNextTest(String programId) -> DirshuTestDate?`
4. Implement `evaluateScoreTrend(List<int> recentScores) -> ScoreTrend`:
   - Returns enum: `improving`, `stable`, `declining`
   - With formatted message string
5. Call `seedTestDates` from app initialization (after DB is ready) for each active Dirshu program

### Step 4: Notification Integration
1. Add Dirshu channel constants and methods to `NotificationService`
2. Create `lib/features/dirshu/domain/services/dirshu_reminder_scheduler.dart`:
   - `scheduleReminders(DateTime testDate, List<int> offsetDays)` — schedules N notifications
   - `cancelAllReminders()` — cancels all Dirshu reminder IDs
3. Update `NotificationInitializer._handleNotificationTap` for `dirshuTestReminderPayload`

### Step 5: Providers
1. Create `lib/features/dirshu/presentation/providers/dirshu_providers.dart`
2. Implement all providers listed in Architecture section
3. Implement `dirshuReminderSyncEffect` following the `reminderSyncEffect` pattern
4. Run code generation

### Step 6: Dashboard Card
1. Create `lib/features/dashboard/presentation/widgets/dirshu_test_card.dart`
2. Widget reads `isDirshuActiveProvider` and `nextDirshuTestProvider`
3. Conditionally renders based on state (upcoming / score-pending / hidden)
4. Add to `_DashboardBody.build()` in `dashboard_screen.dart`:
   ```dart
   // After StreakWidget, before TodaysTasksWidget
   const DirshuTestCard(),
   const SizedBox(height: 12),
   ```
5. Add `dashboardDirshuTestProvider` invalidation to `RefreshIndicator.onRefresh`

### Step 7: Score Entry Screen
1. Create `DirshuScoreEntryScreen` as `ConsumerStatefulWidget`
2. Route param: `testDateId` (int)
3. Load test date info from DB, pre-fill date
4. Score input: `Slider` (0-100) with `Text` showing current value
5. Notes: `TextField(maxLines: 3)`
6. Save button: upsert score, evaluate trend, show motivational notification, `context.router.maybePop()`
7. Register route in `app_router.dart`

### Step 8: Score History Screen
1. Create `DirshuScoreHistoryScreen` as `ConsumerWidget`
2. Route param: `programId` (String)
3. Watch `dirshuScoreHistoryProvider(programId)`
4. ListView with score cards
5. Register route in `app_router.dart`

### Step 9: Settings Integration
1. Add "Dirshu Test Reminders" section to `NotificationsScreen`
2. Conditionally visible when `isDirshuActiveProvider` is true
3. Toggle + offset configuration (1d, 3d, 7d presets)
4. Wire `dirshuReminderSyncEffect` into the screen's `ref.watch`

### Step 10: Onboarding Hook
1. In curriculum activation flow (`CurriculumActivationService.activate` or onboarding), detect if activated curriculum `isDirshuProgram`
2. Trigger test date seeding
3. Show "Enable test reminders?" prompt (can be a simple dialog)

---

## Dev Notes

### Test Date Generation Algorithm

```dart
/// Returns the first Sunday of the given month/year.
DateTime firstSundayOf(int year, int month) {
  final firstDay = DateTime(year, month, 1);
  // DateTime.sunday == 7
  final daysUntilSunday = (DateTime.sunday - firstDay.weekday) % 7;
  return firstDay.add(Duration(days: daysUntilSunday));
}

/// Generate test dates for the next [monthsAhead] months.
List<DateTime> generateTestDates({int monthsAhead = 12}) {
  final now = DateTime.now();
  final dates = <DateTime>[];
  for (var i = 0; i <= monthsAhead; i++) {
    var month = now.month + i;
    var year = now.year;
    while (month > 12) {
      month -= 12;
      year++;
    }
    dates.add(firstSundayOf(year, month));
  }
  // Filter out dates that have already passed
  return dates.where((d) => !d.isBefore(DateTime(now.year, now.month, now.day))).toList();
}
```

### Notification Scheduling Strategy

- Use `zonedSchedule` (not repeating) for each reminder, since test dates are specific calendar dates.
- Notification IDs: `_dirshuReminderBaseId + (testDateId * 10) + offsetIndex` to ensure unique IDs per test + offset combination. This supports up to 10 reminder offsets per test.
- When test dates are re-seeded, cancel all existing Dirshu reminders and reschedule. This is simpler than diffing.
- Maximum pending notifications on Android is 500; with 12 months x 2 offsets = 24 notifications, well within limits.

### Score Trend Evaluation

```dart
enum ScoreTrend { improving, stable, declining }

({ScoreTrend trend, String message}) evaluateScoreTrend(List<int> scores) {
  if (scores.length < 2) {
    return (trend: ScoreTrend.stable, message: 'Keep it up!');
  }

  final recent = scores.take(3).toList(); // most recent first
  final reversed = recent.reversed.toList(); // chronological order

  var allImproving = true;
  var allStable = true;
  for (var i = 1; i < reversed.length; i++) {
    if (reversed[i] < reversed[i - 1]) allImproving = false;
    if ((reversed[i] - reversed[i - 1]).abs() > 3) allStable = false;
  }

  if (allImproving && !allStable) {
    final arrow = reversed.map((s) => '$s%').join(' -> ');
    return (
      trend: ScoreTrend.improving,
      message: '$arrow -- You\'re on fire!',
    );
  } else if (allStable) {
    final avg = (reversed.reduce((a, b) => a + b) / reversed.length).round();
    return (
      trend: ScoreTrend.stable,
      message: 'Consistent at ~$avg% -- solid work!',
    );
  } else {
    return (
      trend: ScoreTrend.declining,
      message: 'Keep pushing -- you\'ve got this!',
    );
  }
}
```

### Dirshu Curriculum Detection

Initially only `mishna_berurah` is Dirshu-affiliated. The `isDirshuProgram` getter on `CurriculumId` makes it trivial to add more programs later (e.g., a dedicated "Dirshu Kinyan Shas" curriculum) without changing any consuming code.

### Notification ID Space

Current allocation:
- `0` — daily reminder
- `1` — streak alert
- `100-199` — reward milestones
- `200-299` — **Dirshu test reminders** (new)

This leaves plenty of room for future notification types.

---

## Test Plan

### Unit Tests

| Test | Location |
|------|----------|
| `firstSundayOf` returns correct date for various months | `test/features/dirshu/domain/services/dirshu_test_service_test.dart` |
| `generateTestDates` produces 12 future first-Sundays | same |
| `evaluateScoreTrend` — improving, stable, declining, single score | same |
| `DirshuTestDao.upsertTestDate` inserts new, updates existing | `test/core/database/daos/dirshu_test_dao_test.dart` |
| `DirshuTestDao.upsertScore` prevents duplicate per user+test | same |
| `DirshuTestDao.getNextTestDate` returns nearest future date | same |
| `DirshuTestDao.getRecentScores` returns correct order and limit | same |
| `DirshuReminderScheduler` calls `zonedSchedule` with correct dates | `test/features/dirshu/domain/services/dirshu_reminder_scheduler_test.dart` |
| Motivational notification respects enabled toggle | same file or notification test |

### Widget Tests

| Test | Location |
|------|----------|
| `DirshuTestCard` shows countdown for future test | `test/features/dashboard/presentation/widgets/dirshu_test_card_test.dart` |
| `DirshuTestCard` shows "Log Score" for past test without score | same |
| `DirshuTestCard` hidden when no Dirshu curriculum active | same |
| `DirshuScoreEntryScreen` validates 0-100 range | `test/features/dirshu/presentation/screens/dirshu_score_entry_screen_test.dart` |
| `DirshuScoreHistoryScreen` renders scores with color coding | `test/features/dirshu/presentation/screens/dirshu_score_history_screen_test.dart` |

### Story Acceptance Tests

File: `test/story_acceptance/epic_15_dirshu_test.dart`

```
group('Story 15.10 — Dirshu Test Tracking')
  - AC1: Test dates seeded for active Dirshu program
  - AC2: Reminders scheduled with correct offsets
  - AC3: Score logged and retrievable
  - AC3: Duplicate score upserts (does not create second row)
  - AC4: Dashboard card visible only for Dirshu users
  - AC5: Motivational message generated for improving trend
  - AC5: Motivational message generated for stable trend
  - AC5: Motivational message generated for declining trend
  - AC6: Settings toggle persists to SharedPreferences
  - AC7: Score history returns entries in descending date order
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/core/database/tables/dirshu_test_dates.dart` | Drift table definition |
| `lib/core/database/tables/dirshu_test_scores.dart` | Drift table definition |
| `lib/core/database/daos/dirshu_test_dao.dart` | DAO with all query methods |
| `lib/features/dirshu/domain/services/dirshu_test_service.dart` | Test date generation, seeding, trend analysis |
| `lib/features/dirshu/domain/services/dirshu_reminder_scheduler.dart` | Notification scheduling for test reminders |
| `lib/features/dirshu/presentation/providers/dirshu_providers.dart` | Riverpod providers |
| `lib/features/dirshu/presentation/screens/dirshu_score_entry_screen.dart` | Score logging screen |
| `lib/features/dirshu/presentation/screens/dirshu_score_history_screen.dart` | Score history list screen |
| `lib/features/dashboard/presentation/widgets/dirshu_test_card.dart` | Dashboard card widget |

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/database/app_database.dart` | Add tables, DAO, bump schema to v10, add migration |
| `lib/core/enums/curriculum_id.dart` | Add `isDirshuProgram` getter |
| `lib/features/notifications/domain/services/notification_service.dart` | Add Dirshu channel + schedule/cancel methods |
| `lib/features/notifications/domain/services/notification_initializer.dart` | Handle `dirshuTestReminderPayload` tap |
| `lib/features/notifications/presentation/providers/notification_providers.dart` | Add SharedPrefs keys for Dirshu settings |
| `lib/features/notifications/presentation/screens/notifications_screen.dart` | Add Dirshu reminders section |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Insert `DirshuTestCard`, add provider invalidation |
| `lib/features/dashboard/presentation/providers/dashboard_providers.dart` | (optional) Add Dirshu-related dashboard provider |
| `lib/core/navigation/app_router.dart` | Register `DirshuScoreEntryRoute`, `DirshuScoreHistoryRoute` |
| `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` | Add "View Test Scores" link for Dirshu curricula |
| `lib/main.dart` | Call `DirshuTestService.seedTestDates` at startup |
