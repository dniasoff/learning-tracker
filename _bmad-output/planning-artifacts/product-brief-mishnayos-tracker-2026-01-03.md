---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments:
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/epics.md'
date: 2026-02-08
author: Daniel
version: v2
previousVersion: v1 (2026-01-03)
---

# Product Brief: Learning Tracker

## Executive Summary

**Learning Tracker** (formerly Mishnayos Tracker) is an Android app for tracking Torah learning across multiple curricula with configurable review cycles, intelligent scheduling, and balanced motivation. The app supports both children and adults, transforming large-scale learning goals into achievable daily habits through structured stage-based tracking, cross-curriculum progress dashboards, and account-based multi-device sync.

The app tracks a configurable N-stage learning cycle (learn + multiple chazara stages with user-defined timing) across five Sefaria-sourced curricula: Mishnayos, Gemara Bavli, Gemara Yerushalmi, Mishna Berurah, and Chumash. It provides adaptive scheduling per curriculum, drag-and-drop learning order customization, and per-curriculum goals with Hebrew or Gregorian deadlines.

Built initially as a father-son bar mitzvah project, Learning Tracker has expanded in scope to serve any Torah learner. Child mode provides full gamification with parent-managed mystery rewards, while adult mode offers a streamlined, self-directed experience with optional engagement features.

---

## Core Vision

### Problem Statement

Torah learners at all levels face the challenge of maintaining consistent daily learning across one or more curricula over months or years. Without structured tracking, learning becomes sporadic, review cycles (chazara) get skipped, and large goals feel overwhelming rather than achievable. Existing tools are either generic habit trackers that don't understand Torah learning methodology, or they lack the multi-curriculum flexibility and intelligent scheduling needed for serious learners.

### Problem Impact

**Without consistent tracking and motivation:**

- Daily learning becomes sporadic, making long-term goals unrealistic
- Learners can't see progress across curricula, leading to discouragement
- No visibility into whether pace supports completion by a target date
- Proper review cycles (chazara) get skipped, undermining retention
- Multiple curricula compound the complexity of staying organized
- Children lose motivation without engagement features; adults lack clear progress metrics
- Multi-device learners have no way to keep progress synchronized

### Why Existing Solutions Fall Short

**Generic habit trackers** lack the structure needed for Torah learning. They don't understand multi-stage learning cycles, hierarchical content organization (seder/masechta/perek/mishna), or curriculum-specific scheduling. They treat all habits equally rather than supporting the unique methodology of Torah study.

**Paper and spreadsheet tracking** doesn't provide the immediate satisfaction of visible progress, adaptive scheduling, or the motivational elements that maintain engagement over years. It also can't sync across devices or provide intelligent chazara scheduling.

**Existing Jewish learning apps** (where they exist) are typically single-curriculum tools without configurable stages, multi-track support, or intelligent scheduling that adapts to individual pace.

### Proposed Solution

**Learning Tracker** is a multi-curriculum Torah learning platform that:

**Multi-Curriculum Content (via Sefaria API):**

- Mishnayos: seder > masechta > perek > mishna (4,192 items)
- Gemara Bavli: masechta > daf > amud (~2,711 dapim)
- Gemara Yerushalmi: masechta > daf > halacha
- Mishna Berurah: siman > seif > seif katan (697 simanim)
- Chumash: sefer > parsha > perek > pasuk (5,845 pesukim)
- Each curriculum independently browseable with Hebrew + English text
- Activate/deactivate curricula at any time without losing data

**Configurable N-Stage Learning Cycle:**

- Default: learn > chazara 1 (+1 day) > chazara 2 (+7 days)
- Users customize stage count, names, and timing intervals per curriculum
- Immutable, append-only completion log preserves all progress
- Automatic chazara scheduling based on configurable timing rules

**Smart Adaptive Scheduling (Per-Curriculum):**

