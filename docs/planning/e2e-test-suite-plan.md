# E2E Test Suite — Master Journey Catalog

**Consolidates:** per-area audits for all 11 feature areas + infra-crosscutting + navigation guards  
**Scope:** 48 routed `@RoutePage` screens · 53 AutoRoute entries · ~54 dialog/sheet surfaces · 16 feature areas  
**Date:** 2026-06-18 · **Status:** Planning — implementation-ready; Wave 1 builds on proven harness at `test/e2e/harness/e2e_harness.dart`

---

## 1. Coverage Overview

### Screen and route inventory

| Category | Count | Notes |
|---|---|---|
| `@RoutePage`-annotated screen classes | **48** | Includes 3 `PinFlow` variant classes in one file |
| AutoRoute entries in `app_router.dart` | **53** | Includes 4 redirect entries, 1 shell route |
| Routed screens reachable from shell | **44** | Shell itself + 4 tab children + 39 full-screen routes |
| Non-routed screens (Navigator push only) | **6** | `ScopeSelectionScreen`, `GoalSetupScreen`, `EditTrackScreen`, `TrackLearningOrderScreen`, `TutorPinSetupScreen`, `TutorPinResetScreen` |
| Dialog/sheet surfaces | **~54** | 27 `showDialog` call-sites, 7 `showModalBottomSheet`, ~20 named helper functions |
| Golden-eligible surfaces | **48** | All routed screens; `skipGolden: true` everywhere today — zero baselines |

### Feature areas (16)

| # | Area | Screens | Journeys | Priority |
|---|---|---|---|---|
| 1 | Onboarding | AppIntro, Onboarding, EmptyLogin, PermissionPrompt | 20 audit journeys → 22 E2E | P0 |
| 2 | Dashboard | DashboardScreen | 16 audit journeys → 16 E2E | P0 |
| 3 | Learning + Completion | LearningScreen | 13 audit journeys → 13 E2E | P0 |
| 4 | Content Browsing | CurriculumList, ContentHierarchy, ContentSearch, TextDisplay | (subset of area 3) | P0–P1 |
| 5 | Tracks | TrackManagementHub, TrackDetail, EditTrack, LearningOrder | 18 audit journeys → 18 E2E | P0–P1 |
| 6 | Scheduler | Scheduler, StudyDayConfig, GoalSetup | 18 audit journeys → 18 E2E | P0–P1 |
| 7 | Gamification | GamificationHub, ChildRedemption, ParentPendingRedemptions, PointConfig, RewardConfig | 16 audit journeys → 16 E2E | P0–P1 |
| 8 | Profiles + Child Mode | ProfilePicker, ManageLearners, ParentSettings, ParentTrackMgmt, PinFlow (×3) | 21 audit journeys → 21 E2E | P0–P1 |
| 9 | Progress | Progress, RecentActivity, LifetimeKnowledge, CurriculumProgress, SiyumimMilestones | 14 audit journeys → 14 E2E | P1 |
| 10 | Settings | Settings, CurriculumSettings, LifetimeMarking, LifetimeCurriculumMarking | 23 audit journeys → 23 E2E | P0–P1 |
| 11 | Tutoring | AcceptInvite, DeclineInvite, InviteTutor, ManageTutors, ManageGrants, TutorAuditLog, TutorPin* | 15 audit journeys → 15 E2E | P0 (highest risk) |
| 12 | Infra-Crosscutting | CityPicker, SacredTime, Notifications, DeviceRestore, SyncStatus | 19 audit journeys → 19 E2E | P0–P2 |
| 13 | Auth / Account | SignIn, Signup, AccountPicker, UpgradeToCloud | — → 10 E2E | P0 |
| 14 | Sync / Offline | BackupSyncSection, OfflineBanner, outbox | — → 6 E2E | P0–P1 |
| 15 | Navigation / Guards | AuthGuard, RestoreGuard, ProfileGuard, PinGuard, ChildModeGuard | — → 9 E2E | P0–P1 |
| 16 | Hebrew RTL dimension | All screens — he variant | — → 12 E2E | P1–P2 |

**Total journeys: 232**

### Dimension multipliers

Every journey can be run in one or more of the following dimensions. The catalog notes which dimensions apply. The full Cartesian product is not required — each dimension is exercised for at least one journey per feature area.

| Dimension | Values | Multiplier reason |
|---|---|---|
| UI locale | `en` / `he-RTL` | RTL layout, Hebrew curriculum terms, locale-aware `DateFormat.yMMMd` |
| Network | online / offline | Drift-first; no network-gated UI; outbox queues writes |
| Profile mode | child / adult / tutor-viewing-child | Different screen rows, guards, mark permissions |
| Parent mode | entered (PIN-gated) / not entered | Controls gamification admin, lifetime marking, track management |

---

## 2. Complete Journey Catalog

**Key:**

- **id** — `E2E-NNN` prefix; hundreds digit matches area number above
- **modes** — `ch`=child · `ad`=adult · `tu`=tutor-as-talmid · `pa`=parent-mode
- **dims** — `en`=English only · `he`=Hebrew-RTL variant required · `off`=offline variant · `*`=all dims
- **P** — priority (P0 happy paths; P1 important paths; P2 edge/variant)
- **seed/pre** — Drift DB state required before the journey starts

### Area 1 — Onboarding

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-101 | Full first-run adult happy path: intro→sign-up→profile→intent→track→permissions→dashboard | P0 | ad | en | AppIntroScreen; create-account → SignupScreen; OnboardingScreen profile step; intent chooser; track wizard; PermissionPromptScreen; lands on Dashboard | Fresh install, 0 profiles |
| E2E-102 | Full first-run child happy path: profile→PIN→track→permissions→handoff→dashboard | P0 | ch | en | Choose Child; set parent PIN; track wizard; permissions; handoff; Dashboard in child mode | 0 profiles |
| E2E-103 | PIN mismatch recovery during child onboarding | P1 | ch | en | Enter mismatched PINs; error shown; entry allowed again; success on re-entry | 0 profiles |
| E2E-104 | Adult skips profile creation — EmptyLoginScreen | P1 | ad | en | No profiles seeded; authenticated; navigates to EmptyLoginScreen | Auth, 0 profiles |
| E2E-105 | Adult selects 'Skip for now' at intent chooser | P1 | ad | en | Intent chooser shown; tap Skip; onboarding marks skipped; dashboard reached without track | Post sign-up |
| E2E-106 | Resume interrupted onboarding from SharedPreferences snapshot | P1 | ad | en | SharedPreferences.setMockInitialValues seeds `onboarding_phase`; app cold-starts; wizard resumes at saved phase | Partial onboarding prefs |
| E2E-107 | Legacy resume: saved phase='calendarPreference' with profileId → jumps to addTrack | P2 | ad | en | Seed `onboarding_phase=calendarPreference`, `onboarding_profile_id=1`; resumes at addTrack step | Legacy prefs |
| E2E-108 | Add another track after first track completes | P1 | ad | en | After first track created; tap 'Add Another Curriculum'; wizard re-runs; second track in Drift | 1 existing track |
| E2E-109 | Add another learner from handoff screen | P1 | ch | en | Handoff screen; tap 'Add Another Learner'; profile creation step for second learner | 1 child profile |
| E2E-110 | AddTrackFlow cancel with no profile yet — back to profileCreation | P2 | ad | en | AddTrackFlow opened; tap Cancel; _createdProfileId=null; routes to profileCreation not dashboard | 0 profiles |
| E2E-111 | AddTrackFlow cancel with adult profile already created — navigate to dashboard | P1 | ad | en | AddTrackFlow cancel; adult profile exists; navigates to dashboard | Adult profile exists |
| E2E-112 | AddTrackFlow cancel with child profile already created — handoff | P1 | ch | en | AddTrackFlow cancel; child profile exists; routes to handoff screen | Child profile exists |
| E2E-113 | Offline account creation — onboarding | P1 | ad | off | connectivityStreamProvider = offline; account + profile created locally; onboarding completes | connectivity mock offline |
| E2E-114 | Google Sign-Up new user — onboarding | P0 | ad | en | signInWithGoogle stub returns new AppUser; onboarding flow starts; profile created | Google stub override |
| E2E-115 | Google Sign-Up returning user with existing data — dashboard bypass | P1 | ad | en | Google stub returns existing uid; curriculumActivationServiceProvider has active curricula; routes to dashboard not onboarding | Existing cloud data |
| E2E-116 | Email verification flow during sign-in | P1 | ad | en | signInControllerProvider.showVerificationDialog callback triggered; EmailVerificationDialog appears | Unverified email user |
| E2E-117 | Permission prompts: both granted, no re-prompt | P1 | ad | en | notificationServiceProvider stub returns granted=true; PermissionPromptScreen proceeds without second prompt on re-launch | `kPermissionsPrompted=true` in prefs |
| E2E-118 | Duplicate profile name rejection | P1 | ad | en | Seed profile 'Alice'; add profile 'Alice' → error message shown; no second row created in Drift | 1 existing profile 'Alice' |
| E2E-119 | BulkMarkScreen — select items, confirm, done | P1 | ad | en | BulkMarkScreen renders seeded content; select items; confirm; completionRepo records sentinel date (2000-01-01) | Seeded content items |
| E2E-120 | Multiple accounts — ProfilePickerRoute when >=2 profiles | P1 | ad | en | Post-onboarding; 2 profiles in Drift; navigates to ProfilePickerRoute, not dashboard | 2 seeded profiles |
| E2E-121 | App intro — sign in path | P0 | ad | en | AppIntroScreen; tap "Sign in" → SignInScreen | Fresh install |
| E2E-122 | App intro — create account path | P0 | ad | en | Tap "Create account" → SignupScreen | Fresh install |

### Area 2 — Dashboard

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-201 | Adult daily check-in: see tasks, open Scheduler | P0 | ad | en | Dashboard renders task cards; tap mission card → SchedulerScreen with correct section | 1 active track, seed daily tasks |
| E2E-202 | Child daily check-in: points card, streak chip navigates to Gamification | P0 | ch | en | Child dashboard shows points; tap streak chip → GamificationScreen (childModeGuard passes) | Child profile, seeded points |
| E2E-203 | Empty dashboard — no tracks, adult — add track CTA | P0 | ad | en | Empty state message; "Add a track" CTA visible; tap → track wizard | Adult, 0 active tracks |
| E2E-204 | Empty dashboard — no tracks, child — ask grown-up message | P1 | ch | en | Child empty state shows "Ask a grown-up" message, not add-track CTA | Child, 0 active tracks |
| E2E-205 | Skipped-onboarding CTA: set up track or dismiss | P1 | ad | en | `kOnboardingSkipped=true`; SkippedOnboardingCtaBanner visible; tap Setup → track wizard; tap Dismiss → hidden | Adult, prefs seeded |
| E2E-206 | All-caught-up state: no remaining tasks | P0 | ad | en | All tasks done for today; "All caught up" empty state shown; no task cards | 1 active track, all completions done |
| E2E-207 | Active track carousel: swipe between tracks, tap card to learn | P0 | ad | en | 2 active tracks; carousel rendered; swipe; tap card → LearningScreen at correct track | 2 active tracks |
| E2E-208 | Pull-to-refresh: re-fetches all dashboard providers | P1 | ad | en | Pull RefreshIndicator; dashboardActiveCurriculaStreamProvider re-evaluated; updated task count shown | Active track |
| E2E-209 | Auto-refresh after SyncStatus.synced on cold start | P0 | ad | en | syncStatusProvider emits SyncStatusSynced; dashboard providers invalidated; new data visible without tap | syncStatus mock |
| E2E-210 | Tutor views talmid dashboard | P1 | tu | en | activeTutoredProfileSelectionProvider seeded; amber tutor bar visible; greeting shows talmid name | Accepted grant, active session |
| E2E-211 | Parent views child dashboard (parent-mode elevation) | P1 | ch,pa | en | parentPinAuthenticatedProfileIdProvider seeded; child banner visible; admin tiles present | Child profile, parent mode |
| E2E-212 | Offline use: dashboard renders from Drift without network | P0 | ad | off | connectivityStreamProvider=false; all Drift providers resolve; offline banner visible | Seeded Drift, offline |
| E2E-213 | Profile switcher bar: tapping opens sheet on all tabs and sub-routes | P1 | ad | en | Tap role label on Dashboard, Learn, Progress, Settings; ProfileSwitcherSheet appears each time | Any active profile |
| E2E-214 | Chazara conditional rendering: tracks without chazara hide all chazara UI | P1 | ad | en | anyActiveTrackHasChazaraProvider=false; no chazara mission card; no chazara column in TrackStatGrid | Stage-less track |
| E2E-215 | Program track: today pill + overdue pill display | P1 | ad | en | Program track (e.g. Daf Yomi); today task pill and overdue count pill visible | Program track enrolled |
| E2E-216 | Self-paced track: current focus range label | P2 | ad | en | Self-paced track; focus range label rendered (not "No projection") | Self-paced track with goal |

