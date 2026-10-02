/// The device's IANA time zone, read when a parent detects the learner's
/// location on this device (DNI-481 AC-3): a detected fix means the learner
/// is where the device is, so its zone is the learner's `time_zone`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Reads the device zone; null when it cannot be read.
typedef DeviceTimeZoneReader = Future<String?> Function();

/// The platform [DeviceTimeZoneReader] (`flutter_timezone`).
Future<String?> readPlatformTimeZone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    return null;
  }
}

/// The [DeviceTimeZoneReader] a location detect uses (tests override it).
final deviceTimeZoneReaderProvider = Provider<DeviceTimeZoneReader>(
  (ref) => readPlatformTimeZone,
);