- Independent scheduler per curriculum with configurable parameters
- Calculates optimal daily recommendations based on goal deadline and remaining items
- Adapts when learner falls behind or accelerates ahead
- Balances new learning with chazara load to prevent pile-up
- Cross-curriculum daily schedule composer aggregates all curricula into a unified daily plan

**Multi-Track Learning (Per-Curriculum):**

- Personal track (mandatory): AI-driven with adaptive scheduler
- School track (optional): Manual progress logging for formal curriculum
- Tutor track (optional): Manual progress logging for tutoring sessions
- Each track maintains its own bookmark per curriculum
- Duplicate prevention within each curriculum's track system

**Child + Adult Modes:**

- Child mode: Full gamification, parent oversight, age-appropriate presentation
- Adult mode: Self-directed, minimal gamification, optional engagement features
- Tutor mode: Optional read-only access for any user type
- Parent mode: Available only for child accounts

**Per-Curriculum Goals & Deadlines:**

- Set target completion date using Gregorian or Hebrew calendar
- Hebrew date picker for bar mitzvah dates and Jewish milestones
- Multiple goals per curriculum (e.g., "finish Seder Zeraim by Pesach")
- No-deadline mode for self-paced learners
- Pace tracking with projected completion date

**Drag-and-Drop Learning Order:**

- Customize the sequence of units within each curriculum
- Default order follows natural Sefaria sequence
- Reset to default at any time

**Account-Based Multi-Device Sync:**

- Email/password + Google Sign-In authentication
- Real-time Firestore sync with offline queuing
- Seamless new-device setup (sign in, full data restored)
- SQLite local source of truth with Firestore as shared cloud source

**Progress & Dashboard:**

- Cross-curriculum dashboard with all active curricula
- Per-curriculum progress views with hierarchy-level breakdowns
- Completions over time charts, cumulative progress, pace trajectory
- Streak tracking (global: any curriculum counts)
- Per-curriculum points accumulation

**Gamification & Engagement:**

- Points per curriculum (configurable per stage)
- Global streak tracking (consecutive days of any learning)
- Mystery rewards system (parent-managed for children, self-managed for adults)
- Completion animations and feedback (scaled by user mode)

### Key Differentiators

**Multi-curriculum flexibility:** A single app handles five distinct Torah curricula with independent hierarchies, scheduling, and tracking. Adding a new curriculum doesn't require schema changes.

**Configurable learning methodology:** N-stage learning cycles with user-defined timing replace hardcoded assumptions. Each curriculum can have its own stage configuration.

**Child + adult modes:** A single platform serves both children (with gamification and parent oversight) and adults (with streamlined, self-directed features), without separate apps.

**Intelligent per-curriculum scheduling:** Independent parametric schedulers per curriculum, aggregated into a unified daily plan. The scheduler adapts to configurable stage definitions, not hardcoded logic.

**Offline-first with multi-device sync:** SQLite-first architecture ensures all features work offline. Account-based auth with Firestore provides seamless multi-device synchronization.

**Content from Sefaria:** All curriculum content sourced from Sefaria's open API, properly attributed, with Hebrew and English text display.

---

## Target Users

### Primary User: Torah Learners (Children)

**Persona: Bar Mitzvah-Age Child (e.g., 10-13 years old)**

A tech-savvy child preparing for bar mitzvah or pursuing a structured Torah learning goal. Needs daily engagement and motivation to maintain consistent learning across one or more curricula over months or years.

**Context & Challenges:**

- Learning across multiple contexts (personal, school, tutor)
- Finds large numbers (thousands of items) overwhelming
- Needs visible progress and reward systems to stay motivated
- Inconsistent without structured tracking and reminders

**Success Vision:**

- Opens the app daily without prompting
- Streak counter becomes something to protect
- Large goals feel achievable through visible daily progress
- Mystery rewards maintain long-term motivation

### Primary User: Torah Learners (Adults)

**Persona: Self-Directed Adult Learner**

An adult pursuing personal Torah learning goals, potentially across multiple curricula. Prefers a streamlined experience focused on progress tracking and scheduling without heavy gamification.