### Area 3 — Learning + Content Browsing

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-301 | Mark single task complete — adult, fine-paced | P0 | ad | en | LearningScreen; tap "Mark Complete"; completionCommittedProvider increments; task removed from today | Active track, seed daily task |
| E2E-302 | Mark task complete — child, unlocks milestone celebration | P0 | ch | en | Child completes task at milestone threshold; AchievementUnlockCelebration fires; points update | Child profile, seeded milestone |
| E2E-303 | Tutor attempts live mark — forbidden dialog shown | P0 | tu | en | Tutor in talmid session; "Mark Complete" button absent; canMarkLiveCompletion=false enforced | Active talmid session |
| E2E-304 | Daf-atomic (coarse-paced) completion marks both amudim | P0 | ad | en | Seed daf-paced track; mark daf; coarseUnitLeafRefs returns 2 amudim; both completion records written | Daf-paced track |
| E2E-305 | Browse curriculum hierarchy — drill down and back | P0 | ad | en | CurriculumListScreen → ContentHierarchyScreen; drill through chapter → daf → back navigation | Content DB seeded |
| E2E-306 | Content search — find and open item | P1 | ad | en | ContentSearchScreen; type query; results appear; tap → TextDisplayScreen | Searchable content |
| E2E-307 | Stage breakdown bottom sheet for reviewed item | P1 | ad | en | Long-press ContentItemTile (count>0, showReviewBadge=true); _StageBreakdownSheet opens; stages listed | Seeded completions with stageOrder |
| E2E-308 | Offline text display — no cached text | P1 | ad | off | textContentProvider = no cache; TextDisplayScreen shows "not cached" state; no crash | contentDatabase empty |
| E2E-309 | Empty learn screen — no active tracks, adult | P1 | ad | en | LearningScreen; 0 active tracks; adult empty state shown with add-track CTA | 0 active tracks |
| E2E-310 | Idempotent re-mark — duplicate completion not re-enqueued | P1 | ad | en | Mark same task twice; second tap shows already-complete state; outbox has 1 row not 2 | Active track, 1 existing completion |
| E2E-311 | Prev/Next navigation between sibling text refs | P1 | ad | en | TextDisplayScreen; tap Next chevron; navigates to adjacent sibling ref; Back chevron returns | adjacentContentRefsProvider seeded |
| E2E-312 | View-all tasks — scheduler screen with skip + undo | P2 | ad | en | Dashboard "View All"; SchedulerScreen opens; skip task; snackbar+undo button appears; tap undo → restored | Active track, seeded tasks |
| E2E-313 | RTL breadcrumb — Hebrew Terms mode | P2 | ad | he | ContentHierarchyScreen in he locale; breadcrumb uses RTL chevron; no overflow | Mishnah/Talmud track, he locale |

### Area 4 — Tracks

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-401 | Add self-paced track — full wizard, no program | P0 | ad | en | TrackManagementHub → Add; curriculum → start position → pace goal → study days → created in Drift | Adult, no existing track |
| E2E-402 | Add program track — calendar-based (e.g. Daf Yomi / Mishna Yomit) | P0 | ad | en | Wizard; choose program curriculum; StartingPositionCalendarMode; goal skipped (program owns schedule); created in Drift | calendarProgramServiceProvider fake |
| E2E-403 | Re-add existing curriculum — replace confirm dialog | P0 | ad | en | Add curriculum already active; replace-confirm dialog appears; confirm → old track archived, new created | 1 existing active track |
| E2E-404 | View track detail and navigate to all action tiles | P0 | ad | en | TrackDetailScreen; Goal tile; Study Days tile; Learning Order tile; Edit tile — all tap successfully | Active track |
| E2E-405 | Delete track — archive path (keep history) | P0 | ad | en | TrackDetailScreen → Delete → Archive; track status='archived' in Drift; completions retained | Active track |
| E2E-406 | Delete track — wipe path (purge history) | P0 | ad | en | Delete → Wipe; track row gone; completion records purged | Active track with completions |
| E2E-407 | Delete last track — blocked by last-curriculum guard | P0 | ad | en | Only 1 active track; delete → LastActiveCurriculumException; error dialog shown; track unchanged | 1 active track |
| E2E-408 | Edit track — change name and study days | P1 | ad | en | EditTrackScreen; change display name; toggle study day; save → Drift updated; no track-type label visible | Active track |
| E2E-409 | Edit chazara schedule from EditTrackScreen | P1 | ad | en | Track with stages; EditTrackScreen chazara config renders; change cadence; save → stages updated | Stage-enabled track |
| E2E-410 | Clear overdue on program track | P1 | ad | en | Program track with overdue tasks; EditTrackScreen 'Clear Overdue' button; tap → reanchor; overdue count = 0 | Program track with backdated start |
| E2E-411 | Reorder content within a track — TrackLearningOrderScreen | P1 | ad | en | TrackDetailScreen → Reorder; TrackLearningOrderScreen drag; ReorderConfirmDialog confirms; order persisted | Multi-section track |
| E2E-412 | Add track with prior completions — bulk-mark at wizard end | P1 | ad | en | Wizard; prior-completions step; BulkMarkScreen; select items; sentinel date written | New track with prior study |
| E2E-413 | Add track — wizard resume after app kill | P1 | ad | en | SharedPreferences seed wizard step 3; cold-start; wizard resumes at step 3 with prior data | Partial prefs seed |
| E2E-414 | Parent-mode: manage child's tracks — ParentTrackManagementScreen | P1 | ch,pa | en | Parent mode entered; ParentTrackManagementScreen shows child tracks; delete/archive controls | Child profile, parent mode |
| E2E-415 | Goal setup / edit from TrackDetailScreen | P1 | ad | en | TrackDetailScreen → Goal; GoalSetupScreen (Navigator push); set deadline; save → goal in Drift | Active track |
| E2E-416 | Hebrew locale / RTL tracks flow | P1 | ad | he | AddTrackFlow in he locale; curriculum names in Hebrew terms; no overflow | he locale |
| E2E-417 | Tutor viewing child's tracks — read-only enforcement | P2 | tu | en | Tutor in talmid session; track hub shows read-only badge; no delete/edit controls | Active talmid session |
| E2E-418 | Whole-curriculum learning order — LearningOrderScreen | P2 | ad | en | LearningOrderScreen (per-curriculum); orderingRestrictedProvider=false; drag reorder; reset option | orderingRestrictedProvider=false |

### Area 5 — Scheduler

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-501 | Dashboard → Scheduler (Today section) → read task → mark complete | P0 | ad | en | Tap mission card → SchedulerScreen Today section; task list visible; tap item → mark complete | allDailyTasksProvider seeded |
| E2E-502 | Dashboard → Scheduler (Overdue section) — back-dated track has overdue items | P0 | ad | en | Back-dated track; SchedulerScreen Overdue section shows back-dated tasks | clockProvider advanced |
| E2E-503 | Skip task (swipe dismiss) then undo | P0 | ad | en | Swipe DailyTaskCard; task dismissed; Undo snackbar appears; tap → task restored | Seeded tasks |
| E2E-504 | Toggle grouped/flat view on Scheduler screen | P1 | ad | en | schedulerGroupedViewProvider toggled; tasks re-grouped vs flat; state resets on restart | Active track |
| E2E-505 | Create a deadline goal for a track | P0 | ad | en | GoalSetupScreen (Navigator push); set deadline date; save → goal row in Drift; pace indicator renders | Active track, no goal |
| E2E-506 | Create a pace goal with Daf granularity (Bavli) | P0 | ad | en | GoalSetupForm; choose pace; Daf unit pill (Hebrew or English term); scopedCoarseUnitCount drives total | Bavli track |
| E2E-507 | Edit existing goal — change deadline date | P1 | ad | en | TrackDetailScreen → Goal; existing goal shown; change deadline; save → goal updated | Track with existing goal |
| E2E-508 | Set Hebrew date deadline with HebrewDatePicker | P1 | ad | en | useHebrewDateProvider=true; GoalSetupForm → HebrewDatePicker; select date; Gregorian preview shows | useHebrewDate=true |
| E2E-509 | Configure study days for a chazara-enabled track | P0 | ad | en | StudyDayConfigScreen; track with stageOrder>1; learn-days and chazara-days columns both visible | Stage-enabled track |
| E2E-510 | Study-day config: no-chazara track shows neutral message | P1 | ad | en | StudyDayConfigScreen; stage-less track; chazara column absent; neutral message shown | Stage-less track |
| E2E-511 | Tutor cannot edit study days — read-only mode | P1 | tu | en | activeTutorPermissionsProvider canEditStudyDays=false; StudyDayConfigScreen day tiles disabled; snackbar on tap | Tutor session |
| E2E-512 | Zero study days warning when all days set to review | P1 | ad | en | Toggle all learn-days off; warning text appears; scheduler would show 0 learn tasks | Stage-enabled track |
| E2E-513 | Scheduler error state and retry | P1 | ad | en | allDailyTasksProvider overrideWith → throws; error state rendered; retry button invokes invalidate | Error mock |
| E2E-514 | Calendar-program track: overdue and today tasks appear | P0 | ad | en | Program track (Daf Yomi); today task present; overdue task present; labels correct | Program track enrolled |
| E2E-515 | Previously-skipped tasks get priority boost next day | P1 | ad | en | clockProvider advanced 1 day; previously-skipped tasks surface with elevated priority | Skipped task in SharedPreferences |
| E2E-516 | Hebrew (RTL) smoke — Scheduler and StudyDayConfig render without overflow | P1 | ad | he | SchedulerScreen + StudyDayConfigScreen in he locale; no overflow; Hebrew term labels | he locale |
| E2E-517 | Reorder-amnesty: overdue tasks before track creation day are not shown | P1 | ad | en | Track anchored today; tasks before anchor suppressed by amnesty; no phantom overdue | clockProvider fixed |
| E2E-518 | No goal → track silently skipped in scheduler | P1 | ad | en | Track without goal row in Drift; allDailyTasksProvider returns [] for that track; "No projection" shown | Track without goal |

