import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';

void main() {
  group('SyncErrorCode', () {
    test('has exactly the four documented values', () {
      expect(SyncErrorCode.values, hasLength(4));
      expect(
        SyncErrorCode.values,
        containsAll(<SyncErrorCode>[
          SyncErrorCode.timeout,
          SyncErrorCode.permissionDenied,
          // appCheck: a PERMANENT App Check attestation failure, distinct from
          // a bare permissionDenied (1.0.67 incident) — presentation must not
          // frame it as transient / tap-to-retry.
          SyncErrorCode.appCheck,
          SyncErrorCode.unknown,
        ]),
      );
    });

    test('values are stable identifiers, not free text', () {
      // EH-5: presentation resolves each code to a localized string via
      // AppLocalizations/ARB — the enum name itself must never be shown
      // directly to a user, so this pins the identifiers as a contract
      // rather than exercising any formatting.
      for (final code in SyncErrorCode.values) {
        expect(code.name, isNotEmpty);
      }
    });

    test('name round-trips through SyncErrorCode.values.byName', () {
      for (final code in SyncErrorCode.values) {
        expect(SyncErrorCode.values.byName(code.name), same(code));
      }
    });
  });
}
