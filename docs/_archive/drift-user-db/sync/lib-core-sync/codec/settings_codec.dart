/// Codec for Firestore `settings/{curriculumId}` documents.
///
/// NOTE (W3.32): This codec handles the current combined settings document
/// that includes stage definitions nested under `stages: [...]`. After
/// W3.32 (split stage_definitions out of settings), this codec will cover
/// only the non-stage-definition settings fields.
library;

import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a curriculum settings document.
class SettingsRow {
  const SettingsRow({
    required this.curriculumId,
    this.trackId,
    this.updatedAt,
    this.syncedAt,
    this.stages = const [],
  });

  final String curriculumId;
  final int? trackId;
  final DateTime? updatedAt;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time. Used as the ±5 s clock-skew tie-breaker by mergers.
  final DateTime? syncedAt;

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
      syncedAt: FirestoreCodec.parseDateTime(raw['synced_at']),
      stages: stages,
    );
  }

  /// **Decode-only (AUD-core-sync-38).** `SettingsCodec.encode()` has zero
  /// production call sites: nothing in `lib/` builds a settings push
  /// payload — `SyncWriteFacade.pushSettings` itself has no live caller
  /// (goals and stage definitions were split onto their own dedicated push
  /// routes; see the doc comments on `sync_write_facade.dart`). `decode()`
  /// is the genuinely live half of this codec — [SettingsMerger] calls it
  /// on every pulled `settings` doc.
  ///
  /// [EntityCodec]'s interface contract requires an `encode` override, so
  /// this can't be deleted outright; it throws instead of silently
  /// returning a payload nobody validates or pushes, so a future caller
  /// discovers the decode-only status immediately rather than shipping
  /// dead code that looks load-bearing. If settings ever gain a real write
  /// path, replace this with a working serializer (mirroring the sibling
  /// codecs) and wire it into that path in the same change.
  @override
  Map<String, dynamic> encode(SettingsRow model) {
    throw UnsupportedError(
      'SettingsCodec.encode() is decode-only (AUD-core-sync-38) — settings '
      'currently have no production push path. See the doc comment on this '
      'method before wiring a caller to it.',
    );
  }
}
