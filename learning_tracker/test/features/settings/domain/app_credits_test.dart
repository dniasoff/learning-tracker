import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/settings/domain/app_credits.dart';

void main() {
  group('appCreators', () {
    test('lists the configured creators in display order', () {
      expect(appCreators.map((creator) => creator.name).toList(), [
        'Daniel Niasoff',
        'Josh Heimann',
      ]);
    });

    test('attaches public contact methods to the matching creator', () {
      final daniel = appCreators[0];
      final josh = appCreators[1];

      expect(daniel.email, isNull);
      expect(daniel.phone, isNull);
      expect(daniel.whatsAppDigits, isNull);
      expect(daniel.website, isNull);
      expect(josh.email, 'heimannshua@gmail.com');
      expect(josh.phone, isNull);
      expect(josh.whatsAppDigits, '447464408299');
      expect(josh.website, isNull);
    });
  });

  test('AppCreator supports optional contact fields independently', () {
    const creator = AppCreator(
      name: 'Creator',
      email: 'creator@example.com',
      phone: '+12125550123',
      whatsAppDigits: '442079460123',
      website: 'https://example.com',
    );

    expect(creator.name, 'Creator');
    expect(creator.email, 'creator@example.com');
    expect(creator.phone, '+12125550123');
    expect(creator.whatsAppDigits, '442079460123');
    expect(creator.website, 'https://example.com');
  });
}
