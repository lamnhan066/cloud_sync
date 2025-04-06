import 'package:cloud_sync/src/models/sync_metadata.dart';

/// Base class representing the state of a synchronization process.
/// This serves as the foundation for all specific synchronization states.
sealed class SyncState {
  /// Constructor for the base synchronization state.
  const SyncState();
}

/// Represents a state where a synchronization operation is already in progress.
/// This prevents multiple synchronization operations from running at the same time.
class AlreadyInProgress extends SyncState {
  /// Constructor for the "Already in progress" synchronization state.
  const AlreadyInProgress();
}

/// Represents a state where the system is fetching metadata from local storage.
/// This is typically the initial step in the synchronization process.
class FetchingLocalMetadata extends SyncState {
  /// Constructor for the "Fetching local metadata" synchronization state.
  const FetchingLocalMetadata();
}

/// Represents a state where the system is fetching metadata from the cloud.
/// This is used to compare cloud data with local data during the synchronization process.
class FetchingCloudMetadata extends SyncState {
  /// Constructor for the "Fetching cloud metadata" synchronization state.
  const FetchingCloudMetadata();
}

/// Represents a state where the system is checking the cloud for missing or outdated data.
/// This ensures that local storage is synchronized with the latest cloud data.
class CheckingCloudForMissingOrOutdatedData extends SyncState {
  /// Constructor for the "Checking cloud for missing or outdated data" synchronization state.
  const CheckingCloudForMissingOrOutdatedData();
}

/// Represents a state where the system is checking local storage for missing or outdated data.
/// This ensures that the cloud is synchronized with the latest local data.
class CheckingLocalForMissingOrOutdatedData extends SyncState {
  /// Constructor for the "Checking local for missing or outdated data" synchronization state.
  const CheckingLocalForMissingOrOutdatedData();
}

/// Represents a state where the system is writing metadata about a file to the cloud.
/// This state includes details about the file being uploaded.
class WritingDetailToCloud extends SyncState {
  /// Constructor for the "Writing detail to cloud" synchronization state.
  ///
  /// [metadata] contains information about the file being uploaded to the cloud.
  const WritingDetailToCloud(this.metadata);

  /// Metadata of the file being uploaded to the cloud.
  final SyncMetadata metadata;
}

/// Represents a state where the system is writing metadata about a file to local storage.
/// This state includes details about the file being saved locally.
class WritingDetailToLocal extends SyncState {
  /// Constructor for the "Writing detail to local" synchronization state.
  ///
  /// [metadata] contains information about the file being saved locally.
  const WritingDetailToLocal(this.metadata);

  /// Metadata of the file being saved locally.
  final SyncMetadata metadata;
}

/// Represents a state where the synchronization process has completed successfully.
/// This indicates the end of the synchronization operation without any errors.
class SynchronizationCompleted extends SyncState {
  /// Constructor for the "Synchronization completed" state.
  const SynchronizationCompleted();
}

/// Represents a state where an error occurred during the synchronization process.
/// This state includes details about the error and its associated stack trace.
class SynchronizationError extends SyncState implements Exception {
  /// Constructor for the "Synchronization error" state.
  ///
  /// [error] is the exception or error that occurred during synchronization.
  /// [stackTrace] provides the stack trace associated with the error.
  const SynchronizationError(this.error, this.stackTrace);

  /// The error that occurred during synchronization.
  final Object error;

  /// The stack trace associated with the error.
  final StackTrace stackTrace;
}
