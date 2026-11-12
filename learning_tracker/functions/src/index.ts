// Cloud Functions entry point.
//
// AUD-firebase-15: this file used to hold five unrelated concerns (account
// deletion, the scheduled audit-log purge, the learning callables, the
// tutor invite/grant lifecycle, and the tutor CRUD write-paths) in one
// 2000+ line god-file. It is now a barrel that re-exports deployed Cloud
// Functions from focused modules. Phrase translation is an opt-in export,
// controlled by PHRASE_TRANSLATION_ENABLED.
//
// Line budget: stays under 300 lines — it should never again accumulate
// function bodies. Add new Cloud Functions to (or alongside) one of the
// modules below, then re-export it here.

export {
  onUserDeleted,
  deleteLearnerProfile,
  deleteCurriculumTrack,
  deleteAccountData,
} from "./deletes";

export { purgeExpiredAuditLogs } from "./audit_log_purge";

export { billingKillSwitch } from "./billing_kill_switch";

export { ownerOversizedGovernedWrite } from "./owner_oversized_governed_write";

export {
  tutorRecordLearning,
  tutorUnlearn,
  tutorUpsertSubTrack,
  tutorVoidLearning,
} from "./tutor_learning";

export {
  inviteTutor,
  acceptTutorInvite,
  declineTutorInvite,
  rescindTutorInvite,
  revokeTutorGrant,
  resignTutorGrant,
  listTutorGrants,
  expirePendingInvites,
} from "./tutor_invites";

export { updateTutorGrantPermissions } from "./tutor_invites";

export {
  tutorUpsertGoal,
  tutorDeleteGoal,
  tutorUpsertTrack,
  tutorDeleteTrack,
  tutorUpsertStageDefinition,
  tutorUpsertStudyDayConfig,
  tutorDeleteStudyDayConfig,
  tutorReplaceStudyDays,
  tutorUpdateGamificationSettings,
  tutorSetProfileProgram,
  tutorUpsertCurriculumScope,
  tutorEditProfile,
} from "./tutor_writes";

// Story 4.7 (DNI-515): parent push when a tutor changes the goal or main track.
export { onChangeLogCreated } from "./notifications";

// Per-child content visibility policy (server-only writes; tutor grant checked).
export { setProfileHiddenContent } from "./hidden_content";

// The translation module declares ANTHROPIC_API_KEY at module scope. Load it
// only when explicitly enabled so deploy discovery never registers that secret
// for a release that does not include the callable.
if (process.env.PHRASE_TRANSLATION_ENABLED === "true") {
  const { translatePhrases } = require("./phrase_translations") as typeof import("./phrase_translations");
  exports.translatePhrases = translatePhrases;
}

// Parent PIN authority and short-lived server sessions (7vx).
export { setParentPin, createParentSession, revokeParentSession } from "./parent_sessions";

// Profile-scoped social graph and parent-controlled child follow requests.
export {
  upsertSocialProfile,
  setChildSocialControls,
  getChildSocialControls,
  sendFollowRequest,
  reviewFollowRequest,
  removeFollow,
  blockSocialProfile,
  unblockSocialProfile,
  publishSocialSummary,
  getSocialSummaryVisibility,
  setSocialSummaryVisibility,
  searchSchoolMembers,
  listSocialConnections,
} from "./social_graph";

// School profiles, membership, invitations, moderation, and staff summary access.
export {
  createSchool,
  getSchoolProfile,
  createSchoolInvite,
  joinSchoolWithInvite,
  listMySchools,
  listSchoolRoster,
  removeSchoolMember,
  leaveSchool,
  addSchoolAdmin,
  removeSchoolAdmin,
  transferSchoolAdmin,
  reportSchool,
  setSchoolSuspended,
  deleteSchool,
} from "./schools";

// Private and school-hosted groups with parent-controlled child summary access.
export {
  createLearningGroup,
  createLearningGroupInvite,
  getLearningGroupInvite,
  joinLearningGroup,
  listMyLearningGroups,
  getLearningGroup,
  listGroupParentApprovals,
  setGroupMemberApproval,
  removeLearningGroupMember,
  leaveLearningGroup,
  transferLearningGroupAdmin,
  deleteLearningGroup,
} from "./groups";

export {
  listGroupTaskCurricula,
  listLearningGroupTasks,
  listGroupTaskScopesForCurriculum,
  createLearningGroupTask,
  respondToLearningGroupTask,
  submitLearningGroupTaskPreferences,
  allocateLearningGroupTask,
  requestLateLearningGroupTaskJoin,
  reviewLateLearningGroupTaskJoin,
  listMyLearningGroupDailyTasks,
  reconcileLearningGroupMissedTasks,
} from "./group_tasks";