### Area 6 — Gamification

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-601 | Parent creates a reward and child redeems it — full happy path | P0 | ch,pa | en | Parent mode; RewardConfigurationScreen; create reward; exit parent mode; ChildRedemptionScreen; sufficient points; confirm → redemption created | Child profile, enough points |
| E2E-602 | Parent fulfils a pending redemption | P0 | ch,pa | en | ParentPendingRedemptionsScreen; tap Approve; status→fulfilled; balance debited | Pending redemption in Drift |
| E2E-603 | Parent declines a redemption — refund path | P0 | ch,pa | en | ParentPendingRedemptionsScreen; tap Decline; status→declined; balance refunded | Pending redemption |
| E2E-604 | Parent configures point values per curriculum | P0 | ch,pa | en | PointConfigScreen renders per-curriculum config; adjust value; save → _pointConfigDataProvider updated | Child profile, parent mode |
| E2E-605 | Parent edits an existing reward via Manage Rewards sheet | P1 | ch,pa | en | RewardConfigurationScreen; long-press reward → edit sheet; change cost; save | Existing reward |
| E2E-606 | Parent deletes a reward | P1 | ch,pa | en | Reward delete via confirm dialog; reward removed from SharedPreferences; no longer visible | Existing reward |
| E2E-607 | Parent toggles a reward enabled/disabled | P1 | ch,pa | en | Toggle enabled switch; reward grayed out in ChildRedemptionScreen | Existing reward |
| E2E-608 | Tutor with restricted permissions sees disabled edit controls | P1 | tu | en | activeTutorPermissionsProvider canEditPoints=false, canEditRewards=false; controls disabled | Tutor session |
| E2E-609 | Tutor cannot redeem on child's behalf | P1 | tu | en | Tutor in talmid session; redeem button absent or disabled on ChildRedemptionScreen | Tutor session |
| E2E-610 | Achievement unlock celebration dialog on new completion | P1 | ch | en | Child completes task at milestone threshold; AchievementUnlockCelebration confetti shown; dismiss | Child, milestone threshold |
| E2E-611 | Achievements screen track filter interaction | P1 | ch | en | GamificationScreen achievements tab; tap track filter chip; milestones filtered by curriculum | Child profile, seeded achievements |
| E2E-612 | Parent manually adjusts child's points balance | P1 | ch,pa | en | PointConfigScreen → AdjustPointsDialog; enter +50; balance updates reactively | Child profile, parent mode |
| E2E-613 | Offline-first: reward config and redemption survive without network | P1 | ch,pa | off | syncWriteFacadeProvider=null; create reward; redeem; SharedPreferences persisted; no crash | Offline connectivity |
| E2E-614 | Gamification screen pull-to-refresh | P2 | ch | en | RefreshIndicator pulled; providers invalidated; updated balance shown | Child profile |
| E2E-615 | Stock template milestones auto-stripped on achievements load | P2 | ch | en | achievementsOverviewProvider runs; stock template rows absent from milestone list | Seeded stock milestones |
| E2E-616 | Hebrew (RTL) locale smoke across gamification screens | P2 | ch | he | GamificationScreen + ChildRedemptionScreen + ParentPendingRedemptionsScreen in he locale; no overflow | he locale |

### Area 7 — Profiles + Child Mode

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-701 | Create first child profile with PIN | P0 | ch | en | ProfilePicker empty; add child profile; set parent PIN; profile in Drift; PIN in SecureStorage | 0 profiles |
| E2E-702 | Create first adult profile | P0 | ad | en | ProfilePicker empty; add adult profile; no PIN prompt; profile in Drift | 0 profiles |
| E2E-703 | Multi-profile: select profile from picker (2+ profiles) | P0 | ad | en | ProfilePickerScreen lists 2 profiles; tap second → activeProfileId updates; dashboard reload | 2 seeded profiles |
| E2E-704 | Profile switcher sheet: switch profile mid-session | P0 | ad | en | Persistent switcher tap → ProfileSwitcherSheet; tap second profile → activeProfileId switches | 2 seeded profiles |
| E2E-705 | Enter parent mode — PIN elevation for child profile | P0 | ch | en | Child profile active; tap "Parent Mode" tile; PinFlowVerifyRoute; correct PIN → parent mode entered | Child profile with PIN |
| E2E-706 | First-time PIN setup via route guard — no PIN set yet | P0 | ch | en | PinFlowSetupRoute; enter 4-digit PIN twice; success; PIN in SecureStorage | Child profile, no PIN |
| E2E-707 | Exit parent mode via _ChildViewBanner | P1 | ch,pa | en | Parent mode active; tap Exit in amber banner; pinGuard.lock(); parent-mode tile shows again | Parent mode entered |
| E2E-708 | Add second profile from profile switcher sheet | P1 | ad | en | ProfileSwitcherSheet → Add Profile; showAddProfileDialog; create second profile; profile in Drift | 1 existing profile |
| E2E-709 | Rename profile via long-press manage sheet | P1 | ad | en | Long-press profile in picker/switcher; ProfileEditFormDialog; change name; save → Drift updated | 1 existing profile |
| E2E-710 | Delete profile — non-last | P1 | ad | en | ManageLearnersScreen; delete second profile; count drops to 1; picker shows 1 | 2 profiles |
| E2E-711 | Delete last profile | P1 | ad | en | 1 profile; delete attempt; error shown ("Cannot delete last profile"); profile unchanged | 1 profile |
| E2E-712 | Edit profile — name, mode, avatar — from switcher sheet | P1 | ad | en | ProfileEditFormDialog; update all 3 fields; save → Drift updated; switcher shows new name | 1 existing profile |
| E2E-713 | PIN verification lockout — 5 wrong attempts | P1 | ch | en | PinFlowVerifyRoute; 5 wrong entries; lockout message shown; correct PIN still accepted after lockout | Child profile with PIN |
| E2E-714 | Change PIN flow | P1 | ch,pa | en | PinFlowChangeRoute; enter old PIN; enter new PIN twice; success; SecureStorage updated | Child profile, parent mode |
| E2E-715 | Tutor enters talmid context — first time, online | P1 | tu | en | ManageGrantsScreen; select talmid; TutorPinEntryGate; _fireEntryPullAndNavigate; amber bar; switcher shows talmid | Accepted grant, online |
| E2E-716 | Tutor exits talmid context via amber banner | P1 | tu | en | Amber tutor banner; tap Exit; activeTutoredProfileSelectionProvider.exit(); switcher shows own profile | Active talmid session |
| E2E-717 | Accept pending tutor invite from profile picker | P1 | tu | en | ProfilePickerScreen; _PendingInviteCard visible; tap → AcceptInviteScreen | Pending invite in Drift |
| E2E-718 | AN-2: PIN guard blocks escalating actions from child context | P1 | ch | en | switcherSheetPinGuardRequiredProvider=true; tab child profile in switcher; PIN prompt appears | Child profile |
| E2E-719 | Offline delete profile attempt — cloud-born account | P2 | ad | off | connectivityStreamProvider=false; delete profile; error shown ("Must be online for cloud accounts") | Cloud-born account |
| E2E-720 | Auto-select single profile on cold start | P0 | ad | en | 1 profile in Drift; cold-start; ProfileGuard auto-selects; shell shows without picker | 1 profile |
| E2E-721 | Profile name duplicate validation in Add/Rename dialogs | P2 | ad | en | Add profile with existing name; DuplicateProfileNameException caught; error label shown; no duplicate in Drift | Existing profile 'Alice' |

### Area 8 — Progress

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-801 | First-time progress hub visit — no completions, empty state | P0 | ad | en | ProgressScreen; 0 completions; empty state (no activity) shown | 0 completion events |
| E2E-802 | Progress hub with live completions — adult | P0 | ad | en | ProgressScreen; seeded completions; engagement/achievement/lifetime tiles render with counts | Seeded completion_events |
| E2E-803 | Progress hub in child mode — points counter shown | P1 | ch | en | ProgressScreen child mode; points counter tile visible; adult-only tiles absent | Child profile, seeded points |
| E2E-804 | Navigate Progress hub → Recent Activity, explore time-range and curriculum filters | P0 | ad | en | RecentActivityScreen; time-range chip filter; curriculum chip filter; list updates | Seeded completions, multiple curricula |
| E2E-805 | Navigate to Siyumim & Milestones, toggle view, check milestone hierarchy | P0 | ad | en | SiyumimMilestonesScreen; toggle grouped/timeline view (journeySortModeProvider); milestone tiers visible | Seeded siyum events |
| E2E-806 | Siyumim & Milestones: tutor views child's journey via profileId query param | P1 | tu | en | SiyumimMilestonesRoute(profileId: talmidId); milestones show for talmid; no access-control block (known gap flagged) | Talmid siyum events |
| E2E-807 | Navigate to Lifetime Knowledge, toggle All Sources / Track Only, expand curriculum tree | P0 | ad | en | LifetimeKnowledgeScreen; toggle _LifetimeSourceFilter; tree expands per curriculum | Seeded priorImports + completions |
| E2E-808 | Navigate Progress Hub → Curriculum Progress detail screen | P0 | ad | en | CurriculumProgressScreen; progress bar renders; section breakdown visible; pace indicator state | Seeded completions for 1 curriculum |
| E2E-809 | Progress hub empty state — no active curricula | P1 | ad | en | 0 active tracks; ProgressScreen shows "No curricula" empty state | 0 active tracks |
| E2E-810 | Recent Activity offline / stale data behavior | P1 | ad | off | Offline; RecentActivityScreen renders from Drift cache; no spinner hang | Offline connectivity |
| E2E-811 | Recent Activity with chazara-enabled track vs. learn-only track | P1 | ad | en | anyActiveTrackHasChazaraProvider=true; chazara count tile visible; =false → tile absent | Track with/without stages |
| E2E-812 | Hebrew locale (RTL) across all progress screens | P1 | ad | he | ProgressScreen, RecentActivity, LifetimeKnowledge, CurriculumProgress, SiyumimMilestones in he locale; no overflow | he locale |
| E2E-813 | Completion committed → progress screens update without pull-to-refresh | P1 | ad | en | completionCommittedProvider incremented; progressLensRefreshTickProvider auto-bumped; progress count updates | Pre-seeded track |
| E2E-814 | Curriculum Progress: pace indicator states (on-pace, ahead, behind) | P1 | ad | en | clockProvider fixed; seed completions at different rates; assert on-pace/ahead/behind text for each | 3 seeded tracks, different pace |

