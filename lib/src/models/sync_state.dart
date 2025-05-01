/// Base class for all synchronization states.
/// Represents the current status of the sync process.
sealed class SyncState {
  /// Creates a base [SyncState].
  const SyncState();
}

/// Indicates that a synchronization operation is already in progress.
/// Prevents multiple sync operations from running simultaneously.
class InProgress extends SyncState {
  /// Creates an [InProgress] state.
  const InProgress();
}

/// Indicates that metadata is being fetched from local storage.
/// Usually the initial step of the sync process.
class FetchingLocalMetadata extends SyncState {
  /// Creates a [FetchingLocalMetadata] state.
  const FetchingLocalMetadata();
}

/// Indicates that metadata is being fetched from the cloud.
/// Used to compare remote and local data.
class FetchingCloudMetadata extends SyncState {
  /// Creates a [FetchingCloudMetadata] state.
  const FetchingCloudMetadata();
}

/// Indicates that the system is scanning the cloud for missing or outdated data.
/// Ensures local storage is up-to-date with cloud changes.
class ScanningCloud extends SyncState {
  /// Creates a [ScanningCloud] state.
  const ScanningCloud();
}

/// Indicates that the system is scanning local storage for missing or outdated data.
/// Ensures the cloud is up-to-date with local changes.
class ScanningLocal extends SyncState {
  /// Creates a [ScanningLocal] state.
  const ScanningLocal();
}

/// Indicates that data is being saved to the cloud.
/// Carries metadata about the item being uploaded.
class SavingToCloud extends SyncState {
  /// Creates a [SavingToCloud] state with the given [metadata].
  const SavingToCloud(this._metadata);

  /// Metadata for the item that was saved to the cloud.
  T metadata<T>() => _metadata as T;

  /// Metadata for the item that was saved to the cloud.
  final dynamic _metadata;
}

/// Indicates that data was successfully saved to the cloud.
class SavedToCloud extends SyncState {
  /// Creates a [SavedToCloud] state with the given [metadata].
  const SavedToCloud(this._metadata);

  /// Metadata for the item that was saved to the cloud.
  T metadata<T>() => _metadata as T;

  /// Metadata for the item that was saved to the cloud.
  final dynamic _metadata;
}

/// Indicates that data is being saved to local storage.
/// Carries metadata about the item being stored.
class SavingToLocal extends SyncState {
  /// Creates a [SavingToLocal] state with the given [metadata].
  const SavingToLocal(this._metadata);

  /// Metadata for the item that was saved locally.
  T metadata<T>() => _metadata as T;

  /// Metadata for the item that was saved locally.
  final dynamic _metadata;
}

/// Indicates that data was successfully saved to local storage.
class SavedToLocal extends SyncState {
  /// Creates a [SavedToLocal] state with the given [metadata].
  const SavedToLocal(this._metadata);

  /// Metadata for the item that was saved locally.
  T metadata<T>() => _metadata as T;

  /// Metadata for the item that was saved locally.
  final dynamic _metadata;
}

/// Indicates that synchronization completed successfully.
class SyncCompleted extends SyncState {
  /// Creates a [SyncCompleted] state.
  const SyncCompleted();
}

/// Indicates that an error occurred during synchronization.
/// Includes the error and its associated stack trace.
class SyncError extends SyncState {
  /// Creates a [SyncError] with the given [error] and [stackTrace].
  const SyncError(this.error, this.stackTrace);

  /// The error that occurred.
  final Object error;

  /// The associated stack trace.
  final StackTrace stackTrace;
}

/// State representing a cancelled sync operation.
class SyncCancelled implements SyncState {
  /// Creates a [SyncCancelled] state.
  const SyncCancelled();
}
