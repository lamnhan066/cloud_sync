/// An error thrown when attempting to perform a sync operation on a disposed CloudSync object.
class SyncDisposedError extends StateError {
  /// Creates a [SyncDisposedError] with a default error message.
  SyncDisposedError()
      : super(
            'CloudSync object has been disposed and cannot perform this operation.');

  /// Creates a [SyncDisposedError] with a custom error message.
  SyncDisposedError.withMethodName(String methodName)
      : super(
            'CloudSync object has been disposed and cannot perform the $methodName operation.');
}
