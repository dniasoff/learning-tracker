import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final profileId = ref.read(selectedProfileIdProvider);
    if (profileId == null) {
      setState(() => _errorMessage = l10n.noActiveProfile);
      return;
    }
    final pinService = ref.read(pinServiceProvider);
    try {
      final isValid = await pinService.verifyProfilePin(profileId, pin);
      if (isValid) {
        ref.read(routerProvider).parentPinGuard.markAuthenticated(profileId);
        if (mounted) await context.router.maybePop(true);
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: l10n.enterParentPin)),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PinEntryWidget(
              title: l10n.enterParentPin,
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
