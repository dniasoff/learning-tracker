---
stepsCompleted: [1, 2, 3, 4, 7, 9, 10, 11]
inputDocuments:
  - '_bmad-output/planning-artifacts/product-brief-learning-tracker-2026-01-03.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/epics.md'
briefCount: 1
researchCount: 0
brainstormingCount: 0
projectDocsCount: 0
techSpecCount: 0
workflowType: 'prd'
lastStep: 11
completedAt: '2026-02-08'
status: 'complete'
date: 2026-02-08
author: Daniel
version: v2
previousVersion: v1 (2026-01-04)
---

# Product Requirements Document - Learning Tracker

**Author:** Daniel
**Date:** 2026-02-08
**Version:** v2

## Executive Summary

**Learning Tracker** (formerly Learning Tracker) is a multi-curriculum Android app for tracking Torah learning with configurable review cycles, intelligent scheduling, and balanced motivation. The app supports both children and adults, serving any Torah learner who needs structured tracking across one or more curricula.

The app tracks a configurable N-stage learning cycle (learn + multiple chazara stages with user-defined timing) across five Sefaria-sourced curricula: Mishnayos, Gemara Bavli, Gemara Yerushalmi, Mishna Berurah, and Chumash. It provides adaptive scheduling per curriculum, drag-and-drop learning order customization, per-curriculum goals with Hebrew or English deadlines, and account-based multi-device sync.

**Target Users:**

- **Primary (Children):** Bar mitzvah-age learners (10-13) who need daily engagement and motivation to maintain consistent learning. Child mode provides full gamification with parent-managed mystery rewards.
- **Primary (Adults):** Self-directed adult learners pursuing personal Torah learning goals across one or more curricula. Adult mode offers streamlined progress tracking with optional engagement features.
- **Secondary (Parents):** Parents of child learners who manage rewards, monitor pace, and configure tracks with minimal daily oversight.
- **Supporting (Tutors):** Tutors who need read-only visibility into learner progress to plan effective sessions. Available for both child and adult accounts.

**Multi-Curriculum Support:**

Five curricula with distinct hierarchies, all sourced from Sefaria API:

- Mishnayos: seder > masechta > perek > mishna (4,192 items)
- Gemara Bavli: masechta > daf > amud (~2,711 dapim)
- Gemara Yerushalmi: masechta > daf > halacha
- Mishna Berurah: siman > seif > seif katan (697 simanim)
- Chumash: sefer > parsha > perek > pasuk (5,845 pesukim)

**Multi-Context Learning:**

The app supports three parallel learning tracks per curriculum, all contributing to the same completion goal:

- **Personal Track (Mandatory):** AI-driven with adaptive scheduler, daily recommendations, automatic chazara scheduling
- **School Track (Optional):** Manual progress logging for formal school curriculum
- **Tutor Track (Optional):** Manual progress logging for tutoring sessions

Each track maintains its own bookmark per curriculum. Tracks can be added or removed as circumstances change. No content item can appear in multiple tracks simultaneously within the same curriculum.

### What Makes This Special

**Multi-curriculum flexibility:** A single app handles five distinct Torah curricula with independent hierarchies, scheduling, and tracking. The polymorphic content model supports new curricula without schema changes.

**Configurable learning methodology:** N-stage learning cycles with user-defined timing replace hardcoded assumptions. Each curriculum can have its own stage count, names, and intervals.

**Child + adult modes:** A single platform serves children (with gamification and parent oversight) and adults (with streamlined, self-directed features) without separate codebases or apps.

**Intelligent per-curriculum scheduling:** Independent parametric schedulers per curriculum calculate optimal daily loads based on goal deadlines, remaining items, and configurable stage timing. A cross-curriculum composer aggregates all schedules into a unified daily plan.

**Offline-first with multi-device sync:** SQLite-first architecture ensures all core features work without network. Account-based auth (email/password + Google Sign-In) with Firestore provides seamless multi-device synchronization.

**Content from Sefaria:** All curriculum content sourced from Sefaria's open API, properly attributed, with Hebrew and English text display. Content is immutable once imported; user customizations (learning order) are stored separately.

## Project Classification

