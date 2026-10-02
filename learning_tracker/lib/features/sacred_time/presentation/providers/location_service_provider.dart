/// The [LocationService] (geolocator + geocoding) the Sacred Time location
/// detect and the onboarding permission prompt use (tests override it).
///
/// DNI-481 (R9) kept only this location lookup from the retired
/// `sacred_location_provider.dart`: a detected fix is written onto the
/// active learner as a governed `learnerSettings` change
/// (`learnerSettingsEditorProvider`), never into device preferences.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';

/// A stateless facade over the platform geolocation calls.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
