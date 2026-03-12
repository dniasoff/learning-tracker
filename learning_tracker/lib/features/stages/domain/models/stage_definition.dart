import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'stage_definition.freezed.dart';

/// Domain model for a stage definition.
///
/// Represents a learning stage (e.g., Learn, Chazara 1) within a curriculum,
/// with ordering and delay configuration per D3.
@freezed
abstract class StageDefinition with _$StageDefinition {
  const factory StageDefinition({
    required int id,
    required CurriculumId curriculumId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    required bool isDefault,
  }) = _StageDefinition;
}