**Technical Type:** mobile_app
**Domain:** edtech
**Complexity:** medium-high
**Project Context:** Greenfield - new project

This is an Android mobile application built with Flutter/Dart, targeting mid-range devices (API 21+). The app leverages offline-first architecture with SQLite local storage, cloud sync via Firebase (Auth + Cloud Firestore), local notifications, and encrypted secure storage.

The medium-high complexity reflects:

- Polymorphic content modeling across five curricula with distinct hierarchies
- Configurable N-stage learning engine replacing hardcoded 3-stage logic
- Per-curriculum parametric scheduling with cross-curriculum aggregation
- Multi-device synchronization with conflict resolution
- Dual user modes (child/adult) with conditional feature gating
- 15 feature modules with clean architecture boundaries

## Success Criteria

### User Success

**Engagement Metrics:**

- Daily app opens without external reminders
- Streak length building to multi-week and multi-month streaks
- Weekly active usage (5-6 days/week)
- Streak counter becomes something learners actively protect

**Learning Effectiveness:**

- Daily task completion rate across all active curricula
- Multi-stage completion consistency (learning + all chazara stages, not just new content)
- Chazara adherence (completing reviews on schedule per stage timing)
- Low task abandonment rate (started-but-not-completed sessions)
- Voluntary extra learning beyond daily recommendations

**Multi-Curriculum Engagement:**

- Active use of multiple curricula simultaneously
- Cross-curriculum daily plan utilization
- Balanced progress across curricula (not neglecting any active curriculum)

**Pace Achievement:**

- On-track status for each curriculum with a deadline
- Projected completion date within goal window
- Sustained completion rate over time
- Buffer maintenance (staying ahead of minimum pace)

**Parent Success (Child Accounts):**

- Child owns their journey without constant parental pushing
- Reward management takes minimal time
- Quick dashboard glances confirm on-track status

**Tutor Success:**

- Visibility into completion history helps plan effective sessions
- Chazara queue shows what needs review focus
- Real-time data keeps tutor aligned with learner progress

### Critical Success Milestones

**1 Week Mark:**

- Opening app daily?
- First streak established (7 days)?
- Completing recommended daily tasks?
- *Indicator:* Habit formation beginning

**1 Month Mark:**

- Consistent usage pattern (5-6 days/week)?
- Learning habit integrated into routine?
- Streak maintained or recovered after breaks?
- *Indicator:* Daily habit solidified

**3 Month Mark:**

- On pace for curriculum deadlines?
- Sustained engagement without motivation drop-off?
- First completed sections visible?
- *Indicator:* Long-term viability proven

### Technical Success

**Data Integrity (Non-Negotiable):**

- Zero data loss over the app's lifetime
- Immutability enforcement: once a stage is marked complete, it's locked (append-only log)
- Multi-device sync consistency: additive merge for completions, last-write-wins for mutable data
- Multi-track constraint enforcement: no duplicate completions within a curriculum
- Transaction safety: all database writes use transactions with rollback on failure

**Reliability (Critical Path):**

- Offline-first operation: all core features work without network
- Content import success: curricula download and import from Sefaria reliably
- Sync recovery: network failures don't block progress; sync recovers with retry
- State persistence: app state survives restarts, device reboots, low memory

**Performance (User Experience):**

- Smooth 60fps rendering on mid-range Android devices
- Smart scheduler calculations complete in <500ms across all active curricula
- Database queries return in <100ms even with thousands of completions
- App startup to usable state in <2 seconds

### Measurable Outcomes

**Quantitative Metrics:**

- Daily completion rate across curricula
- Streak metrics: maximum length, average length, recovery rate
- On-time completion: projected dates within goal windows
- Per-curriculum points accumulation
- Mystery reward earning rate

**Qualitative Outcomes:**

- Learning shifts from sporadic to consistent daily habit
- Large goals feel achievable rather than overwhelming
- Learner feels ownership of their progress
- Multi-curriculum engagement sustained over time

## Product Scope

### MVP - v1.0 Complete Feature Set

All features are required for v1.0 release. This is not a phased rollout.

**Foundation & Infrastructure (Epic 1):**

