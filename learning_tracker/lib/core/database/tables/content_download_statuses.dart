import 'package:drift/drift.dart';

/// Tracks which curricula have had their content hierarchy downloaded
/// from Firebase Cloud Storage.
///
/// Distinct from [TextDownloadStatuses] which tracks Sefaria text content.
/// This table tracks the structural content (items, hierarchy) downloaded
/// from cloud storage.
class ContentDownloadStatuses extends Table {
  /// curriculum_id from CurriculumId enum storageKey
  TextColumn get curriculumId => text()();

  /// Language code of the downloaded content (e.g. 'he', 'en')
  TextColumn get languageCode => text()();

  /// Version string of the content
  TextColumn get contentVersion => text()();

  /// Number of content items in this download
  IntColumn get itemCount => integer()();

  /// When the download completed
  DateTimeColumn get downloadedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {curriculumId, languageCode};
}
