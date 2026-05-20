/// Codec for Firestore `settings/{curriculumId}` documents.
///
/// NOTE (W3.32): This codec handles the current combined settings document
/// that includes stage definitions nested under `stages: [...]`. After
/// W3.32 (split stage_definitions out of settings), this codec will cover
/// only the non-stage-definition settings fields.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a curriculum settings document.
class SettingsRow {
  const SettingsRow({
    required this.curriculumId,
    this.trackId,
    this.updatedAt,
    this.stages = const [],
  });

  final String curriculumId;
  final int? trackId;
  final DateTime? updatedAt;

  /// Nested stage definitions embedded in the settings document.
  ///
  /// Non-empty only until W3.32 splits stage_definitions into their own
  /// Firestore collection.
  final List<StageDefinitionRow> stages;
}

/// Codec for the `settings` Firestore collection.
///
/// Natural key: `curriculumId`.
/// LWW: remote wins when `updated_at` is strictly newer.
class SettingsCodec extends EntityCodec<SettingsRow> {
  const SettingsCodec();

  @override
  String get kind => EntityKind.settings;

  @override
  SettingsRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    if (curriculumId == null) return null;

    final stagesList = raw['stages'] as List<dynamic>?;
    const stageCodec = StageDefinitionCodec();
    final stages =
        stagesList
            ?.cast<Map<String, dynamic>>()
            .map(stageCodec.decode)
            .whereType<StageDefinitionRow>()
            .toList() ??
        <StageDefinitionRow>[];

    return SettingsRow(
      curriculumId: curriculumId,
      trackId: FirestoreCodec.parseInt(raw['track_id']),
      updatedAt: FirestoreCodec.parseDateTime(raw['updated_at']),
      stages: stages,
    );
  }

  @override
  Map<String, dynamic> encode(SettingsRow model) => {
    'curriculum_id': model.curriculumId,
    if (model.trackId != null) 'track_id': model.trackId,
    if (model.updatedAt != null)
      'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
    if (model.stages.isNotEmpty)
      'stages': model.stages.map(const StageDefinitionCodec().encode).toList(),
  };
}