- Flutter project with clean architecture (15 feature modules)
- Complete database schema (SQLite via drift + Cloud Firestore)
- Multi-curriculum content import from Sefaria API
- Firebase Auth (email/password + Google Sign-In)
- auto_route navigation with auth, parent PIN, and tutor PIN guards
- Riverpod state management with family providers for curriculum scoping
- Talker logging with dio/riverpod integrations
- CI/CD pipeline (GitHub Actions)
- Sync engine (push-on-write, pull-on-launch, foreground listeners)
- Material Design 3 theme with RTL Hebrew support
- Security infrastructure (bcrypt PIN hashing, flutter_secure_storage)
- Hebrew calendar utilities (kosher_dart)

**Content Import & Browsing (Epic 2):**

- Sefaria content import pipeline for all five curricula
- Generic hierarchy browsing (works for any curriculum depth 1-4 levels)
- Content text display (Hebrew + English from Sefaria)
- Curriculum activation/deactivation management

**Core Learning Cycle (Epic 3):**

- Mark completion per stage, per track, per curriculum
- Append-only completion log with transaction safety
- Completion history with filters
- Bookmark management with automatic advancement

**Multi-Track Learning (Epic 4):**

- Track management (add/remove school/tutor tracks per curriculum)
- Track assignment with duplicate prevention
- Track-specific progress views

**Configurable Stages & Learning Order (Epic 5):**

- Stage definition configuration (add/edit/delete/reorder stages per curriculum)
- Drag-and-drop learning order customization per curriculum

**Smart Scheduler (Epic 6):**

- Parametric scheduler engine per curriculum
- Daily task generation and display
- Per-curriculum goal management with English/Hebrew deadlines
- Pace tracking (ahead/on-pace/behind)
- Cross-curriculum daily schedule composer

**Dashboard & Progress (Epic 7):**

- Cross-curriculum dashboard with summary cards, streak, daily tasks
- Per-curriculum progress views with hierarchy breakdowns
- Progress charts (completions over time, cumulative, pace trajectory)

**Gamification & Engagement (Epic 8):**

- Per-curriculum points system
- Global streak tracking
- Mystery rewards system

**Onboarding Flow (Epic 9):**

- Welcome and user mode selection (child/adult)
- Curriculum selection with content import
- Per-curriculum goal setup
- Bulk mark prior completions
- Initial rewards setup (child mode)

**Parent Mode (Epic 10):**

- PIN setup and authentication
- Parent dashboard with analytics
- Reward management (CRUD)
- Point value configuration
- Track management

**Tutor Mode (Epic 11):**

- PIN setup and authentication
- Tutor dashboard (read-only)
- Completion history and chazara views

**Notifications (Epic 12):**

- Daily learning reminders
- Streak protection alerts
- Reward milestone notifications

**Cloud Sync (Epic 13):**

- Push-on-write with offline queuing
- Pull-on-launch merge
- Foreground real-time listeners

**Settings (Epic 14):**

- General settings and user profile
- Notification preferences
- Data export/import (JSON)
- Account management (sign out, delete, password change, provider linking)

### Growth Features (Post-MVP)

- iOS version
- Dark theme
- Advanced analytics and learning insights engine
- Curriculum marketplace / user-contributed curricula
- Social features (shared progress, group learning)
- Push notification optimization
- Hebrew language UI option

## User Journeys

### Journey 1: Child Learner - From Overwhelming to "I'm Actually Doing This!"

**The Introduction**

A bar mitzvah-age child has set a goal to complete a significant Torah learning milestone. The total items feel impossibly large and abstract. Learning has been sporadic without visible progress or structured tracking. A parent introduces the app as a tool built to help them achieve their goal.

**First Open - Setting Up**

The child creates an account (with parent help) and selects child mode. Together they activate the curricula they want to track (e.g., Mishnayos). Content imports from Sefaria while they set a completion goal with a Hebrew date deadline. The parent configures the first mystery rewards. Then comes the first completion.

The child marks their first item as learned. A satisfying animation plays, points pop up on screen, and a tiny sliver of the progress bar fills. It's small, but it's *theirs*. Immediate satisfaction.