### Area 9 — Settings

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-901 | Adult opens Settings and verifies profile header + account email | P0 | ad | en | SettingsScreen; profile header tile shows display name + email; tap → AccountActionsSheet | Adult profile, cloud-born |
| E2E-902 | Adult taps header → AccountActionsSheet shows correct items | P0 | ad | en | AccountActionsSheet: Sign Out, Delete Account, Change Password visible; child-only items absent | Adult profile |
| E2E-903 | Child profile — AccountActionsSheet shows only Switch Account | P0 | ch | en | Child profile; AccountActionsSheet shows only Switch Account option; no Sign Out | Child profile |
| E2E-904 | Tutored session — Settings shows talmid management tile only | P1 | tu | en | activeTutoredProfileSelectionProvider seeded; Settings header hidden; only Manage Talmid tile visible | Active talmid session |
| E2E-905 | Toggle Hebrew date preference and verify persistence | P1 | ad | en | Settings Hebrew date tile; toggle on; SharedPreferences written; HebrewDatePicker now opens in GoalSetup | Adult profile |
| E2E-906 | Hebrew Terms toggle shows/hides transliteration variant tile | P1 | ad | en | Toggle Hebrew Terms off; transliteration variant tile hidden; toggle on → visible again | Adult profile |
| E2E-907 | Local-born adult sees Backup+Sync upgrade card and taps Upgrade to Cloud | P0 | ad | en | BackupSyncSection renders local-only card; tap Upgrade → UpgradeToCloudScreen | Local-born account |
| E2E-908 | Cloud user sees synced status in Backup+Sync section | P1 | ad | en | syncStatusProvider = SyncStatusSynced; "Synced" status chip shown; last-sync timestamp visible | Cloud account, sync mock |
| E2E-909 | Sync error state — tap-to-retry and retriggers pull | P1 | ad | en | syncStatusProvider = SyncStatusError; error card with retry button; tap → orchestrator.retryPull() called | syncOrchestrator fake |
| E2E-910 | Upgrade-to-Cloud — successful upgrade for local-born | P0 | ad | en | UpgradeToCloudScreen; enter email + password; upgrade succeeds; authState transitions to cloudBorn | Local-born, accountManagementService fake |
| E2E-911 | Upgrade-to-Cloud — email collision shows resolution options | P1 | ad | en | UpgradeToCloud; existing email; EmailAlreadyExistsError; resolution options shown (sign-in or merge) | Local-born, existing email |
| E2E-912 | Lifetime Marking — adult marks items and saves to ledger | P0 | ad | en | LifetimeMarkingScreen (via PIN gate); select curriculum; LifetimeCurriculumMarkingScreen; mark items; ledger rows written | Adult, parent mode |
| E2E-913 | Lifetime Marking — child profile cannot access | P0 | ch | en | Child profile; LifetimeMarking tile hidden in Settings; /settings/lifetime route blocked by childModeGuard | Child profile |
| E2E-914 | Parental controls — child enters parent mode via PIN | P0 | ch | en | Settings; tap "Parent Mode" in Parental Controls section; PIN entry; parent mode entered | Child profile with PIN |
| E2E-915 | Parental controls — child already in parent mode shows PIN management tile | P1 | ch,pa | en | parentPinAuthenticatedProfileIdProvider seeded; PIN management tile visible in parental controls | Parent mode entered |
| E2E-916 | Sign out flow — adult signs out, navigates to sign-in or account picker | P0 | ad | en | AccountActionsSheet; tap Sign Out; confirm; authState→signedOut; navigates to /intro or /sign-in | Signed-in adult |
| E2E-917 | Delete account — cloud user, types DELETE, reauths, account wiped | P1 | ad | en | AccountActionsSheet → Delete Account; type DELETE confirmation; reauthenticate; account removed; prefs cleared | Cloud-born account |
| E2E-918 | Send diagnostic logs — cloud user taps tile, logs upload, snackbar shown | P1 | ad | en | Settings diagnostic tile; tap; appLoggerProvider history sent; success snackbar | Cloud account, logger fake |
| E2E-919 | Curriculum Settings — view program and request new program | P2 | ad | en | CurriculumSettingsScreen; program info visible; "Request Program" mailto link configured | Active track |
| E2E-920 | Study Day Config — toggle day type, chazara-less track shows message | P1 | ad | en | StudyDayConfigScreen from Settings; toggle day; save; chazara-less track shows neutral message | Track (with/without stages) |
| E2E-921 | Pending tutor invitations — invitation appears, accept navigates to AcceptInviteScreen | P1 | tu | en | incomingTutorGrantsProvider seeded with pending; _PendingInvitesSection shows; tap → AcceptInviteScreen | Pending tutor invite |
| E2E-922 | Hebrew locale — Settings renders in Hebrew RTL, Hebrew Terms tile hidden | P1 | ad | he | SettingsScreen in he locale; tiles render right-to-left; Hebrew Terms tile hidden (already in Hebrew) | he locale |
| E2E-923 | Offline state — Backup+Sync section shows offline card with pending count | P1 | ad | off | syncStatusProvider = SyncStatusOffline; offline card with outbox pending count | Offline, seeded outbox rows |

### Area 10 — Tutoring

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1001 | Parent invites a tutor for a child | P0 | ad | en | InviteTutorScreen; enter tutor email; send; tutorGrantRepositoryProvider records createInvite call; snackbar | Adult child profile |
| E2E-1002 | Tutor accepts invite via email deep-link | P0 | tu | en | AcceptInviteScreen deep-link `/invite?token=X`; step 1→6; grant status→accepted; talmid visible in ManageGrantsScreen | Pending grant, tutor account |
| E2E-1003 | Tutor accepts invite from profile-picker pending invite card | P0 | tu | en | ProfilePickerScreen; _PendingInviteCard; tap → AcceptInviteScreen; accept | Pending invite in Drift |
| E2E-1004 | Tutor declines invite | P1 | tu | en | DeclineInviteScreen; confirm → grant status→declined; talmid not accessible | Pending grant |
| E2E-1005 | Tutor enters talmid session via profile switcher (PIN gate + pull + navigation) | P0 | tu | en | ManageGrantsScreen; select talmid; TutorPinEntryGate; pull completes; amber bar; switcher shows talmid | Accepted grant, online |
| E2E-1006 | Parent rescinds a pending invite | P1 | ad | en | ManageTutorsScreen; pending invite shown; rescind; grant status→rescinded; invite card gone | Pending invite |
| E2E-1007 | Parent revokes an active tutor grant | P0 | ad | en | ManageTutorsScreen; active grant shown; revoke; grant status→revoked; tutor loses talmid access | Active grant |
| E2E-1008 | Tutor resigns from active grant | P1 | tu | en | ManageGrantsScreen; resign from talmid; grant status→resigned; talmid no longer in my-grants | Active grant |
| E2E-1009 | Parent views audit log for active tutor grant | P1 | ad | en | TutorAuditLogScreen; events listed (via fake repository); date format locale-aware | Seeded audit events |
| E2E-1010 | Tutor sets up PIN for first time — from TutorPinEntryGate | P0 | tu | en | tutorPinIsSetProvider=false; TutorPinEntryGate shows setup path; enter PIN; tutorPinServiceProvider records setPin | Tutor, no PIN |
| E2E-1011 | Tutor resets forgotten PIN | P1 | tu | en | TutorPinResetScreen; reset confirmed; clearTutorPin called; PIN removed from SecureStorage | Tutor with PIN |
| E2E-1012 | Tutor live-mark blocked in talmid session | P0 | tu | en | LearningScreen in talmid session; Mark Complete button absent; canMarkLiveCompletion=false | Active talmid session |
| E2E-1013 | Tutor exits talmid session | P1 | tu | en | Amber banner; tap Exit; activeTutoredProfileSelectionProvider.exit(); normal mode restored | Active talmid session |
| E2E-1014 | Parent revocation detected mid-session — online | P1 | tu | en | tutoredListenerSupervisorProvider detects revoke; amber bar dismissed; routes to own profile | Active session, grant revoked |
| E2E-1015 | Offline tutor returning to talmid — cached mirror | P1 | tu | off | Offline; Drift mirror seeded (isTutoredMirror=true); _fireEntryPullAndNavigate skips network; talmid session entered | Drift mirror seeded |

### Area 11 — Infra-Crosscutting

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1101 | City Picker: manual city selection flow | P0 | ad | en | CityPickerScreen; type 2+ chars; citySearchProvider results; tap city → sacredLocationProvider updated | No city set |
| E2E-1102 | City Picker: detect GPS location | P1 | ad | en | CityPickerScreen "Detect" button; sacredLocationProvider returns LocationFetchSuccess; city auto-populated | GPS stub |
| E2E-1103 | Sacred Time lock: Shabbos/YomTov overlay appears and auto-dismisses | P0 | ad | en | currentSacredWindowProvider = active Shabbos window; SacredTimeLockOverlay covers app; 30s timer → dismissed | clockProvider = Shabbos time |
| E2E-1104 | In-Israel toggle updates Yom Tov window computation | P1 | ad | en | inIsraelProvider=true/false; ZmanimWindowService recomputes; Yom Tov window changes | inIsrael toggle |
| E2E-1105 | Enable daily reminder and set custom time | P0 | ad | en | NotificationsScreen; toggle reminder on; time picker; SharedPreferences written | No notification pref set |
| E2E-1106 | Streak alert toggle shows/hides HOT STREAK badge | P1 | ad | en | Toggle streak alert; HOT STREAK badge shown/hidden; SharedPreferences updated | Existing notification prefs |
| E2E-1107 | Device notification toggle: OS blocked path | P1 | ad | en | notificationServiceProvider stub returns hasPermission=false; toggle shows disabled state; system-settings prompt | OS permission blocked |
| E2E-1108 | Per-profile notification prefs isolated on profile switch | P1 | ad | en | 2 profiles; set prefs for profile A; switch to B; prefs differ; switch back to A; prefs restored | 2 profiles |
| E2E-1109 | Device restore: new cloud device happy path | P0 | ad | en | RestoreGuard.markNeedsRestore(); DeviceRestoreScreen phases render; restore completes; dashboard reached | Fresh device, existing cloud data |
| E2E-1110 | Device restore: error then retry | P0 | ad | en | deviceRestoreServiceProvider throws; error state shown; retry button; retry succeeds | deviceRestoreService fake |
| E2E-1111 | Device restore: local-born account skips restore | P1 | ad | en | hasCloudAccount=false in RestoreGuard; DeviceRestoreScreen never shown; routes to dashboard | Local-born account |
| E2E-1112 | Sync status indicator: online/offline/degraded transitions | P1 | ad | en | syncStatusProvider streams through each SyncStatus subclass; BackupSyncSection card updates for each | SyncStatus stream mock |
| E2E-1113 | Identity mismatch banner: degraded sync with wrong Firebase account | P1 | ad | en | syncIdentityStatusProvider = mismatched; IdentityMismatchBanner visible; resolve link shown | Cloud account, uid mismatch |
| E2E-1114 | Auth guard: first-launch flow (intro not seen) | P0 | — | en | `intro_seen=false` in prefs; AuthGuard redirects to /intro; AppIntroScreen shown | Fresh install prefs |
| E2E-1115 | Profile guard: 2+ profiles → profile picker redirect | P0 | ad | en | 2 profiles, no selectedProfileId; ProfileGuard redirects to /profile-picker | 2 profiles, no selection |
| E2E-1116 | Child mode guard: parent-mode routes blocked for child profiles | P0 | ch | en | Child profile; navigate to /gamification (adult-only); ChildModeGuard redirects to /redeem | Child profile |
| E2E-1117 | Persistent profile switcher bar: present on shell tabs and all sub-routes | P0 | ad | en | ProfileSwitcherBar visible on Dashboard, Learn, Progress, Settings; tap opens sheet | Any active profile |
| E2E-1118 | Tutor mode: enter talmid context, verify amber bar, exit | P0 | tu | en | Full tutor-entry flow; amber bar appears; switcher shows talmid; tap Exit → normal mode | Accepted grant |
| E2E-1119 | Parent-mode elevation: enter via PIN, view child banner, exit | P0 | ch | en | Child profile; PIN flow → parent mode; _ChildViewBanner shows; tap Exit → child mode | Child with PIN |

### Area 12 — Auth / Account

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1201 | Sign in with email — happy path | P0 | ad | en | SignInScreen renders; submit valid creds; authStateProvider→signedIn; shell Dashboard reached | Firebase emulator user |
| E2E-1202 | Sign in — wrong password error | P0 | ad | en | Error banner appears; button re-enables; no navigation | Same emulator user |
| E2E-1203 | Sign-up new account — adult | P0 | ad | en | SignupScreen; create account; onboarding flow starts; account in Drift | Fresh emulator |
| E2E-1204 | Account picker — switch account | P1 | ad | en | AccountPickerScreen lists 2 accounts; tap second → shell switches profile | 2 seeded accounts |
| E2E-1205 | Magic link — cold-start deep link consumed | P1 | ad | en | App cold-starts with email-link URI; magicLinkInitializationProvider processes; user signed in | AppLinks stub with pending URI |
| E2E-1206 | Google Sign-In — new user | P0 | ad | en | signInWithGoogle stub returns new AppUser; onboarding flow starts | Google stub override |
| E2E-1207 | Sign out via account actions sheet | P1 | ad | en | AccountActionsSheet; tap Sign Out; confirm → authState→signedOut → /intro | Signed-in account |
| E2E-1208 | Upgrade to cloud — email collision | P1 | ad | en | UpgradeToCloudScreen; existing email; EmailAlreadyExistsError; resolution options shown | Local-born account |
| E2E-1209 | Google Sign-In watchdog — picker abandoned 45s | P2 | ad | en | Google picker held >45s; watchdog fires SignInTimeout; error shown; subsequent attempt resolves cleanly | signInWithGoogle stub with 50s delay |
| E2E-1210 | Magic link — warm-start deep link consumed | P2 | ad | en | App in foreground; email-link deep link arrives; user signed in | AppLinks stub emitting warm URI |

