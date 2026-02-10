---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - '_bmad-output/planning-artifacts/product-brief-learning-tracker-2026-01-03.md'
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/architecture-v1-2026-01-04.md'
  - '_bmad-output/planning-artifacts/epics.md'
  - '_bmad-output/project-context.md'
project_name: 'learning-tracker'
user_name: 'Daniel'
date: '2026-02-08'
---

# UX Design Specification learning-tracker

**Author:** Daniel
**Date:** 2026-02-08

---

## Executive Summary

### Project Vision

Learning Tracker is a multi-curriculum Torah learning Android app that transforms large-scale learning goals into achievable daily habits. Built with Flutter (Material Design 3, RTL Hebrew support), the app tracks configurable N-stage learning cycles across five Sefaria-sourced curricula (Mishnayos, Gemara Bavli, Yerushalmi, Mishna Berurah, Chumash) with per-curriculum adaptive scheduling, multi-track learning, and account-based multi-device sync. The app serves both children (full gamification, parent oversight) and adults (streamlined, self-directed) through a single codebase with mode-based feature gating.

### Target Users

**Primary — Children (10-13):** Bar mitzvah-age learners who need daily engagement and visible progress to maintain motivation across months/years of structured learning. Full gamification (mystery rewards, streaks, animations), parent-managed rewards, multi-context tracking (personal, school, tutor).

**Primary — Adults:** Self-directed Torah learners pursuing goals across one or more curricula. Prefer clean, data-focused UI with intelligent scheduling and multi-device sync. Optional engagement features, no parent mode.

**Secondary — Parents:** Minimal-effort oversight through PIN-protected parent mode (child accounts only). Manage rewards, monitor pace, configure tracks. Weekly check-ins, not daily management.

**Supporting — Tutors:** Read-only PIN-protected access to completion history, chazara status, and progress metrics. Available for both child and adult accounts.

### Key Design Challenges

1. **Complexity vs. simplicity tension:** Deep configurability (N-stage cycles, multi-track, per-curriculum goals, drag-and-drop learning order) must coexist with an effortless daily experience. The dashboard must distill multiple curricula, tracks, and stages into a clear "here's what to do today."

2. **Dual-mode UX:** Child and adult modes share core flows but require fundamentally different emotional tones — celebratory and reward-driven vs. clean and data-focused — affecting animations, language, information density, and visual weight throughout the app.

3. **Hebrew/English bidirectional text:** Every content screen mixes RTL Hebrew with LTR English. Navigation, hierarchy names, and content text must handle BiDi gracefully without layout breaks on mobile screens.

4. **Deep hierarchy navigation:** Five curricula with up to 4 levels of hierarchy create significant navigation depth. Users need efficient drill-down without losing positional context.

5. **Information density on mobile:** Cross-curriculum dashboard, per-curriculum progress, pace tracking, streak, points, and chazara queues compete for limited screen real estate on 5" phones.

6. **Onboarding complexity:** First-time setup spans mode selection, curriculum activation, content import, goal setup, bulk marking, and rewards configuration — must feel guided, not overwhelming.

### Design Opportunities

1. **Daily plan as hero experience:** The cross-curriculum daily schedule composer is the unique differentiator. Making this the primary screen interaction (open → see tasks → complete → feel progress) creates a powerful daily habit loop.

2. **Progressive disclosure of power features:** Stage configuration, learning order customization, and multi-track management are power features best surfaced contextually rather than front-loaded during setup.

3. **Emotionally satisfying completion feedback:** Marking an item complete is the core interaction repeated thousands of times. Making this moment rewarding (scaled by user mode) is the highest-leverage UX investment for retention.

4. **Curriculum-as-identity:** Distinct visual identity per curriculum (color coding, iconography) makes the cross-curriculum dashboard scannable at a glance and gives users a sense of parallel journeys progressing together.

## Core User Experience

### Defining Experience

**Core Action:** Mark a learning item as complete — the atomic interaction repeated thousands of times across the app's lifetime. Completion commits on tap — the feedback animation is decorative, not confirmatory. If the animation is interrupted (app close, phone call), the completion is already saved. No "did it save?" anxiety.

**Core Loop:** Open app → see today's tasks → mark items complete → feel progress → come back tomorrow.

**Hero Screen:** The cross-curriculum daily task list is the app's centerpiece. It answers the only question that matters each day: "What should I learn right now?" The scheduler does the thinking; the user does the learning.

**Micro-Loop (3-second cycle):** Tap to mark complete → instant satisfying feedback (animation, points, progress bar movement) → next task surfaces automatically. This rapid complete-feedback-next cycle is the engine that drives daily engagement and long-term habit formation.

**Three Completion Contexts:**
- **Scheduled completions (daily task flow):** Single-tap, zero decisions. The scheduler pre-resolves curriculum, item, stage, and track — the user just confirms completion. This is the hero path optimized for speed and flow.
- **Ad-hoc completions (content browsing):** Requires stage and track context. When a user browses the hierarchy and marks something complete outside the daily plan, the UI must collect stage and track selection. This path prioritizes clarity over speed.
- **Bulk completions (multi-select):** Multi-item selection with batch confirmation. Used during onboarding (marking prior completions) and ongoing use (marking multiple items from a tutor session or catch-up). Stage selection first, then multi-select items, then single batch confirm. For large batches (e.g., 200+ items during onboarding), a progress indicator shows the write operation. A single summary animation plays on completion, not per-item.

**Navigation Model:** The app's navigation structure (bottom nav, screen hierarchy, transition patterns) is defined in the User Journeys and Screen Architecture sections of this document.

### Platform Strategy

**Platform:** Android mobile app (Flutter, Material Design 3), v1.0 Android only.

**Input Model:** Touch-first. All primary interactions (mark complete, navigate hierarchy, view progress) optimized for one-handed phone use. Drag-and-drop for learning order customization uses standard mobile gesture patterns.

**Screen Targets:** 5" phones (primary) through 10" tablets (supported). Portrait primary, landscape supported for progress chart views.

**Calendar System:** Jewish calendar (via kosher_dart) is the primary date system for all user-facing display. Hebrew dates are shown more prominently than Gregorian dates by default (configurable per user preference). Streak day boundaries, goal deadlines, and milestone tracking all reference the Jewish calendar day. Internal storage remains UTC; conversion to Jewish calendar dates happens in the presentation layer. Shabbos/Yom Tov awareness is built into scheduling and notification quiet mode.

**Offline-First:** All core features work without network. Content browsing, marking completions, viewing progress, smart scheduler — all fully functional offline. Sync happens transparently in the background when connectivity is available.

**Multi-Device Sync UX:** When data arrives from another device, the UI refreshes gracefully — no jarring disappearance of tasks mid-view. A subtle sync status indicator shows connection state. If the user is viewing stale data (e.g., opened tablet before phone synced), newly synced completions merge smoothly with a brief toast ("Synced from another device") rather than a disruptive full-screen reload.

**Device Capabilities Leveraged:**
- Local notifications for daily reminders and streak protection alerts
- Secure storage for PIN hashing (parent/tutor modes)
- SQLite for offline-first data persistence
- Touch haptics as optional enhancement for completion feedback (not relied upon — visual and audio feedback must stand alone, as haptic consistency varies across mid-range Android devices)

### Effortless Interactions

**Zero-thought actions (must feel automatic):**
- **Knowing what to learn today:** Open app, daily tasks are immediately visible framed in the Jewish calendar day — no navigation, no decisions
- **Marking scheduled completion:** Single tap per item in daily task flow. No confirmation dialogs, no stage/track selection — context is pre-resolved
- **Seeing progress:** Dashboard loads instantly with current state across all curricula
- **Chazara scheduling:** System automatically surfaces review items at the right time based on stage timing — user never manually schedules reviews
- **Recovery from behind:** After missed days, the scheduler adapts gracefully and presents an adjusted forward plan — no manual reconfiguration, no overwhelming overdue backlog. The UI shows "here's today's plan" not "you missed 12 tasks"

