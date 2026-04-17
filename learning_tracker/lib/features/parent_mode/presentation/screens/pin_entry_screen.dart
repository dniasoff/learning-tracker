import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Full-screen PIN entry for accessing parent mode.
///
/// Shows a numeric keypad with obscured digits. Handles lockout display.
@RoutePage()
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key});

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  String? _errorMessage;
  bool _isLockedOut = false;
  int _lockoutRemainingMinutes = 0;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  Future<void> _checkLockoutStatus() async {
    final profileId = ref.read(selectedProfileIdProvider);
    if (profileId == null) return;
    final pinService = ref.read(pinServiceProvider);
    final remaining = await pinService.getProfileLockoutRemainingMinutes(
      profileId,
    );
    if (remaining > 0 && mounted) {
      setState(() {
        _isLockedOut = true;
        _lockoutRemainingMinutes = remaining;
      });
    }
  }

  Future<void> _onPinEntered(String pin) async {
    final profileId = ref.read(selectedProfileIdProvider);
    if (profileId == null) {
      setState(() => _errorMessage = 'No active profile');
      return;
    }
    final pinService = ref.read(pinServiceProvider);
    try {
      final isValid = await pinService.verifyProfilePin(profileId, pin);
      if (isValid) {
        if (mounted) await context.router.maybePop(true);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Enter Parent PIN')),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PinEntryWidget(
              title: 'Enter Parent PIN',
              errorMessage: _errorMessage,
              isLockedOut: _isLockedOut,
              lockoutRemainingMinutes: _lockoutRemainingMinutes,
              onPinComplete: _onPinEntered,
            ),
          ),
        ),
      ),
    );
  }
}
