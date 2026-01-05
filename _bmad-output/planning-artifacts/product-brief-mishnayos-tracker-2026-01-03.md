---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments: []
date: 2026-01-03
author: Daniel
---

# Product Brief: mishnayos-tracker

<!-- Content will be appended sequentially through collaborative workflow steps -->

## Executive Summary

**Mishnayos Tracker** is a personalized Android app designed to help a 10-year-old (Yisroel Meir Niasoff) complete all 4,300 Mishnayos by his bar mitzvah through daily tracking, visual progress, and balanced motivation. The app transforms an overwhelming 3-year learning goal into an achievable daily habit by tracking the complete learning cycle (learn + 2x chazara), showing real-time progress, and rewarding consistency with surprise prizes. Built as a deeply personal tool for one child's bar mitzvah journey, it balances the seriousness of Torah learning with age-appropriate engagement through points, progress visualization, and the satisfying experience of ticking off completed Mishnayos. The app will be free on Google Play Store for other Jewish families once proven successful.

---

## Core Vision

### Problem Statement

A 10-year-old boy needs to learn approximately 4,300 Mishnayos over the next 3 years before his bar mitzvah, requiring 4-5 Mishnayos daily with proper review (chazara twice). Without a tracking system, learning is inconsistent - he forgets, needs pushing, and lacks visible progress. The sheer number (4,300) feels overwhelming and abstract rather than achievable, making it difficult to maintain daily momentum over such a long timeline.

### Problem Impact

**Without consistent tracking and motivation:**
- Daily learning becomes sporadic, making the 3-year goal unrealistic
- The child can't see progress, leading to discouragement
- No visibility into whether he's on track for his bar mitzvah deadline
- Forgetting to learn becomes habitual without reminders or engagement
- The enormous total (4,300) remains abstract and intimidating
- Proper review cycles (chazara) get skipped, undermining retention
- The meaningful goal of completing Shas Mishnayos for bar mitzvah becomes a source of stress rather than achievement

### Why Existing Solutions Fall Short

**Generic habit trackers** lack the structure needed for Torah learning - they don't understand the 3-stage learning cycle (learn, chazara, chazara) or the organization of Mishnayos by seder/masechta/perek. They're also impersonal corporate solutions that don't create the special connection between father and son building something together for this life milestone.

**Hypothetical Jewish learning apps** (if any exist) would be generic solutions for all learners, missing the personalization that makes this meaningful - his name, his specific bar mitzvah date, his journey. They might also over-gamify Torah learning or under-gamify for a 10-year-old's engagement needs.

**Paper/spreadsheet tracking** doesn't provide the immediate satisfaction of ticking off progress, visual dashboards showing achievement, or the motivational elements that keep a 10-year-old engaged daily over 3 years.

### Proposed Solution

**Mishnayos Tracker** is a personalized Android app that:

**Core Tracking:**
- Maintains complete database of all ~4,300 Mishnayos organized by seder/masechta/perek
- Tracks 3-stage learning cycle: initial learning, chazara #1 (next day), chazara #2 (7 days after chazara #1)
- Allows immediate tick-off satisfaction when Mishnayos are completed
- Immutable progress - once a stage is marked complete, it's locked forever (prevents errors)
- Syncs data across devices via Firebase cloud backup with free authentication

**Smart Adaptive Scheduling:**
- Calculates optimal daily recommendations based on bar mitzvah deadline
- Recommends balanced daily mix (e.g., "4 new learning + 5 chazara 1 + 3 chazara 2")
- Automatically queues chazara based on timing rules (next day, then +7 days)
- Adjusts recommendations if child falls behind or accelerates ahead
- Handles variable pace - if chazara piles up, reduces new learning temporarily
- Projects completion date and shows on-track status

**Progress Visualization:**
- Dashboard showing progress toward bar mitzvah date
- Visual indicators of on-track status (ahead/behind pace)
- Breakdown of overwhelming 4,300 into achievable daily/weekly chunks
- Shows completed vs. remaining by seder, masechta, and overall
- Current streak tracking (consecutive days learning)
- Multiple progress views (%, masechtos completed, points earned over time)