**Background automation (services running transparently):**
- Scheduler recalculates daily recommendations when completions change (optimistic UI update shown instantly; full recalculation reconciled in background across all active curricula). Newly generated tasks (e.g., a chazara item now due) appear on the next app open or screen refresh, not mid-session — avoids disorienting task list mutations while the user is actively working
- Bookmark advances to next item automatically after first-stage completion
- Streak updates with any curriculum completion (global, not per-curriculum)
- Sync pushes to cloud silently on every local write
- Points accumulate and mystery reward progress updates in real-time
- Jewish date calculations handled automatically — user sees Hebrew dates without manual conversion. Shabbos/Yom Tov quiet mode suppresses notifications based on Jewish calendar

**Smart defaults (presentation-layer decisions):**
- Track auto-assignment when only personal track is active (no track picker needed)
- Smart defaults for stage configuration (learn + 2 chazara stages) — customize only if desired
- Curriculum content imports with progress indicator, not blocking setup flow
- Onboarding steps skippable where possible (goals, bulk mark, rewards)

**Key empty states:**
- **All tasks done for today:** A deliberate success screen, not a bare empty state. Child mode: celebratory "finish line" moment with daily achievement summary. Adult mode: clean "You're done for today" confirmation with optional stats. This is the daily goal state the user works toward
- **Zero curricula activated:** Guided prompt to select and activate first curriculum. Appears after account creation if onboarding was interrupted before curriculum selection
- **No completions yet (new curriculum):** Welcome message with first task highlighted. Progress shows "0 of X — let's begin"

### Critical Success Moments

**First completion (onboarding):** The user marks their very first item as learned. Completion animation plays, points counter appears and increments, progress bar animates from 0% to its first visible increment. This is the "I can do this" moment — it must feel immediate and satisfying.

**Day 7 streak:** "Current Streak: 7 days" with a visual milestone marker. The streak counter transitions from a number to something worth protecting. Child mode: celebratory animation. Adult mode: quiet acknowledgment badge.

**Streak milestones (30, 100 days, full Jewish year):** Major streak achievements receive designed celebration moments scaled by user mode. Milestones are measured in Jewish calendar days, with the full Jewish year milestone (variable length) as the pinnacle achievement. Child mode: special animation, bonus points. Adult mode: milestone badge, acknowledgment.

**First section complete:** A full perek, masechta section, or equivalent is done. The hierarchy-level progress view shows the completed section filled in, with the parent level's progress bar jumping visibly. Large goals start feeling achievable.

**Mystery reward earned (child mode):** Points cross a threshold, reward progress bar fills completely, reward notification fires with anticipation-building animation. The reward itself stays hidden until the parent reveals it — building suspense.

**Pace check confidence:** Pace indicator shows "5 days ahead" in green with projected completion date (Hebrew date primary, Gregorian secondary) well within the goal window. Confidence that the system is working and the goal is achievable.

**Recovery from behind:** User returns after missing several days. Instead of an overdue task count, the scheduler presents a recalculated daily plan that accounts for the gap. The dashboard shows today's adapted plan with a subtle "Adjusted for you" indicator. No guilt, just a forward path.

**Streak break resilience:** When a streak breaks, the display shows "Best streak: 47 days" prominently alongside "Current streak: 1 day." Child mode frames it as "New adventure begins!" with encouraging copy. Adult mode shows it matter-of-factly. The streak counter never displays a bare "0" without the best-streak context to anchor achievement.

**Multi-device continuity:** User switches from phone to tablet. After a brief sync, all progress is current. Completed tasks are gone, new daily plan reflects latest state. A subtle "Synced" indicator confirms data is fresh. The experience feels like one continuous session across devices.

**Make-or-break flows:**
- **Onboarding completion:** If the user doesn't finish setup and mark their first item, they never come back
- **Daily task loading:** If the daily plan takes more than 1-2 seconds to appear or feels overwhelming, the habit breaks
- **Multi-curriculum clarity:** If the dashboard confuses rather than clarifies across curricula, users retreat to single-curriculum use or abandon
- **Pile-up recovery:** If returning after a break feels punishing rather than supportive, the user abandons
- **Streak break moment:** If losing a streak feels devastating rather than motivating to rebuild, engagement drops permanently
- **Multi-device sync lag:** If switching devices shows contradictory or stale state without clear resolution, trust in the system erodes

### Mode Transitions

**Parent mode entry/exit (child accounts):** Entering parent mode via PIN shows a clear visual shift (e.g., distinct header color, "Parent Mode" label). Exiting parent mode returns to the child's view with a confirmation transition ("Returning to [child name]'s view") ensuring the parent knows the child can no longer see settings.

**Tutor mode entry/exit:** Similar pattern — distinct visual identity while in tutor mode, clear exit confirmation back to the learner's view.

**User mode switch (child ↔ adult in settings):** Switching user mode in settings triggers a confirmation dialog explaining what changes (gamification level, parent mode availability). After confirmation, the UI updates to reflect the new mode immediately. No data loss — only presentation changes.

### Experience Principles

1. **"Show me what to do now"** — The app always answers the immediate question. Daily tasks are the default view, framed in the Jewish calendar day. No navigation required to start learning. The scheduler decides; the user acts.

2. **"Every tap matters"** — Each completion is acknowledged instantly with mode-appropriate feedback. No action should feel invisible. Progress is always moving forward, visibly. Visual feedback stands alone — never depend on device capabilities that may be unreliable.

3. **"Simple by default, powerful when needed"** — Core daily flow requires no configuration knowledge. Scheduled completions are single-tap; ad-hoc completions gracefully collect needed context; bulk completions enable efficient batch operations. Power features are discoverable but never in the way.

4. **"One app, two voices"** — Child mode celebrates; adult mode informs. Same data, same flows, different emotional register. Neither mode feels like a compromise. Mode boundaries (parent, tutor) are visually clear.

5. **"Earned trust"** — The scheduler, chazara timing, and pace tracking work reliably day after day. Recommendations are accurate. Data syncs correctly across devices. Users build confidence through consistent, correct behavior.

6. **"Resilience trust"** — When life disrupts the routine — missed days, broken streaks, pace slippage — the system adapts supportively. Recovery feels like a fresh start with a smart plan, not a consequence for falling behind.

## Desired Emotional Response

### Primary Emotional Goals

**For Children (10-13):**
- **Empowered and capable:** "I can do this big thing" — large-scale learning goals feel achievable through daily small wins
- **Excited to come back:** Mystery rewards, streak protection, and visible progress create anticipation for tomorrow's session
- **Proud of accomplishment:** Every completion is celebrated; progress is always moving forward visibly

**For Adults:**
- **Calm confidence:** The system handles complexity (scheduling, chazara timing, multi-curriculum coordination) so the user can focus purely on learning
- **Quiet satisfaction:** Progress accumulates steadily; the data tells the story without fanfare
- **Trust in the system:** Recommendations are accurate, sync is reliable, the scheduler adapts intelligently

**For Parents:**
- **Peace of mind:** Child is engaged and progressing without requiring daily parental management
- **Shared pride:** Reward reveal moments create parent-child connection around the learning journey

**For Tutors:**
- **Professional confidence:** Clear, accurate data to inform teaching decisions
- **Shared investment:** Seeing a student's progress validates the tutoring relationship

### Emotional Journey Mapping

