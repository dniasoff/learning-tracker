/// Reads an async provider once it has settled (C0, DNI-524).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// Listens to [provider] in [container] and drains the event queue until
/// it leaves the loading state (or [maxTurns] queue drains pass), then
/// returns its value. The subscription closes at test teardown.
Future<AsyncValue<T>> settledAsync<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider, {
  int maxTurns = 10,
}) async {
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < maxTurns && sub.read().isLoading; i++) {
    await pumpEventQueue();
  }
  return sub.read();
}