**Balanced Motivation:**
- Points system for completing Mishnayos and chazara cycles
- Surprise rewards at milestone points (parent-configured, hidden from child)
- Progress bar showing points needed for next mystery reward
- Respectful of Torah learning (not frivolous/over-gamified)
- Age-appropriate engagement for tech-savvy 10-year-old
- Satisfying animations and feedback for task completion

**Personal Experience:**
- Built by father for son's bar mitzvah (Yisroel Meir Niasoff)
- Personalized with his name and bar mitzvah date (19 Kislev, 5789 / December 7, 2028)
- Hebrew calendar primary (respects Torah learning tradition)
- Solo journey (not competitive, not parent-monitored in daily use)
- Makes the child feel this was created specifically for him

**Parent Control:**
- PIN-protected parent mode for reward management
- Configure point values and learning order
- View detailed analytics and progress reports
- Manage reward catalog (add/edit prizes, set point thresholds)
- Manual schedule adjustments if needed
- Export/import data for backup

### Key Differentiators

**Personal over generic:** Built as a father for his son's specific bar mitzvah journey (Yisroel Meir Niasoff → 19 Kislev, 5789 / December 7, 2028), creating emotional connection and meaning beyond a corporate app.

**3-stage learning cycle:** Tracks proper Torah learning methodology (learn + chazara next day + chazara 2 after 7 days), not just binary "done/not done" checkboxes like habit trackers.

**Adaptive smart scheduling:** Intelligent algorithm calculates daily recommendations based on bar mitzvah deadline, adjusts for missed days or accelerated pace, and balances new learning with chazara pile-up to ensure completion on time.

**Balanced gamification:** Respectful of Torah learning seriousness while still engaging a 10-year-old through progress visualization, points, and surprise rewards that maintain mystery and anticipation.

**Complete Mishnayos structure:** Properly organized database of ~4,300 Mishnayos by seder/masechta/perek, with parent-controlled learning order and immutable progress (once complete, locked forever).

**Cloud-first architecture:** Firebase backend provides automatic backup, seamless device transfer, and parent account recovery while remaining free and scaling effortlessly from personal use to Play Store release.

**Technology meets tradition:** Leverages a tech-savvy child's natural engagement with apps to serve the traditional goal of completing Shas Mishnayos for bar mitzvah.

---

## Target Users

### Primary User: The Bar Mitzvah Child

**Persona: Yisroel Meir Niasoff (10 years old)**

Yisroel Meir is a tech-savvy 10-year-old preparing for his bar mitzvah on 19 Kislev, 5789 (December 7, 2028). He has approximately 3 years to complete all 4,300 Mishnayos of Shas, requiring consistent daily learning with proper chazara (review).

**Context & Challenges:**
- Learns independently with flexible scheduling (not tied to specific times)
- Prefers quick learning sessions rather than long study marathons
- Currently inconsistent - sometimes forgets, needs occasional pushing
- Finds the sheer number (4,300) overwhelming and abstract
- Lacks visible progress indicators to see his achievement

**Motivation Profile:**
- Excited by seeing numbers go up (completion counts, points accumulating)
- Loves unlocking surprises and mystery rewards
- Gets deep satisfaction from completing tasks and ticking them off
- Motivated by streak counters showing consecutive days of learning
- Appreciates technology and will engage with a well-designed app

**Success Vision:**
What makes Yisroel Meir say "this is exactly what I needed":
- Opens the app and sees HIS name, HIS bar mitzvah date - feels personal
- Can immediately tick off completed Mishnayos - instant satisfaction
- Sees his streak building - "I'm actually doing this every day!"
- Watches progress bars fill up - 4,300 feels achievable, not overwhelming
- Mystery rewards keep him curious and motivated
- Feels ownership of his bar mitzvah journey

### Secondary Users: Parents

**Persona: Mother & Father (shared login)**

Both parents share equal responsibility and use the same parent account to support Yisroel Meir's learning journey.

**Role & Involvement:**
- Mostly hands-off approach - this is Yisroel Meir's achievement, not theirs
- Primarily use parent mode to add rewards to the catalog as he progresses
- Occasional monitoring to ensure he's keeping up with the pace
- Trust him to own his daily learning routine

**What They Need:**
- Simple parent dashboard showing:
  - Is he keeping up with target pace?
  - Overall completion percentage
  - Current streak and engagement
- Easy reward management (add prizes, set point thresholds, keep them hidden)
- Minimal time investment - quick glances, not daily oversight
- Peace of mind that the 3-year goal is achievable

