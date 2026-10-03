// Cloud Functions entry point.
//
// AUD-firebase-15: this file used to hold five unrelated concerns (account
// deletion, the scheduled audit-log purge, the learning callables, the
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
  deleteAccountData,
} from "./deletes";

export { purgeExpiredAuditLogs } from "./audit_log_purge";

export { billingKillSwitch } from "./billing_kill_switch";

export { ownerOversizedGovernedWrite } from "./owner_oversized_governed_write";

export { tutorBulkPriorCompletions } from "./tutor_bulk_completions";

export {
  tutorRecordLearning,
  tutorUnlearn,
  tutorUpsertSubTrack,
  tutorVoidLearning,
} from "./tutor_learning";
export { tutorRecordLearning, tutorUnlearn, tutorUpsertSubTrack, tutorVoidLearning } from "./tutor_learning";

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
