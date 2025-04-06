import 'package:cloud_sync/src/models/sync_metadata.dart';

/// Base class representing the state of a synchronization process.
/// This serves as the foundation for all specific sync states.
sealed class SyncState {
  /// Default constructor for the base sync state.
  const SyncState();
}

/// State indicating that a synchronization operation is already in progress.
/// This prevents multiple sync operations from running simultaneously.
class AlreadyInProgress extends SyncState {
  /// Default constructor for the "Sync already in progress" state.
  const AlreadyInProgress();
}

/// State indicating that the system is currently fetching metadata from the local storage.
/// This is typically the first step in the synchronization process.
class FetchingLocalMetadata extends SyncState {
  /// Default constructor for the "Fetching local metadata" state.
  const FetchingLocalMetadata();
}

/// State indicating that the system is currently fetching metadata from the cloud.
/// This is used to compare cloud data with local data during synchronization.
class FetchingCloudMetadata extends SyncState {
  /// Default constructor for the "Fetching cloud metadata" state.
  const FetchingCloudMetadata();
}

/// State indicating that the system is checking the cloud for files that are missing
/// or outdated compared to the local storage.
class CheckingCloudForMissingOrOutdatedFiles extends SyncState {
  /// Default constructor for the "Checking cloud for missing or outdated files" state.
  const CheckingCloudForMissingOrOutdatedFiles();
}

/// State indicating that the system is checking the local storage for files that are missing
/// or outdated compared to the cloud.
class CheckingLocalForMissingOrOutdatedFiles extends SyncState {
  /// Default constructor for the "Checking local for missing or outdated files" state.
  const CheckingLocalForMissingOrOutdatedFiles();
}

/// State indicating that a file is currently being uploaded to the cloud.
/// This state includes metadata about the file being uploaded.
class SavingFileToCloud extends SyncState {
  /// Constructor for the "Uploading file to cloud" state.
  ///
  /// [metadata] contains information about the file being uploaded.
  const SavingFileToCloud(this.metadata);

  /// Metadata of the file being uploaded to the cloud.
  final SyncMetadata metadata;
}

/// State indicating that a file is currently being saved to the local storage.
/// This state includes metadata about the file being saved.
class SavingFileToLocal extends SyncState {
  /// Constructor for the "Saving file locally" state.
  ///
  /// [metadata] contains information about the file being saved locally.
  const SavingFileToLocal(this.metadata);

  /// Metadata of the file being saved locally.
  final SyncMetadata metadata;
}

/// State indicating that the synchronization process has completed successfully.
/// This state signifies the end of the sync operation without any errors.
class SynchronizationCompleted extends SyncState {
  /// Default constructor for the "Synchronization completed" state.
  const SynchronizationCompleted();
}

/// State representing an error that occurred during the synchronization process.
/// This state includes details about the error and its associated stack trace.
class SynchronizationError extends SyncState implements Exception {
  /// Constructor for the "Synchronization error" state.
  ///
  /// [error] is the exception or error that occurred.
  /// [stackTrace] provides the stack trace associated with the error.
  const SynchronizationError(this.error, this.stackTrace);

  /// The error that occurred during synchronization.
  final Object error;

  /// The stack trace associated with the error.
  final Object stackTrace;
}
