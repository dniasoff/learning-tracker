---
stepsCompleted: [1, 2, 3, 4, 7, 9, 10, 11]
inputDocuments:
  - '_bmad-output/planning-artifacts/product-brief-mishnayos-tracker-2026-01-03.md'
  - '_bmad-output/implementation-artifacts/tech-spec-mishnayos-tracker-v1-complete.md'
briefCount: 1
researchCount: 0
brainstormingCount: 0
projectDocsCount: 0
techSpecCount: 1
workflowType: 'prd'
lastStep: 11
completedAt: '2026-01-04'
status: 'complete'
date: 2026-01-03
author: Daniel
---

# Product Requirements Document - mishnayos-tracker

**Author:** Daniel
**Date:** 2026-01-03

## Executive Summary

**Mishnayos Tracker** is a personalized Android app designed to help Yisroel Meir Niasoff (10 years old) complete all 4,192 Mishnayos by his bar mitzvah on 19 Kislev, 5789 (December 7, 2028) through intelligent daily tracking, visual progress, and balanced motivation. The app transforms an overwhelming 3-year learning goal into an achievable daily habit by tracking the complete 3-stage learning cycle (learn + 2x chazara), providing adaptive scheduling, and rewarding consistency while respecting the seriousness of Torah learning.

Built as a deeply personal father-son project, the app creates emotional connection by being specifically designed for Yisroel Meir's unique journey. It addresses the core problem of inconsistent learning without a tracking system - where forgetting becomes habitual, proper review cycles get skipped, and the enormous total (4,192) remains abstract and intimidating rather than achievable.

**Target Users:**
- **Primary:** Yisroel Meir Niasoff (10-year-old, tech-savvy, preparing for bar mitzvah)
- **Secondary:** Parents (shared login, hands-off monitoring, bulk management capabilities)
- **Supporting:** Tutor (view-only progress access, aligns teaching sessions)

**Multi-Context Learning:**
The app supports three parallel learning contexts that all contribute to the same 4,192 completion goal:
- **Personal Track (Mandatory):** AI-driven with adaptive scheduler, daily recommendations, automatic chazara scheduling
- **School Track (Optional):** Manual progress logging for formal school curriculum
- **Tutor Track (Optional):** Manual progress logging for tutoring sessions

Each track maintains its own bookmark ("where he's up to"), tracks can be added or removed as circumstances change, and no Mishna can appear in multiple tracks simultaneously. This flexible architecture accommodates the reality that a 10-year-old learns in multiple contexts while maintaining one unified goal.

### What Makes This Special

**Personal over generic:** Built as a father for his son's specific bar mitzvah journey, creating emotional connection and meaning beyond a corporate app. The personalization (his name, his date, his journey) makes Yisroel Meir feel this was created specifically for him.

**Proper Torah learning methodology:** Tracks the complete 3-stage learning cycle (learn + chazara next day + chazara 2 after 7 days) that reflects authentic Torah study practices, not just simplistic "done/not done" checkboxes found in generic habit trackers.

**Adaptive intelligence:** The smart scheduler calculates optimal daily recommendations based on the bar mitzvah deadline, automatically adjusts when he falls behind or accelerates ahead, and intelligently balances new learning with chazara pile-up to ensure on-time completion.

**Balanced gamification:** Respectfully engages a 10-year-old through progress visualization, points, and mystery rewards while maintaining the dignity and seriousness of Torah learning - neither frivolous nor boring.

**Multi-context reality:** Recognizes that learning happens in school, with tutors, and personally - providing flexible tracking across all contexts while maintaining one unified completion goal with intelligent recommendations only for personal study.

**Complete Mishnayos structure:** Properly organized database of all 4,192 Mishnayos by seder/masechta/perek with immutable progress tracking (once complete, locked forever) and bulk management for initial onboarding.

**Cloud-first with offline-first:** Firebase backend provides automatic backup, seamless device transfer, and parent account recovery, while SQLite local database ensures the app works smoothly offline with background sync when connected.

## Project Classification

**Technical Type:** mobile_app
**Domain:** edtech
**Complexity:** medium
**Project Context:** Greenfield - new project

This is an Android mobile application built with Flutter/Dart, leveraging device features including push notifications, offline-first operation with SQLite local storage, and cloud sync via Firebase. The offline capability is critical for daily usage reliability, while cloud backup provides safety and device portability.

The educational domain focuses on student learning progress tracking across multiple learning contexts (personal, school, tutor), implementing proper pedagogical methodology (spaced repetition via the 3-stage chazara cycle), and age-appropriate engagement for a 10-year-old user. The medium complexity reflects educational content management and learning methodology implementation, though regulatory requirements (COPPA/FERPA) don't apply since this is private personal use for one child, not a commercial educational platform.

The multi-track architecture accommodates real-world learning scenarios where students engage with the same curriculum across different contexts, while the adaptive scheduler provides intelligent pacing unique to mobile learning applications.

## Success Criteria

### User Success

**Primary Success Indicator: Personal Track Engagement**

Success is measured primarily through Yisroel Meir's engagement with the **personal track** (the AI-driven smart track with adaptive scheduling). School and tutor tracks are passive logging that contribute to overall completion but don't drive the core engagement metrics.

**The "Aha!" Moment:**

The critical success indicator is when Yisroel Meir finds the app **addictive** and learns properly **because of it** - not just tracking what he's already doing, but fundamentally changing his learning behavior through the app's motivation and tracking systems. This typically manifests around days 5-7 when he realizes "I'm actually doing this every day! I can keep going!"

