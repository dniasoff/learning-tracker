// Public surface of the learning feature.
//
// Import this barrel (features/learning/learning.dart) from outside this
// feature. Do NOT import deep paths directly.
//
// Populated in Wave 4 (W4.x) — learning domain and completion modelling.
library learning;

// Story 3.5 (DNI-508): the catch-up reminder withdraws a reminder whose
// card would be empty, reading the card exactly as the Learn tab does.
export 'presentation/providers/catch_up_cards_provider.dart'
    show catchUpCardHasContent;
