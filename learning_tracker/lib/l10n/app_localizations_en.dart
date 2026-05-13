// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Torah Learning Tracker';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get learn => 'Learn';

  @override
  String get progress => 'Progress';

  @override
  String get settings => 'Settings';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get streak => 'STREAK';

  @override
  String get done => 'DONE';

  @override
  String get points => 'POINTS';

  @override
  String get pages => 'PAGES';

  @override
  String get todaysLearning => 'Today\'s Learning';

  @override
  String remaining(int count) {
    return '$count remaining';
  }

  @override
  String get allCaughtUp => 'All caught up!';

  @override
  String get noTasksRemaining => 'No tasks remaining for today.';

  @override
  String get activeCurricula => 'Active Curricula';

  @override
  String get activeTracks => 'Active tracks';

  @override
  String get activeTracksSubtitle =>
      'Keep up the great work on your learning goals';

  @override
  String get activeTrackNextTask => 'NEXT TASK';

  @override
  String get activeTrackCurrentFocus => 'CURRENT FOCUS';

  @override
  String activeTrackPaceAhead(int days) {
    return 'Ahead ${days}d';
  }

  @override
  String activeTrackPaceBehind(int days) {
    return 'Behind ${days}d';
  }

  @override
  String get activeTrackPaceOk => 'OK';

  @override
  String get activeTrackMetricChazara => 'CHAZARA';

  @override
  String get activeTrackMetricDueToday => 'DUE TODAY';

  @override
  String get activeTrackMetricOverdue => 'OVERDUE';

  @override
  String get trackLifetimeLearning => 'Lifetime learning';

  @override
  String get continueLearning => 'Continue Learning';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get myLearningJourney => 'My Learning Journey';

  @override
  String get seeLifetimeAchievements => 'See your lifetime achievements';

  @override
  String get dailyProgress => 'DAILY PROGRESS';

  @override
  String get studyDay => 'Study Day';

  @override
  String get reviewDay => 'Review Day';

  @override
  String get mixedDay => 'Mixed';

  @override
  String get restDay => 'Rest Day';

  @override
  String get overdue => 'Overdue';

  @override
  String moreTasks(int count) {
    return '$count more tasks...';
  }

  @override
  String streakRecovery(int count) {
    return 'You missed 1 day but your $count-day streak is safe!';
  }

  @override
  String get achievements => 'Achievements';

  @override
  String get activityCalendar => 'Activity Calendar';

  @override
  String get nextReward => 'Next Reward';

  @override
  String get earnedRewards => 'Earned Rewards';

  @override
  String get noRewardsYet => 'No rewards earned yet. Keep learning!';

  @override
  String get mysteryReward => 'Mystery Reward!';

  @override
  String get totalPoints => 'Total Points';

  @override
  String get dashboardRewardsGallery => 'Rewards Gallery';

  @override
  String get dashboardChildPointsTab => 'Points';

  @override
  String get dashboardSeeAllRewards => 'SEE ALL';

  @override
  String get dashboardMysteryChest => 'Mystery Chest';

  @override
  String get dashboardCurrentBalance => 'CURRENT BALANCE';

  @override
  String dashboardNextRewardWithName(String name) {
    return 'Next Reward: $name';
  }

  @override
  String dashboardPtsToGo(String count) {
    return '$count pts to go!';
  }

  @override
  String get dashboardRedeemPrizes => 'Redeem Prizes';

  @override
  String dashboardTapToUnlockAtPts(String points) {
    return 'TAP TO UNLOCK AT $points PTS';
  }

  @override
  String dashboardPointsValue(String count) {
    return '$count Points';
  }

  @override
  String get dashboardBubbleDone => 'DONE';

  @override
  String get complete => 'complete';

  @override
  String get gamification => 'Gamification';

  @override
  String get myAchievementsTitle => 'My Achievements';

  @override
  String get achievementsYourProgress => 'YOUR PROGRESS';

  @override
  String achievementsRewardsCount(int unlocked, int total) {
    return '$unlocked / $total Rewards';
  }

  @override
  String get achievementsAcrossAllTracks => 'Across all your tracks.';

  @override
  String get achievementsEncouragement => 'Keep it up, you\'re doing great!';

  @override
  String achievementsRewardsFraction(int unlocked, int total) {
    return '$unlocked / $total';
  }

  @override
  String get achievementsRewardsLabelWord => 'Rewards';

  @override
  String achievementsMilestonePoints(String points) {
    return '$points PTS';
  }

  @override
  String achievementsProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get achievementsTrackSection => 'TRACK SELECTION';

  @override
  String get achievementsAllTracks => 'All Tracks';

  @override
  String get achievementsGlobalRewardsLabel => 'Total points';

  @override
  String get achievementsStatusUnlocked => 'Unlocked!';

  @override
  String get achievementsStatusComingSoon => 'Coming soon!';

  @override
  String get achievementsStatusLocked => 'Locked';

  @override
  String achievementsLockedBlurHint(String points) {
    return 'Reach $points points to unlock';
  }

  @override
  String achievementsUnlockedAtPoints(String points) {
    return 'Unlocked at $points points';
  }

  @override
  String get achievementsUltimateGoal => 'The Ultimate Goal.';

  @override
  String get achievementsProTipTitle => 'Pro Tip!';

  @override
  String get achievementsProTipBody =>
      'Keep learning on your tracks to climb the reward ladder.';

  @override
  String get achievementsActivityAndPoints => 'Activity & points';

  @override
  String get achievementsUnlockPartyTitle => 'Wow! Amazing!';

  @override
  String achievementsUnlockPartyMessage(
    String name,
    String milestone,
    String track,
  ) {
    return 'Congratulations, $name! You unlocked $milestone on your $track track — keep going!';
  }

  @override
  String get achievementsUnlockPartyButton => 'Yay! Let\'s go!';

  @override
  String get achievementsUnlockPartyNameFallback => 'friend';

  @override
  String get rewardCatalog => 'Reward Catalog';

  @override
  String get noRewardsConfigured => 'No rewards configured yet';

  @override
  String get addReward => 'Add Reward';

  @override
  String get editReward => 'Edit Reward';

  @override
  String get deleteReward => 'Delete Reward';

  @override
  String deleteRewardConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get reveal => 'Reveal';

  @override
  String get revealed => 'Revealed';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get pointThreshold => 'Point Threshold';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get thresholdRequired => 'Threshold is required';

  @override
  String get mustBePositive => 'Must be a positive number';

  @override
  String get milestoneType => 'Milestone Type';

  @override
  String get pointsThreshold => 'Points threshold';

  @override
  String get finishMasechta => 'Finish masechta';

  @override
  String get finishSeder => 'Finish seder';

  @override
  String get everyNItems => 'Every N items';

  @override
  String get visibleToChild => 'Visible to child';

  @override
  String get childCanSee => 'Child can see this reward';

  @override
  String get hiddenUntilEarned => 'Hidden until earned (surprise)';

  @override
  String get onboarding => 'Onboarding';

  @override
  String get getStarted => 'Get Started';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get whatsYourName => 'What\'s your name?';

  @override
  String get adult => 'Adult';

  @override
  String get child => 'Child';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectCurricula => 'Select Curricula';

  @override
  String get continueButton => 'Continue';

  @override
  String get skip => 'Skip';

  @override
  String get joinCalendarProgram => 'Join a Calendar Program';

  @override
  String get customTrack => 'Custom Track';

  @override
  String get joinCalendarDesc =>
      'Follow a daily learning schedule like Daf Yomi';

  @override
  String get customTrackDesc =>
      'Create your own learning plan at your own pace';

  @override
  String get availablePrograms => 'Available Programs';

  @override
  String get todaysAssignment => 'Today\'s Assignment';

  @override
  String get startTrackingFrom => 'Start Tracking From';

  @override
  String get fromToday => 'From today';

  @override
  String get beginningOfPerek => 'Beginning of current perek';

  @override
  String get beginningOfMasechta => 'Beginning of current masechta';

  @override
  String get specificDaf => 'From a specific daf';

  @override
  String get setupComplete => 'Setup Complete!';

  @override
  String get addAnotherLearner => 'Add Another Learner';

  @override
  String get startLearning => 'Start Learning';

  @override
  String get language => 'Language';

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get switchProfileSubtitle =>
      'Change to a different profile or your account';

  @override
  String get manageProfiles => 'Manage Profiles';

  @override
  String get manageProfilesSubtitle => 'Add, edit, or remove learner profiles';

  @override
  String get notifications => 'Notifications';

  @override
  String get retry => 'Retry';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading...';

  @override
  String get manageTracks => 'Manage Tracks';

  @override
  String get manageTracksDetail => 'Create and edit your learning tracks';

  @override
  String get addTrackGoalTapToUseDeadline =>
      'Target pace is on — tap here to use a deadline instead';

  @override
  String get addTrackGoalTapToUsePace =>
      'Deadline is on — tap here to use target pace instead';

  @override
  String addTrackGoalDeadlinePaceLine(
    int items,
    String unit,
    int studyDays,
    int totalItems,
  ) {
    return 'About $items $unit per study day, across $studyDays study days to finish the scope by the deadline (≈$totalItems items).';
  }

  @override
  String get addTrackGoalDeadlineNoStudyDaysInWindow =>
      'No study day in your week falls in the range to this deadline. Add study days or move the deadline later.';

  @override
  String get addTrackGoalDeadlinePaceLineLoading =>
      'Loading scope size to estimate per study day…';

  @override
  String get addTrack => 'Add Track';

  @override
  String get addTrackCurriculumReplaceWarning =>
      'You already have a track here. Choosing this curriculum again will replace your current setup and may reset your progress for it.';

  @override
  String get noActiveCurricula => 'No active curricula';

  @override
  String errorLoadingCurricula(String error) {
    return 'Error loading curricula: $error';
  }

  @override
  String trackCreated(String label) {
    return 'Track \"$label\" created';
  }

  @override
  String get learner => 'Learner';

  @override
  String get learningTracker => 'Learning Tracker';

  @override
  String get searchContent => 'Search content';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String errorLoadingTasks(String error) {
    return 'Error loading tasks: $error';
  }

  @override
  String get noActiveTracks => 'No active tracks';

  @override
  String get askGrownUpToAddTrack => 'Ask a grown-up to add a learning track.';

  @override
  String get addTrackToStart => 'Add a track to start learning.';

  @override
  String get todaysTasks => 'Today\'s Tasks';

  @override
  String get viewAll => 'View All';

  @override
  String get myCurricula => 'My Curricula';

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get viewProgress => 'View progress';

  @override
  String get markComplete => 'Mark complete';

  @override
  String get textReaderNextDailyTask => 'Next daily task';

  @override
  String get noProjection => 'No projection';

  @override
  String get today => 'TODAY';

  @override
  String plusNMore(int count) {
    return '+$count more';
  }

  @override
  String get noTracksYet => 'No tracks yet';

  @override
  String get firstTrackPrompt =>
      'Add your first learning track to get started.';

  @override
  String paceAhead(int days) {
    return '${days}d ahead';
  }

  @override
  String paceBehind(int days) {
    return '${days}d behind';
  }

  @override
  String get paceOnPace => 'OK';

  @override
  String get progressNoDataTitle => 'No progress yet';

  @override
  String get progressNoDataSubtitle =>
      'Start learning to see your progress here.';

  @override
  String get statCompletions => 'COMPLETIONS';

  @override
  String get statUnitsDone => 'UNITS DONE';

  @override
  String get statDayStreak => 'DAY STREAK';

  @override
  String get statActiveTracks => 'ACTIVE TRACKS';

  @override
  String get progressChartsTile => 'Progress Charts';

  @override
  String get progressChartsTileSubtitle => 'Completions, trends, and more';

  @override
  String get learningLifetime => 'Learning Lifetime';

  @override
  String get learningLifetimeExpandHint =>
      'Per curriculum: expand to browse what you have learned';

  @override
  String get addWhatYouLearned => 'Add what you\'ve learned';

  @override
  String get addWhatYouLearnedSettingsSubtitle =>
      'Log custom Mitzvot or Torah studies';

  @override
  String get lifetimeLearning => 'Lifetime Learning';

  @override
  String get lifetimeLearningHubSection => 'LEARNING HUB';

  @override
  String lifetimeXpTotal(String points) {
    return '$points XP Total';
  }

  @override
  String get lifetimeStartAdding => 'Start Adding';

  @override
  String get lifetimeBrowseFullLibrary => 'Browse Full Library';

  @override
  String get lifetimeHowItWorksStep1 =>
      'Select a category from the library grid to see all available tracks.';

  @override
  String get lifetimeHowItWorksStep2 =>
      'Toggle units you\'ve finished to update your lifetime progress map.';

  @override
  String get lifetimeHowItWorksStep3 =>
      'Earn special milestone badges for completing whole volumes or tractates.';

  @override
  String get lifetimeNotStarted => 'Not started';

  @override
  String get lifetimeAddHeaderTitle => 'Add what you\'ve learned';

  @override
  String get lifetimeAddHeaderSubtitle =>
      'Mark what you\'ve already studied — in print or anywhere — as lifetime learning.';

  @override
  String get lifetimeHowItWorksTitle => 'How it works';

  @override
  String get lifetimeHowItWorksBody =>
      'Open a curriculum, then use the folder list to select sections. Green = selected for saving; open a subfolder with the arrow when there is more inside.';

  @override
  String get lifetimeSelectScreenTitle => 'Select what you\'ve learned';

  @override
  String get lifetimeSelectScreenSubtitle =>
      'Check sections to include; open folders to go deeper.';

  @override
  String get lifetimeMarkAsLearnedTitle => 'Mark as lifetime learned';

  @override
  String lifetimeMarkAsLearnedLine(int count, int level) {
    return 'Selected: $count • level $level';
  }

  @override
  String get selectAllInThisList => 'Select all in this list';

  @override
  String get deselectAllInThisList => 'Deselect all in this list';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String contentLoadError(String error) {
    return 'Unable to load curriculum content: $error';
  }

  @override
  String get noItemsAtThisLevel => 'No items at this level';

  @override
  String get breadcrumbsRoot => 'Root';

  @override
  String lifetimeMarkSavedCount(int count) {
    return 'Marked $count lifetime selection(s).';
  }

  @override
  String lifetimeMarkSaveError(String error) {
    return 'Could not save lifetime marks: $error';
  }

  @override
  String get dashboardStats => 'STATS';

  @override
  String get learningLifetimeAllCurricula =>
      'Learning lifetime (all curricula)';

  @override
  String get dashboardAllCaughtUpTitle => 'All caught up! Great work!';

  @override
  String get dashboardAllCaughtUpSubtitle =>
      'You have no more tasks for today.';

  @override
  String get dashboardLifetimeProgress => 'Lifetime Progress';

  @override
  String lifetimeSectionsSummary(String learned, String total, int n) {
    return '$learned / $total sections — $n curricula';
  }

  @override
  String greetingHelloName(String name) {
    return 'Shalom, $name!';
  }

  @override
  String get noFocusTag => 'NO FOCUS TAG';

  @override
  String get todaysMissions => 'Today’s Missions';

  @override
  String get noTasksInLane => 'No tasks in this lane';

  @override
  String get reviewSection => 'REVIEW SECTION';

  @override
  String get chazaraReview => 'Chazara/Review';

  @override
  String get activeTrackChazaraLabel => 'Chazara';

  @override
  String get urgent => 'URGENT';

  @override
  String get missedOverdue => 'Missed/Overdue';

  @override
  String get bubbleOverdue => 'OVERDUE';

  @override
  String get bubbleTodayDue => 'TODAY\nDUE';

  @override
  String get bubbleChazara => 'CHAZARA';

  @override
  String get mainFocus => 'MAIN FOCUS';

  @override
  String get carouselCompletion => 'Completion';

  @override
  String get continueCta => 'CONTINUE';

  @override
  String get tabSchedule => 'Schedule';

  @override
  String get dueToday => 'Due today';

  @override
  String get nothingDueInQueue => 'Nothing due in this queue right now.';

  @override
  String get selfPacedScopeTitle => 'All of it, or just a section?';

  @override
  String get learnEntireCurriculumCta => 'I want to learn everything!';

  @override
  String learnEntireCurriculumSubtitle(String name) {
    return 'Select the entire $name';
  }

  @override
  String level1Selection(String name, String levelLabel) {
    return '$name → $levelLabel selection';
  }

  @override
  String get scopeSelectedBadge => 'SELECTED';

  @override
  String get selectAtLeastOne => 'Select at least one';

  @override
  String continueWithSelectionCount(int count) {
    return 'Continue with $count selected';
  }

  @override
  String get sectionLearning => 'LEARNING';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notificationSettingsSubtitle =>
      'Push, email, and study sound alerts';

  @override
  String pointsAbbrev(int count) {
    return '$count pts';
  }

  @override
  String get sectionTracks => 'TRACKS';

  @override
  String get sectionAccount => 'ACCOUNT';

  @override
  String get sectionParentalControls => 'PARENTAL CONTROLS';

  @override
  String get changePassword => 'Change Password';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountSubtitle =>
      'Permanently remove this account and cloud data';

  @override
  String get deleteLocalAccountSubtitle =>
      'Permanently deletes this device account and all learning data';

  @override
  String get settingsHandcraftedTagline => 'Handcrafted for your Torah journey';

  @override
  String get calendarPreference => 'Calendar Preference';

  @override
  String get calendarPreferenceSubtitle => 'Goals, deadlines, and date pickers';

  @override
  String get calendarGregorian => 'English';

  @override
  String get calendarHebrew => 'Hebrew';

  @override
  String get hebrewTermsPreference => 'Hebrew Terms';

  @override
  String get hebrewTermsPreferenceSubtitle =>
      'Show learning terms (chazara, review) in Hebrew script or transliterated';

  @override
  String get hebrewTermsHebrew => 'Hebrew';

  @override
  String get hebrewTermsEnglish => 'English';

  @override
  String get parentMode => 'Parent Mode';

  @override
  String get parentModeSubtitle => 'Switch to admin (PIN-guarded)';

  @override
  String get parentPin => 'Parent PIN';

  @override
  String get parentPinSubtitle => 'Change your security PIN';

  @override
  String get passwordChangedSuccessfully => 'Password changed successfully.';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get userFallbackDisplayName => 'User';

  @override
  String get proBadge => 'PRO';

  @override
  String get selfLearnerBadge => 'SELF-LEARNER';

  @override
  String get noBackup => 'No Backup';

  @override
  String get chooseLanguageTitle => 'Choose Language';

  @override
  String get preferredLanguageForContent => 'Preferred language for content';

  @override
  String get profilePickerTitle => 'Who is learning?';

  @override
  String get profilePickerSubtitle =>
      'Choose a profile to continue your\njourney';

  @override
  String get addProfile => 'Add Profile';

  @override
  String get createProfile => 'Create Profile';

  @override
  String get enterNameHint => 'Enter name';

  @override
  String get chooseMode => 'Choose Mode';

  @override
  String get childModeCardTitle => 'Child Mode';

  @override
  String get childModeCardSubtitleFunRewards => 'Fun & Rewards';

  @override
  String get adultModeCardTitle => 'Adult Mode';

  @override
  String get adultModeCardSubtitleDeepFocused => 'Deep & Focused';

  @override
  String get profileBadgeChildMode => 'CHILD MODE';

  @override
  String get profileBadgeAdultMode => 'ADULT MODE';

  @override
  String profileNameTaken(String name) {
    return 'A profile named \"$name\" already exists';
  }

  @override
  String get maxProfilesReached => 'Maximum 10 profiles reached';

  @override
  String get renameAction => 'Rename';

  @override
  String get mustKeepOneProfile => 'You must have at least one profile';

  @override
  String get profileNameAlreadyExists =>
      'A profile with this name already exists';

  @override
  String get renameProfileTitle => 'Rename Profile';

  @override
  String get displayName => 'Display Name';

  @override
  String get deleteProfileTitle => 'Delete Profile?';

  @override
  String deleteProfileConfirm(String name) {
    return 'Permanently delete \"$name\" and ALL associated learning data? This cannot be undone.';
  }

  @override
  String get cannotDeleteOnlyProfile => 'Cannot delete your only profile';

  @override
  String get tapToContinue => 'Tap to\ncontinue';

  @override
  String get maxProfilesLabel => 'Max Profiles';

  @override
  String get addProfileCardTitle => 'Add\nProfile';

  @override
  String get maxProfilesSubtitle => 'Maximum reached';

  @override
  String get createNewLearner => 'Create new\nlearner';

  @override
  String get profilesLabel => 'Profiles';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncScreenBody => 'Sync status and settings will appear here.';

  @override
  String get parentSettingsTitle => 'Parent Settings';

  @override
  String get manageTracksForChildSubtitle =>
      'Add, edit, or archive your child\'s tracks';

  @override
  String get pointConfiguration => 'Point Configuration';

  @override
  String get pointConfigurationSubtitle =>
      'Set how many points activities are worth';

  @override
  String get rewardConfigurationTitle => 'Reward configuration';

  @override
  String get rewardConfigurationSubtitle =>
      'Set prizes for one track or for total points across all tracks.';

  @override
  String get rewardConfigPerTrackTab => 'Per track';

  @override
  String get rewardConfigTotalPointsTab => 'Total points';

  @override
  String get rewardConfigPerTrackHelper =>
      'These rewards use points earned on the selected track only.';

  @override
  String get rewardConfigTotalPointsHelper =>
      'These rewards use total points from all learning tracks combined (same as your child’s overall points).';

  @override
  String get rewardConfigSelectTrack => 'Track';

  @override
  String get rewardConfigNoActiveTracks =>
      'No active tracks yet. Add a track to configure per-track rewards.';

  @override
  String get rewardConfigAddReward => 'Add reward';

  @override
  String get rewardConfigEditReward => 'Edit reward';

  @override
  String get rewardConfigRewardNameLabel => 'Reward name';

  @override
  String get rewardConfigPointsThresholdLabel => 'Points needed';

  @override
  String get rewardConfigSaveReward => 'Save';

  @override
  String get rewardConfigDeleteReward => 'Delete';

  @override
  String get rewardConfigDuplicateThreshold =>
      'Another reward already uses this point value.';

  @override
  String get rewardConfigEmptyMilestones =>
      'No rewards yet. Tap below to add one.';

  @override
  String get rewardConfigSaved => 'Rewards saved';

  @override
  String get parentPortalTitle => 'Parent Portal';

  @override
  String get rewardConfigScreenContextLabel => 'Reward Configuration';

  @override
  String get rewardConfigConfigureNewTitle => 'Configure New Reward';

  @override
  String get rewardConfigConfigureNewSubtitle =>
      'Select a magical icon and set the milestone goals for your child.';

  @override
  String get rewardConfigChooseAvatarStep => '1. CHOOSE AN AVATAR';

  @override
  String get rewardConfigRewardTypeLabel => 'Reward type';

  @override
  String get rewardConfigChooseTrackLabel => 'Choose track';

  @override
  String get rewardConfigPreviewLabel => 'PREVIEW';

  @override
  String rewardConfigPointsPreview(int points) {
    return '$points Points';
  }

  @override
  String get rewardConfigCancel => 'Cancel';

  @override
  String get rewardConfigSaveRewardButton => 'Save Reward';

  @override
  String get rewardConfigNamePlaceholder => 'e.g., Bronze Star';

  @override
  String get rewardConfigPointsPlaceholder => 'e.g., 500';

  @override
  String get rewardConfigMenuManageRewards => 'Manage rewards';

  @override
  String get rewardConfigRewardCreatedTitle => 'Reward created';

  @override
  String rewardConfigRewardCreatedBody(String name) {
    return '\"$name\" was added. Your child will see it under Achievements — locked and blurred until they reach the points goal.';
  }

  @override
  String get rewardConfigRewardUpdatedTitle => 'Reward updated';

  @override
  String rewardConfigRewardUpdatedBody(String name) {
    return 'Your changes to \"$name\" were saved. Your child will see the update under Achievements.';
  }

  @override
  String get pointConfigPerTaskTitle => 'Points per completed task';

  @override
  String get pointConfigPerTaskDescription =>
      'For each active learning track, set how many points your child earns when they complete one task from their daily list. The amount depends on the task stage (for example first learn vs review).';

  @override
  String get pointConfigNoActiveTracksBody =>
      'No active learning tracks with stages were found for this child. Turn on curricula and set up tracks in Manage Tracks, then return here to choose points per task.';

  @override
  String get pointSettingsTitle => 'Point Settings';

  @override
  String get pointSettingsConfigurationLabel => 'CONFIGURATION';

  @override
  String get pointSettingsRewardsStrategyTitle => 'Rewards Strategy';

  @override
  String get pointSettingsRewardsStrategySubtitle =>
      'Adjust how many points your child earns for each sacred milestone.';

  @override
  String get pointSettingsActiveCurricula => 'Active Curricula';

  @override
  String get pointSettingsPointsPerTask => 'Points per Task';

  @override
  String get pointSettingsPts => 'PTS';

  @override
  String get pointSettingsActiveBadge => 'ACTIVE';

  @override
  String get pointSettingsSaveAll => 'Save All Changes';

  @override
  String get pointSettingsSaveFooter =>
      'Point changes will sync instantly to the Child\'s dashboard.';

  @override
  String get pointSettingsSavedSnackbar => 'Changes saved and synced.';

  @override
  String get pointSettingsNothingToSaveSnackbar => 'No changes to save.';

  @override
  String get pointSettingsPrimaryStageLabel => 'First completion (daily task)';

  @override
  String get sectionAccountSafety => 'ACCOUNT SAFETY';

  @override
  String get bottomNavTracks => 'Tracks';

  @override
  String get bottomNavRewards => 'Rewards';

  @override
  String get bottomNavParent => 'Parent';

  @override
  String get addProfileDialogSubtitle =>
      'Enter a name and select Child mode or Adult mode.';

  @override
  String get setParentPinDialogTitle => 'Set Parent PIN';

  @override
  String setParentPinDialogSubtitle(String name) {
    return 'Set a 4-digit PIN to access parent controls for $name. The PIN is stored only on this device.';
  }

  @override
  String get enterParentPin => 'Enter Parent PIN';

  @override
  String get enterParentPinSubtitle =>
      'Enter your 4-digit PIN to access parent settings.';

  @override
  String get enterNewPinSubtitle => 'Choose a new 4-digit PIN.';

  @override
  String get confirmNewPinSubtitle => 'Enter the same PIN again to confirm.';

  @override
  String get changeParentPin => 'Change Parent PIN';

  @override
  String get pinChangedSuccessfully => 'PIN changed successfully';

  @override
  String get pinFlowSetupSubtitle =>
      'Set a new 4-digit PIN to enable parent mode.';

  @override
  String get pinFlowSetupDeviceLocalBanner =>
      'Parent PINs live only on this device. Set a new 4-digit PIN to enable parent mode here. Other devices keep their own PIN.';

  @override
  String get deviceRestoreChecking => 'Checking device...';

  @override
  String get deviceRestoreComplete => 'Restore complete!';

  @override
  String get deviceRestoreFailed => 'Restore failed';

  @override
  String deviceRestoreStep(int completed, int total) {
    return 'Step $completed of $total';
  }

  @override
  String get skipAndContinue => 'Skip & continue';

  @override
  String get noActiveProfile => 'No active profile';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get enterCurrentPin => 'Enter Current PIN';

  @override
  String get enterNewPin => 'Enter New PIN';

  @override
  String get confirmNewPin => 'Confirm New PIN';

  @override
  String get pinsDoNotMatch => 'PINs do not match';

  @override
  String get tabBarDashboard => 'DASHBOARD';

  @override
  String get tabBarLearn => 'LEARN';

  @override
  String get tabBarProgress => 'PROGRESS';

  @override
  String get tabBarSettings => 'SETTINGS';

  @override
  String get errorLoadingCalendar => 'Error loading calendar';

  @override
  String get journeyByCurriculum => 'By Curriculum';

  @override
  String get journeyTimeline => 'Timeline';

  @override
  String journeyTitleNamed(String name) {
    return '$name\'s Learning Journey';
  }

  @override
  String get loadingYourJourney => 'Loading your journey...';

  @override
  String failedToLoadJourney(String error) {
    return 'Failed to load journey: $error';
  }

  @override
  String get journeyEmptyTitle => 'Your learning journey starts here!';

  @override
  String get journeyEmptyBody =>
      'Complete your first masechta to see it recorded forever.';

  @override
  String get progressChartsTitle => 'Progress Charts';

  @override
  String get chartCompletionsOverTime => 'Completions Over Time';

  @override
  String get chartDailyActivity => 'DAILY ACTIVITY';

  @override
  String get chartCumulativeProgress => 'Cumulative Progress';

  @override
  String get chartCumulativeProgressSubtitle => '+12% vs last week';

  @override
  String get chartPointsEarned => 'Points Earned';

  @override
  String get chartTotalTorahPoints => 'TOTAL TORAH POINTS';

  @override
  String get chartLearningJourney => 'Learning Journey';

  @override
  String get chartJourneyMotivation => 'Keep the flame alive every day!';

  @override
  String get chartSevenDayStreak => '7 DAY STREAK!';

  @override
  String get chartLast7Days => 'Last 7 Days';

  @override
  String get chartLast30Days => 'Last 30\nDays';

  @override
  String get chartAllTime => 'All Time';

  @override
  String get chartFilterAll => 'All';

  @override
  String get notifAppBarNotifications => 'Notifications';

  @override
  String get notifDailyReminder => 'Daily Reminder';

  @override
  String get notifDailyReminderSubtitle => 'Don\'t forget to learn today!';

  @override
  String get notifReminderTime => 'Reminder Time';

  @override
  String get notifStreakAlert => 'Streak Alert';

  @override
  String get notifStreakAlertSubtitle => 'Keep your fire burning!';

  @override
  String get notifHotStreakBadge => 'HOT STREAK';

  @override
  String get notifStreakAlertTime => 'Streak Alert Time';

  @override
  String get notifRewardNotifications => 'Reward Notifications';

  @override
  String get notifRewardNotificationsSubtitle =>
      'When you earn Learning Points!';

  @override
  String get notifSacredTime => 'SHABBOS MODE';

  @override
  String get notifShabbosYomTovMode => 'Shabbos / Yom Tov\nMode';

  @override
  String get notifShabbosModeSubtitle => 'Quiet learning during holy days';

  @override
  String get notifUseLocationForTimes => 'Use Location for Times';

  @override
  String get notifQuietStart => 'QUIET START';

  @override
  String get notifQuietEnd => 'QUIET END';

  @override
  String get notifCandleLighting => 'Candle lighting';

  @override
  String get notifHavdalah => 'Havdalah';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authLocalDataMissing =>
      'This account\'s local data is missing. Connect to the internet to restore it.';

  @override
  String get authEmailOfflineUnreachable =>
      'This email isn\'t on this device and we can\'t reach the cloud. Try again when online.';

  @override
  String get authIncorrectPassword => 'Incorrect password.';

  @override
  String authSignInFailedError(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get authVerifyEmailBody =>
      'We sent a verification link to your inbox. Please check your email to continue.';

  @override
  String get authIveVerified => 'I\'ve verified';

  @override
  String get authVerificationEmailSentAgain => 'Verification email sent again.';

  @override
  String get authEmailStillUnverified =>
      'Email is still unverified. Check your inbox first.';

  @override
  String authMaxDeviceAccounts(int count) {
    return 'Maximum $count device accounts reached. Remove one to add another.';
  }

  @override
  String get authOfflineUseUpgrade =>
      'An offline account with this email exists on this device. Use the Upgrade to Cloud option in Settings instead.';

  @override
  String get authGoogleSignInFailed =>
      'Google Sign-In failed. Please try again.';

  @override
  String get authErrUserNotFound => 'No account found with this email.';

  @override
  String get authErrWrongPassword => 'Incorrect password. Please try again.';

  @override
  String get authErrInvalidCredential =>
      'Invalid email or password. Please try again.';

  @override
  String get authErrUserDisabled => 'This account has been disabled.';

  @override
  String get authErrTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get authErrInvalidEmail => 'Please enter a valid email address.';

  @override
  String get authErrNetwork => 'Network error. Please check your connection.';

  @override
  String get authErrSignInGeneric => 'Sign-in failed. Please try again.';

  @override
  String get authTierCloud => 'Cloud';

  @override
  String get authTierLocal => 'Local';

  @override
  String authFoundOnDevice(String tier) {
    return 'Found on this device ($tier)';
  }

  @override
  String get authNotOnDeviceCheckCloud =>
      'Not on this device — we\'ll check the cloud';

  @override
  String get authNotOnDeviceOffline =>
      'Not on this device (offline — only device accounts available)';

  @override
  String get authModeCloud =>
      'Cloud account: your data is backed up and syncs across devices.';

  @override
  String get authModeCloudOffline =>
      'Cloud account is offline right now. We will try local cached data until internet returns.';

  @override
  String get authModeLocalTitle =>
      'Local account only: no cloud backup and no device sync.';

  @override
  String get authModeLocalBody =>
      'No cloud backup or device sync. Your data stays only on this device.';

  @override
  String get signInWelcomeBack => 'Welcome Back!';

  @override
  String get signInReady => 'Ready for your next learning adventure?';

  @override
  String get signInYourEmail => 'Your Email';

  @override
  String get signInEmailHint => 'yourname@quest.com';

  @override
  String get signInPasswordLabel => 'Secret Key';

  @override
  String get signInPasswordHint => '••••••••';

  @override
  String get signInKeepMeSignedIn => 'Keep me signed in';

  @override
  String get signInCta => 'Sign In';

  @override
  String get signInWithGoogleCta => 'Sign in with Google';

  @override
  String get signInNewToQuest => 'New to the Quest? ';

  @override
  String get signInRegisterHere => 'Register Here';

  @override
  String get chartFailedToLoad => 'Failed to load data';

  @override
  String get accountPickerTitle => 'Choose an Account';

  @override
  String get accountPickerSubtitle =>
      'Select a learner to continue your journey';

  @override
  String accountPickerMaxAccountsShort(int count) {
    return 'Maximum $count device accounts reached';
  }

  @override
  String get accountPickerPrivacyFooter =>
      'Manage your privacy and security in Settings';

  @override
  String get accountRemoveFromDevice => 'Remove from device';

  @override
  String get accountDeleteAccountAction => 'Delete account';

  @override
  String get badgeLocalAccount => 'LOCAL ACCOUNT';

  @override
  String get badgeSignInAgain => 'SIGN IN AGAIN';

  @override
  String get badgeCloudAccount => 'CLOUD ACCOUNT';

  @override
  String get accountRemoveFromDeviceTitle => 'Remove from device?';

  @override
  String get accountDeleteAccountTitle => 'Delete account?';

  @override
  String get accountRemoveFromDeviceBody =>
      'Your cloud data is safe — you can sign back in anytime.';

  @override
  String get accountDeleteAccountBody =>
      'All learning data will be permanently lost. This cannot be undone.';

  @override
  String get accountRemove => 'Remove';

  @override
  String get accountDeleteForever => 'Delete Forever';

  @override
  String accountPickerAddAnother(int remaining) {
    return '+1   Add another account ($remaining slots remaining)';
  }

  @override
  String get cannotDeactivateLastCurriculum =>
      'At least one curriculum must remain active';

  @override
  String get cannotDeactivateLastCurriculumDetail =>
      'You cannot remove your last active curriculum. Add another curriculum before removing this one.';
}