**Engagement Metrics:**
- **Daily app opens:** Yisroel Meir opens the app consistently without parental reminders
- **Streak length:** Building consecutive days of usage (target: multi-week and multi-month streaks)
- **Weekly active usage:** Using the app at least 5-6 days per week
- **Streak protection:** The streak counter becomes something he actively protects and values

**Learning Effectiveness:**
- **Daily task completion rate:** Percentage of personal track recommended daily tasks actually completed
- **3-stage completion consistency:** Following through on learning + both chazara cycles (not just learning new content)
- **Chazara adherence:** Completing chazara on schedule (next day for chazara 1, 7 days later for chazara 2)
- **Task abandonment rate:** Low rate of started-but-not-completed sessions
- **Voluntary extra learning:** Completing beyond recommended daily tasks (indicates genuine engagement)

**Multi-Context Integration:**
- **All tracks contributing:** School track + tutor track + personal track all feeding the unified 4,192 completion goal
- **Track flexibility working:** Ability to add/remove tracks as circumstances change (e.g., if tutor stops)
- **No duplicate assignments:** System prevents same Mishna appearing in multiple tracks
- **Bookmark effectiveness:** "Where he's up to" feature helps resume learning in each context

**On-Track Status:**
- **Pace indicator:** Days ahead/on-pace/behind target completion rate
- **Percentage complete vs time elapsed:** E.g., 33% complete by 1 year mark
- **Projected completion date:** Based on current pace, will he finish before 19 Kislev, 5789?
- **Buffer maintenance:** Staying ahead of minimum pace to allow for sick days, vacations, etc.

**Parent Success:**
- **Minimal intervention needed:** Yisroel Meir owns his journey without constant parental pushing or reminders
- **Ease of reward management:** Parents can quickly add/edit mystery rewards as he progresses
- **Quick monitoring:** Occasional dashboard glances show on-track status without daily oversight
- **Bulk management efficiency:** Initial onboarding with bulk masechta marking works smoothly

**Tutor Success:**
- **Teaching effectiveness:** Visibility into progress helps tutor align teaching sessions appropriately
- **Progress awareness:** Tutor can see which Mishnayos completed and what's due for chazara
- **Session planning:** Real-time data helps focus tutoring on gaps and review needs

**Critical Success Milestones:**

**1 Week Mark:**
- Still opening app daily? ✓
- First streak established (7 days)? ✓
- Completing recommended personal track tasks? ✓
- *Success indicator:* Habit formation beginning

**1 Month Mark:**
- Consistent usage pattern (5-6 days/week)? ✓
- Learning habit integrated into routine? ✓
- Streak maintained or recovered after breaks? ✓
- *Success indicator:* Daily habit solidified

**3 Month Mark:**
- On pace for bar mitzvah deadline? ✓
- Sustained engagement without motivation drop-off? ✓
- First completed masechta(s)? ✓
- *Success indicator:* Long-term viability proven

**6 Month Mark:**
- Multiple completed masechtos? ✓
- Still ahead of or on minimum pace? ✓
- Reward system maintaining motivation? ✓
- *Success indicator:* Halfway confidence established

**1 Year Mark:**
- Approximately 33%+ of total Mishnayos completed? ✓
- Significant progress visible (multiple sedarim substantially complete)? ✓
- App remains part of daily routine? ✓
- Confidence in bar mitzvah completion? ✓
- *Success indicator:* Bar mitzvah goal achievable

### Business Success

**Singular Success Metric:**

**By 19 Kislev, 5789 (December 7, 2028):**
- ✓ All 4,192 Mishnayos of Shas completed (learning stage)
- ✓ All 4,192 Mishnayos completed chazara 1
- ✓ All 4,192 Mishnayos completed chazara 2
- ✓ **Complete 3-stage learning cycle for entire Shas**
- ✓ Yisroel Meir arrives at his bar mitzvah having mastered Shas Mishnayos

**Secondary Success Indicators:**
- Yisroel Meir feels proud of his achievement
- Learning became a positive daily habit, not a burden
- Parents didn't need to constantly push or remind
- The journey built discipline and confidence for bar mitzvah and beyond
- Daily Torah learning habit is established for life

**What "Winning" Looks Like:**
1. Yisroel Meir opens the app daily without being asked
2. His streak counter becomes something he's proud of and protects
3. He stays on pace (or ahead) for his bar mitzvah deadline
4. The total number of Mishnayos feels achievable rather than overwhelming
5. He completes his bar mitzvah goal on 19 Kislev, 5789
6. The habit of daily Torah learning continues beyond bar mitzvah

**What "Failing" Looks Like:**
1. Yisroel Meir stops using it after initial excitement (week 2-4 drop-off)
2. Usage requires constant parental reminders and pushing
3. He falls significantly behind pace with no recovery
4. Chazara cycles are skipped (learning without retention)
5. Motivation wanes and the goal feels impossible again
6. He doesn't complete Shas Mishnayos by his bar mitzvah

### Technical Success

**Data Integrity (Non-Negotiable):**
- **Zero data loss over 3 years:** Yisroel Meir's progress is irreplaceable and must never be lost
- **Immutability enforcement:** Once a stage is marked complete, it's locked forever (prevents accidental unmarking)
- **Firebase sync reliability:** Automatic backup prevents data loss if device breaks or is replaced
- **Completion log integrity:** Append-only architecture ensures historical record is never corrupted
- **Multi-track constraint enforcement:** System prevents duplicate Mishna assignments across tracks

**Reliability (Critical Path):**
- **Offline-first operation:** All core features work without network (mark complete, browse, view progress)
- **First-launch sync success:** All 4,192 Mishnayos download successfully to SQLite within reasonable time
- **Background sync recovery:** Network failures don't block progress; sync recovers with exponential backoff
- **Resumable sync:** If interrupted during first-launch, can resume from checkpoint
- **State persistence:** App state survives restarts, device reboots, low memory situations

