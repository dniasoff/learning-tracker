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
  String todaysLearning(int count) {
    return 'Today\'s learning ($count)';
  }

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
  String get activeTracksPreviousTrack => 'Previous track';

  @override
  String get activeTracksNextTrack => 'Next track';

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
  String get trackCurrentCycle => 'Since reactivation';

  @override
  String get continueLearning => 'Continue Learning';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get myLearningJourney => 'My Learning Journey';

  @override
  String get myLearningJourneySubtitle =>
      'Everything you\'ve learned, in order';

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
  String get ctaGetStartedTitle => 'Get started';

  @override
  String get ctaGetStartedBody =>
      'Add a learning track to begin tracking your progress.';

  @override
  String get ctaAddLearningTrack => 'Add a learning track';

  @override
  String get ctaCreateProfileFirst =>
      'Create a learner profile first, then add a track.';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String commonLabelWithValue(String label, String value) {
    return '$label: $value';
  }

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
  String get introContinueJourney => 'Continue Journey';

  @override
  String get introSetupProgress => 'SETUP PROGRESS';

  @override
  String get introDailyPlanTitleLine1 => 'Your Daily';

  @override
  String get introDailyPlanTitleHighlight => 'Torah Plan';

  @override
  String introDailyPlanSubtitle(String highlight) {
    return 'Learning Tracker turns massive goals into $highlight, so you always know what to study next.';
  }

  @override
  String get introDailyPlanSubtitleHighlight => 'clear daily tasks';

  @override
  String get introMishnaTitlePrefix => 'Never Forget\na ';

  @override
  String introMishnaSubtitle(String highlight) {
    return 'Master your learning with intelligent review cycles. Our $highlight helps you retain everything you learn.';
  }

  @override
  String get introMishnaSubtitleHighlight => 'spaced-repetition engine';

  @override
  String get introRewardsTitle => 'Earn While You Learn';

  @override
  String introRewardsSubtitle(String scholarTier) {
    return 'Collect points, build streaks, and unlock mystery rewards as you climb from a Novice to a ⁦$scholarTier⁩!';
  }

  @override
  String get introMishnaReviewChip => 'Review…';

  @override
  String get introMishnaWordFragmentChip => '…yos';

  @override
  String get introChildModeTagTitle => 'For Child profiles only';

  @override
  String get introChildModeTagBody =>
      'Points, streaks, and rewards show up when you create a Child profile. Adult profiles focus on plain learning progress.';

  @override
  String get introBadgeCollection => 'Badge\nCollection';

  @override
  String get introMysteryPrizes => 'Mystery\nPrizes';

  @override
  String get introScholarProgress => 'Scholar Progress';

  @override
  String get introScholarExample => 'EXAMPLE';

  @override
  String get introScholarNovice => 'NOVICE';

  @override
  String get joinCalendarProgram => 'Join a Calendar Program';

  @override
  String get joinCalendarDesc =>
      'Follow a daily learning schedule like Daf Yomi';

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
  String get addAnotherTrack => 'Add Another Track';

  @override
  String get startLearning => 'Start Learning';

  @override
  String get allSet => 'All set!';

  @override
  String get addYourFirstTrack => 'Add Your First Track';

  @override
  String get addTrackButton => 'ADD TRACK';

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
  String get manageTracksAndGoalsTitle => 'Tracks & Goals';

  @override
  String get manageTracksDetail => 'Create and edit your learning tracks';

  @override
  String get parentManageTracksDetail =>
      'Create and edit your child\'s learning tracks';

  @override
  String get addTrackGoalTapToUseDeadline =>
      'Target pace is on — tap here to use a deadline instead';

  @override
  String get addTrackGoalTapToUsePace =>
      'Deadline is on — tap here to use target pace instead';

  @override
  String addTrackChazaraStepTitle(String term) {
    return 'Add $term?';
  }

  @override
  String addTrackChazaraStepQuestion(String term) {
    return 'How do you want to schedule $term?';
  }

  @override
  String addTrackGoalDeadlinePaceLine(
    int items,
    String unit,
    int studyDays,
    int totalItems,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      studyDays,
      locale: localeName,
      other: '$studyDays study days',
      one: '1 study day',
    );
    return 'About $items $unit per study day, across $_temp0 to finish the scope by the deadline (≈$totalItems items).';
  }

  @override
  String get addTrackGoalDeadlineNoStudyDaysInWindow =>
      'No study day in your week falls in the range to this deadline. Add study days or move the deadline later.';

  @override
  String get addTrackGoalDeadlinePaceLineLoading =>
      'Loading scope size to estimate per study day…';

  @override
  String addTrackGoalDeadlinePaceLineNoTotal(
    int items,
    String unit,
    int studyDays,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      studyDays,
      locale: localeName,
      other: '$studyDays study days',
      one: '1 study day',
    );
    return 'About $items $unit per study day, across $_temp0 to finish the scope by the deadline.';
  }

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
  String get markCompleteTutorUnavailable => 'Not available (tutor mode)';

  @override
  String markCompleteCompletedStage(String stageName) {
    return 'Completed ($stageName)';
  }

  @override
  String unableToLoadCompletionContext(String error) {
    return 'Unable to load completion context: $error';
  }

  @override
  String get accountOfflineSignInToSync =>
      'Working offline for this account. Sign in to resume cloud sync.';

  @override
  String get textReaderNextDailyTask => 'Next daily task';

  @override
  String get noProjection => 'No projection';

  @override
  String get today => 'Today';

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
  String get statCompletions => 'ITEMS LEARNED';

  @override
  String get statUnitsDone => 'TASKS DONE';

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
  String get addWhatYouLearned => 'Add Lifetime Learning';

  @override
  String get addWhatYouLearnedSettingsSubtitle =>
      'Entries appear in your Lifetime Learning reports';

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
  String get learnBrowseSectionTitle => 'Browse';

  @override
  String get lifetimeBrowseFullLibrary => 'Browse Full Library';

  @override
  String get lifetimeHowItWorksStep1 =>
      'Select a category from the library grid to see all available tracks.';

  @override
  String get lifetimeHowItWorksStep2 =>
      'Toggle tasks you\'ve finished to update your lifetime progress map.';

  @override
  String get lifetimeHowItWorksStep3 =>
      'Earn special milestone badges for completing whole volumes or tractates.';

  @override
  String get lifetimeNotStarted => 'Not started';

  @override
  String get lifetimeAddHeaderTitle => 'Add Lifetime Learning';

  @override
  String get lifetimeAddHeaderSubtitle =>
      'Mark what you\'ve already studied as lifetime learning.';

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
  String lifetimeMarkAsLearnedCount(int count) {
    return 'Selected: $count';
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
  String get contentHierarchyBrowseTitle => 'Browse Content';

  @override
  String get contentHierarchyUnknownTitle => 'Unknown Curriculum';

  @override
  String get contentHierarchyNoContent => 'No content available';

  @override
  String get contentHierarchySearchTooltip => 'Search';

  @override
  String get curriculumListTitle => 'Browse Content';

  @override
  String get curriculumListSearchTooltip => 'Search curricula';

  @override
  String get curriculumListSearchHint => 'Search curricula...';

  @override
  String get curriculumListSectionCurricula => 'CURRICULA';

  @override
  String get curriculumListSectionRecentActivity => 'RECENT ACTIVITY';

  @override
  String curriculumListPercentDone(String pctDisplay) {
    return '$pctDisplay Done';
  }

  @override
  String get curriculumListNewBadge => 'New';

  @override
  String get curriculumListActivityEmptyTitle =>
      'Start learning to see activity here';

  @override
  String get curriculumListActivityEmptySubtitle =>
      'Your recent completions will appear below';

  @override
  String get contentSearchClearTooltip => 'Clear';

  @override
  String get stageBreakdownReviewHistoryTitle => 'Review History';

  @override
  String itemReviewBreakdownStageFallback(int stageId) {
    return 'Stage $stageId';
  }

  @override
  String get noItemsAtThisLevel => 'No items at this level';

  @override
  String get breadcrumbsRoot => 'Root';

  @override
  String lifetimeMarkSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marked $count lifetime selections.',
      one: 'Marked 1 lifetime selection.',
    );
    return '$_temp0';
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
  String get chazaraReview => 'Chazara';

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
  String get talmidChochom => 'Talmid Chochom';

  @override
  String get talmidChochomCaps => 'TALMID CHOCHOM';

  @override
  String get mainFocus => 'MAIN FOCUS';

  @override
  String carouselCompletion(String chazara) {
    return 'Completion (with $chazara)';
  }

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
  String addTrackStepCounter(int current, int total) {
    return 'STEP $current OF $total';
  }

  @override
  String get curriculumPickerTitle => 'Select a Curriculum';

  @override
  String get curriculumPickerTitleOnboarding => 'What would you like to learn?';

  @override
  String get curriculumPickerSubtitle =>
      'Choose one curriculum for this track.';

  @override
  String get programStepTitle => 'Join a Program?';

  @override
  String get programStepSubtitle =>
      'Follow a global study calendar, or learn at your own pace.';

  @override
  String get programStepOrChooseFreedom => 'OR CHOOSE FREEDOM';

  @override
  String get programStepSelfPaced => 'Self-paced (no program)';

  @override
  String get programStepSelfPacedCaption =>
      'Recommended for personal projects, catch-up goals, or unstructured learning.';

  @override
  String get programDailyCalendarBadge => 'DAILY CALENDAR';

  @override
  String get programDefaultDescriptionFeatured =>
      'Master the curriculum with a steady daily plan.';

  @override
  String get programDefaultDescriptionCompact => 'Daily guided learning.';

  @override
  String get exitTrackSetupTitle => 'Exit Track Setup?';

  @override
  String get exitTrackSetupMessage =>
      'Are you sure you want to exit?\nYour setup progress will be lost.';

  @override
  String chazaraProgramNoReviewSubtitle(String program) {
    return '$program doesn\'t include a review schedule. Set one up now or skip.';
  }

  @override
  String chazaraSelfPacedSubtitle(String chazara) {
    return 'Pick a preset or build your own $chazara schedule.';
  }

  @override
  String get scopeGlossSeedsAgriculture => 'Seeds & Agriculture';

  @override
  String get scopeGlossFestivalsSabbaths => 'Festivals & Sabbaths';

  @override
  String get scopeGlossWomenMarriage => 'Women & Marriage';

  @override
  String get scopeGlossDamagesCivil => 'Damages & Civil Law';

  @override
  String get scopeGlossTempleSacrifices => 'Temple Service & Sacrifices';

  @override
  String get scopeGlossPurityRitual => 'Purity & Ritual Law';

  @override
  String get scopeGlossCoreFocus => 'Core section focus';

  @override
  String get scopeShowContentsTooltip => 'Show contents';

  @override
  String scopeLevelFallbackLabel(int level) {
    return 'Level $level';
  }

  @override
  String get startingPositionSectionLabel => 'Section';

  @override
  String get trackNameRequired => 'Please enter a name';

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
  String get notificationSettingsSubtitle => 'Push notification alerts';

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
  String get sectionDevice => 'DEVICE';

  @override
  String get sectionProfile => 'PROFILE';

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
  String get parentModeActiveSubtitle => 'Manage tracks, rewards & tutors';

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
  String get parentContextBadge => 'PARENT';

  @override
  String get tutorContextBadge => 'TUTOR';

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
  String get profilePickerMyChildren => 'MY CHILDREN';

  @override
  String get profilePickerYourProfiles => 'YOUR PROFILES';

  @override
  String get profilePickerTalmidProfiles => 'TALMID PROFILES';

  @override
  String settingsTutoringViewAll(int count) {
    return 'View all ($count more)';
  }

  @override
  String get profilePickerSkipToSettings => 'Skip to Settings';

  @override
  String get profilePickerTutoredChildren => 'TUTORED CHILDREN';

  @override
  String get tutoredChildrenViewInvitations => 'View invitations';

  @override
  String get tutoredChildrenManageGrants => 'Manage tutoring grants';

  @override
  String get tutoredChildrenManageGrantsSubtitle =>
      'Resign or review your tutoring access';

  @override
  String tutoredChildrenPendingInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending tutor invitations',
      one: '$count pending tutor invitation',
    );
    return '$_temp0';
  }

  @override
  String get tutoredChildrenStatusTutoring => 'Tutoring';

  @override
  String get tutoredChildrenRoleBadge => 'Tutor';

  @override
  String get tutorModeIndicator => 'Tutor mode';

  @override
  String tutorModeIndicatorNamed(String name) {
    return 'Tutor mode · $name';
  }

  @override
  String get tutorModeExit => 'Exit';

  @override
  String get tutoredEntryPermissionDenied =>
      'Access denied — the grant may have been revoked.';

  @override
  String get tutoredEntryError =>
      'Could not load talmid data. Please try again.';

  @override
  String get tutoredEntryAborted =>
      'Could not open the talmid profile on this account. Please try again.';

  @override
  String viewingChildBanner(String name) {
    return 'Parent mode — viewing $name';
  }

  @override
  String get viewingChildBannerExit => 'Exit parent mode';

  @override
  String get switchIntoChildTitle => 'Switch to child view';

  @override
  String switchIntoChildMessage(String name) {
    return 'You are about to enter $name\'s full experience. You can exit anytime from the banner at the top.';
  }

  @override
  String get switchIntoChildConfirm => 'Switch in';

  @override
  String get tutorCannotMarkLiveCompletion =>
      'Tutors cannot mark live completions';

  @override
  String get tutorWriteForbiddenTitle => 'Action not allowed';

  @override
  String get tutorWriteForbiddenMessage =>
      'Tutors cannot mark live forward completions. This action would credit the child\'s streak and rewards, which is reserved for the parent or child.';

  @override
  String get tutorPermissionDenied =>
      'You don\'t have permission to make this edit';

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
  String get adultModeCardSubtitleDeepFocused => 'Focused';

  @override
  String get profileBadgeChildMode => 'CHILD MODE';

  @override
  String get profileBadgeAdultMode => 'ADULT MODE';

  @override
  String get profileBadgeParentMode => 'PARENT MODE';

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
  String get manageTutors => 'Manage Tutors';

  @override
  String get manageTutorsSubtitle => 'Invite or remove tutors for this child';

  @override
  String get manageTracksForChildSubtitle =>
      'Add, edit, or archive your child\'s tracks';

  @override
  String get manageGoals => 'Manage Goals';

  @override
  String get manageGoalsSubtitle => 'Set pace or deadline goals for each track';

  @override
  String get manageChildLearningSubtitle =>
      'Manage tracks, points, rewards, and goals';

  @override
  String get pointConfiguration => 'Point Configuration';

  @override
  String get pointConfigurationSubtitle =>
      'Set how many points activities are worth';

  @override
  String get rewardConfigurationTitle => 'Reward Configuration';

  @override
  String get rewardConfigurationSubtitle =>
      'Set prizes your child can redeem with their points.';

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
  String get rewardConfigDuplicateName =>
      'A reward with this name already exists.';

  @override
  String get rewardConfigEmptyMilestones =>
      'No rewards yet. Close this menu and use the form above to add one.';

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
  String get rewardConfigChooseAvatarStep => 'CHOOSE AN AVATAR';

  @override
  String get rewardConfigRewardTypeLabel => 'Reward type';

  @override
  String get rewardConfigChooseTrackLabel => 'Choose track';

  @override
  String get rewardConfigPreviewLabel => 'PREVIEW';

  @override
  String rewardConfigPointsPreview(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points Points',
      one: '$points Point',
    );
    return '$_temp0';
  }

  @override
  String get rewardConfigCancel => 'Cancel';

  @override
  String get rewardConfigSaveRewardButton => 'Save Reward';

  @override
  String get rewardConfigUpdateRewardButton => 'Update Reward';

  @override
  String get rewardConfigEditModeSubtitle =>
      'Update the icon, name, or point cost for this reward.';

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
    return '\"$name\" was added. Your child can now see this reward — locked and blurred until they reach the points goal.';
  }

  @override
  String get rewardConfigRewardUpdatedTitle => 'Reward updated';

  @override
  String rewardConfigRewardUpdatedBody(String name) {
    return 'Your changes to \"$name\" were saved. Your child can now see the update.';
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
  String get pinEntryDefaultTitle => 'Enter PIN';

  @override
  String get pinDialogSubtitleSwitchProfile =>
      'Enter the PIN to switch profiles.';

  @override
  String get pinDialogSubtitleEditProfile =>
      'Enter the PIN to edit this profile.';

  @override
  String get pinDialogSubtitleDeleteProfile =>
      'Enter the PIN to delete this profile.';

  @override
  String get pinBackspace => 'Delete';

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
  String get deviceRestorePhaseRestoring => 'Restoring your data...';

  @override
  String get deviceRestorePhaseLoadingCurricula => 'Loading curricula...';

  @override
  String get deviceRestorePhaseImportingContent => 'Importing content...';

  @override
  String get deviceRestoreErrorTimeout =>
      'The restore timed out. Check your connection and try again.';

  @override
  String get deviceRestoreErrorPermissionDenied =>
      'We couldn\'t access your cloud backup. Please sign in again and retry.';

  @override
  String get deviceRestoreErrorGeneric =>
      'Something went wrong while restoring your data. Tap Retry to try again.';

  @override
  String get skipAndContinue => 'Skip & continue';

  @override
  String get noActiveProfile => 'No active profile';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get enterCurrentPin => 'Enter Current PIN';

  @override
  String get enterCurrentPinSubtitle =>
      'Enter your current 4-digit PIN to change it.';

  @override
  String get enterNewPin => 'Enter New PIN';

  @override
  String get confirmNewPin => 'Confirm New PIN';

  @override
  String get pinsDoNotMatch => 'PINs do not match';

  @override
  String get pinInvalidFormat => 'Enter a 4-digit numeric PIN';

  @override
  String get pinFailedToSave => 'Failed to save PIN';

  @override
  String get pinNoActiveProfile => 'No active profile';

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
  String get journeyEmptyTitle => 'No siyumim yet';

  @override
  String get journeyEmptyBody =>
      'When you complete a masechta or sefer, it will be recorded here as a permanent milestone.';

  @override
  String get chartCumulativeProgress => 'Cumulative Progress';

  @override
  String get chartCumulativeProgressSubtitle => 'Total completions over time';

  @override
  String get chartPointsEarned => 'Points Earned';

  @override
  String get chartTotalTorahPoints => 'TOTAL TORAH POINTS';

  @override
  String get chartPointsEarnedSubtitle => 'POINTS EARNED';

  @override
  String get chartLast7Days => 'Last 7 Days';

  @override
  String get chartLast30Days => 'Last 30 Days';

  @override
  String get chartAllTime => 'All Time';

  @override
  String get chartFilterAll => 'All';

  @override
  String get learnStreakCurrentAchievement => 'CURRENT ACHIEVEMENT';

  @override
  String learnStreakDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Day Streak',
      one: '1 Day Streak',
    );
    return '$_temp0';
  }

  @override
  String learnStreakPersonalBest(int count) {
    return 'Personal Best: $count';
  }

  @override
  String get learnStreakKeepItUp => 'Keep it up!';

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
  String get notifRewardMilestones => 'Reward Notifications';

  @override
  String get notifRewardMilestonesSubtitle => 'When you earn Learning Points!';

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
  String get authEmailRequired => 'Email is required';

  @override
  String get authEmailInvalid => 'Please enter a valid email address';

  @override
  String get authDisplayNameRequired => 'Display name is required';

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
  String get authVerifyEmailTitle => 'Confirm Your Email';

  @override
  String get authVerifyEmailBody =>
      'We sent a verification link to your inbox. Please check your email to continue.';

  @override
  String get authOpenEmailButton => 'Open Email';

  @override
  String get authSendAgainButton => 'Send Again';

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
  String get authErrExistingPasswordAccount =>
      'This email already has a password. Sign in with your password instead.';

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
  String get offlineBannerMessage =>
      'Offline — changes will sync when you\'re back';

  @override
  String get offlineBannerSemantics =>
      'Offline — changes will sync when you\'re back online';

  @override
  String get signInOfflineHint =>
      'You\'re offline. Signing in requires an internet connection.';

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
  String get signInPasswordHint => 'Enter your secret key';

  @override
  String get signInKeepMeSignedIn => 'Keep me signed in';

  @override
  String get signInForgotPassword => 'Forgot your Secret Key?';

  @override
  String get signInForgotPasswordSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get signInForgotPasswordNoEmail =>
      'Please enter your email address first.';

  @override
  String get signInCta => 'Sign In';

  @override
  String get signInWithGoogleCta => 'Sign in with Google';

  @override
  String get signInNewToQuest => 'New to the Quest? ';

  @override
  String get signInRegisterHere => 'Register Here';

  @override
  String get signUpTitle => 'Create Account';

  @override
  String get signUpSubtitle => 'Create your free account';

  @override
  String get signUpScholarNameHint => 'Scholar Name';

  @override
  String get signUpEmailAddressLabel => 'Email Address';

  @override
  String get signUpPasswordLabel => 'Create Password';

  @override
  String get signUpPasswordHint => 'Create a secure password';

  @override
  String get signUpCta => 'Sign Up';

  @override
  String get signUpOrDivider => 'OR';

  @override
  String get signUpGoogleCta => 'Sign Up with Google';

  @override
  String get signUpAlreadyExploring => 'Already exploring? ';

  @override
  String get signUpLogIn => 'Log In';

  @override
  String get signUpOfflineAck =>
      'Offline mode: account stays only on this device.';

  @override
  String get signUpAckRequiredError =>
      'Please acknowledge the offline account warning before creating an offline account.';

  @override
  String get signUpOfflineExplain =>
      'No internet connection. You can create an offline account that stays only on this device — no email or password needed. When you\'re back online, you can back it up by upgrading to a cloud account.';

  @override
  String get signUpOfflineConfirmTitle =>
      'No internet — create an offline account?';

  @override
  String get signUpRetryConnection => 'Retry connection';

  @override
  String get offlineAccountLabel => 'Offline account';

  @override
  String get signUpVerificationEmailSent =>
      'Verification email sent. Verify your email, then sign in.';

  @override
  String get signUpEmailAlreadyExists =>
      'An account already exists with this email.';

  @override
  String get signUpDeviceEmailExists =>
      'An account with this email already exists on this device. Sign in instead.';

  @override
  String get signUpOfflineInProgress =>
      'An offline signup for this email is already in progress. Finish creating a profile or try again later.';

  @override
  String get signUpOfflineEmailExists =>
      'An offline account already exists on this device with that email.';

  @override
  String signUpFailed(String error) {
    return 'Signup failed: $error';
  }

  @override
  String get signUpFallbackBody =>
      'The internet connection dropped during signup. Would you like to create an offline account instead?';

  @override
  String get signUpErrWeakPassword =>
      'Password is too weak. Use at least 6 characters.';

  @override
  String get signUpErrGeneric => 'Account creation failed. Please try again.';

  @override
  String get chartFailedToLoad => 'Failed to load data';

  @override
  String get accountPickerTitle => 'Choose an Account';

  @override
  String get accountPickerSubtitle => 'Select an account to continue';

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
  String get accountRemovePendingSyncTitle => 'Not backed up yet';

  @override
  String accountRemovePendingSyncBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes haven\'t',
      one: '1 change hasn\'t',
    );
    return '$_temp0 been backed up to the cloud yet. Connect to the internet, wait for sync to finish, then try again.';
  }

  @override
  String accountPickerAddAnother(int remaining) {
    return 'Add another account ($remaining slots remaining)';
  }

  @override
  String get cannotDeactivateLastCurriculum =>
      'At least one curriculum must remain active';

  @override
  String get cannotDeactivateLastCurriculumDetail =>
      'You cannot remove your last active curriculum. Add another curriculum before removing this one.';

  @override
  String get actionStart => 'Start';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionNext => 'Next';

  @override
  String get actionBack => 'Back';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionExit => 'Exit';

  @override
  String get actionReplace => 'Replace';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionClose => 'Close';

  @override
  String get actionOk => 'OK';

  @override
  String get actionSkipForNow => 'Skip for now';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionUseToday => 'Use Today';

  @override
  String get actionStartHere => 'Start here';

  @override
  String get actionStartHereLabel => 'Start Here';

  @override
  String get actionClear => 'Clear';

  @override
  String get appErrorViewNoConnectionTitle => 'No connection';

  @override
  String get appErrorViewNoConnectionBody =>
      'Check your internet connection and try again.';

  @override
  String get appErrorViewInvalidDataTitle => 'Invalid data';

  @override
  String get appErrorViewInvalidDataBody =>
      'The information provided isn\'t valid. Please check and try again.';

  @override
  String get appErrorViewAccessDeniedTitle => 'Access denied';

  @override
  String get appErrorViewAccessDeniedBody =>
      'You don\'t have permission to view this. Sign in or contact support.';

  @override
  String get appErrorViewNotFoundTitle => 'Not found';

  @override
  String get appErrorViewNotFoundBody =>
      'The requested item could not be found.';

  @override
  String get appErrorViewGenericTitle => 'Something went wrong';

  @override
  String get appErrorViewGenericBody =>
      'An unexpected error occurred. Try again or report the issue.';

  @override
  String get appErrorViewReportButton => 'Report this issue';

  @override
  String get appErrorViewReportedSnackbar =>
      'Thanks — we\'ve logged the issue.';

  @override
  String errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String errorLoadingOrder(String error) {
    return 'Error loading order: $error';
  }

  @override
  String errorLoadingContent(String error) {
    return 'Error loading content: $error';
  }

  @override
  String get errorLoadingPoints => 'Error loading points';

  @override
  String get errorSaveFailed => 'Failed to save. Please try again.';

  @override
  String errorSearchFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String errorSearchError(String error) {
    return 'Search error: $error';
  }

  @override
  String errorUnknownCurriculum(String curriculumId) {
    return 'Unknown curriculum: \"$curriculumId\"';
  }

  @override
  String get errorCouldNotSaveRetry => 'Couldn\'t save — tap to retry';

  @override
  String get errorSaveTrackFailed => 'Failed to save track. Please try again.';

  @override
  String get errorSignOutFailed => 'Failed to sign out. Please try again.';

  @override
  String get errorReauthFailed => 'Re-authentication failed. Please try again.';

  @override
  String get errorResolveAccount =>
      'Could not resolve this account. Try again.';

  @override
  String get errorOnlyOfflineDelete =>
      'Only offline accounts can be deleted here.';

  @override
  String get errorDeleteProfileRequiresInternet =>
      'An internet connection is required to delete a profile.';

  @override
  String get errorDeleteAccountRequiresInternet =>
      'An internet connection is required to delete your account.';

  @override
  String errorDeleteAccountFailed(String error) {
    return 'Failed to delete account: $error';
  }

  @override
  String get errorSendLogsMustBeSignedIn => 'Must be signed in to send logs';

  @override
  String get errorSendLogsNoGateway =>
      'Sync not available — account not linked to cloud';

  @override
  String errorSendLogsFailed(String error) {
    return 'Failed to send logs: $error';
  }

  @override
  String sendLogsSuccess(int count) {
    return 'Logs sent ($count entries). View in Firebase console → diagnostic_logs.';
  }

  @override
  String get errorNoEmailApp => 'No email app found. Copy address instead?';

  @override
  String errorMarkCompleteFailed(String error) {
    return 'Failed to mark complete: $error';
  }

  @override
  String get errorVerificationEmailSent =>
      'Verification email sent. Check your inbox.';

  @override
  String get noData => 'No data';

  @override
  String get noTasksForToday => 'No tasks for today';

  @override
  String get noItemsToOrder => 'No items to order.';

  @override
  String get noProfilesYet => 'No profiles yet. Tap + to add one.';

  @override
  String get noCompletionsYet => 'No completions yet';

  @override
  String noResultsForQuery(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noResultsForQueryHint =>
      'Try searching by the Hebrew name (e.g. ברכות).';

  @override
  String viewAllTasks(int count) {
    return 'View all ($count) →';
  }

  @override
  String tasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks today',
      one: '1 task today',
    );
    return '$_temp0';
  }

  @override
  String get tapToStartLearning => 'Tap to start learning';

  @override
  String get todaysLearningTitle => 'Today\'s Learning';

  @override
  String remainingCount(int count) {
    return '$count remaining';
  }

  @override
  String get allDoneForToday => 'All done for today!';

  @override
  String missedReview(int count) {
    return 'Missed review ($count)';
  }

  @override
  String todaysReview(int count) {
    return 'Today\'s review ($count)';
  }

  @override
  String get dailyTasksTitle => 'Daily Tasks';

  @override
  String get taskSkippedUntilTomorrow => 'Task skipped until tomorrow';

  @override
  String get tasksNoTasksRemainingTitle =>
      'You have no tasks remaining for today.';

  @override
  String get tasksNoOverdueTasksSubtitle => 'No overdue tasks.';

  @override
  String get undoLabel => 'Undo';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHintEnterTerm => 'Enter a search term above';

  @override
  String get loadingText => 'Loading text...';

  @override
  String get markedComplete => 'Marked complete';

  @override
  String couldNotSave(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get textReaderTooltipPrevious => 'Previous';

  @override
  String get textReaderTooltipNext => 'Next';

  @override
  String get textReaderHebrewTab => 'Hebrew Text';

  @override
  String get textReaderEnglishTab => 'English Translation';

  @override
  String get totalPointsLabel => 'Total Points';

  @override
  String get resetToDefaultOrder => 'Reset to Default Order';

  @override
  String get resetToDefaultOrderDialogTitle => 'Reset to Default Order';

  @override
  String get resetToDefaultOrderDialogBody =>
      'This will restore the natural Sefaria order for this curriculum. Your custom ordering will be lost.';

  @override
  String get reorderConfirmTitle => 'Reorder Content?';

  @override
  String reorderConfirmBody(int overdueCount) {
    return 'Reordering will clear your $overdueCount outstanding overdue item(s). Consider completing them first.';
  }

  @override
  String get controlledByParent => 'Controlled by parent';

  @override
  String sacredTimeLockGoodShabbos(String term) {
    return 'Good $term';
  }

  @override
  String sacredTimeLockShabbosSubtitle(String term) {
    return 'The app is closed for $term.';
  }

  @override
  String get sacredTimeLockGoodYomTov => 'Good Yom Tov';

  @override
  String get sacredTimeLockYomTovSubtitle => 'The app is closed for Yom Tov.';

  @override
  String sacredTimeLockShabbosYomTovGreeting(String term) {
    return 'Good $term & Good Yom Tov';
  }

  @override
  String sacredTimeLockShabbosYomTovSubtitle(String term) {
    return 'The app is closed for $term and Yom Tov.';
  }

  @override
  String get sacredTimeLockYomKippurGreeting =>
      'Have an easy and meaningful fast';

  @override
  String get sacredTimeLockYomKippurSubtitle =>
      'The app is closed for Yom Kippur.';

  @override
  String get sacredTimeDetect => 'Detect';

  @override
  String get sacredTimeChooseCity => 'Choose city';

  @override
  String get textReaderTextUnavailableTitle => 'Text not available';

  @override
  String get textReaderCheckConnection =>
      'Check your internet connection and try again.';

  @override
  String get textReaderFailedToLoad => 'Failed to load text';

  @override
  String sacredTimeCardDescription(String term) {
    return 'App is silenced and locked during $term and Yom Tov. Times computed locally from your location with a 15-minute cushion.';
  }

  @override
  String sacredTimeShabbosModeLabel(String term) {
    return '$term MODE';
  }

  @override
  String get sacredTimeAlwaysOn => 'Always on';

  @override
  String get sacredTimeNoLocation => 'No location set';

  @override
  String get sacredTimeSourceDetected => 'Detected automatically';

  @override
  String get sacredTimeSourceManualCity => 'Chosen from city list';

  @override
  String get sacredTimeSourceManualCoords => 'Manual coordinates';

  @override
  String get sacredTimeInIsraelTitle => 'I am in Israel';

  @override
  String get sacredTimeInIsraelSubtitle =>
      'One-day chag if on. Auto-set when you detect or choose a city, flip if you are visiting.';

  @override
  String get sacredTimeLocationUpdated => 'Location updated.';

  @override
  String get sacredTimeLocationPermissionPermanentlyDenied =>
      'Location permission permanently denied. Open system settings to allow.';

  @override
  String get sacredTimeLocationPermissionDenied =>
      'Location permission denied.';

  @override
  String get sacredTimeLocationServicesOff =>
      'Location services are turned off on this device.';

  @override
  String sacredTimeLocationDetectError(String message) {
    return 'Could not detect location: $message';
  }

  @override
  String get newPasswordLabel => 'New Password';

  @override
  String get confirmNewPasswordLabel => 'Confirm New Password';

  @override
  String get passwordMinLengthError => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatchError => 'Passwords do not match';

  @override
  String get changePasswordFailedError =>
      'Failed to change password. Please try again.';

  @override
  String get currentPasswordLabel => 'Current Password';

  @override
  String get invalidPasswordError => 'Invalid password. Please try again.';

  @override
  String get calendarOffsetToday => 'Today';

  @override
  String get dayNameShabbos => 'Shabbos';

  @override
  String get statusPendingTapToAccept => 'Pending — tap to accept';

  @override
  String calendarOffsetDay(String offset) {
    return 'Day $offset';
  }

  @override
  String get calendarDirectionForward => 'FORWARD';

  @override
  String get calendarDirectionBackwards => 'BACKWARDS';

  @override
  String get calendarDirectionToday => 'TODAY';

  @override
  String calendarOffsetDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Days',
      one: '1 Day',
    );
    return '$_temp0';
  }

  @override
  String startingPositionSelectInstruction(String itemLabel) {
    return 'Select the $itemLabel you are currently up to.';
  }

  @override
  String startingPositionBackToListTooltip(String containerLabel) {
    return 'Back to $containerLabel list';
  }

  @override
  String get startingPositionItemFallbackLabel => 'Item';

  @override
  String searchFieldHint(String label) {
    return 'Search ⁦$label⁩…';
  }

  @override
  String get cityPickerTitle => 'Choose a city';

  @override
  String get cityPickerHint => 'Type a city name…';

  @override
  String cityPickerNoMatches(String query) {
    return 'No matches for \"$query\".';
  }

  @override
  String get cityPickerIdleHint =>
      'Start typing to search ~33,000 cities.\nType at least 2 letters.';

  @override
  String get schedulerStudyLabel => 'Study';

  @override
  String get schedulerReviewOnlyLabel => 'Review only';

  @override
  String get schedulerPerDay => 'Per day';

  @override
  String get schedulerPerWeek => 'Per week';

  @override
  String get schedulerPerakimLabel => 'Perakim';

  @override
  String get schedulerPesukimLabel => 'Pesukim';

  @override
  String get schedulerAmudimLabel => 'Amudim';

  @override
  String get schedulerDafimLabel => 'Dafim';

  @override
  String get schedulerDeadlineLabel => 'Deadline';

  @override
  String get schedulerPaceLabel => 'Pace';

  @override
  String get schedulerNoDeadlineLabel => 'No deadline';

  @override
  String get schedulerGoalHint => 'e.g., Bar Mitzvah, Yahrzeit, Siyum';

  @override
  String get schedulerSelectDate => 'Select date';

  @override
  String get schedulerPickDeadlineFirst => 'Pick a deadline first.';

  @override
  String get schedulerDaysLabel => 'Days';

  @override
  String get schedulerWeeksLabel => 'Weeks';

  @override
  String get schedulerHebrewDatePickerTitle => 'Select Hebrew date';

  @override
  String get schedulerHebrewYearLabel => 'Hebrew year';

  @override
  String get schedulerHebrewMonthFieldLabel => 'Month';

  @override
  String get schedulerHebrewDayFieldLabel => 'Day';

  @override
  String schedulerHebrewDateEnglishPreview(String date) {
    return 'English: $date';
  }

  @override
  String get profilesEditLabel => 'Edit';

  @override
  String get profilesDeleteLabel => 'Delete';

  @override
  String get profilesChooseAvatar => 'Choose Avatar';

  @override
  String get profilesAddLearner => 'Add Learner';

  @override
  String get profilesEditLearner => 'Edit Learner';

  @override
  String get profilesChildLabel => 'Child';

  @override
  String get profilesAdultLabel => 'Adult';

  @override
  String get profilesEnterLearnerName => 'Enter learner name';

  @override
  String get profilesNameFieldLabel => 'Name';

  @override
  String get learnerNameRequired => 'Enter a name';

  @override
  String get deleteProfileTitle => 'Delete Profile?';

  @override
  String get deleteProfileLastTitle => 'Delete your only profile?';

  @override
  String deleteProfileBody(String name) {
    return 'Are you sure you want to delete \"$name\"? All learning data for this profile will be permanently lost.';
  }

  @override
  String deleteProfileLastBody(String name) {
    return 'This is your only profile. Deleting \"$name\" will erase every track, completion, and lifetime entry on this account. You will need to create a new profile before you can keep learning.';
  }

  @override
  String get deleteProfileLastConfirm => 'Delete anyway';

  @override
  String get trackNameThisTrack => 'Name This Track';

  @override
  String get trackNameLabel => 'Track Name';

  @override
  String get trackAddLabel => 'ADD TRACK';

  @override
  String get trackDeleteTitle => 'Delete Track?';

  @override
  String get trackMarkContentDone => 'Mark Content Done';

  @override
  String get trackReorderContent => 'Reorder Content';

  @override
  String trackReplaceTitle(String label) {
    return 'Replace your $label track?';
  }

  @override
  String get bulkMarkCompleteTitle => 'Bulk Mark Complete';

  @override
  String bulkMarkedComplete(int count) {
    return 'Marked $count items as complete';
  }

  @override
  String get bulkMarkConfirmBulkTitle => 'Confirm Bulk Mark';

  @override
  String get bulkMarkingCompletions => 'Marking completions...';

  @override
  String get bulkMarkDone => 'Done!';

  @override
  String get bulkMarkSkip => 'Skip';

  @override
  String get bulkMarkPriorLearning => 'Mark Prior Learning';

  @override
  String get completionButtonCompleted => 'Completed';

  @override
  String get completionButtonMarkComplete => 'Mark Complete';

  @override
  String get upgradePromptOnlineBody =>
      'You\'re online — back up your account so you don\'t lose your learning if this device is lost.';

  @override
  String get upgradePromptBackup => 'Back up';

  @override
  String get upgradePromptDismiss => 'Not now';

  @override
  String get upgradeToCloudValuePropNew =>
      'Create a cloud account to back up your learning and sync it across devices. This is one-way — you can\'t switch back to offline-only after upgrading.';

  @override
  String get upgradeToCloudEmailLabel => 'Email address';

  @override
  String get upgradeToCloudNewPasswordLabel => 'Create a password';

  @override
  String get upgradeToCloudEmailRequired => 'Email is required';

  @override
  String get upgradeToCloudEmailInvalid => 'Enter a valid email address';

  @override
  String get upgradeToCloudTitle => 'Upgrade to Cloud';

  @override
  String get upgradeToCloudButton => 'Upgrade to Cloud';

  @override
  String get upgradeToCloudCancelKeepOffline => 'Cancel — keep offline account';

  @override
  String get upgradeToCloudHeadline => 'Back up your account';

  @override
  String upgradeToCloudValueProp(String email) {
    return 'You\'re signed in as $email. Upgrading will create a cloud account with the same email so your data syncs across devices. This is one-way — you can\'t switch back to offline-only after upgrading.';
  }

  @override
  String get upgradeToCloudPasswordLabel => 'Confirm your password';

  @override
  String get upgradeToCloudPasswordRequired => 'Password required';

  @override
  String get upgradeToCloudErrorLocalBornOnly =>
      'Only local-born accounts can be upgraded.';

  @override
  String get upgradeToCloudErrorInternetRequired =>
      'Internet connection is required to upgrade to cloud. Your account and data stay local until you retry online.';

  @override
  String get upgradeToCloudErrorInternetRequiredShort =>
      'Internet connection is required to upgrade to cloud.';

  @override
  String get upgradeToCloudErrorIncorrectPassword => 'Incorrect password.';

  @override
  String get upgradeToCloudErrorGeneric =>
      'We couldn\'t complete the upgrade. Please try again.';

  @override
  String get upgradeToCloudVerifyBody =>
      'We sent a confirmation link to your inbox. After you verify, tap \"I\'ve verified — complete upgrade\" below.';

  @override
  String get upgradeToCloudVerifiedLinkLabel =>
      'I\'ve verified — complete upgrade';

  @override
  String get upgradeToCloudSuccessTitle => 'You\'re backed up!';

  @override
  String get upgradeToCloudSuccessBody =>
      'Your data will now sync across devices automatically.';

  @override
  String get upgradeToCloudCollisionTitle =>
      'A cloud account already exists with this email';

  @override
  String get upgradeToCloudCollisionBody =>
      'We won\'t silently merge — choose how to resolve this:';

  @override
  String get upgradeToCloudCollisionUploadTitle => 'Upload local into cloud';

  @override
  String get upgradeToCloudCollisionUploadSubtitle =>
      'Your offline progress merges with the existing cloud account.';

  @override
  String get upgradeToCloudCollisionKeepCloudTitle =>
      'Keep cloud, discard local';

  @override
  String get upgradeToCloudCollisionKeepCloudSubtitle =>
      'Sign in to the existing cloud account. Your local-only changes on this device are replaced with cloud data.';

  @override
  String get upgradeToCloudCloudPasswordLabel => 'Cloud account password';

  @override
  String get upgradeToCloudCloudPasswordHint =>
      'The password for the existing cloud account';

  @override
  String get upgradeToCloudCloudPasswordRequired =>
      'Please enter your cloud account password.';

  @override
  String get upgradeToCloudDiscardAcknowledge =>
      'I understand that cloud data will replace any purely-local changes on this device.';

  @override
  String get upgradeToCloudDiscardAcknowledgeRequired =>
      'Please acknowledge that local data will be replaced by cloud data.';

  @override
  String get upgradeToCloudCollisionUploadButton => 'Upload and sign in';

  @override
  String get upgradeToCloudCollisionDiscardButton =>
      'Discard local and sign in';

  @override
  String get upgradeToCloudErrorIncorrectCloudPassword =>
      'Incorrect cloud account password.';

  @override
  String get upgradeToCloudErrorMergeInternetRequired =>
      'Internet connection is required to complete this merge option.';

  @override
  String get upgradeToCloudErrorMergeGeneric =>
      'We couldn\'t complete this merge option. Please try again.';

  @override
  String get upgradeToCloudCloudNotVerifiedBody =>
      'This cloud account is not verified yet. Check your inbox, then tap \"I\'ve verified — complete upgrade\" below.';

  @override
  String get scopeSelectionSave => 'Save';

  @override
  String get scopeSelectionTrackEntireCurriculum => 'Track Entire Curriculum';

  @override
  String get scopeSelectionChooseHierarchyLevel =>
      'Choose which hierarchy level to filter by';

  @override
  String get scopeSelectionChangeLevel => 'Change Level';

  @override
  String scopeSelectionTitle(String curriculum) {
    return 'Learning Scope — $curriculum';
  }

  @override
  String get scopeSelectionAllContentIncluded => 'All content is included';

  @override
  String get scopeSelectionOnlySelectedTracked =>
      'Only selected sections are tracked';

  @override
  String get scopeSelectionSelectScopeLevel => 'Select Scope Level';

  @override
  String get scopeSelectionSummary => 'Summary';

  @override
  String scopeSelectionOptionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return '$_temp0';
  }

  @override
  String scopeSelectionItemsWillBeTracked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items will be tracked',
      one: '1 item will be tracked',
    );
    return '$_temp0';
  }

  @override
  String get scopeSelectionScopeSetEntireCurriculum =>
      'Scope set to entire curriculum';

  @override
  String scopeSelectionScopeUpdated(String values) {
    return 'Scope updated: $values';
  }

  @override
  String get curriculumSettingsLoadingProgram => 'Loading program...';

  @override
  String get curriculumSettingsProgramTitle => 'Program';

  @override
  String curriculumSettingsProgramError(String error) {
    return 'Error: $error';
  }

  @override
  String get curriculumSettingsChangeProgram => 'Change Program';

  @override
  String get curriculumSettingsChangeProgramSubtitle =>
      'Switch to a different learning program';

  @override
  String get curriculumSettingsDontSeeProgram => 'Don\'t see your program?';

  @override
  String get curriculumSettingsRequestProgram => 'Request a new program';

  @override
  String get curriculumSettingsCustomSchedule => 'Custom schedule';

  @override
  String curriculumSettingsTitle(String curriculum) {
    return 'Settings - $curriculum';
  }

  @override
  String get curriculumSettingsCopy => 'Copy';

  @override
  String curriculumSettingsProgramLabel(String name) {
    return 'Program: $name';
  }

  @override
  String get deleteAccountDialogTitle => 'Delete Account';

  @override
  String get deleteAccountTypeConfirm => 'Type DELETE to confirm:';

  @override
  String get deleteAccountHint => 'DELETE';

  @override
  String get deleteAccountWarningBody =>
      'This action is permanent and cannot be undone. All your data will be deleted.';

  @override
  String get deleteAccountReauthPassword =>
      'You will be asked to re-enter your password to confirm your identity.';

  @override
  String deleteAccountReauthProvider(String provider) {
    return 'You will be asked to sign in with $provider to confirm your identity.';
  }

  @override
  String backupLastSynced(String timeAgo) {
    return 'Last synced $timeAgo';
  }

  @override
  String get backupSyncing => 'Syncing...';

  @override
  String backupPendingChanges(int count) {
    return '$count changes pending';
  }

  @override
  String backupSyncError(String message) {
    return 'Sync error: $message';
  }

  @override
  String get backupSyncTapToRetry => 'Tap to retry';

  @override
  String get backupSyncCloudUnavailable =>
      'Cloud backup is temporarily unavailable.';

  @override
  String get backupSyncOutboxStuck =>
      'Some changes are waiting to sync. We\'ll retry automatically.';

  @override
  String backupSyncIdentityMismatch(String signedInEmail, String activeEmail) {
    return 'Signed in as $signedInEmail — sign in as $activeEmail to back up this account.';
  }

  @override
  String get backupSyncIdentityMismatchNoEmail =>
      'Signed in as the wrong account — sign in again to back up.';

  @override
  String get backupSyncUnknownAccount => 'a different account';

  @override
  String get backupConnecting => 'Connecting…';

  @override
  String get backupOffline => 'Offline';

  @override
  String backupSyncPaused(int count, String reason) {
    return 'Sync paused — $count queued. $reason';
  }

  @override
  String backupSyncPausedNoCount(String reason) {
    return 'Sync paused. $reason';
  }

  @override
  String get backupUpgradeToCloud => 'Upgrade to Cloud';

  @override
  String get backupSyncCardTitle => 'Backup & Sync';

  @override
  String get backupSyncCardBody =>
      'Your learning progress is currently LOCAL ONLY. Upgrade to sync across all devices.';

  @override
  String get backupTimeAgoJustNow => 'just now';

  @override
  String backupTimeAgoMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String backupTimeAgoHours(int count) {
    return '${count}h ago';
  }

  @override
  String backupTimeAgoDays(int count) {
    return '${count}d ago';
  }

  @override
  String get backupSyncSignInToBackUp => 'Sign in to back up';

  @override
  String get reauthDialogTitle => 'Verify Your Identity';

  @override
  String get reauthDialogBody =>
      'Please enter your current password to continue.';

  @override
  String get reauthVerify => 'Verify';

  @override
  String get linkAccountTitle => 'Link Account';

  @override
  String get linkAccountSubtitle =>
      'Add another sign-in method to your account.';

  @override
  String get linkAccountGoogleLabel => 'Google';

  @override
  String get linkAccountEmailPasswordLabel => 'Email/Password';

  @override
  String get linkAccountLinkEmail => 'Link Email';

  @override
  String get linkAccountAllLinked =>
      'All available sign-in methods are already linked.';

  @override
  String get linkAccountGoogleSuccess => 'Google account linked successfully.';

  @override
  String get linkAccountEmailSuccess =>
      'Email/password account linked successfully.';

  @override
  String get changePasswordDialogTitle => 'Change Password';

  @override
  String get changePasswordButton => 'Change Password';

  @override
  String get accountDeletedTitle => 'Account deleted';

  @override
  String get signOutLabel => 'Sign Out';

  @override
  String get signOutConfirmTitle => 'Sign Out';

  @override
  String get signOutConfirmBody =>
      'Are you sure you want to sign out? Your data will be preserved for when you sign back in.';

  @override
  String get connectionLostTitle => 'Connection lost';

  @override
  String get tryAgainButton => 'Try Again';

  @override
  String get createOfflineAccount => 'Create Offline Account';

  @override
  String get onboardingConfirm => 'Confirm';

  @override
  String get onboardingStartLearning => 'Start Learning';

  @override
  String get onboardingAddAnotherTrack => 'Add Another Track';

  @override
  String get onboardingAddAnotherLearner => 'Add Another Learner';

  @override
  String get onboardingSkipNoReview => 'Skip (no review)';

  @override
  String get onboardingMarkCompleted => 'Mark Completed';

  @override
  String get onboardingStartingPosition => 'Starting Position';

  @override
  String get onboardingStudyDays => 'Study Days';

  @override
  String get stageNameLimud => 'לימוד';

  @override
  String get stageNameChazaraAleph => 'חזרה א׳';

  @override
  String get stageNameChazaraBet => 'חזרה ב׳';

  @override
  String get actionMarkCompleted => 'Mark Completed';

  @override
  String get actionSkipNoReview => 'Skip (no review)';

  @override
  String get studyDaysTitle => 'Study Days';

  @override
  String get studyDaysSubtitle => 'Which days do you learn?';

  @override
  String studyDaysPerWeekLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count study days per week',
      one: '1 study day per week',
    );
    return '$_temp0';
  }

  @override
  String studyDayConfigTitle(String curriculumName) {
    return '$curriculumName Study Days';
  }

  @override
  String get studyDayConfigSubtitle =>
      'Choose which days include new learning and which are for review only.';

  @override
  String get studyDayConfigAllDaysStudy =>
      'All days are study days for this track.';

  @override
  String studyDaysSetByProgram(String programName) {
    return 'Study days set by $programName';
  }

  @override
  String get startingPositionTitle => 'Starting Position';

  @override
  String get startingPositionHint => 'Can start up to 30 days back from today';

  @override
  String startingPositionWhereAreYou(String programName) {
    return 'Where are you in $programName?';
  }

  @override
  String get priorLearningTitle => 'Mark Prior Learning';

  @override
  String get priorLearningSubtitle =>
      'Do you want to mark parts you already learned as completed?';

  @override
  String get goalPickDeadlineFirst => 'Pick a deadline first.';

  @override
  String get trackSaveError => 'Failed to save track. Please try again.';

  @override
  String get pacePerDay => 'Per day';

  @override
  String get pacePerWeek => 'Per week';

  @override
  String get goalTypeDeadline => 'Deadline';

  @override
  String get goalTypePace => 'Pace';

  @override
  String get goalTypeNoDeadline => 'No deadline';

  @override
  String get goalEditTitle => 'Edit Goal';

  @override
  String get goalNewTitle => 'New Goal';

  @override
  String get goalUpdateButton => 'Update Goal';

  @override
  String get goalCreateButton => 'Create Goal';

  @override
  String get goalDeadlineDatePickerHint => 'Tap to choose a date';

  @override
  String get goalDeadlineOccasionLabel => 'Occasion (optional)';

  @override
  String get goalDeadlineOccasionHint => 'e.g., Bar Mitzvah, Yahrzeit, Siyum';

  @override
  String get goalDeadlinePassed => 'Deadline has passed';

  @override
  String goalDeadlinePaceItems(int pace) {
    return '~$pace items per day';
  }

  @override
  String goalDeadlineItemsInDays(int items, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$items items in $_temp0';
  }

  @override
  String goalPaceHowMany(String unit, String period) {
    return 'How many $unit per $period?';
  }

  @override
  String get goalPacePeriodDay => 'day';

  @override
  String get goalPacePeriodWeek => 'week';

  @override
  String goalPaceInputLabel(String unit, String period) {
    return '$unit $period';
  }

  @override
  String goalPaceProjectedCompletion(String date) {
    return 'Projected completion: $date';
  }

  @override
  String goalPaceItemsInDays(int items, String unit, int days) {
    return '$items $unit in ~$days days';
  }

  @override
  String goalTargetPercentOnly(int percent) {
    return 'Complete $percent% of the material';
  }

  @override
  String goalTargetPercentWithCount(int percent, int done, int total) {
    return 'Complete $percent% of the material ($done of $total items)';
  }

  @override
  String get goalLearningUnitLabel => 'Learning unit';

  @override
  String get goalNoPressureLabel =>
      'Learn at your own pace with no time pressure.';

  @override
  String get trackSetGoalLabel => 'Set Goal';

  @override
  String get trackEditGoalLabel => 'Edit Goal';

  @override
  String get goalSavedSnack => 'Goal saved';

  @override
  String get goalRemovedSnack => 'Goal removed';

  @override
  String get goalRemoveButton => 'Remove Goal';

  @override
  String get unitPerakim => 'Perakim';

  @override
  String get unitPesukim => 'Pesukim';

  @override
  String get unitAmudim => 'Amudim';

  @override
  String get unitDafim => 'Dafim';

  @override
  String get tasksUnableToLoad => 'Unable to load tasks';

  @override
  String get tasksAllCaughtUp => 'All caught up';

  @override
  String get tasksNoTasksRemainingToday => 'No tasks remaining for today.';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Items',
      one: '1 Item',
    );
    return '$_temp0';
  }

  @override
  String scopeSelectionCountSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String scopeSelectionItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String reviewStageDayDelay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day delay',
      one: '1 day delay',
    );
    return '$_temp0';
  }

  @override
  String get applyToAll => 'Apply to All';

  @override
  String get trackNameSubtitle => 'Give your track a name to identify it.';

  @override
  String priorLearningChooseSections(String curriculumName) {
    return 'Choose which sections to mark in $curriculumName.';
  }

  @override
  String get priorLearningAlreadyCompleted =>
      'Have you already completed some of these sections?';

  @override
  String get priorLearningMarkEverything => 'Mark everything as finished';

  @override
  String get priorLearningMarkEverythingSubtitle =>
      'Best if you are starting a new review cycle';

  @override
  String get priorLearningNoFolders =>
      'No specific folders were selected, but you can still mark all as completed.';

  @override
  String get priorLearningSelectedFolder => 'Selected folder';

  @override
  String scopeSelectionSelectLevel(String levelName) {
    return 'Select $levelName';
  }

  @override
  String get activeTracksLabel => 'Active Tracks';

  @override
  String activeTracksRunning(int count) {
    return '$count RUNNING';
  }

  @override
  String get trackDetailConfigGoal => 'Goal';

  @override
  String get trackDetailConfigItemsRemaining => 'Items remaining';

  @override
  String get trackDetailConfigEstFinish => 'Est. finish';

  @override
  String trackSince(String date) {
    return 'Since $date';
  }

  @override
  String get trackEditLabel => 'Edit Track';

  @override
  String get trackEditTitle => 'Edit Track';

  @override
  String get trackEditSectionName => 'Track Name';

  @override
  String get trackEditSectionGoal => 'Goal';

  @override
  String get trackEditSectionStudyDays => 'Study Days';

  @override
  String trackEditSectionReview(String term) {
    return 'Review ($term)';
  }

  @override
  String get trackEditGoalTypeLocked =>
      'Goal type cannot be changed after setup';

  @override
  String get trackEditProgramLocked =>
      'Review, scope, and study days are managed by the program.';

  @override
  String get trackEditReviewSummaryNone => 'No review';

  @override
  String trackEditReviewSummaryDays(String delays) {
    return 'After $delays';
  }

  @override
  String get trackEditChangeReview => 'Change';

  @override
  String get trackEditSaveButton => 'Save Changes';

  @override
  String get trackEditNameEmptyError => 'Track name cannot be empty.';

  @override
  String get trackEditZeroStudyDaysWarning =>
      'No study days selected — add at least one to schedule new learning.';

  @override
  String get trackEditConfirmTitle => 'Apply changes?';

  @override
  String get trackEditConfirmBody =>
      'Changes apply to future learning only. Existing completions are not affected.';

  @override
  String get trackEditClearOverdueButton => 'Clear Overdue';

  @override
  String get trackEditClearOverdueConfirmTitle => 'Clear overdue items?';

  @override
  String get trackEditClearOverdueConfirmBody =>
      'Overdue items will be removed from your dashboard. They won\'t be marked as done.';

  @override
  String get trackDeleteLabel => 'Delete Track';

  @override
  String trackDeleteContent(String name) {
    return 'Permanently delete \"$name\"? All progress and data for this track will be removed. This cannot be undone.';
  }

  @override
  String get deleteTrackArchiveTitle => 'Delete Track';

  @override
  String get deleteTrackArchiveBody =>
      'What should happen to your completion history?';

  @override
  String get parentDeleteTrackArchiveBody =>
      'What should happen to your child\'s completion history?';

  @override
  String get deleteTrackArchive => 'Archive (keep history)';

  @override
  String get deleteTrackWipe => 'Delete and wipe history';

  @override
  String get notificationReminderTitle => 'Learning Reminder';

  @override
  String notificationReminderBody(int taskCount, int curriculumCount) {
    String _temp0 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount tasks',
      one: '1 task',
    );
    String _temp1 = intl.Intl.pluralLogic(
      curriculumCount,
      locale: localeName,
      other: '$curriculumCount curricula',
      one: '1 curriculum',
    );
    return 'You have $_temp0 across $_temp1 today';
  }

  @override
  String get startingPositionTargetDate => 'TARGET DATE';

  @override
  String get calendarNoLocalEntryFound =>
      'No local calendar entry found for this date.';

  @override
  String get goalPaceOrDeadlineTitle => 'What\'s your pace or deadline?';

  @override
  String get goalPaceOrDeadlineSubtitle => 'Set a goal.';

  @override
  String get goalTargetPace => 'Target Pace';

  @override
  String goalPaceDescriptionLine(String unit, String period) {
    return '$unit $period';
  }

  @override
  String goalEstimatedFinish(String date) {
    return 'Estimated finish: $date';
  }

  @override
  String get goalSetDeadline => 'Set Deadline';

  @override
  String get reviewScheduleTitle => 'Review Schedule';

  @override
  String reviewScheduleSetByProgram(String programName) {
    return 'Review stages set by $programName';
  }

  @override
  String get reviewScheduleFixedHint =>
      'This schedule is fixed by the program and cannot be edited.';

  @override
  String get reviewScheduleNoStages =>
      'No review stages are configured for this program.';

  @override
  String get reviewScheduleAfterOneDay => 'After 1 day';

  @override
  String reviewScheduleAfterNDays(String count) {
    return 'After $count days';
  }

  @override
  String get reviewScheduleScheduledByProgram => 'Scheduled by program';

  @override
  String get chazaraCustomCycle => 'Custom Cycle';

  @override
  String chazaraSessionsCount(int count) {
    return '$count Sessions';
  }

  @override
  String get chazaraAddNew => 'ADD NEW';

  @override
  String get chazaraPresetLearnOnlyTitle => 'Learn Only';

  @override
  String get chazaraPresetLearnOnlyDescription => 'No scheduled reviews.';

  @override
  String get chazaraPresetOneDayTitle => '1 day';

  @override
  String get chazaraPresetOneDayDescription => 'Review next morning.';

  @override
  String get chazaraPresetWeekTitle => '1 + 7 days';

  @override
  String get chazaraPresetWeekDescription => 'The recommended starter.';

  @override
  String get chazaraPresetMonthTitle => '1 + 7 + 30 days';

  @override
  String get chazaraPresetMonthDescription => 'Full mastery cycle.';

  @override
  String get termChazara => 'Chazara';

  @override
  String get termBubbleChazara => 'CHAZARA';

  @override
  String get termReviewSection => 'REVIEW SECTION';

  @override
  String get termDaf => 'Daf';

  @override
  String get termAmud => 'Amud';

  @override
  String get termPerek => 'Perek';

  @override
  String get termMishnah => 'Mishna';

  @override
  String get termSeder => 'Seder';

  @override
  String get termMasechta => 'Masechta';

  @override
  String get termChumash => 'Chumash';

  @override
  String get termTalmidChochom => 'Talmid Chochom';

  @override
  String get termTalmidChochomCaps => 'TALMID CHOCHOM';

  @override
  String get termStageLearn => 'Learn';

  @override
  String get termStageChazaraPrefix => 'Chazara';

  @override
  String get authSignInTimeout =>
      'Sign-in is taking too long. Check your connection and try again.';

  @override
  String get reauthGoogleTitle => 'Confirm with Google to delete your account';

  @override
  String get reauthGoogleBody =>
      'We need you to sign in with Google one more time to confirm it\'s really you. After signing in, your account and all data will be permanently deleted.';

  @override
  String get reauthGoogleContinue => 'Continue to Google';

  @override
  String get deletingAccountTitle => 'Deleting your account…';

  @override
  String get deletingAccountBody =>
      'This may take a few seconds. Please don\'t close the app.';

  @override
  String get deletingAccountError =>
      'Deletion encountered an issue. You have been signed out.';

  @override
  String get itemsLearnedTitle => 'Items Learned';

  @override
  String get itemsLearnedSubtitle => 'Track completions by curriculum';

  @override
  String get itemsLearnedNoCurricula => 'No track completions yet';

  @override
  String get itemsLearnedNoCurriculaSubtitle =>
      'Complete daily tasks to see your progress here';

  @override
  String itemsLearnedOf(int completed, int total) {
    return '$completed of $total';
  }

  @override
  String get overallProgressCardTitle => 'Overall Progress';

  @override
  String get overallProgressStatTotalItems => 'Total items';

  @override
  String get overallProgressStatCompletedAllStages => 'Completed all stages';

  @override
  String get overallProgressStatInProgress => 'In progress';

  @override
  String get overallProgressStatNotStarted => 'Not started';

  @override
  String get curriculumProgressBreakdownByLevel => 'Breakdown by Level';

  @override
  String get curriculumProgressLoading => 'Loading progress...';

  @override
  String curriculumProgressLoadFailed(String error) {
    return 'Failed to load progress: $error';
  }

  @override
  String get curriculumProgressSettingsTooltip => 'Curriculum settings';

  @override
  String get tierLensRecentActivity => 'Recent Activity';

  @override
  String get tierLensSiyumimMilestones => 'Siyumim & Milestones';

  @override
  String get tierLensLifetimeKnowledge => 'Lifetime Knowledge';

  @override
  String streakWidgetDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak!',
      one: '1 day streak!',
    );
    return '$_temp0';
  }

  @override
  String streakWidgetBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Best: $count days',
      one: 'Best: 1 day',
    );
    return '$_temp0';
  }

  @override
  String streakSubtleBest(int count) {
    return '(best: $count)';
  }

  @override
  String get schedulerTodaysGoal => 'TODAY\'S GOAL';

  @override
  String schedulerGoalTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks today',
      one: '1 task today',
    );
    return '$_temp0';
  }

  @override
  String tierCounterStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '$count-day streak',
    );
    return '$_temp0';
  }

  @override
  String tierCounterSiyumimEarned(int count, String siyumimTerm) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count $siyumimTerm earned',
      one: '$count $siyumimTerm earned',
    );
    return '$_temp0';
  }

  @override
  String tierCounterLifetimeItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in lifetime',
      one: '1 item in lifetime',
    );
    return '$_temp0';
  }

  @override
  String tierCounterPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pts',
      one: '$count pt',
    );
    return '$_temp0';
  }

  @override
  String get tierTileLabelStreak => 'Streak';

  @override
  String tierTileLabelSiyumim(String siyumimTerm) {
    return '$siyumimTerm';
  }

  @override
  String get tierTileLabelLifetime => 'Lifetime';

  @override
  String get tierTileLabelPoints => 'Points';

  @override
  String get limud => 'Limud';

  @override
  String get chazara => 'Chazara';

  @override
  String get chazaros => 'Chazaros';

  @override
  String get siyum => 'Siyum';

  @override
  String get siyumim => 'Siyumim';

  @override
  String get milestone => 'Milestone';

  @override
  String get trackProgress => 'Track progress';

  @override
  String get trackMarkPreviouslyLearned => 'Mark as previously learned';

  @override
  String get lifetimeLabel => 'Lifetime';

  @override
  String get streakLabel => 'Streak';

  @override
  String get labelStreakAcrossAllCurricula => 'Streak across all curricula';

  @override
  String paceAheadByDays(int count) {
    return 'Ahead by $count days';
  }

  @override
  String get paceOnTrack => 'On pace';

  @override
  String paceBehindByDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Behind by $count days',
      one: 'Behind by 1 day',
    );
    return '$_temp0';
  }

  @override
  String itemsLearnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items learned',
      one: '1 item learned',
    );
    return '$_temp0';
  }

  @override
  String totalChazaros(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count total Chazaros',
      one: '1 total chazara',
    );
    return '$_temp0';
  }

  @override
  String get siyumHaShas => 'Siyum HaShas';

  @override
  String get siyumHaTorah => 'Siyum HaTorah';

  @override
  String get siyumHaMishnayos => 'Siyum HaMishnayos';

  @override
  String get siyumHaYerushalmi => 'Siyum HaYerushalmi';

  @override
  String get siyumMishnaBerurah => 'Siyum Mishna Berurah';

  @override
  String get siyumMishnehTorah => 'Siyum Mishneh Torah';

  @override
  String get siyumNach => 'Siyum Nach';

  @override
  String get siyumTanach => 'Siyum Tanach';

  @override
  String get siyumMussar => 'Siyum Mussar';

  @override
  String get siyumSeder => 'Siyum Seder';

  @override
  String get siyumChelek => 'Siyum Chelek';

  @override
  String siyumMasechta(String name) {
    return 'Siyum Masechta $name';
  }

  @override
  String siyumSefer(String name) {
    return 'Siyum Sefer $name';
  }

  @override
  String siyumSiman(String name) {
    return 'Siyum Siman $name';
  }

  @override
  String siyumHilchos(String name) {
    return 'Siyum Hilchos $name';
  }

  @override
  String siyumimLevelCurriculum(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count curriculum-level siyumim',
      one: '1 curriculum-level siyum',
    );
    return '$_temp0';
  }

  @override
  String siyumimLevelAggregate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aggregate-level siyumim',
      one: '1 aggregate-level siyum',
    );
    return '$_temp0';
  }

  @override
  String siyumimLevelUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unit-level siyumim',
      one: '1 unit-level siyum',
    );
    return '$_temp0';
  }

  @override
  String get siyumimEmptyState => 'No siyumim yet — keep learning!';

  @override
  String siyumimAggregateSubtitle(int count, String date) {
    return 'All $count complete · $date';
  }

  @override
  String get paceLiveLearningOnlyCaption => 'Pace tracks track learning only.';

  @override
  String bulkMarkWizardSubtitle(String siyumimTerm) {
    return 'These count toward $siyumimTerm and lifetime knowledge — but not toward your streak or points.';
  }

  @override
  String bulkMarkConfirmationToast(int count) {
    return '$count items marked as previously learned. They\'ll appear in Lifetime Knowledge and may unlock siyumim.';
  }

  @override
  String get lifetimeMarkingSubtitle =>
      'Items you\'ve learned in your life, outside the app\'s tracks. Counted toward Lifetime Knowledge — not toward siyumim, streak, or points.';

  @override
  String get recentActivityLiveOnlyDisclaimer =>
      'Counts track learning (live + bulk-mark). Lifetime-only imports appear under Lifetime Knowledge.';

  @override
  String get lifetimeKnowledgeLoading => 'Loading lifetime knowledge…';

  @override
  String lifetimeKnowledgeLoadError(String error) {
    return 'Failed to load: $error';
  }

  @override
  String lifetimeKnowledgeCounterError(String error) {
    return 'Failed to load counters: $error';
  }

  @override
  String get lifetimeKnowledgeRetry => 'Retry';

  @override
  String get lifetimeKnowledgeToggleAllSources => 'All sources';

  @override
  String get lifetimeKnowledgeToggleTrackOnly => 'Track learning only';

  @override
  String get lifetimeKnowledgeAddCta => 'Add items I learned previously';

  @override
  String get lifetimeKnowledgeAddCtaSubtitle =>
      'Lifetime Marking — counts toward Lifetime Knowledge.';

  @override
  String get provenanceLive => 'Live';

  @override
  String provenanceLiveChazaros(int count) {
    return 'Live · $count chazaros';
  }

  @override
  String get provenanceBulkMarked => 'Bulk-marked';

  @override
  String get provenanceLifetimeImported => 'Lifetime · imported';

  @override
  String get trackInfoStarted => 'Started';

  @override
  String get trackInfoGoal => 'Goal';

  @override
  String get trackInfoRequiredPace => 'Required pace';

  @override
  String get trackInfoActualPace => 'Actual pace';

  @override
  String get trackInfoActualPaceCaption => 'Last 7 days · track learning only';

  @override
  String get trackInfoItemsPerDay => 'items/day';

  @override
  String get trackInfoDafPerDay => 'daf/day';

  @override
  String get trackInfoElapsed => 'Elapsed';

  @override
  String get trackInfoRemaining => 'Remaining';

  @override
  String get trackInfoDays => 'days';

  @override
  String trackInfoDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get allTimeActivityTitle => 'All-time activity';

  @override
  String get allTimeActiveDays => 'Active days';

  @override
  String allTimeTermDone(String term) {
    return '$term done';
  }

  @override
  String allTimeTermDoneHebrew(String term) {
    return '$term שנלמד';
  }

  @override
  String recentActivityActiveDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Active days',
      one: '1 Active day',
    );
    return '$_temp0';
  }

  @override
  String get recentActivityEmptyState =>
      'No learning activity in this range yet.';

  @override
  String get monthlyActivityCalendarNoData => 'No activity data';

  @override
  String monthlyActivityCalendarMonthHeader(String month, int activeDays) {
    String _temp0 = intl.Intl.pluralLogic(
      activeDays,
      locale: localeName,
      other: '$activeDays active days',
      one: '1 active day',
    );
    return '$month  —  $_temp0';
  }

  @override
  String monthlyActivityCalendarCompletionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completions',
      one: '1 completion',
    );
    return '$_temp0';
  }

  @override
  String get redeemScreenTitle => 'Redeem Prizes';

  @override
  String get redeemScreenBalance => 'Your Balance';

  @override
  String get redeemScreenNoRewards =>
      'No prizes configured yet.\nAsk a parent to set some up!';

  @override
  String redeemScreenCostLabel(int points) {
    return '$points Points';
  }

  @override
  String get redeemScreenAffordableLabel => 'Redeem';

  @override
  String get redeemScreenCannotAfford => 'Not enough points';

  @override
  String redeemScreenConfirmTitle(String title) {
    return 'Redeem \"$title\"?';
  }

  @override
  String redeemScreenConfirmBody(int points) {
    return 'This will spend $points points from your balance.';
  }

  @override
  String get redeemScreenConfirmButton => 'Spend & Redeem';

  @override
  String redeemScreenRequestedSnackbar(String title) {
    return '\"$title\" requested! Ask a parent to approve it.';
  }

  @override
  String get redeemScreenInsufficientSnackbar =>
      'Not enough points to redeem this prize.';

  @override
  String get redeemScreenTutorUnavailable => 'Not available (tutor mode)';

  @override
  String get pendingRedemptionsTitle => 'Pending Prizes';

  @override
  String get pendingRedemptionsEmptyTitle => 'No prize requests yet';

  @override
  String get pendingRedemptionsEmpty => 'No pending prize requests.';

  @override
  String pendingRedemptionsCountSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prize requests waiting',
      one: '1 prize request waiting',
    );
    return '$_temp0';
  }

  @override
  String pendingRedemptionsCost(int points) {
    return '$points points';
  }

  @override
  String get pendingRedemptionsApprove => 'Fulfil';

  @override
  String get pendingRedemptionsDecline => 'Decline';

  @override
  String get pendingRedemptionsFulfilledSnackbar =>
      'Prize marked as fulfilled!';

  @override
  String get pendingRedemptionsDeclinedSnackbar =>
      'Prize request declined. Points refunded.';

  @override
  String get parentPointsAdjustTitle => 'Adjust Points';

  @override
  String get parentPointsAdjustSubtitle =>
      'Add or deduct points from your child’s balance.';

  @override
  String get parentPointsAdjustAddLabel => 'Add points';

  @override
  String get parentPointsAdjustDeductLabel => 'Deduct points';

  @override
  String get parentPointsAdjustAmountHint => 'Amount';

  @override
  String get parentPointsAdjustNoteHint => 'Reason (optional)';

  @override
  String get parentPointsAdjustConfirm => 'Apply';

  @override
  String get parentPointsAdjustAppliedSnackbar => 'Balance updated.';

  @override
  String parentPointsAdjustCurrentBalance(int count) {
    return 'Current balance: $count pts';
  }

  @override
  String get profileTypeChild => 'Child';

  @override
  String get profileTypeAdult => 'Adult';

  @override
  String get childMode => 'Child mode';

  @override
  String get adultMode => 'Adult mode';

  @override
  String get statusActive => 'Active';

  @override
  String get statusPending => 'Pending';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionGoToDashboard => 'Go to dashboard';

  @override
  String get emptyLoginTutorEntry => 'I\'m a tutor';

  @override
  String get switchAccount => 'Switch account';

  @override
  String get emptyLoginTutorComingSoon =>
      'Tutor access coming soon. Ask the parent to share an invite link with you.';

  @override
  String get tutorWelcomeBannerTitle => 'Welcome, tutor!';

  @override
  String get tutorWelcomeBannerBody =>
      'Ask the parent to share an invite link with you, then tap below to accept it.';

  @override
  String get switcherSheetProfiles => 'Profiles';

  @override
  String get switcherSheetAccounts => 'Accounts';

  @override
  String get switcherSheetAddAccount => 'Add account';

  @override
  String get addAnotherAccountSubtitle =>
      'Sign in to or create another account on this device';

  @override
  String get acceptInviteAppBarTitle => 'Accept Tutor Invite';

  @override
  String get acceptInviteAccepting => 'Accepting invite…';

  @override
  String get acceptInviteHeading => 'Accept tutor invite';

  @override
  String get acceptInviteBody =>
      'You have been invited to tutor a child. By accepting, you will have access to view and manage their learning profile.';

  @override
  String acceptInviteBodyFromParentForChild(
    String parentLabel,
    String childLabel,
  ) {
    return '$parentLabel has invited you to tutor $childLabel. By accepting, you will have access to view and manage their learning profile.';
  }

  @override
  String get acceptInvitePermissionViewData =>
      'View all learning data and progress';

  @override
  String get acceptInvitePermissionConfigure =>
      'Configure tracks, points, and rewards (if permitted)';

  @override
  String get acceptInvitePermissionBulkMark => 'Perform bulk-mark corrections';

  @override
  String get acceptInvitePermissionNoLive =>
      'Cannot mark live completions (streak / rewards)';

  @override
  String get acceptInviteAccept => 'Accept invite';

  @override
  String get acceptInviteDecline => 'Decline';

  @override
  String get acceptInviteSuccessHeading => 'Invite accepted!';

  @override
  String get acceptInviteSuccessBody =>
      'You now have tutor access to this child\'s learning profile. Open the Profile Picker to switch to the tutored profile.';

  @override
  String get acceptInviteErrorHeading => 'Could not accept invite';

  @override
  String get acceptInviteGenericError =>
      'Unable to accept invite. Please try again.';

  @override
  String get acceptInvitePreconditionError =>
      'This invite can no longer be accepted. It may have expired or already been used.';

  @override
  String get unexpectedError => 'An unexpected error occurred.';

  @override
  String get declineInviteAppBarTitle => 'Decline Invite';

  @override
  String get declineInviteConfirmHeading => 'Decline tutor invite?';

  @override
  String get declineInviteConfirmBody =>
      'You are about to decline this tutor invite. The parent will be notified that you declined. You will not have access to this child\'s learning profile.';

  @override
  String get declineInviteConfirm => 'Decline invite';

  @override
  String get declineInviteInProgress => 'Declining invite…';

  @override
  String get declineInviteSuccessHeading => 'Invite declined';

  @override
  String get declineInviteSuccessBody =>
      'You have declined this tutor invite. The parent has been notified.';

  @override
  String get declineInviteErrorHeading => 'Could not decline invite';

  @override
  String get declineInviteGenericError =>
      'Unable to decline invite. Please try again.';

  @override
  String get declineInvitePreconditionError =>
      'This invite can no longer be declined. It may have expired or already been used.';

  @override
  String get inviteTutorAppBarTitle => 'Invite a Tutor';

  @override
  String get inviteTutorHeading => 'Invite a Tutor';

  @override
  String get inviteTutorBody =>
      'Enter the tutor\'s email address. They will receive an invite link to accept access to this child\'s learning profile.';

  @override
  String get inviteTutorEmailLabel => 'Tutor\'s email address';

  @override
  String get inviteTutorEmailHint => 'tutor@example.com';

  @override
  String get inviteTutorInvalidEmail => 'Please enter a valid email address.';

  @override
  String get inviteTutorSending => 'Sending…';

  @override
  String get inviteTutorSend => 'Send invite';

  @override
  String inviteTutorSentSnackbar(String email) {
    return 'Invite sent to $email!';
  }

  @override
  String get inviteTutorErrorLocalOnly =>
      'Tutoring requires a cloud account — upgrade to invite a tutor.';

  @override
  String get inviteTutorErrorUnauthenticated =>
      'Couldn\'t send the invitation. Please sign in and try again.';

  @override
  String get inviteTutorErrorGeneric =>
      'Couldn\'t send the invitation. Please try again.';

  @override
  String get manageGrantsAppBarTitle => 'My Tutoring Grants';

  @override
  String manageGrantsActiveSection(int count) {
    return 'Active ($count)';
  }

  @override
  String manageGrantsPendingSection(int count) {
    return 'Pending invites ($count)';
  }

  @override
  String get manageGrantsEmptyHeading => 'No tutoring relationships';

  @override
  String get manageGrantsEmptyBody =>
      'When a parent invites you to tutor their child, the grant will appear here.';

  @override
  String get manageGrantsResignTitle => 'Resign from tutoring?';

  @override
  String manageGrantsResignBody(String child, String parent) {
    return 'You will immediately lose access to this child\'s profile. The parent will be notified.\n\nChild: $child\nParent: $parent';
  }

  @override
  String get manageGrantsResign => 'Resign';

  @override
  String get manageGrantsResignErrorGeneric =>
      'Could not resign. Please try again.';

  @override
  String get tutorFallbackName => 'Your tutor';

  @override
  String get manageTutorsEmptyHeading => 'No children profiles yet';

  @override
  String get manageTutorsEmptyBody =>
      'Add a child profile to start inviting tutors.';

  @override
  String get manageTutorsLoadErrorGeneric =>
      'Could not load tutors. Please try again.';

  @override
  String get manageTutorsNoTutors => 'No tutors invited.';

  @override
  String manageTutorsActiveSection(int count) {
    return 'Active ($count)';
  }

  @override
  String manageTutorsPendingSection(int count) {
    return 'Pending ($count)';
  }

  @override
  String get manageTutorsInviteButton => 'Invite a tutor';

  @override
  String get manageTutorsRevokeTitle => 'Revoke tutor access?';

  @override
  String manageTutorsRevokeBody(String email) {
    return '$email will immediately lose access to this child\'s profile.';
  }

  @override
  String get manageTutorsRevoke => 'Revoke';

  @override
  String get manageTutorsRevokeErrorGeneric =>
      'Could not revoke. Please try again.';

  @override
  String get manageTutorsRescindTitle => 'Rescind invitation?';

  @override
  String manageTutorsRescindBody(String email) {
    return 'The pending invite to $email will be cancelled.';
  }

  @override
  String get manageTutorsRescind => 'Rescind';

  @override
  String get manageTutorsRescindErrorGeneric =>
      'Could not rescind. Please try again.';

  @override
  String get manageTutorsViewAuditLog => 'View audit log';

  @override
  String get tutorFallbackParent => 'Parent';

  @override
  String get auditLogTitle => 'Audit Log';

  @override
  String get auditLogClearFilters => 'Clear filters';

  @override
  String get auditLogFilterFromDate => 'Filter from date';

  @override
  String get auditLogFilterToDate => 'Filter to date';

  @override
  String get auditLogFilterFrom => 'From';

  @override
  String get auditLogFilterTo => 'To';

  @override
  String get auditLogEmptyFiltered => 'No entries match the filters';

  @override
  String get auditLogEmpty => 'No audit entries';

  @override
  String get auditLogEmptyFilteredBody => 'Clear filters to see all entries.';

  @override
  String get auditLogEmptyBody =>
      'Tutor actions will appear here as they occur.';

  @override
  String get auditLogChipConfig => 'Config';

  @override
  String get auditLogChipBulkPrior => 'Bulk Prior';

  @override
  String get auditLogChipReset => 'Reset';

  @override
  String get auditLogChipBookmark => 'Bookmark';

  @override
  String get auditLogChipProfile => 'Profile';

  @override
  String get auditLogChipGoal => 'Goal';

  @override
  String get auditLogChipStage => 'Stage';

  @override
  String get auditLogChipReward => 'Reward';

  @override
  String get auditLogChipStudyDay => 'Study Day';

  @override
  String get auditLogActionConfigChanged => 'Config changed';

  @override
  String get auditLogActionBulkPrior => 'Bulk prior';

  @override
  String get auditLogActionReset => 'Reset';

  @override
  String get auditLogActionBookmark => 'Bookmark';

  @override
  String get auditLogActionProfileEdited => 'Profile edited';

  @override
  String get auditLogActionGoalChanged => 'Goal changed';

  @override
  String get auditLogActionStageChanged => 'Stage changed';

  @override
  String get auditLogActionRewardChanged => 'Reward changed';

  @override
  String get auditLogActionStudyDay => 'Study day';

  @override
  String get auditLogBefore => 'before: ';

  @override
  String get auditLogAfter => 'after: ';

  @override
  String get tutorPinAppBarTitle => 'Tutor PIN';

  @override
  String get tutorPinEntryHeading => 'Enter your Tutor PIN';

  @override
  String get tutorPinEntryBody =>
      'Enter your 4-digit Tutor PIN to access this profile.';

  @override
  String get tutorPinForgot => 'Forgot your Tutor PIN?';

  @override
  String get tutorPinIncorrect => 'Incorrect PIN. Please try again.';

  @override
  String get tutorPinValidationMalformed =>
      'Your Tutor PIN must be exactly 4 numeric digits.';

  @override
  String tutorPinLockedOut(int minutes) {
    return 'Too many attempts. Locked for $minutes minute(s).';
  }

  @override
  String get parentPinLockoutTitle => 'Too many failed attempts';

  @override
  String parentPinLockoutBody(int minutes) {
    return 'Try again in $minutes minute(s)';
  }

  @override
  String tutorPinErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get tutorPinSetupAppBarTitle => 'Set Tutor PIN';

  @override
  String get tutorPinSetupConfirmHeading => 'Confirm your Tutor PIN';

  @override
  String get tutorPinSetupCreateHeading => 'Create your Tutor PIN';

  @override
  String get tutorPinSetupConfirmBody =>
      'Re-enter the same 4-digit PIN to confirm.';

  @override
  String get tutorPinSetupCreateBody =>
      'Your Tutor PIN protects access to every child profile you tutor. Enter a 4-digit PIN.';

  @override
  String get tutorPinSetupConfirmLabel => 'Confirm PIN';

  @override
  String get tutorPinSetupEnterNewLabel => 'Enter New PIN';

  @override
  String get tutorPinSetupMismatch => 'PINs do not match. Please try again.';

  @override
  String get tutorPinSetupSaveError => 'Unable to save PIN. Please try again.';

  @override
  String get tutorPinSetupLater => 'Set up later';

  @override
  String get tutorPinResetAppBarTitle => 'Reset Tutor PIN';

  @override
  String get tutorPinResetHeading => 'Reset your Tutor PIN';

  @override
  String get tutorPinResetSendingTo => 'We will send a reset link to:';

  @override
  String get tutorPinResetReturnHint =>
      'After following the link, return here to create a new PIN.';

  @override
  String get tutorPinResetNoEmail =>
      'No email address found for your account. Please sign in with a cloud account to use PIN reset.';

  @override
  String get tutorPinResetSendFailed =>
      'Failed to send reset email. Please try again.';

  @override
  String get tutorPinResetFallbackEmail => 'your account email';

  @override
  String get tutorPinResetSendButton => 'Send reset email';

  @override
  String get tutorPinResetCheckEmailHeading => 'Check your email';

  @override
  String tutorPinResetCheckEmailBody(String email) {
    return 'We sent a reset link to $email. Follow the link, then return here to set a new PIN.';
  }

  @override
  String get tutorPinResetSetNew => 'Set new PIN';

  @override
  String get settingsAppPermissions => 'App Permissions';

  @override
  String get settingsAppPermissionsSubtitle =>
      'Notifications and location access';

  @override
  String get settingsSendDiagnosticLogs => 'Send Diagnostic Logs';

  @override
  String get settingsSendDiagnosticLogsSubtitle =>
      'Stream last 10 min of activity to Firebase';

  @override
  String get settingsPronunciation => 'Pronunciation';

  @override
  String get settingsPronunciationSubtitle =>
      'Bereishis (Ashkenazi) or Bereshit (Sephardi)';

  @override
  String get settingsPronunciationAshkenazi => 'Ashkenazi';

  @override
  String get settingsPronunciationSephardi => 'Sephardi';

  @override
  String get settingsNikud => 'Nikud';

  @override
  String get settingsNikudSubtitle =>
      'Show or hide Hebrew vowel marks when learning.';

  @override
  String get settingsNikudWithout => 'Without nikud';

  @override
  String get settingsNikudWith => 'With nikud';

  @override
  String get deviceNotificationsTitle => 'Device notifications';

  @override
  String get deviceNotificationsChecking => 'Checking permission…';

  @override
  String get deviceNotificationsAllowed =>
      'Notifications allowed on this device';

  @override
  String get deviceNotificationsBlocked =>
      'Notifications blocked — tap to open Settings';

  @override
  String get deviceNotificationsDisableHint =>
      'To disable notifications, go to Settings > Apps > Learning Tracker.';

  @override
  String get deviceNotificationsBlockedHint =>
      'Notifications blocked. Enable them in Settings > Apps > Learning Tracker > Notifications.';

  @override
  String get notificationReminderGenericBody =>
      'Time to learn! Open the app to see your tasks.';

  @override
  String get notificationStreakTitle => 'Streak at Risk!';

  @override
  String notificationStreakBody(int currentStreak) {
    return 'Your $currentStreak-day streak is at risk!';
  }

  @override
  String get onboardingNamePrompt => 'What should we call you?';

  @override
  String get onboardingLearningExperience => 'Learning Experience';

  @override
  String get onboardingCalendarLabel => 'Calendar';

  @override
  String get onboardingSettingsChangeableLater =>
      'You can change these settings anytime later.';

  @override
  String get onboardingIntentHeading => 'What brings you here?';

  @override
  String get onboardingIntentSubtitle => 'Choose how you want to get started.';

  @override
  String get onboardingIntentTrackTitle => 'Track my own learning';

  @override
  String get onboardingIntentTrackSubtitle =>
      'Set up a curriculum, goals, and daily schedule.';

  @override
  String get onboardingIntentSkipTitle => 'Skip for now';

  @override
  String get onboardingIntentSkipSubtitle =>
      'Go to the app and decide later. You can set up a track or accept an invite any time.';

  @override
  String get permissionPromptTitleOnboarding => 'Almost Done!';

  @override
  String permissionPromptBodyOnboarding(String shabbos) {
    return 'Allow these optional permissions so Learning Tracker can remind you to learn and compute $shabbos times for your location.';
  }

  @override
  String permissionPromptBodySettings(String shabbos) {
    return 'Manage optional permissions for reminders and $shabbos-time calculations.';
  }

  @override
  String get permissionPromptNotifSubtitle =>
      'Daily learning reminders and streak-protection alerts.';

  @override
  String get permissionPromptLocationTitle => 'Location';

  @override
  String permissionPromptLocationSubtitle(String shabbos, String havdalah) {
    return 'Accurate $shabbos candle-lighting and $havdalah times based on your city.';
  }

  @override
  String get permissionPromptCtaDone => 'Done';

  @override
  String get permissionPromptAllowButton => 'Allow';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selections',
      one: '$count selection',
    );
    return '$_temp0';
  }

  @override
  String chazaraDayUnitLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Days',
      one: 'Day',
    );
    return '$_temp0';
  }

  @override
  String scopeChooseLevelPrompt(String levelLabel) {
    return 'Choose a $levelLabel';
  }

  @override
  String schedulerStudyDaysScreenTitle(String curriculum) {
    return '$curriculum • Study Days';
  }

  @override
  String trackReorderScreenTitle(String curriculum) {
    return '$curriculum • Reorder';
  }

  @override
  String learningOrderScreenTitle(String curriculum) {
    return '$curriculum Order';
  }

  @override
  String bulkMarkScreenTitle(String curriculum) {
    return 'Mark Prior Completions — $curriculum';
  }

  @override
  String get bulkMarkSelectHeading =>
      'Select content you\'ve already completed';

  @override
  String get schedulerStudyDaysIntro =>
      'Choose which days include new learning and which are for review only.';

  @override
  String get schedulerStudyDaysAllStudyDays =>
      'All days are study days for this track.';

  @override
  String schedulerStudyDaysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count study days per week',
      one: '1 study day per week',
    );
    return '$_temp0';
  }

  @override
  String get schedulerStudyDaysZeroWarning =>
      'No study days selected — every day is review only and no new learning will be scheduled.';

  @override
  String get schedulerDayAbbrevSun => 'Sun';

  @override
  String get schedulerDayAbbrevMon => 'Mon';

  @override
  String get schedulerDayAbbrevTue => 'Tue';

  @override
  String get schedulerDayAbbrevWed => 'Wed';

  @override
  String get schedulerDayAbbrevThu => 'Thu';

  @override
  String get schedulerDayAbbrevFri => 'Fri';

  @override
  String get trackEditNameRequired => 'Enter a track name';

  @override
  String trackEditReviewSummaryWithDays(String delays, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return 'After $delays $_temp0';
  }

  @override
  String get goalClearDeadlineTooltip => 'Clear deadline date';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get programDescriptionOraysa =>
      'Structured learning with daily study, next-day review, weekly review, and rolling back-20 review cycle.';

  @override
  String get programDescriptionDirshuKinyanTorah =>
      'Daf Yomi pace with 3 chazarah review cycles and monthly tests.';

  @override
  String get programDescriptionDirshuAmudHaYomi =>
      'Half-daf daily pace with review cycles and monthly tests.';

  @override
  String get programDescriptionDirshuKinyanYerushalmi =>
      'Yerushalmi study with review cycles and monthly tests.';

  @override
  String get programDescriptionDafYomi =>
      'One daf per day, no built-in review.';

  @override
  String get programDescriptionMishnayYomis =>
      'Two mishnayos per day, no built-in review.';

  @override
  String get programDescriptionNachYomi =>
      'One chapter per day, no built-in review.';

  @override
  String get programDescriptionYerushalmiYomi =>
      'One daf of Talmud Yerushalmi per day.';

  @override
  String get programDescriptionRambam1Chapter =>
      'One chapter of Mishneh Torah per day.';

  @override
  String get programDescriptionRambam3Chapters =>
      'Three chapters of Mishneh Torah per day.';

  @override
  String get programDescriptionDafAWeek => 'One daf of Talmud Bavli per week.';

  @override
  String get programDescriptionHalakhahYomit =>
      'Daily halacha study following the Shulchan Aruch cycle.';

  @override
  String get programDescriptionArukhHashulchanYomi =>
      'Daily study of the Arukh HaShulchan.';

  @override
  String get programDescriptionTanakhYomi => 'Daily Tanakh study cycle.';

  @override
  String get programDescriptionChofetzChaimDaily =>
      'Daily study of the Chofetz Chaim on Shmirat HaLashon.';

  @override
  String get programDescriptionKitzurShulchanAruchYomi =>
      'Daily study of the Kitzur Shulchan Aruch.';

  @override
  String get programDescriptionTehillimYomi => 'Daily Psalms cycle.';

  @override
  String get programDescriptionPerekYomi => 'One Mishnah perek per day.';

  @override
  String get programDescriptionSeferHaMitzvot =>
      'Daily study of the Rambam\'s Sefer HaMitzvot.';

  @override
  String get programDescriptionShemiratHaLashon =>
      'Daily study of the Chofetz Chaim\'s Shemirat HaLashon (companion to Chofetz Chaim Yomi).';

  @override
  String get programDescriptionPirkeiAvotSummer =>
      'One perek of Pirkei Avot each Shabbos between Pesach and Rosh Hashana.';

  @override
  String get onboardingSetUpTrackTitle => 'Set Up a Track';

  @override
  String get onboardingTrackReadyTitle => 'Track Ready!';

  @override
  String get onboardingAllSetTitle => 'All Set!';

  @override
  String onboardingTrackReadyMessage(String trackLabel) {
    return 'Your track \"$trackLabel\" is ready!';
  }

  @override
  String onboardingTrackCountSetUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count tracks set up.',
      one: 'You have 1 track set up.',
    );
    return '$_temp0';
  }

  @override
  String get onboardingHandoffFallbackName => 'Your child';

  @override
  String onboardingHandoffAllSetUp(String name) {
    return '$name\'s learning is all set up';
  }

  @override
  String onboardingHandoffDeviceHint(String name) {
    return 'Hand the device to $name to start learning';
  }

  @override
  String get onboardingHandoffRewardsHint =>
      'You can set up rewards later in Parent Mode';

  @override
  String get onboardingParentPinFallbackChildName => 'your child';

  @override
  String get onboardingPinReenterSubtitle => 'Re-enter the PIN to confirm';

  @override
  String get bulkMarkCannotUnmarkAllError =>
      'You must leave at least some content unmarked to continue learning.';

  @override
  String get bulkMarkSearchHint => 'Search content...';

  @override
  String bulkMarkCompletionRecordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completion records will be created',
      one: '1 completion record will be created',
    );
    return '$_temp0';
  }

  @override
  String wizardHowDoesChildReview(String childName) {
    return 'How does $childName review?';
  }

  @override
  String get wizardHowDoYouReview => 'How do you review?';

  @override
  String get wizardFollowProgramTitle => 'Follow a program';

  @override
  String wizardProgramsAvailableCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count programs available',
      one: '1 program available',
    );
    return '$_temp0';
  }

  @override
  String get wizardCustomScheduleSubtitle => 'Build your own review cycle';

  @override
  String get wizardNoFormalReviewTitle => 'No formal review';

  @override
  String get wizardNoFormalReviewSubtitle => 'Just track learning progress';

  @override
  String wizardWhatProgramDoesChildFollow(String childName) {
    return 'What program does $childName follow?';
  }

  @override
  String get wizardSelectAProgram => 'Select a program';

  @override
  String get wizardHowManyReviewRounds => 'How many review rounds?';

  @override
  String get wizardEachRoundIntervalsSubtitle =>
      'Each round reviews the material at increasing intervals';

  @override
  String wizardChazarahRoundsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String get wizardSetDelayForEachRound => 'Set delay for each round';

  @override
  String get wizardHowLongBeforeReview =>
      'How long after learning before each review?';

  @override
  String get wizardReviewYourSchedule => 'Review your schedule';

  @override
  String get wizardDailyNewMaterial => 'Daily new material';

  @override
  String wizardEveryDaysLabel(String days) {
    return 'Every $days';
  }

  @override
  String wizardRoundDelayAfterLearning(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days after learning',
      one: '1 day after learning',
    );
    return '$_temp0';
  }

  @override
  String wizardRoundDelayAfter(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days after',
      one: '1 day after',
    );
    return '$_temp0';
  }
}
