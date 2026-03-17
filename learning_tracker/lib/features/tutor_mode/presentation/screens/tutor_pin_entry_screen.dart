import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';

/// Full-screen PIN entry for accessing tutor mode.
///
/// Shows a numeric keypad with obscured digits. Handles lockout display.
@RoutePage()
class TutorPinEntryScreen extends ConsumerStatefulWidget {
  const TutorPinEntryScreen({super.key});

  @override
  ConsumerState<TutorPinEntryScreen> createState() =>
      _TutorPinEntryScreenState();
}

class _TutorPinEntryScreenState extends ConsumerState<TutorPinEntryScreen> {
  String? _errorMessage;
  bool _isLockedOut = false;
  int _lockoutRemainingMinutes = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkLockoutStatus();
    });
  }

  Future<void> _checkLockoutStatus() async {
    final pinService = ref.read(pinServiceProvider);
    final remaining = await pinService.getTutorLockoutRemainingMinutes();
    if (!mounted) return;
    if (remaining > 0) {
      setState(() {
        _isLockedOut = true;
        _lockoutRemainingMinutes = remaining;
      });
      _startLockoutCountdown();
    } else {
      _lockoutTimer?.cancel();
      setState(() {
        _isLockedOut = false;
        _lockoutRemainingMinutes = 0;
      });
    }
  }

  Future<void> _onPinEntered(String pin) async {
    final pinService = ref.read(pinServiceProvider);
    try {
      final isValid = await pinService.verifyTutorPin(pin);
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
      appBar: AppBar(title: const AppBarTitle(text: 'Enter Tutor PIN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PinEntryWidget(
            title: 'Enter Tutor PIN',
            errorMessage: _errorMessage,
            isLockedOut: _isLockedOut,
            lockoutRemainingMinutes: _lockoutRemainingMinutes,
            onPinComplete: _onPinEntered,
          ),
        ),
      ),
    );
  }
}
