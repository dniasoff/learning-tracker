import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

/// Provider for DataExportImportService
final dataExportImportServiceProvider = Provider<DataExportImportService>((
  ref,
) {
  return DataExportImportService(database: ref.watch(userDatabaseProvider));
});