### Area 13 — Sync / Offline

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1301 | Offline-first: all shell tabs render offline | P0 | ad | off | connectivityStreamProvider=false; Dashboard/Learn/Progress/Settings all render from Drift; no spinner hang | Seeded Drift, offline |
| E2E-1302 | Outbox write queued offline → flushed online | P1 | ad | off | Mark task offline; reconnect; outbox row consumed; syncWriteFacadeProvider.flush() called | outbox seeded |
| E2E-1303 | Sync status indicator — 7 states | P1 | ad | en | BackupSyncSection card cycles through: syncing, synced, error, pending, stale, offline, local-only | SyncStatus stream mock |
| E2E-1304 | Two-device sync — LWW merge | P1 | ad | en | Two in-memory DBs; conflicting completion; merge resolves LWW winner | DriftMergeStore |
| E2E-1305 | Degraded card — stuck outbox detected | P2 | ad | en | BackupSyncSection._buildDegradedCard appears when outbox row age > threshold | Seeded old outbox row |
| E2E-1306 | Offline banner: appears for cloud-born user when offline, hidden for local-born | P1 | ad | off | Cloud-born + offline: OfflineTopBanner visible; local-born + offline: banner absent | Both account types |

### Area 14 — Navigation / Guards

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1401 | Auth guard — unauthenticated redirect to /intro | P0 | — | en | 0 auth state; navigate to /dashboard → redirected to /intro | No auth |
| E2E-1402 | Profile guard — no-profile redirect to /onboarding | P0 | ad | en | Authenticated, 0 profiles → /onboarding | Auth, 0 profiles |
| E2E-1403 | PIN guard — child-mode screen requires PIN | P0 | ch | en | /parent-mode/settings without PIN → PinGuard → /parent-mode/pin-entry | Child profile, no PIN |
| E2E-1404 | Child mode guard — redirects child profile from adult screen | P0 | ch | en | ChildModeGuard on /gamification → /redeem | Child profile |
| E2E-1405 | Restore guard — fresh device triggers restore screen | P1 | ad | en | RestoreGuard.markNeedsRestore(); /restore shown; markRestoreComplete() → dashboard | RestoreGuard = needs-restore |
| E2E-1406 | Guard fail-safe — no lockout on guard exception | P1 | ad | en | Guard throws; top-level try/catch allows navigation to proceed | AuthGuard throws |
| E2E-1407 | Deep link — /invite?token=X routes to AcceptInvite (no auth required) | P0 | tu | en | AcceptInviteRoute has no authGuard; unauthenticated user reaches screen | Unauthenticated |
| E2E-1408 | No-profile auto-jump to Settings tab — switcher sheet has Skip to Settings | P1 | ad | en | 0 profiles; autoSelectedProfileIdProvider creates default; switcher shows Skip to Settings | 0 profiles, auto-create disabled |
| E2E-1409 | Guard chain: auth→profile→child→pin all pass in sequence | P1 | ch,pa | en | Full cold-start; every guard passes; child profile with PIN → parent mode screens reachable | Child profile with PIN |

### Area 15 — Hebrew RTL Dimension Variants

| id | name | P | modes | dims | key assertions | seed / pre |
|---|---|---|---|---|---|---|
| E2E-1501 | Dashboard RTL — no overflow, Hebrew dates | P1 | ad | he | Dashboard in he locale; DateFormat.yMMMd → "11 יוני 2026"; no text overflow | he locale |
| E2E-1502 | Learning screen RTL — Hebrew curriculum terms | P1 | ad | he | LearningScreen; CurriculumLabelRenderer produces Hebrew label; breadcrumb RTL | he locale, Mishnah track |
| E2E-1503 | Track wizard RTL — no overflow in wizard steps | P1 | ad | he | AddTrackFlow in he locale; all wizard steps render; study days grid no overflow | he locale |
| E2E-1504 | Scheduler RTL — task cards no overflow | P1 | ad | he | SchedulerScreen in he locale; DailyTaskCard Hebrew term; no row overflow | he locale |
| E2E-1505 | Progress screens RTL sweep | P1 | ad | he | ProgressScreen + RecentActivity + Lifetime + CurriculumProgress + SiyumimMilestones in he locale | he locale |
| E2E-1506 | Settings RTL — tiles and dialogs | P1 | ad | he | SettingsScreen tiles RTL; AccountActionsSheet RTL; no overflow | he locale |
| E2E-1507 | Tutoring screens RTL | P1 | ad | he | InviteTutor + AcceptInvite + ManageTutors in he locale; no overflow; date format locale-aware | he locale |
| E2E-1508 | Gamification screens RTL | P1 | ch | he | GamificationScreen + ChildRedemption in he locale; points counter no overflow | he locale |
| E2E-1509 | Profile picker + switcher sheet RTL | P1 | ad | he | ProfilePickerScreen + ProfileSwitcherSheet in he locale; names in RTL order | he locale |
| E2E-1510 | Onboarding flow RTL | P1 | ad | he | OnboardingScreen all steps in he locale; hardcoded-English strings flagged (see R-OB7) | he locale |
| E2E-1511 | City picker RTL — search results | P1 | ad | he | CityPickerScreen in he locale; "No matches" text hardcoded English (known gap); search list RTL | he locale |
| E2E-1512 | Overflow guard sweep — all 48 routed screens | P2 | ad | he | `expectNoOverflowAcrossDevices` sweep across all 48 `@RoutePage` screens in en + he; no overflow errors | All screens pumpable |

---

## 3. Implementation Waves

Waves are ordered P0 → P1 → P2 and grouped so each is a reviewable commit batch. All built on the proven harness at `test/e2e/harness/e2e_harness.dart`.

### Wave 1 — P0 Happy Paths (target: ~40 journeys)

**Goal:** All primary user-facing happy paths. Every primary feature area reachable in one session. CI gate: `PATH=/home/daniel/flutter/bin:$PATH LD_LIBRARY_PATH=/home/daniel/.local/lib/sqliteshim flutter test test/e2e/`.

| Journey IDs | Area |
|---|---|
| E2E-101, E2E-102, E2E-114, E2E-121, E2E-122 | Onboarding: adult + child + Google Sign-Up + intro paths |
| E2E-201, E2E-203, E2E-206, E2E-207, E2E-209 | Dashboard: adult daily check-in, empty+adult, all-caught-up, carousel, auto-refresh |
| E2E-212 | Dashboard: offline render |
| E2E-301, E2E-302, E2E-303, E2E-304, E2E-305 | Learning: mark complete (adult, child), tutor blocked, daf-paced, browse hierarchy |
| E2E-401, E2E-402, E2E-403, E2E-404, E2E-405, E2E-406, E2E-407 | Tracks: add self-paced, add program, re-add confirm, view detail, delete archive, delete wipe, delete last blocked |
| E2E-501, E2E-502, E2E-503, E2E-505, E2E-506, E2E-509, E2E-514 | Scheduler: today tasks, overdue, skip+undo, create deadline goal, create pace goal, study-day chazara config, program track |
| E2E-601, E2E-602, E2E-603, E2E-604 | Gamification: create+redeem happy path, approve, decline, point config |
| E2E-701, E2E-702, E2E-703, E2E-704, E2E-705, E2E-706, E2E-720 | Profiles: create child+adult, picker, switcher, parent mode, PIN setup, auto-select |
| E2E-801, E2E-802, E2E-804, E2E-805, E2E-807, E2E-808 | Progress: first-visit empty, populated adult, recent activity, siyumim, lifetime, curriculum progress |
| E2E-901, E2E-902, E2E-903, E2E-907, E2E-910, E2E-912, E2E-913, E2E-914, E2E-916 | Settings: adult+child rows, account sheet, backup+sync card, upgrade, lifetime marking, child block, parental controls, sign-out |
| E2E-1001, E2E-1002, E2E-1003, E2E-1005, E2E-1007, E2E-1010, E2E-1012 | Tutoring: invite, accept deep-link, accept from picker, enter session, revoke, PIN setup, no-mark invariant |
| E2E-1101, E2E-1103, E2E-1105, E2E-1109, E2E-1110 | Infra: city picker, sacred time lock, notifications, device restore happy + error+retry |
| E2E-1201, E2E-1202, E2E-1203, E2E-1206 | Auth: sign-in, wrong-password, sign-up, Google new user |
| E2E-1301 | Sync: offline-first render |
| E2E-1401, E2E-1402, E2E-1403, E2E-1404, E2E-1407 | Guards: auth, profile, PIN, child mode, deep-link |

### Wave 2 — P1 Important Paths (~120 journeys)

All remaining P1 journeys not in Wave 1. Adds offline variants, tutor read-only, dimension variants, error states, management flows.

**Onboarding P1:** E2E-103, E2E-104, E2E-105, E2E-106, E2E-108, E2E-109, E2E-111, E2E-112, E2E-113, E2E-115, E2E-116, E2E-117, E2E-118, E2E-119, E2E-120  
**Dashboard P1:** E2E-204, E2E-205, E2E-208, E2E-210, E2E-211, E2E-213, E2E-214, E2E-215  
**Learning P1:** E2E-306, E2E-307, E2E-308, E2E-309, E2E-310, E2E-311  
**Tracks P1:** E2E-408, E2E-409, E2E-410, E2E-411, E2E-412, E2E-413, E2E-414, E2E-415, E2E-416  
**Scheduler P1:** E2E-504, E2E-507, E2E-508, E2E-510, E2E-511, E2E-512, E2E-513, E2E-515, E2E-516, E2E-517, E2E-518  
**Gamification P1:** E2E-605, E2E-606, E2E-607, E2E-608, E2E-609, E2E-610, E2E-611, E2E-612, E2E-613  
**Profiles P1:** E2E-707, E2E-708, E2E-709, E2E-710, E2E-711, E2E-712, E2E-713, E2E-714, E2E-715, E2E-716, E2E-717, E2E-718  
**Progress P1:** E2E-803, E2E-806, E2E-809, E2E-810, E2E-811, E2E-812 (he), E2E-813, E2E-814  
**Settings P1:** E2E-904, E2E-905, E2E-906, E2E-908, E2E-909, E2E-911, E2E-915, E2E-917, E2E-918, E2E-920, E2E-921, E2E-922, E2E-923  
**Tutoring P1:** E2E-1004, E2E-1006, E2E-1008, E2E-1009, E2E-1011, E2E-1013, E2E-1014, E2E-1015  
**Infra P1:** E2E-1102, E2E-1104, E2E-1106, E2E-1107, E2E-1108, E2E-1111, E2E-1112, E2E-1113  
**Auth P1:** E2E-1204, E2E-1205, E2E-1207, E2E-1208  
**Sync P1:** E2E-1302, E2E-1303, E2E-1304, E2E-1306  
**Guards P1:** E2E-1405, E2E-1406, E2E-1408, E2E-1409  
**Hebrew RTL P1:** E2E-1501 – E2E-1511

### Wave 3 — P2 Edge Cases, Dimension Variants, Overflow Guard (~22 journeys)

