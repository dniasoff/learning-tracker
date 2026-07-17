/// Unit tests for [resolvePinFlowErrorText] — the single, exhaustive
/// PinFlowError -> localized-text switch shared by every PIN-entry UI
/// (AUD-profiles-06/AUD-profiles-09).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/pin_flow_error_text.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  group('resolvePinFlowErrorText', () {
    test('null error resolves to null (no text shown)', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      expect(resolvePinFlowErrorText(null, l10n), isNull);
    });

    test('every PinFlowError value resolves to non-empty EN text', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      for (final error in PinFlowError.values) {
        final text = resolvePinFlowErrorText(error, l10n);
        expect(
          text,
          isNotNull,
          reason: '$error must resolve to localized text, not null',
        );
        expect(
          text,
          isNotEmpty,
          reason: '$error must resolve to non-empty text',
        );
      }
    });

    test('resolves each error to its expected EN ARB string', () {
      final AppLocalizations l10n = AppLocalizationsEn();
      expect(
        resolvePinFlowErrorText(PinFlowError.incorrectPin, l10n),
        l10n.incorrectPin,
      );
      expect(
        resolvePinFlowErrorText(PinFlowError.pinsDoNotMatch, l10n),
        l10n.pinsDoNotMatch,
      );
      expect(
        resolvePinFlowErrorText(PinFlowError.noActiveProfile, l10n),
        l10n.pinNoActiveProfile,
      );
      expect(
        resolvePinFlowErrorText(PinFlowError.invalidPinFormat, l10n),
        l10n.pinInvalidFormat,
      );
      expect(
        resolvePinFlowErrorText(PinFlowError.unexpected, l10n),
        l10n.pinFailedToSave,
      );
    });

    test('every PinFlowError value resolves to non-empty Hebrew text — no '
        'raw-English-leak fallback', () {
      final AppLocalizations l10n = AppLocalizationsHe();
      for (final error in PinFlowError.values) {
        final text = resolvePinFlowErrorText(error, l10n);
        expect(
          text,
          isNotNull,
          reason: '$error must resolve to localized Hebrew text',
        );
        expect(text, isNotEmpty);
      }
    });
  });
}