**Context & Challenges:**

- Balancing Torah learning with work and family obligations
- May be learning multiple curricula simultaneously
- Needs intelligent scheduling to stay on pace for self-set goals
- Wants progress visibility without childish engagement features

**Success Vision:**

- Clear daily task list across all active curricula
- Pace tracking shows projected completion dates
- Chazara scheduling prevents review from falling behind
- Multi-device sync lets them learn from any device

### Secondary Users: Parents

**Persona: Parent of a Child Learner**

A parent supporting their child's Torah learning journey with minimal daily oversight. Manages rewards, monitors pace, and configures tracks.

**Role & Involvement:**

- Sets up initial rewards catalog and learning configuration
- Occasional dashboard monitoring (weekly or less)
- Manages school and tutor tracks as circumstances change
- Reveals earned mystery rewards

**Success Vision:**

- Child owns their learning journey without constant pushing
- Quick dashboard glances confirm on-track status
- Reward management takes minimal time

### Supporting User: Tutor

**Persona: Learning Tutor/Rebbe**

A tutor who needs visibility into student progress to plan effective teaching sessions. Available for both child and adult learners.

**Role & Needs:**

- Read-only access to completion history and chazara status
- Views which items are due for review to focus sessions
- Monitors overall pace across curricula

**Success Vision:**

- Can quickly see what the student has completed since last session
- Knows which items need chazara focus
- Uses progress data to plan effective sessions

### User Journey

**Discovery & Onboarding:**

1. **Account creation:** Sign up with email/password or Google Sign-In
2. **Mode selection:** Choose child mode or adult mode
3. **Curriculum selection:** Activate one or more of five available curricula
4. **Content import:** Selected curricula download from Sefaria API
5. **Goal setup:** Set per-curriculum completion goals with deadlines (optional)
6. **Bulk mark (optional):** Mark previously completed content
7. **Rewards setup (child mode):** Parent configures initial mystery rewards

**Daily Usage:**

1. Open app to cross-curriculum dashboard
2. View daily tasks across all active curricula
3. Complete learning and chazara tasks, marking progress
4. Watch progress bars fill, streak increment, points accumulate
5. Earn mystery rewards at point thresholds

**Long-Term Integration:**

- App becomes part of daily routine
- Per-curriculum progress views show mastery building over time
- Adaptive scheduling adjusts to maintain pace for each goal
- Multi-device sync allows learning from any device

---

## Success Metrics

### User Success Metrics

**1. Engagement - "They use it"**

- Daily app opens without external reminders
- Streak length (target: multi-week and multi-month streaks)
- Weekly active usage (5-6 days/week)

**2. Learning Effectiveness - "It helps them learn"**

- Daily task completion rate across curricula
- Multi-stage completion consistency (not just learning, but completing chazara cycles)
- Chazara adherence (completing reviews on schedule)

**3. Pace Achievement - "They reach their goals"**

- On-track status for each curriculum with a deadline
- Projected completion date within goal window
- Sustained completion rate over time

**4. Multi-Curriculum Engagement - "They use multiple curricula"**

- Number of active curricula per user
- Cross-curriculum daily plan utilization
- Balanced progress across curricula (not neglecting any)

### Key Performance Indicators

**1 Week Mark:**

- Still opening app daily?
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

### What "Winning" Looks Like

1. Learner opens the app daily without being asked
2. Streak counter becomes something they actively protect
3. On pace (or ahead) for all curriculum deadlines
4. Large goals feel achievable through visible daily progress
5. Multi-stage learning cycle (learn + chazara) consistently followed
6. Daily Torah learning habit established for the long term

### What "Failing" Looks Like

1. Learner stops using the app after initial excitement (week 2-4 drop-off)
2. Usage requires constant external reminders
3. Falls significantly behind pace with no recovery
4. Chazara cycles skipped (learning without retention)
5. Multiple curricula activated but only one used

---