- E2E-107 Legacy onboarding resume
- E2E-110 AddTrackFlow cancel with no profile
- E2E-216 Self-paced current focus range
- E2E-312 View-all tasks with skip+undo
- E2E-313 RTL breadcrumb
- E2E-417 Tutor viewing tracks read-only
- E2E-418 Whole-curriculum learning order
- E2E-614 Gamification pull-to-refresh
- E2E-615 Stock template milestones stripped
- E2E-616 Gamification he RTL
- E2E-719 Offline delete profile cloud-born
- E2E-721 Profile name duplicate validation
- E2E-919 Curriculum settings + program request
- E2E-1103 Sacred time overlay (full app wrapper needed — see risk R-IC2)
- E2E-1104 In-Israel toggle
- E2E-1209 Google watchdog timeout
- E2E-1210 Magic link warm-start
- E2E-1305 Degraded card stuck outbox
- E2E-1512 `expectNoOverflowAcrossDevices` sweep all 48 screens en+he

---

## 4. Harness API Summary

All journeys build on the proven in-process harness. Reference implementation: `test/e2e/harness/e2e_harness.dart`.

### Core harness helpers

```dart
// Boot the full app as a signed-in adult
final identity = E2EIdentity.localBorn(displayName: 'Alice');
final h = E2EHarness(tester, identity: identity);
addTearDown(h.dispose);
await h.pumpApp(
  path: '/dashboard',
  extraOverrides: h.dashboardSilenceOverrides,
);

// Assertions
h.expectOnScreen('DASHBOARD');
h.expectNotOnScreen('SELF-LEARNER');

// Interaction
await h.tapText('LEARN');
await h.tapByKey(const Key('mark_complete_button'));
await h.enterText(find.byType(TextField), 'Alice');

// Direct DB assertions
final profiles = await h.db.profileDao.getProfilesByAccount(identity.accountId);
expect(profiles.first.displayName, 'Alice');

// Router state
expect(h.router.current.name, 'DashboardRoute');
```

### Standard Riverpod overrides per feature area

```dart
// Auth (already in harness defaults)
authStateProvider.overrideWithValue(AuthState.signedIn(user, tier: Tier.localBorn)),
authRepositoryProvider.overrideWithValue(_StubAuthRepository()),

// Database (already in harness defaults)
userDatabaseProvider.overrideWithValue(db),              // in-memory
appDatabaseProvider.overrideWithValue(db),
contentDatabaseProvider.overrideWithValue(cdb),          // GAP: not in harness yet

// Profile (already in harness defaults when identity provided)
activeProfileIdProvider.overrideWith(() => _FixedProfileId(id)),
selectedProfileIdProvider.overrideWith(() => _FixedSelectedProfile(id)),
profileListStreamProvider.overrideWith((ref) => Stream.value([profile])),

// Clock
clockProvider.overrideWithValue(DateTime.utc(2026, 6, 18)),

// Connectivity
connectivityStreamProvider.overrideWith((ref) => Stream.value(false)), // offline

// Daily tasks (bypass full projection engine)
allDailyTasksProvider.overrideWith((ref) => Future.value([...tasks])),

// Sync (already in harness defaults)
syncWriteFacadeProvider.overrideWithValue(null),
syncOrchestratorProvider.overrideWithValue(null),

// Tutor session
activeTutoredProfileSelectionProvider,                   // call .enter(selection) in test setup
activeTutorPermissionsProvider.overrideWith((ref) => TutorPermissions(...)),
incomingTutorGrantsProvider.overrideWith((ref) => AsyncValue.data(grants)),
tutorGrantRepositoryProvider.overrideWithValue(fakeTutorGrantRepo),

// Gamification
dashboardUserModeProvider.overrideWith((ref) => AsyncValue.data(ProfileMode.child)),
childRedemptionBalanceProvider.overrideWith((ref) => Stream.value(100)),
achievementsOverviewProvider.overrideWith((ref) => AsyncValue.data(overview)),

// Hebrew locale
useHebrewTermsProvider.overrideWith(() => ...),
useHebrewDateProvider.overrideWith((ref) => true),
currentTransliterationVariantProvider.overrideWithValue(ashkenazi),

// Sacred time
currentSacredWindowProvider.overrideWith((ref) => ActiveSacredWindow(...)),

// Notifications
notificationServiceProvider.overrideWithValue(FakeNotificationGateway()),

// Content (for text display and hierarchy tests)
contentRepositoryProvider.overrideWith((ref) => StubContentRepository()),

// Calendar programs (for program track tests)
calendarProgramServiceProvider.overrideWithValue(FakeCalendarProgramService()),

// PIN (already in harness as _NullPinService; override for PIN tests)
pinServiceProvider.overrideWithValue(FakePinService(hasPin: true)),
```

### SharedPreferences seeds

```dart
SharedPreferences.setMockInitialValues({
  'onboarding_complete': true,     // harness default
  'intro_seen': true,              // skip AppIntroScreen
  'permissions_prompted': true,    // skip PermissionPromptScreen
  'onboarding_skipped': false,
  'onboarding_phase': 'addTrack', // resume test
  'onboarding_profile_id': '1',
  // per-profile notification prefs:
  'reminder_enabled_1': true,
  'reminder_time_1': '19:00',
});
```

### Harness gaps to address before Wave 1

| Gap | Action |
|---|---|
| `contentDatabaseProvider` not overridden in harness | Add second in-memory NativeDatabase override for `contentDatabaseProvider` |
| `PersistentSwitcherScaffold` not mounted in harness `_buildMaterialApp` | Switcher-bar tests must pump `LearningTrackerApp` directly (device test) or wrap via builder |
| `SacredTimeLockOverlay` not in harness | Lock-overlay tests require device test or explicit app-widget wrap |
| `rootScaffoldMessengerKey` not wired | `UpgradeToCloud` MaterialBanner tests need root key |

---

## 5. Coverage Matrix — Screen to Journey

Every `@RoutePage` screen must be reached by at least one journey. Screens marked `[GAP]` have no assigned journey.

### Routed screens

| Screen (route) | Journey IDs | Notes |
|---|---|---|
| AppIntroScreen (`/intro`) | E2E-121, E2E-122, E2E-1114, E2E-1401 | |
| SignInScreen (`/sign-in`) | E2E-1201, E2E-1202 | |
| SignupScreen (`/create-account`) | E2E-1203 | |
| AccountPickerScreen (`/account-picker`) | E2E-1204 | |
| UpgradeToCloudScreen (`/upgrade-to-cloud`) | E2E-907, E2E-910, E2E-911, E2E-1208 | |
| OnboardingScreen (`/onboarding`) | E2E-101, E2E-102, E2E-114, E2E-1402 | |
| EmptyLoginScreen (`/empty-login`) | E2E-104 | |
| PermissionPromptScreen (`/permission-prompt`) | E2E-117 | |
| DeviceRestoreScreen (`/restore`) | E2E-1109, E2E-1110, E2E-1405 | |
| ProfilePickerScreen (`/profile-picker`) | E2E-703, E2E-1115 | |
| ManageLearnersScreen (`/manage-learners`) | E2E-710 | Note: no PIN guard on route — security gap (R-PR10) |
| AppShell (`/`) | E2E-201, E2E-301, E2E-801, E2E-901 | Parent shell for tabs |
| DashboardScreen (`/dashboard`) | E2E-201–E2E-216 | |
| LearningScreen (`/learn`) | E2E-301–E2E-313 | |
| ProgressScreen (`/progress`) | E2E-801, E2E-802, E2E-803, E2E-809 | |
| SettingsScreen (`/settings`) | E2E-901–E2E-923 | |
| SiyumimMilestonesScreen (`/journey`) | E2E-805, E2E-806 | |
| RecentActivityScreen (`/progress/recent`) | E2E-804 | |
| LifetimeKnowledgeScreen (`/progress/lifetime`) | E2E-807 | |
| CurriculumListScreen (`/browse`) | E2E-305 | |
| ContentHierarchyScreen (`/curriculum/:id/browse`) | E2E-305 | |
| CurriculumProgressScreen (`/curriculum/:id/progress`) | E2E-808, E2E-814 | |
| CurriculumSettingsScreen (`/curriculum/:id/settings`) | E2E-919 | |
| ContentSearchScreen (`/curriculum/:id/search`) | E2E-306 | |
| TextDisplayScreen (`/text/:sefariaRef`) | E2E-308, E2E-311 | |
| SchedulerScreen (`/scheduler`) | E2E-501–E2E-518 | |
| GamificationScreen (`/gamification`) | E2E-611, E2E-1116 | childModeGuard tested via E2E-1404/1116 |
| ChildRedemptionScreen (`/redeem`) | E2E-601 (partial), E2E-609 | |
| ParentPendingRedemptionsScreen (`/parent-mode/pending-redemptions`) | E2E-602, E2E-603 | |
| NotificationsScreen (`/notifications`) | E2E-1105 | |
| CityPickerScreen (`/sacred-time/city`) | E2E-1101, E2E-1102 | |
| ParentSettingsScreen (`/parent-mode/settings`) | E2E-914, E2E-915 | |
| PointConfigScreen (`/parent-mode/point-config`) | E2E-604, E2E-612 | |
| RewardConfigurationScreen (`/parent-mode/reward-config`) | E2E-601, E2E-605, E2E-606, E2E-607 | |
| PinFlowScreen — Setup (`/parent-mode/pin-setup`) | E2E-706, E2E-1403 | |
| PinFlowScreen — Verify (`/parent-mode/pin-entry`) | E2E-705, E2E-1403 | |
| PinFlowScreen — Change (`/parent-mode/pin-change`) | E2E-714 | |
| ParentTrackManagementScreen (`/parent-mode/tracks`) | E2E-414 | |
| StudyDayConfigScreen (`/study-days/:curriculumId`) | E2E-509, E2E-510, E2E-511, E2E-920 | |
| TrackManagementHubScreen (`/settings/tracks`) | E2E-401 | |
| TrackDetailScreen (`/settings/tracks/detail`) | E2E-404, E2E-415 | |
| LifetimeMarkingScreen (`/settings/lifetime`) | E2E-912, E2E-913 | |
| LifetimeCurriculumMarkingScreen (`/settings/lifetime/:curriculumId`) | E2E-912 | |
| LearningOrderScreen (`/curriculum/:id/order`) | E2E-418 | |
| ManageTutorsScreen (`/tutor/manage-tutors`) | E2E-1006, E2E-1007 | |
| ManageGrantsScreen (`/tutor/my-grants`) | E2E-1005, E2E-1008 | |
| TutorAuditLogScreen (`/tutor/audit-log`) | E2E-1009 | |
| InviteTutorScreen (`/tutor/invite`) | E2E-1001 | |
| AcceptInviteScreen (`/invite`) | E2E-1002, E2E-1003, E2E-1407 | |
| DeclineInviteScreen (`/tutor/decline`) | E2E-1004 | |

### Non-routed screens (Navigator push — no AutoRoute path)

| Screen | Journey IDs | Notes |
|---|---|---|
| EditTrackScreen | E2E-408, E2E-409, E2E-410 | Push from TrackDetailScreen |
| TrackLearningOrderScreen | E2E-411 | Push from TrackDetailScreen; distinct from LearningOrderScreen |
| GoalSetupScreen | E2E-415, E2E-505 | Navigator push; no AutoRoute guard chain |
| ScopeSelectionScreen | [GAP] | No AutoRoute; no call site found in settings; suspected dead screen (R-ST1) |
| TutorPinSetupScreen | E2E-1010 | Navigator push from tutoring settings |
| TutorPinResetScreen | E2E-1011 | Navigator push from tutoring settings |
| BulkMarkScreen | E2E-119, E2E-412 | Push from onboarding wizard + LifetimeCurriculumMarkingScreen |

### Named dialogs and sheets

