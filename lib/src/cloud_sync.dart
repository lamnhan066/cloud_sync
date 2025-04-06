library;

import 'dart:async';

import 'models/sync_file.dart';
import 'models/sync_metadata.dart';
import 'models/sync_state.dart';

/// Type definition for a function that fetches a list of metadata.
typedef FetchMetadataList = Future<List<SyncMetadata>> Function();

/// Type definition for a function that fetches a file based on metadata.
typedef FetchFileByMetadata = Future<SyncFile> Function(SyncMetadata metadata);

/// Type definition for a function that writes a file to a storage.
typedef WriteFileToStorage = Future<void> Function(
    SyncMetadata metadata, SyncFile file);

/// Type definition for a callback function to report synchronization progress.
typedef SyncProgressCallback = void Function(SyncState state);

/// A class to handle synchronization between local and cloud storage.
class CloudSync {
  /// Creates an instance of the [CloudSync] class.
  ///
  /// Requires functions for fetching metadata and files from both local and cloud storage,
  /// as well as functions for writing files to local and cloud storage.
  CloudSync({
    required this.fetchLocalMetadataList,
    required this.fetchCloudMetadataList,
    required this.fetchLocalFileByMetadata,
    required this.fetchCloudFileByMetadata,
    required this.writeFileToLocalStorage,
    required this.writeFileToCloudStorage,
  });

  /// Function to fetch metadata from the local storage.
  final FetchMetadataList fetchLocalMetadataList;

  /// Function to fetch metadata from the cloud storage.
  final FetchMetadataList fetchCloudMetadataList;

  /// Function to fetch a file from the local storage based on metadata.
  final FetchFileByMetadata fetchLocalFileByMetadata;

  /// Function to fetch a file from the cloud storage based on metadata.
  final FetchFileByMetadata fetchCloudFileByMetadata;

  /// Function to save a file to the local storage.
  final WriteFileToStorage writeFileToLocalStorage;

  /// Function to save a file to the cloud storage.
  final WriteFileToStorage writeFileToCloudStorage;

  /// A flag indicating whether a synchronization operation is currently in progress.
  bool _isSyncInProgress = false;

  // Timer to periodically trigger auto-sync.
  Timer? _autoSyncTimer;

  /// Starts the auto-sync process with a specified [interval].
  ///
  /// The [interval] determines how often the synchronization process is triggered.
  /// An optional [progressCallback] can be provided to report the synchronization progress.
  ///
  /// **Note:** If a sync is already in progress when the timer fires, that sync attempt
  /// will be skipped and not retried.
  void autoSync({
    required Duration interval,
    SyncProgressCallback? progressCallback,
  }) {
    _autoSyncTimer?.cancel();

    _autoSyncTimer = Timer.periodic(interval, (_) async {
      await sync(progressCallback: progressCallback);
    });
  }

  /// Stops the auto-sync process.
  ///
  /// Cancels the periodic timer and resets the auto-sync state.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Performs the synchronization process between local and cloud storage.
  ///
  /// This method fetches metadata from both local and cloud storage, compares them,
  /// and ensures that missing or outdated files are synchronized in both directions.
  ///
  /// An optional [progressCallback] can be provided to report the synchronization progress.
  ///
  /// **Error Handling:** If any unhandled error occurs during the entire synchronization process,
  /// it is rethrown after reporting to the [progressCallback].
  Future<void> sync({SyncProgressCallback? progressCallback}) async {
    if (_isSyncInProgress) {
      progressCallback?.call(AlreadyInProgress());
      return;
    }
    _isSyncInProgress = true;

    try {
      // Step 1: Fetch metadata from the local storage.
      progressCallback?.call(FetchingLocalMetadata());
      final localMetadataList = await fetchLocalMetadataList();
      final localMetadataMap = {
        for (var metadata in localMetadataList) metadata.id: metadata,
      };

      // Step 2: Fetch metadata from the cloud storage.
      progressCallback?.call(FetchingCloudMetadata());
      final cloudMetadataList = await fetchCloudMetadataList();
      final cloudMetadataMap = {
        for (var metadata in cloudMetadataList) metadata.id: metadata,
      };

      // Step 3: Synchronize missing or outdated files to the cloud.
      progressCallback?.call(CheckingCloudForMissingOrOutdatedFiles());
      for (final localMetadata in localMetadataList) {
        final cloudMetadata = cloudMetadataMap[localMetadata.id];
        final isMissingOrOutdated = cloudMetadata == null ||
            cloudMetadata.modifiedAt.isBefore(localMetadata.modifiedAt);

        if (isMissingOrOutdated) {
          progressCallback?.call(SavingFileToCloud(localMetadata));
          try {
            final localFile = await fetchLocalFileByMetadata(localMetadata);
            await writeFileToCloudStorage(localMetadata, localFile);
          } catch (e, stackTrace) {
            progressCallback?.call(SynchronizationError(e, stackTrace));
          }
        }
      }

      // Step 4: Synchronize missing or outdated files to the local storage.
      progressCallback?.call(CheckingLocalForMissingOrOutdatedFiles());
      for (final cloudMetadata in cloudMetadataList) {
        final localMetadata = localMetadataMap[cloudMetadata.id];
        final isMissingOrOutdated = localMetadata == null ||
            localMetadata.modifiedAt.isBefore(cloudMetadata.modifiedAt);

        if (isMissingOrOutdated) {
          progressCallback?.call(SavingFileToLocal(cloudMetadata));
          try {
            final cloudFile = await fetchCloudFileByMetadata(cloudMetadata);
            await writeFileToLocalStorage(cloudMetadata, cloudFile);
          } catch (e, stackTrace) {
            progressCallback?.call(SynchronizationError(e, stackTrace));
          }
        }
      }

      // Step 5: Notify that the synchronization process has completed successfully.
      progressCallback?.call(SynchronizationCompleted());
    } catch (error, stackTrace) {
      progressCallback?.call(SynchronizationError(error, stackTrace));
      rethrow;
    } finally {
      _isSyncInProgress = false;
    }
  }
}