**Performance (User Experience):**
- **Smooth 60fps:** Scrolling, animations, transitions maintain 60fps on mid-range Android devices
- **Smart scheduler speed:** Daily recommendation calculations complete in <500ms
- **Database query performance:** Progress queries return in <100ms even with thousands of completions
- **App startup time:** Opens to usable state in <2 seconds on typical device
- **No crashes:** Crash-free rate >99.9% over the 3-year period

**System Robustness:**
- **Proper error handling:** Network errors, database errors, and edge cases handled gracefully
- **Transaction safety:** Database writes use transactions with automatic rollback on failure
- **Conflict resolution:** Last-write-wins with UTC timestamps handles multi-device edge cases
- **Firebase quota management:** Stays within free tier limits, graceful degradation if quota exceeded
- **Hebrew calendar accuracy:** Date calculations verified against authoritative sources (Hebcal.com)

### Measurable Outcomes

**Quantitative Metrics:**
- **Total completions over 3 years:** 12,576 total stage completions (4,192 × 3 stages)
- **Daily completion rate:** Average 12 completions/day during steady state (days 9-1,062)
- **Streak metrics:** Maximum streak length, average streak length, streak recovery rate
- **On-time completion:** Projected completion date ≤ 19 Kislev, 5789
- **Pace buffer:** Days ahead of minimum required pace
- **Points accumulation:** Total points earned over journey (max 83,840 if all defaults)
- **Reward earning rate:** Mystery rewards earned at planned intervals

**Qualitative Outcomes:**
- **Behavioral change:** Learning shifts from sporadic to consistent daily habit
- **Emotional impact:** From "overwhelming and impossible" to "achievable and satisfying"
- **Ownership:** Yisroel Meir feels ownership of his bar mitzvah journey
- **Pride:** Visible progress creates sense of accomplishment and pride
- **Confidence:** Belief that he will complete his goal by bar mitzvah

**Decision Points:**
- **Week 2-4:** Critical period - if usage drops off, intervention needed
- **3 Month Mark:** Evaluate if trajectory supports 3-year completion
- **1 Year Mark:** Assess if v2.0 public release is warranted based on proven success
- **Bar Mitzvah Completion:** Ultimate validation of concept and methodology

## Product Scope

### MVP - Minimum Viable Product

**v1.0 Complete Feature Set (No Phasing)**

Everything in the tech spec must be complete and functional on day 1. This is not a phased rollout - all features are required for the product to be useful for Yisroel Meir's 3-year journey.

**Phase 1 - Foundation:**
- Flutter project with proper architecture
- Complete database schema (SQLite + Firestore)
- All 4,192 Mishnayos pre-seeded from Sefaria API
- Firebase project configured
- Core domain models
- Basic app shell and navigation

**Phase 2 - Core Tracking:**
- Complete 3-stage learning cycle (learning, chazara 1, chazara 2)
- Multi-track system (personal/school/tutor tracks)
- Track management (add/remove optional tracks)
- Bookmark per track ("where he's up to")
- Immutable progress enforcement via completion log
- Bulk masechta management for parents (initial onboarding)
- First-launch sync (Firebase → SQLite, all 4,192 Mishnayos)
- Delta sync (SQLite ↔ Firebase with conflict resolution)
- Mishna browsing by seder/masechta/perek
- Text display (Hebrew + English from Sefaria)
- Mark completion UI with stage-specific buttons

**Phase 3 - Intelligence Layer:**
- Smart adaptive scheduler (personal track only)
- Daily recommendation engine
- Automatic chazara scheduling (next day + 7 days)
- Adaptive pacing algorithm (adjusts based on progress)
- Chazara pile-up management
- Progress dashboard (multiple views)
- Hebrew calendar integration (kosher_dart)
- On-track status calculations
- Seder/masechta/overall progress visualization
- Points over time charting

**Phase 4 - Engagement & Access:**
- Points system (learning=10, chazara1=5, chazara2=5)
- Mystery rewards system (parent-configured, hidden from child)
- Streak tracking (consecutive days)
- Completion animations and feedback
- Parent mode (PIN-protected)
  - Reward catalog management
  - Bulk masechta marking
  - Analytics dashboard
  - Point value configuration
  - Track management (add/remove school/tutor tracks)
- Tutor mode (separate PIN, view-only)
- Local push notifications (daily reminders)
- Data backup/restore (JSON export/import)
- Sefaria attribution
- Onboarding flow
- Material Design 3 theme

**Technical Requirements (All Required):**
- Offline-first architecture
- Firebase Anonymous Authentication
- Cloud Firestore with security rules
- Encrypted PIN storage (flutter_secure_storage + bcrypt)
- Network retry with exponential backoff
- Resumable first-launch sync with checkpoints
- Transaction-based database writes
- Error handling and crash prevention
- 80%+ test coverage on business logic
- Unit, widget, and integration tests

**Acceptance Criteria:**
All 76 acceptance criteria from tech spec must pass before release to Yisroel Meir.

### Growth Features (Post-MVP)

**v2.0 - Public Release (Conditional on v1.0 Success)**

Only pursued if Yisroel Meir successfully completes his bar mitzvah goal using the app.

**Generalization Features:**
- Multi-user support (remove hardcoding)
- Setup wizard (child name, bar mitzvah date entry)
- Firebase user isolation (each family gets private data)
- Email/password authentication (replaces anonymous auth)
- Privacy policy and terms of service
- Beta testing group validation
- Firebase Crashlytics for public monitoring
- Play Store listing and compliance

