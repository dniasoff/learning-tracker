// Cloud Functions entry point.
//
// AUD-firebase-15: this file used to hold five unrelated concerns (account
// deletion, the scheduled audit-log purge, the bulk-completion proxy, the
// tutor invite/grant lifecycle, and the tutor CRUD write-paths) in one
// 2000+ line god-file. It is now a barrel that only re-exports the deployed
// Cloud Functions from their focused modules below — deployed function
// names and functions/test imports (`import('../lib/index.js')`) are
// unaffected because every export name is preserved exactly.
//
// Line budget: stays under 300 lines — it should never again accumulate
// function bodies. Add new Cloud Functions to (or alongside) one of the
// modules below, then re-export it here.

export {
  onUserDeleted,
  deleteLearnerProfile,
  deleteCurriculumTrack,
  deleteBulkMarkedCompletions,
  deleteAccountData,
} from "./deletes";

export { purgeExpiredAuditLogs } from "./audit_log_purge";

export { tutorBulkPriorCompletions } from "./tutor_bulk_completions";

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

export {
  tutorResetCompletion,
  tutorUpsertGoal,
  tutorDeleteGoal,
  tutorUpsertTrack,
  tutorDeleteTrack,
  tutorUpsertStageDefinition,
  tutorUpsertStudyDayConfig,
  tutorDeleteStudyDayConfig,
  tutorUpdateGamificationSettings,
  tutorUpsertBookmark,
  tutorSetProfileProgram,
  tutorUpsertCurriculumScope,
  tutorEditProfile,
} from "./tutor_writes";
