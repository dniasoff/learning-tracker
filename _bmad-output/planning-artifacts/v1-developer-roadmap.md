# Learning Tracker — V1 Developer Roadmap

**Target Release:** April 18th, 2026 (iOS + Android)
**Prepared:** March 18th, 2026
**For:** New developer onboarding

---

## Product Vision (V1)

A Torah learning tracker that supports three user types on a single device:

- **Learner** — adult/older child who manages their own learning
- **Child** — learns and sees progress, but never manages setup
- **Parent** — any user who adds a child automatically gains parent powers (PIN-protected)

No "profile types" exist in the system. A user who adds themselves is a learner. A user who adds a child is a parent. Both? Both.

---

## V1 Scope — What's In

| Feature | Priority |
|---------|----------|
| CI/CD — Play Store deploy from main | **P0 — Critical** |
| Onboarding wizard (amazing UX) | **P0 — Critical** |
| Calendar-linked learning plans (Daf Yomi, etc.) | **P0 — Critical** |
| Custom learning tracks | **P0 — Critical** |
| Progress celebration (streaks, milestones, visual progress) | **P0 — Critical** |
| Profile switching (children tap freely, parent PIN-protected) | **P0 — Critical** |
| Today view with English & Hebrew date | **P0 — Critical** |
| iOS full setup & release | **P0 — Critical** |
| Screen audit & fixes | **P1 — High** |
| Parent dashboard (see children's progress) | **P1 — High** |
| Parent manages rewards for children | **P1 — High** |
| Bulk-mark prior learning (optional during onboarding) | **P1 — High** |
| Multi-lingual UI support | **P1 — High** |
| Sefaria content integration (1 language + Hebrew) | **P1 — High** |
| Polish & bug fixes (discovered during testing) | **P1 — High** |

## V1 Scope — What's Out (V2)

| Feature | Reason |
|---------|--------|
| Tutor role & linking | Separate device, relationship model needs design |
| Teacher role & linking | Most complex role — test uploads, push to students |
| Parent on separate device | Cross-device sync of relationship data |
| Mother/Father shared tracking | Multi-user-per-role model |
| Multiple adults linked to one child | Relationship management UI |
| Teacher test uploads & push to students | Significant feature set |
| Shabbat/Yom Tov lock | Location-based, candle lighting to motzei — needs zmanim integration |
| Material linking for current learning (shiurim, video, audio, PDFs, commentaries, related texts — open in-app) | Content aggregation from external sources (Sefaria, AllDaf, YUTorah, TorahAnytime, etc.) |

---

## Phase 1: Foundation & Onboarding — Make It Amazing

This is the **highest priority** and the gateway to testing everything else.

### 1.1 Developer Onboarding
- Clone repo, run `flutter pub get`, `dart run build_runner build`
- Read architecture docs: `_bmad-output/planning-artifacts/architecture.md`
- Read project context: `_bmad-output/project-context.md` (120+ critical rules)
- Read development guide: `docs/development-guide.md`
- Run existing test suite: `flutter test` — 1,293 tests should pass
- Run app on Android emulator — get familiar with current state

### 1.1b CI/CD — Play Store Deployment Pipeline
- Set up CI/CD pipeline (GitHub Actions or similar) to automatically deploy main branch to Google Play Store (internal testing track)
- Must be in place early so every merge to main produces a testable build
- Pipeline steps: build → test → sign → upload to Play Store
- Signing keys and service account credentials securely stored (GitHub Secrets or equivalent)
- This unblocks continuous testing on real devices throughout all phases

### 1.2 Onboarding UX Design & Specification
Before writing code, document the complete onboarding flow:

**App Entry Flow:**
1. Login (Firebase auth)
2. Welcome screen → Wizard with clear choices:
   - **"Add myself as a learner"** → proceeds to learning setup
   - **"Add a child"** → parent enters child name/avatar, then learning setup for child
   - **Skip** → lands on empty home, can run wizard later
3. After initial setup, wizard is re-runnable at any time from settings/home
4. Re-running wizard can optionally remember prior learning (bulk-mark)

**Learning Setup (the core of onboarding):**

Two paths, presented clearly:

**Path A: Join a Calendar Program**
- Show available programs (sourced from Sefaria + Hebcal APIs):
  - Daf Yomi (Bavli)
  - Daf Yomi Yerushalmi (Vilna / Schottenstein)
  - Mishna Yomit
  - Nach Yomi
  - Rambam Yomi (1 chapter / 3 chapters)
  - Daf a Week
  - Tanakh Yomi
  - Halakhah Yomit
  - Arukh HaShulchan Yomi
  - Kitzur Shulchan Aruch Yomi
  - Chofetz Chaim Daily
  - And others from API
- User selects ONE program (can add more later)
- App shows where the cycle is today

**Step 1: Chazarah (Review) Plan — Optional**
- After selecting a program, ask if user wants to set up a review schedule
- Review options are program-aware (e.g., Daf Yomi might suggest):
  - Daily chazarah of the previous day's daf
  - Weekly review of all 7 dafim on Shabbos
  - Custom chazarah schedule
- User can skip — no review is perfectly valid
- Multiple chazarah rounds supported (e.g., Chazarah 1, Chazarah 2, Chazarah 3)

**Step 2: Start Tracking From**
- Default: from today (most common)
- Options:
  - From today
  - From beginning of current perek
  - From beginning of current masechta
  - From a specific daf (manual selection)
- This determines the "tracking window" — reminders and daily tasks are generated from this point forward

**Step 3: Mark Already-Completed Content — Two Use Cases**

*Use Case A: Within tracking window (affects reminders)*
- For dafim from the selected tracking start point onward (i.e., the program's schedule from that point)
- Marking these as done affects reminder scheduling (won't nag about completed ones)
- Per chazarah cycle granularity: user can mark individual dafim as completed for specific review rounds (e.g., "learned daf X all 3 chazarah rounds, daf Y only once")

*Use Case B: Before tracking window (achievements only)*
- For content learned before the tracking start point (historical)
- Purely for achievement/progress display — does NOT generate reminders
- Also supports per-chazarah-cycle marking (same granularity as above)
- Gives users credit for prior learning without cluttering their reminder queue

- Done — today's learning appears

**Path B: Custom Track**
- Choose scope: specific masechtos, sefarim, or all of a curriculum
- Start from beginning, work through to end
- Choose review plan / stages
- Self-paced — no external calendar
- Done — learning appears

**Key UX principles:**
- Form-based, not conversational
- Clean, minimal, one decision at a time
- Start with one program, add more later
- Must feel polished and intentional — this is the first impression

### 1.3 Calendar Data Integration
- Integrate Sefaria Calendars API (`/api/calendars`)
- Integrate Hebcal API for programs Sefaria doesn't cover
- Cache daily responses
- Map API responses to internal curriculum/content model
- Handle "where am I in the cycle" logic for mid-cycle joins
- Consider: `kosher_dart` package for Hebrew date display

### 1.4 Sefaria Content Integration
- Integrate Sefaria Text API (`/api/texts/{ref}`) to display actual learning content in-app
- Support bilingual display: Hebrew + one translation language (English, French, Spanish, etc. — user's choice)
- Content should open within the app, not redirect to browser
- Cache fetched texts for offline access
- Handle Hebrew RTL rendering alongside LTR translation

### 1.5 Multi-Lingual UI
- Implement Flutter localization (intl / arb files)
- Support Hebrew UI and English UI at minimum
- Language selection during onboarding or in settings
- All user-facing strings externalized for translation

### 1.6 Onboarding Implementation
- Build the wizard screens per the UX spec
- Wire up profile creation (learner / child)
- Auto-grant parent role when child is added
- Connect to learning plan setup (calendar + custom)
- Implement "re-run wizard" entry point
- Implement bulk-mark prior learning (optional step)

### 1.7 Dashboard (Default Landing Screen)
- **This is the most important screen in the app** — it must feel exciting, vibrant, and make the user want to open the app every day
- Default landing screen post-onboarding for all users
- Display today's learning tasks with English and Hebrew date
- Show progress / completion state with celebration-forward design

**Dashboard for Learners (adults):**
- Daily streak counter (prominent, animated)
- Progress toward current milestones (e.g., "12/120 dafim in Masechet Shabbos")
- "Up to date" / "behind" status for calendar programs
- Recent achievements and milestone celebrations
- Quick-tap completion for today's tasks

**Dashboard for Children:**
- All of the above, plus:
- Visible rewards — show what they're working toward (pool or specific non-surprise)
- Reward progress bar ("15 more dafim until you can pick a reward!")
- Earned rewards showcase
- Age-appropriate celebration animations — make completing a daf feel like an event
- Surprise reward reveal moment when a hidden milestone reward is earned

**Design principles:**
- Vibrant, colourful, energy — not a bland checklist
- Celebration-first: progress and achievements are front and centre, not buried in a sub-screen
- Every app open should feel like positive reinforcement
- The dashboard sells the app — if this screen doesn't spark excitement, nothing else matters

**Exit criteria:** A user can install the app, log in, complete onboarding, and land on a dashboard that makes them genuinely excited to learn. Today's tasks, streaks, progress, and rewards (for children) are all visible and feel alive. The flow feels clean and intuitive. Daniel can test the full app.

---

## Phase 2: Screen Audit & Fix

Once onboarding works, Daniel can actually test the app end-to-end. This phase is deliberately reactive.

### 2.1 Full Screen Audit
- Daniel tests every flow with real usage
- Catalogue what's broken, incomplete, or confusing
- Prioritize by impact on V1 release

### 2.2 Fix Critical Issues
- Fix broken screens identified in audit
- Complete incomplete screens
- Wire up disconnected flows

### 2.3 Learning Plan Flows
- Verify calendar-linked tracking works correctly (today's daf, behind/ahead tracking)
- Verify custom track progression works
- Verify profile switching between siblings works smoothly
- Verify parent mode shows children's progress correctly

**Exit criteria:** All core flows work end-to-end. No dead ends or broken screens in the main user journeys.

---

## Phase 3: Progress & Celebration

This is the **heart of the product**. The dashboard (built in Phase 1.7) is the canvas — Phase 3 fills it with everything that makes users come back. Progress celebration must feel meaningful, not gimmicky. This is Torah learning — achievements should feel like genuine simcha.

### 3.1 Audit Existing Achievement System
- Review what's built in Epics 8 (achievements) and 10 (parent rewards)
- Identify gaps between what exists and what's needed
- Map what exists to the dashboard design from Phase 1.7

### 3.2 Progress Visualization & Celebration
- **Streaks:** daily learning streak counter, streak milestones (7 days, 30 days, 100 days, etc.), streak recovery ("you missed 1 day but your 45-day streak is safe!")
- **Milestones:** "Completed Masechet Brachos!", "100 mishnayos learned!", siyum celebrations
- **Visual progress:** animated progress bars, completion percentages, masechta/seder progress maps
- **Calendar-linked:** "You're up to date!" or "3 dafim behind" with encouragement
- **Celebration moments:** animations/confetti on completion, milestone fanfare, special celebrations for siyumim
- **Children's experience:** extra vibrant, age-appropriate animations, reward progress prominently displayed
- All of this lives on the dashboard — not buried in settings or sub-menus

### 3.3 Parent Rewards
- PIN-protected reward management (parent only)
- Rewards are per-child — each child has their own targets and rewards
- Two reward modes:
  - **Specific Reward** — a single reward tied to a milestone. Can be configured as a surprise (hidden from child until earned) or visible.
  - **Reward Pool** — a collection of rewards the child can choose from when they hit the milestone. Always visible to the child (provides motivation). Pools can optionally be shared across children, but targets/milestones are always per-child.
- Milestone types:
  - Finish a masechta
  - Finish a seder
  - Every N dafim (repeating milestone — must use a pool since it triggers multiple times)
- Either reward mode (specific or pool) can be used with any milestone type, except repeating milestones which require a pool
- Child sees available pool rewards in advance; for specific rewards, parent chooses visible vs. surprise

**Exit criteria:** Opening the app feels motivating and exciting. The dashboard is vibrant and alive with progress, streaks, milestones, and rewards. Children are buzzing to open the app. Adults feel genuine satisfaction seeing their learning journey. Nobody opens this app and feels like they're looking at a spreadsheet.

---

## Phase 4: iOS, Polish & Release

### 4.1 iOS Project Setup
- Configure Xcode project (Runner.xcworkspace)
- Apple Developer account, certificates, provisioning profiles
- Firebase iOS app registration + GoogleService-Info.plist
- Configure iOS-specific plugins (notifications, auth, etc.)
- TestFlight setup for beta testing
- Verify app builds and runs on iOS simulator
- Identify and fix any platform-specific issues

### 4.2 Cross-Platform Testing
- Test all flows on iOS devices (not just simulator)
- Test all flows on Android devices
- Fix platform-specific issues
- Verify Firebase works on both platforms

### 4.3 Polish
- UI consistency pass
- Loading states, empty states, error states
- Hebrew text rendering (BiDi, nikud, RTL)
- Performance (large curriculum lists need ListView.builder)
- Offline behaviour (app should work without internet after initial sync)

### 4.4 Release Preparation
- App Store assets: screenshots, descriptions, keywords
- Play Store assets: screenshots, descriptions
- App icons, splash screens
- Privacy policy (required for both stores)
- TestFlight beta → final testing
- Play Store internal testing → final testing

### 4.5 Release
- Submit to App Store (allow 24-48h review time)
- Submit to Play Store
- Monitor for issues

**Exit criteria:** App is live on both iOS and Android App Stores.

---

## Calendar Data Sources — Technical Reference

### Primary: Sefaria API
- **Endpoint:** `https://www.sefaria.org/api/calendars`
- **With date:** `https://www.sefaria.org/api/calendars?year=2026&month=3&day=18`
- **Coverage:** Daf Yomi, Yerushalmi, Mishna Yomit, Nach Yomi, Rambam (1+3), Daf a Week, Halakhah Yomit, Arukh HaShulchan, Tanakh Yomi, Tanya Yomi, 929, Chok LeYisrael, Parashat Hashavua
- **Bonus:** Returns direct text references for linking to content

### Secondary: Hebcal API
- **Endpoint:** `https://www.hebcal.com/hebcal?v=1&cfg=json`
- **Gap coverage:** Chofetz Chaim, Shemirat HaLashon, Daily Tehillim, Kitzur Shulchan Aruch, Pirkei Avot
- **Parameters:** `F=on` (Daf Yomi), `myomi=on` (Mishna), `nyomi=on` (Nach), `dr1=on` / `dr3=on` (Rambam), etc.

### Flutter Package
- **`kosher_dart`** (pub.dev) — Jewish calendar, zmanim, Daf Yomi. Useful for Hebrew date display and future Shabbat lock (V2).

---

## Architecture Notes for Developer

- **Pattern:** Feature-first Clean Architecture with Riverpod
- **Database:** Drift (SQLite) — offline-first
- **Navigation:** auto_route
- **State:** Riverpod 3.x with AsyncValue (never custom state classes)
- **Models:** Freezed + copyWith (never mutate directly)
- **Testing:** mocktail, 80%+ domain coverage target
- **Code gen:** Run `dart run build_runner build` after ANY annotation changes
- **Pre-commit:** Always run `dart analyze` + `dart format .` + `flutter test`
- **Full rules:** See `_bmad-output/project-context.md` (120+ rules)

---

## Phase Summary

| Phase | Focus |
|-------|-------|
| **Phase 1** | Foundation — developer onboarding, onboarding wizard, calendar integration, today view |
| **Phase 2** | Screen audit & fix — reactive to Daniel's testing |
| **Phase 3** | Progress celebration & rewards — the heart of the app |
| **Phase 4** | iOS setup, polish, cross-platform testing, release |

---

## Risk Register

| Risk | Mitigation |
|------|------------|
| Onboarding scope creep | Keep it tight — one program at a time, add complexity later |
| Calendar API data doesn't map cleanly to internal model | Prototype integration early in Phase 1 |
| Screen audit reveals more broken than expected | Phase 2 is deliberately reactive; deprioritize nice-to-haves |
| App Store review delays | Submit early; have TestFlight build ready before final polish |
| Hebrew text rendering issues on iOS | Test RTL/BiDi as soon as iOS builds |
| iOS plugin compatibility issues | Identify and resolve in Phase 4 before polish work |
