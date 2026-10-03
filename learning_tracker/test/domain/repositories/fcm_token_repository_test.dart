// FcmTokenOwner value semantics (Story 4.7 / DNI-515).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/repositories/fcm_token_repository.dart';

void main() {
  test('owners compare by account id and path uid', () {
    const a = FcmTokenOwner(accountId: 'acct', uid: 'uid');
    expect(a, const FcmTokenOwner(accountId: 'acct', uid: 'uid'));
    expect(
      a.hashCode,
      const FcmTokenOwner(accountId: 'acct', uid: 'uid').hashCode,
    );
    expect(a == const FcmTokenOwner(accountId: 'acct', uid: 'other'), isFalse);
    expect(a == const FcmTokenOwner(accountId: 'other', uid: 'uid'), isFalse);
  });

  test('toString never prints the path uid', () {
    expect(
      const FcmTokenOwner(accountId: 'acct', uid: 'secret-uid').toString(),
      isNot(contains('secret-uid')),
    );
  });
}