**Daily Routine Emerges**

Over the next few days, a routine develops. The dashboard greets them: "Today's Tasks: 4 new learning, 3 chazara 1, 2 chazara 2." After learning each item, they mark it complete. Each time: animation, points popup, progress bars filling, streak counter incrementing. The progress bar for the next mystery reward builds anticipation.

**The "Aha!" Moment - Days 5-7**

It's the sixth day in a row. "Current Streak: 6 days." Something clicks. "I'm actually doing this every day! I can keep going!" The overall progress shows real completion building. The thousands of items don't feel impossible anymore. The child feels ownership and pride in visible progress. The app isn't just tracking -- it's making them *want* to learn.

**The Journey Continues - Weeks and Months**

The app becomes part of daily routine. The streak becomes precious. Mystery rewards fuel continued motivation. Pace tracking shows they're ahead of schedule. Multiple sections are completing. Confidence builds toward the goal.

**This journey reveals requirements for:**

- Account-based onboarding with mode selection
- Multi-curriculum content import from Sefaria
- Configurable N-stage learning cycle with immutable completion
- Smart daily recommendations per curriculum
- Completion animations and instant feedback
- Streak tracking and visualization
- Cross-curriculum dashboard
- Mystery rewards with progress bars
- Bulk marking for prior completions

### Journey 2: Adult Learner - Structured Progress Across Curricula

**Getting Started**

An adult Torah learner wants to work through Mishnayos and Gemara Bavli simultaneously. They create an account, select adult mode, and activate both curricula. Content imports from Sefaria. They set a completion goal for Mishnayos (by next Rosh Hashana) and leave Bavli as self-paced with no deadline.

**Daily Usage**

The dashboard shows a unified daily plan: "5 tasks across 2 curricula today." Three Mishnayos items (1 new, 2 chazara) and two Bavli items (both new). The interface is clean and focused -- no mystery rewards or celebrations, just clear progress tracking. They mark items as completed throughout the day, sometimes from their phone, sometimes from their tablet (multi-device sync).

**Customization**

After a few weeks, they adjust the chazara timing for Bavli (adding a third chazara stage at +30 days for deeper retention) and reorganize the masechta learning order via drag-and-drop. The scheduler adapts automatically.

**Long-Term Value**

Months later, the per-curriculum progress views show substantial completion. The Mishnayos pace indicator shows they're 5 days ahead of the Rosh Hashana deadline. Bavli is progressing steadily without deadline pressure. The app has transformed their learning from sporadic to systematic.

**This journey reveals requirements for:**

- Adult mode with streamlined UI (minimal gamification)
- Multiple curricula activated simultaneously
- Per-curriculum goal management (with and without deadlines)
- Cross-curriculum daily schedule composer
- Configurable stage definitions per curriculum
- Drag-and-drop learning order
- Multi-device sync
- Per-curriculum progress views with pace tracking

### Journey 3: Parents - Hands-Off Oversight

**Setup**

The parent helps their child create an account in child mode. They set a 4-digit parent PIN, configure the initial mystery rewards catalog, review the learning order defaults, and set the bar mitzvah date as the goal deadline. Everything is ready.

**Ongoing**

Every few weeks, the parent logs into parent mode to add another reward. It takes less than 2 minutes. They set the point threshold, write a title, and save. They don't micromanage daily learning.

**Occasional Check-Ins**

About once a week, the parent glances at the parent dashboard: on-track status, overall completion percentage, current streak. The check takes 30 seconds. No intervention needed.

**Reward Moments**

A notification appears: "Mystery reward earned!" The parent reveals the surprise to the child. Minimal effort, maximum impact.

**This journey reveals requirements for:**

- PIN-protected parent mode (child accounts only)
- Reward catalog management (CRUD)
- Parent analytics dashboard (pace, completion %, streak)
- Track management (add/remove school/tutor tracks)
- Point value configuration per stage per curriculum
- Notification for reward milestones
- Minimal-time-investment UX design

### Journey 4: Tutor - Teaching with Visibility

**Getting Access**

The tutor receives a separate 4-digit PIN from the student (or parent). Tutor mode provides read-only access to all progress data. Available for both child and adult accounts.