| Stage | Child Emotion | Adult Emotion |
|-------|--------------|---------------|
| **First open** | Curiosity + excitement | Interest + "this looks manageable" |
| **Onboarding** | "This is easy!" | "This respects my time" |
| **First completion** | Instant delight | Quiet confirmation |
| **Daily return** | Anticipation (what's today?) | Routine confidence |
| **Mid-goal progress** | Growing pride | Steady satisfaction |
| **Streak milestone** | Celebration + protection instinct | Achievement acknowledgment |
| **Behind on pace** | Gentle encouragement | Adjusted plan, no judgment |
| **Streak break** | "New adventure!" | Matter-of-fact reset with best-streak context |
| **Goal completion** | Peak celebration | Deep accomplishment |
| **Something goes wrong** | Protected from frustration | Confident it will resolve |

### Micro-Emotions

**Critical micro-emotion pairs (design must land on the left side):**

- **Confidence** vs. Confusion — Navigation, hierarchy browsing, and daily task presentation must never leave the user wondering "what do I do?"
- **Accomplishment** vs. "So what?" — Every completion must register as meaningful progress, not a checkbox exercise
- **Trust** vs. Skepticism — Scheduler recommendations, pace projections, and sync status must feel reliable from day one
- **Achievability** vs. Overwhelm — Never show raw total counts to learners. "Perek 3 of Maseches Brachos" not "item 47 of 4,192." Frame progress in human-scale units (current section, current masechta) not absolute numbers
- **Delight** vs. Monotony — The 500th completion must feel as recognized as the 5th, even if the celebration is subtler
- **Belonging** vs. Isolation — Multi-track awareness (personal, school, tutor) reinforces that learning happens in community context

### Relational Emotional Moments

**Parent-child reward reveal:** The mystery reward system creates a designed moment of connection. The child earns the reward through learning; the parent reveals it. This shared moment — child's anticipation meeting parent's pride — is an emotional peak the app deliberately enables.

**Tutor viewing progress:** When a tutor opens their PIN-protected view and sees completion history and chazara status, the data tells a story of the student's dedication. The tutor's emotional response (pride, insight, informed planning) feeds back into better teaching, which the student feels.

**Multi-device family awareness:** When a parent sees "Synced from another device" on the tablet, it carries an implicit message: the child was learning on their own. This ambient awareness of learning activity is emotionally valuable even without explicit notification.

### Celebration Tiers

**Tier 1 — Daily/Subtle (every completion):**
- Child: Quick satisfying animation, points increment, progress bar movement
- Adult: Clean checkmark, progress update, minimal motion
- Frequency: Multiple times per session — must never feel heavy or slow

**Tier 2 — Periodic/Moderate (section completions, weekly streaks, pace milestones):**
- Child: Notable animation, bonus points, achievement badge
- Adult: Milestone marker, progress summary, quiet badge
- Frequency: Every few days to weekly — noticeable but not disruptive

**Tier 3 — Rare/Full Celebration (masechta completion, 100-day streak, goal completion, full Jewish year streak):**
- Child: Special animation sequence, major reward progress, designed celebration moment
- Adult: Significant acknowledgment, milestone badge, achievement summary
- Frequency: Weeks to months apart — these are peak emotional moments worth designing for

### Emotional Anti-Patterns (Never Make the User Feel...)

- **Guilty:** No "you missed 12 tasks" messaging. Recovery shows a forward path, not a deficit
- **Overwhelmed:** No raw counts of remaining items. Progress framed in current context, not total scope
- **"So what?":** No completion without feedback. Every action registers visibly
- **Patronized:** Adult mode never uses childish language or unnecessary celebration. Child mode never talks down
- **Diminished:** Streak breaks show best-streak context. Behind-pace shows adjusted plan. The system always frames the user's position constructively

### Design Implications

**Emotional goal → UX design approach:**

- **Empowerment** → Daily task list pre-resolves all decisions; single-tap completion; "here's what to do" not "figure out what to do"
- **Calm confidence** → Consistent, predictable UI patterns; reliable scheduler; transparent sync status
- **Achievability** → Progress shown in human-scale units (current perek, current masechta); never expose raw totals; progressive disclosure of scope
- **Trust** → Pace indicator with projected completion date (Hebrew date primary); streak counter always visible; sync status indicator
- **Delight** → Mode-appropriate completion animations; mystery reward anticipation; streak milestone celebrations
- **Resilience** → Recovery messaging focuses on "here's today's plan" not "here's what you missed"; streak break shows best-streak alongside current; pace recalculation is automatic and supportive

### Emotional Design Principles

1. **"Celebrate the journey, not just the destination"** — Daily completions matter as much as masechta completions. The 3-tier celebration framework ensures every scale of achievement is emotionally recognized appropriately.

2. **"Frame everything as forward motion"** — Behind on pace? Here's the adjusted plan. Streak broke? New streak starts now (with best-streak context). Missed days? Today's plan accounts for it. The UI always points forward.

3. **"Match the emotional register to the user"** — Child mode celebrates with energy and excitement. Adult mode acknowledges with quiet confidence. Neither feels like a compromise. Same data, different emotional wrapper.

4. **"Build trust through consistency"** — Emotional reliability matters as much as data reliability. The app should feel the same — predictable, supportive, clear — on day 1 and day 365. No bait-and-switch between onboarding and daily use.

5. **"Protect from negative emotions as deliberately as we design positive ones"** — The emotional anti-patterns checklist is as important as the celebration tiers. Preventing guilt, overwhelm, and "so what?" requires active design decisions, not just absence of bad patterns.

6. **"Design for the relational, not just the individual"** — The app exists in a context of relationships (parent-child, tutor-student). Emotional moments that strengthen these relationships (reward reveals, progress sharing) multiply the app's value beyond individual use.

## UX Pattern Analysis & Inspiration

### Direct Competitors Analysis

**Existing Torah tracking apps** (Shas Tracker, Mishnah Yomit trackers, yeshiva-specific apps):
- **What they offer:** Basic completion tracking, typically single-curriculum, manual entry, calendar-based marking
- **What they lack:** No intelligent scheduling, no adaptive chazara management, no multi-curriculum coordination, no dual child/adult modes, no gamification, no multi-device sync, no pace tracking
- **Our differentiation:** The category of *smart multi-curriculum scheduling with adaptive chazara* doesn't exist yet. Existing apps are digital checkboxes; Learning Tracker is an intelligent learning companion that tells you what to do today across all your curricula and manages your review cycles automatically. This isn't "better UX on an existing concept" — it's a new category of tool.

### Inspiring Products Analysis

**Duolingo — Daily Learning Habit Engine**
- **What it nails:** The daily streak as retention mechanic. Streak freeze / recovery mechanics that reduce streak-break anxiety. The "just one more lesson" micro-loop keeps sessions short but frequent. Scaled celebration (lesson complete → level complete → crown complete) maps directly to our 3-tier celebration framework.
- **Key UX pattern:** Open → see today's task → do it → feel progress → close. The entire session can be under 5 minutes. This is critical for Learning Tracker because children are borrowing a parent's phone — sessions must be efficient, not sprawling.
- **What to learn:** Streak recovery mechanics, session brevity as a feature, making the daily return feel effortless.
- **What to avoid:** Duolingo's aggressive notification strategy and guilt-tripping owl ("These reminders don't seem to be working") directly conflicts with our emotional anti-patterns. Their hearts/lives system creates anxiety — we want confidence, not fear of failure.

**Sefaria — Torah Content Navigation**
- **What it nails:** Deep hierarchy navigation through the Torah corpus. Hebrew/English bilingual text handling. Breadcrumb-style positional awareness ("Brachos > Perek 1 > Mishna 3"). Content depth and accuracy.
- **Key UX pattern:** Users already have mental models for navigating Torah content hierarchy. The transferable pattern isn't Sefaria's specific UI — it's that users expect a drill-down that matches the traditional structure of each corpus. Mishnayos: Seder → Masechta → Perek → Mishna. Gemara Bavli: Masechta → Daf → Amud. Mishna Berurah: Siman → Se'if. Chumash: Sefer → Parsha → Perek → Pasuk. Each curriculum's hierarchy should feel natural to someone who learned it traditionally, not forced into a single navigation pattern.
- **What to learn:** Hierarchy breadcrumbs for positional context, Hebrew/English text layout patterns, BiDi text handling conventions that Torah learners already expect.
- **What to avoid:** Sefaria is a reference tool, not a daily habit tool. It has no progress tracking, no daily guidance, no completion state. Our users will come from Sefaria's mental model but need a fundamentally different interaction pattern — action-oriented (mark complete) rather than reference-oriented (browse and read).

**Todoist / Things 3 — Task Completion Satisfaction**
- **What it nails:** The "Today" view as hero screen. Single-tap completion with satisfying visual feedback. Clean information density on mobile. Things 3 in particular demonstrates that a task app can feel calm and focused rather than overwhelming.
- **Key UX pattern — with a critical distinction:** Todoist's "Today" shows all tasks due today. Our daily task list is fundamentally different: it's *curated by the scheduler* — not "everything due" but "what we recommend today." This is a more opinionated model. The scheduler factors in pace, chazara timing, multi-curriculum balance, and goal deadlines to compose a daily plan. Users trust the scheduler's judgment rather than managing their own lists.
- **What to learn:** Completion animation timing and weight. How Things 3 makes checking off a task feel like an accomplishment. How Todoist handles overdue tasks without creating guilt (reschedule, not accumulate).
- **What to avoid:** Both apps assume the user manages their own task list. Learning Tracker's scheduler is the task manager — the user shouldn't need to think about what's next.

**Khan Academy Kids — Shared Device Learning**
- **What it nails:** Designed for children using a parent's device. Quick session entry with minimal friction. Age-appropriate celebration without being patronizing. Progress visible to both child and parent.
- **Key UX pattern:** The shared-device model where a child uses the app on a parent's phone. Sessions are bounded and focused. Parent can check progress without disrupting the child's experience.
- **What to learn:** How to make a child's session feel complete in 3-5 minutes. How to show progress that satisfies both the child (celebration) and parent (data). Quick app entry — minimal taps to start the session.
- **What to avoid:** Khan Academy Kids is fully child-oriented with no adult mode. Their visual language wouldn't work for adult Torah learners. We need the dual-voice approach where the same app serves both audiences.

### Shared-Device Design Implications

Children generally don't have their own smartphones. This constraint shapes multiple design decisions:

**Parent as gatekeeper:** The parent controls when the child uses the app. The child doesn't decide "time to learn" — the parent hands them the phone. This means:
- App launch to first actionable screen must be near-instant
- No login friction for returning sessions (biometric/PIN unlock → straight to daily tasks)
- Session efficiency is respect for the parent's device and patience

**Interrupted session resume:** If a child completes 3 of 5 daily items and the parent takes the phone back, the next session must pick up seamlessly. The daily task list shows "You did 3 earlier today. Here are your remaining 2." No re-orientation needed, no loss of context. The app treats interrupted sessions as normal, not exceptional.

**Notification strategy for child accounts:** Daily reminder notifications go to the parent's phone. The notification copy should address the parent, not the child: "Moshe has 4 items for today" not "Time to learn!" The parent is the activation mechanism for the child's learning session. Streak protection alerts similarly address the parent: "Moshe hasn't learned today yet — streak at risk."

**Session brevity as design constraint:** Design daily sessions to be completable in 3-5 minutes. The child's goal is to finish today's items quickly and hand the phone back. The micro-loop (tap → feedback → next) must be fast enough that 5 completions feel like 2 minutes, not 10.

### Transferable UX Patterns

**Navigation Patterns:**
- **"Today" as home screen** (Todoist/Things 3 adapted) → Daily task list is the app's landing screen. Cross-curriculum tasks pre-assembled by the scheduler. No navigation required to start learning.
- **Corpus-native hierarchy** (Sefaria mental model adapted) → Each curriculum's drill-down follows its traditional structure. Mishnayos users expect Seder → Masechta → Perek → Mishna. Gemara users expect Masechta → Daf → Amud. The navigation feels natural to someone who learned it traditionally, even if the underlying UI components are shared.
- **Bottom navigation with 3-4 destinations** (Material Design 3 standard) → Daily tasks, Curricula/Browse, Progress, Settings. Keep primary navigation flat; depth lives within each destination.

**Interaction Patterns:**
- **Single-tap completion with undo snackbar** (Todoist/Gmail pattern) → The core interaction. Tap → commit → animate. No confirmation dialog. A brief undo snackbar ("Marked complete" with "Undo" action) displays for ~5 seconds as a safety net. This is the Material Design 3 standard pattern — commit on action, undo as recovery.
- **Streak as retention mechanic** (Duolingo) → Global streak across all curricula. Visual streak counter on the daily screen. Milestone celebrations at 7, 30, 100 days, and full Jewish year. Best-streak context always visible alongside current streak.
- **Borrowed-device session brevity** (Khan Academy Kids) → Design daily sessions to be completable in 3-5 minutes. The micro-loop must be fast enough that completing today's items feels quick and satisfying, not like a chore.
- **Interrupted session continuity** → When a session is interrupted mid-way, the next app open shows remaining items with context: "2 remaining for today." No re-orientation, no loss of progress. Treat partial sessions as the normal shared-device pattern.
- **Graceful overdue handling** (Todoist adapted) → Behind-pace items are rescheduled into the forward plan by the scheduler, not accumulated as a guilt-inducing backlog. "Adjusted for you" indicator, not "12 overdue items."

**Visual Patterns:**
- **Curriculum color coding** (Khan Academy subject colors) → Each curriculum gets a distinct color identity. The daily task list uses color to make cross-curriculum items scannable at a glance. Progress views use the same colors consistently.
- **Progress as filling, not counting** (Duolingo skill tree) → Show progress as visual fill (progress bars, filled sections) rather than raw numbers. "Perek 3 of 12" with a fill bar, not "item 267 of 4,192."
- **Calm density** (Things 3) → Adult mode should feel like Things 3 — clean, focused, information-rich without feeling crowded. Child mode can be more spacious and animated.

### Anti-Patterns to Avoid

- **Guilt-driven retention** (Duolingo's sad owl, "You're losing your streak!") → Conflicts directly with our "never make the user feel guilty" principle. Streak protection alerts should be informational ("Learning today keeps your streak alive"), not guilt-inducing. For child accounts, alerts go to the parent with parent-appropriate copy.
- **Accumulated overdue counts** (most task managers) → Showing "47 overdue items" after a vacation destroys motivation. The scheduler silently absorbs the gap and presents a fresh daily plan.
- **Raw total exposure** (most progress trackers) → "You've completed 267 of 4,192 mishnayos" makes the goal feel impossible. Always frame in human-scale units: current perek, current masechta, percentage of current section.
- **Confirmation dialogs on primary actions** (many Android apps) → "Are you sure you want to mark this complete?" on the action that happens thousands of times would be maddening. Completion commits on tap; undo snackbar provides the safety net.
- **Heavy onboarding before first value** (many learning apps) → If the user must configure 5 things before marking their first completion, most won't finish. Onboarding should get to the first completion moment as fast as possible, with configuration deferred.
- **Notification spam** (Duolingo's aggressive reminders) → One daily reminder at the user's preferred time. Streak protection alert if approaching day-end without completion. No multiple nudges, no escalating urgency, no guilt messaging. Respect Shabbos/Yom Tov quiet mode absolutely. Child account notifications address the parent.

### Design Inspiration Strategy

**What to Adopt Directly:**
- **Duolingo's streak mechanic** with best-streak context and Jewish calendar day boundaries
- **Todoist's "Today" view** as the hero screen pattern — daily tasks are the default, everything else is secondary
- **Things 3's completion interaction** with undo snackbar — single tap, instant satisfying feedback, calm visual language for adult mode
- **Khan Academy Kids' shared-device model** — session brevity, parent-accessible progress, quick entry

**What to Adapt:**
- **Sefaria's hierarchy mental model** → Each curriculum follows its own traditional structure, not a one-size-fits-all navigation
- **Todoist's "Today" concept** → Adapt from "all tasks due" to "scheduler-curated daily plan" — more opinionated, less user-managed
- **Duolingo's celebration scaling** → Map to our 3-tier framework but with mode-appropriate emotional register (child celebratory vs. adult understated)
- **Khan Academy Kids' notification model** → Adapt so child account notifications address the parent as the activation mechanism

**What to Explicitly Reject:**
- **Duolingo's guilt mechanics** (sad owl, aggressive notifications, hearts system) → Conflicts with every emotional anti-pattern we've defined
- **Raw progress numbers** from any tracking app → Always human-scale framing
- **Configuration-heavy onboarding** → Get to first completion fast, defer power features
- **Confirmation dialogs on completion** → Commit on tap, undo snackbar as safety net
- **Child-as-device-owner assumption** → Children borrow parent's phone; design for that reality

## Design System Foundation

### Design System Choice

**Material Design 3 (MD3)** — Flutter's native design system via the `material` library.

This is not a competitive selection — Flutter on Android makes MD3 the natural and correct foundation. The question isn't "which design system?" but "how do we customize MD3 to serve Learning Tracker's unique needs?" MD3 provides the component library, interaction patterns, accessibility baseline, and theming infrastructure. Our work is in the customization layer.

### Rationale for Selection

1. **Flutter-native integration:** MD3 is built into Flutter's `material` library. Every widget, animation, and interaction pattern is first-class. No third-party dependency, no version lag, no compatibility layer.

2. **Android user expectations:** Android users have internalized MD3 patterns — bottom navigation, FABs, cards, snackbars, bottom sheets. Using these patterns means zero learning curve for standard interactions, freeing cognitive budget for Learning Tracker's unique features.

3. **Comprehensive accessibility:** MD3's accessibility compliance (color contrast ratios, touch targets, screen reader semantics, focus management) is built into every component. This is especially critical for our dual-mode app where child mode needs large touch targets and adult mode needs information density — both within accessibility standards.

4. **Dynamic Color / Material You:** Android 12+ Dynamic Color lets the app harmonize with the user's system wallpaper colors while maintaining our curriculum color identity. This creates a feeling of "this app belongs on my phone" without any user configuration.

5. **Theming infrastructure:** MD3's `ThemeData`, `ColorScheme`, and `TextTheme` provide the layering infrastructure needed for our composable theme architecture (mode × curriculum × overlay).

6. **RTL support:** Flutter's MD3 implementation handles RTL layout mirroring, text direction, and icon mirroring natively. Combined with Dart's BiDi text support, this provides the foundation for our Hebrew/English mixed-direction interface.

### Implementation Approach

#### Composable Theme Architecture

The app uses a **three-axis composable theme** that combines independently:

**Axis 1 — Mode Theme (app-wide):**
- **Child mode:** Warmer palette, larger touch targets (minimum 56dp), rounded corners (16dp), more generous spacing, playful motion curves, celebration-forward feedback
- **Adult mode:** Cooler/neutral palette, standard touch targets (48dp), subtle corners (12dp), tighter spacing, restrained motion, data-forward feedback

**Axis 2 — Curriculum Color (per-widget):**
- Each curriculum carries a `ColorScheme` seed color applied at the widget level, not the app level
- Curriculum color appears on: task cards (left border), progress bars, section headers, hierarchy breadcrumbs
- **Five curriculum colors:** Mishnayos, Bavli, Yerushalmi, Mishna Berurah, Chumash — each visually distinct, accessible against both light and dark backgrounds

**Axis 3 — Mode Overlay (chrome-level):**
- **Parent mode:** Distinct header color + "Parent Mode" label — visually unmistakable
- **Tutor mode:** Distinct header color + "Tutor Mode" label
- **Standard learner:** Default chrome, no overlay

**Composition rule:** `ModeTheme(child|adult)` sets the base → `CurriculumColor(per-widget)` tints individual components → `ModeOverlay(parent|tutor|standard)` modifies the app chrome. These layers are independent — changing user mode doesn't affect curriculum colors; entering parent mode doesn't change curriculum identity.

#### Text Directionality Strategy

**RTL content areas, LTR app shell:**
- **App chrome** (bottom nav, app bar, settings, navigation) → LTR layout. Android conventions, Material Design patterns, and most UI labels are English or direction-neutral
- **Content areas** (Torah text, hierarchy names, daily task items) → RTL layout. Hebrew text flows right-to-left with proper Unicode BiDi algorithm handling
- **Mixed-direction cells** (e.g., a task card with Hebrew masechta name + English stage label) → Container is RTL (Hebrew content is primary); English fragments use BiDi embedding marks to display correctly within the RTL flow

**Implementation:** Flutter's `Directionality` widget wraps content areas in `TextDirection.rtl`. The app scaffold remains `TextDirection.ltr`. `TextAlign.start` resolves correctly per-context. No global RTL toggle — directionality is contextual.

#### Icon Mirroring Rules

- **Navigation icons** (back arrow, forward arrow, navigation drawer) → Mirror in RTL content areas per MD3 standard
- **Progress icons** (progress bars, fill indicators) → Mirror so progress fills right-to-left in Hebrew content contexts
- **Symmetric icons** (checkmark, star, settings gear, calendar) → No mirroring needed
- **Content-specific icons** (curriculum icons, achievement badges) → No mirroring — these are identity, not directional

#### Font Strategy

**Primary Hebrew font:** Noto Sans Hebrew
- **Body text:** 16sp (10-15% larger than Latin equivalent for equivalent readability)
- **Small text (captions, labels):** Medium weight (500) at small sizes — Hebrew's dense glyph structure needs the extra weight to remain legible on mobile screens
- **Headlines:** Regular weight (400) — Hebrew glyphs are naturally prominent at large sizes

**Latin fallback:** Noto Sans (same family, harmonious metrics)

**Mixed-direction text:** When Hebrew and English appear in the same text block, Noto Sans Hebrew and Noto Sans share x-height and baseline alignment, preventing visual jarring at language boundaries.

#### Component Strategy

**Standard MD3 components (use as-is with theming):**
- Bottom navigation, app bars, cards, FABs, snackbars, bottom sheets, dialogs, text fields, switches, chips

**Customized MD3 components (themed beyond defaults):**
- **Task completion card:** MD3 card with curriculum color left-border, single-tap completion with mode-appropriate animation, undo snackbar trigger
- **Progress bar:** MD3 linear progress with curriculum color fill, human-scale labels
- **Streak counter:** Custom widget using MD3 typography and color tokens
- **Celebration overlays:** Tier 1/2/3 animations built on Flutter's animation framework, respecting MD3 motion principles

**Custom components (no MD3 equivalent):**
- **Daily task list:** Scheduler-curated cross-curriculum task list with grouped sections
- **Hierarchy browser:** Curriculum-specific drill-down with breadcrumb navigation
- **Chazara stage indicator:** Visual representation of N-stage learning cycle position
- **Mystery reward progress:** Child-mode engagement widget with anticipation-building animation

#### Design Token Strategy

**Token hierarchy:**
```
MD3 baseline tokens
  → Learning Tracker semantic tokens (e.g., `curriculumMishnayos`, `celebrationTier1`)
    → Mode-specific overrides (child vs. adult)
      → Dynamic Color adaptation (Material You)
```

**Key semantic tokens:**
- `curriculum.{name}.primary` / `.onPrimary` / `.container` — per-curriculum color identity
- `celebration.tier{1|2|3}.duration` / `.curve` — mode-appropriate animation parameters
- `completion.feedback.scale` — child (1.0) vs. adult (0.6) animation intensity
- `spacing.touchTarget` — child (56dp minimum) vs. adult (48dp minimum)

#### Animation Performance Budget

**Tier 1 — Completion feedback (every tap):**
- Budget: under 300ms total
- Constraint: GPU-composited transforms and opacity only — no layout rebuilds
- Must not block the next interaction — user can tap the next item before animation completes

**Tier 2 — Section/milestone celebrations:**
- Budget: up to 600ms
- Can use hero animations, shared element transitions
- Should not block navigation — dismissible by tapping through

**Tier 3 — Major celebrations (masechta completion, 100-day streak):**
- Budget: up to 2 seconds
- Can use full-screen overlays, particle effects, multi-stage sequences
- Auto-dismiss after duration; tappable to dismiss early
- Child mode uses full budget; adult mode targets 50-60% of budget with subtler effects

### Customization Strategy

#### Per-Curriculum Visual Identity

Each curriculum gets a distinct color seed that generates a full `ColorScheme` via MD3's tonal palette system:

| Curriculum | Color Seed | Identity Feeling |
|-----------|-----------|-----------------|
| Mishnayos | Warm amber/gold | Traditional, foundational |
| Bavli | Deep blue | Depth, scholarship |
| Yerushalmi | Teal/green | Distinctive, exploratory |
| Mishna Berurah | Rich burgundy | Precision, halachic gravity |
| Chumash | Forest green | Organic, primary source |

Colors are applied at the widget level (card borders, progress fills, section headers), not the page level. The daily task list shows all five colors simultaneously when multiple curricula are active — scannability is the goal.

#### Dark Mode Curriculum Colors

In dark mode, curriculum colors shift from background tints to **accent markers:**
- **Light mode:** Curriculum color as card left-border (4dp width) + subtle tinted background
- **Dark mode:** Curriculum color as card left-border (4dp width) on dark surface — **no colored backgrounds** on dark cards. The border strip provides curriculum identity; the dark surface provides visual rest

This prevents the "carnival of colors" problem where five curriculum colors on dark backgrounds create visual noise instead of clarity.

#### Mode-Specific Customizations

| Property | Child Mode | Adult Mode |
|---------|-----------|-----------|
| Touch targets | 56dp minimum | 48dp minimum |
| Corner radius | 16dp (playful) | 12dp (refined) |
| Animation intensity | Full (1.0x) | Restrained (0.6x) |
| Spacing | Generous (16dp gutters) | Compact (12dp gutters) |
| Typography scale | Slightly larger body | Standard MD3 scale |
| Celebration feedback | Animated, multi-element | Subtle, single-element |
| Progress framing | Achievement-oriented ("Amazing! 3 done!") | Data-oriented ("3 of 5 complete") |
| Empty state tone | Encouraging, playful | Clean, informational |

#### Accessibility Baseline

- **Color contrast:** WCAG 2.1 AA minimum (4.5:1 body text, 3:1 large text) enforced by MD3 tonal palette system
- **Touch targets:** 48dp minimum (adult), 56dp minimum (child) — exceeds MD3's 48dp recommendation for child mode
- **Screen reader:** Semantic labels on all interactive elements; curriculum color identity conveyed through text labels, not color alone
- **Reduced motion:** System `prefers-reduced-motion` respected — celebrations fall back to simple fade transitions; completion feedback uses opacity only
- **Font scaling:** Supports system font scaling up to 200% with layout reflow — no text truncation on critical labels

## Defining Core Experience

### The Defining Experience

**"Open the app, see what's next, tap done, feel progress."**

If we describe Learning Tracker to a friend in one sentence: *"It tells me what to learn today across all my sedarim, and I just tap when I'm done."*

The defining experience is **the scheduler-curated daily task list combined with single-tap completion.** Not the tracking. Not the progress charts. Not the chazara scheduling. Those are features that support the defining experience. The core is: the app knows what you should do today, you do it, you tell the app with one tap, and you see yourself moving forward.

This is the interaction that, if we nail it, makes everything else follow. If the daily list is accurate and the tap feels satisfying, users build the habit. Once the habit exists, every other feature (chazara, progress, streaks, rewards) has a surface to live on.

### User Mental Model

**Current state: No tracking behavior exists.**

Torah learners — both children and adults — currently track their learning progress in their heads. A child's rebbi may keep a list, but the learner themselves simply "knows where I'm up to." Adults learning multiple curricula carry multiple bookmarks in memory: "I'm on daf 47 of Brachos, perek 3 of Kelim, siman 12 of Mishna Berurah."

**This means Learning Tracker is not replacing a tool — it's creating a new behavior.** There is no existing digital tracking habit to build on. The implication:

**Mental model: "Where I'm up to" not "what I completed"**
- Users think in terms of their current position (bookmark), not their completion history (log)
- The daily task list should present items as "here's what's next" — forward-looking, not backward-looking
- Progress views should emphasize current position within the hierarchy ("Perek 4 of Maseches Brachos") not completion counts
- The bookmark is the hero data point: each curriculum's detail view leads with **"You're up to: Brachos 4:7"** — the single most important piece of information the user wants to see, matching their existing mental model of "knowing where I'm at"

**No tracking muscle memory to leverage**
- Users will not instinctively open an app after learning. The daily reminder notification (to the parent for child accounts) is the primary activation mechanism
- The completion flow must be faster than the alternative (remembering). If it takes 10 seconds to mark something complete, the user will think "I'll just remember" and not bother
- Target: **warm resume to first completion in under 2 seconds; cold start under 5 seconds.** Warm resume (app in recents) is the common case — user opens app, daily tasks are cached, first tap is immediate. Cold start on a mid-range Android includes SQLite query + UI render — the daily task list must be the first query and render priority

**The rebbi as external authority (child accounts)**
- For children, the rebbi assigns and tracks learning. The app should feel like it's working *alongside* the rebbi's system, not replacing it
- Multi-track support (personal, school, tutor) maps to this reality — the school/tutor tracks represent what the rebbi assigned; the personal track is what the child does on their own
- Completion in the app *confirms* what happened in the real world. The tap means "I did this" — it's a recording, not a permission

**Adults and the "I just remember" ceiling**
- One curriculum is easy to remember. Two is manageable. Three starts getting unreliable. Five is impossible without external support
- The scheduler's value is invisible for single-curriculum users but becomes essential as complexity grows
- Onboarding should make the first curriculum effortless; the "aha" moment comes when the user adds a second curriculum and realizes the scheduler handles the coordination automatically

### Scheduler Trust Arc

The scheduler-curated daily plan is our key innovation — but users won't trust an algorithm over their own memory on day one. Trust must be earned through a deliberate arc:

**Days 1-7 — Scheduler is invisible:**
Single curriculum, sequential learning. The scheduler says "learn the next mishna." The user thinks "I could have figured that out." That's fine — the scheduler is being correct without being impressive. The user builds the *habit* of opening the app and tapping, not the *trust* in the scheduler's intelligence.

**Weeks 2-4 — Scheduler becomes useful:**
Chazara items start appearing in the daily plan. The user didn't have to remember when to review — the scheduler surfaced it. First "oh, this is helpful" moment. If a second curriculum is added, the scheduler interleaves items from both without the user managing two lists. The value of delegation starts to register.

**Month 2+ — Scheduler is essential:**
Multiple curricula, multiple chazara stages, pace tracking against goal deadlines. The user couldn't manage this mentally anymore — they have 3 curricula with 3 chazara stages each, creating 9+ parallel streams. The scheduler coordinates all of it into a single daily plan. Trust is now earned through demonstrated competence over time.

**Design implication:** The onboarding flow should not *explain* the scheduler's intelligence. It should let users *experience* it gradually. No "our smart algorithm" marketing copy. Just increasingly accurate daily plans that prove their value through use.

### Success Criteria

**The core experience succeeds when:**

1. **"It knows what I should do"** — User opens the app and immediately sees today's tasks without any decision-making. The scheduler's recommendation feels right — not too much, not too little, and the chazara items surface at appropriate intervals

2. **"Tapping done is faster than remembering"** — The completion interaction is so fast (single tap, instant feedback, next item surfaces) that recording in the app is *less effort* than maintaining a mental bookmark. Target: under 1 second from tap to ready-for-next-tap

3. **"I can see I'm getting somewhere"** — After completing today's items, the user sees tangible forward motion. Progress bar moved. Streak incremented. Current position advanced. The daily session ends with a clear "you moved forward today" signal

4. **"I never lose track"** — After a week, a month, three months — the app always knows exactly where the user is across every curriculum. The user stops carrying bookmarks in their head because the app is more reliable than memory

5. **"Coming back is effortless"** — After missing a day or a week, the app presents a reasonable daily plan, not an accusation. The scheduler absorbed the gap. The user picks up where they left off with zero re-orientation

### Novel vs. Established Pattern Analysis

**Established patterns we adopt:**
- **Single-tap completion** (Todoist/Things 3) — proven, universal, no learning required
- **"Today" view as home screen** (Todoist) — users understand "here are today's tasks" instantly
- **Streak counter** (Duolingo) — familiar retention mechanic, no explanation needed
- **Bottom navigation** (MD3 standard) — Android users navigate this in their sleep
- **Undo snackbar** (Gmail/Material Design) — "Undo" as safety net instead of confirmation dialog

**Novel pattern — the scheduler-curated daily plan:**
Unlike Todoist where the user creates their own "Today" list, our daily plan is *generated by the scheduler* based on pace, chazara timing, multi-curriculum balance, and goal deadlines. Users are accustomed to either managing their own task lists or following a fixed calendar (daf yomi). A system that dynamically generates a personalized daily plan across multiple curricula with adaptive chazara scheduling has no direct precedent in this domain.

**How we build trust in the novel pattern:**
- **Transparency on demand:** Tapping any daily task shows *why* it's there ("Chazara — last reviewed 3 days ago" or "New learning — next in sequence")
- **Predictability:** The scheduler follows clear rules the user can understand — it's not a black box
- **Override capability:** Users can skip/defer items or add ad-hoc completions. The scheduler adapts to overrides gracefully
- **Gradual trust:** The trust arc (invisible → useful → essential) means the scheduler earns authority over weeks, not minutes

**Novel-adjacent pattern — completion as behavioral shift:**
The act of opening an app to tap "done" is a new behavior for users who currently just remember. We're not teaching a new *interaction* pattern (tapping is universal) — we're creating a new *behavioral* pattern (recording completions digitally). The key is making the recording feel like a natural part of the learning moment, not administrative overhead added after the fact.

### Experience Mechanics

#### Daily Task Card Anatomy

Each card in the daily task list has a defined information architecture:

```
┌─────────────────────────────────────┐
│▐ משנה ברכות פרק ג׳ משנה ז׳          │
│▐ Chazara 1 · Personal              │
│▐ ░░░░░░░░░░░░░█████  Perek 3: 7/12 │
└─────────────────────────────────────┘
 ▐ = curriculum color left border (4dp)
```

- **Line 1:** Hebrew item name (primary text, RTL, 16sp Noto Sans Hebrew)
- **Line 2:** Stage label + track indicator (secondary text, English, 14sp). Track indicator only shown when multiple tracks are active for this curriculum
- **Line 3:** Progress context in human-scale units (progress bar + "Perek 3: 7 of 12")
- **Left border:** 4dp curriculum color strip — the only color differentiation between curricula in the list
- **Tap target:** Entire card is the completion tap target (minimum 56dp height child, 48dp adult)

**Child mode variant:** Slightly larger card (more generous padding), curriculum color more prominent, progress shows achievement framing ("7 done! 5 to go!")

**Adult mode variant:** Compact card, curriculum color subtle, progress shows data framing ("7/12")

#### The Completion Micro-Loop (3-second cycle)

```
[0ms]       User sees daily task card
[tap]       Finger touches the card
[0-5ms]     Completion commits to local DB (drift insert, WAL mode)
[5-20ms]    Haptic pulse dispatched async (optional, device-dependent)
[20-150ms]  Card exit animation begins:
             Child: Card scales (1.02x), curriculum color floods briefly,
                    card slides away with satisfying arc
             Adult: Checkmark fades in, card slides out smoothly
[150-250ms] Points counter increments (child). Progress bar advances
[250-300ms] Next task card slides into position
[300ms]     Undo snackbar appears: "Marked complete · Undo" (5s timeout)
[ready]     User can tap the next card immediately — animations are
            decorative, not blocking
```

**Animation queuing for rapid-fire completions:** When a user taps multiple items faster than animations complete, completions queue correctly. Each commit is immediate and independent. Card exit animations overlap. **List layout reflows in batches every 300ms** — preventing janky per-item shifting. Implementation uses Flutter's `AnimatedList` with `removeItem`/`insertItem` managing the backing list, not manual `AnimationController` orchestration.

**Key constraint:** Animations are decorative, not blocking. The user can tap the next item at any point during the previous item's animation. If 3 items are tapped in 2 seconds, all 3 commit to DB independently, all 3 animate their exits (overlapping), and the 4th item is ready when layout reflows.

#### Undo Mechanics

The undo path requires the same precision as the commit path:

```
[user taps "Undo" on snackbar within 5s]
[0-5ms]     Reverse DB write (delete the completion record)
[5-50ms]    Scheduler recalculates next item (the undone item returns
            to pending, any downstream scheduler adjustments revert)
[50-200ms]  Card re-insert animation: item slides back into its
            original position in the list
[200ms]     Snackbar dismisses. List state is as if the tap never happened
```

**Edge case:** If the user completes item A, then completes item B, then undoes item A — item A re-inserts above item B. The list maintains scheduler ordering, not completion ordering. If the user undoes after the snackbar timeout (5s), undo is no longer available — the completion is permanent. This is the standard Material Design pattern and avoids complex multi-undo state management.

#### Daily Session Flow

```
1. ENTRY (0-2 seconds warm resume, 0-5 seconds cold start)
   - App opens to daily task list (hero screen)
   - Header shows: Jewish date, streak counter, "X items today"
   - Task cards are pre-loaded, ordered by scheduler priority
   - Child mode: encouraging greeting ("Ready to learn, [name]?")
   - Adult mode: clean data header only

2. COMPLETION LOOP (2-180 seconds, ~30 seconds per item)
   - User scans first task → recognizes it → taps complete
   - Micro-loop plays (see above)
   - Repeat for each daily task
   - Between items: no decisions required for scheduled completions

3. SESSION END (after last completion)
   - "All done for today" state:
     Child: Tier 2 celebration, daily summary ("Amazing! 5 items
            done! Streak: 23 days!"), mystery reward progress
     Adult: Clean summary ("5 of 5 · Streak: 23 · Pace: 3 days ahead")
   - No "what next?" prompt — session is complete. User closes the app
   - Total session: 3-5 minutes for a typical daily plan of 5-7 items
```

#### Ad-Hoc Completion Flow (outside daily plan)

```
1. User navigates to a curriculum → browses hierarchy → finds item
2. Taps "Mark complete" on the item
3. MD3 bottom sheet slides up with stage selector:
   - "Which stage?" — radio list of configured stages
     (Learn / Chazara 1 / Chazara 2 / ...)
   - Pre-selects the most likely stage based on item's current state
4. If multiple tracks active: track selector row appears in same
   bottom sheet (Personal / School / Tutor)
5. Single tap on "Complete" button → completion commits → same
   feedback animation as daily flow
6. Undo snackbar with full context:
   "Brachos 3:7 · Chazara 1 · Personal · Undo"
```

The bottom sheet pattern is chosen because: (a) it's the MD3 standard for contextual selection, (b) it doesn't obscure the item being completed (user can still see the hierarchy context), (c) it dismisses cleanly on completion, (d) it accommodates variable numbers of stages without layout issues.

#### Bulk Completion Flow (onboarding and catch-up)

```
1. User selects stage first: "I'm marking these as Learned"
2. Multi-select mode activates on the hierarchy list
3. User taps items to select (checkmarks appear, count badge updates)
4. "Mark X items complete" button at bottom
5. Single confirmation tap → batch write begins
6. For large sets (50+ items): real progress indicator shows
   "Marking 147 of 200..." — batched writes via drift batch()
   with periodic yield for UI progress callback updates.
   Not a spinner — actual progress.
7. Summary animation (one Tier 2 celebration, not per-item)
8. Undo snackbar: "Marked 200 items complete · Undo"
   (Undo on bulk reverts entire batch)
```

## Visual Design Foundation

### Color System

**Curriculum Identity Colors** (Dynamic Color immune — never overridden by Material You wallpaper palette):

| Curriculum | Color | Hex | Feel | Dark-Mode Variant |
|---|---|---|---|---|
| Mishnayos | Amber | `#FF8F00` | Traditional, foundational | `#FFD54F` |
| Bavli | Blue | `#1565C0` | Depth, scholarship | `#42A5F5` |
| Yerushalmi | Cyan | `#0097A7` | Distinctive, exploratory | `#4DD0E1` |
| Mishna Berurah | Burgundy | `#AD1457` | Precision, halachic gravity | `#F06292` |
| Chumash | Green | `#2E7D32` | Living, growing | `#66BB6A` |

> Hex values aligned with Step 6 identity feelings. Yerushalmi shifted from teal to cyan for hue distance from Chumash green. All five occupy distinct hue bands (amber, blue, cyan, pink-burgundy, green).

**Semantic Colors** (Material 3 roles):

| Role | Light | Dark | Usage |
|---|---|---|---|
| Primary | per curriculum | per curriculum | Active curriculum context |
| Secondary | per mode | per mode | Supporting actions |
| Success | `#2E7D32` | `#66BB6A` | Completion confirmations |
| Warning | `#F57F17` | `#FFD54F` | Overdue / attention |
| Error | `#C62828` | `#EF5350` | Destructive / failure |
| Surface | `#FFFBFE` | `#1C1B1F` | Cards, sheets |

**Dark Mode Rules:**
- Follows **system setting** by default
- User override in Settings: Always Light / System (default) / Always Dark
- Dark/light preference is **independent of child/adult mode** — a child on a dark-mode phone sees child-mode in dark theme
- No per-curriculum dark toggle; one global switch

**Mode Overlays:**

| Mode | Light Tint | Dark Tint | Purpose |
|---|---|---|---|
| Child | Warmer surfaces (+4% primary) | Warmer darks | Playful energy |
| Adult | Neutral surfaces | Neutral darks | Focused calm |
| Parent | Subtle blue-grey | Cool darks | Authority / oversight |

### Elevation Strategy

| Level | dp | Usage |
|---|---|---|
| 1 | 1 | Task cards, list tiles |
| 2 | 3 | Bottom navigation, app bar |
| 3 | 6 | Bottom sheets, snackbars |
| 4 | 8 | Dialogs, pickers |
| 5 | 12 | Celebration overlays, confetti layer |

### Typography System

Three-column scale — Hebrew primary, Latin fallback, both from Noto family:

| Token | Hebrew (Noto Sans Hebrew) | Latin (Noto Sans) | Size / Weight / Height |
|---|---|---|---|
| headlineLarge | yes | yes | 32sp / 400 / 40 |
| headlineMedium | yes | yes | 28sp / 400 / 36 |
| titleLarge | yes | yes | 22sp / 500 / 28 |
| titleMedium | yes | yes | 16sp / 500 / 24 |
| bodyLarge | yes | yes | 16sp / 400 / 24 |
| bodyMedium | yes | yes | 14sp / 400 / 20 |
| labelLarge | yes | yes | 14sp / 500 / 20 |
| labelSmall | yes | yes | 11sp / 500 / 16 |

> `displayLarge` (57sp) removed — unused in a phone app with 3-5 minute sessions. Scale caps at `headlineLarge` (32sp) for celebration overlays and masechta headers.

**Font weight rule:** Weight 500 applies when **rendered size** is <= 14sp equivalent, not when the token size is <= 14sp. At system font scale 150%+, a `labelSmall` (11sp x 1.5 = 16.5sp rendered) reverts to weight 400 to avoid appearing overly bold compared to surrounding text.

### Spacing & Layout Foundation

**Base unit:** 4dp
**Spacing tokens:**

| Token | Value | Usage |
|---|---|---|
| xs | 4dp | Icon-to-label, inline gaps |
| sm | 8dp | Intra-component padding |
| md | 16dp | Card padding, list item height |
| lg | 24dp | Section gaps |
| xl | 32dp | Screen-level margins (phone) |
| bottomNavHeight | 80dp | Bottom navigation bar height |

**Border-width tokens:**

| Token | Light | Dark | Usage |
|---|---|---|---|
| curriculum.border | 4dp | 6dp | Curriculum color card border |

> Dark mode border increased to 6dp to compensate for reduced contrast perception on dark surfaces.

**Responsive Breakpoints:**

| Breakpoint | Width | Margins | Max Card Width |
|---|---|---|---|
| Phone | < 600dp | 16dp | 100% - 32dp |
| Tablet | >= 600dp | 24dp | 480dp centered |

### Screen Layout Structure

```
┌──────────────────────────┐
│  AppBar  [≡ if parent] [⚙]│   ← Settings gear icon (not nav)
├──────────────────────────┤
│                          │
│     Content Area         │   ← RTL for Hebrew content
│     (scrollable)         │
│                          │
├──────────────────────────┤
│  Today │ Browse │Progress │   ← 3 destinations only
└──────────────────────────┘
```

**Bottom Nav:** 3 primary destinations (Today, Browse, Progress). Settings accessed via app bar gear icon — avoids the "4th tab that nobody uses" anti-pattern.

### "All Done" Success State

Shown when `items_remaining == 0` **at render time**. If the scheduler has since added new items, the normal task list renders instead — no stale celebration.

**Child mode:** Confetti burst (elevation 5) + large animated mascot + "!כל הכבוד" + streak counter
**Adult mode:** Calm checkmark animation + "!סיימת להיום" + subtle streak badge

**Curriculum-colored border:** 4dp in light mode, **6dp in dark mode**.

### Accessibility Summary

- All text meets WCAG 2.1 AA contrast (4.5:1 body, 3:1 large)
- Touch targets: 56dp child mode, 48dp adult mode
- Curriculum colors tested for deuteranopia/protanopia — each pair maintains distinguishable luminance delta
- `Semantics` widget on every interactive element
- Reduced-motion respects `MediaQuery.disableAnimations`
- Font weight adapts to rendered size at high system font scaling
