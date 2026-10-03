// Story 5.4 (DNI-519) AC-13: the AR-3 bump (share_plus ^13.3.0, pdf
// ^3.13.1; Story 1.1, DNI-463) has landed, and the existing backup export
// still delivers its file through the share_plus 13 API.
//
// The pubspec constraints themselves are asserted by
// test/tool/check_story_1_1_stack_test.dart; this file checks the backup
// delivery end to end against the share_plus platform channel.
@Tags(['settings', 'backup', 'story_5_4'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/presentation/providers/data_export_import_providers.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late PathProviderPlatform previousPathProvider;
  final calls = <MethodCall>[];

  setUp(() {
    temp = Directory.systemTemp.createTempSync('backup_share_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(temp.path);
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          calls.add(call);
          return 'dev.fluttercommunity.plus/share/unavailable';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
    PathProviderPlatform.instance = previousPathProvider;
    temp.deleteSync(recursive: true);
  });

  test(
    'AC-13 the backup JSON is shared as a file through share_plus 13',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(backupFileDeliveryProvider).share('{"v":1}');

      expect(calls, hasLength(1));
      final call = calls.single;
      expect(call.method, 'share');
      final args = Map<String, Object?>.from(call.arguments as Map);
      final paths = (args['paths']! as List).cast<String>();
      expect(paths, ['${temp.path}/learning_tracker_backup.json']);
      expect(args['mimeTypes'], ['application/json']);
      expect(File(paths.single).readAsStringSync(), '{"v":1}');
    },
  );
}