**Pre-Session Check**

Before each session, the tutor logs into tutor mode and reviews: which items have been completed since last session, what's due for chazara, and overall pace status. This takes 3-4 minutes and transforms how sessions are planned.

**Session Focus**

During the session, the tutor uses progress data to focus on items due for review rather than just pushing forward. The app's data shows exactly where to focus.

**This journey reveals requirements for:**

- Separate PIN-protected tutor mode (any account type)
- Read-only access enforcement
- Completion history with timestamps
- Chazara queue visibility
- On-track status and overall progress metrics
- Progress breakdowns by curriculum hierarchy

## Mobile App Specific Requirements

### Technical Architecture

**Cross-Platform Framework with Single-Platform Deployment:**

- **Framework:** Flutter/Dart (cross-platform codebase)
- **v1.0 Target:** Android only (API level 21+ / Android 5.0 Lollipop+)
- **Future Expansion:** iOS deferred to post-v1.0

**Performance Targets:**

- 60fps rendering on mid-range Android devices
- Sub-2-second startup to usable state
- Sub-500ms scheduler calculations across all active curricula
- Sub-100ms database queries with thousands of completion records
- Minimal battery drain from sync operations

### Platform Requirements

**Android:**

- Minimum SDK: API 21 (Android 5.0 Lollipop)
- Target SDK: Latest stable Android version
- Device classes: Mid-range phones and tablets
- Screen support: 5" phones to 10" tablets
- Orientation: Portrait primary, landscape supported for progress views

**Distribution:**

- v1.0: Direct APK installation (sideloading)
- Future: Google Play Store distribution

### Device Permissions

**Required:**

- **Storage:** SQLite database, secure PIN storage, app data
- **Notifications:** Local scheduled notifications (Android 13+ runtime permission)
- **Network (Optional):** Firebase sync, Sefaria API content fetching

**Not Required:**

- Camera, Location, Contacts, Microphone, Biometrics, Phone state, SMS, Calendar access

### Offline Mode

**Offline-First Architecture:**

- SQLite is source of truth (local database is canonical, not Firebase)
- All core features work without network: browse content, mark completions, view progress, smart scheduler, streak tracking, parent/tutor modes
- Network required for: first-time content import from Sefaria, multi-device sync, new-device data restore

**Sync Strategy:**

- Push-on-write: local writes trigger async Firestore push (queued if offline)
- Pull-on-launch: app startup pulls latest from Firestore and merges with local
- Foreground listeners: real-time Firestore listeners while app is active
- Conflict resolution: additive merge for completions (append-only), last-write-wins with UTC timestamps for mutable data

### Push Strategy

**Local Notifications Only (No Cloud Messaging):**

- Library: `flutter_local_notifications`
- All notifications generated and scheduled locally on device

**Notification Types:**

- **Daily Learning Reminder:** Configurable time (default 7:00 PM), "You have X tasks across Y curricula today"
- **Streak Protection Alert:** If no learning by 9:00 PM and active streak exists, "Your X-day streak is at risk!"
- **Reward Earned:** Instant when point threshold crossed, "Mystery reward earned!"
- **Shabbos/Yom Tov quiet mode:** Suppress notifications during Shabbos (configurable)

### Store Compliance

**v1.0 - Direct APK Distribution:**

- No Play Store compliance required
- Valid signing certificate, app icon, standard Android manifest

**Future - Google Play Store:**

- Privacy policy, terms of service, age rating
- COPPA compliance if targeting children
- Data deletion capability (GDPR)
- Firebase Crashlytics for production monitoring

## Functional Requirements

### Content & Curriculum Management

- FR1: System provides five curricula (Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash) sourced from Sefaria API
- FR2: Users browse curriculum content hierarchically through up to 4 levels of generic hierarchy
- FR3: Users view content text in Hebrew and English from Sefaria
- FR4: System attributes content to Sefaria API source
- FR5: Users activate and deactivate curricula at any time without losing progress data
- FR6: All curriculum content (hierarchy and text in all available languages) is bundled with the app at build time — no runtime downloading or importing. Content updates ship with app updates.
- FR7: System populates curriculum hierarchy configuration (level labels and depth) per curriculum

