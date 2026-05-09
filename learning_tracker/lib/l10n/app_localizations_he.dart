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
  String get todaysLearning => 'הלימוד של היום';

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
  String get trackLifetimeLearning => 'לימוד לאורך חיים';

  @override
  String get continueLearning => 'המשך לימוד';

  @override
  String get recentActivity => 'פעילות אחרונה';

  @override
  String get myLearningJourney => 'מסע הלימוד שלי';

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
  String get customTrack => 'מסלול מותאם אישית';

  @override
  String get joinCalendarDesc => 'עקוב אחרי לוח לימוד יומי כמו דף יומי';

  @override
  String get customTrackDesc => 'צור תוכנית לימוד משלך בקצב שלך';

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
  String get startLearning => 'התחל ללמוד';

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
  String get manageTracksDetail => 'יצירה ועריכה של מסלולי הלמידה';

  @override
  String get addTrackGoalTapToUseDeadline =>
      'מצב קצב יעד פעיל — יש ללחוץ כאן ליעד לפי תאריך יעד';

  @override
  String get addTrackGoalTapToUsePace =>
      'מצב תאריך יעד פעיל — יש ללחוץ כאן לקצב יעד';

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
    return 'שגיאה בטעינת המשימות: $error';
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
  String get statCompletions => 'השלמות';

  @override
  String get statUnitsDone => 'יחידות';

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
  String get addWhatYouLearned => 'הוסיפו מה שלמדתם';

  @override
  String get addWhatYouLearnedSettingsSubtitle =>
      'רישום מצוות או לימוד תורה מותאם אישית';

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
  String get lifetimeBrowseFullLibrary => 'עיון בספרייה המלאה';

  @override
  String get lifetimeHowItWorksStep1 =>
      'בחרו קטגוריה מרשת הקטגוריות כדי לראות את כל המסלולים.';

  @override
  String get lifetimeHowItWorksStep2 =>
      'סמנו יחידות שסיימתם כדי לעדכן את מפת ההתקדמות לכל החיים.';

  @override
  String get lifetimeHowItWorksStep3 =>
      'קבלו תגי אבן דרך מיוחדים על השלמת ספרים או מסכתות שלמות.';

  @override
  String get lifetimeNotStarted => 'טרם התחיל';

  @override
  String get lifetimeAddHeaderTitle => 'הוסיפו מה שלמדתם';

  @override
  String get lifetimeAddHeaderSubtitle =>
      'סמנו מה שלמדתם כבר — מדפוס או מכל מקום — כלימוד לכל החיים.';

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
  String get noItemsAtThisLevel => 'אין פריטים ברמה זו';

  @override
  String get breadcrumbsRoot => 'שורש';

  @override
  String lifetimeMarkSavedCount(int count) {
    return 'סומנו $count בחירה(ות) לכל החיים.';
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
  String get mainFocus => 'מיקוד ראשי';

  @override
  String get carouselCompletion => 'השלמה';

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
  String get deleteProfileTitle => 'למחוק את הפרופיל?';

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
  String get manageTracksForChildSubtitle =>
      'הוספה, עריכה או ארכיון של מסלולי הילד';

  @override
  String get pointConfiguration => 'הגדרת נקודות';

  @override
  String get pointConfigurationSubtitle => 'כמה נקודות שווה כל פעילות';

  @override
  String get rewardConfigurationTitle => 'הגדרת פרסים';

  @override
  String get rewardConfigurationSubtitle =>
      'פרסים לפי מסלול או לפי סך נקודות מכל המסלולים.';

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
  String get skipAndContinue => 'דלגו והמשיכו';

  @override
  String get noActiveProfile => 'אין פרופיל פעיל';

  @override
  String get incorrectPin => 'קוד שגוי';

  @override
  String get enterCurrentPin => 'הזינו את הקוד הנוכחי';

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
  String get journeyEmptyTitle => 'מסע הלמידה שלכם מתחיל כאן!';

  @override
  String get journeyEmptyBody =>
      'השלימו את המסכתא הראשונה כדי לראות אותה נרשמת לנצח.';

  @override
  String get progressChartsTitle => 'תרשימי התקדמות';

  @override
  String get chartCompletionsOverTime => 'השלמות לאורך זמן';

  @override
  String get chartDailyActivity => 'פעילות יומית';

  @override
  String get chartCumulativeProgress => 'התקדמות מצטברת';

  @override
  String get chartCumulativeProgressSubtitle => '+12% לעומת השבוע שעבר';

  @override
  String get chartPointsEarned => 'נקודות שהורו';

  @override
  String get chartTotalTorahPoints => 'נק׳ תורה סה״כ';

  @override
  String get chartLearningJourney => 'מסע הלמידה';

  @override
  String get chartJourneyMotivation => 'שמרו על הלהבה בוערת מדי יום!';

  @override
  String get chartSevenDayStreak => 'רצף 7 ימים!';

  @override
  String get chartLast7Days => '7 ימים';

  @override
  String get chartLast30Days => '30\nימים';

  @override
  String get chartAllTime => 'הכול';

  @override
  String get chartFilterAll => 'הכול';

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
  String get notifRewardNotifications => 'התראות פרסים';

  @override
  String get notifRewardNotificationsSubtitle => 'כשאתם מרוויחים נק׳ למידה!';

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
  String get signInPasswordHint => '••••••••';

  @override
  String get signInKeepMeSignedIn => 'השאירו אותי מחוברים';

  @override
  String get signInCta => 'התחברות';

  @override
  String get signInWithGoogleCta => 'התחברות עם גוגל';

  @override
  String get signInNewToQuest => 'חדשים בקווסט? ';

  @override
  String get signInRegisterHere => 'הרשמה כאן';

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
}
