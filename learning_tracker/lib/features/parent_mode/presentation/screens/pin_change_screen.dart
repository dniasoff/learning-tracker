import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

  String _titleForStep(AppLocalizations l10n) {
    switch (_step) {
      case _PinChangeStep.verifyCurrent:
        return l10n.enterCurrentPin;
      case _PinChangeStep.enterNew:
        return l10n.enterNewPin;
      case _PinChangeStep.confirmNew:
        return l10n.confirmNewPin;
    }
  }

  Future<void> _onPinComplete(String pin) async {
    final l10n = AppLocalizations.of(context)!;
    final pinService = ref.read(pinServiceProvider);
    final profileId = ref.read(selectedProfileIdProvider);
    if (profileId == null) {
      setState(() => _errorMessage = l10n.noActiveProfile);
      return;
    }

    switch (_step) {
      case _PinChangeStep.verifyCurrent:
        try {
          final isValid = await pinService.verifyProfilePin(profileId, pin);
          if (isValid) {
            setState(() {
              _step = _PinChangeStep.enterNew;
              _errorMessage = null;
            });
          } else {
            setState(() => _errorMessage = l10n.incorrectPin);
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
            _errorMessage = l10n.pinsDoNotMatch;
            _step = _PinChangeStep.enterNew;
            _newPin = null;
          });
          return;
        }
        await pinService.setProfilePin(profileId, pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.pinChangedSuccessfully)),
          );
          await context.router.maybePop(true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: l10n.changeParentPin)),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PinEntryWidget(
              title: _titleForStep(l10n),
              errorMessage: _errorMessage,
              isLockedOut: _isLockedOut,
              lockoutRemainingMinutes: _lockoutRemainingMinutes,
              onPinComplete: _onPinComplete,
            ),
          ),
        ),
      ),
    );
  }
}
