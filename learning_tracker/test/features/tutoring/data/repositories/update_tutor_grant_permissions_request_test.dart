// Contract test — UpdateTutorGrantPermissionsRequest (AD-53, DNI-487, ruling
// B13). The same fixture is sent verbatim to the callable by
// functions/test/cf_tutor_grant_permissions.test.mjs, so the client codec and
// the server agree on the `{grantId, canEditLearning}` wire shape.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/update_tutor_grant_permissions_request.dart';

void main() {
  test('toWire matches the shared functions contract fixture', () {
    final fixture =
        jsonDecode(
              File(
                'functions/test/fixtures/'
                'update_tutor_grant_permissions_request.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    const request = UpdateTutorGrantPermissionsRequest(
      grantId: 'grant-1',
      canEditLearning: false,
    );
    expect(request.toWire(), equals(fixture));
  });

  test('sends exactly grantId and canEditLearning', () {
    const request = UpdateTutorGrantPermissionsRequest(
      grantId: 'g',
      canEditLearning: true,
    );
    expect(request.toWire(), {'grantId': 'g', 'canEditLearning': true});
    expect(kUpdateTutorGrantPermissionsCallable, 'updateTutorGrantPermissions');
  });
}
