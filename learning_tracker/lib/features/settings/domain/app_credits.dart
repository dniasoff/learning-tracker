/// A creator and the contact methods that belong to them.
class AppCreator {
  const AppCreator({
    required this.name,
    this.email,
    this.phone,
    this.whatsAppDigits,
    this.website,
  });

  final String name;
  final String? email;
  final String? phone;

  /// WhatsApp phone number in international digits-only format, without `+`.
  final String? whatsAppDigits;
  final String? website;
}

/// Public creator credits and owner-provided contact details for the About page.
const List<AppCreator> appCreators = [
  AppCreator(name: 'Daniel Niasoff'),
  AppCreator(
    name: 'Josh Heimann',
    email: 'heimannshua@gmail.com',
    whatsAppDigits: '447464408299',
  ),
];
