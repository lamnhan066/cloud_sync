import 'package:cloud_sync/src/models/sync_metadata.dart';

/// Base class representing the state of a synchronization process.
/// This serves as the foundation for all specific synchronization states.
sealed class SyncState<M extends SyncMetadata> {
  /// Creates a base synchronization state.
  const SyncState();
}

/// Represents a state where a synchronization operation is already in progress.
/// Prevents multiple synchronization operations from running simultaneously.
class AlreadyInProgress<M extends SyncMetadata> extends SyncState<M> {
  /// Creates an "Already in progress" synchronization state.
  const AlreadyInProgress();
}

/// Represents a state where the system is fetching metadata from local storage.
/// Typically the initial step in the synchronization process.
class FetchingLocalMetadata<M extends SyncMetadata> extends SyncState<M> {
  /// Creates a "Fetching local metadata" synchronization state.
  const FetchingLocalMetadata();
}

/// Represents a state where the system is fetching metadata from the cloud.
/// Used to compare cloud data with local data during synchronization.
class FetchingCloudMetadata<M extends SyncMetadata> extends SyncState<M> {
  /// Creates a "Fetching cloud metadata" synchronization state.
  const FetchingCloudMetadata();
}

/// Represents a state where the system is checking the cloud for missing or outdated data.
/// Ensures that local storage is synchronized with the latest cloud data.
class CheckingCloudForMissingOrOutdatedData<M extends SyncMetadata>
    extends SyncState<M> {
  /// Creates a "Checking cloud for missing or outdated data" synchronization state.
  const CheckingCloudForMissingOrOutdatedData();
}

/// Represents a state where the system is checking local storage for missing or outdated data.
/// Ensures that the cloud is synchronized with the latest local data.
class CheckingLocalForMissingOrOutdatedData<M extends SyncMetadata>
    extends SyncState<M> {
  /// Creates a "Checking local for missing or outdated data" synchronization state.
  const CheckingLocalForMissingOrOutdatedData();
}

/// Represents a state where the system is writing metadata about a file to the cloud.
/// Includes details about the file being uploaded.
class WritingDetailToCloud<M extends SyncMetadata> extends SyncState<M> {
  /// Creates a "Writing detail to cloud" synchronization state.
  ///
  /// [metadata] contains information about the file being uploaded to the cloud.
  const WritingDetailToCloud(this.metadata);

  /// Metadata of the file being uploaded to the cloud.
  final M metadata;
}

/// Represents a state where the system is writing metadata about a file to local storage.
/// Includes details about the file being saved locally.
class WritingDetailToLocal<M extends SyncMetadata> extends SyncState<M> {
  /// Creates a "Writing detail to local" synchronization state.
  ///
  /// [metadata] contains information about the file being saved locally.
  const WritingDetailToLocal(this.metadata);

  /// Metadata of the file being saved locally.
  final M metadata;
}

/// Represents a state where the synchronization process has completed successfully.
/// Indicates the end of the synchronization operation without any errors.
@Deprecated('Use `SynchronizationCompleted` instead')
typedef SynchronizationCompleted<M extends SyncMetadata> = SyncCompleted<M>;

/// Represents a state where the synchronization process has completed successfully.
/// Indicates the end of the synchronization operation without any errors.
class SyncCompleted<M extends SyncMetadata> extends SyncState<M> {
  /// Creates a "Synchronization completed" state.
  const SyncCompleted();
}

/// Represents a state where an error occurred during the synchronization process.
/// Includes details about the error and its associated stack trace.
@Deprecated('Use `SyncError` instead')
typedef SynchronizationError<M extends SyncMetadata> = SyncError<M>;

/// Represents a state where an error occurred during the synchronization process.
/// Includes details about the error and its associated stack trace.
class SyncError<M extends SyncMetadata> extends SyncState<M>
    implements Exception {
  /// Creates a "Synchronization error" state.
  ///
  /// [error] is the exception or error that occurred during synchronization.
  /// [stackTrace] provides the stack trace associated with the error.
  const SyncError(this.error, this.stackTrace);

  /// The error that occurred during synchronization.
  final Object error;

  /// The stack trace associated with the error.
  final StackTrace stackTrace;
}