**User-Requested Enhancements:**
- Hebrew language UI option
- Customizable learning goals (beyond bar mitzvah)
- Parent-child progress sharing features
- Community-contributed reward ideas
- Multiple children per family account
- Advanced analytics and data export

### Vision (Future)

**Long-Term Vision:**

Make Mishnayos Tracker the go-to free app for Jewish families preparing their sons for bar mitzvah, helping thousands of children complete Shas Mishnayos through consistent daily learning habits supported by respectful gamification.

**Potential Future Directions:**
- iOS version (expand beyond Android)
- Expanded curriculum support (Gemara, Tanach, etc.)
- Advanced predictive analytics (completion forecasting)
- AI-powered learning insights
- Community features (anonymous leaderboards, family challenges)

**Success Metrics for Public Release:**
- 1,000+ active families using the app
- 90%+ bar mitzvah completion rate
- 4.5+ star rating on Play Store
- Active community of contributing families
- Sustainability model (donations, sponsorships)

## User Journeys

### Journey 1: Yisroel Meir Niasoff - From Overwhelming to "I'm Actually Doing This!"

**The Introduction**

Yisroel Meir is 10 years old and has just learned he needs to complete all 4,192 Mishnayos of Shas before his bar mitzvah on 19 Kislev, 5789 (December 7, 2028). That's about 3 years away, and the number feels impossibly large and abstract. His learning has been sporadic - sometimes he forgets, sometimes he needs pushing, and without visible progress, it's hard to stay motivated. His father sits down with him one evening and says, "We built something special for your bar mitzvah."

**First Open - It's Personal**

Yisroel Meir opens the app and immediately sees his name - "Yisroel Meir Niasoff" - and his Hebrew bar mitzvah date: 19 Kislev, 5789. This wasn't downloaded from the Play Store. This was made FOR HIM. His parents help him through the setup: configuring the bar mitzvah date, setting the learning order for masechtos, and adding the first few mystery rewards to the catalog. Then comes his first completion.

He marks his very first Mishna as learned. A satisfying checkmark animation plays, points pop up on screen (+10!), and he watches a tiny sliver of the progress bar fill. It's small, but it's *his*. Immediate satisfaction.

**Daily Routine Emerges**

Over the next few days, Yisroel Meir develops a routine. He opens the app at a flexible time during his day - sometimes morning, sometimes evening, depending on his schedule. The dashboard greets him: "Today's Tasks: 4 new learning, 3 chazara 1, 2 chazara 2." After learning each Mishna with his sefer, he taps to mark it complete. Each time: satisfying tick animation, points popup, progress bars filling incrementally, streak counter incrementing. He checks the progress bar for his next mystery reward, building anticipation.

**The "Aha!" Moment - Days 5-7**

It's the sixth day in a row that Yisroel Meir opens the app. He sees "Current Streak: 6 days 🔥" displayed prominently. Something clicks. "I'm actually doing this every day! I can keep going!" He looks at the overall progress - a few masechtos are starting to show real completion. The 4,192 that felt overwhelming last week? It doesn't feel impossible anymore. He can *see* it happening. He feels ownership and pride in his visible progress. The app isn't just tracking - it's making him *want* to learn.

**The Journey Continues - Weeks and Months**

The app becomes part of Yisroel Meir's daily routine, as automatic as brushing his teeth. His streak becomes something precious - he doesn't want to break it. After a few weeks, a notification pops up: "Mystery reward earned!" His parents reveal the surprise, and the excitement fuels his motivation for the next one. Months pass. He sees himself ahead of pace on the dashboard - a confidence boost. Multiple masechtos are complete now. Entire sedarim are filling up. As he approaches his bar mitzvah with over two years of consistent learning, completion is in sight. The 4,192 that once felt abstract is now a journey he owns completely.

**This journey reveals requirements for:**
- Personalized onboarding with his name and bar mitzvah date
- Multi-track system (personal/school/tutor) with bookmarks
- 3-stage learning cycle tracking with immutable completion
- Smart daily recommendations (personal track only)
- Satisfying completion animations and instant feedback
- Streak tracking and visualization
- Progress dashboards (overall, by seder, by masechta)
- Mystery rewards system with progress bars
- Bulk masechta marking for initial setup

### Journey 2: Parents (Mother & Father) - Hands-Off Observers

**Setup Night**

It's the evening before Yisroel Meir starts using the app. Both parents sit together with the app open in parent mode (they share one login). They enter their 4-digit PIN for the first time - this section is theirs alone. They configure the initial rewards catalog: a small prize at 10,000 points, something bigger at 25,000, and so on. They think about what will keep him motivated over 3 years without making it feel like bribery. They review the learning order of masechtos and confirm the defaults look good. They set the bar mitzvah date one more time to double-check: 19 Kislev, 5789. Everything is ready.

**Ongoing - Weekly Reward Updates**

Every few weeks, one parent logs into parent mode to add another reward to the catalog. It takes less than 2 minutes. They set the point threshold, write a title (keeping it mysterious for Yisroel Meir), add a description they'll reveal when he earns it, and save. The app handles the rest. They don't micromanage his daily learning - that's his journey.

**Occasional Check-Ins**

