import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/features/content_browsing/domain/profile_visible_content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';

/// Test wiring for consumers that resolve the profile-visible content seam.
///
/// The raw repository remains the fixture source while the visible wrapper is
/// resolved with an empty hidden-ref policy unless a test explicitly needs to
/// exercise hidden content.
List<Override> contentRepositoryOverrides(
  ContentRepository repository, {
  Set<String> hiddenRefs = const <String>{},
}) => [
  contentRepositoryProvider.overrideWithValue(repository),
  visibleContentRepositoryProvider.overrideWith(
    (ref) async => ProfileVisibleContentRepository(repository, hiddenRefs),
  ),
  visibleContentRepositoryForScopeProvider.overrideWith(
    (ref, scope) async =>
        ProfileVisibleContentRepository(repository, hiddenRefs),
  ),
];
