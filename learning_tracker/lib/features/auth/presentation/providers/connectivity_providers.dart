import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';

/// Polls [ConnectivityService.isOnline] every 2 seconds and emits
/// `true` for online, `false` for offline.
///
/// Cheap, stream-based alternative to plumbing through a proper
/// platform-level connectivity listener — good enough for the
/// 20.8 banner (spec allows up to 2s detection delay per
/// v2 §4.6 ACs).
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  while (true) {
    yield await service.isOnline;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
});
