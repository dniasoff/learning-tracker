import 'package:drift/drift.dart';

/// Tracks which curricula have had their text content downloaded.
///
/// Each row represents a curriculum whose text content has been
/// downloaded for offline access. The itemCount and textVersion
/// allow staleness detection.
class TextDownloadStatuses extends Table {
  /// curriculum_id from CurriculumId enum storageKey
  TextColumn get curriculumId => text()();

  /// Number of text items downloaded for this curriculum
  IntColumn get itemCount => integer()();

  /// Version string of the text content
  TextColumn get textVersion => text()();

  /// When the download completed
  DateTimeColumn get downloadedAt => dateTime()();

  /// Number of items stored so far during an in-progress download.
  /// Null when no partial download is in progress.
  IntColumn get storedItemCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {curriculumId};
}
