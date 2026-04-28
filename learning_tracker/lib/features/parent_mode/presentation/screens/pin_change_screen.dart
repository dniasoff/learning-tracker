import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Route target for changing the parent PIN. Presents the same keypad dialog
/// used from Settings, then pops this shell route with the dialog result.
@RoutePage()
class PinChangeScreen extends ConsumerStatefulWidget {
  const PinChangeScreen({super.key});

  @override
  ConsumerState<PinChangeScreen> createState() => _PinChangeScreenState();
}

class _PinChangeScreenState extends ConsumerState<PinChangeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDialog());
  }

  Future<void> _openDialog() async {
    if (!mounted) return;
    final profileId = ref.read(selectedProfileIdProvider);
    final pinService = ref.read(pinServiceProvider);
    if (profileId == null) {
      if (mounted) await context.router.maybePop(false);
      return;
    }
    final ok = await showParentPinChangeDialog(
      context,
      profileId: profileId,
      pinService: pinService,
    );
    if (mounted) await context.router.maybePop(ok);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
