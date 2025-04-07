/// Exception thrown when a sync operation is cancelled.
class SyncCancelledException implements Exception {
  @override
  String toString() => 'Sync operation was cancelled';
}
