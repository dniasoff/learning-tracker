// Mirror test for
// `lib/features/sacred_time/presentation/providers/location_service_provider.dart`
// (DNI-481: the only part of the retired sacred_location_provider kept).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/location_service_provider.dart';

void main() {
  test('provides the platform LocationService', () {
    final container = ProviderContainer.test();
    expect(container.read(locationServiceProvider), isA<LocationService>());
  });
}
