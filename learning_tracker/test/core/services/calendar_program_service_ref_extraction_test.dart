import 'package:flutter_test/flutter_test.dart';

/// Tests for the Sefaria ref extraction logic used in CalendarProgramService.
///
/// The actual method is private, so we test the same extraction algorithm
/// directly to validate the logic without needing to mock the full service.
String extractSefariaRefFromLink(String? link, String fallback) {
  if (link == null || !link.contains('sefaria.org/')) return fallback;
  try {
    final uri = Uri.parse(link);
    final path = uri.path;
    final rawRef = path.startsWith('/') ? path.substring(1) : path;
    return Uri.decodeComponent(rawRef);
  } catch (_) {
    return fallback;
  }
}

void main() {
  group('Sefaria ref extraction from Hebcal link', () {
    test('extracts URL-decoded ref from Chofetz Chaim link', () {
      const link =
          'https://www.sefaria.org/Chofetz_Chaim%2C_Part_One%2C_The_Prohibition_Against_Lashon_Hara%2C_Principle_9.1?lang=bi&utm_source=hebcal.com';
      final ref = extractSefariaRefFromLink(link, 'fallback');
      expect(
        ref,
        'Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1',
      );
    });

    test('extracts ref from simple Nach Yomi link', () {
      const link =
          'https://www.sefaria.org/I_Samuel.1?lang=bi&utm_source=hebcal.com';
      final ref = extractSefariaRefFromLink(link, 'fallback');
      expect(ref, 'I_Samuel.1');
    });

    test('extracts ref from Kitzur SA link', () {
      const link = 'https://www.sefaria.org/Kitzur_Shulchan_Arukh.1.1?lang=bi';
      final ref = extractSefariaRefFromLink(link, 'fallback');
      expect(ref, 'Kitzur_Shulchan_Arukh.1.1');
    });

    test('returns fallback when link is null', () {
      final ref = extractSefariaRefFromLink(null, 'my fallback');
      expect(ref, 'my fallback');
    });

    test('returns fallback when link has no sefaria.org', () {
      const link = 'https://www.hebcal.com/some/path';
      final ref = extractSefariaRefFromLink(link, 'my fallback');
      expect(ref, 'my fallback');
    });

    test('returns fallback for empty string link', () {
      final ref = extractSefariaRefFromLink('', 'my fallback');
      expect(ref, 'my fallback');
    });

    test('handles link with no path after domain', () {
      const link = 'https://www.sefaria.org/';
      final ref = extractSefariaRefFromLink(link, 'fallback');
      expect(ref, '');
    });
  });
}
