import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

/// One verse range assigned to an aliyah in a weekly parsha.
final class ParshaAliyah {
  const ParshaAliyah({
    required this.portionKey,
    required this.portionName,
    required this.aliyahNumber,
    required this.startRef,
    required this.endRef,
  });

  final String portionKey;
  final String portionName;
  final int aliyahNumber;
  final String startRef;
  final String endRef;
}

/// Cache-only access to the bundled weekly and festival aliyah boundaries.
final class ParshaAliyahRepository {
  const ParshaAliyahRepository(this._database);

  final ContentDatabase _database;

  /// Looks up aliyot using the enum name returned by kosher_dart.
  Future<List<ParshaAliyah>> getForPortion(
    String portionKey, {
    required bool inIsrael,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT portion_key, portion_name, aliyah_number, start_ref, end_ref '
          'FROM parsha_aliyot WHERE portion_key = ? AND region IN (?, ?) '
          'ORDER BY aliyah_number',
          variables: [
            Variable.withString(portionKey),
            Variable.withString('any'),
            Variable.withString(inIsrael ? 'israel' : 'diaspora'),
          ],
          readsFrom: {_database.parshaAliyot},
        )
        .get();
    return [
      for (final row in rows)
        ParshaAliyah(
          portionKey: row.read<String>('portion_key'),
          portionName: row.read<String>('portion_name'),
          aliyahNumber: row.read<int>('aliyah_number'),
          startRef: row.read<String>('start_ref'),
          endRef: row.read<String>('end_ref'),
        ),
    ];
  }
}
