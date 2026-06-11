/// PP-11 regression test: ProfileEditFormDialog must NOT autofocus the name
/// field so the avatar picker is not hidden behind the keyboard at large text.
///
/// RED → GREEN cycle:
///   RED:  autofocus: true on the TextField → fails because autofocusEnabled
///   GREEN: autofocus removed → test passes.
@Tags(['profiles', 'pp11'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _buildDialog() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Render the dialog directly to avoid InkSparkle shader asset issues.
      home: Scaffold(
        body: ProfileEditFormDialog(
          title: 'Edit Learner',
          initialName: 'TestUser',
          initialMode: 'child',
          initialAvatar: 0,
        ),
      ),
    ),
  );
}

void main() {
  group('PP-11 ProfileEditFormDialog autofocus', () {
    testWidgets(
      'name TextField does NOT have autofocus so avatar picker stays visible',
      (tester) async {
        await tester.pumpWidget(_buildDialog());
        await tester.pump();

        // Find the TextField for the profile name.
        final tfFinder = find.byType(TextField);
        expect(tfFinder, findsOneWidget);

        final tf = tester.widget<TextField>(tfFinder);
        // PP-11 fix: autofocus must be false so the keyboard does not push
        // the avatar picker below the fold at font scale 1.3.
        expect(
          tf.autofocus,
          isFalse,
          reason:
              'PP-11: autofocus must be false on the name field so the avatar '
              'picker is not hidden behind the keyboard at large text scale.',
        );
      },
    );
  });
}
