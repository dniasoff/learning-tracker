import 'package:freezed_annotation/freezed_annotation.dart';

part 'hebcal_learning_response.freezed.dart';
part 'hebcal_learning_response.g.dart';

/// A single learning item from the Hebcal API.
@freezed
abstract class HebcalLearningItem with _$HebcalLearningItem {
  const factory HebcalLearningItem({
    required String title,
    String? date,
    String? category,
    String? memo,
    String? link,
  }) = _HebcalLearningItem;

  factory HebcalLearningItem.fromJson(Map<String, dynamic> json) =>
      _$HebcalLearningItemFromJson(json);
}

/// Response from the Hebcal API for daily learning programs.
@freezed
abstract class HebcalLearningResponse with _$HebcalLearningResponse {
  const factory HebcalLearningResponse({
    required List<HebcalLearningItem> items,
    String? title,
  }) = _HebcalLearningResponse;

  factory HebcalLearningResponse.fromJson(Map<String, dynamic> json) =>
      _$HebcalLearningResponseFromJson(json);
}