### Multi-Track Learning Management

- FR8: Users manage up to 3 learning tracks per curriculum (personal mandatory, school/tutor optional)
- FR9: Users add or remove optional tracks per curriculum as circumstances change
- FR10: System maintains separate bookmarks per track per curriculum
- FR11: System prevents the same content item's stage from being completed under multiple tracks within a curriculum
- FR12: Users designate which track a completion belongs to (auto-assigned if only personal active)

### Configurable N-Stage Learning Cycle

- FR13: Users mark a content item as completed for a specific stage within a specific track
- FR14: System enforces stage progression (must complete stage N before stage N+1 for same item)
- FR15: System enforces immutability (completed stages cannot be unmarked, append-only log)
- FR15b: System permanently tracks the total number of times each content item has been learned and reviewed. Every completion (initial learning and every subsequent chazara round) is recorded in the append-only log. Users can see the full review count per item (e.g., "Shabbos Daf 5a — learned 1x, reviewed 10x"). This count persists forever and survives track deletion, scope changes, and curriculum deactivation.
- FR16: System awards configurable points per stage per curriculum on completion
- FR17: System advances bookmark to next item in learning order on first-stage completion
- FR18: System syncs completions to Firestore via push-on-write
- FR19: Users bulk-mark multiple items as completed for a stage in one action
- FR20: System maintains transaction safety (completion + bookmark update + points in single transaction)

### Stage Configuration

- FR21: Users customize learning stages per curriculum (add, edit, delete, reorder stages)
- FR22: System provides default stages for all curricula (learn/0 days, chazara 1/+1 day, chazara 2/+7 days)
- FR23: "Learn" stage (stage_order=1, delay_days=0) cannot be deleted
- FR24: Stage changes apply to future scheduling only (existing completions unaffected)
- FR25: Users reset stages to defaults per curriculum
- FR26: System syncs stage definitions to Firestore per curriculum

### Learning Order

- FR27: Users customize content item learning order per curriculum via drag-and-drop
- FR28: Default order uses natural Sefaria order (content_items.sort_order)
- FR29: Users reset learning order to default (deletes custom ordering)
- FR30: Scheduler and bookmark advancement respect custom learning order

### Smart Scheduling & Recommendations

- FR31: System generates daily task recommendations per curriculum based on stage definitions, learning order, goal deadline, and current progress
- FR32: System adapts daily load when learner falls behind or accelerates ahead
- FR33: System balances new learning with chazara load to prevent pile-up
- FR34: System schedules chazara tasks based on configurable delay_days per stage
- FR35: System composes cross-curriculum daily plan from all active curriculum schedules
- FR36: System enforces total daily load cap (configurable max tasks per day)
- FR37: Scheduler runs for personal track only (school/tutor tracks are externally paced)

### Goal Management

- FR38: Users set per-curriculum completion goals using one of two modes:
  - **Deadline mode:** Target completion date (English or Hebrew calendar). Scheduler calculates daily load automatically.
  - **Pace mode:** User-defined pace (e.g., 1 daf/day, 1 amud/day, 5 amudim/week). Scheduler follows the specified pace. App calculates and displays projected completion date.
- FR39: Users set target dates using English or Hebrew calendar (deadline mode)
- FR40: Users set multiple goals per curriculum (e.g., section-level deadlines)
- FR41: Users modify or remove goals at any time
- FR42: System tracks pace per goal (ahead/on-pace/behind with projected completion date)
- FR43: Users learn without deadlines (no-deadline mode with chazara-only recommendations)
- FR43b: Users configure study day schedules per curriculum:
  - Designate which days of the week are for **new learning** (e.g., Sunday–Thursday)
  - Designate which days are for **review/chazara only** (e.g., Friday & Shabbos)
  - Scheduler only assigns new learning tasks on study days and chazara tasks on review days
  - Fully configurable — any combination of days allowed

### Progress Tracking & Visualization

