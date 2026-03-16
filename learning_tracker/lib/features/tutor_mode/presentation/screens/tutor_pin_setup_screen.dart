import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';

/// Screen for setting up a 4-digit tutor PIN with confirmation.
///
/// Flow: enter PIN → confirm PIN → store bcrypt hash via PinService.
@RoutePage()
class TutorPinSetupScreen extends ConsumerStatefulWidget {
  const TutorPinSetupScreen({super.key});

  @override
  ConsumerState<TutorPinSetupScreen> createState() =>
      _TutorPinSetupScreenState();
}

class _TutorPinSetupScreenState extends ConsumerState<TutorPinSetupScreen> {
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

    try {
      final pinService = ref.read(pinServiceProvider);
      await pinService.setTutorPin(pin);
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
      appBar: AppBar(title: const Text('Set Tutor PIN')),
      body: Center(
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
    );
  }
}