**Success Vision:**
Parents feel successful when:
- Yisroel Meir opens the app daily without prompting
- They see consistent progress over weeks and months
- The app handles motivation so they don't have to push constantly
- He feels proud of his achievement and stays on track for bar mitzvah

### Supporting User: Tutor

**Persona: Learning Tutor/Rebbe**

A tutor who helps Yisroel Meir with Mishnayos learning and needs visibility into progress to support effective teaching.

**Role & Needs:**
- Tracks which Mishnayos have been completed (learning + chazara stages)
- Sees what's due for chazara to focus tutoring sessions appropriately
- Monitors overall progress to adjust teaching approach
- Uses progress data to celebrate achievements and address gaps

**Access Model:**
- Shared login or view-only access to progress dashboard
- Needs real-time data on learning status
- Can see which sedarim/masechtos are in progress

**Success Vision:**
Tutor feels successful when:
- Can quickly see what Yisroel Meir has completed since last session
- Knows which Mishnayos need chazara focus
- Can align tutoring sessions with the app's scheduling
- Watches Yisroel Meir stay motivated and on track

### User Journey

**Discovery & Onboarding (Yisroel Meir):**
1. **Introduction:** Father presents the app - "We built something special for your bar mitzvah"
2. **First Open:** Sees his name, his Hebrew bar mitzvah date, realizes this was made FOR HIM
3. **Setup:** Parents configure bar mitzvah date, learning order, initial rewards
4. **First Completion:** Marks his first Mishna as learned → sees animation, earns points → immediate satisfaction

**Daily Usage (Yisroel Meir):**
1. Opens app at flexible time during his day
2. Dashboard shows: "Today's Tasks: 4 new learning, 3 chazara 1, 2 chazara 2"
3. After learning each Mishna → taps to complete → satisfying tick animation + points popup
4. Watches progress bars fill, sees streak counter increment
5. Checks progress to next mystery reward - building anticipation

**The "Aha!" Moment (Days 5-7):**
- Yisroel Meir opens the app and sees "Current Streak: 6 days 🔥"
- Realizes: "I'm actually doing this every day! I can keep going!"
- The 4,300 no longer feels impossible - he sees masechtos completing
- Feels ownership and pride in his visible progress

**Long-Term Integration (Weeks/Months):**
- App becomes part of daily routine (like brushing teeth)
- Streak becomes precious - doesn't want to break it
- Earns first mystery reward → excitement → motivated for next one
- Sees himself ahead of pace → confidence boost
- Approaching bar mitzvah with completion in sight

**Parent Journey:**
1. **Setup:** Enter parent PIN, configure initial rewards catalog
2. **Ongoing (weekly/monthly):** Log in to add new rewards as he progresses
3. **Monitoring (occasional):** Quick dashboard check - "Is he keeping up? Overall completion?"
4. **Reward Moments:** When notification "Mystery reward earned!" → reveal the surprise
5. **Success:** Minimal intervention needed, Yisroel Meir owns his journey

**Tutor Journey:**
1. **Access:** Given login credentials or view-only dashboard access
2. **Weekly Check:** Before tutoring sessions, reviews progress
3. **Teaching Focus:** Sees which Mishnayos need chazara, aligns session content
4. **Progress Monitoring:** Tracks overall pace to adjust teaching support
5. **Celebration:** Acknowledges completed masechtos and milestones

---

## Success Metrics

### User Success Metrics

Success for **Mishnayos Tracker** is measured entirely by whether Yisroel Meir achieves his bar mitzvah goal of completing all Mishnayos of Shas by 19 Kislev, 5789. The following metrics indicate the app is creating value:

**1. Engagement Metrics - "He uses it"**
- **Daily app opens:** Yisroel Meir opens the app consistently without parental reminders
- **Streak length:** Building consecutive days of usage (target: multi-week and multi-month streaks)
- **Weekly active usage:** Using the app at least 5-6 days per week

**2. Learning Effectiveness - "It helps him learn"**
- **Daily task completion rate:** Percentage of recommended daily tasks actually completed
- **3-stage completion consistency:** Following through on learning + both chazara cycles (not just learning new content)
- **Chazara adherence:** Completing chazara on schedule (next day for chazara 1, 7 days later for chazara 2)
- **Task abandonment rate:** Low rate of started-but-not-completed sessions

