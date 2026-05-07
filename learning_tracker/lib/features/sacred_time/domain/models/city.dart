import 'package:freezed_annotation/freezed_annotation.dart';

part 'city.freezed.dart';

/// A row from the bundled cities database (GeoNames cities15000).
@freezed
abstract class City with _$City {
  const factory City({
    required int id,
    required String name,
    required String countryCode,
    required double latitude,
    required double longitude,
    required int population,
    String? admin1,
    String? timezone,
  }) = _City;
}
