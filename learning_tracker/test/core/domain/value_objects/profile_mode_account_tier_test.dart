import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';

void main() {
  group('ProfileMode', () {
    group('storageKey', () {
      test('adult → "adult"', () {
        expect(ProfileMode.adult.storageKey, 'adult');
      });

      test('child → "child"', () {
        expect(ProfileMode.child.storageKey, 'child');
      });
    });

    group('fromStorageKey', () {
      test('parses "adult"', () {
        expect(ProfileMode.fromStorageKey('adult'), ProfileMode.adult);
      });

      test('parses "child"', () {
        expect(ProfileMode.fromStorageKey('child'), ProfileMode.child);
      });

      test('throws ArgumentError for unknown key', () {
        expect(
          () => ProfileMode.fromStorageKey('unknown'),
          throwsArgumentError,
        );
      });
    });

    group('accessors', () {
      test('isAdult true for adult', () {
        expect(ProfileMode.adult.isAdult, isTrue);
      });

      test('isAdult false for child', () {
        expect(ProfileMode.child.isAdult, isFalse);
      });

      test('isChild true for child', () {
        expect(ProfileMode.child.isChild, isTrue);
      });

      test('isChild false for adult', () {
        expect(ProfileMode.adult.isChild, isFalse);
      });
    });

    test('round-trips through storageKey', () {
      for (final mode in ProfileMode.values) {
        expect(ProfileMode.fromStorageKey(mode.storageKey), mode);
      }
    });
  });

  group('AccountTier', () {
    group('storageKey', () {
      test('cloud → "cloudBorn"', () {
        expect(AccountTier.cloud.storageKey, 'cloudBorn');
      });

      test('local → "localBorn"', () {
        expect(AccountTier.local.storageKey, 'localBorn');
      });
    });

    group('fromStorageKey', () {
      test('parses "cloudBorn"', () {
        expect(AccountTier.fromStorageKey('cloudBorn'), AccountTier.cloud);
      });

      test('parses "localBorn"', () {
        expect(AccountTier.fromStorageKey('localBorn'), AccountTier.local);
      });

      test('throws ArgumentError for unknown key', () {
        expect(
          () => AccountTier.fromStorageKey('unknown'),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for "cloud" (not the storage key)', () {
        expect(() => AccountTier.fromStorageKey('cloud'), throwsArgumentError);
      });
    });

    group('accessors', () {
      test('isCloud true for cloud', () {
        expect(AccountTier.cloud.isCloud, isTrue);
      });

      test('isCloud false for local', () {
        expect(AccountTier.local.isCloud, isFalse);
      });

      test('isLocal true for local', () {
        expect(AccountTier.local.isLocal, isTrue);
      });

      test('isLocal false for cloud', () {
        expect(AccountTier.cloud.isLocal, isFalse);
      });
    });

    test('round-trips through storageKey', () {
      for (final tier in AccountTier.values) {
        expect(AccountTier.fromStorageKey(tier.storageKey), tier);
      }
    });
  });
}
