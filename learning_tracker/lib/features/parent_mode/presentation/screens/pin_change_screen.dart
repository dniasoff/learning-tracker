import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';

/// Screen for changing the parent PIN.
///
/// Flow: verify current PIN → enter new PIN → confirm new PIN → store.
@RoutePage()
class PinChangeScreen extends ConsumerStatefulWidget {
  const PinChangeScreen({super.key});

  @override
  ConsumerState<PinChangeScreen> createState() => _PinChangeScreenState();
}

enum _PinChangeStep { verifyCurrent, enterNew, confirmNew }

class _PinChangeScreenState extends ConsumerState<PinChangeScreen> {
  _PinChangeStep _step = _PinChangeStep.verifyCurrent;
  String? _newPin;
  String? _errorMessage;
  bool _isLockedOut = false;
  int _lockoutRemainingMinutes = 0;

  String get _title {
    switch (_step) {
      case _PinChangeStep.verifyCurrent:
        return 'Enter Current PIN';
      case _PinChangeStep.enterNew:
        return 'Enter New PIN';
      case _PinChangeStep.confirmNew:
        return 'Confirm New PIN';
    }
  }

  Future<void> _onPinComplete(String pin) async {
    final pinService = ref.read(pinServiceProvider);

    switch (_step) {
      case _PinChangeStep.verifyCurrent:
        try {
          final isValid = await pinService.verifyParentPin(pin);
          if (isValid) {
            setState(() {
              _step = _PinChangeStep.enterNew;
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

      case _PinChangeStep.enterNew:
        setState(() {
          _newPin = pin;
          _step = _PinChangeStep.confirmNew;
          _errorMessage = null;
        });

      case _PinChangeStep.confirmNew:
        if (pin != _newPin) {
          setState(() {
            _errorMessage = 'PINs do not match';
            _step = _PinChangeStep.enterNew;
            _newPin = null;
          });
          return;
        }
        await pinService.setParentPin(pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN changed successfully')),
          );
          await context.router.maybePop(true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Change Parent PIN')),
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
