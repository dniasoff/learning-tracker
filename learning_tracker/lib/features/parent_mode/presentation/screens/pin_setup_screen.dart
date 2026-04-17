import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Screen for setting up a 4-digit parent PIN with confirmation.
///
/// Flow: enter PIN → confirm PIN → store bcrypt hash via PinService.
@RoutePage()
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _firstPin;
  String? _errorMessage;
  bool _isConfirmStep = false;

  void _onFirstPinEntered(String pin) {
    setState(() {
      _firstPin = pin;
      _isConfirmStep = true;
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmPinEntered(String pin) async {
    if (pin != _firstPin) {
      setState(() {
        _errorMessage = 'PINs do not match';
        _isConfirmStep = false;
        _firstPin = null;
      });
      return;
    }

    final profileId = ref.read(selectedProfileIdProvider);
    if (profileId == null) {
      setState(() => _errorMessage = 'No active profile — cannot set PIN');
      return;
    }

    try {
      final pinService = ref.read(pinServiceProvider);
      await pinService.setProfilePin(profileId, pin);
      if (mounted) {
        await context.router.maybePop(true);
      }
    } on ArgumentError catch (e) {
      setState(() {
        _errorMessage = e.message as String?;
        _isConfirmStep = false;
        _firstPin = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Set Parent PIN')),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PinEntryWidget(
              title: _isConfirmStep ? 'Confirm PIN' : 'Enter New PIN',
              errorMessage: _errorMessage,
              onPinComplete: _isConfirmStep
                  ? _onConfirmPinEntered
                  : _onFirstPinEntered,
            ),
          ),
        ),
      ),
    );
  }
}
