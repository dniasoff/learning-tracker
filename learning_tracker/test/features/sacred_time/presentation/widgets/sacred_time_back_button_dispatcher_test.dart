// Mirror test for
// `lib/features/sacred_time/presentation/widgets/sacred_time_back_button_dispatcher.dart`
// (DNI-481 AC-1: back navigation is blocked during a lock).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_back_button_dispatcher.dart';

class _Delegate extends RouterDelegate<Object> with ChangeNotifier {
  int pops = 0;

  @override
  Widget build(BuildContext context) => const SizedBox();

  @override
  Future<bool> popRoute() async {
    pops++;
    return true;
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('while locked, system back is consumed and no route pops', () async {
    var locked = true;
    final dispatcher = SacredTimeBackButtonDispatcher(isLocked: () => locked);
    var routerPops = 0;
    Future<bool> router() async {
      routerPops++;
      return true;
    }

    dispatcher.addCallback(router);
    // Unregisters the dispatcher from the binding again.
    addTearDown(() => dispatcher.removeCallback(router));
    expect(await dispatcher.didPopRoute(), isTrue);
    expect(routerPops, 0);

    locked = false;
    expect(await dispatcher.didPopRoute(), isTrue);
    expect(routerPops, 1, reason: 'unlocked: the router handles back');
  });

  testWidgets('withSacredTimeBackBlock keeps the config and swaps only the '
      'dispatcher; a locked back press never reaches the delegate', (
    tester,
  ) async {
    var locked = true;
    final delegate = _Delegate();
    final base = RouterConfig<Object>(routerDelegate: delegate);
    final config = withSacredTimeBackBlock(base, isLocked: () => locked);
    expect(config.routerDelegate, same(delegate));
    expect(config.backButtonDispatcher, isA<SacredTimeBackButtonDispatcher>());

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.binding.handlePopRoute();
    expect(delegate.pops, 0);

    locked = false;
    await tester.binding.handlePopRoute();
    expect(delegate.pops, 1);
  });
}
