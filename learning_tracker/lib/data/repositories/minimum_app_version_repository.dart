import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/auth/auth_providers.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract interface class MinimumAppVersionChecker {
  Future<bool> shouldBlockApp();
}

final minimumAppVersionCheckerProvider = Provider<MinimumAppVersionChecker>(
  (ref) => FirebaseMinimumAppVersionChecker(
    auth: ref.watch(firebaseAuthGatewayProvider),
    resolveAccount: () => ref.read(activeAccountFirebaseProvider.future),
  ),
);

class FirebaseMinimumAppVersionChecker implements MinimumAppVersionChecker {
  FirebaseMinimumAppVersionChecker({
    required FirebaseAuthGateway auth,
    required Future<AccountFirebaseHandles?> Function() resolveAccount,
    Future<PackageInfo> Function()? loadPackageInfo,
    this.serverReadTimeout = const Duration(seconds: 5),
  }) : _auth = auth,
       _resolveAccount = resolveAccount,
       _loadPackageInfo = loadPackageInfo ?? PackageInfo.fromPlatform;

  static const configPath = 'app_config/min_version';
  static const minimumBuildField = 'minimum_build_number';
  static const lastSeenBuildField = 'last_seen_app_build';

  final FirebaseAuthGateway _auth;
  final Future<AccountFirebaseHandles?> Function() _resolveAccount;
  final Future<PackageInfo> Function() _loadPackageInfo;
  final Duration serverReadTimeout;

  @override
  Future<bool> shouldBlockApp() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final packageInfo = await _loadPackageInfo();
      final build = int.tryParse(packageInfo.buildNumber);
      if (build == null || build < 1) return false;

      final account = await _resolveAccount();
      if (account == null || account.authUid != user.uid) return false;

      unawaited(_recordBuild(account, build));

      // Read only from the server: a cache miss or offline state must never
      // keep the user out of the app. A stale cached minimum is not enforced.
      final snapshot = await account.firestore
          .doc(configPath)
          .get(const GetOptions(source: Source.server))
          .timeout(serverReadTimeout);
      final minimum = snapshot.data()?[minimumBuildField];
      return minimum is int && minimum > build;
    } on Object {
      // Sign-in restoration, Firestore, and network failures are best-effort.
      return false;
    }
  }

  Future<void> _recordBuild(AccountFirebaseHandles account, int build) async {
    if (account.uid != account.authUid) return;
    try {
      await account.firestore.doc('users/${account.uid}').update({
        lastSeenBuildField: build,
      });
    } on Object {
      // This write is informational and cannot block startup or offline use.
    }
  }
}
