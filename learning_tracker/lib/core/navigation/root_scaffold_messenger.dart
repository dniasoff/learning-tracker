import 'package:flutter/material.dart';

/// App-wide [ScaffoldMessengerState] key.
///
/// Code that runs ABOVE the route-level Scaffold — e.g. the shell `build()`
/// that gates the offline-account "back up" banner — cannot reliably reach a
/// displayed messenger via `ScaffoldMessenger.of(context)` (the resolved
/// ancestor messenger may have no visible host, so `showMaterialBanner` would
/// silently no-op). Wiring this key into `MaterialApp.router`'s
/// `scaffoldMessengerKey` lets such code target the root messenger directly.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
