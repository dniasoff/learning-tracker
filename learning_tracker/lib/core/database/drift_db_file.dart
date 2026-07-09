import 'dart:io';

/// Resolves a drift_flutter-managed database's on-disk [File], or null if
/// neither the `.sqlite`-suffixed nor the bare-name file exists.
///
/// drift_flutter 0.2.8 stores `driftDatabase(name: 'foo.db')` as
/// `foo.db.sqlite` on the filesystem (see drift_flutter/src/native.dart line
/// 51: `'$name.sqlite'`). Callers that know [dbFileName] from a registry row
/// (which stores the logical name, not the on-disk name) must try the
/// `.sqlite`-suffixed path first, then fall back to the bare name so
/// registry entries written before this fix are still resolved.
///
/// AUD-account-09: this was independently reimplemented in
/// [AccountLifecycleService] and `PendingLocalSignupStore`, each discovered
/// and fixed as a separate bug. Any future drift_flutter change to the
/// on-disk filename scheme now only needs to be applied here.
File? resolveDriftDbFile(String databasesPath, String dbFileName) {
  final suffixed = File('$databasesPath/$dbFileName.sqlite');
  if (suffixed.existsSync()) return suffixed;
  final bare = File('$databasesPath/$dbFileName');
  if (bare.existsSync()) return bare;
  return null;
}

/// Deletes the on-disk file for a drift_flutter-managed database identified
/// by [dbFileName] under [databasesPath], if it exists. No-ops if neither
/// the `.sqlite`-suffixed nor the bare-name file is present.
void deleteDriftDbFile(String databasesPath, String dbFileName) {
  resolveDriftDbFile(databasesPath, dbFileName)?.deleteSync();
}
