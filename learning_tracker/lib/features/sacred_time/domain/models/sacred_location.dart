import 'package:freezed_annotation/freezed_annotation.dart';

part 'sacred_location.freezed.dart';

enum SacredLocationSource { detected, manualCity, manualCoords }

@freezed
abstract class SacredLocation with _$SacredLocation {
  const factory SacredLocation({
    required double latitude,
    required double longitude,
    required SacredLocationSource source,
    required DateTime fixedAt,
    String? countryCode,
    String? cityLabel,
  }) = _SacredLocation;
}