**3. Increased Learning Volume - "He learns more because of it"**
- **Total Mishnayos completed per week/month:** Sustained completion rate over time
- **Pre-app vs post-app comparison:** Improved consistency compared to sporadic pre-app learning
- **Sustained motivation:** Usage doesn't drop off after initial excitement (weeks 2-4 are critical)
- **Voluntary extra learning:** Completing beyond recommended daily tasks (indicates genuine engagement)

**4. On-Track Status - "He's on time for his bar mitzvah"**
- **Pace indicator:** Days ahead/on-pace/behind target completion rate
- **Percentage complete vs time elapsed:** E.g., 33% complete by 1 year mark
- **Projected completion date:** Based on current pace, will he finish before 19 Kislev, 5789?
- **Buffer maintenance:** Staying ahead of minimum pace to allow for sick days, vacations, etc.

### Key Performance Indicators

**Critical Milestones:**

**1 Week Mark:**
- Still opening app daily? ✓
- First streak established (7 days)? ✓
- Completing recommended daily tasks? ✓
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

**Ultimate Success Measure:**

**By 19 Kislev, 5789 (December 7, 2028):**
- ✓ All Mishnayos of Shas completed (learning stage)
- ✓ All Mishnayos completed chazara 1
- ✓ All Mishnayos completed chazara 2
- ✓ **Complete 3-stage learning cycle for entire Shas**
- ✓ Yisroel Meir arrives at his bar mitzvah having mastered Shas Mishnayos

**Secondary Success Indicators:**
- Yisroel Meir feels proud of his achievement
- Learning became a positive daily habit, not a burden
- Parents didn't need to constantly push or remind
- The journey built discipline and confidence for bar mitzvah and beyond

### What "Winning" Looks Like

**The app succeeds when:**
1. Yisroel Meir opens it daily without being asked
2. His streak counter becomes something he's proud of and protects
3. He stays on pace (or ahead) for his bar mitzvah deadline
4. The total number of Mishnayos feels achievable rather than overwhelming
5. He completes his bar mitzvah goal on 19 Kislev, 5789
6. The habit of daily Torah learning is established for life

**The app fails if:**
1. Yisroel Meir stops using it after initial excitement (week 2-4 drop-off)
2. Usage requires constant parental reminders and pushing
3. He falls significantly behind pace with no recovery
4. Chazara cycles are skipped (learning without retention)
5. Motivation wanes and the goal feels impossible again
6. He doesn't complete Shas Mishnayos by his bar mitzvah

---

## MVP Scope

### Core Features (v1.0 - Full Release)

**1. Complete Mishna Database with Text Display**
- Accurate database of all Mishnayos organized by seder/masechta/perek with actual counts
- Integration with Sefaria API to display actual Mishna text (Hebrew and English)
- Navigate and browse all Mishnayos by hierarchical structure
- Proper organization reflecting the structure of Shas

