# Learning Tracker -- Product Overview for Testers

> **Read this document first.** Before working through any test scenario, test plan, or
> bug report, read this overview end-to-end. It explains what the product is, who it
> serves, and how the pieces fit together. Without this context, the test scenarios
> will feel like a random collection of checkboxes.

---

## 1. What Is Learning Tracker?

Learning Tracker is a Flutter/Dart Android app that helps users track and manage
their Torah (Jewish religious text) learning across multiple curricula.

The problem it solves is deceptively simple: a learner juggling multiple subjects
needs to remember where they are in each one, which sections are due for review,
and whether they are on pace for their goal. Multiply that across several
curricula, each with thousands of individual items, and the mental overhead
becomes unmanageable. Learning Tracker handles all of it automatically.

**In concrete terms, the app:**

- Manages **9 curricula** (Mishnayos, Talmud Bavli, Chumash, etc.) with
  configurable multi-stage review cycles
- Runs an **intelligent scheduler** that generates a personalized daily task
  list balancing new learning with review
- Supports **three independent tracks** per curriculum (Personal, School, Tutor)
  so the same material can be tracked from different contexts without
  double-counting
- Serves **two audiences**: children ages 10-13 (with parent management and
  balanced gamification) and adults (self-directed, clean interface)
- Works **fully offline** -- crucial for Shabbos-observant users who cannot use
  devices on Shabbos but want to track their learning before and after

The key value proposition: thousands of learning items, transformed into a clear
daily plan.

---

## 2. Why It Is Amazing (and What Makes It Hard to Test)

Each of these strengths is also a testing surface:

| Strength | What It Does | Why It Is Hard to Test |
|---|---|---|
| **Smart scheduling** | Calculates optimal daily workload balancing new learning with review (chazara). Adapts when you fall behind or get ahead. | The scheduler's output depends on completions, stage configs, goals, and date. Edge cases multiply fast. |
| **Multi-track** | A student learning the same material in school, with a tutor, and independently at home can track all three separately. | Track interactions (especially the no-double-counting rule FR11) need careful verification. |
| **Offline-first** | Full functionality without internet. SQLite is the source of truth. Firestore is a backup channel only. | Two auth tiers (cloud-born vs local-born) with different capabilities. Sync conflicts. |
| **Cultural sensitivity** | Hebrew calendar integration, Shabbos/Yom Tov awareness (streaks do not break, notifications silence), RTL text support. | Calendar-dependent behavior requires testing around real Hebrew dates and edge cases (e.g., two-day Yom Tov). |
| **Data is sacred** | Completions are immutable and append-only. Nothing is ever deleted. | Data migration, storage growth, and export/import all need to preserve this guarantee. |

---

## 3. The 9 Curricula

Each curriculum represents a body of Torah literature with its own internal
structure. Different curricula have different hierarchy depths (3-4 levels) and
vastly different item counts.

| Curriculum | Hebrew | What It Is | Items | Hierarchy (levels) |
|---|---|---|---|---|
| Mishnayos | משניות | Oral Law -- the foundational text after the Torah. 6 orders (sedarim), 63 tractates. Most common for young learners. | ~4,192 | Seder > Masechta > Perek > Mishna |
| Talmud Bavli | תלמוד בבלי | Babylonian Talmud -- extensive commentary on the Mishna. The "Daf Yomi" program completes it in ~7.5 years, one page (daf) per day. | ~2,711 dapim | Seder > Masechta > Daf > Amud |
| Talmud Yerushalmi | תלמוד ירושלמי | Jerusalem Talmud -- shorter parallel to Bavli. Less commonly studied but has its own daily programs. | varies | Masechta > Daf > Halacha |
| Mishna Berurah | משנה ברורה | Practical Jewish law (halacha) compendium by the Chofetz Chaim. 697 sections (simanim). | ~17,397 | Siman > Seif > Seif Katan |
| Chumash | חומש | The Five Books of Moses (Genesis-Deuteronomy). 5,845 verses. Often studied with weekly Torah portion cycle. | 5,845 | Sefer > Parsha > Perek > Pasuk |
| Mishneh Torah | משנה תורה | Maimonides' comprehensive code of Jewish law (Rambam). 14 books, 83 sections, 1,000 chapters. | varies | Sefer > Section > Chapter |
| Tanach | תנ"ך | Full Hebrew Bible (Torah + Prophets + Writings). 24 books total. | varies | Section > Sefer > Perek > Pasuk |
| Nach | נ"ך | Prophets + Writings (Tanach minus Torah). 19 books. | ~17,360 | Section > Sefer > Perek > Pasuk |
| Mussar | מוסר | Ethics and character development texts. Various classic works. | ~51 | Sefer > Section > Chapter |

### Testing Implication

Different curricula have different hierarchy depths (3-4 levels) and vastly
different item counts (51 to 17,397). When testing, use at least:

- **Mishnayos** -- 4-level hierarchy, manageable size (~4,192 items), most
  common curriculum for the target audience
