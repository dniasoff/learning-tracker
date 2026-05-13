---
name: Flutter/Dart toolchain path
description: dart and flutter binaries are not on PATH; must use explicit paths
type: feedback
---

`dart` and `flutter` are not on the system PATH. Always use explicit paths:

- Flutter: `/home/daniel/development/flutter/bin/flutter`
- Dart: `/home/daniel/development/flutter/bin/dart`

**Why:** `which flutter` and `which dart` both return nothing; running `dart` bare returns exit 127.

**How to apply:** Any time running `dart analyze`, `dart run build_runner`, `flutter test`, `flutter build`, etc. — prefix with the full path above.