About once a week (sometimes less), a parent opens the dashboard and glances at the key metrics:
- Is he keeping up with the target pace? ✓ (He's 3 days ahead)
- Overall completion percentage? ✓ (15% after 4 months - right on track)
- Current streak? ✓ (23 days - impressive!)

The check takes 30 seconds. They close the app satisfied. No intervention needed.

**The Reward Moment**

A notification appears on their phone: "Mystery reward earned!" They check which reward it is from the catalog, then call Yisroel Meir over. "You earned something!" They reveal what the mystery reward was, and his face lights up. This is why they built this. A few minutes later, they're back to their day. Minimal effort, maximum impact.

**Three Years Later**

It's a few weeks before the bar mitzvah. The parents open the app and see: 100% complete. All 4,192 Mishnayos. All three stages (learning, chazara 1, chazara 2). Yisroel Meir did it. They never had to push, never had to remind constantly. The app became his companion for the journey. They feel proud - not because they managed it, but because *he* owned it.

**This journey reveals requirements for:**
- PIN-protected parent mode (separate from child access)
- Reward catalog management (add/edit/delete rewards)
- Simple analytics dashboard (on-track status, completion %, streak)
- Bulk masechta marking (initial onboarding)
- Track management (add/remove school/tutor tracks)
- Point value configuration
- Notification system for reward milestones
- Minimal time investment design (quick glances, not daily oversight)

### Journey 3: Tutor - Teaching with Visibility

**Getting Access**

The tutor receives login credentials from Yisroel Meir's parents - a separate PIN for tutor mode. It's view-only access, which is perfect. The tutor doesn't need to change anything, just see progress to align teaching sessions effectively.

**Weekly Pre-Session Check**

Every Monday morning before the weekly tutoring session, the tutor logs into tutor mode and reviews:
- Which Mishnayos has Yisroel Meir completed since last week? (Sees the completion log with dates)
- What's due for chazara today or this week? (Sees the chazara queue)
- Overall pace - is he on track? Falling behind? Ahead? (Sees on-track status)

This takes 3-4 minutes and completely transforms how the tutor plans the session.

**Teaching Focus Adjustment**

During the Tuesday tutoring session, the tutor notices Yisroel Meir completed Masechta Berachos learning stage but has several Mishnayos due for chazara 1. Instead of pushing forward with new masechtos, the tutor focuses the session on reviewing those specific Mishnayos, reinforcing retention. The app's data shows exactly where to focus.

**Progress Monitoring Over Time**

Every few months, the tutor reviews overall progress trends:
- Are there patterns in which masechtos he completes faster?
- Is the chazara piling up, or is he keeping pace?
- Does the pace suggest he'll finish on time for his bar mitzvah?

The tutor uses these insights to adjust teaching approach and provide encouragement or additional support where needed.

**Celebration Moments**

When Yisroel Meir completes an entire seder, the tutor sees it in the dashboard and acknowledges the milestone during their next session. "I saw you finished Seder Zeraim - that's incredible!" The real-time visibility lets the tutor celebrate achievements that might otherwise go unnoticed.

**This journey reveals requirements for:**
- Separate PIN-protected tutor mode (different from parent PIN)
- View-only access (no edit capabilities)
- Completion log visibility (what's been completed, when, which stage)
- Chazara queue visibility (what's due for review)
- On-track status and overall progress metrics
- Real-time sync (tutor sees latest data)
- Progress breakdown by seder/masechta
- Historical completion data (trends over time)

### Journey Requirements Summary

**From Yisroel Meir's Journey:**
- Personalized onboarding and setup
- Multi-track system with bookmarks (personal/school/tutor)
- 3-stage learning cycle with immutable progress
- Smart adaptive scheduler (personal track only)
- Daily recommendations
- Completion UI with animations and feedback
- Streak tracking and protection
- Multi-view progress dashboards
- Mystery rewards with progress visualization
- Bulk masechta management

**From Parent Journey:**
- PIN-protected parent mode
- Reward catalog management (CRUD operations)
- Simple analytics dashboard
- Bulk masechta marking
- Track management (add/remove optional tracks)
- Point value configuration
- Notification system for milestones
- Minimal-time-investment UX design

**From Tutor Journey:**
- Separate PIN-protected tutor mode
- View-only access enforcement
- Completion log visibility with timestamps
- Chazara queue display
- On-track status calculations
- Real-time Firebase sync
- Progress breakdowns (seder/masechta/overall)
- Historical trend data

## Mobile App Specific Requirements

### Project-Type Overview

Mishnayos Tracker is an **Android mobile application** built using **Flutter/Dart** (cross-platform framework), though v1.0 deployment targets Android exclusively. The app leverages mobile-specific capabilities including offline-first architecture, local notifications, encrypted secure storage, and background synchronization. The mobile platform choice reflects the target user's daily usage pattern - a 10-year-old who needs quick, flexible access throughout the day on his personal Android device.

### Technical Architecture Considerations

**Cross-Platform Framework with Single-Platform Deployment:**
- **Framework:** Flutter/Dart provides cross-platform codebase
- **v1.0 Target:** Android only (API level 21+ / Android 5.0 Lollipop+)
- **Future Expansion:** iOS support deferred to v2.0+ (framework supports it, but separate development effort)
- **Rationale:** Flutter chosen for rapid development, native performance, rich UI capabilities, and future iOS portability

**Performance Targets:**
- **60fps rendering** for smooth scrolling, animations, and transitions on mid-range Android devices
- **Sub-2-second startup time** to usable state
- **Sub-500ms scheduler calculations** for daily recommendations
- **Sub-100ms database queries** even with thousands of completion records
- **Minimal battery drain** from background sync operations

### Platform Requirements

**Android Platform:**
- **Minimum SDK:** API 21 (Android 5.0 Lollipop)
- **Target SDK:** Latest stable Android version at release
- **Device Classes:** Mid-range Android phones and tablets (no flagship-only features)
- **Screen Support:** Responsive layouts for 5" phones to 10" tablets
- **Orientation:** Portrait primary, landscape supported for viewing progress dashboards

**Distribution Method:**
- **v1.0:** Direct APK installation (sideloading for personal use)
- **v2.0+:** Google Play Store distribution (requires compliance process)

**Development Environment:**
- Flutter SDK (stable channel)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator for testing

### Device Permissions

**Required Permissions:**

**Storage:**
- **Local database storage:** SQLite database for 4,192 Mishnayos and completion log
- **Secure storage:** Encrypted PIN storage using `flutter_secure_storage`
- **App data directory:** Configuration, cache, temporary files

**Notifications:**
- **Local scheduled notifications:** Daily learning reminders via `flutter_local_notifications`
- **Notification permission:** Required on Android 13+ (runtime permission)

**Network (Optional):**
- **Internet access:** Background Firebase sync when online
- **Network state detection:** `connectivity_plus` to detect online/offline state
- **Graceful degradation:** All core features work without network permission

**NO permissions required for:**
- Camera
- Location
- Contacts
- Microphone
- Biometrics
- Phone state
- SMS
- Calendar access (uses kosher_dart library for calculations, no device calendar integration)

### Offline Mode

**Offline-First Architecture (Critical Requirement):**

**Design Philosophy:**
- **SQLite is source of truth:** Local database is canonical, not Firebase
- **Offline by default:** App fully functional without network connectivity
- **Background sync:** Firebase sync is enhancement, not requirement
- **User experience:** Zero difference between online/offline for core operations

**Offline Capabilities:**
- **Browse Mishnayos:** Navigate seder/masechta/perek structure offline
- **Mark completions:** All 3 stages (learning, chazara 1, chazara 2) work offline
- **View progress:** Dashboards, charts, statistics calculate from local data
- **Smart scheduler:** Daily recommendations compute locally
- **Streak tracking:** Maintains streak counter offline
- **Points system:** Accumulates points locally
- **Parent/Tutor modes:** PIN authentication and mode access work offline

**Requires Network:**
- **First-launch sync:** Initial download of 4,192 Mishnayos from Firebase to SQLite (resumable with checkpoints)
- **Background sync:** Delta sync of local completions to Firebase (exponential backoff retry)
- **Device transfer:** Restoring data on new device requires one-time sync

**Sync Strategy:**
- **Conflict resolution:** Last-write-wins with UTC timestamps
- **Delta sync only:** Only changed records sync (not full database)
- **Automatic retry:** Exponential backoff for failed syncs
- **Battery-aware:** Respects battery saver mode, defers non-critical sync

### Push Strategy

**Local Notifications Only (No Cloud Messaging):**

**Technology:**
- **Library:** `flutter_local_notifications` package
- **Type:** Local scheduled notifications (NOT Firebase Cloud Messaging)
- **Scope:** All notifications generated and scheduled locally on device

**Notification Types:**

**Daily Learning Reminder:**
- **Trigger:** Daily at configurable time (default 7:00 PM)
- **Content:** "Time to learn! You have [N] tasks today"
- **Purpose:** Gentle daily reminder to maintain learning habit
- **User control:** Can enable/disable, change time, or disable entirely in settings

**Streak Protection Alert:**
- **Trigger:** If user hasn't opened app by 9:00 PM and has active streak
- **Content:** "Don't break your [N]-day streak!"
- **Purpose:** Protect valuable multi-week/month streaks from accidental breaks
- **User control:** Can disable streak alerts separately from daily reminders

**Reward Earned Notification:**
- **Trigger:** When point threshold crossed for mystery reward
- **Content:** "Mystery reward unlocked! Ask your parents to reveal it."
- **Purpose:** Immediate excitement and parent notification
- **Delivery:** Instant notification when reward threshold reached

**Permission Handling:**
- **Android 12 and below:** Notifications work by default
- **Android 13+:** Runtime permission request on first launch
- **Graceful degradation:** App works fully without notification permission (just no reminders)

**NO Cloud Messaging Requirements:**
- No Firebase Cloud Messaging (FCM) integration
- No server-triggered push notifications
- No remote notification payloads
- Simplified privacy and battery profile

### Store Compliance

**v1.0 - Direct APK Distribution:**

**No Play Store Compliance Required:**
- Distributed as APK file via direct install (sideloading)
- Private personal use for one family
- No public distribution or monetization
- No Play Store policies apply

**Basic Android APK Requirements:**
- Valid signing certificate (debug or release)
- Proper app icon and launcher configuration
- Standard Android manifest permissions
- Installation instructions for parents

**v2.0+ - Google Play Store Preparation:**

When pursuing public release, will require:

**Legal/Compliance:**
- Privacy policy (hosted URL)
- Terms of service
- Age rating declaration (PEGI, ESRB)
- Data handling transparency
- COPPA compliance (if targeting children under 13 in US)

**Technical Requirements:**
- Release signing certificate (production)
- App signing by Google Play
- Target latest Android API level (Google requirement)
- 64-bit architecture support
- Smaller APK size optimization

**Store Listing:**
- App description, screenshots, feature graphic
- Localization (English + Hebrew if desired)
- Content rating questionnaire
- Developer account ($25 one-time fee)

**Privacy & Security:**
- Firebase security rules hardened for multi-user
- User data isolation per family account
- Email/password authentication (replaces anonymous auth)
- Data deletion capability (GDPR compliance)
- Crashlytics for production monitoring

**Testing:**
- Internal testing track
- Closed beta testing with volunteer families
- Production rollout phased by percentage

### Implementation Considerations

**Flutter-Specific Best Practices:**
- **State management:** Provider or Riverpod for app-wide state
- **Dependency injection:** get_it for service locator pattern
- **Code architecture:** Clean architecture with presentation/domain/data layers
- **Testing:** Unit tests (80%+ business logic), widget tests, integration tests

**Android-Specific Optimizations:**
- **ProGuard/R8:** Code shrinking and obfuscation for release builds
- **App bundles:** Use AAB format for smaller download size (v2.0+)
- **Background work:** WorkManager for reliable background sync
- **Battery optimization:** Respect Doze mode, use efficient wake locks

**Hebrew Language Support:**
- **RTL layout:** Proper right-to-left layout for Hebrew text
- **Text rendering:** Flutter handles bidirectional text (Hebrew + English)
- **Fonts:** Include Hebrew-compatible fonts (possibly Noto Sans Hebrew)
- **Character encoding:** UTF-8 throughout for proper Hebrew display
- **Sefaria API:** Returns Hebrew text correctly formatted

**Accessibility:**
- Material Design 3 provides baseline accessibility
- Semantic labels for screen readers (future enhancement)
- Sufficient touch target sizes (48dp minimum)
- Color contrast ratios meeting WCAG AA standards

## Functional Requirements

### Learning Content & Structure

- FR1: System can provide complete database of 4,192 Mishnayos organized by seder/masechta/perek structure
- FR2: Users can browse Mishnayos content hierarchically (seder → masechta → perek → individual Mishna)
- FR3: Users can view Mishna text in both Hebrew and English
- FR4: System can attribute content to Sefaria API source

### Multi-Track Learning Management

- FR5: Users can manage up to 3 learning tracks (personal, school, tutor) with personal track mandatory
- FR6: Users can add or remove optional tracks (school/tutor) as circumstances change
- FR7: System can maintain separate "where he's up to" bookmark for each active track
- FR8: System can prevent a single Mishna from being assigned to multiple tracks simultaneously
- FR9: Users can designate which track a Mishna belongs to when marking progress

### 3-Stage Learning Cycle

- FR10: Users can mark a Mishna as completed for learning stage (stage 1)
- FR11: Users can mark a Mishna as completed for chazara 1 (review stage 2)
- FR12: Users can mark a Mishna as completed for chazara 2 (review stage 3)
- FR13: System can enforce immutability - once a stage is marked complete, it cannot be unmarked
- FR14: System can maintain append-only completion log with timestamps for all stage completions
- FR15: System can track which Mishnayos are due for chazara 1 (next day after learning)
- FR16: System can track which Mishnayos are due for chazara 2 (7 days after chazara 1)

### Smart Scheduling & Recommendations (Personal Track Only)

- FR17: System can generate daily recommendations for personal track showing new learning and chazara tasks
- FR18: System can calculate optimal daily task count based on bar mitzvah deadline and current progress
- FR19: System can adapt recommendations when user falls behind or accelerates ahead of pace
- FR20: System can balance new learning with chazara pile-up to prevent overload
- FR21: System can automatically schedule chazara tasks based on completion timestamps

### Progress Tracking & Visualization

- FR22: Users can view overall progress as percentage of 4,192 Mishnayos completed
- FR23: Users can view progress broken down by seder
- FR24: Users can view progress broken down by masechta
- FR25: Users can view progress broken down by perek
- FR26: Users can view which track contributed each completion
- FR27: Users can see current pace status (days ahead/on-pace/behind target)
- FR28: Users can see projected completion date based on current pace
- FR29: Users can view completion history over time

### Gamification & Motivation System

- FR30: System can award points for completing learning stages (configurable, default 10 points)
- FR31: System can award points for completing chazara 1 (configurable, default 5 points)
- FR32: System can award points for completing chazara 2 (configurable, default 5 points)
- FR33: Users can track total points accumulated over time
- FR34: Users can view points earned over time via charting
- FR35: System can track consecutive days of app usage (streak counter)
- FR36: Users can view current streak length and maximum streak achieved
- FR37: System can display mystery rewards with progress bars showing points needed
- FR38: System can notify when mystery reward point threshold is reached
- FR39: Parents can reveal mystery reward details when earned

### Parent Mode Capabilities

- FR40: Parents can access PIN-protected parent mode (4-digit PIN)
- FR41: Parents can manage mystery reward catalog (add/edit/delete rewards with point thresholds)
- FR42: Parents can bulk mark entire masechtas as already completed during initial onboarding
- FR43: Parents can configure point values for each learning stage
- FR44: Parents can add or remove optional tracks (school/tutor)
- FR45: Parents can view analytics dashboard showing on-track status, completion percentage, and streak
- FR46: Parents can view all completion history and progress data

### Tutor Mode Capabilities

- FR47: Tutor can access PIN-protected tutor mode with separate PIN from parent mode
- FR48: Tutor can view (but not modify) all completion data and progress
- FR49: Tutor can see completion log with timestamps showing what was completed and when
- FR50: Tutor can see which Mishnayos are due for chazara
- FR51: Tutor can view on-track status and overall progress metrics
- FR52: Tutor can view progress breakdowns by seder/masechta

### Onboarding & Setup

- FR53: Users can complete initial app setup including bar mitzvah date configuration
- FR54: Users can set personalized user information (name, bar mitzvah date in Hebrew calendar)
- FR55: Parents can configure initial mystery rewards during setup
- FR56: Parents can bulk mark prior completed masechtas during onboarding
- FR57: Users can configure learning order preferences for masechtos

### Notification & Reminders

- FR58: Users can receive daily learning reminder notifications at configurable time (default 7:00 PM)
- FR59: Users can receive streak protection alert if no app usage by 9:00 PM
- FR60: Users can receive instant notification when mystery reward is earned
- FR61: Users can enable/disable notification types independently
- FR62: Users can configure notification times
- FR63: Parents can receive reward milestone notifications

### Offline & Data Management

- FR64: Users can access all core features without network connectivity (offline-first)
- FR65: System can perform first-launch sync to download all 4,192 Mishnayos from Firebase to local database
- FR66: System can perform background delta sync of local completions to Firebase when online
- FR67: System can resume interrupted first-launch sync from checkpoint
- FR68: System can resolve sync conflicts using last-write-wins with UTC timestamps
- FR69: System can retry failed syncs with exponential backoff
- FR70: Users can export progress data to JSON for backup
- FR71: Users can import progress data from JSON backup file

### Security & Access Control

- FR72: System can encrypt and securely store parent PIN using secure storage
- FR73: System can encrypt and securely store tutor PIN using secure storage
- FR74: System can authenticate parent mode access via 4-digit PIN
- FR75: System can authenticate tutor mode access via separate 4-digit PIN
- FR76: System can enforce view-only permissions for tutor mode (no edit capabilities)

### Calendar & Date Management

- FR77: System can calculate Hebrew calendar dates using kosher_dart library
- FR78: System can track bar mitzvah deadline (19 Kislev, 5789 / December 7, 2028)
- FR79: System can calculate days remaining until bar mitzvah
- FR80: System can use Hebrew calendar for scheduling and display purposes

### Completion Animations & Feedback

- FR81: Users can see satisfying completion animations when marking stages complete
- FR82: Users can see points popup immediately when earning points
- FR83: Users can see progress bars fill incrementally with each completion
- FR84: Users can see streak counter increment with daily usage

## Non-Functional Requirements

### Performance

**Response Time:**
- NFR1: App startup must complete to usable state within 2 seconds on mid-range Android devices
- NFR2: Smart scheduler calculations must complete within 500ms for daily recommendations
- NFR3: Database queries must return results within 100ms even with thousands of completion records
- NFR4: User actions (mark complete, navigate, view progress) must respond within 200ms

**Rendering Performance:**
- NFR5: UI must maintain 60fps during scrolling, animations, and transitions on mid-range Android devices
- NFR6: Progress bar animations must render smoothly without frame drops
- NFR7: List scrolling (Mishna browsing) must maintain consistent 60fps performance

**Resource Efficiency:**
- NFR8: Background sync operations must minimize battery drain (< 2% daily battery impact)
- NFR9: App memory footprint must not exceed 150MB during normal operation
- NFR10: First-launch sync must complete within 5 minutes on typical mobile network connection

### Reliability & Data Integrity

**Data Persistence:**
- NFR11: Zero data loss over 3-year usage period - all completion data must be preserved
- NFR12: Completion log must maintain integrity through device reboots, crashes, and low-memory situations
- NFR13: SQLite transactions must use automatic rollback on failure to prevent partial writes
- NFR14: App state must survive device restarts without loss of unsynchronized data

**Crash Resilience:**
- NFR15: Crash-free rate must exceed 99.9% over the 3-year period
- NFR16: All errors must be handled gracefully with user-friendly error messages
- NFR17: Network errors must not cause app crashes or data corruption

**Sync Reliability:**
- NFR18: First-launch sync must be resumable from checkpoint if interrupted
- NFR19: Background sync must retry failed operations with exponential backoff (max 5 retries)
- NFR20: Sync conflicts must resolve using last-write-wins with UTC timestamps
- NFR21: Firebase quota limits must be monitored with graceful degradation if exceeded

### Offline Capability

**Core Functionality:**
- NFR22: All essential features (browse, mark complete, view progress, smart scheduler) must work without network connectivity
- NFR23: Offline operation must provide identical user experience to online operation for core features
- NFR24: Local database must serve as source of truth, not Firebase

**Sync Behavior:**
- NFR25: Background sync must operate battery-efficiently without blocking user actions
- NFR26: Network state changes must trigger sync automatically when connectivity restored
- NFR27: Sync must respect Android battery saver mode and defer non-critical operations

### Security & Privacy

**Authentication:**
- NFR28: Parent PIN must be encrypted using flutter_secure_storage with bcrypt hashing
- NFR29: Tutor PIN must be encrypted separately from parent PIN using secure storage
- NFR30: PIN authentication must lockout after 5 failed attempts with 30-second timeout

**Data Protection:**
- NFR31: All Firebase communication must use HTTPS/TLS encryption
- NFR32: Firestore security rules must prevent unauthorized access to user data
- NFR33: Local data must be stored in app-private directory inaccessible to other apps

**Access Control:**
- NFR34: Tutor mode must enforce view-only access preventing data modification
- NFR35: Parent mode must be the only mode with data modification capabilities (beyond child marking completions)

### Integration & Compatibility

**External APIs:**
- NFR36: Sefaria API integration must handle API failures gracefully with cached fallback
- NFR37: Hebrew calendar calculations (kosher_dart) must be verified against authoritative sources (Hebcal.com)
- NFR38: Firebase operations must handle network timeouts gracefully (15-second timeout with retry)

**Platform Compatibility:**
- NFR39: App must support Android API 21+ (Android 5.0 Lollipop and above)
- NFR40: App must function correctly on screen sizes from 5" phones to 10" tablets
- NFR41: App must support both portrait and landscape orientations

**Hebrew Language Support:**
- NFR42: Hebrew text must render correctly with RTL (right-to-left) layout
- NFR43: Bidirectional text (Hebrew + English) must display properly
- NFR44: Hebrew fonts must be included and render clearly on all supported devices

### Accessibility (Baseline)

**Material Design 3 Compliance:**
- NFR45: Touch targets must meet minimum 48dp size requirement
- NFR46: Color contrast ratios must meet WCAG AA standards (4.5:1 for normal text, 3:1 for large text)
- NFR47: UI must provide semantic structure for future screen reader support