- FR44: Users view cross-curriculum dashboard with summary cards for all active curricula
- FR45: Users view per-curriculum progress with hierarchy-level breakdowns
- FR46: Users view which track contributed each completion
- FR47: Users view pace status per curriculum (days ahead/on-pace/behind)
- FR48: Users view projected completion date based on current pace
- FR49: Users view completion history over time with filters (curriculum, track, stage, date range)
- FR49b: Users view per-item review counts showing how many times each content item has been learned and reviewed (e.g., "learned 1x, reviewed 10x"). This is a permanent, lifetime count derived from the append-only completion log.
- FR50: Users view completions-over-time charts and cumulative progress
- FR51: Users view streak calendar highlighting days with learning activity

### Gamification & Motivation

- FR52: System accumulates points per curriculum from stage completions (configurable values)
- FR53: System tracks global streak (consecutive days with any curriculum completion)
- FR54: Users view current streak and max streak
- FR55: System displays mystery rewards with progress bars showing points needed
- FR56: System notifies when mystery reward point threshold reached
- FR57: Parents reveal mystery reward details when earned (child mode)
- FR58: Adults manage their own rewards (adult mode)
- FR59: Child mode displays full gamification (animations, celebrations); adult mode displays minimal or optional

### Parent Mode (Child Accounts Only)

- FR60: Parents access PIN-protected parent mode (4-digit PIN, bcrypt-hashed, device-local)
- FR61: Parents manage mystery reward catalog (add/edit/delete rewards with point thresholds)
- FR62: Parents configure point values per stage per curriculum
- FR63: Parents add or remove school/tutor tracks per curriculum
- FR64: Parents view analytics dashboard (on-track status, completion %, streak, recent completions)
- FR65: Parents view detailed progress and engagement metrics
- FR66: Parent mode locks out after 5 failed PIN attempts with cooldown
- FR67: Parent mode not available for adult accounts

### Tutor Mode (Any Account)

- FR68: Tutors access PIN-protected tutor mode (separate 4-digit PIN, device-local)
- FR69: Tutor mode is read-only (no data modification)
- FR70: Tutors view completion history with timestamps
- FR71: Tutors view items due for chazara review, grouped by urgency
- FR72: Tutors view on-track status and progress metrics per curriculum
- FR73: Tutors view schedule recommendations (read-only daily task view)
- FR74: Tutor mode available for both child and adult accounts

### Onboarding & Setup

- FR75: Users create accounts with email/password or Google Sign-In
- FR76: Users select child mode or adult mode during onboarding
- FR77: Users select which curricula to activate (minimum one required)
- FR78: Users set per-curriculum goals with deadlines during onboarding (skippable)
- FR79: Users bulk-mark previously completed content during onboarding
- FR80: Parents configure initial mystery rewards during child account onboarding
- FR81: User mode changeable later from settings

### Notifications & Reminders

- FR82: Users receive daily learning reminders at configurable time (default 7:00 PM)
- FR83: Users receive streak protection alert if no learning by configurable time (default 9:00 PM)
- FR84: Users receive instant notification when mystery reward earned
- FR85: Users enable/disable each notification type independently
- FR86: Users configure notification times
- FR87: System suppresses notifications during Shabbos/Yom Tov (configurable)

### Offline & Data Management

- FR88: Users access all core features without network connectivity (offline-first)
- FR89: System pushes local writes to Firestore asynchronously (queued if offline)
- FR90: System pulls latest data from Firestore on app launch and merges with local
- FR91: System maintains real-time Firestore listeners while app is in foreground
- FR92: System resolves conflicts: additive merge for completions, last-write-wins for mutable data
- FR93: System retries failed syncs with exponential backoff
- FR94: System restores full state from Firestore on new device sign-in
- FR95: Users export progress data to JSON for backup
- FR96: Users import progress data from JSON backup file

### Security & Access Control

- FR97: System encrypts and stores parent PIN using flutter_secure_storage with bcrypt hashing
- FR98: System encrypts and stores tutor PIN separately from parent PIN
- FR99: PINs are device-local only (never synced to Firestore)
- FR100: System enforces view-only permissions for tutor mode
- FR101: System locks out after 5 failed PIN attempts with configurable cooldown

### Account Management