| Dialog / Sheet | Journey IDs |
|---|---|
| ProfileSwitcherSheet | E2E-213, E2E-704, E2E-708 |
| showAddProfileDialog | E2E-708 |
| ProfileEditFormDialog | E2E-709, E2E-712 |
| showParentPinSetupDialog | E2E-706 |
| showParentPinVerificationDialog | E2E-705 |
| showParentPinChangeDialog | E2E-714 |
| showTutorPinVerificationDialog | E2E-1010 |
| showAccountActionsSheet | E2E-902, E2E-903, E2E-916 |
| showDeleteAccountDialog | E2E-917 |
| showReauthenticateDialog | E2E-917 |
| showChangePasswordDialog | E2E-902 |
| showEmailVerificationDialog | E2E-116 |
| showDeleteDialog (track) | E2E-405, E2E-406 |
| showAdjustPointsDialog | E2E-612 |
| ReorderConfirmDialog | E2E-411 |
| ResetOrderDialog | E2E-411, E2E-418 |
| AchievementUnlockCelebration | E2E-302, E2E-610 |
| HebrewDatePicker | E2E-508 |
| TutorPinEntryGate | E2E-1005, E2E-1010 |
| RevokeGrantDialog | E2E-1007 |
| AcceptInviteDialog (6-step) | E2E-1002 |

### Identified gaps (screens with no assigned journey — close before Wave 2 finishes)

1. `ScopeSelectionScreen` — No AutoRoute registration; no call site found in live code; suspected dead (R-ST1). Verify before Wave 2; if alive, add journey.
2. Named dialog `showDeleteDialog` for profile delete — covered by E2E-710, E2E-711 but note path divergence between picker and switcher sheet.

---

## 6. Lower-Layer Cross-Reference

The E2E layer (headless `flutter test test/e2e/`) owns **through-the-UI journeys**. It does NOT duplicate what is tested in lower layers:

| Lower layer | Location | What it owns — E2E does NOT repeat |
|---|---|---|
| **Codec-rules contract** | `test/story_acceptance/epic_25_story_9_lints_test.dart` + custom lints | Layering invariants: no cross-feature imports, Firebase confined to core, Talker to logging, `.displayName*` access confined to labels |
| **Emulator Firestore rules suite** | Firebase `rules-unit-testing` suite (`make test-rules`) | All 24+ Firestore security-rules paths (read/write per collection, tutor write-block, hasOnly, default-deny) |
| **Cloud Function unit tests** | `functions/test/` via `firebase-functions-test` | All CF auth/state-machine branches: `acceptTutorInvite`, `tutorBulkPriorCompletions` live-forward block, `purgeExpiredAuditLogs` |
| **Merge round-trip tests** | `test/story_acceptance/epic_25_story_13_merge_router_test.dart` | DriftMergeStore LWW logic, outbox codec, data export round-trip |
| **Overflow guard tests** | `test/helpers/overflow_harness.dart` + `test/widget/step_overflow_test.dart` | Layout overflow across device matrix — E2E Wave 3 calls the same helper for new screens not yet in the guard suite |
| **Story acceptance tests** | `test/story_acceptance/epic_*` | Story-level unit/widget behaviour; E2E adds the through-the-router navigation layer on top |

**Boundary rule:** When a bug is caught by the Firestore rules suite (e.g. a tutor trying to write a live completion), the E2E test asserts the UI outcome (button absent) but does NOT re-test the rules path. E2E-1012 (tutor no-mark invariant) asserts the UI button is absent; the rules + CF test asserts the server-side rejection. Both must pass independently.

---

## 7. Known Risks — Consolidated from All Area Audits

Each risk is tagged with the area audit it came from, and the journey that covers it.

### Onboarding risks (R-OB)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-OB1 | `TransliterationVariant` not surfaced in OnboardingProfileCreationStep — Sephardi users must change in Settings post-onboarding | — | Document intentional; no E2E needed yet |
| R-OB2 | `kPermissionsPrompted` race: one-frame blank before `postFrameCallback` fires | E2E-117 | Assert no blank frame; pump extra frame after mount |
| R-OB3 | `_addAnotherLearner` resets `_profileMode` to 'adult' unconditionally | E2E-109 | Assert second learner profile defaults to adult mode |
| R-OB4 | `OnboardingDoneStep` is dead code — never reached | — | Document dead code; no journey needed |
| R-OB5 | Unauthenticated bounce uses `addPostFrameCallback` — one-frame race | — | Covered by harness auth override; no special journey |
| R-OB6 | BulkMarkScreen container-row expunge deferred when `_resolvedItems` is null | E2E-119 | Assert all selected items present in Drift after confirm |
| R-OB7 | (FIXED) Profile-mode display text hardcoded English — breaks Hebrew locale | E2E-1510 | Assert he-RTL variant shows localised text — now a live, un-skipped assertion |
| R-OB8 | WizardCustomStep2 'Weeks' mode allows 0 days — produces `daysOfWeek=[]` | — | No E2E; unit test for `CustomRound` validation |
| R-OB9 | `_onAddTrackCancel` with `_createdProfileId=null` silently routes to profileCreation | E2E-110 | Assert profile row not orphaned in Drift |
| R-OB10 | Multi-profile post-onboarding: second profile may not have a track when routing to picker | E2E-120 | Assert both profiles have >=1 track before picker shown |

### Dashboard risks (R-DB)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-DB1 | `anyActiveTrackHasChazaraProvider` vs per-card `trackHasChazaraProvider` transient disagreement — one-frame mismatch | E2E-214 | Assert settled state; pump until providers agree |
| R-DB2 | `tasksReady` race when `allDailyTasksProvider` resolves before tracks | E2E-201 | Assert no false "all caught up" on first load |
| R-DB3 | Greeting uses active profile name (talmid in tutored session) — historical regression | E2E-210 | Assert greeting shows talmid name not signed-in user |
| R-DB4 | `CurriculumSummaryCard` dead but has hardcoded English — could be re-activated | — | Flag in code review; no E2E for dead code |
| R-DB5 | `PointsSummaryWidget` dead with hardcoded English | — | Same |
| R-DB6 | `SkippedOnboardingCtaBanner` flag not cleared on profile add — shows again on next empty-track state | E2E-205 | Assert flag cleared after Setup tap |
| R-DB7 | ActiveTracksCarousel `SizedBox(height: 460)` clips on large text scale | E2E-1512 | Overflow guard sweep |
| R-DB8 | `dashboardModelProvider` unmaintained parallel — could drift from actual provider list | — | Code review; no E2E |
| R-DB9 | Lifecycle listener auth change relies on uid stream freshness | — | Unit test for lifecycle observer |
| R-DB10 | Streak chip double-push guard — `isGamificationRouteActive` staleness race | E2E-202 | Assert single navigation event on streak chip tap |

### Learning + Content Browsing risks (R-LC)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-LC1 | `CurriculumListScreen` search button `onPressed: {}` — decorative | E2E-305 | Assert button exists; assert search result from ContentSearchScreen instead |
| R-LC2 | `contentDatabaseProvider` not stubbed in harness | — | Fix before Wave 1 (harness gap) |
| R-LC3 | `completionCommittedProvider` keepAlive — non-zero between tests | — | Reset between tests or isolate per-container |
| R-LC4 | `adjacentContentRefsProvider` N×thousands scan — timeout risk | E2E-311 | Stub `contentRepositoryProvider` with small fixed list |
| R-LC5 | `trackStorageKeyForTrackIdProvider` always returns 'personal' | — | Assert trackType='personal'; document known stub |
| R-LC6 | `onLongPress` on `ContentItemTile` null when count=0 | E2E-307 | Seed completions before long-press test |
| R-LC7 | RTL breadcrumb panel uses hardcoded `Icons.chevron_right` | E2E-313 | Assert RTL separator icon correct (visual gap) |
| R-LC8 | LearningScreen Browse section shows all curricula incl. those with no track | — | Document; product decision |
| R-LC9 | `_StageBreakdownSheet` uses `FutureBuilder` — first frame shows fallback labels | E2E-307 | Await `pumpAndSettle` before asserting stage names |
| R-LC10 | `OptimisticCompletionState` not rolled back on write failure | E2E-301 (error sub-case) | Stub `markCompletionUseCaseProvider` to throw; assert item reverts |
| R-LC11 | Optimistic path never invoked in real `_handleComplete` flow | — | Code review; document design intent gap |

### Tracks risks (R-TR)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-TR1 | `TrackManagementBody` vs `TrackManagementHubScreen` diverging delete logic | E2E-403, E2E-405 | Cover both code paths in journeys |
| R-TR2 | `ParentTrackManagementScreen` delete dialog misses last-curriculum guard | E2E-414 | Assert last-track guard fires from parent-mode screen |
| R-TR3 | `_finishFlow` `unawaited` for `_applySelfPacedPriorCompletions` — errors swallowed | E2E-412 | Inject error; assert no crash; document silent failure |
| R-TR4 | StartingPositionCalendarMode error state hardcoded English 'No local calendar entry found' | — | Flag in l10n audit; not yet an E2E journey |
| R-TR5 | `EditTrackScreen._buildDeadlineEditor` uses `DateFormat.yMMMd` not `formatTrackDate` — ignores Hebrew calendar pref | E2E-416 he variant | Assert deadline displays locale-correctly |
| R-TR6 | Wizard resume: chazara result and goal null after app-kill mid-wizard | E2E-413 | Seed wizard state; assert no null crash on resume |
| R-TR7 | Progress bar step label mismatch: 'STEP 1 OF 5' vs bar at 1/6 | — | Cosmetic; document |
| R-TR8 | `TrackLearningOrderScreen` has no AppBar back button | — | Confirm Android system back works; document gap |
| R-TR9 | 'Controlled by parent' banner hardcoded English | E2E-417 he variant | Assert he locale shows Hebrew text |
| R-TR10 | Wizard chazara step `_buildChazaraStep` for open-chazara program: `programName=null` on resume | E2E-413 | Assert empty string not null crash |

### Scheduler risks (R-SC)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-SC1 | `HebrewDatePicker` 4 hardcoded English strings | E2E-508, E2E-1504 he | Assert he locale shows Hebrew (or flag as known gap) |
| R-SC2 | `_summaryForSection` 3 hardcoded English template strings | E2E-516 he | Assert he locale: no raw English section summary |
| R-SC3 | `PaceIndicator` dead widget with hardcoded English strings | — | Dead code; no E2E |
| R-SC4 | `toggleStudyDayProvider` deprecated/dead — risk of accidental use | — | Code review |
| R-SC5 | `GoalSetupScreen` not an `@RoutePage` — no auto_route guard chain | E2E-505 | Test via Navigator push pattern (standalone pump) |
| R-SC6 | Completion-filter dual-stage-id ambiguity: `c.stageId == task.stageDefinitionId || c.stageId == task.stageOrder` | — | Unit test for edge case; not a UI journey |
| R-SC7 | `StudyDayConfigScreen._toggleDay` mounted-check gap | E2E-509 | Pump after toggle; assert no mounted-check crash |
| R-SC8 | `/scheduler` has no child-mode guard — children can reach it via notification tap | E2E-502 (child variant) | Assert scheduler renders for child; document as intentional or flag |
| R-SC9 | `schedulerGroupedViewProvider` not persisted across restarts | E2E-504 | Assert grouped state resets on re-pump |
| R-SC10 | Reorder-amnesty program-track interaction fragile | E2E-517 | Assert no phantom overdue with explicit anchor |
| R-SC11 | `GoalSetupForm._now()` uses `ref.read` not `ref.watch` — clock override must precede form mount | E2E-505 | Set clockProvider before pumpApp |

