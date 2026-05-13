/// Identifies the business reason for a cross-profile database read.
///
/// All [CompletionDao] methods that query completions across profiles
/// (i.e. without a `profileId` filter) require an explicit scope value
/// at call time.  This makes unintentional multi-profile leaks visible in
/// code review and in debug logs.
///
/// **This is a Phase-0 band-aid (DNI-321).**  E25 will close the leak at
/// the schema level; at that point these methods will be replaced by
/// profile-scoped queries and this enum can be removed.
enum CrossProfileScope {
  /// Aggregating adult-only completions across profiles for analytics
  /// (e.g. a parent reviewing overall family progress).
  adultAggregation,

  /// Reading completions across profiles to power parent-analytics screens.
  parentAnalytics,

  /// Exporting all user data to a portable format.
  dataExport,

  /// Restoring or syncing completions during a device-restore / cloud-pull
  /// operation.
  syncRestore,
}
