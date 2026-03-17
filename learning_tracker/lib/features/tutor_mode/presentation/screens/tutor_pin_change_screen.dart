import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';

/// Screen for changing the tutor PIN.
///
/// Flow: verify current PIN → enter new PIN → confirm new PIN → store.
@RoutePage()
class TutorPinChangeScreen extends ConsumerStatefulWidget {
  const TutorPinChangeScreen({super.key});

  @override
  ConsumerState<TutorPinChangeScreen> createState() =>
      _TutorPinChangeScreenState();
}

enum _TutorPinChangeStep { verifyCurrent, enterNew, confirmNew }

class _TutorPinChangeScreenState extends ConsumerState<TutorPinChangeScreen> {
  _TutorPinChangeStep _step = _TutorPinChangeStep.verifyCurrent;
  String? _newPin;
  String? _errorMessage;
  bool _isLockedOut = false;
  int _lockoutRemainingMinutes = 0;

  String get _title {
    switch (_step) {
      case _TutorPinChangeStep.verifyCurrent:
        return 'Enter Current PIN';
      case _TutorPinChangeStep.enterNew:
        return 'Enter New PIN';
      case _TutorPinChangeStep.confirmNew:
        return 'Confirm New PIN';
    }
  }

  Future<void> _onPinComplete(String pin) async {
    final pinService = ref.read(pinServiceProvider);

    switch (_step) {
      case _TutorPinChangeStep.verifyCurrent:
        try {
          final isValid = await pinService.verifyTutorPin(pin);
          if (isValid) {
            setState(() {
              _step = _TutorPinChangeStep.enterNew;
              _errorMessage = null;
            });
          } else {
            setState(() => _errorMessage = 'Incorrect PIN');
          }
        } on PinLockoutException catch (e) {
          setState(() {
            _isLockedOut = true;
            _lockoutRemainingMinutes = e.remainingMinutes;
            _errorMessage = null;
          });
        }

      case _TutorPinChangeStep.enterNew:
        setState(() {
          _newPin = pin;
          _step = _TutorPinChangeStep.confirmNew;
          _errorMessage = null;
        });

      case _TutorPinChangeStep.confirmNew:
        if (pin != _newPin) {
          setState(() {
            _errorMessage = 'PINs do not match';
            _step = _TutorPinChangeStep.enterNew;
            _newPin = null;
          });
          return;
        }
        await pinService.setTutorPin(pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tutor PIN changed successfully')),
          );
          await context.router.maybePop(true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Change Tutor PIN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PinEntryWidget(
            title: _title,
            errorMessage: _errorMessage,
            isLockedOut: _isLockedOut,
            lockoutRemainingMinutes: _lockoutRemainingMinutes,
            onPinComplete: _onPinComplete,
          ),
        ),
      ),
    );
  }
}
