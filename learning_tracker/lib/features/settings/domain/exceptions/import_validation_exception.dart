import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown by `DataExportImportService.validateAndPreview` (and, by
/// propagation, `DataExportImportService.importData`) when the import
/// payload is malformed JSON or well-formed JSON missing a required
/// export section.
///
/// Distinct from the `dart:core` `FormatException` that `json.decode`
/// itself can throw two lines above the first throw site: without this
/// type a caller could not distinguish "malformed JSON" from "well-formed
/// JSON with an invalid export payload" without string-matching
/// [message], and could not catch it by a stable project type the way
/// every other domain exception in this codebase is caught (AUD-settings-13).
class ImportValidationException extends ValidationException {
  const ImportValidationException(super.message);
}