## MVP Scope

### Core Features (v1.0 - Full Release)

**1. Multi-Curriculum Content (Sefaria API)**

- Five curricula with distinct hierarchies (Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash)
- Hierarchical browsing with Hebrew + English text display
- Activate/deactivate curricula without data loss
- Content import with progress indicators

**2. Configurable N-Stage Learning Cycle**

- Default stages: learn > chazara 1 (+1 day) > chazara 2 (+7 days)
- User-customizable stage count, names, and timing per curriculum
- Immutable, append-only completion log
- Automatic chazara scheduling based on stage timing

**3. Multi-Track Learning (Per-Curriculum)**

- Personal track (mandatory) with AI-driven scheduling
- Optional school and tutor tracks with manual logging
- Per-track bookmarks per curriculum
- Duplicate prevention within each curriculum

**4. Smart Adaptive Scheduler (Per-Curriculum)**

- Per-curriculum scheduling based on goal deadline and stage definitions
- Adaptive pacing (adjusts when behind or ahead)
- Chazara pile-up management
- Cross-curriculum daily schedule composer

**5. Per-Curriculum Goals & Deadlines**

- Gregorian and Hebrew date pickers
- Multiple goals per curriculum
- No-deadline mode for self-paced learning
- Pace tracking with projected completion date

**6. Drag-and-Drop Learning Order**

- Customizable unit sequence per curriculum
- Default follows natural Sefaria order
- Reset to default option

**7. Cross-Curriculum Dashboard & Progress**

- Dashboard with curriculum summary cards, streak, daily tasks
- Per-curriculum progress views with hierarchy breakdowns
- Charts: completions over time, cumulative progress, pace trajectory
- Streak calendar view

**8. Gamification & Engagement**

- Per-curriculum points accumulation
- Global streak tracking
- Mystery rewards system (parent-managed for children, self-managed for adults)
- Completion animations scaled by user mode

**9. Child + Adult Modes**

- Child mode: full gamification, parent mode available
- Adult mode: streamlined, optional engagement features
- Mode selection during onboarding, changeable later

**10. Parent Mode (PIN-Protected, Child Accounts Only)**

- Reward catalog management (CRUD)
- Analytics dashboard with pace and engagement metrics
- Point value configuration per stage per curriculum
- Track management (add/remove school/tutor tracks)

**11. Tutor Mode (PIN-Protected, Any Account)**

- Read-only access to completion history and chazara status
- Progress breakdowns by curriculum hierarchy
- Schedule recommendations (read-only view)

**12. Account-Based Multi-Device Sync**

- Email/password + Google Sign-In
- Push-on-write, pull-on-launch, foreground real-time listeners
- Offline queue with persistent retry
- Sync status indicator in UI

**13. Notifications**

- Daily learning reminders (configurable time)
- Streak protection alerts
- Reward milestone notifications
- Shabbos/Yom Tov quiet mode

**14. Settings & Data Management**

- Account management (sign out, delete account, change password)
- Notification preferences
- Data export/import (JSON)
- Font size, theme, and general preferences

### Out of Scope (v1.0)

- iOS version (Android only for v1.0)
- Dark theme (light only for v1.0)
- Push notifications via cloud messaging (local only)
- Social features, leaderboards, or community sharing
- Audio playback of texts
- Study notes or annotations
- User-contributed curricula

### MVP Success Criteria

**v1.0 succeeds if:**

1. **Week 1:** Learner uses the app daily without prompting
2. **Month 1:** Daily habit established (5-6 days/week minimum)
3. **Month 3:** Sustained engagement, on-track for curriculum deadlines
4. **Technical:** Zero data loss, reliable sync, sub-500ms scheduling

### Future Vision (Post-v1.0)

**Potential Enhancements:**

- iOS version
- Dark theme
- Advanced analytics and learning insights
- Curriculum marketplace / user-contributed curricula
- Social features (shared progress, group learning)
- Push notification optimization
- Hebrew language UI option