- **Talmud Bavli** -- daf-based structure with a different UX around daf/amud
  units, exercises the scheduler with a different content shape

---

## 4. The 3 Track Types

Every curriculum can be tracked under up to three independent tracks. Each track
has its own bookmark per curriculum.

| Track | Required? | Scheduling | Who Controls It | Key Behavior |
|---|---|---|---|---|
| **Personal** | Yes (mandatory, cannot be removed) | Auto-scheduled by smart scheduler | The learner | Self-paced learning. Scheduler generates daily tasks balancing new items + reviews. Bookmark advances automatically. |
| **School** | Optional | Manual (no auto-scheduling) | Parent or learner | Tracks what is being learned in school/yeshiva. User manually marks items. Separate bookmark from Personal. Can be activated/deactivated without data loss. |
| **Tutor** | Optional | Manual (no auto-scheduling) | Tutor (via PIN-protected mode) | Tracks tutoring sessions. Tutor marks items during sessions. Read-only dashboard for tutor to see all progress. Separate PIN from parent PIN. |

### The No-Double-Counting Rule (FR11)

This is critical: **the same content item's stage CANNOT be completed under
multiple tracks.** If you mark Mishnayos Perek 1, Mishna 1 "Learn" stage
complete on the Personal track, you cannot mark it again on the School track.
This prevents inflating progress.

### Independent Bookmarks

Each track maintains its own bookmark per curriculum, independently. Personal
might be on chapter 3, School on chapter 5, Tutor on chapter 1 -- all moving
at their own pace.

---

## 5. The Chazara (Review) Concept

This is the heart of the app's intelligence. "Chazara" means review, and the
app implements a multi-stage review cycle for every item learned.

### The Stages

| Stage | Name | Typical Timing | Purpose |
|---|---|---|---|
| Stage 0 | **Learn** | N/A | First time encountering the material. The bookmark advances. |
| Stage 1 | **Chazara 1** | +1 day after learning | First review. Reinforces initial memory. |
| Stage 2 | **Chazara 2** | +7 days after learning | Second review. Deeper retention. |
| Stage 3+ | **Additional** | Configurable | Up to 10 total stages can be configured per curriculum. |

### Three Schedule Types for Review Stages

| Schedule Type | How It Works | Example |
|---|---|---|
| **Delay** | Review N days after previous stage completion. Most common. | "Review 3 days after you learned it" |
| **Weekly** | Review on specific days of the week. | "Review every Friday" |
| **Rolling** | Always keep the last N completed items in rotation. | "Always have your most recent 20 items in review" |

### Why This Matters for Testing

The scheduler's daily task list is the product's number-one value proposition.
It must correctly generate tasks mixing new learning with due reviews, respecting
the configured schedule type for each stage. A bug here means the user gets the
wrong daily plan -- the one thing they rely on the app to get right.

---

## 6. The Smart Scheduler

The scheduler runs for the **Personal track only** (School and Tutor are manually
paced). It is a three-phase engine:

### Phase 1: Data Loading

Reads completions, stage configs, content tree, and goals from local SQLite.

### Phase 2: Analysis

- Calculates pace using a **7-day rolling average**
- Determines what is due today (overdue reviews, scheduled reviews, new items)
- Compares current pace against goal requirements

### Phase 3: Task Assembly

Produces an ordered daily task list with this priority:

1. **Overdue chazara** -- reviews that were due on previous days but not completed
2. **Scheduled chazara** -- reviews due today
3. **New learning** -- fresh items to advance the bookmark

### Goal Types

| Goal Type | Description | Scheduler Behavior |
|---|---|---|
| **Deadline** | "Finish all Mishnayos by Pesach" | Scheduler calculates required daily load to hit the target date. Adjusts as you fall behind or get ahead. |
| **Pace** | "1 daf per day" | App shows projected completion date based on set pace. |
| **No goal** | Chazara-only mode | Only reviews are scheduled. No new items are pushed. Good for consolidation periods. |

---

## 7. Child vs Adult Mode

The app serves two distinct audiences with different UX treatments:

| Aspect | Child Mode (ages 10-13) | Adult Mode |
|---|---|---|
| **Gamification** | Full: mystery rewards, celebrations, point popups | Minimal or optional |
| **Parent Mode** | Available (PIN-protected) | Not available |
| **Tutor Mode** | Available | Available |
| **Completion feedback** | Satisfying animation, celebratory | Subtle, clean |
| **Streak milestones** | Tiered celebrations (7, 30, 100 days) | Simple acknowledgment |
| **Complexity** | Simplified where possible | Full control exposed |

---

## 8. Authentication and Offline-First Architecture

### The Hard-Tier Model

The user's auth tier is **set at signup based on network state and is immutable**
-- it cannot change later.

| Tier | How You Get It | Authentication | Sync | Recovery |
|---|---|---|---|---|
| **Cloud-born** | Signed up with internet available | Firebase Auth (email/password or Google) | Firestore sync, multi-device support | Full backup and restore |
| **Local-born** | Signed up without internet | Password hashed with argon2id, stored in local SQLite | None. No sync, no backup, no recovery. | None. Prominent warning shown at signup. |

