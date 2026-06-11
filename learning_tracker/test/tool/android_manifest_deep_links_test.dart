// Regression test for PP-7: AndroidManifest.xml must register an intent-filter
// for the /invite deep-link path so AcceptInvite resolves correctly.
//
// Root cause: only /sign-in was registered; /invite was advertised in the app
// but missing from the manifest — so Android never routed invite links to the
// app's MainActivity.
//
// Fix: added a second autoVerify intent-filter with pathPrefix="/invite" on the
// same host (torah-study-tracker.firebaseapp.com).
//
// This test reads AndroidManifest.xml as text and asserts the required
// attributes are present.  It is a plain unit test — no device/emulator needed.

@Tags(['android', 'manifest', 'pp_7'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Returns the text content of AndroidManifest.xml.
/// flutter test runs with cwd = learning_tracker/.
String _readManifest() =>
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

void main() {
  group('AndroidManifest deep-link intent-filters (PP-7)', () {
    test('/sign-in intent-filter is present (baseline check)', () {
      final text = _readManifest();
      expect(
        text,
        contains('android:pathPrefix="/sign-in"'),
        reason:
            '/sign-in intent-filter must still be present (baseline sanity)',
      );
    });

    test(
      '/invite pathPrefix is registered for AcceptInvite deep-link (PP-7)',
      () {
        final text = _readManifest();
        expect(
          text,
          contains('android:pathPrefix="/invite"'),
          reason:
              '/invite must be registered as a pathPrefix in an intent-filter '
              'so Android routes tutor invite deep-links to MainActivity. '
              'Without this, AcceptInviteScreen is unreachable via external '
              'links.',
        );
      },
    );

    test('/invite filter references the correct host', () {
      final text = _readManifest();
      // Find the intent-filter block that contains /invite.
      // We look for the host declaration near the /invite pathPrefix.
      // Both attributes must appear in the same intent-filter block.
      final inviteFilterStart = text.indexOf('android:pathPrefix="/invite"');
      expect(
        inviteFilterStart,
        greaterThan(-1),
        reason: '/invite pathPrefix must exist before we can check the host',
      );

      // Find the enclosing <intent-filter> by scanning backwards.
      final beforeInvite = text.substring(0, inviteFilterStart);
      final filterStart = beforeInvite.lastIndexOf('<intent-filter');
      final filterEnd = text.indexOf('</intent-filter>', inviteFilterStart);

      expect(filterStart, greaterThan(-1));
      expect(filterEnd, greaterThan(-1));

      final filterBlock = text.substring(filterStart, filterEnd);
      expect(
        filterBlock,
        contains('torah-study-tracker'),
        reason:
            'The /invite intent-filter must reference torah-study-tracker '
            'as the host',
      );
    });

    test('/invite filter uses https scheme', () {
      final text = _readManifest();
      final inviteFilterStart = text.indexOf('android:pathPrefix="/invite"');
      expect(inviteFilterStart, greaterThan(-1));

      final beforeInvite = text.substring(0, inviteFilterStart);
      final filterStart = beforeInvite.lastIndexOf('<intent-filter');
      final filterEnd = text.indexOf('</intent-filter>', inviteFilterStart);
      final filterBlock = text.substring(filterStart, filterEnd);

      expect(
        filterBlock,
        contains('android:scheme="https"'),
        reason:
            'The /invite intent-filter must declare scheme="https" so that '
            'https://torah-study-tracker... invite links are handled',
      );
    });

    test('/invite filter has android:autoVerify="true" for App Links', () {
      final text = _readManifest();
      final inviteFilterStart = text.indexOf('android:pathPrefix="/invite"');
      expect(inviteFilterStart, greaterThan(-1));

      final beforeInvite = text.substring(0, inviteFilterStart);
      final filterStart = beforeInvite.lastIndexOf('<intent-filter');
      final filterEnd = text.indexOf('</intent-filter>', inviteFilterStart);
      final filterBlock = text.substring(filterStart, filterEnd);

      // autoVerify can appear on the opening tag of the <intent-filter>.
      final openTagEnd = filterBlock.indexOf('>');
      final openTag = filterBlock.substring(0, openTagEnd + 1);

      expect(
        openTag,
        contains('android:autoVerify="true"'),
        reason:
            'The /invite intent-filter should have android:autoVerify="true" '
            'so Android App Links verification skips the app-chooser dialog',
      );
    });
  });
}
