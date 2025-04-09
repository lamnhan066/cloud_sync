/// Exception thrown when a sync operation is cancelled.
class SyncCancelledException implements Exception {
  /// An exception that is thrown when a synchronization operation is cancelled.
  ///
  /// This exception can be used to indicate that a sync process was intentionally
  /// stopped or interrupted before completion.
  const SyncCancelledException();
}
