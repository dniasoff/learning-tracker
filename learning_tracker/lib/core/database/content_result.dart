/// Result type for cross-database content lookups.
sealed class ContentResult<T> {
  const ContentResult();
}

/// The content was found and loaded successfully.
class ContentLoaded<T> extends ContentResult<T> {
  /// Creates a [ContentLoaded] with the resolved [data].
  const ContentLoaded(this.data);

  /// The loaded content data.
  final T data;
}

/// The content was not found for the given reference.
class ContentNotFound<T> extends ContentResult<T> {
  /// Creates a [ContentNotFound] for the given [ref].
  const ContentNotFound(this.ref);

  /// The reference string that could not be resolved.
  final String ref;
}
