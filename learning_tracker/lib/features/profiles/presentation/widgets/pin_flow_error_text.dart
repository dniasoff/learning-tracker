import 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart'
    show PinFlowError;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Localizes a [PinFlowError] code into its ARB string.
///
/// AUD-profiles-06/AUD-profiles-09 (EH-5/AX-2): every PIN-entry UI (the
/// routed PinFlowScreen and the three modal dialogs — setup, verify, change)
/// resolves [PinEntryMachine]'s error codes through this single, EXHAUSTIVE
/// switch — deliberately no default/fallback arm — so a new [PinFlowError]
/// value without a case here is a compile error everywhere, not a silent
/// raw-English leak to Hebrew-locale users. Before consolidation, the modal
/// dialogs each resolved (or in one case did not resolve at all — read a raw
/// exception `.message`) their own error text independently, one of several
/// copies of logic this file now replaces with one.
String? resolvePinFlowErrorText(PinFlowError? error, AppLocalizations l10n) =>
    switch (error) {
      null => null,
      PinFlowError.incorrectPin => l10n.incorrectPin,
      PinFlowError.pinsDoNotMatch => l10n.pinsDoNotMatch,
      PinFlowError.noActiveProfile => l10n.pinNoActiveProfile,
      PinFlowError.invalidPinFormat => l10n.pinInvalidFormat,
      PinFlowError.unexpected => l10n.pinFailedToSave,
    };