### Gamification risks (R-GA)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-GA1 | `RewardMilestoneService` in SharedPreferences not in Drift — no offline-first guarantee; corruption returns `[]` | E2E-613 | Seed prefs; assert offline reward persist |
| R-GA2 | Unlocked milestone can flip back to locked after redemption debit | E2E-602 (post-redemption assertion) | Assert milestone count after redemption |
| R-GA3 | `RewardSaveDuplicateThreshold` dead branch — `saveReward()` never returns it | — | Dead code; no E2E |
| R-GA4 | `_showAdjustPointsDialog` controllers not disposed on cancel | — | Leak; no E2E; flutter_test disposes on teardown |
| R-GA5 | `AchievementUnlockCelebration` orphaned dialog on profile switch | E2E-610 | Verify dialog dismissed before profile switch |
| R-GA6 | `_pointConfigDataProvider` side effects inside FutureProvider | — | Unit test for duplicate-write race |
| R-GA7 | `GamificationScreen` adult-mode flash before child-mode guard confirms | E2E-1116 | Assert no adult-mode content flash on child profile |
| R-GA8 | `pendingRedemptionsCountProvider` multi-profile count isolation | E2E-602 (multi-profile) | Assert counts per-profile isolated |
| R-GA9 | `ChildRedemptionScreen` error state shows raw `e.toString()` | — | L1 widget test; not full E2E |
| R-GA10 | `_SubtleStreakDisplay` `'(best: $maxStreak)'` hardcoded English | E2E-616 he | Assert he locale; flag as gap |

### Profiles risks (R-PR)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-PR1 | Last-profile delete inconsistency between picker path and switcher sheet path | E2E-711 | Cover both delete-last code paths |
| R-PR2 | Online check for cloud-born delete only in picker path; switcher sheet proceeds offline | E2E-719 | Assert switcher-sheet delete offline behaviour |
| R-PR3 | `PinFlowController` keepAlive stale-buffer race with `mountToken` fix | E2E-706 | Assert PIN setup from cold state; no stale digit |
| R-PR4 | Mode toggle in edit dialog: child→adult does not clear orphaned PIN in SecureStorage | E2E-712 | Assert after mode change: no stale PIN blocks parent mode |
| R-PR5 | Switcher sheet stays mounted behind dialog on context killed mid-close | E2E-708 | Pump after dialog close; assert sheet dismissed |
| R-PR6 | `TutoredChildrenSection` `context.mounted` guard is no-op on `ConsumerWidget` | — | Code review; risk only on mid-async unmount |
| R-PR7 | `_PendingInviteCard` looks identical for all pending invites — ambiguous multi-invite | E2E-717 | Assert first invite accepted; document ordering |
| R-PR8 | `ProfileSwitcherBar` RTL dead-zone on wrong side | E2E-1509 | Assert switcher tap area in RTL; no accidental back intercept |
| R-PR9 | `autoSelectedProfileIdProvider` silently creates profile with no user notification | E2E-720 | Assert display name derived from auth user; snackbar or absence documented |
| R-PR10 | `ManageLearnersScreen` no PIN guard in router — child could reach and modify profiles | E2E-710 | Assert adult-only access; flag security gap |

### Progress risks (R-PG)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-PG1 | `recentActivityPointsProvider` always passes `ProfileMode.child` regardless of actual user mode | — | Low risk (hidden for adults); document |
| R-PG2 | `SiyumimMilestonesScreen` formerly 'Learning Journey' — tests using literal `/journey` | E2E-805 | Use `SiyumimMilestonesRoute()`, not literal path |
| R-PG3 | `MonthlyActivitySliverCalendar` dead widget with hardcoded English | — | Dead code; document |
| R-PG4 | `_LifetimeSourceFilter` local state resets on every navigation | E2E-807 | Re-select toggle in each test; assert default all-sources |
| R-PG5 | `CurriculumProgressScreen._curriculumEnum()` `firstWhere` throws on unknown key | E2E-808 (error sub-case) | Inject unknown curriculumId; assert error state |
| R-PG6 | `anyActiveTrackHasChazaraProvider` not invalidated on completion commit | E2E-811 | Assert chazara state after adding stage-enabled track mid-session |
| R-PG7 | `SiyumimMilestonesScreen` profileId query param: no access-control check | E2E-806 | Document; flag security gap; assert any auth user can load |
| R-PG8 | `lifetimeDataProvider` N per-curriculum async calls for subset ledger | E2E-807 | Stub `contentRepositoryProvider`; avoid file I/O latency |
| R-PG9 | `journeySortModeProvider` not persisted — test order may matter | E2E-805 | Reset to default in teardown |
| R-PG10 | `formatFractionAsPercent` clamp: lifetimePct>1.0 before clamp masks data inconsistency | — | Unit test; not a UI journey |
| R-PG11 | `RefreshIndicator.onRefresh` does not await providers — spinner dismisses before data | E2E-808 | `pumpAndSettle` after pull; assert updated data |
| R-PG12 | `ProgressTierCounterRow` RTL narrow-device overflow risk | E2E-1512 | Overflow guard sweep; assert no overflow in he |

### Settings risks (R-ST)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-ST1 | `ScopeSelectionScreen` no AutoRoute registration, no live call site — suspected dead | — | Verify call site before Wave 2; if dead, remove from matrix |
| R-ST2 | `LifetimeMarkingScreen` reachable from Settings via MaterialPageRoute bypassing PIN guard | E2E-912, E2E-913 | Assert PIN required; flag guard gap |
| R-ST3 | `DataExportImportService` no UI wiring — dead service | — | Dead code; document |
| R-ST4 | `BackupSyncSection` cold-start `pullOnLaunch` 8s timeout swallows exceptions — test may hang | E2E-908 | Inject `syncOrchestratorProvider` fake; assert no 8s hang |
| R-ST5 | `_ParentalControlsSection` async `_load()` in `initState` — extra pump needed | E2E-914 | Pump extra frame after mount before asserting PIN state |
| R-ST6 | `AccountActionsSheet` uses pageContext/pageRef — post-pop flows need extra pump | E2E-916 | Extra pump after sheet close; assert post-sheet navigation |
| R-ST7 | Delete account overlay `_DeletingAccountOverlay` uses `UncontrolledProviderScope` — not testable headless | E2E-917 | Device integration test for delete flow |
| R-ST8 | `UpgradeToCloud._isCredentialLess` derived from email `@offline.local` suffix | E2E-910, E2E-911 | Supply matching email in authState override |
| R-ST9 | Sacred Time detect/choose buttons have no `ValueKey` — fragile finds in he locale | — | Add `ValueKey` before Wave 2 test writing |
| R-ST10 | `StudyDayConfigScreen._toggleDay` unawaited `.then()` chain | E2E-920 | `pumpAndSettle` after toggle; assert DB state |
| R-ST11 | `LifetimeCurriculumMarkingScreen._hasNavStack` / `_navPathLength` not exposed via keys | E2E-912 | Use `find.byType(HierarchySelectionPanel)` for hierarchy navigation |
| R-ST12 | Version footer `PackageInfo.fromPlatform()` not mocked in harness — silently returns null | — | Mock MethodChannel if testing footer specifically |

### Tutoring risks (R-TU)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-TU1 | Revoke/Rescind dialogs are plain `AlertDialog`, not `showAppDialog` — overflow risk | E2E-1007, E2E-1006 | Add to overflow guard sweep; assert no overflow on narrow device |
| R-TU2 | ManageTutors pull-to-refresh silently swallows permission-denied as empty list | E2E-1007 | Inject permission-denied on refresh; assert error state shown |
| R-TU3 | Two `incomingTutorGrants` providers (different instances) — import alias risk | — | Code review; document import alias invariant |
| R-TU4 | `TutorPinResetScreen` sends password-reset email — confusing for Google-sign-in users | E2E-1011 | Assert reset email sent; document UX gap |
| R-TU5 | `tutorAuditLogWriteRepositoryProvider` is a stub no-op — audit entries never written | E2E-1009 | Pre-seed events via fake repo; document production gap |
| R-TU6 | `DeclineInviteScreen` has `assert((token != null) != (grant != null))` — compiled out in release | E2E-1004 | Test with both null; assert safe error state |
| R-TU7 | `_fireEntryPullAndNavigate` `dismissLoading()` after widget unmount — `context.mounted` gap | E2E-1005 | Assert no `setState after dispose` error; pump after navigation |
| R-TU8 | `_ViewInvitationsRow` double `Navigator.pop()` — second pop conditional on `canPop` | E2E-1003, E2E-717 | Assert final navigation state after double-pop |
| R-TU9 | `InviteTutorScreen` keyboard not dismissed on submit — overlays snackbar on small viewports | — | UX gap; document |
| R-TU10 | `TutorAuditLogScreen` date uses numeric `dt.day/dt.month` not locale-aware format | E2E-1009 | Assert locale-aware date format |
| R-TU11 | `TutorAuditLogScreen` 'To'/'From' date pickers: from > to range possible | — | Edge case; manual QA |
| R-TU12 | 'Invite a tutor' button always visible even when active grant exists | — | UX gap; document |

### Infra-Crosscutting risks (R-IC)

| # | Risk | Journey | Action |
|---|---|---|---|
| R-IC1 | `PersistentSwitcherScaffold` not in harness `_buildMaterialApp` | E2E-213, E2E-1117 | Use device integration test or wrap with `LearningTrackerApp` |
| R-IC2 | `SacredTimeLockOverlay` not in harness | E2E-1103 | Device integration test or explicit app-widget wrap |
| R-IC3 | CityPickerScreen 'No matches' text hardcoded English | E2E-1511 he | Flag as gap; assert English literal visible in he (known bug) |
| R-IC4 | `DeviceNotificationToggle` default value: `permitted ?? true` shows ON while loading | E2E-1105 | Extra pump to settle async `_checkPermission`; check subtitle 'Checking...' |
| R-IC5 | Notification toggle async default race on profile switch | E2E-1108 | Extra pump after profile switch; assert correct persisted state |
| R-IC6 | Persistent switcher dead-zone wrong side in RTL | E2E-1509 | Assert RTL tap area; document |
| R-IC7 | `UpgradeToCloud` MaterialBanner via `rootScaffoldMessengerKey` — not in harness | E2E-907 | Device integration test; flag harness gap |
| R-IC8 | Sacred time 30s timer: tests must advance fake clock by ≥30s or override provider | E2E-1103 | Override `currentSacredWindowProvider` directly to dismiss |
| R-IC9 | City picker missing RTL chevron for long admin1 city names | E2E-1511 | Overflow guard sweep |
| R-IC10 | Device restore phase strings hardcoded English in service | E2E-1109 he | Assert phase strings in he locale; known gap |
| R-IC11 | `SyncStatusDegraded` reason leaks raw engineering string | E2E-1113 | Assert localised reason; flag non-stuck-outbox path |
| R-IC12 | City search minimum 2 chars — single char shows idle hint | E2E-1101 | Assert 1-char query shows hint, not results |
| R-IC13 | `inIsrael` auto-set race between detect() and setInIsrael() | E2E-1104 | Sequential order in test; assert final state |
| R-IC14 | Parent-mode exit keeps child profile active — only switcher can switch back | E2E-707, E2E-1119 | Assert child profile still active after Exit; document UX |

---

## 8. Metrics Targets

| Wave | Journeys | Focus | Target |
|---|---|---|---|
| Wave 1 (P0) | ~40 | All 48 screens reachable, primary happy paths | 82% line coverage from 58.5% baseline |
| Wave 2 (P1) | ~140 | All dialogs/sheets, offline variants, he-RTL per-area | 87% |
| Wave 3 (P2 + goldens) | ~42 | Edge cases, overflow guard sweep all 48 screens, golden baselines | 90%+ |

**Definition of "E2E done" for a screen:** at least one journey (a) navigates to the screen through the router, (b) asserts at least one primary button or state, (c) asserts the screen renders offline or documents why offline does not apply, (d) has a `he-RTL` variant or documents why it is content-equivalent to the `en` variant.
