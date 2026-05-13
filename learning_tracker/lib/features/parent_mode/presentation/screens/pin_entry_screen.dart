import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Route shell for entering the parent PIN. Opens the keypad dialog and pops
/// with `true` when verification succeeds (and marks the guard session).
@RoutePage()
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
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
    final ok = await showParentPinVerificationDialog(
      context,
      profileId: profileId,
      pinService: pinService,
    );
    if (ok) {
      ref.read(routerProvider).pinGuard.markAuthenticated(profileId);
    }
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