- FR102: Users sign out (local session cleared, data preserved for re-sign-in)
- FR103: Users delete account (Firestore data deleted, Firebase Auth account deleted, local data cleared)
- FR104: Users change password (email/password accounts)
- FR105: Users link additional auth providers (e.g., add Google Sign-In to email account)

### Calendar & Date Management

- FR106: System calculates Hebrew calendar dates using kosher_dart
- FR107: System supports English and Hebrew date pickers for goal deadlines
- FR108: System stores all dates/times as UTC, converts in presentation layer only
- FR109: System uses local timezone for streak day boundary

### Completion Feedback

- FR110: Users see completion animations when marking stages complete (scaled by user mode)
- FR111: Users see points popup when earning points (child mode: celebratory, adult mode: subtle/none)
- FR112: Users see progress bars fill incrementally with each completion
- FR113: Users see streak counter increment with daily activity

## Non-Functional Requirements

### Performance

- NFR1: App startup to usable state within 2 seconds on mid-range Android devices
- NFR2: Smart scheduler calculations complete within 500ms across all active curricula
- NFR3: Database queries return within 100ms even with thousands of completion records
- NFR4: User actions (mark complete, navigate, view progress) respond within 200ms
- NFR5: UI maintains 60fps during scrolling, animations, and transitions on mid-range devices
- NFR6: Progress bar animations render smoothly without frame drops
- NFR7: List scrolling (content browsing) maintains consistent 60fps
- NFR8: Background sync operations minimize battery drain (<2% daily battery impact)
- NFR9: App memory footprint does not exceed 150MB during normal operation
- NFR10: Content import completes within reasonable time on typical mobile network

### Reliability & Data Integrity

- NFR11: Zero data loss over the app's lifetime
- NFR12: Completion log maintains integrity through device reboots, crashes, and low-memory situations
- NFR13: SQLite transactions use automatic rollback on failure
- NFR14: App state survives device restarts without loss of unsynchronized data
- NFR15: Crash-free rate exceeds 99.9%
- NFR16: All errors handled gracefully with user-friendly messages
- NFR17: Network errors do not cause crashes or data corruption
- NFR18: Content import is idempotent and can recover from interruption
- NFR19: Sync retries failed operations with exponential backoff (max 5 retries)
- NFR20: Sync conflicts resolve consistently (additive for completions, last-write-wins for mutable)
- NFR21: Firebase quota limits monitored with graceful degradation

### Offline Capability

- NFR22: All core features (browse, mark complete, view progress, scheduler) work without network
- NFR23: Offline operation provides identical user experience to online for core features
- NFR24: Local SQLite database serves as source of truth
- NFR25: Background sync operates battery-efficiently without blocking user actions
- NFR26: Network connectivity restoration triggers sync automatically
- NFR27: Sync respects Android battery saver mode

### Security & Privacy

- NFR28: Parent and tutor PINs encrypted with bcrypt and stored via flutter_secure_storage
- NFR29: PINs are device-local only (never transmitted or synced)
- NFR30: PIN authentication locks out after 5 failed attempts with cooldown
- NFR31: All Firebase communication uses HTTPS/TLS
- NFR32: Firestore security rules prevent unauthorized access, scoped by user UID
- NFR33: Local data stored in app-private directory
- NFR34: Tutor mode enforces view-only access (no data modification)
- NFR35: Account deletion removes all Firestore user data

### Integration & Compatibility

- NFR36: Sefaria API integration handles failures gracefully with retry
- NFR37: Hebrew calendar calculations verified against authoritative sources
- NFR38: Firebase operations handle network timeouts gracefully
- NFR39: App supports Android API 21+ (Lollipop and above)
- NFR40: App functions correctly on screen sizes from 5" phones to 10" tablets
- NFR41: App supports portrait and landscape orientations
- NFR42: Hebrew text renders correctly with RTL layout
- NFR43: Bidirectional text (Hebrew + English) displays properly
- NFR44: Hebrew fonts render clearly on all supported devices

### Accessibility (Baseline)

- NFR45: Touch targets meet minimum 48dp size
- NFR46: Color contrast ratios meet WCAG AA standards
- NFR47: UI provides semantic structure for future screen reader support
