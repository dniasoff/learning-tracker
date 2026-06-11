import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Torah Learning Tracker'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @learn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get learn;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get streak;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get done;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'POINTS'**
  String get points;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'PAGES'**
  String get pages;

  /// No description provided for @todaysLearning.
  ///
  /// In en, this message translates to:
  /// **'Today\'s learning ({count})'**
  String todaysLearning(int count);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String remaining(int count);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get allCaughtUp;

  /// No description provided for @noTasksRemaining.
  ///
  /// In en, this message translates to:
  /// **'No tasks remaining for today.'**
  String get noTasksRemaining;

  /// No description provided for @activeCurricula.
  ///
  /// In en, this message translates to:
  /// **'Active Curricula'**
  String get activeCurricula;

  /// No description provided for @activeTracks.
  ///
  /// In en, this message translates to:
  /// **'Active tracks'**
  String get activeTracks;

  /// No description provided for @activeTracksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep up the great work on your learning goals'**
  String get activeTracksSubtitle;

  /// No description provided for @activeTrackNextTask.
  ///
  /// In en, this message translates to:
  /// **'NEXT TASK'**
  String get activeTrackNextTask;

  /// No description provided for @activeTrackCurrentFocus.
  ///
  /// In en, this message translates to:
  /// **'CURRENT FOCUS'**
  String get activeTrackCurrentFocus;

  /// No description provided for @activeTrackPaceAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead {days}d'**
  String activeTrackPaceAhead(int days);

  /// No description provided for @activeTrackPaceBehind.
  ///
  /// In en, this message translates to:
  /// **'Behind {days}d'**
  String activeTrackPaceBehind(int days);

  /// No description provided for @activeTrackPaceOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get activeTrackPaceOk;

  /// No description provided for @activeTrackMetricChazara.
  ///
  /// In en, this message translates to:
  /// **'CHAZARA'**
  String get activeTrackMetricChazara;

  /// No description provided for @activeTrackMetricDueToday.
  ///
  /// In en, this message translates to:
  /// **'DUE TODAY'**
  String get activeTrackMetricDueToday;

  /// No description provided for @activeTrackMetricOverdue.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get activeTrackMetricOverdue;

  /// No description provided for @trackCurrentCycle.
  ///
  /// In en, this message translates to:
  /// **'Since reactivation'**
  String get trackCurrentCycle;

  /// No description provided for @continueLearning.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearning;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @myLearningJourney.
  ///
  /// In en, this message translates to:
  /// **'My Learning Journey'**
  String get myLearningJourney;

  /// No description provided for @myLearningJourneySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you\'ve learned, in order'**
  String get myLearningJourneySubtitle;

  /// No description provided for @seeLifetimeAchievements.
  ///
  /// In en, this message translates to:
  /// **'See your lifetime achievements'**
  String get seeLifetimeAchievements;

  /// No description provided for @dailyProgress.
  ///
  /// In en, this message translates to:
  /// **'DAILY PROGRESS'**
  String get dailyProgress;

  /// No description provided for @studyDay.
  ///
  /// In en, this message translates to:
  /// **'Study Day'**
  String get studyDay;

  /// No description provided for @reviewDay.
  ///
  /// In en, this message translates to:
  /// **'Review Day'**
  String get reviewDay;

  /// No description provided for @mixedDay.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get mixedDay;

  /// No description provided for @restDay.
  ///
  /// In en, this message translates to:
  /// **'Rest Day'**
  String get restDay;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @moreTasks.
  ///
  /// In en, this message translates to:
  /// **'{count} more tasks...'**
  String moreTasks(int count);

  /// No description provided for @streakRecovery.
  ///
  /// In en, this message translates to:
  /// **'You missed 1 day but your {count}-day streak is safe!'**
  String streakRecovery(int count);

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @activityCalendar.
  ///
  /// In en, this message translates to:
  /// **'Activity Calendar'**
  String get activityCalendar;

  /// No description provided for @nextReward.
  ///
  /// In en, this message translates to:
  /// **'Next Reward'**
  String get nextReward;

  /// No description provided for @earnedRewards.
  ///
  /// In en, this message translates to:
  /// **'Earned Rewards'**
  String get earnedRewards;

  /// No description provided for @noRewardsYet.
  ///
  /// In en, this message translates to:
  /// **'No rewards earned yet. Keep learning!'**
  String get noRewardsYet;

  /// No description provided for @mysteryReward.
  ///
  /// In en, this message translates to:
  /// **'Mystery Reward!'**
  String get mysteryReward;

  /// No description provided for @totalPoints.
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPoints;

  /// No description provided for @dashboardRewardsGallery.
  ///
  /// In en, this message translates to:
  /// **'Rewards Gallery'**
  String get dashboardRewardsGallery;

  /// No description provided for @dashboardChildPointsTab.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get dashboardChildPointsTab;

  /// No description provided for @dashboardSeeAllRewards.
  ///
  /// In en, this message translates to:
  /// **'SEE ALL'**
  String get dashboardSeeAllRewards;

  /// No description provided for @dashboardMysteryChest.
  ///
  /// In en, this message translates to:
  /// **'Mystery Chest'**
  String get dashboardMysteryChest;

  /// No description provided for @dashboardCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'CURRENT BALANCE'**
  String get dashboardCurrentBalance;

  /// No description provided for @dashboardNextRewardWithName.
  ///
  /// In en, this message translates to:
  /// **'Next Reward: {name}'**
  String dashboardNextRewardWithName(String name);

  /// No description provided for @dashboardPtsToGo.
  ///
  /// In en, this message translates to:
  /// **'{count} pts to go!'**
  String dashboardPtsToGo(String count);

  /// No description provided for @dashboardRedeemPrizes.
  ///
  /// In en, this message translates to:
  /// **'Redeem Prizes'**
  String get dashboardRedeemPrizes;

  /// No description provided for @dashboardTapToUnlockAtPts.
  ///
  /// In en, this message translates to:
  /// **'TAP TO UNLOCK AT {points} PTS'**
  String dashboardTapToUnlockAtPts(String points);

  /// No description provided for @dashboardPointsValue.
  ///
  /// In en, this message translates to:
  /// **'{count} Points'**
  String dashboardPointsValue(String count);

  /// No description provided for @dashboardBubbleDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get dashboardBubbleDone;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'complete'**
  String get complete;

  /// No description provided for @gamification.
  ///
  /// In en, this message translates to:
  /// **'Gamification'**
  String get gamification;

  /// No description provided for @myAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Achievements'**
  String get myAchievementsTitle;

  /// No description provided for @achievementsYourProgress.
  ///
  /// In en, this message translates to:
  /// **'YOUR PROGRESS'**
  String get achievementsYourProgress;

  /// No description provided for @achievementsRewardsCount.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} / {total} Rewards'**
  String achievementsRewardsCount(int unlocked, int total);

  /// No description provided for @achievementsAcrossAllTracks.
  ///
  /// In en, this message translates to:
  /// **'Across all your tracks.'**
  String get achievementsAcrossAllTracks;

  /// No description provided for @achievementsEncouragement.
  ///
  /// In en, this message translates to:
  /// **'Keep it up, you\'re doing great!'**
  String get achievementsEncouragement;

  /// No description provided for @achievementsRewardsFraction.
  ///
  /// In en, this message translates to:
  /// **'{unlocked} / {total}'**
  String achievementsRewardsFraction(int unlocked, int total);

  /// No description provided for @achievementsRewardsLabelWord.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get achievementsRewardsLabelWord;

  /// No description provided for @achievementsMilestonePoints.
  ///
  /// In en, this message translates to:
  /// **'{points} PTS'**
  String achievementsMilestonePoints(String points);

  /// No description provided for @achievementsProgressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String achievementsProgressPercent(int percent);

  /// No description provided for @achievementsTrackSection.
  ///
  /// In en, this message translates to:
  /// **'TRACK SELECTION'**
  String get achievementsTrackSection;

  /// No description provided for @achievementsAllTracks.
  ///
  /// In en, this message translates to:
  /// **'All Tracks'**
  String get achievementsAllTracks;

  /// No description provided for @achievementsGlobalRewardsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total points'**
  String get achievementsGlobalRewardsLabel;

  /// No description provided for @achievementsStatusUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked!'**
  String get achievementsStatusUnlocked;

  /// No description provided for @achievementsStatusComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon!'**
  String get achievementsStatusComingSoon;

  /// No description provided for @achievementsStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get achievementsStatusLocked;

  /// No description provided for @achievementsLockedBlurHint.
  ///
  /// In en, this message translates to:
  /// **'Reach {points} points to unlock'**
  String achievementsLockedBlurHint(String points);

  /// No description provided for @achievementsUnlockedAtPoints.
  ///
  /// In en, this message translates to:
  /// **'Unlocked at {points} points'**
  String achievementsUnlockedAtPoints(String points);

  /// No description provided for @achievementsUltimateGoal.
  ///
  /// In en, this message translates to:
  /// **'The Ultimate Goal.'**
  String get achievementsUltimateGoal;

  /// No description provided for @achievementsProTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Tip!'**
  String get achievementsProTipTitle;

  /// No description provided for @achievementsProTipBody.
  ///
  /// In en, this message translates to:
  /// **'Keep learning on your tracks to climb the reward ladder.'**
  String get achievementsProTipBody;

  /// No description provided for @achievementsActivityAndPoints.
  ///
  /// In en, this message translates to:
  /// **'Activity & points'**
  String get achievementsActivityAndPoints;

  /// No description provided for @achievementsUnlockPartyTitle.
  ///
  /// In en, this message translates to:
  /// **'Wow! Amazing!'**
  String get achievementsUnlockPartyTitle;

  /// No description provided for @achievementsUnlockPartyMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations, {name}! You unlocked {milestone} on your {track} track — keep going!'**
  String achievementsUnlockPartyMessage(
    String name,
    String milestone,
    String track,
  );

  /// No description provided for @achievementsUnlockPartyButton.
  ///
  /// In en, this message translates to:
  /// **'Yay! Let\'s go!'**
  String get achievementsUnlockPartyButton;

  /// No description provided for @achievementsUnlockPartyNameFallback.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get achievementsUnlockPartyNameFallback;

  /// No description provided for @rewardCatalog.
  ///
  /// In en, this message translates to:
  /// **'Reward Catalog'**
  String get rewardCatalog;

  /// No description provided for @noRewardsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No rewards configured yet'**
  String get noRewardsConfigured;

  /// No description provided for @addReward.
  ///
  /// In en, this message translates to:
  /// **'Add Reward'**
  String get addReward;

  /// No description provided for @editReward.
  ///
  /// In en, this message translates to:
  /// **'Edit Reward'**
  String get editReward;

  /// No description provided for @deleteReward.
  ///
  /// In en, this message translates to:
  /// **'Delete Reward'**
  String get deleteReward;

  /// No description provided for @deleteRewardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteRewardConfirm(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @revealed.
  ///
  /// In en, this message translates to:
  /// **'Revealed'**
  String get revealed;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @pointThreshold.
  ///
  /// In en, this message translates to:
  /// **'Point Threshold'**
  String get pointThreshold;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @thresholdRequired.
  ///
  /// In en, this message translates to:
  /// **'Threshold is required'**
  String get thresholdRequired;

  /// No description provided for @mustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be a positive number'**
  String get mustBePositive;

  /// No description provided for @milestoneType.
  ///
  /// In en, this message translates to:
  /// **'Milestone Type'**
  String get milestoneType;

  /// No description provided for @pointsThreshold.
  ///
  /// In en, this message translates to:
  /// **'Points threshold'**
  String get pointsThreshold;

  /// No description provided for @finishMasechta.
  ///
  /// In en, this message translates to:
  /// **'Finish masechta'**
  String get finishMasechta;

  /// No description provided for @finishSeder.
  ///
  /// In en, this message translates to:
  /// **'Finish seder'**
  String get finishSeder;

  /// No description provided for @everyNItems.
  ///
  /// In en, this message translates to:
  /// **'Every N items'**
  String get everyNItems;

  /// No description provided for @visibleToChild.
  ///
  /// In en, this message translates to:
  /// **'Visible to child'**
  String get visibleToChild;

  /// No description provided for @childCanSee.
  ///
  /// In en, this message translates to:
  /// **'Child can see this reward'**
  String get childCanSee;

  /// No description provided for @hiddenUntilEarned.
  ///
  /// In en, this message translates to:
  /// **'Hidden until earned (surprise)'**
  String get hiddenUntilEarned;

  /// No description provided for @onboarding.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboarding;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @ctaGetStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get ctaGetStartedTitle;

  /// No description provided for @ctaGetStartedBody.
  ///
  /// In en, this message translates to:
  /// **'Add a learning track to begin tracking your progress.'**
  String get ctaGetStartedBody;

  /// No description provided for @ctaAddLearningTrack.
  ///
  /// In en, this message translates to:
  /// **'Add a learning track'**
  String get ctaAddLearningTrack;

  /// No description provided for @ctaCreateProfileFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a learner profile first, then add a track.'**
  String get ctaCreateProfileFirst;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @whatsYourName.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get whatsYourName;

  /// No description provided for @adult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get adult;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectCurricula.
  ///
  /// In en, this message translates to:
  /// **'Select Curricula'**
  String get selectCurricula;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @joinCalendarProgram.
  ///
  /// In en, this message translates to:
  /// **'Join a Calendar Program'**
  String get joinCalendarProgram;

  /// No description provided for @joinCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'Follow a daily learning schedule like Daf Yomi'**
  String get joinCalendarDesc;

  /// No description provided for @availablePrograms.
  ///
  /// In en, this message translates to:
  /// **'Available Programs'**
  String get availablePrograms;

  /// No description provided for @todaysAssignment.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Assignment'**
  String get todaysAssignment;

  /// No description provided for @startTrackingFrom.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking From'**
  String get startTrackingFrom;

  /// No description provided for @fromToday.
  ///
  /// In en, this message translates to:
  /// **'From today'**
  String get fromToday;

  /// No description provided for @beginningOfPerek.
  ///
  /// In en, this message translates to:
  /// **'Beginning of current perek'**
  String get beginningOfPerek;

  /// No description provided for @beginningOfMasechta.
  ///
  /// In en, this message translates to:
  /// **'Beginning of current masechta'**
  String get beginningOfMasechta;

  /// No description provided for @specificDaf.
  ///
  /// In en, this message translates to:
  /// **'From a specific daf'**
  String get specificDaf;

  /// No description provided for @setupComplete.
  ///
  /// In en, this message translates to:
  /// **'Setup Complete!'**
  String get setupComplete;

  /// No description provided for @addAnotherLearner.
  ///
  /// In en, this message translates to:
  /// **'Add Another Learner'**
  String get addAnotherLearner;

  /// No description provided for @addAnotherTrack.
  ///
  /// In en, this message translates to:
  /// **'Add Another Track'**
  String get addAnotherTrack;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @allSet.
  ///
  /// In en, this message translates to:
  /// **'All set!'**
  String get allSet;

  /// No description provided for @addYourFirstTrack.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Track'**
  String get addYourFirstTrack;

  /// No description provided for @addTrackButton.
  ///
  /// In en, this message translates to:
  /// **'ADD TRACK'**
  String get addTrackButton;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get switchProfile;

  /// No description provided for @switchProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change to a different profile or your account'**
  String get switchProfileSubtitle;

  /// No description provided for @manageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage Profiles'**
  String get manageProfiles;

  /// No description provided for @manageProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or remove learner profiles'**
  String get manageProfilesSubtitle;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @manageTracks.
  ///
  /// In en, this message translates to:
  /// **'Manage Tracks'**
  String get manageTracks;

  /// AppBar title for the parent track-management screen, reached from both the 'Manage Tracks' and 'Manage Goals' tiles (goals are set per-track here), so the title covers both.
  ///
  /// In en, this message translates to:
  /// **'Tracks & Goals'**
  String get manageTracksAndGoalsTitle;

  /// No description provided for @manageTracksDetail.
  ///
  /// In en, this message translates to:
  /// **'Create and edit your learning tracks'**
  String get manageTracksDetail;

  /// No description provided for @parentManageTracksDetail.
  ///
  /// In en, this message translates to:
  /// **'Create and edit your child\'s learning tracks'**
  String get parentManageTracksDetail;

  /// No description provided for @addTrackGoalTapToUseDeadline.
  ///
  /// In en, this message translates to:
  /// **'Target pace is on — tap here to use a deadline instead'**
  String get addTrackGoalTapToUseDeadline;

  /// No description provided for @addTrackGoalTapToUsePace.
  ///
  /// In en, this message translates to:
  /// **'Deadline is on — tap here to use target pace instead'**
  String get addTrackGoalTapToUsePace;

  /// Title for the optional chazara (review) setup step in the add-track flow. {term} is the localized chazara/review domain term.
  ///
  /// In en, this message translates to:
  /// **'Add {term}?'**
  String addTrackChazaraStepTitle(String term);

  /// Question header for the chazara (review) setup step in the add-track flow. {term} is the localized chazara/review domain term.
  ///
  /// In en, this message translates to:
  /// **'How do you want to {term}?'**
  String addTrackChazaraStepQuestion(String term);

  /// No description provided for @addTrackGoalDeadlinePaceLine.
  ///
  /// In en, this message translates to:
  /// **'About {items} {unit} per study day, across {studyDays, plural, =1{1 study day} other{{studyDays} study days}} to finish the scope by the deadline (≈{totalItems} items).'**
  String addTrackGoalDeadlinePaceLine(
    int items,
    String unit,
    int studyDays,
    int totalItems,
  );

  /// No description provided for @addTrackGoalDeadlineNoStudyDaysInWindow.
  ///
  /// In en, this message translates to:
  /// **'No study day in your week falls in the range to this deadline. Add study days or move the deadline later.'**
  String get addTrackGoalDeadlineNoStudyDaysInWindow;

  /// No description provided for @addTrackGoalDeadlinePaceLineLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading scope size to estimate per study day…'**
  String get addTrackGoalDeadlinePaceLineLoading;

  /// Deadline pace line shown before the scope item count resolves to a positive number — omits the '(≈N items)' parenthetical so we never display '≈0 items'.
  ///
  /// In en, this message translates to:
  /// **'About {items} {unit} per study day, across {studyDays, plural, =1{1 study day} other{{studyDays} study days}} to finish the scope by the deadline.'**
  String addTrackGoalDeadlinePaceLineNoTotal(
    int items,
    String unit,
    int studyDays,
  );

  /// No description provided for @addTrack.
  ///
  /// In en, this message translates to:
  /// **'Add Track'**
  String get addTrack;

  /// No description provided for @addTrackCurriculumReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'You already have a track here. Choosing this curriculum again will replace your current setup and may reset your progress for it.'**
  String get addTrackCurriculumReplaceWarning;

  /// No description provided for @noActiveCurricula.
  ///
  /// In en, this message translates to:
  /// **'No active curricula'**
  String get noActiveCurricula;

  /// No description provided for @errorLoadingCurricula.
  ///
  /// In en, this message translates to:
  /// **'Error loading curricula: {error}'**
  String errorLoadingCurricula(String error);

  /// No description provided for @trackCreated.
  ///
  /// In en, this message translates to:
  /// **'Track \"{label}\" created'**
  String trackCreated(String label);

  /// No description provided for @learner.
  ///
  /// In en, this message translates to:
  /// **'Learner'**
  String get learner;

  /// No description provided for @learningTracker.
  ///
  /// In en, this message translates to:
  /// **'Learning Tracker'**
  String get learningTracker;

  /// No description provided for @searchContent.
  ///
  /// In en, this message translates to:
  /// **'Search content'**
  String get searchContent;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @errorLoadingTasks.
  ///
  /// In en, this message translates to:
  /// **'Error loading tasks: {error}'**
  String errorLoadingTasks(String error);

  /// No description provided for @noActiveTracks.
  ///
  /// In en, this message translates to:
  /// **'No active tracks'**
  String get noActiveTracks;

  /// No description provided for @askGrownUpToAddTrack.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to add a learning track.'**
  String get askGrownUpToAddTrack;

  /// No description provided for @addTrackToStart.
  ///
  /// In en, this message translates to:
  /// **'Add a track to start learning.'**
  String get addTrackToStart;

  /// No description provided for @todaysTasks.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Tasks'**
  String get todaysTasks;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @myCurricula.
  ///
  /// In en, this message translates to:
  /// **'My Curricula'**
  String get myCurricula;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @viewProgress.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get viewProgress;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get markComplete;

  /// No description provided for @markCompleteTutorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available (tutor mode)'**
  String get markCompleteTutorUnavailable;

  /// No description provided for @markCompleteCompletedStage.
  ///
  /// In en, this message translates to:
  /// **'Completed ({stageName})'**
  String markCompleteCompletedStage(String stageName);

  /// No description provided for @unableToLoadCompletionContext.
  ///
  /// In en, this message translates to:
  /// **'Unable to load completion context: {error}'**
  String unableToLoadCompletionContext(String error);

  /// No description provided for @accountOfflineSignInToSync.
  ///
  /// In en, this message translates to:
  /// **'Working offline for this account. Sign in to resume cloud sync.'**
  String get accountOfflineSignInToSync;

  /// No description provided for @textReaderNextDailyTask.
  ///
  /// In en, this message translates to:
  /// **'Next daily task'**
  String get textReaderNextDailyTask;

  /// No description provided for @noProjection.
  ///
  /// In en, this message translates to:
  /// **'No projection'**
  String get noProjection;

  /// Today label — used in dashboard/recent activity sections.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @plusNMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String plusNMore(int count);

  /// No description provided for @noTracksYet.
  ///
  /// In en, this message translates to:
  /// **'No tracks yet'**
  String get noTracksYet;

  /// No description provided for @firstTrackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add your first learning track to get started.'**
  String get firstTrackPrompt;

  /// No description provided for @paceAhead.
  ///
  /// In en, this message translates to:
  /// **'{days}d ahead'**
  String paceAhead(int days);

  /// No description provided for @paceBehind.
  ///
  /// In en, this message translates to:
  /// **'{days}d behind'**
  String paceBehind(int days);

  /// No description provided for @paceOnPace.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get paceOnPace;

  /// No description provided for @progressNoDataTitle.
  ///
  /// In en, this message translates to:
  /// **'No progress yet'**
  String get progressNoDataTitle;

  /// No description provided for @progressNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start learning to see your progress here.'**
  String get progressNoDataSubtitle;

  /// No description provided for @statCompletions.
  ///
  /// In en, this message translates to:
  /// **'ITEMS LEARNED'**
  String get statCompletions;

  /// No description provided for @statUnitsDone.
  ///
  /// In en, this message translates to:
  /// **'TASKS DONE'**
  String get statUnitsDone;

  /// No description provided for @statDayStreak.
  ///
  /// In en, this message translates to:
  /// **'DAY STREAK'**
  String get statDayStreak;

  /// No description provided for @statActiveTracks.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE TRACKS'**
  String get statActiveTracks;

  /// No description provided for @progressChartsTile.
  ///
  /// In en, this message translates to:
  /// **'Progress Charts'**
  String get progressChartsTile;

  /// No description provided for @progressChartsTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completions, trends, and more'**
  String get progressChartsTileSubtitle;

  /// No description provided for @learningLifetime.
  ///
  /// In en, this message translates to:
  /// **'Learning Lifetime'**
  String get learningLifetime;

  /// No description provided for @learningLifetimeExpandHint.
  ///
  /// In en, this message translates to:
  /// **'Per curriculum: expand to browse what you have learned'**
  String get learningLifetimeExpandHint;

  /// No description provided for @addWhatYouLearned.
  ///
  /// In en, this message translates to:
  /// **'Add Lifetime Learning'**
  String get addWhatYouLearned;

  /// No description provided for @addWhatYouLearnedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Entries appear in your Lifetime Learning reports'**
  String get addWhatYouLearnedSettingsSubtitle;

  /// No description provided for @lifetimeLearning.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Learning'**
  String get lifetimeLearning;

  /// No description provided for @lifetimeLearningHubSection.
  ///
  /// In en, this message translates to:
  /// **'LEARNING HUB'**
  String get lifetimeLearningHubSection;

  /// No description provided for @lifetimeXpTotal.
  ///
  /// In en, this message translates to:
  /// **'{points} XP Total'**
  String lifetimeXpTotal(String points);

  /// No description provided for @lifetimeStartAdding.
  ///
  /// In en, this message translates to:
  /// **'Start Adding'**
  String get lifetimeStartAdding;

  /// No description provided for @learnBrowseSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get learnBrowseSectionTitle;

  /// No description provided for @lifetimeBrowseFullLibrary.
  ///
  /// In en, this message translates to:
  /// **'Browse Full Library'**
  String get lifetimeBrowseFullLibrary;

  /// No description provided for @lifetimeHowItWorksStep1.
  ///
  /// In en, this message translates to:
  /// **'Select a category from the library grid to see all available tracks.'**
  String get lifetimeHowItWorksStep1;

  /// No description provided for @lifetimeHowItWorksStep2.
  ///
  /// In en, this message translates to:
  /// **'Toggle tasks you\'ve finished to update your lifetime progress map.'**
  String get lifetimeHowItWorksStep2;

  /// No description provided for @lifetimeHowItWorksStep3.
  ///
  /// In en, this message translates to:
  /// **'Earn special milestone badges for completing whole volumes or tractates.'**
  String get lifetimeHowItWorksStep3;

  /// No description provided for @lifetimeNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get lifetimeNotStarted;

  /// No description provided for @lifetimeAddHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Lifetime Learning'**
  String get lifetimeAddHeaderTitle;

  /// No description provided for @lifetimeAddHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark what you\'ve already studied as lifetime learning.'**
  String get lifetimeAddHeaderSubtitle;

  /// No description provided for @lifetimeHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get lifetimeHowItWorksTitle;

  /// No description provided for @lifetimeHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Open a curriculum, then use the folder list to select sections. Green = selected for saving; open a subfolder with the arrow when there is more inside.'**
  String get lifetimeHowItWorksBody;

  /// No description provided for @lifetimeSelectScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Select what you\'ve learned'**
  String get lifetimeSelectScreenTitle;

  /// No description provided for @lifetimeSelectScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check sections to include; open folders to go deeper.'**
  String get lifetimeSelectScreenSubtitle;

  /// No description provided for @lifetimeMarkAsLearnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as lifetime learned'**
  String get lifetimeMarkAsLearnedTitle;

  /// No description provided for @lifetimeMarkAsLearnedLine.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count} • level {level}'**
  String lifetimeMarkAsLearnedLine(int count, int level);

  /// PP-3 fix: header info line in LifetimeCurriculumMarkingScreen — shows the session-selected count without leaking the internal 'level N' folder size.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String lifetimeMarkAsLearnedCount(int count);

  /// No description provided for @selectAllInThisList.
  ///
  /// In en, this message translates to:
  /// **'Select all in this list'**
  String get selectAllInThisList;

  /// No description provided for @deselectAllInThisList.
  ///
  /// In en, this message translates to:
  /// **'Deselect all in this list'**
  String get deselectAllInThisList;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @contentLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load curriculum content: {error}'**
  String contentLoadError(String error);

  /// AppBar title for the ContentHierarchyScreen showing the curriculum content tree.
  ///
  /// In en, this message translates to:
  /// **'Browse Content'**
  String get contentHierarchyBrowseTitle;

  /// AppBar title shown in ContentHierarchyScreen when the curriculumId does not match any known curriculum.
  ///
  /// In en, this message translates to:
  /// **'Unknown Curriculum'**
  String get contentHierarchyUnknownTitle;

  /// Empty-state message in ContentHierarchyScreen when there are no items to display.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get contentHierarchyNoContent;

  /// Tooltip for the search icon button in ContentHierarchyScreen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get contentHierarchySearchTooltip;

  /// No description provided for @noItemsAtThisLevel.
  ///
  /// In en, this message translates to:
  /// **'No items at this level'**
  String get noItemsAtThisLevel;

  /// No description provided for @breadcrumbsRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get breadcrumbsRoot;

  /// IL-3 fix: ICU plural to drop the (s) anti-pattern.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Marked 1 lifetime selection.} other{Marked {count} lifetime selections.}}'**
  String lifetimeMarkSavedCount(int count);

  /// No description provided for @lifetimeMarkSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save lifetime marks: {error}'**
  String lifetimeMarkSaveError(String error);

  /// No description provided for @dashboardStats.
  ///
  /// In en, this message translates to:
  /// **'STATS'**
  String get dashboardStats;

  /// No description provided for @learningLifetimeAllCurricula.
  ///
  /// In en, this message translates to:
  /// **'Learning lifetime (all curricula)'**
  String get learningLifetimeAllCurricula;

  /// No description provided for @dashboardAllCaughtUpTitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up! Great work!'**
  String get dashboardAllCaughtUpTitle;

  /// No description provided for @dashboardAllCaughtUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You have no more tasks for today.'**
  String get dashboardAllCaughtUpSubtitle;

  /// No description provided for @dashboardLifetimeProgress.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Progress'**
  String get dashboardLifetimeProgress;

  /// No description provided for @lifetimeSectionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{learned} / {total} sections — {n} curricula'**
  String lifetimeSectionsSummary(String learned, String total, int n);

  /// No description provided for @greetingHelloName.
  ///
  /// In en, this message translates to:
  /// **'Shalom, {name}!'**
  String greetingHelloName(String name);

  /// No description provided for @noFocusTag.
  ///
  /// In en, this message translates to:
  /// **'NO FOCUS TAG'**
  String get noFocusTag;

  /// No description provided for @todaysMissions.
  ///
  /// In en, this message translates to:
  /// **'Today’s Missions'**
  String get todaysMissions;

  /// No description provided for @noTasksInLane.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this lane'**
  String get noTasksInLane;

  /// No description provided for @reviewSection.
  ///
  /// In en, this message translates to:
  /// **'REVIEW SECTION'**
  String get reviewSection;

  /// No description provided for @chazaraReview.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get chazaraReview;

  /// No description provided for @activeTrackChazaraLabel.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get activeTrackChazaraLabel;

  /// No description provided for @urgent.
  ///
  /// In en, this message translates to:
  /// **'URGENT'**
  String get urgent;

  /// No description provided for @missedOverdue.
  ///
  /// In en, this message translates to:
  /// **'Missed/Overdue'**
  String get missedOverdue;

  /// No description provided for @bubbleOverdue.
  ///
  /// In en, this message translates to:
  /// **'OVERDUE'**
  String get bubbleOverdue;

  /// No description provided for @bubbleTodayDue.
  ///
  /// In en, this message translates to:
  /// **'TODAY\nDUE'**
  String get bubbleTodayDue;

  /// No description provided for @bubbleChazara.
  ///
  /// In en, this message translates to:
  /// **'CHAZARA'**
  String get bubbleChazara;

  /// No description provided for @talmidChochom.
  ///
  /// In en, this message translates to:
  /// **'Talmid Chochom'**
  String get talmidChochom;

  /// No description provided for @talmidChochomCaps.
  ///
  /// In en, this message translates to:
  /// **'TALMID CHOCHOM'**
  String get talmidChochomCaps;

  /// No description provided for @mainFocus.
  ///
  /// In en, this message translates to:
  /// **'MAIN FOCUS'**
  String get mainFocus;

  /// No description provided for @carouselCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completion (with {chazara})'**
  String carouselCompletion(String chazara);

  /// No description provided for @continueCta.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueCta;

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tabSchedule;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @nothingDueInQueue.
  ///
  /// In en, this message translates to:
  /// **'Nothing due in this queue right now.'**
  String get nothingDueInQueue;

  /// No description provided for @selfPacedScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'All of it, or just a section?'**
  String get selfPacedScopeTitle;

  /// No description provided for @learnEntireCurriculumCta.
  ///
  /// In en, this message translates to:
  /// **'I want to learn everything!'**
  String get learnEntireCurriculumCta;

  /// No description provided for @learnEntireCurriculumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select the entire {name}'**
  String learnEntireCurriculumSubtitle(String name);

  /// No description provided for @level1Selection.
  ///
  /// In en, this message translates to:
  /// **'{name} → {levelLabel} selection'**
  String level1Selection(String name, String levelLabel);

  /// No description provided for @scopeSelectedBadge.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get scopeSelectedBadge;

  /// No description provided for @selectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one'**
  String get selectAtLeastOne;

  /// No description provided for @continueWithSelectionCount.
  ///
  /// In en, this message translates to:
  /// **'Continue with {count} selected'**
  String continueWithSelectionCount(int count);

  /// No description provided for @sectionLearning.
  ///
  /// In en, this message translates to:
  /// **'LEARNING'**
  String get sectionLearning;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @notificationSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Push, email, and study sound alerts'**
  String get notificationSettingsSubtitle;

  /// No description provided for @pointsAbbrev.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String pointsAbbrev(int count);

  /// No description provided for @sectionTracks.
  ///
  /// In en, this message translates to:
  /// **'TRACKS'**
  String get sectionTracks;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get sectionAccount;

  /// No description provided for @sectionParentalControls.
  ///
  /// In en, this message translates to:
  /// **'PARENTAL CONTROLS'**
  String get sectionParentalControls;

  /// No description provided for @sectionDevice.
  ///
  /// In en, this message translates to:
  /// **'DEVICE'**
  String get sectionDevice;

  /// No description provided for @sectionProfile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get sectionProfile;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this account and cloud data'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteLocalAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes this device account and all learning data'**
  String get deleteLocalAccountSubtitle;

  /// No description provided for @settingsHandcraftedTagline.
  ///
  /// In en, this message translates to:
  /// **'Handcrafted for your Torah journey'**
  String get settingsHandcraftedTagline;

  /// No description provided for @calendarPreference.
  ///
  /// In en, this message translates to:
  /// **'Calendar Preference'**
  String get calendarPreference;

  /// No description provided for @calendarPreferenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Goals, deadlines, and date pickers'**
  String get calendarPreferenceSubtitle;

  /// No description provided for @calendarGregorian.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get calendarGregorian;

  /// No description provided for @calendarHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get calendarHebrew;

  /// No description provided for @hebrewTermsPreference.
  ///
  /// In en, this message translates to:
  /// **'Hebrew Terms'**
  String get hebrewTermsPreference;

  /// No description provided for @hebrewTermsPreferenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show learning terms (chazara, review) in Hebrew script or transliterated'**
  String get hebrewTermsPreferenceSubtitle;

  /// No description provided for @hebrewTermsHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get hebrewTermsHebrew;

  /// No description provided for @hebrewTermsEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get hebrewTermsEnglish;

  /// No description provided for @parentMode.
  ///
  /// In en, this message translates to:
  /// **'Parent Mode'**
  String get parentMode;

  /// No description provided for @parentModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to admin (PIN-guarded)'**
  String get parentModeSubtitle;

  /// No description provided for @parentModeActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage tracks, rewards & tutors'**
  String get parentModeActiveSubtitle;

  /// No description provided for @parentPin.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN'**
  String get parentPin;

  /// No description provided for @parentPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change your security PIN'**
  String get parentPinSubtitle;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChangedSuccessfully;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @userFallbackDisplayName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallbackDisplayName;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @selfLearnerBadge.
  ///
  /// In en, this message translates to:
  /// **'SELF-LEARNER'**
  String get selfLearnerBadge;

  /// No description provided for @parentContextBadge.
  ///
  /// In en, this message translates to:
  /// **'PARENT'**
  String get parentContextBadge;

  /// No description provided for @tutorContextBadge.
  ///
  /// In en, this message translates to:
  /// **'TUTOR'**
  String get tutorContextBadge;

  /// No description provided for @noBackup.
  ///
  /// In en, this message translates to:
  /// **'No Backup'**
  String get noBackup;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguageTitle;

  /// No description provided for @preferredLanguageForContent.
  ///
  /// In en, this message translates to:
  /// **'Preferred language for content'**
  String get preferredLanguageForContent;

  /// No description provided for @profilePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Who is learning?'**
  String get profilePickerTitle;

  /// No description provided for @profilePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a profile to continue your\njourney'**
  String get profilePickerSubtitle;

  /// No description provided for @profilePickerMyChildren.
  ///
  /// In en, this message translates to:
  /// **'MY CHILDREN'**
  String get profilePickerMyChildren;

  /// No description provided for @profilePickerYourProfiles.
  ///
  /// In en, this message translates to:
  /// **'YOUR PROFILES'**
  String get profilePickerYourProfiles;

  /// No description provided for @profilePickerTalmidProfiles.
  ///
  /// In en, this message translates to:
  /// **'TALMID PROFILES'**
  String get profilePickerTalmidProfiles;

  /// No description provided for @profilePickerSkipToSettings.
  ///
  /// In en, this message translates to:
  /// **'Skip to Settings'**
  String get profilePickerSkipToSettings;

  /// No description provided for @profilePickerTutoredChildren.
  ///
  /// In en, this message translates to:
  /// **'TUTORED CHILDREN'**
  String get profilePickerTutoredChildren;

  /// No description provided for @tutoredChildrenViewInvitations.
  ///
  /// In en, this message translates to:
  /// **'View invitations'**
  String get tutoredChildrenViewInvitations;

  /// No description provided for @tutoredChildrenManageGrants.
  ///
  /// In en, this message translates to:
  /// **'Manage tutoring grants'**
  String get tutoredChildrenManageGrants;

  /// No description provided for @tutoredChildrenManageGrantsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resign or review your tutoring access'**
  String get tutoredChildrenManageGrantsSubtitle;

  /// No description provided for @tutoredChildrenPendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} pending tutor invitation} other{{count} pending tutor invitations}}'**
  String tutoredChildrenPendingInvitations(int count);

  /// No description provided for @tutoredChildrenStatusTutoring.
  ///
  /// In en, this message translates to:
  /// **'Tutoring'**
  String get tutoredChildrenStatusTutoring;

  /// No description provided for @tutoredChildrenRoleBadge.
  ///
  /// In en, this message translates to:
  /// **'Tutor'**
  String get tutoredChildrenRoleBadge;

  /// No description provided for @tutorModeIndicator.
  ///
  /// In en, this message translates to:
  /// **'Tutor mode'**
  String get tutorModeIndicator;

  /// No description provided for @tutorModeIndicatorNamed.
  ///
  /// In en, this message translates to:
  /// **'Tutor mode · {name}'**
  String tutorModeIndicatorNamed(String name);

  /// No description provided for @tutorModeExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get tutorModeExit;

  /// No description provided for @tutoredEntryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied — the grant may have been revoked.'**
  String get tutoredEntryPermissionDenied;

  /// No description provided for @tutoredEntryError.
  ///
  /// In en, this message translates to:
  /// **'Could not load talmid data. Please try again.'**
  String get tutoredEntryError;

  /// No description provided for @viewingChildBanner.
  ///
  /// In en, this message translates to:
  /// **'Parent mode — viewing {name}'**
  String viewingChildBanner(String name);

  /// No description provided for @viewingChildBannerExit.
  ///
  /// In en, this message translates to:
  /// **'Exit parent mode'**
  String get viewingChildBannerExit;

  /// No description provided for @switchIntoChildTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to child view'**
  String get switchIntoChildTitle;

  /// No description provided for @switchIntoChildMessage.
  ///
  /// In en, this message translates to:
  /// **'You are about to enter {name}\'s full experience. You can exit anytime from the banner at the top.'**
  String switchIntoChildMessage(String name);

  /// No description provided for @switchIntoChildConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch in'**
  String get switchIntoChildConfirm;

  /// No description provided for @tutorCannotMarkLiveCompletion.
  ///
  /// In en, this message translates to:
  /// **'Tutors cannot mark live completions'**
  String get tutorCannotMarkLiveCompletion;

  /// No description provided for @tutorWriteForbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Action not allowed'**
  String get tutorWriteForbiddenTitle;

  /// No description provided for @tutorWriteForbiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Tutors cannot mark live forward completions. This action would credit the child\'s streak and rewards, which is reserved for the parent or child.'**
  String get tutorWriteForbiddenMessage;

  /// No description provided for @tutorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to make this edit'**
  String get tutorPermissionDenied;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get addProfile;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// No description provided for @enterNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterNameHint;

  /// No description provided for @chooseMode.
  ///
  /// In en, this message translates to:
  /// **'Choose Mode'**
  String get chooseMode;

  /// No description provided for @childModeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Child Mode'**
  String get childModeCardTitle;

  /// No description provided for @childModeCardSubtitleFunRewards.
  ///
  /// In en, this message translates to:
  /// **'Fun & Rewards'**
  String get childModeCardSubtitleFunRewards;

  /// No description provided for @adultModeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Adult Mode'**
  String get adultModeCardTitle;

  /// No description provided for @adultModeCardSubtitleDeepFocused.
  ///
  /// In en, this message translates to:
  /// **'Deep & Focused'**
  String get adultModeCardSubtitleDeepFocused;

  /// No description provided for @profileBadgeChildMode.
  ///
  /// In en, this message translates to:
  /// **'CHILD MODE'**
  String get profileBadgeChildMode;

  /// No description provided for @profileBadgeAdultMode.
  ///
  /// In en, this message translates to:
  /// **'ADULT MODE'**
  String get profileBadgeAdultMode;

  /// No description provided for @profileBadgeParentMode.
  ///
  /// In en, this message translates to:
  /// **'PARENT MODE'**
  String get profileBadgeParentMode;

  /// No description provided for @profileNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A profile named \"{name}\" already exists'**
  String profileNameTaken(String name);

  /// No description provided for @maxProfilesReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum 10 profiles reached'**
  String get maxProfilesReached;

  /// No description provided for @renameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAction;

  /// No description provided for @mustKeepOneProfile.
  ///
  /// In en, this message translates to:
  /// **'You must have at least one profile'**
  String get mustKeepOneProfile;

  /// No description provided for @profileNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A profile with this name already exists'**
  String get profileNameAlreadyExists;

  /// No description provided for @renameProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Profile'**
  String get renameProfileTitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @deleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get deleteProfileTitle;

  /// No description provided for @deleteProfileConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{name}\" and ALL associated learning data? This cannot be undone.'**
  String deleteProfileConfirm(String name);

  /// No description provided for @cannotDeleteOnlyProfile.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete your only profile'**
  String get cannotDeleteOnlyProfile;

  /// No description provided for @tapToContinue.
  ///
  /// In en, this message translates to:
  /// **'Tap to\ncontinue'**
  String get tapToContinue;

  /// No description provided for @maxProfilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Profiles'**
  String get maxProfilesLabel;

  /// No description provided for @addProfileCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Add\nProfile'**
  String get addProfileCardTitle;

  /// No description provided for @maxProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum reached'**
  String get maxProfilesSubtitle;

  /// No description provided for @createNewLearner.
  ///
  /// In en, this message translates to:
  /// **'Create new\nlearner'**
  String get createNewLearner;

  /// No description provided for @profilesLabel.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesLabel;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @syncScreenBody.
  ///
  /// In en, this message translates to:
  /// **'Sync status and settings will appear here.'**
  String get syncScreenBody;

  /// No description provided for @parentSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Settings'**
  String get parentSettingsTitle;

  /// No description provided for @manageTutors.
  ///
  /// In en, this message translates to:
  /// **'Manage Tutors'**
  String get manageTutors;

  /// No description provided for @manageTutorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite or remove tutors for this child'**
  String get manageTutorsSubtitle;

  /// No description provided for @manageTracksForChildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or archive your child\'s tracks'**
  String get manageTracksForChildSubtitle;

  /// No description provided for @manageGoals.
  ///
  /// In en, this message translates to:
  /// **'Manage Goals'**
  String get manageGoals;

  /// No description provided for @manageGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set pace or deadline goals for each track'**
  String get manageGoalsSubtitle;

  /// No description provided for @manageChildLearningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage tracks, points, rewards, and goals'**
  String get manageChildLearningSubtitle;

  /// No description provided for @pointConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Point Configuration'**
  String get pointConfiguration;

  /// No description provided for @pointConfigurationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set how many points activities are worth'**
  String get pointConfigurationSubtitle;

  /// No description provided for @rewardConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Reward Configuration'**
  String get rewardConfigurationTitle;

  /// No description provided for @rewardConfigurationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set prizes your child can redeem with their points.'**
  String get rewardConfigurationSubtitle;

  /// No description provided for @rewardConfigPerTrackTab.
  ///
  /// In en, this message translates to:
  /// **'Per track'**
  String get rewardConfigPerTrackTab;

  /// No description provided for @rewardConfigTotalPointsTab.
  ///
  /// In en, this message translates to:
  /// **'Total points'**
  String get rewardConfigTotalPointsTab;

  /// No description provided for @rewardConfigPerTrackHelper.
  ///
  /// In en, this message translates to:
  /// **'These rewards use points earned on the selected track only.'**
  String get rewardConfigPerTrackHelper;

  /// No description provided for @rewardConfigTotalPointsHelper.
  ///
  /// In en, this message translates to:
  /// **'These rewards use total points from all learning tracks combined (same as your child’s overall points).'**
  String get rewardConfigTotalPointsHelper;

  /// No description provided for @rewardConfigSelectTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get rewardConfigSelectTrack;

  /// No description provided for @rewardConfigNoActiveTracks.
  ///
  /// In en, this message translates to:
  /// **'No active tracks yet. Add a track to configure per-track rewards.'**
  String get rewardConfigNoActiveTracks;

  /// No description provided for @rewardConfigAddReward.
  ///
  /// In en, this message translates to:
  /// **'Add reward'**
  String get rewardConfigAddReward;

  /// No description provided for @rewardConfigEditReward.
  ///
  /// In en, this message translates to:
  /// **'Edit reward'**
  String get rewardConfigEditReward;

  /// No description provided for @rewardConfigRewardNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Reward name'**
  String get rewardConfigRewardNameLabel;

  /// No description provided for @rewardConfigPointsThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Points needed'**
  String get rewardConfigPointsThresholdLabel;

  /// No description provided for @rewardConfigSaveReward.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get rewardConfigSaveReward;

  /// No description provided for @rewardConfigDeleteReward.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get rewardConfigDeleteReward;

  /// No description provided for @rewardConfigDuplicateThreshold.
  ///
  /// In en, this message translates to:
  /// **'Another reward already uses this point value.'**
  String get rewardConfigDuplicateThreshold;

  /// No description provided for @rewardConfigEmptyMilestones.
  ///
  /// In en, this message translates to:
  /// **'No rewards yet. Close this menu and use the form above to add one.'**
  String get rewardConfigEmptyMilestones;

  /// No description provided for @rewardConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Rewards saved'**
  String get rewardConfigSaved;

  /// No description provided for @parentPortalTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Portal'**
  String get parentPortalTitle;

  /// No description provided for @rewardConfigScreenContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Reward Configuration'**
  String get rewardConfigScreenContextLabel;

  /// No description provided for @rewardConfigConfigureNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure New Reward'**
  String get rewardConfigConfigureNewTitle;

  /// No description provided for @rewardConfigConfigureNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a magical icon and set the milestone goals for your child.'**
  String get rewardConfigConfigureNewSubtitle;

  /// No description provided for @rewardConfigChooseAvatarStep.
  ///
  /// In en, this message translates to:
  /// **'1. CHOOSE AN AVATAR'**
  String get rewardConfigChooseAvatarStep;

  /// No description provided for @rewardConfigRewardTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reward type'**
  String get rewardConfigRewardTypeLabel;

  /// No description provided for @rewardConfigChooseTrackLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose track'**
  String get rewardConfigChooseTrackLabel;

  /// No description provided for @rewardConfigPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get rewardConfigPreviewLabel;

  /// No description provided for @rewardConfigPointsPreview.
  ///
  /// In en, this message translates to:
  /// **'{points, plural, =1{{points} Point} other{{points} Points}}'**
  String rewardConfigPointsPreview(int points);

  /// No description provided for @rewardConfigCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get rewardConfigCancel;

  /// No description provided for @rewardConfigSaveRewardButton.
  ///
  /// In en, this message translates to:
  /// **'Save Reward'**
  String get rewardConfigSaveRewardButton;

  /// No description provided for @rewardConfigUpdateRewardButton.
  ///
  /// In en, this message translates to:
  /// **'Update Reward'**
  String get rewardConfigUpdateRewardButton;

  /// No description provided for @rewardConfigEditModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the icon, name, or point cost for this reward.'**
  String get rewardConfigEditModeSubtitle;

  /// No description provided for @rewardConfigNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., Bronze Star'**
  String get rewardConfigNamePlaceholder;

  /// No description provided for @rewardConfigPointsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., 500'**
  String get rewardConfigPointsPlaceholder;

  /// No description provided for @rewardConfigMenuManageRewards.
  ///
  /// In en, this message translates to:
  /// **'Manage rewards'**
  String get rewardConfigMenuManageRewards;

  /// No description provided for @rewardConfigRewardCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reward created'**
  String get rewardConfigRewardCreatedTitle;

  /// No description provided for @rewardConfigRewardCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" was added. Your child will see it under Achievements — locked and blurred until they reach the points goal.'**
  String rewardConfigRewardCreatedBody(String name);

  /// No description provided for @rewardConfigRewardUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reward updated'**
  String get rewardConfigRewardUpdatedTitle;

  /// No description provided for @rewardConfigRewardUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes to \"{name}\" were saved. Your child will see the update under Achievements.'**
  String rewardConfigRewardUpdatedBody(String name);

  /// No description provided for @pointConfigPerTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Points per completed task'**
  String get pointConfigPerTaskTitle;

  /// No description provided for @pointConfigPerTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'For each active learning track, set how many points your child earns when they complete one task from their daily list. The amount depends on the task stage (for example first learn vs review).'**
  String get pointConfigPerTaskDescription;

  /// No description provided for @pointConfigNoActiveTracksBody.
  ///
  /// In en, this message translates to:
  /// **'No active learning tracks with stages were found for this child. Turn on curricula and set up tracks in Manage Tracks, then return here to choose points per task.'**
  String get pointConfigNoActiveTracksBody;

  /// No description provided for @pointSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Point Settings'**
  String get pointSettingsTitle;

  /// No description provided for @pointSettingsConfigurationLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIGURATION'**
  String get pointSettingsConfigurationLabel;

  /// No description provided for @pointSettingsRewardsStrategyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewards Strategy'**
  String get pointSettingsRewardsStrategyTitle;

  /// No description provided for @pointSettingsRewardsStrategySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust how many points your child earns for each sacred milestone.'**
  String get pointSettingsRewardsStrategySubtitle;

  /// No description provided for @pointSettingsActiveCurricula.
  ///
  /// In en, this message translates to:
  /// **'Active Curricula'**
  String get pointSettingsActiveCurricula;

  /// No description provided for @pointSettingsPointsPerTask.
  ///
  /// In en, this message translates to:
  /// **'Points per Task'**
  String get pointSettingsPointsPerTask;

  /// No description provided for @pointSettingsPts.
  ///
  /// In en, this message translates to:
  /// **'PTS'**
  String get pointSettingsPts;

  /// No description provided for @pointSettingsActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get pointSettingsActiveBadge;

  /// No description provided for @pointSettingsSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All Changes'**
  String get pointSettingsSaveAll;

  /// No description provided for @pointSettingsSaveFooter.
  ///
  /// In en, this message translates to:
  /// **'Point changes will sync instantly to the Child\'s dashboard.'**
  String get pointSettingsSaveFooter;

  /// No description provided for @pointSettingsSavedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Changes saved and synced.'**
  String get pointSettingsSavedSnackbar;

  /// No description provided for @pointSettingsNothingToSaveSnackbar.
  ///
  /// In en, this message translates to:
  /// **'No changes to save.'**
  String get pointSettingsNothingToSaveSnackbar;

  /// No description provided for @pointSettingsPrimaryStageLabel.
  ///
  /// In en, this message translates to:
  /// **'First completion (daily task)'**
  String get pointSettingsPrimaryStageLabel;

  /// No description provided for @sectionAccountSafety.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT SAFETY'**
  String get sectionAccountSafety;

  /// No description provided for @bottomNavTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get bottomNavTracks;

  /// No description provided for @bottomNavRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get bottomNavRewards;

  /// No description provided for @bottomNavParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get bottomNavParent;

  /// No description provided for @addProfileDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and select Child mode or Adult mode.'**
  String get addProfileDialogSubtitle;

  /// No description provided for @setParentPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Parent PIN'**
  String get setParentPinDialogTitle;

  /// No description provided for @setParentPinDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a 4-digit PIN to access parent controls for {name}. The PIN is stored only on this device.'**
  String setParentPinDialogSubtitle(String name);

  /// No description provided for @enterParentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Parent PIN'**
  String get enterParentPin;

  /// No description provided for @enterParentPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN to access parent settings.'**
  String get enterParentPinSubtitle;

  /// No description provided for @enterNewPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new 4-digit PIN.'**
  String get enterNewPinSubtitle;

  /// No description provided for @confirmNewPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same PIN again to confirm.'**
  String get confirmNewPinSubtitle;

  /// No description provided for @changeParentPin.
  ///
  /// In en, this message translates to:
  /// **'Change Parent PIN'**
  String get changeParentPin;

  /// No description provided for @pinChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'PIN changed successfully'**
  String get pinChangedSuccessfully;

  /// No description provided for @pinFlowSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new 4-digit PIN to enable parent mode.'**
  String get pinFlowSetupSubtitle;

  /// No description provided for @pinFlowSetupDeviceLocalBanner.
  ///
  /// In en, this message translates to:
  /// **'Parent PINs live only on this device. Set a new 4-digit PIN to enable parent mode here. Other devices keep their own PIN.'**
  String get pinFlowSetupDeviceLocalBanner;

  /// No description provided for @deviceRestoreChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking device...'**
  String get deviceRestoreChecking;

  /// No description provided for @deviceRestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore complete!'**
  String get deviceRestoreComplete;

  /// No description provided for @deviceRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get deviceRestoreFailed;

  /// No description provided for @deviceRestoreStep.
  ///
  /// In en, this message translates to:
  /// **'Step {completed} of {total}'**
  String deviceRestoreStep(int completed, int total);

  /// No description provided for @deviceRestorePhaseRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring your data...'**
  String get deviceRestorePhaseRestoring;

  /// No description provided for @deviceRestorePhaseLoadingCurricula.
  ///
  /// In en, this message translates to:
  /// **'Loading curricula...'**
  String get deviceRestorePhaseLoadingCurricula;

  /// No description provided for @deviceRestorePhaseImportingContent.
  ///
  /// In en, this message translates to:
  /// **'Importing content...'**
  String get deviceRestorePhaseImportingContent;

  /// No description provided for @skipAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Skip & continue'**
  String get skipAndContinue;

  /// No description provided for @noActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'No active profile'**
  String get noActiveProfile;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get incorrectPin;

  /// No description provided for @enterCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Current PIN'**
  String get enterCurrentPin;

  /// No description provided for @enterCurrentPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your current 4-digit PIN to change it.'**
  String get enterCurrentPinSubtitle;

  /// No description provided for @enterNewPin.
  ///
  /// In en, this message translates to:
  /// **'Enter New PIN'**
  String get enterNewPin;

  /// No description provided for @confirmNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm New PIN'**
  String get confirmNewPin;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinsDoNotMatch;

  /// No description provided for @tabBarDashboard.
  ///
  /// In en, this message translates to:
  /// **'DASHBOARD'**
  String get tabBarDashboard;

  /// No description provided for @tabBarLearn.
  ///
  /// In en, this message translates to:
  /// **'LEARN'**
  String get tabBarLearn;

  /// No description provided for @tabBarProgress.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS'**
  String get tabBarProgress;

  /// No description provided for @tabBarSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get tabBarSettings;

  /// No description provided for @errorLoadingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Error loading calendar'**
  String get errorLoadingCalendar;

  /// No description provided for @journeyByCurriculum.
  ///
  /// In en, this message translates to:
  /// **'By Curriculum'**
  String get journeyByCurriculum;

  /// No description provided for @journeyTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get journeyTimeline;

  /// No description provided for @journeyTitleNamed.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Learning Journey'**
  String journeyTitleNamed(String name);

  /// No description provided for @loadingYourJourney.
  ///
  /// In en, this message translates to:
  /// **'Loading your journey...'**
  String get loadingYourJourney;

  /// No description provided for @failedToLoadJourney.
  ///
  /// In en, this message translates to:
  /// **'Failed to load journey: {error}'**
  String failedToLoadJourney(String error);

  /// No description provided for @journeyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No siyumim yet'**
  String get journeyEmptyTitle;

  /// No description provided for @journeyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When you complete a masechta or sefer, it will be recorded here as a permanent milestone.'**
  String get journeyEmptyBody;

  /// No description provided for @chartCumulativeProgress.
  ///
  /// In en, this message translates to:
  /// **'Cumulative Progress'**
  String get chartCumulativeProgress;

  /// No description provided for @chartCumulativeProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Total completions over time'**
  String get chartCumulativeProgressSubtitle;

  /// No description provided for @chartPointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points Earned'**
  String get chartPointsEarned;

  /// No description provided for @chartTotalTorahPoints.
  ///
  /// In en, this message translates to:
  /// **'TOTAL TORAH POINTS'**
  String get chartTotalTorahPoints;

  /// No description provided for @chartLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get chartLast7Days;

  /// No description provided for @chartLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30\nDays'**
  String get chartLast30Days;

  /// No description provided for @chartAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get chartAllTime;

  /// No description provided for @chartFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chartFilterAll;

  /// No description provided for @learnStreakCurrentAchievement.
  ///
  /// In en, this message translates to:
  /// **'CURRENT ACHIEVEMENT'**
  String get learnStreakCurrentAchievement;

  /// No description provided for @learnStreakDayStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day Streak} other{{count} Day Streak}}'**
  String learnStreakDayStreak(int count);

  /// No description provided for @learnStreakPersonalBest.
  ///
  /// In en, this message translates to:
  /// **'Personal Best: {count}'**
  String learnStreakPersonalBest(int count);

  /// No description provided for @learnStreakKeepItUp.
  ///
  /// In en, this message translates to:
  /// **'Keep it up!'**
  String get learnStreakKeepItUp;

  /// No description provided for @notifAppBarNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifAppBarNotifications;

  /// No description provided for @notifDailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get notifDailyReminder;

  /// No description provided for @notifDailyReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget to learn today!'**
  String get notifDailyReminderSubtitle;

  /// No description provided for @notifReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get notifReminderTime;

  /// No description provided for @notifStreakAlert.
  ///
  /// In en, this message translates to:
  /// **'Streak Alert'**
  String get notifStreakAlert;

  /// No description provided for @notifStreakAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your fire burning!'**
  String get notifStreakAlertSubtitle;

  /// No description provided for @notifHotStreakBadge.
  ///
  /// In en, this message translates to:
  /// **'HOT STREAK'**
  String get notifHotStreakBadge;

  /// No description provided for @notifStreakAlertTime.
  ///
  /// In en, this message translates to:
  /// **'Streak Alert Time'**
  String get notifStreakAlertTime;

  /// No description provided for @notifRewardMilestones.
  ///
  /// In en, this message translates to:
  /// **'Reward Notifications'**
  String get notifRewardMilestones;

  /// No description provided for @notifRewardMilestonesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you earn Learning Points!'**
  String get notifRewardMilestonesSubtitle;

  /// No description provided for @notifSacredTime.
  ///
  /// In en, this message translates to:
  /// **'SHABBOS MODE'**
  String get notifSacredTime;

  /// No description provided for @notifShabbosYomTovMode.
  ///
  /// In en, this message translates to:
  /// **'Shabbos / Yom Tov\nMode'**
  String get notifShabbosYomTovMode;

  /// No description provided for @notifShabbosModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet learning during holy days'**
  String get notifShabbosModeSubtitle;

  /// No description provided for @notifUseLocationForTimes.
  ///
  /// In en, this message translates to:
  /// **'Use Location for Times'**
  String get notifUseLocationForTimes;

  /// No description provided for @notifQuietStart.
  ///
  /// In en, this message translates to:
  /// **'QUIET START'**
  String get notifQuietStart;

  /// No description provided for @notifQuietEnd.
  ///
  /// In en, this message translates to:
  /// **'QUIET END'**
  String get notifQuietEnd;

  /// No description provided for @notifCandleLighting.
  ///
  /// In en, this message translates to:
  /// **'Candle lighting'**
  String get notifCandleLighting;

  /// No description provided for @notifHavdalah.
  ///
  /// In en, this message translates to:
  /// **'Havdalah'**
  String get notifHavdalah;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authLocalDataMissing.
  ///
  /// In en, this message translates to:
  /// **'This account\'s local data is missing. Connect to the internet to restore it.'**
  String get authLocalDataMissing;

  /// No description provided for @authEmailOfflineUnreachable.
  ///
  /// In en, this message translates to:
  /// **'This email isn\'t on this device and we can\'t reach the cloud. Try again when online.'**
  String get authEmailOfflineUnreachable;

  /// No description provided for @authIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get authIncorrectPassword;

  /// No description provided for @authSignInFailedError.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String authSignInFailedError(String error);

  /// No description provided for @authVerifyEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to your inbox. Please check your email to continue.'**
  String get authVerifyEmailBody;

  /// No description provided for @authIveVerified.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get authIveVerified;

  /// No description provided for @authVerificationEmailSentAgain.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent again.'**
  String get authVerificationEmailSentAgain;

  /// No description provided for @authEmailStillUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email is still unverified. Check your inbox first.'**
  String get authEmailStillUnverified;

  /// No description provided for @authMaxDeviceAccounts.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} device accounts reached. Remove one to add another.'**
  String authMaxDeviceAccounts(int count);

  /// No description provided for @authOfflineUseUpgrade.
  ///
  /// In en, this message translates to:
  /// **'An offline account with this email exists on this device. Use the Upgrade to Cloud option in Settings instead.'**
  String get authOfflineUseUpgrade;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed. Please try again.'**
  String get authGoogleSignInFailed;

  /// No description provided for @authErrUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get authErrUserNotFound;

  /// No description provided for @authErrWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get authErrWrongPassword;

  /// No description provided for @authErrInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password. Please try again.'**
  String get authErrInvalidCredential;

  /// No description provided for @authErrUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrUserDisabled;

  /// No description provided for @authErrTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authErrTooManyRequests;

  /// No description provided for @authErrInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get authErrInvalidEmail;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get authErrNetwork;

  /// No description provided for @authErrSignInGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get authErrSignInGeneric;

  /// No description provided for @authTierCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get authTierCloud;

  /// No description provided for @authTierLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get authTierLocal;

  /// No description provided for @authFoundOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Found on this device ({tier})'**
  String authFoundOnDevice(String tier);

  /// No description provided for @authNotOnDeviceCheckCloud.
  ///
  /// In en, this message translates to:
  /// **'Not on this device — we\'ll check the cloud'**
  String get authNotOnDeviceCheckCloud;

  /// No description provided for @authNotOnDeviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Not on this device (offline — only device accounts available)'**
  String get authNotOnDeviceOffline;

  /// No description provided for @authModeCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud account: your data is backed up and syncs across devices.'**
  String get authModeCloud;

  /// No description provided for @authModeCloudOffline.
  ///
  /// In en, this message translates to:
  /// **'Cloud account is offline right now. We will try local cached data until internet returns.'**
  String get authModeCloudOffline;

  /// No description provided for @authModeLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Local account only: no cloud backup and no device sync.'**
  String get authModeLocalTitle;

  /// No description provided for @authModeLocalBody.
  ///
  /// In en, this message translates to:
  /// **'No cloud backup or device sync. Your data stays only on this device.'**
  String get authModeLocalBody;

  /// No description provided for @signInWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get signInWelcomeBack;

  /// No description provided for @signInReady.
  ///
  /// In en, this message translates to:
  /// **'Ready for your next learning adventure?'**
  String get signInReady;

  /// No description provided for @signInYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Your Email'**
  String get signInYourEmail;

  /// No description provided for @signInEmailHint.
  ///
  /// In en, this message translates to:
  /// **'yourname@quest.com'**
  String get signInEmailHint;

  /// No description provided for @signInPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Key'**
  String get signInPasswordLabel;

  /// No description provided for @signInPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your secret key'**
  String get signInPasswordHint;

  /// No description provided for @signInKeepMeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get signInKeepMeSignedIn;

  /// No description provided for @signInForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPassword;

  /// No description provided for @signInForgotPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get signInForgotPasswordSent;

  /// No description provided for @signInForgotPasswordNoEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address first.'**
  String get signInForgotPasswordNoEmail;

  /// No description provided for @signInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInCta;

  /// No description provided for @signInWithGoogleCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogleCta;

  /// No description provided for @signInNewToQuest.
  ///
  /// In en, this message translates to:
  /// **'New to the Quest? '**
  String get signInNewToQuest;

  /// No description provided for @signInRegisterHere.
  ///
  /// In en, this message translates to:
  /// **'Register Here'**
  String get signInRegisterHere;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUpTitle;

  /// No description provided for @signUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your free account'**
  String get signUpSubtitle;

  /// No description provided for @signUpScholarNameHint.
  ///
  /// In en, this message translates to:
  /// **'Scholar Name'**
  String get signUpScholarNameHint;

  /// No description provided for @signUpEmailAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get signUpEmailAddressLabel;

  /// No description provided for @signUpPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Create Password'**
  String get signUpPasswordLabel;

  /// No description provided for @signUpPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Create a secure password'**
  String get signUpPasswordHint;

  /// No description provided for @signUpCta.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpCta;

  /// No description provided for @signUpOrDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get signUpOrDivider;

  /// No description provided for @signUpGoogleCta.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Google'**
  String get signUpGoogleCta;

  /// No description provided for @signUpAlreadyExploring.
  ///
  /// In en, this message translates to:
  /// **'Already exploring? '**
  String get signUpAlreadyExploring;

  /// No description provided for @signUpLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get signUpLogIn;

  /// No description provided for @signUpOfflineAck.
  ///
  /// In en, this message translates to:
  /// **'Offline mode: account stays only on this device.'**
  String get signUpOfflineAck;

  /// No description provided for @signUpAckRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please acknowledge the offline account warning before creating an offline account.'**
  String get signUpAckRequiredError;

  /// No description provided for @signUpVerificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Verify your email, then sign in.'**
  String get signUpVerificationEmailSent;

  /// No description provided for @signUpEmailAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email.'**
  String get signUpEmailAlreadyExists;

  /// No description provided for @signUpDeviceEmailExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists on this device. Sign in instead.'**
  String get signUpDeviceEmailExists;

  /// No description provided for @signUpOfflineInProgress.
  ///
  /// In en, this message translates to:
  /// **'An offline signup for this email is already in progress. Finish creating a profile or try again later.'**
  String get signUpOfflineInProgress;

  /// No description provided for @signUpOfflineEmailExists.
  ///
  /// In en, this message translates to:
  /// **'An offline account already exists on this device with that email.'**
  String get signUpOfflineEmailExists;

  /// No description provided for @signUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Signup failed: {error}'**
  String signUpFailed(String error);

  /// No description provided for @signUpFallbackBody.
  ///
  /// In en, this message translates to:
  /// **'The internet connection dropped during signup. Would you like to create an offline account instead?'**
  String get signUpFallbackBody;

  /// No description provided for @signUpErrWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get signUpErrWeakPassword;

  /// No description provided for @signUpErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Account creation failed. Please try again.'**
  String get signUpErrGeneric;

  /// No description provided for @chartFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get chartFailedToLoad;

  /// No description provided for @accountPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an Account'**
  String get accountPickerTitle;

  /// No description provided for @accountPickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a learner to continue your journey'**
  String get accountPickerSubtitle;

  /// No description provided for @accountPickerMaxAccountsShort.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} device accounts reached'**
  String accountPickerMaxAccountsShort(int count);

  /// No description provided for @accountPickerPrivacyFooter.
  ///
  /// In en, this message translates to:
  /// **'Manage your privacy and security in Settings'**
  String get accountPickerPrivacyFooter;

  /// No description provided for @accountRemoveFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from device'**
  String get accountRemoveFromDevice;

  /// No description provided for @accountDeleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAccountAction;

  /// No description provided for @badgeLocalAccount.
  ///
  /// In en, this message translates to:
  /// **'LOCAL ACCOUNT'**
  String get badgeLocalAccount;

  /// No description provided for @badgeSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN AGAIN'**
  String get badgeSignInAgain;

  /// No description provided for @badgeCloudAccount.
  ///
  /// In en, this message translates to:
  /// **'CLOUD ACCOUNT'**
  String get badgeCloudAccount;

  /// No description provided for @accountRemoveFromDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from device?'**
  String get accountRemoveFromDeviceTitle;

  /// No description provided for @accountDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get accountDeleteAccountTitle;

  /// No description provided for @accountRemoveFromDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Your cloud data is safe — you can sign back in anytime.'**
  String get accountRemoveFromDeviceBody;

  /// No description provided for @accountDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'All learning data will be permanently lost. This cannot be undone.'**
  String get accountDeleteAccountBody;

  /// No description provided for @accountRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get accountRemove;

  /// No description provided for @accountDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get accountDeleteForever;

  /// No description provided for @accountPickerAddAnother.
  ///
  /// In en, this message translates to:
  /// **'+1   Add another account ({remaining} slots remaining)'**
  String accountPickerAddAnother(int remaining);

  /// No description provided for @cannotDeactivateLastCurriculum.
  ///
  /// In en, this message translates to:
  /// **'At least one curriculum must remain active'**
  String get cannotDeactivateLastCurriculum;

  /// No description provided for @cannotDeactivateLastCurriculumDetail.
  ///
  /// In en, this message translates to:
  /// **'You cannot remove your last active curriculum. Add another curriculum before removing this one.'**
  String get cannotDeactivateLastCurriculumDetail;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get actionExit;

  /// No description provided for @actionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get actionReplace;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionSkipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get actionSkipForNow;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionUseToday.
  ///
  /// In en, this message translates to:
  /// **'Use Today'**
  String get actionUseToday;

  /// No description provided for @actionStartHere.
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get actionStartHere;

  /// No description provided for @actionStartHereLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Here'**
  String get actionStartHereLabel;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorGeneric(String error);

  /// No description provided for @errorLoadingOrder.
  ///
  /// In en, this message translates to:
  /// **'Error loading order: {error}'**
  String errorLoadingOrder(String error);

  /// No description provided for @errorLoadingContent.
  ///
  /// In en, this message translates to:
  /// **'Error loading content: {error}'**
  String errorLoadingContent(String error);

  /// No description provided for @errorLoadingPoints.
  ///
  /// In en, this message translates to:
  /// **'Error loading points'**
  String get errorLoadingPoints;

  /// No description provided for @errorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get errorSaveFailed;

  /// No description provided for @errorSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String errorSearchFailed(String error);

  /// No description provided for @errorSearchError.
  ///
  /// In en, this message translates to:
  /// **'Search error: {error}'**
  String errorSearchError(String error);

  /// No description provided for @errorUnknownCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Unknown curriculum: \"{curriculumId}\"'**
  String errorUnknownCurriculum(String curriculumId);

  /// No description provided for @errorCouldNotSaveRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — tap to retry'**
  String get errorCouldNotSaveRetry;

  /// No description provided for @errorSaveTrackFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save track. Please try again.'**
  String get errorSaveTrackFailed;

  /// No description provided for @errorSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out. Please try again.'**
  String get errorSignOutFailed;

  /// No description provided for @errorReauthFailed.
  ///
  /// In en, this message translates to:
  /// **'Re-authentication failed. Please try again.'**
  String get errorReauthFailed;

  /// No description provided for @errorResolveAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve this account. Try again.'**
  String get errorResolveAccount;

  /// No description provided for @errorOnlyOfflineDelete.
  ///
  /// In en, this message translates to:
  /// **'Only offline accounts can be deleted here.'**
  String get errorOnlyOfflineDelete;

  /// No description provided for @errorDeleteProfileRequiresInternet.
  ///
  /// In en, this message translates to:
  /// **'An internet connection is required to delete a profile.'**
  String get errorDeleteProfileRequiresInternet;

  /// No description provided for @errorDeleteAccountRequiresInternet.
  ///
  /// In en, this message translates to:
  /// **'An internet connection is required to delete your account.'**
  String get errorDeleteAccountRequiresInternet;

  /// No description provided for @errorDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account: {error}'**
  String errorDeleteAccountFailed(String error);

  /// No description provided for @errorSendLogsMustBeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Must be signed in to send logs'**
  String get errorSendLogsMustBeSignedIn;

  /// No description provided for @errorSendLogsNoGateway.
  ///
  /// In en, this message translates to:
  /// **'Sync not available — account not linked to cloud'**
  String get errorSendLogsNoGateway;

  /// No description provided for @errorSendLogsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send logs: {error}'**
  String errorSendLogsFailed(String error);

  /// No description provided for @sendLogsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logs sent ({count} entries). View in Firebase console → diagnostic_logs.'**
  String sendLogsSuccess(int count);

  /// No description provided for @errorNoEmailApp.
  ///
  /// In en, this message translates to:
  /// **'No email app found. Copy address instead?'**
  String get errorNoEmailApp;

  /// No description provided for @errorMarkCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to mark complete: {error}'**
  String errorMarkCompleteFailed(String error);

  /// No description provided for @errorVerificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent. Check your inbox.'**
  String get errorVerificationEmailSent;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @noTasksForToday.
  ///
  /// In en, this message translates to:
  /// **'No tasks for today'**
  String get noTasksForToday;

  /// No description provided for @noItemsToOrder.
  ///
  /// In en, this message translates to:
  /// **'No items to order.'**
  String get noItemsToOrder;

  /// No description provided for @noProfilesYet.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet. Tap + to add one.'**
  String get noProfilesYet;

  /// No description provided for @noCompletionsYet.
  ///
  /// In en, this message translates to:
  /// **'No completions yet'**
  String get noCompletionsYet;

  /// No description provided for @noResultsForQuery.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsForQuery(String query);

  /// No description provided for @viewAllTasks.
  ///
  /// In en, this message translates to:
  /// **'View all ({count}) →'**
  String viewAllTasks(int count);

  /// No description provided for @tasksDueToday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task today} other{{count} tasks today}}'**
  String tasksDueToday(int count);

  /// No description provided for @tapToStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Tap to start learning'**
  String get tapToStartLearning;

  /// No description provided for @todaysLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Learning'**
  String get todaysLearningTitle;

  /// No description provided for @remainingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String remainingCount(int count);

  /// No description provided for @allDoneForToday.
  ///
  /// In en, this message translates to:
  /// **'All done for today!'**
  String get allDoneForToday;

  /// No description provided for @missedReview.
  ///
  /// In en, this message translates to:
  /// **'Missed review ({count})'**
  String missedReview(int count);

  /// No description provided for @todaysReview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s review ({count})'**
  String todaysReview(int count);

  /// No description provided for @dailyTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Tasks'**
  String get dailyTasksTitle;

  /// No description provided for @taskSkippedUntilTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Task skipped until tomorrow'**
  String get taskSkippedUntilTomorrow;

  /// No description provided for @tasksNoTasksRemainingTitle.
  ///
  /// In en, this message translates to:
  /// **'You have no tasks remaining for today.'**
  String get tasksNoTasksRemainingTitle;

  /// No description provided for @undoLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoLabel;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHintEnterTerm.
  ///
  /// In en, this message translates to:
  /// **'Enter a search term above'**
  String get searchHintEnterTerm;

  /// No description provided for @loadingText.
  ///
  /// In en, this message translates to:
  /// **'Loading text...'**
  String get loadingText;

  /// No description provided for @markedComplete.
  ///
  /// In en, this message translates to:
  /// **'Marked complete'**
  String get markedComplete;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {error}'**
  String couldNotSave(String error);

  /// No description provided for @textReaderTooltipPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get textReaderTooltipPrevious;

  /// No description provided for @textReaderTooltipNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get textReaderTooltipNext;

  /// No description provided for @textReaderHebrewTab.
  ///
  /// In en, this message translates to:
  /// **'Hebrew Text'**
  String get textReaderHebrewTab;

  /// No description provided for @textReaderEnglishTab.
  ///
  /// In en, this message translates to:
  /// **'English Translation'**
  String get textReaderEnglishTab;

  /// No description provided for @totalPointsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPointsLabel;

  /// No description provided for @resetToDefaultOrder.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default Order'**
  String get resetToDefaultOrder;

  /// No description provided for @resetToDefaultOrderDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default Order'**
  String get resetToDefaultOrderDialogTitle;

  /// No description provided for @resetToDefaultOrderDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will restore the natural Sefaria order for this curriculum. Your custom ordering will be lost.'**
  String get resetToDefaultOrderDialogBody;

  /// No description provided for @reorderConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder Content?'**
  String get reorderConfirmTitle;

  /// No description provided for @reorderConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Reordering will clear your {overdueCount} outstanding overdue item(s). Consider completing them first.'**
  String reorderConfirmBody(int overdueCount);

  /// No description provided for @controlledByParent.
  ///
  /// In en, this message translates to:
  /// **'Controlled by parent'**
  String get controlledByParent;

  /// No description provided for @sacredTimeLockGoodShabbos.
  ///
  /// In en, this message translates to:
  /// **'Good {term}'**
  String sacredTimeLockGoodShabbos(String term);

  /// No description provided for @sacredTimeLockShabbosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app is closed for {term}.'**
  String sacredTimeLockShabbosSubtitle(String term);

  /// No description provided for @sacredTimeLockGoodYomTov.
  ///
  /// In en, this message translates to:
  /// **'Good Yom Tov'**
  String get sacredTimeLockGoodYomTov;

  /// No description provided for @sacredTimeLockYomTovSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app is closed for Yom Tov.'**
  String get sacredTimeLockYomTovSubtitle;

  /// No description provided for @sacredTimeLockShabbosYomTovGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good {term} & Good Yom Tov'**
  String sacredTimeLockShabbosYomTovGreeting(String term);

  /// No description provided for @sacredTimeLockShabbosYomTovSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app is closed for {term} and Yom Tov.'**
  String sacredTimeLockShabbosYomTovSubtitle(String term);

  /// No description provided for @sacredTimeLockYomKippurGreeting.
  ///
  /// In en, this message translates to:
  /// **'Have an easy and meaningful fast'**
  String get sacredTimeLockYomKippurGreeting;

  /// No description provided for @sacredTimeLockYomKippurSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app is closed for Yom Kippur.'**
  String get sacredTimeLockYomKippurSubtitle;

  /// No description provided for @sacredTimeDetect.
  ///
  /// In en, this message translates to:
  /// **'Detect'**
  String get sacredTimeDetect;

  /// No description provided for @sacredTimeChooseCity.
  ///
  /// In en, this message translates to:
  /// **'Choose city'**
  String get sacredTimeChooseCity;

  /// No description provided for @textReaderTextUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Text not available'**
  String get textReaderTextUnavailableTitle;

  /// No description provided for @textReaderCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get textReaderCheckConnection;

  /// No description provided for @textReaderFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load text'**
  String get textReaderFailedToLoad;

  /// No description provided for @sacredTimeCardDescription.
  ///
  /// In en, this message translates to:
  /// **'App is silenced and locked during {term} and Yom Tov. Times computed locally from your location with a 15-minute cushion.'**
  String sacredTimeCardDescription(String term);

  /// No description provided for @sacredTimeShabbosModeLabel.
  ///
  /// In en, this message translates to:
  /// **'{term} MODE'**
  String sacredTimeShabbosModeLabel(String term);

  /// No description provided for @sacredTimeAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get sacredTimeAlwaysOn;

  /// No description provided for @sacredTimeNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location set'**
  String get sacredTimeNoLocation;

  /// No description provided for @sacredTimeSourceDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected automatically'**
  String get sacredTimeSourceDetected;

  /// No description provided for @sacredTimeSourceManualCity.
  ///
  /// In en, this message translates to:
  /// **'Chosen from city list'**
  String get sacredTimeSourceManualCity;

  /// No description provided for @sacredTimeSourceManualCoords.
  ///
  /// In en, this message translates to:
  /// **'Manual coordinates'**
  String get sacredTimeSourceManualCoords;

  /// No description provided for @sacredTimeInIsraelTitle.
  ///
  /// In en, this message translates to:
  /// **'I am in Israel'**
  String get sacredTimeInIsraelTitle;

  /// No description provided for @sacredTimeInIsraelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-day chag if on. Auto-set when you detect or choose a city, flip if you are visiting.'**
  String get sacredTimeInIsraelSubtitle;

  /// No description provided for @sacredTimeLocationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Location updated.'**
  String get sacredTimeLocationUpdated;

  /// No description provided for @sacredTimeLocationPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied. Open system settings to allow.'**
  String get sacredTimeLocationPermissionPermanentlyDenied;

  /// No description provided for @sacredTimeLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get sacredTimeLocationPermissionDenied;

  /// No description provided for @sacredTimeLocationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off on this device.'**
  String get sacredTimeLocationServicesOff;

  /// No description provided for @sacredTimeLocationDetectError.
  ///
  /// In en, this message translates to:
  /// **'Could not detect location: {message}'**
  String sacredTimeLocationDetectError(String message);

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordMinLengthError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLengthError;

  /// No description provided for @passwordsDoNotMatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatchError;

  /// No description provided for @changePasswordFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password. Please try again.'**
  String get changePasswordFailedError;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPasswordLabel;

  /// No description provided for @invalidPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Invalid password. Please try again.'**
  String get invalidPasswordError;

  /// No description provided for @calendarOffsetToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarOffsetToday;

  /// No description provided for @dayNameShabbos.
  ///
  /// In en, this message translates to:
  /// **'Shabbos'**
  String get dayNameShabbos;

  /// No description provided for @statusPendingTapToAccept.
  ///
  /// In en, this message translates to:
  /// **'Pending — tap to accept'**
  String get statusPendingTapToAccept;

  /// No description provided for @calendarOffsetDay.
  ///
  /// In en, this message translates to:
  /// **'Day {offset}'**
  String calendarOffsetDay(String offset);

  /// No description provided for @calendarDirectionForward.
  ///
  /// In en, this message translates to:
  /// **'FORWARD'**
  String get calendarDirectionForward;

  /// No description provided for @calendarDirectionBackwards.
  ///
  /// In en, this message translates to:
  /// **'BACKWARDS'**
  String get calendarDirectionBackwards;

  /// No description provided for @calendarDirectionToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get calendarDirectionToday;

  /// No description provided for @calendarOffsetDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day} other{{count} Days}}'**
  String calendarOffsetDaysCount(int count);

  /// No description provided for @startingPositionSelectInstruction.
  ///
  /// In en, this message translates to:
  /// **'Select the {itemLabel} you are currently up to.'**
  String startingPositionSelectInstruction(String itemLabel);

  /// No description provided for @searchFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search {label}…'**
  String searchFieldHint(String label);

  /// No description provided for @cityPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get cityPickerTitle;

  /// No description provided for @cityPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Type a city name…'**
  String get cityPickerHint;

  /// No description provided for @schedulerStudyLabel.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get schedulerStudyLabel;

  /// No description provided for @schedulerReviewOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Review only'**
  String get schedulerReviewOnlyLabel;

  /// No description provided for @schedulerPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get schedulerPerDay;

  /// No description provided for @schedulerPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Per week'**
  String get schedulerPerWeek;

  /// No description provided for @schedulerPerakimLabel.
  ///
  /// In en, this message translates to:
  /// **'Perakim'**
  String get schedulerPerakimLabel;

  /// No description provided for @schedulerPesukimLabel.
  ///
  /// In en, this message translates to:
  /// **'Pesukim'**
  String get schedulerPesukimLabel;

  /// No description provided for @schedulerAmudimLabel.
  ///
  /// In en, this message translates to:
  /// **'Amudim'**
  String get schedulerAmudimLabel;

  /// No description provided for @schedulerDafimLabel.
  ///
  /// In en, this message translates to:
  /// **'Dafim'**
  String get schedulerDafimLabel;

  /// No description provided for @schedulerDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get schedulerDeadlineLabel;

  /// No description provided for @schedulerPaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get schedulerPaceLabel;

  /// No description provided for @schedulerNoDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'No deadline'**
  String get schedulerNoDeadlineLabel;

  /// No description provided for @schedulerGoalHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Bar Mitzvah, Yahrzeit, Siyum'**
  String get schedulerGoalHint;

  /// No description provided for @schedulerSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get schedulerSelectDate;

  /// No description provided for @schedulerPickDeadlineFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a deadline first.'**
  String get schedulerPickDeadlineFirst;

  /// No description provided for @schedulerDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get schedulerDaysLabel;

  /// No description provided for @schedulerWeeksLabel.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get schedulerWeeksLabel;

  /// No description provided for @profilesEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profilesEditLabel;

  /// No description provided for @profilesDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profilesDeleteLabel;

  /// No description provided for @profilesChooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose Avatar'**
  String get profilesChooseAvatar;

  /// No description provided for @profilesAddLearner.
  ///
  /// In en, this message translates to:
  /// **'Add Learner'**
  String get profilesAddLearner;

  /// No description provided for @profilesEditLearner.
  ///
  /// In en, this message translates to:
  /// **'Edit Learner'**
  String get profilesEditLearner;

  /// No description provided for @profilesChildLabel.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get profilesChildLabel;

  /// No description provided for @profilesAdultLabel.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get profilesAdultLabel;

  /// No description provided for @profilesEnterLearnerName.
  ///
  /// In en, this message translates to:
  /// **'Enter learner name'**
  String get profilesEnterLearnerName;

  /// No description provided for @profilesNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profilesNameFieldLabel;

  /// No description provided for @deleteProfileLastTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your only profile?'**
  String get deleteProfileLastTitle;

  /// No description provided for @deleteProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? All learning data for this profile will be permanently lost.'**
  String deleteProfileBody(String name);

  /// No description provided for @deleteProfileLastBody.
  ///
  /// In en, this message translates to:
  /// **'This is your only profile. Deleting \"{name}\" will erase every track, completion, and lifetime entry on this account. You will need to create a new profile before you can keep learning.'**
  String deleteProfileLastBody(String name);

  /// No description provided for @deleteProfileLastConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get deleteProfileLastConfirm;

  /// No description provided for @trackNameThisTrack.
  ///
  /// In en, this message translates to:
  /// **'Name This Track'**
  String get trackNameThisTrack;

  /// No description provided for @trackNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Track Name'**
  String get trackNameLabel;

  /// No description provided for @trackAddLabel.
  ///
  /// In en, this message translates to:
  /// **'ADD TRACK'**
  String get trackAddLabel;

  /// No description provided for @trackDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Track?'**
  String get trackDeleteTitle;

  /// No description provided for @trackMarkContentDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Content Done'**
  String get trackMarkContentDone;

  /// No description provided for @trackReorderContent.
  ///
  /// In en, this message translates to:
  /// **'Reorder Content'**
  String get trackReorderContent;

  /// No description provided for @trackReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace your {label} track?'**
  String trackReplaceTitle(String label);

  /// No description provided for @bulkMarkCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Mark Complete'**
  String get bulkMarkCompleteTitle;

  /// No description provided for @bulkMarkedComplete.
  ///
  /// In en, this message translates to:
  /// **'Marked {count} items as complete'**
  String bulkMarkedComplete(int count);

  /// No description provided for @bulkMarkConfirmBulkTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Bulk Mark'**
  String get bulkMarkConfirmBulkTitle;

  /// No description provided for @bulkMarkingCompletions.
  ///
  /// In en, this message translates to:
  /// **'Marking completions...'**
  String get bulkMarkingCompletions;

  /// No description provided for @bulkMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get bulkMarkDone;

  /// No description provided for @bulkMarkSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get bulkMarkSkip;

  /// No description provided for @bulkMarkPriorLearning.
  ///
  /// In en, this message translates to:
  /// **'Mark Prior Learning'**
  String get bulkMarkPriorLearning;

  /// No description provided for @completionButtonCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completionButtonCompleted;

  /// No description provided for @completionButtonMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get completionButtonMarkComplete;

  /// No description provided for @upgradeToCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Cloud'**
  String get upgradeToCloudTitle;

  /// No description provided for @upgradeToCloudButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Cloud'**
  String get upgradeToCloudButton;

  /// No description provided for @upgradeToCloudCancelKeepOffline.
  ///
  /// In en, this message translates to:
  /// **'Cancel — keep offline account'**
  String get upgradeToCloudCancelKeepOffline;

  /// No description provided for @scopeSelectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get scopeSelectionSave;

  /// No description provided for @scopeSelectionTrackEntireCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Track Entire Curriculum'**
  String get scopeSelectionTrackEntireCurriculum;

  /// No description provided for @scopeSelectionChooseHierarchyLevel.
  ///
  /// In en, this message translates to:
  /// **'Choose which hierarchy level to filter by'**
  String get scopeSelectionChooseHierarchyLevel;

  /// No description provided for @scopeSelectionChangeLevel.
  ///
  /// In en, this message translates to:
  /// **'Change Level'**
  String get scopeSelectionChangeLevel;

  /// No description provided for @curriculumSettingsLoadingProgram.
  ///
  /// In en, this message translates to:
  /// **'Loading program...'**
  String get curriculumSettingsLoadingProgram;

  /// No description provided for @curriculumSettingsProgramTitle.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get curriculumSettingsProgramTitle;

  /// No description provided for @curriculumSettingsProgramError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String curriculumSettingsProgramError(String error);

  /// No description provided for @curriculumSettingsChangeProgram.
  ///
  /// In en, this message translates to:
  /// **'Change Program'**
  String get curriculumSettingsChangeProgram;

  /// No description provided for @curriculumSettingsChangeProgramSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to a different learning program'**
  String get curriculumSettingsChangeProgramSubtitle;

  /// No description provided for @curriculumSettingsDontSeeProgram.
  ///
  /// In en, this message translates to:
  /// **'Don\'t see your program?'**
  String get curriculumSettingsDontSeeProgram;

  /// No description provided for @curriculumSettingsRequestProgram.
  ///
  /// In en, this message translates to:
  /// **'Request a new program'**
  String get curriculumSettingsRequestProgram;

  /// No description provided for @deleteAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountDialogTitle;

  /// No description provided for @deleteAccountTypeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm:'**
  String get deleteAccountTypeConfirm;

  /// No description provided for @deleteAccountHint.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountHint;

  /// No description provided for @deleteAccountWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and cannot be undone. All your data will be deleted.'**
  String get deleteAccountWarningBody;

  /// No description provided for @deleteAccountReauthPassword.
  ///
  /// In en, this message translates to:
  /// **'You will be asked to re-enter your password to confirm your identity.'**
  String get deleteAccountReauthPassword;

  /// No description provided for @deleteAccountReauthProvider.
  ///
  /// In en, this message translates to:
  /// **'You will be asked to sign in with {provider} to confirm your identity.'**
  String deleteAccountReauthProvider(String provider);

  /// No description provided for @backupLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {timeAgo}'**
  String backupLastSynced(String timeAgo);

  /// No description provided for @backupSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get backupSyncing;

  /// No description provided for @backupPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count} changes pending'**
  String backupPendingChanges(int count);

  /// No description provided for @backupSyncError.
  ///
  /// In en, this message translates to:
  /// **'Sync error: {message}'**
  String backupSyncError(String message);

  /// No description provided for @backupSyncTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get backupSyncTapToRetry;

  /// Friendly message shown instead of a raw exception string when cloud sync fails (ST-4).
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is temporarily unavailable.'**
  String get backupSyncCloudUnavailable;

  /// Friendly message shown when the outbox has stuck rows, replacing the raw 'N row(s) stuck after 3+ attempts' English string (ST-4).
  ///
  /// In en, this message translates to:
  /// **'Some changes are waiting to sync. We\'ll retry automatically.'**
  String get backupSyncOutboxStuck;

  /// No description provided for @backupConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get backupConnecting;

  /// No description provided for @backupOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get backupOffline;

  /// No description provided for @backupSyncPaused.
  ///
  /// In en, this message translates to:
  /// **'Sync paused — {count} queued. {reason}'**
  String backupSyncPaused(int count, String reason);

  /// No description provided for @backupSyncPausedNoCount.
  ///
  /// In en, this message translates to:
  /// **'Sync paused. {reason}'**
  String backupSyncPausedNoCount(String reason);

  /// No description provided for @backupUpgradeToCloud.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Cloud'**
  String get backupUpgradeToCloud;

  /// No description provided for @backupSyncCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Sync'**
  String get backupSyncCardTitle;

  /// No description provided for @backupSyncCardBody.
  ///
  /// In en, this message translates to:
  /// **'Your learning progress is currently LOCAL ONLY. Upgrade to sync across all devices.'**
  String get backupSyncCardBody;

  /// No description provided for @reauthDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Identity'**
  String get reauthDialogTitle;

  /// No description provided for @reauthDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password to continue.'**
  String get reauthDialogBody;

  /// No description provided for @reauthVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get reauthVerify;

  /// No description provided for @linkAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Account'**
  String get linkAccountTitle;

  /// No description provided for @linkAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add another sign-in method to your account.'**
  String get linkAccountSubtitle;

  /// No description provided for @linkAccountGoogleLabel.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get linkAccountGoogleLabel;

  /// No description provided for @linkAccountEmailPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Email/Password'**
  String get linkAccountEmailPasswordLabel;

  /// No description provided for @linkAccountLinkEmail.
  ///
  /// In en, this message translates to:
  /// **'Link Email'**
  String get linkAccountLinkEmail;

  /// No description provided for @linkAccountAllLinked.
  ///
  /// In en, this message translates to:
  /// **'All available sign-in methods are already linked.'**
  String get linkAccountAllLinked;

  /// No description provided for @linkAccountGoogleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Google account linked successfully.'**
  String get linkAccountGoogleSuccess;

  /// No description provided for @linkAccountEmailSuccess.
  ///
  /// In en, this message translates to:
  /// **'Email/password account linked successfully.'**
  String get linkAccountEmailSuccess;

  /// No description provided for @changePasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordDialogTitle;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordButton;

  /// No description provided for @accountDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeletedTitle;

  /// No description provided for @signOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutLabel;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? Your data will be preserved for when you sign back in.'**
  String get signOutConfirmBody;

  /// No description provided for @connectionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLostTitle;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainButton;

  /// No description provided for @createOfflineAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Offline Account'**
  String get createOfflineAccount;

  /// No description provided for @onboardingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get onboardingConfirm;

  /// No description provided for @onboardingStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get onboardingStartLearning;

  /// No description provided for @onboardingAddAnotherTrack.
  ///
  /// In en, this message translates to:
  /// **'Add Another Track'**
  String get onboardingAddAnotherTrack;

  /// No description provided for @onboardingAddAnotherLearner.
  ///
  /// In en, this message translates to:
  /// **'Add Another Learner'**
  String get onboardingAddAnotherLearner;

  /// No description provided for @onboardingSkipNoReview.
  ///
  /// In en, this message translates to:
  /// **'Skip (no review)'**
  String get onboardingSkipNoReview;

  /// No description provided for @onboardingMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get onboardingMarkCompleted;

  /// No description provided for @onboardingStartingPosition.
  ///
  /// In en, this message translates to:
  /// **'Starting Position'**
  String get onboardingStartingPosition;

  /// No description provided for @onboardingStudyDays.
  ///
  /// In en, this message translates to:
  /// **'Study Days'**
  String get onboardingStudyDays;

  /// No description provided for @stageNameLimud.
  ///
  /// In en, this message translates to:
  /// **'לימוד'**
  String get stageNameLimud;

  /// No description provided for @stageNameChazaraAleph.
  ///
  /// In en, this message translates to:
  /// **'חזרה א׳'**
  String get stageNameChazaraAleph;

  /// No description provided for @stageNameChazaraBet.
  ///
  /// In en, this message translates to:
  /// **'חזרה ב׳'**
  String get stageNameChazaraBet;

  /// No description provided for @actionMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get actionMarkCompleted;

  /// No description provided for @actionSkipNoReview.
  ///
  /// In en, this message translates to:
  /// **'Skip (no review)'**
  String get actionSkipNoReview;

  /// No description provided for @studyDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Days'**
  String get studyDaysTitle;

  /// No description provided for @studyDaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which days do you learn?'**
  String get studyDaysSubtitle;

  /// No description provided for @studyDaysPerWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 study day per week} other{{count} study days per week}}'**
  String studyDaysPerWeekLabel(int count);

  /// No description provided for @studyDayConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'{curriculumName} Study Days'**
  String studyDayConfigTitle(String curriculumName);

  /// No description provided for @studyDayConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which days include new learning and which are for review only.'**
  String get studyDayConfigSubtitle;

  /// No description provided for @studyDayConfigAllDaysStudy.
  ///
  /// In en, this message translates to:
  /// **'All days are study days for this track.'**
  String get studyDayConfigAllDaysStudy;

  /// No description provided for @studyDaysSetByProgram.
  ///
  /// In en, this message translates to:
  /// **'Study days set by {programName}'**
  String studyDaysSetByProgram(String programName);

  /// No description provided for @startingPositionTitle.
  ///
  /// In en, this message translates to:
  /// **'Starting Position'**
  String get startingPositionTitle;

  /// No description provided for @startingPositionHint.
  ///
  /// In en, this message translates to:
  /// **'Can start up to 30 days back from today'**
  String get startingPositionHint;

  /// No description provided for @startingPositionWhereAreYou.
  ///
  /// In en, this message translates to:
  /// **'Where are you in {programName}?'**
  String startingPositionWhereAreYou(String programName);

  /// No description provided for @priorLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark Prior Learning'**
  String get priorLearningTitle;

  /// No description provided for @priorLearningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Do you want to mark parts you already learned as completed?'**
  String get priorLearningSubtitle;

  /// No description provided for @goalPickDeadlineFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a deadline first.'**
  String get goalPickDeadlineFirst;

  /// No description provided for @trackSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save track. Please try again.'**
  String get trackSaveError;

  /// No description provided for @pacePerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get pacePerDay;

  /// No description provided for @pacePerWeek.
  ///
  /// In en, this message translates to:
  /// **'Per week'**
  String get pacePerWeek;

  /// No description provided for @goalTypeDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get goalTypeDeadline;

  /// No description provided for @goalTypePace.
  ///
  /// In en, this message translates to:
  /// **'Pace'**
  String get goalTypePace;

  /// No description provided for @goalTypeNoDeadline.
  ///
  /// In en, this message translates to:
  /// **'No deadline'**
  String get goalTypeNoDeadline;

  /// No description provided for @goalEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get goalEditTitle;

  /// No description provided for @goalNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Goal'**
  String get goalNewTitle;

  /// No description provided for @goalUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update Goal'**
  String get goalUpdateButton;

  /// No description provided for @goalCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Goal'**
  String get goalCreateButton;

  /// No description provided for @goalDeadlineDatePickerHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose a date'**
  String get goalDeadlineDatePickerHint;

  /// No description provided for @goalDeadlineOccasionLabel.
  ///
  /// In en, this message translates to:
  /// **'Occasion (optional)'**
  String get goalDeadlineOccasionLabel;

  /// No description provided for @goalDeadlineOccasionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Bar Mitzvah, Yahrzeit, Siyum'**
  String get goalDeadlineOccasionHint;

  /// No description provided for @goalDeadlinePassed.
  ///
  /// In en, this message translates to:
  /// **'Deadline has passed'**
  String get goalDeadlinePassed;

  /// No description provided for @goalDeadlinePaceItems.
  ///
  /// In en, this message translates to:
  /// **'~{pace} items per day'**
  String goalDeadlinePaceItems(int pace);

  /// No description provided for @goalDeadlineItemsInDays.
  ///
  /// In en, this message translates to:
  /// **'{items} items in {days} days'**
  String goalDeadlineItemsInDays(int items, int days);

  /// No description provided for @goalPaceHowMany.
  ///
  /// In en, this message translates to:
  /// **'How many {unit} per {period}?'**
  String goalPaceHowMany(String unit, String period);

  /// No description provided for @goalPaceInputLabel.
  ///
  /// In en, this message translates to:
  /// **'{unit} {period}'**
  String goalPaceInputLabel(String unit, String period);

  /// No description provided for @goalPaceProjectedCompletion.
  ///
  /// In en, this message translates to:
  /// **'Projected completion: {date}'**
  String goalPaceProjectedCompletion(String date);

  /// No description provided for @goalPaceItemsInDays.
  ///
  /// In en, this message translates to:
  /// **'{items} {unit} in ~{days} days'**
  String goalPaceItemsInDays(int items, String unit, int days);

  /// No description provided for @goalTargetPercentOnly.
  ///
  /// In en, this message translates to:
  /// **'Complete {percent}% of the material'**
  String goalTargetPercentOnly(int percent);

  /// No description provided for @goalTargetPercentWithCount.
  ///
  /// In en, this message translates to:
  /// **'Complete {percent}% of the material ({done} of {total} items)'**
  String goalTargetPercentWithCount(int percent, int done, int total);

  /// No description provided for @goalLearningUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Learning unit'**
  String get goalLearningUnitLabel;

  /// No description provided for @goalNoPressureLabel.
  ///
  /// In en, this message translates to:
  /// **'Learn at your own pace with no time pressure.'**
  String get goalNoPressureLabel;

  /// No description provided for @trackSetGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Set Goal'**
  String get trackSetGoalLabel;

  /// No description provided for @trackEditGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Goal'**
  String get trackEditGoalLabel;

  /// No description provided for @goalSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Goal saved'**
  String get goalSavedSnack;

  /// No description provided for @goalRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Goal removed'**
  String get goalRemovedSnack;

  /// No description provided for @goalRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove Goal'**
  String get goalRemoveButton;

  /// No description provided for @unitPerakim.
  ///
  /// In en, this message translates to:
  /// **'Perakim'**
  String get unitPerakim;

  /// No description provided for @unitPesukim.
  ///
  /// In en, this message translates to:
  /// **'Pesukim'**
  String get unitPesukim;

  /// No description provided for @unitAmudim.
  ///
  /// In en, this message translates to:
  /// **'Amudim'**
  String get unitAmudim;

  /// No description provided for @unitDafim.
  ///
  /// In en, this message translates to:
  /// **'Dafim'**
  String get unitDafim;

  /// No description provided for @tasksUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load tasks'**
  String get tasksUnableToLoad;

  /// No description provided for @tasksAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get tasksAllCaughtUp;

  /// No description provided for @tasksNoTasksRemainingToday.
  ///
  /// In en, this message translates to:
  /// **'No tasks remaining for today.'**
  String get tasksNoTasksRemainingToday;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Item} other{{count} Items}}'**
  String itemsCount(int count);

  /// No description provided for @scopeSelectionCountSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 selected} other{{count} selected}}'**
  String scopeSelectionCountSelected(int count);

  /// No description provided for @scopeSelectionItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item} other{{count} items}}'**
  String scopeSelectionItemCount(int count);

  /// No description provided for @reviewStageDayDelay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day delay} other{{count} day delay}}'**
  String reviewStageDayDelay(int count);

  /// No description provided for @applyToAll.
  ///
  /// In en, this message translates to:
  /// **'Apply to All'**
  String get applyToAll;

  /// No description provided for @trackNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give your track a name to identify it.'**
  String get trackNameSubtitle;

  /// No description provided for @priorLearningChooseSections.
  ///
  /// In en, this message translates to:
  /// **'Choose which sections to mark in {curriculumName}.'**
  String priorLearningChooseSections(String curriculumName);

  /// No description provided for @priorLearningAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Have you already completed some of these sections?'**
  String get priorLearningAlreadyCompleted;

  /// No description provided for @priorLearningMarkEverything.
  ///
  /// In en, this message translates to:
  /// **'Mark everything as finished'**
  String get priorLearningMarkEverything;

  /// No description provided for @priorLearningMarkEverythingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best if you are starting a new review cycle'**
  String get priorLearningMarkEverythingSubtitle;

  /// No description provided for @priorLearningNoFolders.
  ///
  /// In en, this message translates to:
  /// **'No specific folders were selected, but you can still mark all as completed.'**
  String get priorLearningNoFolders;

  /// No description provided for @priorLearningSelectedFolder.
  ///
  /// In en, this message translates to:
  /// **'Selected folder'**
  String get priorLearningSelectedFolder;

  /// No description provided for @scopeSelectionSelectLevel.
  ///
  /// In en, this message translates to:
  /// **'Select {levelName}'**
  String scopeSelectionSelectLevel(String levelName);

  /// No description provided for @activeTracksLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Tracks'**
  String get activeTracksLabel;

  /// No description provided for @activeTracksRunning.
  ///
  /// In en, this message translates to:
  /// **'{count} RUNNING'**
  String activeTracksRunning(int count);

  /// No description provided for @trackDetailConfigGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get trackDetailConfigGoal;

  /// No description provided for @trackDetailConfigItemsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Items remaining'**
  String get trackDetailConfigItemsRemaining;

  /// No description provided for @trackDetailConfigEstFinish.
  ///
  /// In en, this message translates to:
  /// **'Est. finish'**
  String get trackDetailConfigEstFinish;

  /// No description provided for @trackSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String trackSince(String date);

  /// No description provided for @trackEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit Track'**
  String get trackEditLabel;

  /// No description provided for @trackEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Track'**
  String get trackEditTitle;

  /// No description provided for @trackEditSectionName.
  ///
  /// In en, this message translates to:
  /// **'Track Name'**
  String get trackEditSectionName;

  /// No description provided for @trackEditSectionGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get trackEditSectionGoal;

  /// No description provided for @trackEditSectionStudyDays.
  ///
  /// In en, this message translates to:
  /// **'Study Days'**
  String get trackEditSectionStudyDays;

  /// No description provided for @trackEditSectionReview.
  ///
  /// In en, this message translates to:
  /// **'Review (Chazara)'**
  String get trackEditSectionReview;

  /// No description provided for @trackEditGoalTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'Goal type cannot be changed after setup'**
  String get trackEditGoalTypeLocked;

  /// No description provided for @trackEditProgramLocked.
  ///
  /// In en, this message translates to:
  /// **'Review, scope, and study days are managed by the program.'**
  String get trackEditProgramLocked;

  /// No description provided for @trackEditReviewSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'No review'**
  String get trackEditReviewSummaryNone;

  /// No description provided for @trackEditReviewSummaryDays.
  ///
  /// In en, this message translates to:
  /// **'After {delays}'**
  String trackEditReviewSummaryDays(String delays);

  /// No description provided for @trackEditChangeReview.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get trackEditChangeReview;

  /// No description provided for @trackEditSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get trackEditSaveButton;

  /// No description provided for @trackEditNameEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Track name cannot be empty.'**
  String get trackEditNameEmptyError;

  /// No description provided for @trackEditZeroStudyDaysWarning.
  ///
  /// In en, this message translates to:
  /// **'No study days selected — new learning will not be scheduled until you add at least one study day.'**
  String get trackEditZeroStudyDaysWarning;

  /// No description provided for @trackEditConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply changes?'**
  String get trackEditConfirmTitle;

  /// No description provided for @trackEditConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to future learning only. Existing completions are not affected.'**
  String get trackEditConfirmBody;

  /// No description provided for @trackEditClearOverdueButton.
  ///
  /// In en, this message translates to:
  /// **'Clear Overdue'**
  String get trackEditClearOverdueButton;

  /// No description provided for @trackEditClearOverdueConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear overdue items?'**
  String get trackEditClearOverdueConfirmTitle;

  /// No description provided for @trackEditClearOverdueConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Overdue items will be removed from your dashboard. They won\'t be marked as done.'**
  String get trackEditClearOverdueConfirmBody;

  /// No description provided for @trackDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete Track'**
  String get trackDeleteLabel;

  /// No description provided for @trackDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{name}\"? All progress and data for this track will be removed. This cannot be undone.'**
  String trackDeleteContent(String name);

  /// No description provided for @deleteTrackArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Track'**
  String get deleteTrackArchiveTitle;

  /// No description provided for @deleteTrackArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'What should happen to your completion history?'**
  String get deleteTrackArchiveBody;

  /// No description provided for @parentDeleteTrackArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'What should happen to your child\'s completion history?'**
  String get parentDeleteTrackArchiveBody;

  /// No description provided for @deleteTrackArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive (keep history)'**
  String get deleteTrackArchive;

  /// No description provided for @deleteTrackWipe.
  ///
  /// In en, this message translates to:
  /// **'Delete and wipe history'**
  String get deleteTrackWipe;

  /// No description provided for @notificationReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Reminder'**
  String get notificationReminderTitle;

  /// No description provided for @notificationReminderBody.
  ///
  /// In en, this message translates to:
  /// **'You have {taskCount, plural, =1{1 task} other{{taskCount} tasks}} across {curriculumCount, plural, =1{1 curriculum} other{{curriculumCount} curricula}} today'**
  String notificationReminderBody(int taskCount, int curriculumCount);

  /// No description provided for @startingPositionTargetDate.
  ///
  /// In en, this message translates to:
  /// **'TARGET DATE'**
  String get startingPositionTargetDate;

  /// No description provided for @goalPaceOrDeadlineTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your pace or deadline?'**
  String get goalPaceOrDeadlineTitle;

  /// No description provided for @goalPaceOrDeadlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a goal.'**
  String get goalPaceOrDeadlineSubtitle;

  /// No description provided for @goalTargetPace.
  ///
  /// In en, this message translates to:
  /// **'Target Pace'**
  String get goalTargetPace;

  /// No description provided for @goalPaceDescriptionLine.
  ///
  /// In en, this message translates to:
  /// **'{unit} {period}'**
  String goalPaceDescriptionLine(String unit, String period);

  /// No description provided for @goalEstimatedFinish.
  ///
  /// In en, this message translates to:
  /// **'Estimated finish: {date}'**
  String goalEstimatedFinish(String date);

  /// No description provided for @goalSetDeadline.
  ///
  /// In en, this message translates to:
  /// **'Set Deadline'**
  String get goalSetDeadline;

  /// No description provided for @reviewScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Schedule'**
  String get reviewScheduleTitle;

  /// No description provided for @reviewScheduleSetByProgram.
  ///
  /// In en, this message translates to:
  /// **'Review stages set by {programName}'**
  String reviewScheduleSetByProgram(String programName);

  /// No description provided for @reviewScheduleFixedHint.
  ///
  /// In en, this message translates to:
  /// **'This schedule is fixed by the program and cannot be edited.'**
  String get reviewScheduleFixedHint;

  /// No description provided for @reviewScheduleNoStages.
  ///
  /// In en, this message translates to:
  /// **'No review stages are configured for this program.'**
  String get reviewScheduleNoStages;

  /// No description provided for @reviewScheduleAfterOneDay.
  ///
  /// In en, this message translates to:
  /// **'After 1 day'**
  String get reviewScheduleAfterOneDay;

  /// No description provided for @reviewScheduleAfterNDays.
  ///
  /// In en, this message translates to:
  /// **'After {count} days'**
  String reviewScheduleAfterNDays(String count);

  /// No description provided for @reviewScheduleScheduledByProgram.
  ///
  /// In en, this message translates to:
  /// **'Scheduled by program'**
  String get reviewScheduleScheduledByProgram;

  /// No description provided for @chazaraCustomCycle.
  ///
  /// In en, this message translates to:
  /// **'Custom Cycle'**
  String get chazaraCustomCycle;

  /// No description provided for @chazaraSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Sessions'**
  String chazaraSessionsCount(int count);

  /// No description provided for @chazaraAddNew.
  ///
  /// In en, this message translates to:
  /// **'ADD NEW'**
  String get chazaraAddNew;

  /// No description provided for @termChazara.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get termChazara;

  /// No description provided for @termBubbleChazara.
  ///
  /// In en, this message translates to:
  /// **'CHAZARA'**
  String get termBubbleChazara;

  /// No description provided for @termReviewSection.
  ///
  /// In en, this message translates to:
  /// **'REVIEW SECTION'**
  String get termReviewSection;

  /// No description provided for @termDaf.
  ///
  /// In en, this message translates to:
  /// **'Daf'**
  String get termDaf;

  /// No description provided for @termAmud.
  ///
  /// In en, this message translates to:
  /// **'Amud'**
  String get termAmud;

  /// No description provided for @termPerek.
  ///
  /// In en, this message translates to:
  /// **'Perek'**
  String get termPerek;

  /// No description provided for @termMishnah.
  ///
  /// In en, this message translates to:
  /// **'Mishna'**
  String get termMishnah;

  /// No description provided for @termSeder.
  ///
  /// In en, this message translates to:
  /// **'Seder'**
  String get termSeder;

  /// No description provided for @termMasechta.
  ///
  /// In en, this message translates to:
  /// **'Masechta'**
  String get termMasechta;

  /// No description provided for @termChumash.
  ///
  /// In en, this message translates to:
  /// **'Chumash'**
  String get termChumash;

  /// No description provided for @termTalmidChochom.
  ///
  /// In en, this message translates to:
  /// **'Talmid Chochom'**
  String get termTalmidChochom;

  /// No description provided for @termTalmidChochomCaps.
  ///
  /// In en, this message translates to:
  /// **'TALMID CHOCHOM'**
  String get termTalmidChochomCaps;

  /// No description provided for @termStageLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get termStageLearn;

  /// No description provided for @termStageChazaraPrefix.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get termStageChazaraPrefix;

  /// No description provided for @authSignInTimeout.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is taking too long. Check your connection and try again.'**
  String get authSignInTimeout;

  /// No description provided for @reauthGoogleTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm with Google to delete your account'**
  String get reauthGoogleTitle;

  /// No description provided for @reauthGoogleBody.
  ///
  /// In en, this message translates to:
  /// **'We need you to sign in with Google one more time to confirm it\'s really you. After signing in, your account and all data will be permanently deleted.'**
  String get reauthGoogleBody;

  /// No description provided for @reauthGoogleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to Google'**
  String get reauthGoogleContinue;

  /// No description provided for @deletingAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deletingAccountTitle;

  /// No description provided for @deletingAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This may take a few seconds. Please don\'t close the app.'**
  String get deletingAccountBody;

  /// No description provided for @deletingAccountError.
  ///
  /// In en, this message translates to:
  /// **'Deletion encountered an issue. You have been signed out.'**
  String get deletingAccountError;

  /// No description provided for @itemsLearnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Items Learned'**
  String get itemsLearnedTitle;

  /// No description provided for @itemsLearnedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track completions by curriculum'**
  String get itemsLearnedSubtitle;

  /// No description provided for @itemsLearnedNoCurricula.
  ///
  /// In en, this message translates to:
  /// **'No track completions yet'**
  String get itemsLearnedNoCurricula;

  /// No description provided for @itemsLearnedNoCurriculaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete daily tasks to see your progress here'**
  String get itemsLearnedNoCurriculaSubtitle;

  /// No description provided for @itemsLearnedOf.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total}'**
  String itemsLearnedOf(int completed, int total);

  /// Title of the OverallStatsCard on the Curriculum Progress screen.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get overallProgressCardTitle;

  /// Row label in OverallStatsCard for the total number of items in the curriculum.
  ///
  /// In en, this message translates to:
  /// **'Total items'**
  String get overallProgressStatTotalItems;

  /// Row label in OverallStatsCard for the count of items that have completed every stage.
  ///
  /// In en, this message translates to:
  /// **'Completed all stages'**
  String get overallProgressStatCompletedAllStages;

  /// Row label in OverallStatsCard for the count of items currently in progress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get overallProgressStatInProgress;

  /// Row label in OverallStatsCard for the count of items not yet started.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get overallProgressStatNotStarted;

  /// Section heading in CurriculumProgressScreen above the per-level hierarchy cards.
  ///
  /// In en, this message translates to:
  /// **'Breakdown by Level'**
  String get curriculumProgressBreakdownByLevel;

  /// Loading placeholder shown in CurriculumProgressScreen while progress data is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading progress...'**
  String get curriculumProgressLoading;

  /// Error message shown in CurriculumProgressScreen when progress data fails to load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load progress: {error}'**
  String curriculumProgressLoadFailed(String error);

  /// Lens label for the engagement tier (live-only completions) — Recent Activity screen and Progress hub tile.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get tierLensRecentActivity;

  /// Lens label for the achievement tier (track-scoped siyumim/milestones) — Siyumim & Milestones screen and Progress hub tile.
  ///
  /// In en, this message translates to:
  /// **'Siyumim & Milestones'**
  String get tierLensSiyumimMilestones;

  /// Lens label for the lifetime tier (all sources — live + bulkInTrack + lifetimeOnly) — Lifetime Knowledge screen and Progress hub tile.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Knowledge'**
  String get tierLensLifetimeKnowledge;

  /// Child-mode StreakWidget headline showing the current streak length. ICU plural so 1 reads '1 day streak!' not '1 days'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day streak!} other{{count} day streak!}}'**
  String streakWidgetDayStreak(int count);

  /// Child-mode StreakWidget sub-line showing the longest streak. ICU plural so 1 reads 'Best: 1 day' not 'Best: 1 days'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Best: 1 day} other{Best: {count} days}}'**
  String streakWidgetBest(int count);

  /// Eyebrow label on the daily-task scheduler goal banner, above the task count. Uppercase styling is applied by the text theme, not the string.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S GOAL'**
  String get schedulerTodaysGoal;

  /// Headline count on the scheduler goal banner — number of tasks scheduled for today. ICU plural so count==1 reads '1 task today' not '1 tasks today'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task today} other{{count} tasks today}}'**
  String schedulerGoalTaskCount(int count);

  /// Engagement-tier counter — current consecutive-day streak. Appears in the three-counter header row on Dashboard and Progress hub. ICU plural so count==1 stays grammatical ('1-day streak').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count}-day streak} other{{count}-day streak}}'**
  String tierCounterStreakDays(int count);

  /// Achievement-tier counter — total siyumim earned. {siyumimTerm} is the toggle-aware domain term (Siyumim / סיומים) and is already a plural noun, so the noun word is unchanged across counts; ICU plural is kept for parity with the Hebrew dual.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} {siyumimTerm} earned} other{{count} {siyumimTerm} earned}}'**
  String tierCounterSiyumimEarned(int count, String siyumimTerm);

  /// Lifetime-tier counter — total distinct items the user has ever marked learned (across live + bulkInTrack + lifetimeOnly). ICU plural so count==1 reads '1 item in lifetime'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item in lifetime} other{{count} items in lifetime}}'**
  String tierCounterLifetimeItems(int count);

  /// Child-mode points counter — appears as the fourth counter in the header row when child mode is active. ICU plural so count==1 reads '1 pt'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} pt} other{{count} pts}}'**
  String tierCounterPoints(int count);

  /// Tile-row label (short noun) under the big streak count. The big number above already shows the count, so the label is just the noun — kept short so it fits the tile width without truncation.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get tierTileLabelStreak;

  /// Tile-row label (short noun) under the big siyumim count. Renders the locale-aware siyumim term (Latin or Hebrew script per the Hebrew Terms toggle).
  ///
  /// In en, this message translates to:
  /// **'{siyumimTerm}'**
  String tierTileLabelSiyumim(String siyumimTerm);

  /// Tile-row label (short noun) under the big lifetime-items count. Refers to Lifetime Knowledge — all items the user has ever marked learned.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get tierTileLabelLifetime;

  /// Tile-row label (short noun) under the big points count. Child-mode only.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get tierTileLabelPoints;

  /// Canonical vocabulary: initial study (stage 1) of one item. Lean-hard transliteration in English-default; Hebrew script when the Hebrew Terms toggle is ON.
  ///
  /// In en, this message translates to:
  /// **'Limud'**
  String get limud;

  /// Canonical vocabulary: review (stage 2+) of one item. Lean-hard transliteration in English-default; Hebrew script when the Hebrew Terms toggle is ON.
  ///
  /// In en, this message translates to:
  /// **'Chazara'**
  String get chazara;

  /// Canonical vocabulary: plural of chazara — total review events ever. Used in Lifetime Knowledge totals (`{count} total chazaros`).
  ///
  /// In en, this message translates to:
  /// **'Chazaros'**
  String get chazaros;

  /// Canonical vocabulary: finish-celebration of a whole unit (e.g. masechta, sefer). Lean-hard transliteration in English-default; Hebrew script when toggle is ON.
  ///
  /// In en, this message translates to:
  /// **'Siyum'**
  String get siyum;

  /// Canonical vocabulary: plural of siyum.
  ///
  /// In en, this message translates to:
  /// **'Siyumim'**
  String get siyumim;

  /// Canonical vocabulary: umbrella term for any achievement (siyum, seder-complete, curriculum-complete).
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get milestone;

  /// Canonical vocabulary: plural of milestone. Used as a screen/section heading.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestoneAggregate;

  /// Canonical vocabulary: per-track progress percentage (engagement + achievement). Distinct from `lifetimeLabel` which reflects all sources.
  ///
  /// In en, this message translates to:
  /// **'Track progress'**
  String get trackProgress;

  /// Action tile in Track Detail screen to bulk-mark prior learning (lifetime-only credit, no streak/points).
  ///
  /// In en, this message translates to:
  /// **'Mark as previously learned'**
  String get trackMarkPreviouslyLearned;

  /// Canonical vocabulary: lifetime label as used in dual-track-label dashboards (Track progress vs Lifetime). Distinct from `tierLensLifetimeKnowledge` (the lens screen title).
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetimeLabel;

  /// Short form of `tierLensRecentActivity` for use in compact UI (e.g. breadcrumbs).
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivityShort;

  /// Title-case 'Streak' label — distinct from the existing all-caps `streak` key. Used in recent-activity screen section headers.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakLabel;

  /// Subtitle clarifying that the headline streak number is profile-global (across every curriculum), while the calendar dots follow the active curriculum filter.
  ///
  /// In en, this message translates to:
  /// **'Streak across all curricula'**
  String get labelStreakAcrossAllCurricula;

  /// No description provided for @paceAheadByDays.
  ///
  /// In en, this message translates to:
  /// **'Ahead by {count} days'**
  String paceAheadByDays(int count);

  /// No description provided for @paceOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On pace'**
  String get paceOnTrack;

  /// IL-3 fix: ICU plural so 1 reads 'Behind by 1 day' not 'Behind by 1 days'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Behind by 1 day} other{Behind by {count} days}}'**
  String paceBehindByDays(int count);

  /// IL-3 fix: ICU plural so 1 reads '1 item learned' not '1 items learned'. NEW sense: distinct sefariaRefs ever touched (lifetime tier). Distinct from the legacy `itemsLearnedTitle` screen-title key.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item learned} other{{count} items learned}}'**
  String itemsLearnedCount(int count);

  /// IL-3 fix: ICU plural so 1 reads '1 total chazara' not '1 total chazaros'. Lifetime-tier total review count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 total chazara} other{{count} total Chazaros}}'**
  String totalChazaros(int count);

  /// Top-level curriculum-complete celebration — Talmud Bavli.
  ///
  /// In en, this message translates to:
  /// **'Siyum HaShas'**
  String get siyumHaShas;

  /// Top-level curriculum-complete celebration — Chumash (Torah).
  ///
  /// In en, this message translates to:
  /// **'Siyum HaTorah'**
  String get siyumHaTorah;

  /// Top-level curriculum-complete celebration — Mishnayos.
  ///
  /// In en, this message translates to:
  /// **'Siyum HaMishnayos'**
  String get siyumHaMishnayos;

  /// Top-level curriculum-complete celebration — Talmud Yerushalmi.
  ///
  /// In en, this message translates to:
  /// **'Siyum HaYerushalmi'**
  String get siyumHaYerushalmi;

  /// Top-level curriculum-complete celebration — Mishna Berurah.
  ///
  /// In en, this message translates to:
  /// **'Siyum Mishna Berurah'**
  String get siyumMishnaBerurah;

  /// Top-level curriculum-complete celebration — Mishneh Torah (Rambam).
  ///
  /// In en, this message translates to:
  /// **'Siyum Mishneh Torah'**
  String get siyumMishnehTorah;

  /// Top-level curriculum-complete celebration — Nach (Neviim + Ketuvim).
  ///
  /// In en, this message translates to:
  /// **'Siyum Nach'**
  String get siyumNach;

  /// Top-level curriculum-complete celebration — Tanach (Torah + Nach).
  ///
  /// In en, this message translates to:
  /// **'Siyum Tanach'**
  String get siyumTanach;

  /// Top-level curriculum-complete celebration — Mussar curriculum.
  ///
  /// In en, this message translates to:
  /// **'Siyum Mussar'**
  String get siyumMussar;

  /// Mid-level aggregate siyum — completion of a whole seder (e.g. seder of mishnah/talmud).
  ///
  /// In en, this message translates to:
  /// **'Siyum Seder'**
  String get siyumSeder;

  /// Mid-level aggregate siyum — completion of a chelek (e.g. Shulchan Aruch chelek).
  ///
  /// In en, this message translates to:
  /// **'Siyum Chelek'**
  String get siyumChelek;

  /// Unit-level siyum — completion of one masechta (tractate). `{name}` is the masechta name (e.g. Berachos).
  ///
  /// In en, this message translates to:
  /// **'Siyum Masechta {name}'**
  String siyumMasechta(String name);

  /// Unit-level siyum — completion of one sefer. `{name}` is the sefer name (e.g. Bereishis).
  ///
  /// In en, this message translates to:
  /// **'Siyum Sefer {name}'**
  String siyumSefer(String name);

  /// Unit-level siyum — completion of one siman (numbered section, e.g. Shulchan Aruch).
  ///
  /// In en, this message translates to:
  /// **'Siyum Siman {name}'**
  String siyumSiman(String name);

  /// Unit-level siyum — completion of one section of Hilchos (e.g. Hilchos Shabbos).
  ///
  /// In en, this message translates to:
  /// **'Siyum Hilchos {name}'**
  String siyumHilchos(String name);

  /// IL-3 fix: ICU plural so 1 reads '1 curriculum-level siyum' not '1 curriculum-level siyumim'. Top-counter row on the Siyumim & Milestones screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 curriculum-level siyum} other{{count} curriculum-level siyumim}}'**
  String siyumimLevelCurriculum(int count);

  /// IL-3 fix: ICU plural so 1 reads '1 aggregate-level siyum' not '1 aggregate-level siyumim'. Top-counter row on the Siyumim & Milestones screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 aggregate-level siyum} other{{count} aggregate-level siyumim}}'**
  String siyumimLevelAggregate(int count);

  /// IL-3 fix: ICU plural so 1 reads '1 unit-level siyum' not '1 unit-level siyumim'. Top-counter row on the Siyumim & Milestones screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 unit-level siyum} other{{count} unit-level siyumim}}'**
  String siyumimLevelUnit(int count);

  /// Empty-state message rendered by SiyumimGroupedView when the user has no milestones to show.
  ///
  /// In en, this message translates to:
  /// **'No siyumim yet — keep learning!'**
  String get siyumimEmptyState;

  /// Subtitle on an aggregate-level milestone row (Siyum Seder / Siyum Chelek) when every contained unit is complete. `{count}` is the number of contained units; `{date}` is a locale-formatted achievement date — pre-formatted via DateFormat.yMMMd(locale) by the caller.
  ///
  /// In en, this message translates to:
  /// **'All {count} complete · {date}'**
  String siyumimAggregateSubtitle(int count, String date);

  /// Caption shown under the PaceIndicator on the Curriculum Progress screen — disambiguates pace (engagement-tier track learning) from the lifetime tier so users don't conflate the two.
  ///
  /// In en, this message translates to:
  /// **'Pace tracks track learning only.'**
  String get paceLiveLearningOnlyCaption;

  /// Subtitle/explainer for the Bulk Mark wizard (Wave 5 Task #17) — clarifies tier credit so the user understands why streak/points are not impacted.
  ///
  /// In en, this message translates to:
  /// **'These count toward siyumim and lifetime knowledge — but not toward your streak or points.'**
  String get bulkMarkWizardSubtitle;

  /// Confirmation toast after the bulk-mark save completes — used by Wave 5 Task #17.
  ///
  /// In en, this message translates to:
  /// **'{count} items marked as previously learned. They\'ll appear in Lifetime Knowledge and may unlock siyumim.'**
  String bulkMarkConfirmationToast(int count);

  /// Subtitle for the Lifetime Marking screen (Wave 5 Task #18) — clarifies the lifetimeOnly source so users understand the tier credit.
  ///
  /// In en, this message translates to:
  /// **'Items you\'ve learned in your life, outside the app\'s tracks. Counted toward Lifetime Knowledge — not toward siyumim, streak, or points.'**
  String get lifetimeMarkingSubtitle;

  /// Subtitle shown on Recent Activity charts. Track learning = live + bulk-mark in-track (the achievement tier). Lifetime-only imports are the only completions excluded here.
  ///
  /// In en, this message translates to:
  /// **'Counts track learning (live + bulk-mark). Lifetime-only imports appear under Lifetime Knowledge.'**
  String get recentActivityLiveOnlyDisclaimer;

  /// Loading indicator message on the Lifetime Knowledge screen body.
  ///
  /// In en, this message translates to:
  /// **'Loading lifetime knowledge…'**
  String get lifetimeKnowledgeLoading;

  /// Body error message when the Lifetime Knowledge per-curriculum tree fails to load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String lifetimeKnowledgeLoadError(String error);

  /// Header error message when the Lifetime Knowledge header counters fail to load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load counters: {error}'**
  String lifetimeKnowledgeCounterError(String error);

  /// Retry action label on the Lifetime Knowledge error states.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lifetimeKnowledgeRetry;

  /// Source-toggle label on the Lifetime Knowledge screen — includes lifetimeOnly imports.
  ///
  /// In en, this message translates to:
  /// **'All sources'**
  String get lifetimeKnowledgeToggleAllSources;

  /// Source-toggle label on the Lifetime Knowledge screen — restricts to live + bulkInTrack rows.
  ///
  /// In en, this message translates to:
  /// **'Track learning only'**
  String get lifetimeKnowledgeToggleTrackOnly;

  /// Bottom CTA on the Lifetime Knowledge screen — links to the Lifetime Marking flow.
  ///
  /// In en, this message translates to:
  /// **'Add items I learned previously'**
  String get lifetimeKnowledgeAddCta;

  /// Subtitle for the Lifetime Knowledge CTA card — clarifies the tier credit.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Marking — counts toward Lifetime Knowledge.'**
  String get lifetimeKnowledgeAddCtaSubtitle;

  /// Per-leaf provenance label when the leaf was completed live with zero chazaros (rare — usually has a count).
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get provenanceLive;

  /// Per-leaf provenance label for a live-completed leaf with its event count. {count} is the chazaros count (limud + chazaros).
  ///
  /// In en, this message translates to:
  /// **'Live · {count} chazaros'**
  String provenanceLiveChazaros(int count);

  /// Per-leaf provenance label when the leaf entered via a bulk-in-track import (onboarding mark wizard).
  ///
  /// In en, this message translates to:
  /// **'Bulk-marked'**
  String get provenanceBulkMarked;

  /// Per-leaf provenance label when the leaf entered via a lifetime-only import (outside any track).
  ///
  /// In en, this message translates to:
  /// **'Lifetime · imported'**
  String get provenanceLifetimeImported;

  /// Label for the track start date row in the TrackInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get trackInfoStarted;

  /// Label for the goal (target) date row in the TrackInfoCard — only shown for deadline goals.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get trackInfoGoal;

  /// Label for the required pace row in the TrackInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Required pace'**
  String get trackInfoRequiredPace;

  /// Label for the actual pace row in the TrackInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Actual pace'**
  String get trackInfoActualPace;

  /// Sub-caption under the actual pace label clarifying the measurement window and source.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days · track learning only'**
  String get trackInfoActualPaceCaption;

  /// Unit suffix for pace values shown in the TrackInfoCard (e.g. '2.3 items/day').
  ///
  /// In en, this message translates to:
  /// **'items/day'**
  String get trackInfoItemsPerDay;

  /// Label prefix for the elapsed-days segment in the TrackInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get trackInfoElapsed;

  /// Label prefix for the remaining-days segment in the TrackInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get trackInfoRemaining;

  /// Unit suffix for day counts in the TrackInfoCard (e.g. 'Elapsed 14 days').
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get trackInfoDays;

  /// Section heading for the All Time summary card in the Recent Activity screen.
  ///
  /// In en, this message translates to:
  /// **'All-time activity'**
  String get allTimeActivityTitle;

  /// Label for the active-days stat in the All Time summary card (Recent Activity screen).
  ///
  /// In en, this message translates to:
  /// **'Active days'**
  String get allTimeActiveDays;

  /// Stat label in the All Time summary card. {term} is a toggle-aware domain term (e.g. Limud/לימוד or Chazaros/חזרות).
  ///
  /// In en, this message translates to:
  /// **'{term} done'**
  String allTimeTermDone(String term);

  /// Active-days stat phrase in the All Time summary card (Recent Activity screen). ICU plural so count==1 is singular ("1 Active day").
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Active day} other{{count} Active days}}'**
  String recentActivityActiveDaysCount(int count);

  /// Empty-state message shown in the Recent Activity charts when the selected time-range/curriculum filter yields no live completions (charts would otherwise be blank/zeroed).
  ///
  /// In en, this message translates to:
  /// **'No learning activity in this range yet.'**
  String get recentActivityEmptyState;

  /// No description provided for @redeemScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem Prizes'**
  String get redeemScreenTitle;

  /// No description provided for @redeemScreenBalance.
  ///
  /// In en, this message translates to:
  /// **'Your Balance'**
  String get redeemScreenBalance;

  /// No description provided for @redeemScreenNoRewards.
  ///
  /// In en, this message translates to:
  /// **'No prizes configured yet.\nAsk a parent to set some up!'**
  String get redeemScreenNoRewards;

  /// No description provided for @redeemScreenCostLabel.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String redeemScreenCostLabel(int points);

  /// No description provided for @redeemScreenAffordableLabel.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeemScreenAffordableLabel;

  /// No description provided for @redeemScreenCannotAfford.
  ///
  /// In en, this message translates to:
  /// **'Not enough points'**
  String get redeemScreenCannotAfford;

  /// No description provided for @redeemScreenConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem \"{title}\"?'**
  String redeemScreenConfirmTitle(String title);

  /// No description provided for @redeemScreenConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will spend {points} points from your balance.'**
  String redeemScreenConfirmBody(int points);

  /// No description provided for @redeemScreenConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Spend & Redeem'**
  String get redeemScreenConfirmButton;

  /// No description provided for @redeemScreenRequestedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" requested! Ask a parent to approve it.'**
  String redeemScreenRequestedSnackbar(String title);

  /// No description provided for @redeemScreenInsufficientSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Not enough points to redeem this prize.'**
  String get redeemScreenInsufficientSnackbar;

  /// No description provided for @redeemScreenTutorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available (tutor mode)'**
  String get redeemScreenTutorUnavailable;

  /// No description provided for @pendingRedemptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Prizes'**
  String get pendingRedemptionsTitle;

  /// No description provided for @pendingRedemptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending prize requests.'**
  String get pendingRedemptionsEmpty;

  /// Subtitle on the Pending Prizes settings row showing how many redemption requests are awaiting the parent. Reactive — updates live as requests arrive/clear. Shows pendingRedemptionsEmpty when count is 0.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 prize request waiting} other{{count} prize requests waiting}}'**
  String pendingRedemptionsCountSubtitle(int count);

  /// No description provided for @pendingRedemptionsCost.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String pendingRedemptionsCost(int points);

  /// No description provided for @pendingRedemptionsApprove.
  ///
  /// In en, this message translates to:
  /// **'Fulfil'**
  String get pendingRedemptionsApprove;

  /// No description provided for @pendingRedemptionsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get pendingRedemptionsDecline;

  /// No description provided for @pendingRedemptionsFulfilledSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Prize marked as fulfilled!'**
  String get pendingRedemptionsFulfilledSnackbar;

  /// No description provided for @pendingRedemptionsDeclinedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Prize request declined. Points refunded.'**
  String get pendingRedemptionsDeclinedSnackbar;

  /// No description provided for @parentPointsAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust Points'**
  String get parentPointsAdjustTitle;

  /// No description provided for @parentPointsAdjustSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add or deduct points from your child’s balance.'**
  String get parentPointsAdjustSubtitle;

  /// No description provided for @parentPointsAdjustAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add points'**
  String get parentPointsAdjustAddLabel;

  /// No description provided for @parentPointsAdjustDeductLabel.
  ///
  /// In en, this message translates to:
  /// **'Deduct points'**
  String get parentPointsAdjustDeductLabel;

  /// No description provided for @parentPointsAdjustAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get parentPointsAdjustAmountHint;

  /// No description provided for @parentPointsAdjustNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get parentPointsAdjustNoteHint;

  /// No description provided for @parentPointsAdjustConfirm.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get parentPointsAdjustConfirm;

  /// No description provided for @parentPointsAdjustAppliedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Balance updated.'**
  String get parentPointsAdjustAppliedSnackbar;

  /// No description provided for @parentPointsAdjustCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance: {count} pts'**
  String parentPointsAdjustCurrentBalance(int count);

  /// No description provided for @profileTypeChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get profileTypeChild;

  /// No description provided for @profileTypeAdult.
  ///
  /// In en, this message translates to:
  /// **'Adult'**
  String get profileTypeAdult;

  /// No description provided for @childMode.
  ///
  /// In en, this message translates to:
  /// **'Child mode'**
  String get childMode;

  /// No description provided for @adultMode.
  ///
  /// In en, this message translates to:
  /// **'Adult mode'**
  String get adultMode;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionGoToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to dashboard'**
  String get actionGoToDashboard;

  /// No description provided for @emptyLoginTutorEntry.
  ///
  /// In en, this message translates to:
  /// **'I\'m a tutor'**
  String get emptyLoginTutorEntry;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchAccount;

  /// No description provided for @emptyLoginTutorComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Tutor access coming soon. Ask the parent to share an invite link with you.'**
  String get emptyLoginTutorComingSoon;

  /// No description provided for @tutorWelcomeBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome, tutor!'**
  String get tutorWelcomeBannerTitle;

  /// No description provided for @tutorWelcomeBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Ask the parent to share an invite link with you, then tap below to accept it.'**
  String get tutorWelcomeBannerBody;

  /// No description provided for @switcherSheetProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get switcherSheetProfiles;

  /// No description provided for @switcherSheetAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get switcherSheetAccounts;

  /// No description provided for @switcherSheetAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get switcherSheetAddAccount;

  /// No description provided for @addAnotherAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to or create another account on this device'**
  String get addAnotherAccountSubtitle;

  /// No description provided for @acceptInviteAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept Tutor Invite'**
  String get acceptInviteAppBarTitle;

  /// No description provided for @acceptInviteAccepting.
  ///
  /// In en, this message translates to:
  /// **'Accepting invite…'**
  String get acceptInviteAccepting;

  /// No description provided for @acceptInviteHeading.
  ///
  /// In en, this message translates to:
  /// **'Accept tutor invite'**
  String get acceptInviteHeading;

  /// No description provided for @acceptInviteBody.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to tutor a child. By accepting, you will have access to view and manage their learning profile.'**
  String get acceptInviteBody;

  /// No description provided for @acceptInvitePermissionViewData.
  ///
  /// In en, this message translates to:
  /// **'View all learning data and progress'**
  String get acceptInvitePermissionViewData;

  /// No description provided for @acceptInvitePermissionConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure tracks, points, and rewards (if permitted)'**
  String get acceptInvitePermissionConfigure;

  /// No description provided for @acceptInvitePermissionBulkMark.
  ///
  /// In en, this message translates to:
  /// **'Perform bulk-mark corrections'**
  String get acceptInvitePermissionBulkMark;

  /// No description provided for @acceptInvitePermissionNoLive.
  ///
  /// In en, this message translates to:
  /// **'Cannot mark live completions (streak / rewards)'**
  String get acceptInvitePermissionNoLive;

  /// No description provided for @acceptInviteAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept invite'**
  String get acceptInviteAccept;

  /// No description provided for @acceptInviteDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get acceptInviteDecline;

  /// No description provided for @acceptInviteSuccessHeading.
  ///
  /// In en, this message translates to:
  /// **'Invite accepted!'**
  String get acceptInviteSuccessHeading;

  /// No description provided for @acceptInviteSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'You now have tutor access to this child\'s learning profile. Open the Profile Picker to switch to the tutored profile.'**
  String get acceptInviteSuccessBody;

  /// No description provided for @acceptInviteErrorHeading.
  ///
  /// In en, this message translates to:
  /// **'Could not accept invite'**
  String get acceptInviteErrorHeading;

  /// No description provided for @acceptInviteGenericError.
  ///
  /// In en, this message translates to:
  /// **'Unable to accept invite. Please try again.'**
  String get acceptInviteGenericError;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get unexpectedError;

  /// No description provided for @declineInviteAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline Invite'**
  String get declineInviteAppBarTitle;

  /// No description provided for @declineInviteConfirmHeading.
  ///
  /// In en, this message translates to:
  /// **'Decline tutor invite?'**
  String get declineInviteConfirmHeading;

  /// No description provided for @declineInviteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You are about to decline this tutor invite. The parent will be notified that you declined. You will not have access to this child\'s learning profile.'**
  String get declineInviteConfirmBody;

  /// No description provided for @declineInviteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Decline invite'**
  String get declineInviteConfirm;

  /// No description provided for @declineInviteInProgress.
  ///
  /// In en, this message translates to:
  /// **'Declining invite…'**
  String get declineInviteInProgress;

  /// No description provided for @declineInviteSuccessHeading.
  ///
  /// In en, this message translates to:
  /// **'Invite declined'**
  String get declineInviteSuccessHeading;

  /// No description provided for @declineInviteSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'You have declined this tutor invite. The parent has been notified.'**
  String get declineInviteSuccessBody;

  /// No description provided for @declineInviteErrorHeading.
  ///
  /// In en, this message translates to:
  /// **'Could not decline invite'**
  String get declineInviteErrorHeading;

  /// No description provided for @declineInviteGenericError.
  ///
  /// In en, this message translates to:
  /// **'Unable to decline invite. Please try again.'**
  String get declineInviteGenericError;

  /// No description provided for @inviteTutorAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite a Tutor'**
  String get inviteTutorAppBarTitle;

  /// No description provided for @inviteTutorHeading.
  ///
  /// In en, this message translates to:
  /// **'Invite a Tutor'**
  String get inviteTutorHeading;

  /// No description provided for @inviteTutorBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the tutor\'s email address. They will receive an invite link to accept access to this child\'s learning profile.'**
  String get inviteTutorBody;

  /// No description provided for @inviteTutorEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Tutor\'s email address'**
  String get inviteTutorEmailLabel;

  /// No description provided for @inviteTutorEmailHint.
  ///
  /// In en, this message translates to:
  /// **'tutor@example.com'**
  String get inviteTutorEmailHint;

  /// No description provided for @inviteTutorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get inviteTutorInvalidEmail;

  /// No description provided for @inviteTutorSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get inviteTutorSending;

  /// No description provided for @inviteTutorSend.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get inviteTutorSend;

  /// No description provided for @inviteTutorSentSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {email}!'**
  String inviteTutorSentSnackbar(String email);

  /// No description provided for @manageGrantsAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tutoring Grants'**
  String get manageGrantsAppBarTitle;

  /// No description provided for @manageGrantsActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String manageGrantsActiveSection(int count);

  /// No description provided for @manageGrantsPendingSection.
  ///
  /// In en, this message translates to:
  /// **'Pending invites ({count})'**
  String manageGrantsPendingSection(int count);

  /// No description provided for @manageGrantsEmptyHeading.
  ///
  /// In en, this message translates to:
  /// **'No tutoring relationships'**
  String get manageGrantsEmptyHeading;

  /// No description provided for @manageGrantsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When a parent invites you to tutor their child, the grant will appear here.'**
  String get manageGrantsEmptyBody;

  /// No description provided for @manageGrantsResignTitle.
  ///
  /// In en, this message translates to:
  /// **'Resign from tutoring?'**
  String get manageGrantsResignTitle;

  /// No description provided for @manageGrantsResignBody.
  ///
  /// In en, this message translates to:
  /// **'You will immediately lose access to this child\'s profile. The parent will be notified.\n\nChild: {child}\nParent: {parent}'**
  String manageGrantsResignBody(String child, String parent);

  /// No description provided for @manageGrantsResign.
  ///
  /// In en, this message translates to:
  /// **'Resign'**
  String get manageGrantsResign;

  /// No description provided for @manageGrantsResignError.
  ///
  /// In en, this message translates to:
  /// **'Could not resign: {error}'**
  String manageGrantsResignError(String error);

  /// No description provided for @tutorFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Your tutor'**
  String get tutorFallbackName;

  /// No description provided for @manageTutorsEmptyHeading.
  ///
  /// In en, this message translates to:
  /// **'No children profiles yet'**
  String get manageTutorsEmptyHeading;

  /// No description provided for @manageTutorsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a child profile to start inviting tutors.'**
  String get manageTutorsEmptyBody;

  /// No description provided for @manageTutorsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load tutors: {error}'**
  String manageTutorsLoadError(String error);

  /// No description provided for @manageTutorsNoTutors.
  ///
  /// In en, this message translates to:
  /// **'No tutors invited.'**
  String get manageTutorsNoTutors;

  /// No description provided for @manageTutorsActiveSection.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String manageTutorsActiveSection(int count);

  /// No description provided for @manageTutorsPendingSection.
  ///
  /// In en, this message translates to:
  /// **'Pending ({count})'**
  String manageTutorsPendingSection(int count);

  /// No description provided for @manageTutorsInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Invite a tutor'**
  String get manageTutorsInviteButton;

  /// No description provided for @manageTutorsRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke tutor access?'**
  String get manageTutorsRevokeTitle;

  /// No description provided for @manageTutorsRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'{email} will immediately lose access to this child\'s profile.'**
  String manageTutorsRevokeBody(String email);

  /// No description provided for @manageTutorsRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get manageTutorsRevoke;

  /// No description provided for @manageTutorsRevokeError.
  ///
  /// In en, this message translates to:
  /// **'Could not revoke: {error}'**
  String manageTutorsRevokeError(String error);

  /// No description provided for @manageTutorsRescindTitle.
  ///
  /// In en, this message translates to:
  /// **'Rescind invitation?'**
  String get manageTutorsRescindTitle;

  /// No description provided for @manageTutorsRescindBody.
  ///
  /// In en, this message translates to:
  /// **'The pending invite to {email} will be cancelled.'**
  String manageTutorsRescindBody(String email);

  /// No description provided for @manageTutorsRescind.
  ///
  /// In en, this message translates to:
  /// **'Rescind'**
  String get manageTutorsRescind;

  /// No description provided for @manageTutorsRescindError.
  ///
  /// In en, this message translates to:
  /// **'Could not rescind: {error}'**
  String manageTutorsRescindError(String error);

  /// No description provided for @manageTutorsViewAuditLog.
  ///
  /// In en, this message translates to:
  /// **'View audit log'**
  String get manageTutorsViewAuditLog;

  /// No description provided for @tutorFallbackParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get tutorFallbackParent;

  /// No description provided for @auditLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLogTitle;

  /// No description provided for @auditLogClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get auditLogClearFilters;

  /// No description provided for @auditLogFilterFromDate.
  ///
  /// In en, this message translates to:
  /// **'Filter from date'**
  String get auditLogFilterFromDate;

  /// No description provided for @auditLogFilterToDate.
  ///
  /// In en, this message translates to:
  /// **'Filter to date'**
  String get auditLogFilterToDate;

  /// No description provided for @auditLogFilterFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get auditLogFilterFrom;

  /// No description provided for @auditLogFilterTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get auditLogFilterTo;

  /// No description provided for @auditLogEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No entries match the filters'**
  String get auditLogEmptyFiltered;

  /// No description provided for @auditLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No audit entries'**
  String get auditLogEmpty;

  /// No description provided for @auditLogEmptyFilteredBody.
  ///
  /// In en, this message translates to:
  /// **'Clear filters to see all entries.'**
  String get auditLogEmptyFilteredBody;

  /// No description provided for @auditLogEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tutor actions will appear here as they occur.'**
  String get auditLogEmptyBody;

  /// No description provided for @auditLogChipConfig.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get auditLogChipConfig;

  /// No description provided for @auditLogChipBulkPrior.
  ///
  /// In en, this message translates to:
  /// **'Bulk Prior'**
  String get auditLogChipBulkPrior;

  /// No description provided for @auditLogChipReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get auditLogChipReset;

  /// No description provided for @auditLogChipBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get auditLogChipBookmark;

  /// No description provided for @auditLogChipProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get auditLogChipProfile;

  /// No description provided for @auditLogChipGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get auditLogChipGoal;

  /// No description provided for @auditLogChipStage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get auditLogChipStage;

  /// No description provided for @auditLogChipReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get auditLogChipReward;

  /// No description provided for @auditLogChipStudyDay.
  ///
  /// In en, this message translates to:
  /// **'Study Day'**
  String get auditLogChipStudyDay;

  /// No description provided for @auditLogActionConfigChanged.
  ///
  /// In en, this message translates to:
  /// **'Config changed'**
  String get auditLogActionConfigChanged;

  /// No description provided for @auditLogActionBulkPrior.
  ///
  /// In en, this message translates to:
  /// **'Bulk prior'**
  String get auditLogActionBulkPrior;

  /// No description provided for @auditLogActionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get auditLogActionReset;

  /// No description provided for @auditLogActionBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get auditLogActionBookmark;

  /// No description provided for @auditLogActionProfileEdited.
  ///
  /// In en, this message translates to:
  /// **'Profile edited'**
  String get auditLogActionProfileEdited;

  /// No description provided for @auditLogActionGoalChanged.
  ///
  /// In en, this message translates to:
  /// **'Goal changed'**
  String get auditLogActionGoalChanged;

  /// No description provided for @auditLogActionStageChanged.
  ///
  /// In en, this message translates to:
  /// **'Stage changed'**
  String get auditLogActionStageChanged;

  /// No description provided for @auditLogActionRewardChanged.
  ///
  /// In en, this message translates to:
  /// **'Reward changed'**
  String get auditLogActionRewardChanged;

  /// No description provided for @auditLogActionStudyDay.
  ///
  /// In en, this message translates to:
  /// **'Study day'**
  String get auditLogActionStudyDay;

  /// No description provided for @auditLogBefore.
  ///
  /// In en, this message translates to:
  /// **'before: '**
  String get auditLogBefore;

  /// No description provided for @auditLogAfter.
  ///
  /// In en, this message translates to:
  /// **'after: '**
  String get auditLogAfter;

  /// No description provided for @tutorPinAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Tutor PIN'**
  String get tutorPinAppBarTitle;

  /// No description provided for @tutorPinEntryHeading.
  ///
  /// In en, this message translates to:
  /// **'Enter your Tutor PIN'**
  String get tutorPinEntryHeading;

  /// No description provided for @tutorPinEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit Tutor PIN to access this profile.'**
  String get tutorPinEntryBody;

  /// No description provided for @tutorPinForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot your Tutor PIN?'**
  String get tutorPinForgot;

  /// No description provided for @tutorPinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Please try again.'**
  String get tutorPinIncorrect;

  /// No description provided for @tutorPinLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Locked for {minutes} minute(s).'**
  String tutorPinLockedOut(int minutes);

  /// No description provided for @parentPinLockoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts'**
  String get parentPinLockoutTitle;

  /// No description provided for @parentPinLockoutBody.
  ///
  /// In en, this message translates to:
  /// **'Try again in {minutes} minute(s)'**
  String parentPinLockoutBody(int minutes);

  /// No description provided for @tutorPinErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String tutorPinErrorPrefix(String error);

  /// No description provided for @tutorPinSetupAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Tutor PIN'**
  String get tutorPinSetupAppBarTitle;

  /// No description provided for @tutorPinSetupConfirmHeading.
  ///
  /// In en, this message translates to:
  /// **'Confirm your Tutor PIN'**
  String get tutorPinSetupConfirmHeading;

  /// No description provided for @tutorPinSetupCreateHeading.
  ///
  /// In en, this message translates to:
  /// **'Create your Tutor PIN'**
  String get tutorPinSetupCreateHeading;

  /// No description provided for @tutorPinSetupConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the same 4-digit PIN to confirm.'**
  String get tutorPinSetupConfirmBody;

  /// No description provided for @tutorPinSetupCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Your Tutor PIN protects access to every child profile you tutor. Enter a 4-digit PIN.'**
  String get tutorPinSetupCreateBody;

  /// No description provided for @tutorPinSetupConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get tutorPinSetupConfirmLabel;

  /// No description provided for @tutorPinSetupEnterNewLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter New PIN'**
  String get tutorPinSetupEnterNewLabel;

  /// No description provided for @tutorPinSetupMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Please try again.'**
  String get tutorPinSetupMismatch;

  /// No description provided for @tutorPinSetupSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save PIN. Please try again.'**
  String get tutorPinSetupSaveError;

  /// No description provided for @tutorPinSetupLater.
  ///
  /// In en, this message translates to:
  /// **'Set up later'**
  String get tutorPinSetupLater;

  /// No description provided for @tutorPinResetAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Tutor PIN'**
  String get tutorPinResetAppBarTitle;

  /// No description provided for @tutorPinResetHeading.
  ///
  /// In en, this message translates to:
  /// **'Reset your Tutor PIN'**
  String get tutorPinResetHeading;

  /// No description provided for @tutorPinResetSendingTo.
  ///
  /// In en, this message translates to:
  /// **'We will send a reset link to:'**
  String get tutorPinResetSendingTo;

  /// No description provided for @tutorPinResetReturnHint.
  ///
  /// In en, this message translates to:
  /// **'After following the link, return here to create a new PIN.'**
  String get tutorPinResetReturnHint;

  /// No description provided for @tutorPinResetNoEmail.
  ///
  /// In en, this message translates to:
  /// **'No email address found for your account. Please sign in with a cloud account to use PIN reset.'**
  String get tutorPinResetNoEmail;

  /// No description provided for @tutorPinResetSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email. Please try again.'**
  String get tutorPinResetSendFailed;

  /// No description provided for @tutorPinResetFallbackEmail.
  ///
  /// In en, this message translates to:
  /// **'your account email'**
  String get tutorPinResetFallbackEmail;

  /// No description provided for @tutorPinResetSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset email'**
  String get tutorPinResetSendButton;

  /// No description provided for @tutorPinResetCheckEmailHeading.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get tutorPinResetCheckEmailHeading;

  /// No description provided for @tutorPinResetCheckEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to {email}. Follow the link, then return here to set a new PIN.'**
  String tutorPinResetCheckEmailBody(String email);

  /// No description provided for @tutorPinResetSetNew.
  ///
  /// In en, this message translates to:
  /// **'Set new PIN'**
  String get tutorPinResetSetNew;

  /// No description provided for @settingsAppPermissions.
  ///
  /// In en, this message translates to:
  /// **'App Permissions'**
  String get settingsAppPermissions;

  /// No description provided for @settingsAppPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications and location access'**
  String get settingsAppPermissionsSubtitle;

  /// No description provided for @settingsSendDiagnosticLogs.
  ///
  /// In en, this message translates to:
  /// **'Send Diagnostic Logs'**
  String get settingsSendDiagnosticLogs;

  /// No description provided for @settingsSendDiagnosticLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stream last 10 min of activity to Firebase'**
  String get settingsSendDiagnosticLogsSubtitle;

  /// No description provided for @settingsPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get settingsPronunciation;

  /// No description provided for @settingsPronunciationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bereishis (Ashkenazi) or Bereshit (Sephardi)'**
  String get settingsPronunciationSubtitle;

  /// No description provided for @settingsPronunciationAshkenazi.
  ///
  /// In en, this message translates to:
  /// **'Ashkenazi'**
  String get settingsPronunciationAshkenazi;

  /// No description provided for @settingsPronunciationSephardi.
  ///
  /// In en, this message translates to:
  /// **'Sephardi'**
  String get settingsPronunciationSephardi;

  /// No description provided for @settingsNikud.
  ///
  /// In en, this message translates to:
  /// **'Nikud'**
  String get settingsNikud;

  /// No description provided for @settingsNikudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show or hide Hebrew vowel marks when learning.'**
  String get settingsNikudSubtitle;

  /// No description provided for @settingsNikudWithout.
  ///
  /// In en, this message translates to:
  /// **'Without nikud'**
  String get settingsNikudWithout;

  /// No description provided for @settingsNikudWith.
  ///
  /// In en, this message translates to:
  /// **'With nikud'**
  String get settingsNikudWith;

  /// No description provided for @deviceNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Device notifications'**
  String get deviceNotificationsTitle;

  /// No description provided for @deviceNotificationsChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking permission…'**
  String get deviceNotificationsChecking;

  /// No description provided for @deviceNotificationsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Notifications allowed on this device'**
  String get deviceNotificationsAllowed;

  /// No description provided for @deviceNotificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications blocked — tap to open Settings'**
  String get deviceNotificationsBlocked;

  /// No description provided for @deviceNotificationsDisableHint.
  ///
  /// In en, this message translates to:
  /// **'To disable notifications, go to Settings > Apps > Learning Tracker.'**
  String get deviceNotificationsDisableHint;

  /// No description provided for @deviceNotificationsBlockedHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications blocked. Enable them in Settings > Apps > Learning Tracker > Notifications.'**
  String get deviceNotificationsBlockedHint;

  /// No description provided for @notificationReminderGenericBody.
  ///
  /// In en, this message translates to:
  /// **'Time to learn! Open the app to see your tasks.'**
  String get notificationReminderGenericBody;

  /// No description provided for @notificationStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak at Risk!'**
  String get notificationStreakTitle;

  /// No description provided for @notificationStreakBody.
  ///
  /// In en, this message translates to:
  /// **'Your {currentStreak}-day streak is at risk!'**
  String notificationStreakBody(int currentStreak);

  /// No description provided for @onboardingIntentHeading.
  ///
  /// In en, this message translates to:
  /// **'What brings you here?'**
  String get onboardingIntentHeading;

  /// No description provided for @onboardingIntentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to get started.'**
  String get onboardingIntentSubtitle;

  /// No description provided for @onboardingIntentTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track my own learning'**
  String get onboardingIntentTrackTitle;

  /// No description provided for @onboardingIntentTrackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up a curriculum, goals, and daily schedule.'**
  String get onboardingIntentTrackSubtitle;

  /// No description provided for @onboardingIntentSkipTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingIntentSkipTitle;

  /// No description provided for @onboardingIntentSkipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Go to the app and decide later. You can set up a track or accept an invite any time.'**
  String get onboardingIntentSkipSubtitle;

  /// AppBar title for PermissionPromptScreen when launched from the onboarding flow.
  ///
  /// In en, this message translates to:
  /// **'Almost Done!'**
  String get permissionPromptTitleOnboarding;

  /// Body text on PermissionPromptScreen in onboarding mode. {shabbos} is the nusach-aware Shabbos/Shabbat/שבת term.
  ///
  /// In en, this message translates to:
  /// **'Allow these optional permissions so Learning Tracker can remind you to learn and compute {shabbos} times for your location.'**
  String permissionPromptBodyOnboarding(String shabbos);

  /// Body text on PermissionPromptScreen when opened from Settings. {shabbos} is the nusach-aware Shabbos/Shabbat/שבת term.
  ///
  /// In en, this message translates to:
  /// **'Manage optional permissions for reminders and {shabbos}-time calculations.'**
  String permissionPromptBodySettings(String shabbos);

  /// Subtitle text on the Notifications permission card in PermissionPromptScreen.
  ///
  /// In en, this message translates to:
  /// **'Daily learning reminders and streak-protection alerts.'**
  String get permissionPromptNotifSubtitle;

  /// Title on the Location permission card in PermissionPromptScreen.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permissionPromptLocationTitle;

  /// Subtitle on the Location permission card. {shabbos} is the nusach-aware Shabbos term; {havdalah} is the nusach-aware Havdalah term.
  ///
  /// In en, this message translates to:
  /// **'Accurate {shabbos} candle-lighting and {havdalah} times based on your city.'**
  String permissionPromptLocationSubtitle(String shabbos, String havdalah);

  /// Primary CTA label on PermissionPromptScreen when opened from Settings (isOnboarding=false).
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get permissionPromptCtaDone;

  /// Label on the Allow button inside each permission card on PermissionPromptScreen.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionPromptAllowButton;

  /// IL-9: localized count label shown below HierarchySelectionPanel when items are selected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} selection} other{{count} selections}}'**
  String selectionCount(int count);

  /// R1-(3): singular/plural unit word ('Day'/'Days') shown under the numeric delay in the custom-cycle review chip. Uppercased at render time. count==1 must be singular ('1 DAY').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Day} other{Days}}'**
  String chazaraDayUnitLabel(int count);

  /// R1-(6): top-level scope breadcrumb prompt. Shown after the curriculum chip; must NOT repeat the curriculum name. levelLabel is the localized level word (e.g. Sefer, Seder).
  ///
  /// In en, this message translates to:
  /// **'Choose a {levelLabel}'**
  String scopeChooseLevelPrompt(String levelLabel);

  /// AppBar title for the standalone Study Days config screen. {curriculum} is the curriculum/track display label (transliteration in English mode, Hebrew in Hebrew mode).
  ///
  /// In en, this message translates to:
  /// **'{curriculum} Study Days'**
  String schedulerStudyDaysScreenTitle(String curriculum);

  /// Instructional subtitle on the Study Days config screen explaining the study vs review-only toggle.
  ///
  /// In en, this message translates to:
  /// **'Choose which days include new learning and which are for review only.'**
  String get schedulerStudyDaysIntro;

  /// Fallback message shown on the Study Days screen for learn-only tracks (no chazara), where review-day configuration is not applicable. Must not mention review/chazara.
  ///
  /// In en, this message translates to:
  /// **'All days are study days for this track.'**
  String get schedulerStudyDaysAllStudyDays;

  /// Footer summary on the Study Days screen showing how many study days are selected per week.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 study day per week} other{{count} study days per week}}'**
  String schedulerStudyDaysPerWeek(int count);

  /// Inline warning shown on the Study Days screen when zero study days are selected for the week.
  ///
  /// In en, this message translates to:
  /// **'No study days selected — every day is review only and no new learning will be scheduled.'**
  String get schedulerStudyDaysZeroWarning;

  /// Short weekday label for Sunday on the Study Days screen.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get schedulerDayAbbrevSun;

  /// Short weekday label for Monday on the Study Days screen.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get schedulerDayAbbrevMon;

  /// Short weekday label for Tuesday on the Study Days screen.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get schedulerDayAbbrevTue;

  /// Short weekday label for Wednesday on the Study Days screen.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get schedulerDayAbbrevWed;

  /// Short weekday label for Thursday on the Study Days screen.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get schedulerDayAbbrevThu;

  /// Short weekday label for Friday on the Study Days screen.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get schedulerDayAbbrevFri;

  /// No description provided for @trackEditNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a track name'**
  String get trackEditNameRequired;

  /// No description provided for @trackEditReviewSummaryWithDays.
  ///
  /// In en, this message translates to:
  /// **'After {delays} {count, plural, =1{day} other{days}}'**
  String trackEditReviewSummaryWithDays(String delays, int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
