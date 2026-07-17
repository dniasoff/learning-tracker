// Public surface of the content_browsing feature.
//
// Rule 2 (DNI-386): cross-feature deep imports into `lib/features/content_browsing/`
// sub-paths are forbidden. Other features MUST import this barrel — never
// `lib/features/content_browsing/presentation/...` or
// `lib/features/content_browsing/domain/...` directly.
//
// Only exports that are demonstrably consumed by another feature (or by
// lib/core/) live here; intra-feature imports inside
// `lib/features/content_browsing/` keep using deep paths and SHOULD NOT
// route through this barrel (that would create circular re-exports and
// slow analysis).
//
// To add a new export: confirm the type is actually imported by code
// outside `lib/features/content_browsing/`, then add one line below with a
// comment pointing at one such consumer.
library content_browsing;

// Content repository interface — the DI seam every other feature's
// repositories/services take a `ContentRepository` through. Consumed by:
//   - lib/core/labels/curriculum_label_providers.dart
//   - lib/core/content/content_tree.dart, content_index.dart
//   - lib/features/tracks/, lib/features/learning/, lib/features/progress/,
//     lib/features/onboarding/ (repository/service constructors)
export 'domain/repositories/content_repository.dart' show ContentRepository;

// Content providers — `contentRepositoryProvider` and
// `curriculumContentProvider` are watched directly from outside the
// feature; `curriculumHierarchyConfigProvider` and `contentSearchProvider`
// are also consumed externally. Consumed by:
//   - lib/core/labels/curriculum_label_providers.dart, curriculum_level_name.dart
//   - lib/core/content/content_tree.dart, content_index.dart
//   - lib/features/tracks/, lib/features/learning/, lib/features/progress/,
//     lib/features/onboarding/, lib/features/settings/
export 'presentation/providers/content_providers.dart';