### The Offline-First Principle

Regardless of tier, **SQLite is always the source of truth.** The app works
identically whether online or offline. Firestore (for cloud-born users) is a
backup and sync channel only -- never the primary data store.

**Testing implication:** Every core feature must work in airplane mode. If a
feature breaks without internet, that is a bug (unless it is explicitly a
cloud-only feature like multi-device sync).

---

## 9. Key Concepts Glossary

For testers encountering these terms for the first time:

### Content Structure Terms

| Term | Hebrew | Meaning in the App |
|---|---|---|
| Seder | סדר | "Order" -- top-level division of Mishnayos (6 total) |
| Masechta | מסכתא | "Tractate" -- a book within a Seder (63 total in Mishnayos) |
| Perek | פרק | "Chapter" within a Masechta |
| Mishna | משנה | Individual teaching unit (the leaf item in Mishnayos) |
| Daf | דף | "Page" of Talmud (front + back = 2 amudim) |
| Amud | עמוד | "Column/side" -- one side of a daf (the leaf item in Bavli) |
| Siman | סימן | "Section" in Mishna Berurah (697 total) |
| Seif | סעיף | "Sub-section" within a Siman |
| Seif Katan | סעיף קטן | "Small sub-section" -- the leaf item in Mishna Berurah |
| Pasuk | פסוק | "Verse" in Tanach/Chumash |
| Parsha | פרשה | Weekly Torah portion (54 per year) |
| Sefer | ספר | "Book" -- e.g., Bereishis (Genesis) |

### App and Domain Terms

| Term | Hebrew | Meaning in the App |
|---|---|---|
| Chazara | חזרה | "Review" -- the multi-stage review cycle that is the core of the app |
| Siyum | סיום | "Completion" celebration -- finishing a masechta, seder, or full curriculum |
| Shabbos | שבת | Saturday sabbath -- no device use. Streaks do not break. Notifications silence. |
| Yom Tov | יום טוב | Jewish holidays -- same device restrictions as Shabbos |
| Zmanim | זמנים | "Times" -- halachic time calculations (sunset, etc.) used for Shabbos boundaries |
| Nikud | ניקוד | Vowel marks on Hebrew text -- search strips these for easier matching |
| Sefaria | N/A | Open-source library providing all the Hebrew/English text content for the app |

---

## 10. App Navigation Structure

### Bottom Navigation (4 Tabs)

| Tab | Purpose | What the User Does Here |
|---|---|---|
| **Dashboard** | "What should I learn today?" | Cross-curriculum summary cards showing daily tasks, streak status, and progress at a glance. |
| **Learn** | Active learning screen | View current items, mark completions, advance through material. |
| **Progress** | Charts and statistics | Learning journey visualization, milestones, per-curriculum drill-down. |
| **Settings** | Preferences and account | Account management, data export/import, notification preferences, display settings. |

### Special Modes (PIN-Protected)

These overlay the main app and are accessed via separate PINs:

| Mode | Access | Purpose |
|---|---|---|
| **Parent Mode** | Parent PIN | Manage child's rewards, points, tracks. View analytics. Configure gamification. |
| **Tutor Mode** | Tutor PIN (separate from parent) | Read-only view of all progress. View chazara queue and completion history. Mark items during tutoring sessions. |

### Key User Flows

**First launch:**
```
Auth (sign up/sign in) --> Onboarding (select curriculum, set goals) --> Dashboard
```

**Daily use:**
```
Dashboard --> tap task --> mark complete --> next task
```

**Review progress:**
```
Progress tab --> per-curriculum drill-down --> charts and milestones
```

---

## Putting It All Together

Here is how the pieces connect in a typical scenario:

1. A 12-year-old student opens the app for the first time. He signs up
   (cloud-born, since he is online) and is guided through onboarding.

2. During onboarding, he selects **Mishnayos** as his curriculum, sets a
   **deadline goal** ("finish Seder Moed by the end of the school year"), and
   his parent activates the **School track** so his rebbe can assign what they
   cover in class.

3. The **smart scheduler** calculates that he needs to learn roughly 3 mishnayos
   per day to hit his deadline, plus whatever chazara is due from previous days.

4. Each morning, his **Dashboard** shows today's tasks: 2 overdue chazara items
   from last week, 1 scheduled chazara due today, and 3 new mishnayos.

5. He completes them throughout the day. Each completion is **append-only** --
   written to SQLite immediately, synced to Firestore when connectivity allows.

6. On **Shabbos**, he does not use the app. His streak does not break. No
   notifications fire. The scheduler accounts for the gap on Sunday.

7. His tutor logs in via **Tutor Mode** (separate PIN), sees the student's
   progress across all tracks, and marks 2 mishnayos covered during their
   Wednesday session.

8. At milestones (finishing a perek, a masechta, a full seder), the app
   triggers a **siyum celebration** with gamification appropriate to child mode.

This is the product. Every test scenario you encounter will exercise some
combination of these pieces.