**2. 3-Stage Learning Cycle Tracking**
- Track complete learning journey: Learning → Chazara 1 (next day) → Chazara 2 (7 days later)
- Immutable progress tracking (once a stage is marked complete, it's locked forever)
- Automatic scheduling of chazara based on completion dates
- Visual stage indicators showing which stage each Mishna is in

**3. Smart Adaptive Scheduler**
- Calculate optimal daily recommendations based on bar mitzvah deadline (19 Kislev, 5789)
- Recommend balanced daily mix (new learning + chazara 1 + chazara 2)
- Adaptive pacing algorithm that adjusts if child falls behind or accelerates ahead
- Intelligent chazara pile-up management (reduces new learning when reviews accumulate)
- Projects completion date and tracks on-pace/ahead/behind status

**4. Comprehensive Progress Visualization**
- Multi-view dashboard:
  - Overall completion percentage
  - Progress by Seder (6 visual segments)
  - Progress by Masechta (detailed breakdown)
  - Days to bar mitzvah (Hebrew date countdown)
  - Current streak (consecutive days learning)
  - On-track status indicator
  - Points total and trend
- Hebrew calendar integration (19 Kislev, 5789 primary display)
- Completion dates tracked in Hebrew calendar

**5. Balanced Gamification System**
- Points awarded for completing each learning stage
- Configurable point values (parent-controlled)
- Mystery rewards system (parent-configured, hidden from child)
- Progress bar showing points needed for next surprise reward
- Satisfying animations and feedback for task completion
- Streak counter to build daily habit

**6. Parent Mode (PIN-Protected)**
- Separate PIN for parent access
- Reward catalog management (add/edit/remove rewards, set point thresholds)
- Configure masechta learning sequence (parent controls order)
- Point value configuration
- Analytics dashboard:
  - Overall progress and completion metrics
  - On-track status
  - Engagement metrics (streak, consistency)
  - Projected completion date
- Minimal time investment required (hands-off design)

**7. Tutor Access (Separate PIN)**
- Separate PIN for tutor (different from parent PIN)
- View-only access to progress tracking
- See completed Mishnayos by stage (learning, chazara 1, chazara 2)
- View what's due for chazara to align tutoring sessions
- Track overall progress to adjust teaching support
- Real-time sync with child's progress

**8. Cloud-First Architecture (Firebase)**
- Firebase Authentication for parent account
- Cloud Firestore for real-time data sync
- Automatic backup (no data loss risk)
- Seamless device transfer (login on new device, all data restored)
- Offline-first (SQLite local cache, syncs when online)
- Parent account recovery (password reset via email)
- Free tier sufficient for usage scale

**9. Personalized Experience**
- App personalized with "Yisroel Meir Niasoff"
- Bar mitzvah date: 19 Kislev, 5789 (December 7, 2028)
- Hebrew calendar primary throughout app
- Built specifically for his journey

**10. Daily Engagement Features**
- Push notifications for daily learning reminders
- Configurable reminder times
- Today's recommended tasks prominently displayed
- Quick-access to resume learning
- Browse mode to explore full Mishna structure

**11. Technical Foundation**
- Flutter + Dart for cross-platform Android development
- Material Design 3 UI (polished, native feel)
- Riverpod state management
- SQLite local database with Cloud Firestore sync
- Sefaria API integration for Mishna text
- Hebrew calendar library integration
- Push notification system

### Out of Scope (Not Planned)

The following features are **not planned** for any version:

- ❌ Multi-user support for other families (v1.0 hardcoded for Yisroel Meir)
- ❌ Hebrew language UI (app interface remains English)
- ❌ iOS version (Android only)
- ❌ Social features, leaderboards, or community sharing
- ❌ Audio playback of Mishnayos
- ❌ Study notes or annotations within the app
- ❌ Integration with other learning platforms
- ❌ Advanced analytics or export features beyond basic dashboard

### MVP Success Criteria

**v1.0 is successful if:**

1. **Week 1:** Yisroel Meir uses the app daily without prompting
2. **Month 1:** Daily habit established (5-6 days/week minimum)
3. **Month 3:** Sustained engagement, on-track for bar mitzvah deadline
4. **Month 6:** Multiple masechtos completed, motivation maintained
5. **Ultimate:** Completes all Mishnayos with full chazara cycles by 19 Kislev, 5789

**Technical Success:**
- App performs smoothly on Android devices
- Firebase sync works reliably
- Sefaria API integration provides accurate Mishna text
- Smart scheduler calculates accurate recommendations
- No data loss over 3-year usage period

**Decision Point:**
If Yisroel Meir successfully completes his bar mitzvah goal using the app, evaluate whether to generalize for public release.

### Future Vision (Post-v1.0 Success)

**If v1.0 succeeds with Yisroel Meir:**

**v2.0 - Public Release (Play Store):**
- Generalize the app for other families
- Setup wizard: enter child's name, bar mitzvah date (Hebrew)
- Multi-user support with Firebase user isolation
- Each family gets private, isolated data
- Free on Google Play Store (no ads, no subscriptions)
- Privacy policy and terms of service
- Beta testing group for validation
- Crash reporting and analytics (Firebase Crashlytics)

**Potential Enhancements (if community requests):**
- Hebrew language UI option
- Customizable learning goals (beyond bar mitzvah)
- Parent-child progress sharing features
- Community-contributed reward ideas
- Multiple children per family account

**Long-Term Vision:**
Make Mishnayos Tracker the go-to free app for Jewish families preparing their sons for bar mitzvah, helping thousands of children complete Shas Mishnayos through consistent daily learning habits supported by respectful gamification.

