// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'מעקב לימוד תורה';

  @override
  String get dashboard => 'לוח בקרה';

  @override
  String get learn => 'לימוד';

  @override
  String get progress => 'התקדמות';

  @override
  String get settings => 'הגדרות';

  @override
  String get goodMorning => 'בוקר טוב';

  @override
  String get goodAfternoon => 'צהריים טובים';

  @override
  String get goodEvening => 'ערב טוב';

  @override
  String get streak => 'רצף';

  @override
  String get done => 'הושלם';

  @override
  String get points => 'נקודות';

  @override
  String get pages => 'עמודים';

  @override
  String todaysLearning(int count) {
    return 'לימוד היום ($count)';
  }

  @override
  String remaining(int count) {
    return '$count נותרו';
  }

  @override
  String get allCaughtUp => 'הכל מעודכן!';

  @override
  String get noTasksRemaining => 'אין משימות נוספות להיום.';

  @override
  String get activeCurricula => 'תוכניות לימוד פעילות';

  @override
  String get activeTracks => 'מסלולים פעילים';

  @override
  String get activeTracksSubtitle => 'המשיכו בצורה מעולה ביעדי הלמידה';

  @override
  String get activeTrackNextTask => 'המשימה הבאה';

  @override
  String get activeTrackCurrentFocus => 'מיקוד נוכחי';

  @override
  String activeTrackPaceAhead(int days) {
    return 'לפני $days ימים';
  }

  @override
  String activeTrackPaceBehind(int days) {
    return 'אחרי $days ימים';
  }

  @override
  String get activeTrackPaceOk => 'במסלול';

  @override
  String get activeTrackMetricChazara => 'חזרה';

  @override
  String get activeTrackMetricDueToday => 'להיום';

  @override
  String get activeTrackMetricOverdue => 'באיחור';

  @override
  String get trackCurrentCycle => 'מאז ההפעלה מחדש';

  @override
  String get continueLearning => 'המשך לימוד';

  @override
  String get recentActivity => 'פעילות אחרונה';

  @override
  String get myLearningJourney => 'מסע הלימוד שלי';

  @override
  String get myLearningJourneySubtitle => 'כל מה שלמדת, לפי הסדר';

  @override
  String get seeLifetimeAchievements => 'הישגים לאורך כל הדרך';

  @override
  String get dailyProgress => 'התקדמות יומית';

  @override
  String get studyDay => 'יום לימוד';

  @override
  String get reviewDay => 'יום חזרה';

  @override
  String get mixedDay => 'משולב';

  @override
  String get restDay => 'יום מנוחה';

  @override
  String get overdue => 'באיחור';

  @override
  String moreTasks(int count) {
    return 'עוד $count משימות...';
  }

  @override
  String streakRecovery(int count) {
    return 'פספסת יום אחד אבל הרצף של $count ימים שמור!';
  }

  @override
  String get achievements => 'הישגים';

  @override
  String get activityCalendar => 'לוח פעילות';

  @override
  String get nextReward => 'הפרס הבא';

  @override
  String get earnedRewards => 'פרסים שהושגו';

  @override
  String get noRewardsYet => 'עדיין אין פרסים. המשיכו ללמוד!';

  @override
  String get mysteryReward => '!פרס מסתורי';

  @override
  String get totalPoints => 'סה״כ נקודות';

  @override
  String get dashboardRewardsGallery => 'גלריית פרסים';

  @override
  String get dashboardChildPointsTab => 'נקודות';

  @override
  String get dashboardSeeAllRewards => 'הצג הכול';

  @override
  String get dashboardMysteryChest => 'תיבת מסתורין';

  @override
  String get dashboardCurrentBalance => 'יתרה נוכחית';

  @override
  String dashboardNextRewardWithName(String name) {
    return 'פרס הבא: $name';
  }

  @override
  String dashboardPtsToGo(String count) {
    return 'עוד $count נק׳!';
  }

  @override
  String get dashboardRedeemPrizes => 'מימוש פרסים';

  @override
  String dashboardTapToUnlockAtPts(String points) {
    return 'לחיצה לפתיחה ב־$points נק׳';
  }

  @override
  String dashboardPointsValue(String count) {
    return '$count נקודות';
  }

  @override
  String get dashboardBubbleDone => 'בוצע';

  @override
  String get complete => 'הושלם';

  @override
  String get gamification => 'הישגים ופרסים';

  @override
  String get myAchievementsTitle => 'ההישגים שלי';

  @override
  String get achievementsYourProgress => 'ההתקדמות שלך';

  @override
  String achievementsRewardsCount(int unlocked, int total) {
    return '$unlocked / $total פרסים';
  }

  @override
  String get achievementsAcrossAllTracks => 'בכל המסלולים שלך.';

  @override
  String get achievementsEncouragement => 'המשך ככה, מצוין!';

  @override
  String achievementsRewardsFraction(int unlocked, int total) {
    return '$unlocked / $total';
  }

  @override
  String get achievementsRewardsLabelWord => 'פרסים';

  @override
  String achievementsMilestonePoints(String points) {
    return '$points נק׳';
  }

  @override
  String achievementsProgressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get achievementsTrackSection => 'בחירת מסלול';

  @override
  String get achievementsAllTracks => 'כל המסלולים';

  @override
  String get achievementsGlobalRewardsLabel => 'נקודות כוללות';

  @override
  String get achievementsStatusUnlocked => 'נפתח!';

  @override
  String get achievementsStatusComingSoon => 'בקרוב!';

  @override
  String get achievementsStatusLocked => 'נעול';

  @override
  String achievementsLockedBlurHint(String points) {
    return 'הגיעו ל־$points נקודות כדי לפתוח';
  }

  @override
  String achievementsUnlockedAtPoints(String points) {
    return 'נפתח ב־$points נקודות';
  }

  @override
  String get achievementsUltimateGoal => 'היעד האולטימטיבי.';

  @override
  String get achievementsProTipTitle => 'טיפ!';

  @override
  String get achievementsProTipBody =>
      'המשיכו ללמוד במסלולים כדי לטפס בסולם הפרסים.';

  @override
  String get achievementsActivityAndPoints => 'פעילות ונקודות';

  @override
  String get achievementsUnlockPartyTitle => 'וואו! איזה כיף!';

  @override
  String achievementsUnlockPartyMessage(
    String name,
    String milestone,
    String track,
  ) {
    return 'כל הכבוד, $name! פתחת את $milestone במסלול $track — המשך ככה!';
  }

  @override
  String get achievementsUnlockPartyButton => 'יאללה! בואו נמשיך';

  @override
  String get achievementsUnlockPartyNameFallback => 'חבר';

  @override
  String get rewardCatalog => 'קטלוג פרסים';

  @override
  String get noRewardsConfigured => 'עדיין לא הוגדרו פרסים';

  @override
  String get addReward => 'הוסף פרס';

  @override
  String get editReward => 'ערוך פרס';

  @override
  String get deleteReward => 'מחק פרס';

  @override
  String deleteRewardConfirm(String title) {
    return 'בטוח שברצונך למחוק את \"$title\"?';
  }

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמירה';

  @override
  String get add => 'הוספה';

  @override
  String get delete => 'מחיקה';

  @override
  String get reveal => 'חשיפה';

  @override
  String get revealed => 'נחשף';

  @override
  String get title => 'כותרת';

  @override
  String get description => 'תיאור';

  @override
  String get pointThreshold => 'סף נקודות';

  @override
  String get titleRequired => 'יש להזין כותרת';

  @override
  String get descriptionRequired => 'יש להזין תיאור';

  @override
  String get thresholdRequired => 'יש להזין סף';

  @override
  String get mustBePositive => 'חייב להיות מספר חיובי';

  @override
  String get milestoneType => 'סוג אבן דרך';

  @override
  String get pointsThreshold => 'סף נקודות';

  @override
  String get finishMasechta => 'סיום מסכת';

  @override
  String get finishSeder => 'סיום סדר';

  @override
  String get everyNItems => 'כל N פריטים';

  @override
  String get visibleToChild => 'גלוי לילד';

  @override
  String get childCanSee => 'הילד יכול לראות את הפרס';

  @override
  String get hiddenUntilEarned => 'מוסתר עד שנצבר (הפתעה)';

  @override
  String get onboarding => 'הגדרה ראשונית';

  @override
  String get getStarted => 'בואו נתחיל';

  @override
  String get ctaGetStartedTitle => 'בואו נתחיל';

  @override
  String get ctaGetStartedBody =>
      'הוסיפו מסלול לימוד כדי להתחיל לעקוב אחר ההתקדמות.';

  @override
  String get ctaAddLearningTrack => 'הוסיפו מסלול לימוד';

  @override
  String get ctaCreateProfileFirst =>
      'צרו תחילה פרופיל לומד, ואז הוסיפו מסלול.';

  @override
  String get commonDismiss => 'סגירה';

  @override
  String get alreadyHaveAccount => 'כבר יש לך חשבון?';

  @override
  String get whatsYourName => 'מה השם שלך?';

  @override
  String get adult => 'מבוגר';

  @override
  String get child => 'ילד';

  @override
  String get selectLanguage => 'בחר שפה';

  @override
  String get selectCurricula => 'בחר תוכניות לימוד';

  @override
  String get continueButton => 'המשך';

  @override
  String get skip => 'דלג';

  @override
  String get joinCalendarProgram => 'הצטרף לתוכנית לוח שנה';

  @override
  String get joinCalendarDesc => 'עקוב אחרי לוח לימוד יומי כמו דף יומי';

  @override
  String get availablePrograms => 'תוכניות זמינות';

  @override
  String get todaysAssignment => 'המשימה של היום';

  @override
  String get startTrackingFrom => 'התחל מעקב מ';

  @override
  String get fromToday => 'מהיום';

  @override
  String get beginningOfPerek => 'תחילת הפרק הנוכחי';

  @override
  String get beginningOfMasechta => 'תחילת המסכת הנוכחית';

  @override
  String get specificDaf => 'מדף מסוים';

  @override
  String get setupComplete => '!ההגדרה הושלמה';

  @override
  String get addAnotherLearner => 'הוסף לומד נוסף';

  @override
  String get addAnotherTrack => 'הוסף מסלול נוסף';

  @override
  String get startLearning => 'התחל ללמוד';

  @override
  String get allSet => '!הכל מוכן';

  @override
  String get addYourFirstTrack => 'הוסף את המסלול הראשון שלך';

  @override
  String get addTrackButton => 'הוסף מסלול';

  @override
  String get language => 'שפה';

  @override
  String get switchProfile => 'החלף פרופיל';

  @override
  String get switchProfileSubtitle => 'החלף לפרופיל אחר או לחשבון שלך';

  @override
  String get manageProfiles => 'ניהול פרופילים';

  @override
  String get manageProfilesSubtitle => 'הוסף, ערוך או מחק פרופילי לומדים';

  @override
  String get notifications => 'התראות';

  @override
  String get retry => 'נסה שוב';

  @override
  String get error => 'שגיאה';

  @override
  String get loading => '...טוען';

  @override
  String get manageTracks => 'ניהול מסלולים';

  @override
  String get manageTracksAndGoalsTitle => 'מסלולים ומטרות';

  @override
  String get manageTracksDetail => 'יצירה ועריכה של מסלולי הלמידה';

  @override
  String get parentManageTracksDetail =>
      'יצירה ועריכה של מסלולי הלמידה של ילדך';

  @override
  String get addTrackGoalTapToUseDeadline =>
      'מצב קצב יעד פעיל — יש ללחוץ כאן ליעד לפי תאריך יעד';

  @override
  String get addTrackGoalTapToUsePace =>
      'מצב תאריך יעד פעיל — יש ללחוץ כאן לקצב יעד';

  @override
  String addTrackChazaraStepTitle(String term) {
    return 'להוסיף $term?';
  }

  @override
  String addTrackChazaraStepQuestion(String term) {
    return 'איך תרצה לבצע $term?';
  }

  @override
  String addTrackGoalDeadlinePaceLine(
    int items,
    String unit,
    int studyDays,
    int totalItems,
  ) {
    return 'בערך $items $unit בכל יום לימוד, על פני $studyDays ימי לימוד עד תאריך היעד (בערך $totalItems יחידות בתחום).';
  }

  @override
  String get addTrackGoalDeadlineNoStudyDaysInWindow =>
      'אין יום לימוד בטווח עד תאריך היעד. הוסיפו ימי לימוד או בחרו תאריך מאוחר יותר.';

  @override
  String get addTrackGoalDeadlinePaceLineLoading =>
      'טוען גודל תחום לחישוב לכל יום לימוד…';

  @override
  String get addTrack => 'הוסף מסלול';

  @override
  String get addTrackCurriculumReplaceWarning =>
      'כבר יש לך מסלול כאן. בחירת הקורס שוב תחליף את ההגדרה הנוכחית ועלולה לאפס את ההתקדמות שלך בו.';

  @override
  String get noActiveCurricula => 'אין תוכניות לימוד פעילות';

  @override
  String errorLoadingCurricula(String error) {
    return 'שגיאה בטעינת תוכניות הלימוד: $error';
  }

  @override
  String trackCreated(String label) {
    return 'המסלול \"$label\" נוצר';
  }

  @override
  String get learner => 'לומד';

  @override
  String get learningTracker => 'מעקב לימוד';

  @override
  String get searchContent => 'חיפוש תוכן';

  @override
  String errorWithMessage(String error) {
    return 'שגיאה: $error';
  }

  @override
  String errorLoadingTasks(String error) {
    return 'שגיאה בטעינת משימות: $error';
  }

  @override
  String get noActiveTracks => 'אין מסלולים פעילים';

  @override
  String get askGrownUpToAddTrack => 'בקשו ממבוגר להוסיף מסלול לימוד.';

  @override
  String get addTrackToStart => 'הוסיפו מסלול כדי להתחיל ללמוד.';

  @override
  String get todaysTasks => 'המשימות של היום';

  @override
  String get viewAll => 'הצג הכל';

  @override
  String get myCurricula => 'תוכניות הלימוד שלי';

  @override
  String percentComplete(int percent) {
    return '$percent% הושלם';
  }

  @override
  String get viewProgress => 'הצג התקדמות';

  @override
  String get markComplete => 'סמן כהושלם';

  @override
  String get markCompleteTutorUnavailable => 'לא זמין (מצב מדריך)';

  @override
  String markCompleteCompletedStage(String stageName) {
    return 'הושלם ($stageName)';
  }

  @override
  String unableToLoadCompletionContext(String error) {
    return 'לא ניתן לטעון את נתוני ההשלמה: $error';
  }

  @override
  String get accountOfflineSignInToSync =>
      'עובד במצב לא מקוון עבור חשבון זה. התחבר כדי לחדש את הסנכרון בענן.';

  @override
  String get textReaderNextDailyTask => 'המשימה הבאה';

  @override
  String get noProjection => 'אין תחזית';

  @override
  String get today => 'היום';

  @override
  String plusNMore(int count) {
    return '+$count נוספים';
  }

  @override
  String get noTracksYet => 'עדיין אין מסלולים';

  @override
  String get firstTrackPrompt => 'הוסיפו את מסלול הלימוד הראשון כדי להתחיל.';

  @override
  String paceAhead(int days) {
    return '$days ימים מקדימה';
  }

  @override
  String paceBehind(int days) {
    return '$days ימים באיחור';
  }

  @override
  String get paceOnPace => 'בקצב';

  @override
  String get progressNoDataTitle => 'עדיין אין התקדמות';

  @override
  String get progressNoDataSubtitle =>
      'התחילו ללמוד כדי לראות את ההתקדמות כאן.';

  @override
  String get statCompletions => 'פריטים שנלמדו';

  @override
  String get statUnitsDone => 'משימות';

  @override
  String get statDayStreak => 'רצף ימים';

  @override
  String get statActiveTracks => 'מסלולים פעילים';

  @override
  String get progressChartsTile => 'גרפי התקדמות';

  @override
  String get progressChartsTileSubtitle => 'השלמות, מגמות ועוד';

  @override
  String get learningLifetime => 'לימוד לאורך חיים';

  @override
  String get learningLifetimeExpandHint =>
      'לפי תוכנית: פתחו כדי לעיין במה נלמד';

  @override
  String get addWhatYouLearned => 'הוספת לימוד לאורך חיים';

  @override
  String get addWhatYouLearnedSettingsSubtitle =>
      'הרשומות מופיעות בדוחות לימוד לאורך חיים';

  @override
  String get lifetimeLearning => 'לימוד חיים';

  @override
  String get lifetimeLearningHubSection => 'מרכז הלמידה';

  @override
  String lifetimeXpTotal(String points) {
    return '$points נקודות XP בסך הכל';
  }

  @override
  String get lifetimeStartAdding => 'התחל להוסיף';

  @override
  String get learnBrowseSectionTitle => 'עיון';

  @override
  String get lifetimeBrowseFullLibrary => 'עיון בספרייה המלאה';

  @override
  String get lifetimeHowItWorksStep1 =>
      'בחרו קטגוריה מרשת הקטגוריות כדי לראות את כל המסלולים.';

  @override
  String get lifetimeHowItWorksStep2 =>
      'סמנו משימות שסיימתם כדי לעדכן את מפת ההתקדמות לכל החיים.';

  @override
  String get lifetimeHowItWorksStep3 =>
      'קבלו תגי אבן דרך מיוחדים על השלמת ספרים או מסכתות שלמות.';

  @override
  String get lifetimeNotStarted => 'טרם התחיל';

  @override
  String get lifetimeAddHeaderTitle => 'הוספת לימוד לאורך חיים';

  @override
  String get lifetimeAddHeaderSubtitle =>
      'סמנו מה שלמדתם כבר כלימוד לכל החיים.';

  @override
  String get lifetimeHowItWorksTitle => 'איך זה עובד';

  @override
  String get lifetimeHowItWorksBody =>
      'בחרו תוכנית, ואז השתמשו ברשימת התיקיות לבחירת חלקים. ירוק = נבחר לשמירה; פתחו תת־תיקייה עם החץ אם יש עוד בפנים.';

  @override
  String get lifetimeSelectScreenTitle => 'בחרו מה שלמדתם';

  @override
  String get lifetimeSelectScreenSubtitle =>
      'סמנו חלקים לכלול; פתחו תיקיות כדי לרדת לעומק.';

  @override
  String get lifetimeMarkAsLearnedTitle => 'סמן כלומד לכל החיים';

  @override
  String lifetimeMarkAsLearnedLine(int count, int level) {
    return 'נבחרו: $count • רמה $level';
  }

  @override
  String lifetimeMarkAsLearnedCount(int count) {
    return 'נבחרו: $count';
  }

  @override
  String get selectAllInThisList => 'בחר הכל ברשימה';

  @override
  String get deselectAllInThisList => 'בטל בחירה בכל הרשימה';

  @override
  String get clearSelection => 'נקה בחירה';

  @override
  String contentLoadError(String error) {
    return 'לא ניתן לטעון את תוכן התוכנית: $error';
  }

  @override
  String get contentHierarchyBrowseTitle => 'עיון בתוכן';

  @override
  String get contentHierarchyUnknownTitle => 'קורס לא ידוע';

  @override
  String get contentHierarchyNoContent => 'אין תוכן זמין';

  @override
  String get contentHierarchySearchTooltip => 'חיפוש';

  @override
  String get noItemsAtThisLevel => 'אין פריטים ברמה זו';

  @override
  String get breadcrumbsRoot => 'שורש';

  @override
  String lifetimeMarkSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'סומנו $count בחירות לכל החיים.',
      one: 'סומנה בחירה אחת לכל החיים.',
    );
    return '$_temp0';
  }

  @override
  String lifetimeMarkSaveError(String error) {
    return 'לא ניתן לשמור סימונים: $error';
  }

  @override
  String get dashboardStats => 'סטטיסטיקה';

  @override
  String get learningLifetimeAllCurricula => 'לימוד לכל החיים (כל התוכניות)';

  @override
  String get dashboardAllCaughtUpTitle => 'הכל מעודכן! עבודה מצוינת!';

  @override
  String get dashboardAllCaughtUpSubtitle => 'אין לך עוד משימות להיום.';

  @override
  String get dashboardLifetimeProgress => 'התקדמות לכל החיים';

  @override
  String lifetimeSectionsSummary(String learned, String total, int n) {
    return '$learned / $total חלקים — $n תוכניות';
  }

  @override
  String greetingHelloName(String name) {
    return 'שלום, $name!';
  }

  @override
  String get noFocusTag => 'ללא תג מיקוד';

  @override
  String get todaysMissions => 'המשימות של היום';

  @override
  String get noTasksInLane => 'אין משימות במסלול הזה';

  @override
  String get reviewSection => 'מקטע חזרה';

  @override
  String get chazaraReview => 'חזרה';

  @override
  String get activeTrackChazaraLabel => 'חזרה';

  @override
  String get urgent => 'דחוף';

  @override
  String get missedOverdue => 'החמצה / איחור';

  @override
  String get bubbleOverdue => 'איחור';

  @override
  String get bubbleTodayDue => 'היום';

  @override
  String get bubbleChazara => 'חזרה';

  @override
  String get talmidChochom => 'תלמיד חכם';

  @override
  String get talmidChochomCaps => 'תלמיד חכם';

  @override
  String get mainFocus => 'מיקוד ראשי';

  @override
  String carouselCompletion(String chazara) {
    return 'השלמה (עם $chazara)';
  }

  @override
  String get continueCta => 'המשך';

  @override
  String get tabSchedule => 'לוח';

  @override
  String get dueToday => 'להיום';

  @override
  String get nothingDueInQueue => 'אין כרגע משימות בתור הזה.';

  @override
  String get selfPacedScopeTitle => 'הכול, או רק חלק?';

  @override
  String get learnEntireCurriculumCta => 'רוצה ללמוד את הכול!';

  @override
  String learnEntireCurriculumSubtitle(String name) {
    return 'בחרו את כל $name';
  }

  @override
  String level1Selection(String name, String levelLabel) {
    return '$name ← $levelLabel בחירה';
  }

  @override
  String get scopeSelectedBadge => 'נבחר';

  @override
  String get selectAtLeastOne => 'בחרו לפחות אחד';

  @override
  String continueWithSelectionCount(int count) {
    return 'המשך עם $count נבחרים';
  }

  @override
  String get sectionLearning => 'למידה';

  @override
  String get notificationSettings => 'הגדרות התראות';

  @override
  String get notificationSettingsSubtitle => 'דחיפה, אימייל והתראות קול ללימוד';

  @override
  String pointsAbbrev(int count) {
    return '$count נק׳';
  }

  @override
  String get sectionTracks => 'מסלולים';

  @override
  String get sectionAccount => 'חשבון';

  @override
  String get sectionParentalControls => 'הורה';

  @override
  String get sectionDevice => 'מכשיר';

  @override
  String get sectionProfile => 'פרופיל';

  @override
  String get changePassword => 'שינוי סיסמה';

  @override
  String get signOut => 'התנתקות';

  @override
  String get deleteAccountTitle => 'מחיקת חשבון';

  @override
  String get deleteAccountSubtitle => 'הסרה לצמיתות של החשבון ונתוני הענן';

  @override
  String get deleteLocalAccountSubtitle =>
      'מחיקה לצמיתות של החשבון במכשיר וכל נתוני הלמידה';

  @override
  String get settingsHandcraftedTagline => 'נוצר ביד עבור מסע התורה שלכם';

  @override
  String get calendarPreference => 'העדפת לוח שנה';

  @override
  String get calendarPreferenceSubtitle => 'יעדים, מועדים ובוררי תאריך';

  @override
  String get calendarGregorian => 'אנגלית';

  @override
  String get calendarHebrew => 'עברי';

  @override
  String get hebrewTermsPreference => 'מונחים בעברית';

  @override
  String get hebrewTermsPreferenceSubtitle =>
      'הצגת מונחי לימוד (חזרה, סקירה) בעברית או בתעתיק';

  @override
  String get hebrewTermsHebrew => 'עברית';

  @override
  String get hebrewTermsEnglish => 'אנגלית';

  @override
  String get parentMode => 'מצב הורה';

  @override
  String get parentModeSubtitle => 'מעבר למנהל (מוגן בקוד)';

  @override
  String get parentModeActiveSubtitle => 'ניהול מסלולים, פרסים ומורים';

  @override
  String get parentPin => 'קוד הורה';

  @override
  String get parentPinSubtitle => 'שינוי קוד האבטחה';

  @override
  String get passwordChangedSuccessfully => 'הסיסמה שונתה בהצלחה.';

  @override
  String get notSignedIn => 'לא מחוברים';

  @override
  String get userFallbackDisplayName => 'משתמש';

  @override
  String get proBadge => 'PRO';

  @override
  String get selfLearnerBadge => 'לומד עצמאי';

  @override
  String get parentContextBadge => 'הורה';

  @override
  String get tutorContextBadge => 'מורה';

  @override
  String get noBackup => 'אין גיבוי';

  @override
  String get chooseLanguageTitle => 'בחירת שפה';

  @override
  String get preferredLanguageForContent => 'שפה מועדפת לתוכן';

  @override
  String get profilePickerTitle => 'מי לומד?';

  @override
  String get profilePickerSubtitle => 'בחרו פרופיל כדי להמשיך\nאת המסע';

  @override
  String get profilePickerMyChildren => 'הילדים שלי';

  @override
  String get profilePickerYourProfiles => 'הפרופילים שלך';

  @override
  String get profilePickerTalmidProfiles => 'פרופילי תלמידים';

  @override
  String get profilePickerSkipToSettings => 'מעבר להגדרות';

  @override
  String get profilePickerTutoredChildren => 'ילדים מוּדרכים';

  @override
  String get tutoredChildrenViewInvitations => 'צפייה בהזמנות';

  @override
  String get tutoredChildrenManageGrants => 'ניהול הרשאות הדרכה';

  @override
  String get tutoredChildrenManageGrantsSubtitle =>
      'התפטרות או סקירת גישת ההדרכה שלכם';

  @override
  String tutoredChildrenPendingInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הזמנות הדרכה ממתינות',
      one: 'הזמנת הדרכה אחת ממתינה',
    );
    return '$_temp0';
  }

  @override
  String get tutoredChildrenStatusTutoring => 'מדריך';

  @override
  String get tutoredChildrenRoleBadge => 'מדריך';

  @override
  String get tutorModeIndicator => 'מצב מדריך';

  @override
  String tutorModeIndicatorNamed(String name) {
    return 'מצב מדריך · $name';
  }

  @override
  String get tutorModeExit => 'יציאה';

  @override
  String get tutoredEntryPermissionDenied =>
      'הגישה נדחתה — ייתכן שההרשאה בוטלה.';

  @override
  String get tutoredEntryError =>
      'לא ניתן לטעון את נתוני התלמיד. אנא נסה שנית.';

  @override
  String viewingChildBanner(String name) {
    return 'מצב הורה — צופה ב-$name';
  }

  @override
  String get viewingChildBannerExit => 'יציאה ממצב הורה';

  @override
  String get switchIntoChildTitle => 'מעבר לתצוגת ילד';

  @override
  String switchIntoChildMessage(String name) {
    return 'אתה עומד להיכנס לחוויה המלאה של $name. ניתן לצאת בכל עת מהפס שבראש המסך.';
  }

  @override
  String get switchIntoChildConfirm => 'כניסה';

  @override
  String get tutorCannotMarkLiveCompletion =>
      'מדריכים אינם יכולים לסמן השלמות חיות';

  @override
  String get tutorWriteForbiddenTitle => 'פעולה לא מורשית';

  @override
  String get tutorWriteForbiddenMessage =>
      'מדריכים אינם יכולים לסמן השלמות חיות. פעולה זו מזכה את הרצף והפרסים של הילד, ושמורה להורה או לילד.';

  @override
  String get tutorPermissionDenied => 'אין לך הרשאה לבצע עריכה זו';

  @override
  String get addProfile => 'הוספת פרופיל';

  @override
  String get createProfile => 'יצירת פרופיל';

  @override
  String get enterNameHint => 'הזינו שם';

  @override
  String get chooseMode => 'בחירת מצב';

  @override
  String get childModeCardTitle => 'מצב ילדים';

  @override
  String get childModeCardSubtitleFunRewards => 'כיף ופרסים';

  @override
  String get adultModeCardTitle => 'מצב מבוגרים';

  @override
  String get adultModeCardSubtitleDeepFocused => 'עומק ומיקוד';

  @override
  String get profileBadgeChildMode => 'מצב ילדים';

  @override
  String get profileBadgeAdultMode => 'מצב מבוגרים';

  @override
  String get profileBadgeParentMode => 'מצב הורה';

  @override
  String profileNameTaken(String name) {
    return 'כבר קיים פרופיל בשם \"$name\"';
  }

  @override
  String get maxProfilesReached => 'הגעתם למקסימום — 10 פרופילים';

  @override
  String get renameAction => 'שינוי שם';

  @override
  String get mustKeepOneProfile => 'חייב להישאר לפחות פרופיל אחד';

  @override
  String get profileNameAlreadyExists => 'כבר קיים פרופיל עם השם הזה';

  @override
  String get renameProfileTitle => 'שינוי שם פרופיל';

  @override
  String get displayName => 'שם תצוגה';

  @override
  String get deleteProfileTitle => 'מחיקת פרופיל';

  @override
  String deleteProfileConfirm(String name) {
    return 'למחוק לצמיתות את \"$name\" ואת כל נתוני הלמידה הקשורים? לא ניתן לבטל.';
  }

  @override
  String get cannotDeleteOnlyProfile => 'לא ניתן למחוק את הפרופיל היחיד';

  @override
  String get tapToContinue => 'הקשו כדי\nלהמשיך';

  @override
  String get maxProfilesLabel => 'מקס׳ פרופילים';

  @override
  String get addProfileCardTitle => 'הוספת\nפרופיל';

  @override
  String get maxProfilesSubtitle => 'הגעתם למקסימום';

  @override
  String get createNewLearner => 'ליצור לומד\nחדש';

  @override
  String get profilesLabel => 'פרופילים';

  @override
  String get syncTitle => 'סנכרון';

  @override
  String get syncScreenBody => 'מצב הסנכרון וההגדרות יופיעו כאן.';

  @override
  String get parentSettingsTitle => 'הגדרות הורה';

  @override
  String get manageTutors => 'ניהול מדריכים';

  @override
  String get manageTutorsSubtitle => 'הזמנה או הסרה של מדריכים לילד זה';

  @override
  String get manageTracksForChildSubtitle =>
      'הוספה, עריכה או ארכיון של מסלולי הילד';

  @override
  String get manageGoals => 'ניהול מטרות';

  @override
  String get manageGoalsSubtitle => 'הגדרת מטרות קצב או יעד לכל מסלול';

  @override
  String get manageChildLearningSubtitle =>
      'ניהול מסלולים, נקודות, פרסים ומטרות';

  @override
  String get pointConfiguration => 'הגדרת נקודות';

  @override
  String get pointConfigurationSubtitle => 'כמה נקודות שווה כל פעילות';

  @override
  String get rewardConfigurationTitle => 'הגדרת פרסים';

  @override
  String get rewardConfigurationSubtitle =>
      'הגדירו פרסים שהילד יוכל לממש עם הנקודות שצבר.';

  @override
  String get rewardConfigPerTrackTab => 'לפי מסלול';

  @override
  String get rewardConfigTotalPointsTab => 'סך נקודות';

  @override
  String get rewardConfigPerTrackHelper =>
      'הפרסים מבוססים על נקודות במסלול הנבחר בלבד.';

  @override
  String get rewardConfigTotalPointsHelper =>
      'הפרסים מבוססים על סך הנקודות מכל מסלולי הלמידה (כמו סך הנקודות הכולל של הילד).';

  @override
  String get rewardConfigSelectTrack => 'מסלול';

  @override
  String get rewardConfigNoActiveTracks =>
      'אין מסלולים פעילים. הוסיפו מסלול כדי להגדיר פרסים לפי מסלול.';

  @override
  String get rewardConfigAddReward => 'הוסף פרס';

  @override
  String get rewardConfigEditReward => 'עריכת פרס';

  @override
  String get rewardConfigRewardNameLabel => 'שם הפרס';

  @override
  String get rewardConfigPointsThresholdLabel => 'נקודות נדרשות';

  @override
  String get rewardConfigSaveReward => 'שמירה';

  @override
  String get rewardConfigDeleteReward => 'מחיקה';

  @override
  String get rewardConfigDuplicateThreshold =>
      'פרס אחר כבר משתמש בערך נקודות זה.';

  @override
  String get rewardConfigEmptyMilestones =>
      'עדיין אין פרסים. לחצו למטה להוספה.';

  @override
  String get rewardConfigSaved => 'הפרסים נשמרו';

  @override
  String get parentPortalTitle => 'פורטל הורים';

  @override
  String get rewardConfigScreenContextLabel => 'הגדרת פרסים';

  @override
  String get rewardConfigConfigureNewTitle => 'הגדרת פרס חדש';

  @override
  String get rewardConfigConfigureNewSubtitle =>
      'בחרו סמל והגדירו יעדי נקודות לילד.';

  @override
  String get rewardConfigChooseAvatarStep => '1. בחירת סמל';

  @override
  String get rewardConfigRewardTypeLabel => 'סוג פרס';

  @override
  String get rewardConfigChooseTrackLabel => 'בחירת מסלול';

  @override
  String get rewardConfigPreviewLabel => 'תצוגה מקדימה';

  @override
  String rewardConfigPointsPreview(int points) {
    return '$points נקודות';
  }

  @override
  String get rewardConfigCancel => 'ביטול';

  @override
  String get rewardConfigSaveRewardButton => 'שמירת פרס';

  @override
  String get rewardConfigUpdateRewardButton => 'עדכון פרס';

  @override
  String get rewardConfigEditModeSubtitle =>
      'עדכן את הסמל, השם, או עלות הנקודות עבור פרס זה.';

  @override
  String get rewardConfigNamePlaceholder => 'למשל, כוכב ארד';

  @override
  String get rewardConfigPointsPlaceholder => 'למשל, 500';

  @override
  String get rewardConfigMenuManageRewards => 'ניהול פרסים';

  @override
  String get rewardConfigRewardCreatedTitle => 'הפרס נוצר';

  @override
  String rewardConfigRewardCreatedBody(String name) {
    return '\"$name\" נוסף. הילד יראה אותו תחת הישגים — נעול ומטושטש עד שיגיע ליעד הנקודות.';
  }

  @override
  String get rewardConfigRewardUpdatedTitle => 'הפרס עודכן';

  @override
  String rewardConfigRewardUpdatedBody(String name) {
    return 'השינויים ב־\"$name\" נשמרו. הילד יראה את העדכון תחת הישגים.';
  }

  @override
  String get pointConfigPerTaskTitle => 'נקודות לכל משימה שהושלמה';

  @override
  String get pointConfigPerTaskDescription =>
      'לכל מסלול למידה פעיל, הגדירו כמה נקודות הילד מקבל כשהוא משלים משימה אחת מהרשימה היומית. הסכום תלוי בשלב המשימה (למשל לימוד ראשון מול חזרה).';

  @override
  String get pointConfigNoActiveTracksBody =>
      'לא נמצאו מסלולי למידה פעילים עם שלבים לילד הזה. הפעילו מקצועות והגדירו מסלולים תחת ניהול מסלולים, ואז חזרו לכאן כדי לקבוע נקודות לכל משימה.';

  @override
  String get pointSettingsTitle => 'הגדרות נקודות';

  @override
  String get pointSettingsConfigurationLabel => 'הגדרות';

  @override
  String get pointSettingsRewardsStrategyTitle => 'אסטרטגיית פרסים';

  @override
  String get pointSettingsRewardsStrategySubtitle =>
      'כווננו כמה נקודות הילד מקבל בכל צעד משמעותי בלמידה.';

  @override
  String get pointSettingsActiveCurricula => 'מקצועות פעילים';

  @override
  String get pointSettingsPointsPerTask => 'נקודות למשימה';

  @override
  String get pointSettingsPts => 'נק׳';

  @override
  String get pointSettingsActiveBadge => 'פעיל';

  @override
  String get pointSettingsSaveAll => 'שמירת כל השינויים';

  @override
  String get pointSettingsSaveFooter =>
      'שינויי הנקודות יסתנכרנו מיד ללוח הילד.';

  @override
  String get pointSettingsSavedSnackbar => 'השינויים נשמרו וסונכרנו.';

  @override
  String get pointSettingsNothingToSaveSnackbar => 'אין שינויים לשמירה.';

  @override
  String get pointSettingsPrimaryStageLabel => 'השלמה ראשונה (משימה יומית)';

  @override
  String get sectionAccountSafety => 'בטיחות חשבון';

  @override
  String get bottomNavTracks => 'מסלולים';

  @override
  String get bottomNavRewards => 'פרסים';

  @override
  String get bottomNavParent => 'הורה';

  @override
  String get addProfileDialogSubtitle => 'הזינו שם ובחרו מצב ילד או מבוגר.';

  @override
  String get setParentPinDialogTitle => 'הגדרת קוד הורה';

  @override
  String setParentPinDialogSubtitle(String name) {
    return 'הגדירו קוד בן 4 ספרות לשליטה הורית עבור $name. הקוד נשמר רק במכשיר זה.';
  }

  @override
  String get enterParentPin => 'הזינו קוד הורה';

  @override
  String get enterParentPinSubtitle =>
      'הזינו קוד בן 4 ספרות כדי לגשת להגדרות הורה.';

  @override
  String get enterNewPinSubtitle => 'בחרו קוד חדש בן 4 ספרות.';

  @override
  String get confirmNewPinSubtitle => 'הזינו שוב את אותו קוד לאישור.';

  @override
  String get changeParentPin => 'שינוי קוד הורה';

  @override
  String get pinChangedSuccessfully => 'הקוד שונה בהצלחה';

  @override
  String get pinFlowSetupSubtitle =>
      'הגדירו קוד חדש בן 4 ספרות להפעלת מצב הורה.';

  @override
  String get pinFlowSetupDeviceLocalBanner =>
      'קודי ההורה נשמרים רק במכשיר זה. הגדירו קוד חדש בן 4 ספרות להפעלת מצב הורה. מכשירים אחרים שומרים קוד משלהם.';

  @override
  String get deviceRestoreChecking => 'בודקים מכשיר...';

  @override
  String get deviceRestoreComplete => 'השחזור הושלם!';

  @override
  String get deviceRestoreFailed => 'השחזור נכשל';

  @override
  String deviceRestoreStep(int completed, int total) {
    return 'שלב $completed מתוך $total';
  }

  @override
  String get deviceRestorePhaseRestoring => 'מחזיר את הנתונים שלך...';

  @override
  String get deviceRestorePhaseLoadingCurricula => 'טוען תוכניות לימוד...';

  @override
  String get deviceRestorePhaseImportingContent => 'מייבא תוכן...';

  @override
  String get skipAndContinue => 'דלגו והמשיכו';

  @override
  String get noActiveProfile => 'אין פרופיל פעיל';

  @override
  String get incorrectPin => 'קוד שגוי';

  @override
  String get enterCurrentPin => 'הזינו את הקוד הנוכחי';

  @override
  String get enterCurrentPinSubtitle =>
      'הזינו את הקוד הנוכחי בן 4 ספרות כדי לשנותו.';

  @override
  String get enterNewPin => 'הזינו קוד חדש';

  @override
  String get confirmNewPin => 'אשרו את הקוד החדש';

  @override
  String get pinsDoNotMatch => 'הקודים אינם תואמים';

  @override
  String get tabBarDashboard => 'לוח';

  @override
  String get tabBarLearn => 'למידה';

  @override
  String get tabBarProgress => 'התקדמות';

  @override
  String get tabBarSettings => 'הגדרות';

  @override
  String get errorLoadingCalendar => 'שגיאה בטעינת לוח השנה';

  @override
  String get journeyByCurriculum => 'לפי תוכנית';

  @override
  String get journeyTimeline => 'ציר זמן';

  @override
  String journeyTitleNamed(String name) {
    return 'מסע הלמידה של $name';
  }

  @override
  String get loadingYourJourney => 'טוענים את המסע...';

  @override
  String failedToLoadJourney(String error) {
    return 'נכשל בטעינת המסע: $error';
  }

  @override
  String get journeyEmptyTitle => 'עדיין אין סיומים';

  @override
  String get journeyEmptyBody =>
      'כשתסיימו מסכתא או ספר, הוא יירשם כאן כאבן דרך קבועה.';

  @override
  String get chartCumulativeProgress => 'התקדמות מצטברת';

  @override
  String get chartCumulativeProgressSubtitle => 'סה״כ השלמות לאורך זמן';

  @override
  String get chartPointsEarned => 'נקודות שהורו';

  @override
  String get chartTotalTorahPoints => 'נק׳ תורה סה״כ';

  @override
  String get chartLast7Days => '7 ימים';

  @override
  String get chartLast30Days => '30\nימים';

  @override
  String get chartAllTime => 'הכול';

  @override
  String get chartFilterAll => 'הכול';

  @override
  String get learnStreakCurrentAchievement => 'הישג נוכחי';

  @override
  String learnStreakDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'רצף $count ימים',
      one: 'רצף יום 1',
    );
    return '$_temp0';
  }

  @override
  String learnStreakPersonalBest(int count) {
    return 'שיא אישי: $count';
  }

  @override
  String get learnStreakKeepItUp => 'כל הכבוד!';

  @override
  String get notifAppBarNotifications => 'התראות';

  @override
  String get notifDailyReminder => 'תזכורת יומית';

  @override
  String get notifDailyReminderSubtitle => 'אל תשכחו ללמוד היום!';

  @override
  String get notifReminderTime => 'שעת תזכורת';

  @override
  String get notifStreakAlert => 'התראת רצף';

  @override
  String get notifStreakAlertSubtitle => 'שמרו על האש בוערת!';

  @override
  String get notifHotStreakBadge => 'רצף לוהט';

  @override
  String get notifStreakAlertTime => 'שעת התראת רצף';

  @override
  String get notifRewardMilestones => 'התראות פרסים';

  @override
  String get notifRewardMilestonesSubtitle => 'כשאתם מרוויחים נק׳ למידה!';

  @override
  String get notifSacredTime => 'מצב שבת';

  @override
  String get notifShabbosYomTovMode => 'מצב שבת / יום טוב';

  @override
  String get notifShabbosModeSubtitle => 'לימוד שקט בימים קדושים';

  @override
  String get notifUseLocationForTimes => 'מיקום לשעות';

  @override
  String get notifQuietStart => 'התחלת שקט';

  @override
  String get notifQuietEnd => 'סיום שקט';

  @override
  String get notifCandleLighting => 'הדלקת נרות';

  @override
  String get notifHavdalah => 'הבדלה';

  @override
  String get authPasswordRequired => 'נדרשת סיסמה';

  @override
  String get authLocalDataMissing =>
      'נתונים מקומיים של חשבון זה חסרים. התחברו לאינטרנט כדי לשחזר אותם.';

  @override
  String get authEmailOfflineUnreachable =>
      'האימייל הזה אינו במכשיר ואין גישה לענן. נסו שוב כשאתם מקוונים.';

  @override
  String get authIncorrectPassword => 'סיסמה שגויה.';

  @override
  String authSignInFailedError(String error) {
    return 'הכניסה נכשלה: $error';
  }

  @override
  String get authVerifyEmailBody =>
      'שלחנו קישור אימות לתיבה שלכם. בדקו את האימייל כדי להמשיך.';

  @override
  String get authIveVerified => 'אימתתי';

  @override
  String get authVerificationEmailSentAgain => 'מייל אימות נשלח שוב.';

  @override
  String get authEmailStillUnverified =>
      'האימייל עדיין לא אומת. בדקו קודם את תיבת הדואר.';

  @override
  String authMaxDeviceAccounts(int count) {
    return 'הגעתם למקסימום $count חשבונות במכשיר. הסירו אחד כדי להוסיף.';
  }

  @override
  String get authOfflineUseUpgrade =>
      'במכשיר כבר קיים חשבון אוף־ליין עם אימייל זה. השתמשו ב״שדרג לענן״ בהגדרות.';

  @override
  String get authGoogleSignInFailed => 'הכניסה בגוגל נכשלה. נסו שוב.';

  @override
  String get authErrUserNotFound => 'לא נמצא חשבון עם האימייל הזה.';

  @override
  String get authErrWrongPassword => 'סיסמה שגויה. נסו שוב.';

  @override
  String get authErrInvalidCredential => 'אימייל או סיסמה לא תקינים. נסו שוב.';

  @override
  String get authErrUserDisabled => 'חשבון זה הושבת.';

  @override
  String get authErrTooManyRequests => 'יותר מדי נסיונות. נסו שוב מאוחר יותר.';

  @override
  String get authErrInvalidEmail => 'הזינו כתובת אימייל תקינה.';

  @override
  String get authErrNetwork => 'שגיאת רשת. בדקו את החיבור.';

  @override
  String get authErrSignInGeneric => 'ההתחברות נכשלה. נסו שוב.';

  @override
  String get authTierCloud => 'ענן';

  @override
  String get authTierLocal => 'מקומי';

  @override
  String authFoundOnDevice(String tier) {
    return 'נמצא במכשיר הזה ($tier)';
  }

  @override
  String get authNotOnDeviceCheckCloud => 'לא על המכשיר — נבדוק מול הענן';

  @override
  String get authNotOnDeviceOffline =>
      'לא על המכשיר (לא מקוונים — רק חשבונות מקומיים)';

  @override
  String get authModeCloud =>
      'חשבון ענן: הנתונים מגובים ומסתנכרנים בין מכשירים.';

  @override
  String get authModeCloudOffline =>
      'החשבון בענן לא מקוון כרגע. ננסה נתונים מקומיים עד שיוחזר אינטרנט.';

  @override
  String get authModeLocalTitle =>
      'חשבון מקומי בלבד: ללא גיבוי לענן וללא סנכרון בין מכשירים.';

  @override
  String get authModeLocalBody =>
      'ללא גיבוי לענן. הנתונים נשארים רק במכשיר הזה.';

  @override
  String get signInWelcomeBack => 'ברוכים השבים!';

  @override
  String get signInReady => 'מוכנים להרפתקת הלמידה הבאה?';

  @override
  String get signInYourEmail => 'האימייל שלכם';

  @override
  String get signInEmailHint => 'yourname@quest.com';

  @override
  String get signInPasswordLabel => 'סיסמה';

  @override
  String get signInPasswordHint => 'הכניסו את הסיסמה';

  @override
  String get signInKeepMeSignedIn => 'השאירו אותי מחוברים';

  @override
  String get signInForgotPassword => 'שכחתי סיסמה?';

  @override
  String get signInForgotPasswordSent =>
      'נשלח מייל לאיפוס סיסמה. בדקו את תיבת הדואר.';

  @override
  String get signInForgotPasswordNoEmail => 'נא הכניסו כתובת אימייל תחילה.';

  @override
  String get signInCta => 'התחברות';

  @override
  String get signInWithGoogleCta => 'התחברות עם גוגל';

  @override
  String get signInNewToQuest => 'חדשים בקווסט? ';

  @override
  String get signInRegisterHere => 'הרשמה כאן';

  @override
  String get signUpTitle => 'צור חשבון';

  @override
  String get signUpSubtitle => 'צור את חשבונך החינמי';

  @override
  String get signUpScholarNameHint => 'שם הלומד';

  @override
  String get signUpEmailAddressLabel => 'כתובת אימייל';

  @override
  String get signUpPasswordLabel => 'צור סיסמה';

  @override
  String get signUpPasswordHint => 'צור סיסמה בטוחה';

  @override
  String get signUpCta => 'הרשמה';

  @override
  String get signUpOrDivider => 'או';

  @override
  String get signUpGoogleCta => 'הרשמה עם גוגל';

  @override
  String get signUpAlreadyExploring => 'כבר בחקירה? ';

  @override
  String get signUpLogIn => 'כניסה';

  @override
  String get signUpOfflineAck => 'מצב לא מקוון: החשבון נשמר רק במכשיר הזה.';

  @override
  String get signUpAckRequiredError =>
      'אנא אשר את האזהרה לחשבון לא מקוון לפני יצירת חשבון אופ־ליין.';

  @override
  String get signUpVerificationEmailSent =>
      'אימייל אימות נשלח. אמת את האימייל שלך ולאחר מכן היכנס.';

  @override
  String get signUpEmailAlreadyExists => 'חשבון כבר קיים עם האימייל הזה.';

  @override
  String get signUpDeviceEmailExists =>
      'חשבון עם האימייל הזה כבר קיים במכשיר. היכנס במקום זאת.';

  @override
  String get signUpOfflineInProgress =>
      'הרשמה לא מקוונת לאימייל זה כבר בתהליך. סיים יצירת פרופיל או נסה שוב מאוחר יותר.';

  @override
  String get signUpOfflineEmailExists =>
      'חשבון לא מקוון כבר קיים במכשיר הזה עם האימייל הזה.';

  @override
  String signUpFailed(String error) {
    return 'ההרשמה נכשלה: $error';
  }

  @override
  String get signUpFallbackBody =>
      'החיבור לאינטרנט נפסק במהלך ההרשמה. האם ברצונך ליצור חשבון לא מקוון במקום זאת?';

  @override
  String get signUpErrWeakPassword => 'הסיסמה חלשה מדי. השתמש לפחות ב-6 תווים.';

  @override
  String get signUpErrGeneric => 'יצירת החשבון נכשלה. נסה שוב.';

  @override
  String get chartFailedToLoad => 'נכשל בטעינת הנתונים';

  @override
  String get accountPickerTitle => 'בחירת חשבון';

  @override
  String get accountPickerSubtitle => 'בחרו משתמש כדי להמשיך';

  @override
  String accountPickerMaxAccountsShort(int count) {
    return 'הגעתם למקסימום $count חשבונות';
  }

  @override
  String get accountPickerPrivacyFooter => 'ניהול פרטיות ואבטחה בהגדרות';

  @override
  String get accountRemoveFromDevice => 'הסרה מהמכשיר';

  @override
  String get accountDeleteAccountAction => 'מחיקת חשבון';

  @override
  String get badgeLocalAccount => 'חשבון מקומי';

  @override
  String get badgeSignInAgain => 'התחברו שוב';

  @override
  String get badgeCloudAccount => 'חשבון ענן';

  @override
  String get accountRemoveFromDeviceTitle => 'להסיר מהמכשיר?';

  @override
  String get accountDeleteAccountTitle => 'למחוק חשבון?';

  @override
  String get accountRemoveFromDeviceBody =>
      'הנתונים בענן בטוחים — תוכלו להתחבר שוב בכל עת.';

  @override
  String get accountDeleteAccountBody =>
      'כל נתוני הלמידה יימחקו לצמיתות. לא ניתן לבטל.';

  @override
  String get accountRemove => 'הסרה';

  @override
  String get accountDeleteForever => 'מחיקה לצמיתות';

  @override
  String accountPickerAddAnother(int remaining) {
    return '+1   הוספת חשבון ($remaining מקומות פנויים)';
  }

  @override
  String get cannotDeactivateLastCurriculum =>
      'חייב להישאר לפחות קורס לימוד אחד פעיל';

  @override
  String get cannotDeactivateLastCurriculumDetail =>
      'לא ניתן להסיר את קורס הלימוד האחרון הפעיל. הוסיפו קורס נוסף לפני הסרת זה.';

  @override
  String get actionStart => 'התחל';

  @override
  String get actionCancel => 'ביטול';

  @override
  String get actionSave => 'שמור';

  @override
  String get actionConfirm => 'אישור';

  @override
  String get actionReset => 'איפוס';

  @override
  String get actionNext => 'הבא';

  @override
  String get actionBack => 'חזור';

  @override
  String get actionContinue => 'המשך';

  @override
  String get actionSkip => 'דלג';

  @override
  String get actionRetry => 'נסה שוב';

  @override
  String get actionExit => 'יציאה';

  @override
  String get actionReplace => 'החלף';

  @override
  String get actionDelete => 'מחק';

  @override
  String get actionEdit => 'ערוך';

  @override
  String get actionClose => 'סגור';

  @override
  String get actionOk => 'אישור';

  @override
  String get actionSkipForNow => 'דלג לעכשיו';

  @override
  String get actionRemove => 'הסר';

  @override
  String get actionUseToday => 'השתמש בהיום';

  @override
  String get actionStartHere => 'התחל כאן';

  @override
  String get actionStartHereLabel => 'התחל כאן';

  @override
  String errorGeneric(String error) {
    return 'שגיאה: $error';
  }

  @override
  String errorLoadingOrder(String error) {
    return 'שגיאה בטעינת הסדר: $error';
  }

  @override
  String errorLoadingContent(String error) {
    return 'שגיאה בטעינת תוכן: $error';
  }

  @override
  String get errorLoadingPoints => 'שגיאה בטעינת נקודות';

  @override
  String get errorSaveFailed => 'השמירה נכשלה. נסו שוב.';

  @override
  String errorSearchFailed(String error) {
    return 'החיפוש נכשל: $error';
  }

  @override
  String errorSearchError(String error) {
    return 'שגיאת חיפוש: $error';
  }

  @override
  String errorUnknownCurriculum(String curriculumId) {
    return 'קורס לימוד לא מוכר: \"$curriculumId\"';
  }

  @override
  String get errorCouldNotSaveRetry => 'לא ניתן לשמור — לחצו לניסיון חוזר';

  @override
  String get errorSaveTrackFailed => 'שמירת המסלול נכשלה. נסו שוב.';

  @override
  String get errorSignOutFailed => 'יציאה נכשלה. נסו שוב.';

  @override
  String get errorReauthFailed => 'אימות מחדש נכשל. נסו שוב.';

  @override
  String get errorResolveAccount => 'לא ניתן לאמת את החשבון. נסו שוב.';

  @override
  String get errorOnlyOfflineDelete => 'ניתן למחוק כאן רק חשבונות לא מקוונים.';

  @override
  String get errorDeleteProfileRequiresInternet =>
      'נדרש חיבור לאינטרנט כדי למחוק פרופיל.';

  @override
  String get errorDeleteAccountRequiresInternet =>
      'נדרש חיבור לאינטרנט כדי למחוק את החשבון.';

  @override
  String errorDeleteAccountFailed(String error) {
    return 'מחיקת החשבון נכשלה: $error';
  }

  @override
  String get errorSendLogsMustBeSignedIn => 'יש להיות מחובר כדי לשלוח יומנים';

  @override
  String get errorSendLogsNoGateway =>
      'סנכרון לא זמין — החשבון אינו מקושר לענן';

  @override
  String errorSendLogsFailed(String error) {
    return 'שליחת היומנים נכשלה: $error';
  }

  @override
  String sendLogsSuccess(int count) {
    return 'היומנים נשלחו ($count רשומות). צפו במסוף Firebase ← diagnostic_logs.';
  }

  @override
  String get errorNoEmailApp =>
      'לא נמצאה אפליקציית דוא\"ל. להעתיק כתובת במקום?';

  @override
  String errorMarkCompleteFailed(String error) {
    return 'סימון כהושלם נכשל: $error';
  }

  @override
  String get errorVerificationEmailSent =>
      'נשלח אימייל אימות. בדקו את תיבת הדואר.';

  @override
  String get noData => 'אין נתונים';

  @override
  String get noTasksForToday => 'אין משימות להיום';

  @override
  String get noItemsToOrder => 'אין פריטים לסידור.';

  @override
  String get noProfilesYet => 'אין פרופילים עדיין. לחצו + להוספה.';

  @override
  String get noCompletionsYet => 'אין השלמות עדיין';

  @override
  String noResultsForQuery(String query) {
    return 'אין תוצאות עבור \"$query\"';
  }

  @override
  String viewAllTasks(int count) {
    return 'הצג הכול ($count) →';
  }

  @override
  String tasksDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count משימות היום',
      one: 'משימה אחת היום',
    );
    return '$_temp0';
  }

  @override
  String get tapToStartLearning => 'לחצו להתחיל ללמוד';

  @override
  String get todaysLearningTitle => 'לימוד היום';

  @override
  String remainingCount(int count) {
    return '$count נותרו';
  }

  @override
  String get allDoneForToday => 'סיימתם להיום!';

  @override
  String missedReview(int count) {
    return 'חזרה שהוחמצה ($count)';
  }

  @override
  String todaysReview(int count) {
    return 'חזרה של היום ($count)';
  }

  @override
  String get dailyTasksTitle => 'משימות יומיות';

  @override
  String get taskSkippedUntilTomorrow => 'המשימה נדחתה למחר';

  @override
  String get tasksNoTasksRemainingTitle => 'אין משימות נותרות להיום.';

  @override
  String get undoLabel => 'בטל';

  @override
  String get searchTitle => 'חיפוש';

  @override
  String get searchHintEnterTerm => 'הזינו מונח חיפוש למעלה';

  @override
  String get loadingText => 'טוען טקסט...';

  @override
  String get markedComplete => 'סומן כהושלם';

  @override
  String couldNotSave(String error) {
    return 'לא ניתן לשמור: $error';
  }

  @override
  String get textReaderTooltipPrevious => 'הקודם';

  @override
  String get textReaderTooltipNext => 'הבא';

  @override
  String get textReaderHebrewTab => 'טקסט עברי';

  @override
  String get textReaderEnglishTab => 'תרגום לאנגלית';

  @override
  String get totalPointsLabel => 'סה\"כ נקודות';

  @override
  String get resetToDefaultOrder => 'איפוס לסדר ברירת מחדל';

  @override
  String get resetToDefaultOrderDialogTitle => 'איפוס לסדר ברירת מחדל';

  @override
  String get resetToDefaultOrderDialogBody =>
      'פעולה זו תשחזר את הסדר הטבעי של ספריא עבור קורס לימוד זה. הסדר המותאם אישית שלכם יאבד.';

  @override
  String get reorderConfirmTitle => 'לשנות סדר תוכן?';

  @override
  String reorderConfirmBody(int overdueCount) {
    return 'שינוי הסדר יאפס את $overdueCount הפריטים הפיגורים שלך. שקול להשלים אותם קודם.';
  }

  @override
  String get controlledByParent => 'בשליטת ההורה';

  @override
  String sacredTimeLockGoodShabbos(String term) {
    return 'שבת שלום';
  }

  @override
  String sacredTimeLockShabbosSubtitle(String term) {
    return 'האפליקציה סגורה לכבוד שבת.';
  }

  @override
  String get sacredTimeLockGoodYomTov => 'חג שמח';

  @override
  String get sacredTimeLockYomTovSubtitle => 'האפליקציה סגורה לכבוד יום טוב.';

  @override
  String sacredTimeLockShabbosYomTovGreeting(String term) {
    return 'שבת שלום וחג שמח';
  }

  @override
  String sacredTimeLockShabbosYomTovSubtitle(String term) {
    return 'האפליקציה סגורה לכבוד שבת ויום טוב.';
  }

  @override
  String get sacredTimeLockYomKippurGreeting => 'גמר חתימה טובה';

  @override
  String get sacredTimeLockYomKippurSubtitle =>
      'האפליקציה סגורה לכבוד יום כיפור.';

  @override
  String get sacredTimeDetect => 'זיהוי אוטומטי';

  @override
  String get sacredTimeChooseCity => 'בחר עיר';

  @override
  String get textReaderTextUnavailableTitle => 'הטקסט אינו זמין';

  @override
  String get textReaderCheckConnection => 'בדקו את חיבור האינטרנט ונסו שוב.';

  @override
  String get textReaderFailedToLoad => 'טעינת הטקסט נכשלה';

  @override
  String sacredTimeCardDescription(String term) {
    return 'האפליקציה מושתקת ונעולה בשבת וביום טוב. הזמנים מחושבים מקומית לפי המיקום שלכם עם מרווח של 15 דקות.';
  }

  @override
  String sacredTimeShabbosModeLabel(String term) {
    return 'מצב שבת';
  }

  @override
  String get sacredTimeAlwaysOn => 'תמיד פעיל';

  @override
  String get sacredTimeNoLocation => 'לא הוגדר מיקום';

  @override
  String get sacredTimeSourceDetected => 'זוהה אוטומטית';

  @override
  String get sacredTimeSourceManualCity => 'נבחר מרשימת ערים';

  @override
  String get sacredTimeSourceManualCoords => 'קואורדינטות ידניות';

  @override
  String get sacredTimeInIsraelTitle => 'אני בישראל';

  @override
  String get sacredTimeInIsraelSubtitle =>
      'חג של יום אחד כאשר מופעל. נקבע אוטומטית כשמזהים או בוחרים עיר; שנו אם אתם מבקרים.';

  @override
  String get sacredTimeLocationUpdated => 'המיקום עודכן.';

  @override
  String get sacredTimeLocationPermissionPermanentlyDenied =>
      'הרשאת המיקום נדחתה לצמיתות. פתחו את הגדרות המערכת כדי לאפשר.';

  @override
  String get sacredTimeLocationPermissionDenied => 'הרשאת המיקום נדחתה.';

  @override
  String get sacredTimeLocationServicesOff => 'שירותי המיקום כבויים במכשיר זה.';

  @override
  String sacredTimeLocationDetectError(String message) {
    return 'לא ניתן לזהות מיקום: $message';
  }

  @override
  String get newPasswordLabel => 'סיסמה חדשה';

  @override
  String get confirmNewPasswordLabel => 'אישור סיסמה חדשה';

  @override
  String get passwordMinLengthError => 'הסיסמה חייבת להכיל לפחות 6 תווים';

  @override
  String get passwordsDoNotMatchError => 'הסיסמאות אינן תואמות';

  @override
  String get changePasswordFailedError => 'שינוי הסיסמה נכשל. אנא נסו שוב.';

  @override
  String get currentPasswordLabel => 'סיסמה נוכחית';

  @override
  String get invalidPasswordError => 'סיסמה שגויה. אנא נסו שוב.';

  @override
  String get calendarOffsetToday => 'היום';

  @override
  String get dayNameShabbos => 'שבת';

  @override
  String get statusPendingTapToAccept => 'ממתין — הקישו לאישור';

  @override
  String calendarOffsetDay(String offset) {
    return 'יום $offset';
  }

  @override
  String get calendarDirectionForward => 'קדימה';

  @override
  String get calendarDirectionBackwards => 'אחורה';

  @override
  String get calendarDirectionToday => 'היום';

  @override
  String calendarOffsetDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ימים',
      two: 'יומיים',
      one: 'יום אחד',
    );
    return '$_temp0';
  }

  @override
  String startingPositionSelectInstruction(String itemLabel) {
    return 'בחרו את $itemLabel שאתם נמצאים בו כעת.';
  }

  @override
  String searchFieldHint(String label) {
    return 'חיפוש $label…';
  }

  @override
  String get cityPickerTitle => 'בחרו עיר';

  @override
  String get cityPickerHint => 'הקלד שם עיר…';

  @override
  String get schedulerStudyLabel => 'לימוד';

  @override
  String get schedulerReviewOnlyLabel => 'חזרה בלבד';

  @override
  String get schedulerPerDay => 'ליום';

  @override
  String get schedulerPerWeek => 'לשבוע';

  @override
  String get schedulerPerakimLabel => 'פרקים';

  @override
  String get schedulerPesukimLabel => 'פסוקים';

  @override
  String get schedulerAmudimLabel => 'עמודים';

  @override
  String get schedulerDafimLabel => 'דפים';

  @override
  String get schedulerDeadlineLabel => 'דד-ליין';

  @override
  String get schedulerPaceLabel => 'קצב';

  @override
  String get schedulerNoDeadlineLabel => 'ללא דד-ליין';

  @override
  String get schedulerGoalHint => 'לדוג׳, בר מצווה, יארצייט, סיום';

  @override
  String get schedulerSelectDate => 'בחר תאריך';

  @override
  String get schedulerPickDeadlineFirst => 'בחרו דד-ליין קודם.';

  @override
  String get schedulerDaysLabel => 'ימים';

  @override
  String get schedulerWeeksLabel => 'שבועות';

  @override
  String get profilesEditLabel => 'ערוך';

  @override
  String get profilesDeleteLabel => 'מחק';

  @override
  String get profilesChooseAvatar => 'בחרו אווטאר';

  @override
  String get profilesAddLearner => 'הוסף לומד';

  @override
  String get profilesEditLearner => 'ערוך לומד';

  @override
  String get profilesChildLabel => 'ילד';

  @override
  String get profilesAdultLabel => 'מבוגר';

  @override
  String get profilesEnterLearnerName => 'הזינו שם לומד';

  @override
  String get profilesNameFieldLabel => 'שם';

  @override
  String get deleteProfileLastTitle => 'למחוק את הפרופיל היחיד שלך?';

  @override
  String deleteProfileBody(String name) {
    return 'האם למחוק את \"$name\"? כל נתוני הלמידה של פרופיל זה יימחקו לצמיתות.';
  }

  @override
  String deleteProfileLastBody(String name) {
    return 'זהו הפרופיל היחיד שלך. מחיקת \"$name\" תמחק כל מסלול, השלמה ורישום מצטבר בחשבון זה. יהיה עליך ליצור פרופיל חדש כדי להמשיך ללמוד.';
  }

  @override
  String get deleteProfileLastConfirm => 'מחק בכל זאת';

  @override
  String get trackNameThisTrack => 'שמרו מסלול זה';

  @override
  String get trackNameLabel => 'שם המסלול';

  @override
  String get trackAddLabel => 'הוסף מסלול';

  @override
  String get trackDeleteTitle => 'למחוק מסלול?';

  @override
  String get trackMarkContentDone => 'סמן תוכן כהושלם';

  @override
  String get trackReorderContent => 'סדר מחדש תוכן';

  @override
  String trackReplaceTitle(String label) {
    return 'להחליף את מסלול $label?';
  }

  @override
  String get bulkMarkCompleteTitle => 'סימון המוני כהושלם';

  @override
  String bulkMarkedComplete(int count) {
    return 'סומנו $count פריטים כהושלמו';
  }

  @override
  String get bulkMarkConfirmBulkTitle => 'אישור סימון המוני';

  @override
  String get bulkMarkingCompletions => 'מסמן השלמות...';

  @override
  String get bulkMarkDone => 'סיום!';

  @override
  String get bulkMarkSkip => 'דלג';

  @override
  String get bulkMarkPriorLearning => 'סמן לימוד קודם';

  @override
  String get completionButtonCompleted => 'הושלם';

  @override
  String get completionButtonMarkComplete => 'סמן כהושלם';

  @override
  String get upgradeToCloudTitle => 'שדרג לענן';

  @override
  String get upgradeToCloudButton => 'שדרג לענן';

  @override
  String get upgradeToCloudCancelKeepOffline => 'ביטול — שמור חשבון לא מקוון';

  @override
  String get scopeSelectionSave => 'שמור';

  @override
  String get scopeSelectionTrackEntireCurriculum => 'עקוב אחר כל קורס הלימוד';

  @override
  String get scopeSelectionChooseHierarchyLevel =>
      'בחרו לפי איזה רמת היררכיה לסנן';

  @override
  String get scopeSelectionChangeLevel => 'שנה רמה';

  @override
  String get curriculumSettingsLoadingProgram => 'טוען תוכנית...';

  @override
  String get curriculumSettingsProgramTitle => 'תוכנית';

  @override
  String curriculumSettingsProgramError(String error) {
    return 'שגיאה: $error';
  }

  @override
  String get curriculumSettingsChangeProgram => 'שנה תוכנית';

  @override
  String get curriculumSettingsChangeProgramSubtitle =>
      'עברו לתוכנית לימוד אחרת';

  @override
  String get curriculumSettingsDontSeeProgram => 'לא רואים את התוכנית שלכם?';

  @override
  String get curriculumSettingsRequestProgram => 'בקשו תוכנית חדשה';

  @override
  String get deleteAccountDialogTitle => 'מחיקת חשבון';

  @override
  String get deleteAccountTypeConfirm => 'הקלידו DELETE לאישור:';

  @override
  String get deleteAccountHint => 'DELETE';

  @override
  String get deleteAccountWarningBody =>
      'פעולה זו היא לצמיתות ולא ניתן לבטלה. כל הנתונים שלך יימחקו.';

  @override
  String get deleteAccountReauthPassword =>
      'תתבקשו להזין מחדש את הסיסמה כדי לאמת את זהותכם.';

  @override
  String deleteAccountReauthProvider(String provider) {
    return 'תתבקשו להיכנס עם $provider כדי לאמת את זהותכם.';
  }

  @override
  String backupLastSynced(String timeAgo) {
    return 'סונכרן לאחרונה $timeAgo';
  }

  @override
  String get backupSyncing => 'מסנכרן...';

  @override
  String backupPendingChanges(int count) {
    return '$count שינויים ממתינים';
  }

  @override
  String backupSyncError(String message) {
    return 'שגיאת סנכרון: $message';
  }

  @override
  String get backupSyncTapToRetry => 'הקש לניסיון חוזר';

  @override
  String get backupSyncCloudUnavailable => 'הגיבוי בענן אינו זמין כרגע.';

  @override
  String get backupSyncOutboxStuck =>
      'חלק מהשינויים ממתינים לסנכרון. ננסה שוב באופן אוטומטי.';

  @override
  String get backupConnecting => 'מתחבר…';

  @override
  String get backupOffline => 'לא מקוון';

  @override
  String backupSyncPaused(int count, String reason) {
    return 'סנכרון מושהה — $count ממתינים. $reason';
  }

  @override
  String backupSyncPausedNoCount(String reason) {
    return 'סנכרון מושהה. $reason';
  }

  @override
  String get backupUpgradeToCloud => 'שדרג לענן';

  @override
  String get reauthDialogTitle => 'אמתו את זהותכם';

  @override
  String get reauthDialogBody => 'הזינו את הסיסמה הנוכחית כדי להמשיך.';

  @override
  String get reauthVerify => 'אמת';

  @override
  String get linkAccountTitle => 'קשר חשבון';

  @override
  String get linkAccountSubtitle => 'הוסיפו שיטת כניסה נוספת לחשבונכם.';

  @override
  String get linkAccountGoogleLabel => 'גוגל';

  @override
  String get linkAccountEmailPasswordLabel => 'דוא\"ל וסיסמה';

  @override
  String get linkAccountLinkEmail => 'קשר דוא\"ל';

  @override
  String get linkAccountAllLinked => 'כל שיטות הכניסה כבר מקושרות.';

  @override
  String get linkAccountGoogleSuccess => 'חשבון גוגל קושר בהצלחה.';

  @override
  String get linkAccountEmailSuccess => 'חשבון דוא\"ל וסיסמה קושר בהצלחה.';

  @override
  String get changePasswordDialogTitle => 'שנה סיסמה';

  @override
  String get changePasswordButton => 'שנה סיסמה';

  @override
  String get accountDeletedTitle => 'החשבון נמחק';

  @override
  String get signOutLabel => 'התנתק';

  @override
  String get signOutConfirmTitle => 'התנתקות';

  @override
  String get signOutConfirmBody =>
      'האם אתם בטוחים שברצונכם להתנתק? הנתונים שלכם יישמרו לכשתחזרו.';

  @override
  String get connectionLostTitle => 'החיבור אבד';

  @override
  String get tryAgainButton => 'נסה שוב';

  @override
  String get createOfflineAccount => 'צור חשבון לא מקוון';

  @override
  String get onboardingConfirm => 'אישור';

  @override
  String get onboardingStartLearning => 'התחל ללמוד';

  @override
  String get onboardingAddAnotherTrack => 'הוסף מסלול נוסף';

  @override
  String get onboardingAddAnotherLearner => 'הוסף לומד נוסף';

  @override
  String get onboardingSkipNoReview => 'דלג (ללא חזרה)';

  @override
  String get onboardingMarkCompleted => 'סמן כהושלם';

  @override
  String get onboardingStartingPosition => 'נקודת התחלה';

  @override
  String get onboardingStudyDays => 'ימי לימוד';

  @override
  String get stageNameLimud => 'לימוד';

  @override
  String get stageNameChazaraAleph => 'חזרה א׳';

  @override
  String get stageNameChazaraBet => 'חזרה ב׳';

  @override
  String get actionMarkCompleted => 'סמן כהושלם';

  @override
  String get actionSkipNoReview => 'דלג (ללא חזרה)';

  @override
  String get studyDaysTitle => 'ימי לימוד';

  @override
  String get studyDaysSubtitle => 'באילו ימים אתה לומד?';

  @override
  String studyDaysSetByProgram(String programName) {
    return 'ימי הלימוד נקבעו על ידי $programName';
  }

  @override
  String get startingPositionTitle => 'מיקום התחלתי';

  @override
  String get startingPositionHint => 'ניתן להתחיל עד 30 ימים אחורה מהיום';

  @override
  String startingPositionWhereAreYou(String programName) {
    return 'איפה אתה ב$programName?';
  }

  @override
  String get priorLearningTitle => 'סימון לימוד קודם';

  @override
  String get priorLearningSubtitle =>
      'האם ברצונך לסמן חלקים שכבר למדת כהושלמו?';

  @override
  String get goalPickDeadlineFirst => 'בחר תאריך יעד תחילה.';

  @override
  String get trackSaveError => 'שגיאה בשמירת המסלול. נסה שוב.';

  @override
  String get pacePerDay => 'ליום';

  @override
  String get pacePerWeek => 'לשבוע';

  @override
  String get goalTypeDeadline => 'תאריך יעד';

  @override
  String get goalTypePace => 'קצב';

  @override
  String get goalTypeNoDeadline => 'ללא יעד';

  @override
  String get goalEditTitle => 'עריכת יעד';

  @override
  String get goalNewTitle => 'יעד חדש';

  @override
  String get goalUpdateButton => 'עדכן יעד';

  @override
  String get goalCreateButton => 'צור יעד';

  @override
  String get trackSetGoalLabel => 'הגדרת יעד';

  @override
  String get trackEditGoalLabel => 'עריכת יעד';

  @override
  String get goalSavedSnack => 'היעד נשמר';

  @override
  String get goalRemovedSnack => 'היעד הוסר';

  @override
  String get goalRemoveButton => 'הסרת יעד';

  @override
  String get unitPerakim => 'פרקים';

  @override
  String get unitPesukim => 'פסוקים';

  @override
  String get unitAmudim => 'עמודים';

  @override
  String get unitDafim => 'דפים';

  @override
  String get tasksUnableToLoad => 'לא ניתן לטעון משימות';

  @override
  String get tasksAllCaughtUp => 'עדכני לחלוטין';

  @override
  String get tasksNoTasksRemainingToday => 'אין משימות נותרות להיום.';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String scopeSelectionCountSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נבחרו $count',
      one: 'נבחר 1',
    );
    return '$_temp0';
  }

  @override
  String scopeSelectionItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים',
      one: 'פריט אחד',
    );
    return '$_temp0';
  }

  @override
  String reviewStageDayDelay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עיכוב של $count ימים',
      one: 'עיכוב של יום אחד',
    );
    return '$_temp0';
  }

  @override
  String get applyToAll => 'החל על הכל';

  @override
  String get trackNameSubtitle => 'תן למסלול שלך שם לזיהוי.';

  @override
  String priorLearningChooseSections(String curriculumName) {
    return 'בחר אילו סעיפים לסמן ב$curriculumName.';
  }

  @override
  String get priorLearningAlreadyCompleted =>
      'האם כבר השלמת חלק מהסעיפים האלה?';

  @override
  String get priorLearningMarkEverything => 'סמן הכל כהושלם';

  @override
  String get priorLearningMarkEverythingSubtitle =>
      'מומלץ אם אתה מתחיל מחזור חזרה חדש';

  @override
  String get priorLearningNoFolders =>
      'לא נבחרו תיקיות ספציפיות, אך עדיין ניתן לסמן הכל כהושלם.';

  @override
  String get priorLearningSelectedFolder => 'תיקייה שנבחרה';

  @override
  String scopeSelectionSelectLevel(String levelName) {
    return 'בחר $levelName';
  }

  @override
  String get activeTracksLabel => 'מסלולים פעילים';

  @override
  String activeTracksRunning(int count) {
    return '$count פעיל';
  }

  @override
  String get trackDetailConfigGoal => 'יעד';

  @override
  String get trackDetailConfigItemsRemaining => 'פריטים שנותרו';

  @override
  String get trackDetailConfigEstFinish => 'סיום משוער';

  @override
  String trackSince(String date) {
    return 'מאז $date';
  }

  @override
  String get trackEditLabel => 'ערוך מסלול';

  @override
  String get trackEditTitle => 'ערוך מסלול';

  @override
  String get trackEditSectionName => 'שם מסלול';

  @override
  String get trackEditSectionGoal => 'יעד';

  @override
  String get trackEditSectionStudyDays => 'ימי לימוד';

  @override
  String get trackEditSectionReview => 'חזרה';

  @override
  String get trackEditGoalTypeLocked => 'לא ניתן לשנות את סוג היעד לאחר ההגדרה';

  @override
  String get trackEditProgramLocked =>
      'חזרה, היקף ויימי לימוד מנוהלים על ידי התוכנית.';

  @override
  String get trackEditReviewSummaryNone => 'ללא חזרה';

  @override
  String trackEditReviewSummaryDays(String delays) {
    return 'אחרי $delays';
  }

  @override
  String get trackEditChangeReview => 'שנה';

  @override
  String get trackEditSaveButton => 'שמור שינויים';

  @override
  String get trackEditConfirmTitle => 'להחיל שינויים?';

  @override
  String get trackEditConfirmBody =>
      'השינויים חלים על לימוד עתידי בלבד. השלמות קיימות אינן מושפעות.';

  @override
  String get trackEditClearOverdueButton => 'נקה פיגורים';

  @override
  String get trackEditClearOverdueConfirmTitle => 'לנקות פיגורים?';

  @override
  String get trackEditClearOverdueConfirmBody =>
      'הפיגורים יוסרו מהדשבורד. הם לא יסומנו כנעשה.';

  @override
  String get trackDeleteLabel => 'מחק מסלול';

  @override
  String trackDeleteContent(String name) {
    return 'למחוק לצמיתות את \"$name\"? כל ההתקדמות והנתונים של מסלול זה יוסרו. לא ניתן לבטל פעולה זו.';
  }

  @override
  String get deleteTrackArchiveTitle => 'מחיקת מסלול';

  @override
  String get deleteTrackArchiveBody => 'מה לעשות עם היסטוריית ההשלמות שלך?';

  @override
  String get parentDeleteTrackArchiveBody =>
      'מה לעשות עם היסטוריית ההשלמות של ילדך?';

  @override
  String get deleteTrackArchive => 'ארכיון (שמור היסטוריה)';

  @override
  String get deleteTrackWipe => 'מחק ומחה היסטוריה';

  @override
  String get notificationReminderTitle => 'תזכורת לימוד';

  @override
  String notificationReminderBody(int taskCount, int curriculumCount) {
    String _temp0 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount משימות',
      one: 'משימה אחת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      curriculumCount,
      locale: localeName,
      other: '$curriculumCount תוכניות לימוד',
      one: 'תוכנית לימוד אחת',
    );
    return 'יש לכם $_temp0 ב$_temp1 היום';
  }

  @override
  String get startingPositionTargetDate => 'תאריך יעד';

  @override
  String get goalPaceOrDeadlineTitle => 'מה הקצב או המועד שלך?';

  @override
  String get goalPaceOrDeadlineSubtitle => 'הגדר יעד.';

  @override
  String get goalTargetPace => 'קצב יעד';

  @override
  String goalPaceDescriptionLine(String unit, String period) {
    return '$unit $period';
  }

  @override
  String goalEstimatedFinish(String date) {
    return 'סיום משוער: $date';
  }

  @override
  String get goalSetDeadline => 'קבע מועד יעד';

  @override
  String get reviewScheduleTitle => 'לוח חזרות';

  @override
  String reviewScheduleSetByProgram(String programName) {
    return 'שלבי החזרה נקבעו על ידי $programName';
  }

  @override
  String get reviewScheduleFixedHint =>
      'לוח זה קבוע על ידי התוכנית ולא ניתן לעריכה.';

  @override
  String get reviewScheduleNoStages => 'לא מוגדרים שלבי חזרה לתוכנית זו.';

  @override
  String get reviewScheduleAfterOneDay => 'אחרי יום אחד';

  @override
  String reviewScheduleAfterNDays(String count) {
    return 'אחרי $count ימים';
  }

  @override
  String get reviewScheduleScheduledByProgram => 'מתוזמן על ידי התוכנית';

  @override
  String get chazaraCustomCycle => 'מחזור מותאם אישית';

  @override
  String chazaraSessionsCount(int count) {
    return '$count סבבים';
  }

  @override
  String get chazaraAddNew => 'הוסף';

  @override
  String get termChazara => 'חזרה';

  @override
  String get termBubbleChazara => 'חזרה';

  @override
  String get termReviewSection => 'חזרה';

  @override
  String get termDaf => 'דף';

  @override
  String get termAmud => 'עמוד';

  @override
  String get termPerek => 'פרק';

  @override
  String get termMishnah => 'משנה';

  @override
  String get termSeder => 'סדר';

  @override
  String get termMasechta => 'מסכת';

  @override
  String get termChumash => 'חומש';

  @override
  String get termTalmidChochom => 'תלמיד חכם';

  @override
  String get termTalmidChochomCaps => 'תלמיד חכם';

  @override
  String get termStageLearn => 'לימוד';

  @override
  String get termStageChazaraPrefix => 'חזרה';

  @override
  String get authSignInTimeout =>
      'הכניסה לוקחת יותר מדי זמן. בדוק את החיבור ונסה שוב.';

  @override
  String get reauthGoogleTitle => 'אמת עם גוגל כדי למחוק את חשבונך';

  @override
  String get reauthGoogleBody =>
      'אנו צריכים שתיכנס עם גוגל עוד פעם אחת כדי לאמת שזה באמת אתה. לאחר הכניסה, חשבונך וכל הנתונים יימחקו לצמיתות.';

  @override
  String get reauthGoogleContinue => 'המשך לגוגל';

  @override
  String get deletingAccountTitle => 'מוחק את חשבונך…';

  @override
  String get deletingAccountBody =>
      'זה עשוי לקחת מספר שניות. אנא אל תסגור את האפליקציה.';

  @override
  String get deletingAccountError => 'המחיקה נתקלה בבעיה. התנתקת מהחשבון.';

  @override
  String get itemsLearnedTitle => 'פריטים שנלמדו';

  @override
  String get itemsLearnedSubtitle => 'השלמות מסלול לפי תוכנית';

  @override
  String get itemsLearnedNoCurricula => 'עדיין אין השלמות מסלול';

  @override
  String get itemsLearnedNoCurriculaSubtitle =>
      'השלם משימות יומיות כדי לראות את ההתקדמות כאן';

  @override
  String itemsLearnedOf(int completed, int total) {
    return '$completed מתוך $total';
  }

  @override
  String get overallProgressCardTitle => 'התקדמות כוללת';

  @override
  String get overallProgressStatTotalItems => 'סה\"כ פריטים';

  @override
  String get overallProgressStatCompletedAllStages => 'הושלמו כל השלבים';

  @override
  String get overallProgressStatInProgress => 'בתהליך';

  @override
  String get overallProgressStatNotStarted => 'טרם הוחל';

  @override
  String get curriculumProgressBreakdownByLevel => 'פירוט לפי רמה';

  @override
  String get curriculumProgressLoading => 'טוענים נתוני התקדמות...';

  @override
  String curriculumProgressLoadFailed(String error) {
    return 'שגיאה בטעינת ההתקדמות: $error';
  }

  @override
  String get tierLensRecentActivity => 'פעילות אחרונה';

  @override
  String get tierLensSiyumimMilestones => 'סיומים והישגים';

  @override
  String get tierLensLifetimeKnowledge => 'ידע כולל';

  @override
  String streakWidgetDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'רצף של $count ימים!',
      one: 'רצף של יום אחד!',
    );
    return '$_temp0';
  }

  @override
  String streakWidgetBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'שיא: $count ימים',
      one: 'שיא: יום אחד',
    );
    return '$_temp0';
  }

  @override
  String tierCounterStreakDays(int count) {
    return 'רצף של $count ימים';
  }

  @override
  String tierCounterSiyumimEarned(int count, String siyumimTerm) {
    return '$count $siyumimTerm';
  }

  @override
  String tierCounterLifetimeItems(int count) {
    return '$count פריטים';
  }

  @override
  String tierCounterPoints(int count) {
    return '$count נקודות';
  }

  @override
  String get tierTileLabelStreak => 'רצף';

  @override
  String tierTileLabelSiyumim(String siyumimTerm) {
    return '$siyumimTerm';
  }

  @override
  String get tierTileLabelLifetime => 'ידע כולל';

  @override
  String get tierTileLabelPoints => 'נקודות';

  @override
  String get limud => 'לימוד';

  @override
  String get chazara => 'חזרה';

  @override
  String get chazaros => 'חזרות';

  @override
  String get siyum => 'סיום';

  @override
  String get siyumim => 'סיומים';

  @override
  String get milestone => 'הישג';

  @override
  String get milestoneAggregate => 'הישגים';

  @override
  String get trackProgress => 'התקדמות מסלול';

  @override
  String get trackMarkPreviouslyLearned => 'סמן כנלמד בעבר';

  @override
  String get lifetimeLabel => 'ידע כולל';

  @override
  String get recentActivityShort => 'פעילות אחרונה';

  @override
  String get streakLabel => 'רצף';

  @override
  String get labelStreakAcrossAllCurricula => 'רצף בכל המסלולים';

  @override
  String paceAheadByDays(int count) {
    return 'לפני ב-$count ימים';
  }

  @override
  String get paceOnTrack => 'בקצב הנכון';

  @override
  String paceBehindByDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'מאחור ב-$count ימים',
      one: 'מאחור ביום אחד',
    );
    return '$_temp0';
  }

  @override
  String itemsLearnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פריטים נלמדו',
      one: 'פריט אחד נלמד',
    );
    return '$_temp0';
  }

  @override
  String totalChazaros(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count חזרות סה״כ',
      one: 'חזרה אחת סה״כ',
    );
    return '$_temp0';
  }

  @override
  String get siyumHaShas => 'סיום הש״ס';

  @override
  String get siyumHaTorah => 'סיום התורה';

  @override
  String get siyumHaMishnayos => 'סיום המשניות';

  @override
  String get siyumHaYerushalmi => 'סיום הירושלמי';

  @override
  String get siyumMishnaBerurah => 'סיום משנה ברורה';

  @override
  String get siyumMishnehTorah => 'סיום משנה תורה';

  @override
  String get siyumNach => 'סיום נ״ך';

  @override
  String get siyumTanach => 'סיום תנ״ך';

  @override
  String get siyumMussar => 'סיום מוסר';

  @override
  String get siyumSeder => 'סיום סדר';

  @override
  String get siyumChelek => 'סיום חלק';

  @override
  String siyumMasechta(String name) {
    return 'סיום מסכת $name';
  }

  @override
  String siyumSefer(String name) {
    return 'סיום ספר $name';
  }

  @override
  String siyumSiman(String name) {
    return 'סיום סימן $name';
  }

  @override
  String siyumHilchos(String name) {
    return 'סיום הלכות $name';
  }

  @override
  String siyumimLevelCurriculum(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count סיומים ברמת מסלול',
      one: 'סיום אחד ברמת מסלול',
    );
    return '$_temp0';
  }

  @override
  String siyumimLevelAggregate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count סיומים ברמת אגד',
      one: 'סיום אחד ברמת אגד',
    );
    return '$_temp0';
  }

  @override
  String siyumimLevelUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count סיומים ברמת יחידה',
      one: 'סיום אחד ברמת יחידה',
    );
    return '$_temp0';
  }

  @override
  String get siyumimEmptyState => 'אין סיומים עדיין — המשיכו ללמוד!';

  @override
  String siyumimAggregateSubtitle(int count, String date) {
    return 'כל $count הושלמו · $date';
  }

  @override
  String get paceLiveLearningOnlyCaption =>
      'הקצב עוקב אחר לימוד במסלולים בלבד.';

  @override
  String get bulkMarkWizardSubtitle =>
      'פריטים אלו נספרים לסיומים ולידע הכולל — אך לא לרצף או לנקודות שלך.';

  @override
  String bulkMarkConfirmationToast(int count) {
    return '$count פריטים סומנו כנלמדו בעבר. הם יופיעו בידע הכולל ועשויים לפתוח סיומים.';
  }

  @override
  String get lifetimeMarkingSubtitle =>
      'פריטים שלמדת בחייך, מחוץ למסלולי האפליקציה. נספרים לידע הכולל — אך לא לסיומים, לרצף, או לנקודות.';

  @override
  String get recentActivityLiveOnlyDisclaimer =>
      'כולל לימוד במסלולים (חי + סימון בקבוצה). ייבוא לכל החיים מופיע תחת הידע הכולל.';

  @override
  String get lifetimeKnowledgeLoading => 'טוען ידע כולל…';

  @override
  String lifetimeKnowledgeLoadError(String error) {
    return 'נכשל בטעינה: $error';
  }

  @override
  String lifetimeKnowledgeCounterError(String error) {
    return 'נכשל בטעינת מונים: $error';
  }

  @override
  String get lifetimeKnowledgeRetry => 'נסה שוב';

  @override
  String get lifetimeKnowledgeToggleAllSources => 'כל המקורות';

  @override
  String get lifetimeKnowledgeToggleTrackOnly => 'למידה במסלולים בלבד';

  @override
  String get lifetimeKnowledgeAddCta => 'הוסף פריטים שלמדתי בעבר';

  @override
  String get lifetimeKnowledgeAddCtaSubtitle =>
      'סימון לידע כולל — נספר לידע הכולל.';

  @override
  String get provenanceLive => 'בלמידה';

  @override
  String provenanceLiveChazaros(int count) {
    return 'בלמידה · $count חזרות';
  }

  @override
  String get provenanceBulkMarked => 'מסומן בקבוצה';

  @override
  String get provenanceLifetimeImported => 'ייבוא לכל החיים';

  @override
  String get trackInfoStarted => 'התחיל';

  @override
  String get trackInfoGoal => 'יעד';

  @override
  String get trackInfoRequiredPace => 'קצב נדרש';

  @override
  String get trackInfoActualPace => 'קצב בפועל';

  @override
  String get trackInfoActualPaceCaption =>
      '7 ימים אחרונים · לימוד במסלולים בלבד';

  @override
  String get trackInfoItemsPerDay => 'פריטים ליום';

  @override
  String get trackInfoElapsed => 'חלף';

  @override
  String get trackInfoRemaining => 'נותר';

  @override
  String get trackInfoDays => 'ימים';

  @override
  String get allTimeActivityTitle => 'פעילות כל הזמנים';

  @override
  String get allTimeActiveDays => 'ימים פעילים';

  @override
  String allTimeTermDone(String term) {
    return '$term שנלמד';
  }

  @override
  String get redeemScreenTitle => 'פרס הפרסים';

  @override
  String get redeemScreenBalance => 'היתרה שלך';

  @override
  String get redeemScreenNoRewards =>
      'עדיין לא הוגדרו פרסים.\nבקש מהורה להגדיר!';

  @override
  String redeemScreenCostLabel(int points) {
    return '$points נקודות';
  }

  @override
  String get redeemScreenAffordableLabel => 'פדה';

  @override
  String get redeemScreenCannotAfford => 'אין מספיק נקודות';

  @override
  String redeemScreenConfirmTitle(String title) {
    return 'לפדות \"$title\"?';
  }

  @override
  String redeemScreenConfirmBody(int points) {
    return 'פעולה זו תנצל $points נקודות מהיתרה שלך.';
  }

  @override
  String get redeemScreenConfirmButton => 'בזבז ופדה';

  @override
  String redeemScreenRequestedSnackbar(String title) {
    return '\"$title\" הוזמן! בקש מהורה לאשר.';
  }

  @override
  String get redeemScreenInsufficientSnackbar =>
      'אין מספיק נקודות לפדות פרס זה.';

  @override
  String get redeemScreenTutorUnavailable => 'לא זמין (מצב מדריך)';

  @override
  String get pendingRedemptionsTitle => 'פרסים ממתינים';

  @override
  String get pendingRedemptionsEmpty => 'אין בקשות פרס ממתינות.';

  @override
  String pendingRedemptionsCountSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בקשות פרס ממתינות',
      one: 'בקשת פרס אחת ממתינה',
    );
    return '$_temp0';
  }

  @override
  String pendingRedemptionsCost(int points) {
    return '$points נקודות';
  }

  @override
  String get pendingRedemptionsApprove => 'מלא';

  @override
  String get pendingRedemptionsDecline => 'דחה';

  @override
  String get pendingRedemptionsFulfilledSnackbar => 'הפרס סומן כמומש!';

  @override
  String get pendingRedemptionsDeclinedSnackbar =>
      'בקשת הפרס נדחתה. הנקודות הוחזרו.';

  @override
  String get parentPointsAdjustTitle => 'התאם נקודות';

  @override
  String get parentPointsAdjustSubtitle => 'הוסף או הפחת נקודות מיתרת הילד.';

  @override
  String get parentPointsAdjustAddLabel => 'הוסף נקודות';

  @override
  String get parentPointsAdjustDeductLabel => 'הפחת נקודות';

  @override
  String get parentPointsAdjustAmountHint => 'כמות';

  @override
  String get parentPointsAdjustNoteHint => 'סיבה (אופציונלי)';

  @override
  String get parentPointsAdjustConfirm => 'החל';

  @override
  String get parentPointsAdjustAppliedSnackbar => 'היתרה עודכנה.';

  @override
  String parentPointsAdjustCurrentBalance(int count) {
    return 'יתרה נוכחית: $count נק׳';
  }

  @override
  String get profileTypeChild => 'ילד';

  @override
  String get profileTypeAdult => 'מבוגר';

  @override
  String get childMode => 'מצב ילדים';

  @override
  String get adultMode => 'מצב מבוגרים';

  @override
  String get statusActive => 'פעיל';

  @override
  String get statusPending => 'ממתין';

  @override
  String get actionTryAgain => 'נסו שוב';

  @override
  String get actionGoToDashboard => 'מעבר ללוח';

  @override
  String get emptyLoginTutorEntry => 'אני מדריך';

  @override
  String get switchAccount => 'החלפת חשבון';

  @override
  String get emptyLoginTutorComingSoon =>
      'גישת מדריך תהיה זמינה בקרוב. בקשו מההורה לשתף אתכם בקישור הזמנה.';

  @override
  String get tutorWelcomeBannerTitle => 'ברוכים הבאים, מדריך!';

  @override
  String get tutorWelcomeBannerBody =>
      'בקשו מההורה לשתף אתכם בקישור הזמנה, ואז הקישו למטה כדי לאשר אותה.';

  @override
  String get switcherSheetProfiles => 'פרופילים';

  @override
  String get switcherSheetAccounts => 'חשבונות';

  @override
  String get switcherSheetAddAccount => 'הוספת חשבון';

  @override
  String get addAnotherAccountSubtitle => 'התחבר או צור חשבון נוסף במכשיר זה';

  @override
  String get acceptInviteAppBarTitle => 'אישור הזמנת מדריך';

  @override
  String get acceptInviteAccepting => 'מאשר הזמנה…';

  @override
  String get acceptInviteHeading => 'אישור הזמנת מדריך';

  @override
  String get acceptInviteBody =>
      'הוזמנתם להדריך ילד. באישור ההזמנה תקבלו גישה לצפייה ולניהול של פרופיל הלמידה שלו.';

  @override
  String get acceptInvitePermissionViewData =>
      'צפייה בכל נתוני הלמידה וההתקדמות';

  @override
  String get acceptInvitePermissionConfigure =>
      'הגדרת מסלולים, נקודות ופרסים (אם הותר)';

  @override
  String get acceptInvitePermissionBulkMark => 'ביצוע תיקוני סימון מרוכזים';

  @override
  String get acceptInvitePermissionNoLive =>
      'לא ניתן לסמן השלמות חיות (רצף / פרסים)';

  @override
  String get acceptInviteAccept => 'אישור הזמנה';

  @override
  String get acceptInviteDecline => 'דחייה';

  @override
  String get acceptInviteSuccessHeading => 'ההזמנה אושרה!';

  @override
  String get acceptInviteSuccessBody =>
      'כעת יש לכם גישת מדריך לפרופיל הלמידה של הילד. פתחו את בורר הפרופילים כדי לעבור לפרופיל המודרך.';

  @override
  String get acceptInviteErrorHeading => 'לא ניתן לאשר את ההזמנה';

  @override
  String get acceptInviteGenericError => 'לא ניתן לאשר את ההזמנה. נסו שוב.';

  @override
  String get unexpectedError => 'אירעה שגיאה בלתי צפויה.';

  @override
  String get declineInviteAppBarTitle => 'דחיית הזמנה';

  @override
  String get declineInviteConfirmHeading => 'לדחות את הזמנת המדריך?';

  @override
  String get declineInviteConfirmBody =>
      'אתם עומדים לדחות את הזמנת המדריך. ההורה יקבל הודעה שדחיתם. לא תהיה לכם גישה לפרופיל הלמידה של הילד.';

  @override
  String get declineInviteConfirm => 'דחיית הזמנה';

  @override
  String get declineInviteInProgress => 'דוחה הזמנה…';

  @override
  String get declineInviteSuccessHeading => 'ההזמנה נדחתה';

  @override
  String get declineInviteSuccessBody =>
      'דחיתם את הזמנת המדריך. ההורה קיבל הודעה.';

  @override
  String get declineInviteErrorHeading => 'לא ניתן לדחות את ההזמנה';

  @override
  String get declineInviteGenericError => 'לא ניתן לדחות את ההזמנה. נסו שוב.';

  @override
  String get inviteTutorAppBarTitle => 'הזמנת מדריך';

  @override
  String get inviteTutorHeading => 'הזמנת מדריך';

  @override
  String get inviteTutorBody =>
      'הזינו את כתובת האימייל של המדריך. הוא יקבל קישור הזמנה לאישור גישה לפרופיל הלמידה של הילד.';

  @override
  String get inviteTutorEmailLabel => 'כתובת האימייל של המדריך';

  @override
  String get inviteTutorEmailHint => 'tutor@example.com';

  @override
  String get inviteTutorInvalidEmail => 'הזינו כתובת אימייל תקינה.';

  @override
  String get inviteTutorSending => 'שולח…';

  @override
  String get inviteTutorSend => 'שליחת הזמנה';

  @override
  String inviteTutorSentSnackbar(String email) {
    return 'ההזמנה נשלחה אל $email!';
  }

  @override
  String get manageGrantsAppBarTitle => 'ההדרכות שלי';

  @override
  String manageGrantsActiveSection(int count) {
    return 'פעילות ($count)';
  }

  @override
  String manageGrantsPendingSection(int count) {
    return 'הזמנות ממתינות ($count)';
  }

  @override
  String get manageGrantsEmptyHeading => 'אין קשרי הדרכה';

  @override
  String get manageGrantsEmptyBody =>
      'כשהורה יזמין אתכם להדריך את ילדו, ההרשאה תופיע כאן.';

  @override
  String get manageGrantsResignTitle => 'להתפטר מההדרכה?';

  @override
  String manageGrantsResignBody(String child, String parent) {
    return 'תאבדו מיד את הגישה לפרופיל של הילד. ההורה יקבל הודעה.\n\nילד: $child\nהורה: $parent';
  }

  @override
  String get manageGrantsResign => 'התפטרות';

  @override
  String manageGrantsResignError(String error) {
    return 'לא ניתן להתפטר: $error';
  }

  @override
  String get tutorFallbackName => 'המדריך שלכם';

  @override
  String get manageTutorsEmptyHeading => 'אין עדיין פרופילי ילדים';

  @override
  String get manageTutorsEmptyBody =>
      'הוסיפו פרופיל ילד כדי להתחיל להזמין מדריכים.';

  @override
  String manageTutorsLoadError(String error) {
    return 'לא ניתן לטעון מדריכים: $error';
  }

  @override
  String get manageTutorsNoTutors => 'לא הוזמנו מדריכים.';

  @override
  String manageTutorsActiveSection(int count) {
    return 'פעילים ($count)';
  }

  @override
  String manageTutorsPendingSection(int count) {
    return 'ממתינים ($count)';
  }

  @override
  String get manageTutorsInviteButton => 'הזמנת מדריך';

  @override
  String get manageTutorsRevokeTitle => 'לבטל גישת מדריך?';

  @override
  String manageTutorsRevokeBody(String email) {
    return '$email יאבד מיד את הגישה לפרופיל של הילד.';
  }

  @override
  String get manageTutorsRevoke => 'ביטול גישה';

  @override
  String manageTutorsRevokeError(String error) {
    return 'לא ניתן לבטל את הגישה: $error';
  }

  @override
  String get manageTutorsRescindTitle => 'לבטל את ההזמנה?';

  @override
  String manageTutorsRescindBody(String email) {
    return 'ההזמנה הממתינה אל $email תבוטל.';
  }

  @override
  String get manageTutorsRescind => 'ביטול הזמנה';

  @override
  String manageTutorsRescindError(String error) {
    return 'לא ניתן לבטל את ההזמנה: $error';
  }

  @override
  String get manageTutorsViewAuditLog => 'צפייה ביומן הפעולות';

  @override
  String get tutorFallbackParent => 'הורה';

  @override
  String get auditLogTitle => 'יומן פעולות';

  @override
  String get auditLogClearFilters => 'ניקוי סינונים';

  @override
  String get auditLogFilterFromDate => 'סינון מתאריך';

  @override
  String get auditLogFilterToDate => 'סינון עד תאריך';

  @override
  String get auditLogFilterFrom => 'מתאריך';

  @override
  String get auditLogFilterTo => 'עד תאריך';

  @override
  String get auditLogEmptyFiltered => 'אין רשומות התואמות לסינון';

  @override
  String get auditLogEmpty => 'אין רשומות ביומן';

  @override
  String get auditLogEmptyFilteredBody =>
      'נקו את הסינונים כדי לראות את כל הרשומות.';

  @override
  String get auditLogEmptyBody => 'פעולות המדריך יופיעו כאן ככל שיתבצעו.';

  @override
  String get auditLogChipConfig => 'הגדרות';

  @override
  String get auditLogChipBulkPrior => 'סימון מרוכז';

  @override
  String get auditLogChipReset => 'איפוס';

  @override
  String get auditLogChipBookmark => 'סימנייה';

  @override
  String get auditLogChipProfile => 'פרופיל';

  @override
  String get auditLogChipGoal => 'יעד';

  @override
  String get auditLogChipStage => 'שלב';

  @override
  String get auditLogChipReward => 'פרס';

  @override
  String get auditLogChipStudyDay => 'יום לימוד';

  @override
  String get auditLogActionConfigChanged => 'הגדרות שונו';

  @override
  String get auditLogActionBulkPrior => 'סימון מרוכז';

  @override
  String get auditLogActionReset => 'איפוס';

  @override
  String get auditLogActionBookmark => 'סימנייה';

  @override
  String get auditLogActionProfileEdited => 'פרופיל נערך';

  @override
  String get auditLogActionGoalChanged => 'יעד שונה';

  @override
  String get auditLogActionStageChanged => 'שלב שונה';

  @override
  String get auditLogActionRewardChanged => 'פרס שונה';

  @override
  String get auditLogActionStudyDay => 'יום לימוד';

  @override
  String get auditLogBefore => 'לפני: ';

  @override
  String get auditLogAfter => 'אחרי: ';

  @override
  String get tutorPinAppBarTitle => 'קוד מדריך';

  @override
  String get tutorPinEntryHeading => 'הזינו את קוד המדריך';

  @override
  String get tutorPinEntryBody =>
      'הזינו את קוד המדריך בן 4 הספרות כדי לגשת לפרופיל זה.';

  @override
  String get tutorPinForgot => 'שכחתם את קוד המדריך?';

  @override
  String get tutorPinIncorrect => 'קוד שגוי. נסו שוב.';

  @override
  String tutorPinLockedOut(int minutes) {
    return 'יותר מדי ניסיונות. ננעל למשך $minutes דקות.';
  }

  @override
  String get parentPinLockoutTitle => 'יותר מדי ניסיונות כושלים';

  @override
  String parentPinLockoutBody(int minutes) {
    return 'נסה שוב בעוד $minutes דקות';
  }

  @override
  String tutorPinErrorPrefix(String error) {
    return 'שגיאה: $error';
  }

  @override
  String get tutorPinSetupAppBarTitle => 'הגדרת קוד מדריך';

  @override
  String get tutorPinSetupConfirmHeading => 'אישור קוד המדריך';

  @override
  String get tutorPinSetupCreateHeading => 'יצירת קוד מדריך';

  @override
  String get tutorPinSetupConfirmBody =>
      'הזינו שוב את אותו קוד בן 4 ספרות לאישור.';

  @override
  String get tutorPinSetupCreateBody =>
      'קוד המדריך מגן על הגישה לכל פרופיל ילד שאתם מדריכים. הזינו קוד בן 4 ספרות.';

  @override
  String get tutorPinSetupConfirmLabel => 'אישור קוד';

  @override
  String get tutorPinSetupEnterNewLabel => 'הזנת קוד חדש';

  @override
  String get tutorPinSetupMismatch => 'הקודים אינם תואמים. נסו שוב.';

  @override
  String get tutorPinSetupSaveError => 'לא ניתן לשמור את הקוד. נסו שוב.';

  @override
  String get tutorPinSetupLater => 'הגדרה מאוחר יותר';

  @override
  String get tutorPinResetAppBarTitle => 'איפוס קוד מדריך';

  @override
  String get tutorPinResetHeading => 'איפוס קוד המדריך';

  @override
  String get tutorPinResetSendingTo => 'נשלח קישור לאיפוס אל:';

  @override
  String get tutorPinResetReturnHint =>
      'לאחר לחיצה על הקישור, חזרו לכאן כדי ליצור קוד חדש.';

  @override
  String get tutorPinResetNoEmail =>
      'לא נמצאה כתובת אימייל לחשבונכם. התחברו עם חשבון ענן כדי להשתמש באיפוס הקוד.';

  @override
  String get tutorPinResetSendFailed => 'שליחת אימייל האיפוס נכשלה. נסו שוב.';

  @override
  String get tutorPinResetFallbackEmail => 'כתובת האימייל של חשבונכם';

  @override
  String get tutorPinResetSendButton => 'שליחת אימייל איפוס';

  @override
  String get tutorPinResetCheckEmailHeading => 'בדקו את האימייל';

  @override
  String tutorPinResetCheckEmailBody(String email) {
    return 'שלחנו קישור לאיפוס אל $email. לחצו על הקישור וחזרו לכאן כדי להגדיר קוד חדש.';
  }

  @override
  String get tutorPinResetSetNew => 'הגדרת קוד חדש';

  @override
  String get settingsAppPermissions => 'הרשאות אפליקציה';

  @override
  String get settingsAppPermissionsSubtitle => 'התראות וגישה למיקום';

  @override
  String get settingsSendDiagnosticLogs => 'שליחת יומני אבחון';

  @override
  String get settingsSendDiagnosticLogsSubtitle =>
      'שדרו את 10 הדקות האחרונות של הפעילות אל Firebase';

  @override
  String get settingsPronunciation => 'הגייה';

  @override
  String get settingsPronunciationSubtitle =>
      'בראשית (אשכנזי) או בְּרֵשִית (ספרדי)';

  @override
  String get settingsPronunciationAshkenazi => 'אשכנזי';

  @override
  String get settingsPronunciationSephardi => 'ספרדי';

  @override
  String get settingsNikud => 'ניקוד';

  @override
  String get settingsNikudSubtitle => 'הצגה או הסתרה של ניקוד עברי בעת הלימוד.';

  @override
  String get settingsNikudWithout => 'ללא ניקוד';

  @override
  String get settingsNikudWith => 'עם ניקוד';

  @override
  String get deviceNotificationsTitle => 'התראות מכשיר';

  @override
  String get deviceNotificationsChecking => 'בודק הרשאה…';

  @override
  String get deviceNotificationsAllowed => 'התראות מאושרות במכשיר זה';

  @override
  String get deviceNotificationsBlocked =>
      'התראות חסומות — הקישו כדי לפתוח הגדרות';

  @override
  String get deviceNotificationsDisableHint =>
      'כדי להשבית התראות, עברו להגדרות > אפליקציות > Learning Tracker.';

  @override
  String get deviceNotificationsBlockedHint =>
      'התראות חסומות. הפעילו אותן בהגדרות > אפליקציות > Learning Tracker > התראות.';

  @override
  String get notificationReminderGenericBody =>
      'הגיע הזמן ללמוד! פתחו את האפליקציה כדי לראות את המשימות שלכם.';

  @override
  String get notificationStreakTitle => 'הרצף בסכנה!';

  @override
  String notificationStreakBody(int currentStreak) {
    return 'רצף $currentStreak הימים שלכם בסכנה!';
  }

  @override
  String get onboardingIntentHeading => 'מה הביא אותך לכאן?';

  @override
  String get onboardingIntentSubtitle => 'בחר איך תרצה להתחיל.';

  @override
  String get onboardingIntentTrackTitle => 'לעקוב אחרי הלמידה שלי';

  @override
  String get onboardingIntentTrackSubtitle =>
      'הגדר תכנית לימוד, מטרות ולוח זמנים יומי.';

  @override
  String get onboardingIntentSkipTitle => 'דלג בינתיים';

  @override
  String get onboardingIntentSkipSubtitle =>
      'כנס לאפליקציה והחלט מאוחר יותר. תוכל להגדיר מסלול או לקבל הזמנה בכל עת.';

  @override
  String get permissionPromptTitleOnboarding => 'כמעט סיימנו!';

  @override
  String permissionPromptBodyOnboarding(String shabbos) {
    return 'אפשרו הרשאות אלה כדי שהאפליקציה תוכל להזכיר לכם ללמוד ולחשב זמני $shabbos לפי מיקומכם.';
  }

  @override
  String permissionPromptBodySettings(String shabbos) {
    return 'נהלו הרשאות אופציונליות לתזכורות ולחישובי זמני $shabbos.';
  }

  @override
  String get permissionPromptNotifSubtitle =>
      'תזכורות לימוד יומיות והתראות להגנת הרצף.';

  @override
  String get permissionPromptLocationTitle => 'מיקום';

  @override
  String permissionPromptLocationSubtitle(String shabbos, String havdalah) {
    return 'זמני הדלקת נרות $shabbos ו$havdalah מדויקים לפי עירכם.';
  }

  @override
  String get permissionPromptCtaDone => 'סיום';

  @override
  String get permissionPromptAllowButton => 'אפשר';

  @override
  String selectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count בחירות',
      one: 'בחירה אחת',
    );
    return '$_temp0';
  }
}
