library;

import 'dart:async';

import 'models/sync_metadata.dart';
import 'models/sync_state.dart';

/// Fetches a list of [SyncMetadata] from a data source.
typedef FetchMetadataList<M extends SyncMetadata> = Future<List<M>> Function();

/// Fetches a data object based on [SyncMetadata].
typedef FetchDetail<M extends SyncMetadata, D> = Future<D> Function(M metadata);

/// Writes a data object to a storage location.
typedef WriteDetail<M extends SyncMetadata, D> = Future<void> Function(
    M metadata, D detail);

/// Reports synchronization progress via a [SyncState].
typedef SyncProgressCallback = void Function(SyncState state);

/// Handles synchronization between local and cloud storage.
///
/// This class compares metadata from local and cloud storage and transfers
/// missing or outdated data in both directions.
class CloudSync<M extends SyncMetadata, D> {
  /// Creates a [CloudSync] instance.
  ///
  /// Requires fetch and write functions for both local and cloud storage.
  CloudSync({
    required this.fetchLocalMetadataList,
    required this.fetchCloudMetadataList,
    required this.fetchLocalDetail,
    required this.fetchCloudDetail,
    required this.writeDetailToLocal,
    required this.writeDetailToCloud,
  });

  /// Fetches metadata from local storage.
  final FetchMetadataList<M> fetchLocalMetadataList;

  /// Fetches metadata from cloud storage.
  final FetchMetadataList<M> fetchCloudMetadataList;

  /// Fetches a data object from local storage based on metadata.
  final FetchDetail<M, D> fetchLocalDetail;

  /// Fetches a data object from cloud storage based on metadata.
  final FetchDetail<M, D> fetchCloudDetail;

  /// Writes a data object to local storage.
  final WriteDetail<M, D> writeDetailToLocal;

  /// Writes a data object to cloud storage.
  final WriteDetail<M, D> writeDetailToCloud;

  /// Indicates whether a synchronization process is currently in progress.
  bool _isSyncInProgress = false;

  /// Timer used to trigger auto-sync periodically.
  Timer? _autoSyncTimer;

  /// Starts periodic auto-sync with the given [interval].
  ///
  /// Optionally provides [progressCallback] to report sync progress.
  /// If a sync is already in progress when the timer fires, that cycle is skipped.
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
  /// Cancels the timer and resets internal state.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Performs a full synchronization between local and cloud storage.
  ///
  /// Steps:
  /// 1. Fetches metadata from both local and cloud storage.
  /// 2. Identifies missing or outdated files in both locations.
  /// 3. Uploads local changes to the cloud.
  /// 4. Downloads cloud changes to local storage.
  ///
  /// Optionally reports progress via [progressCallback].
  /// If an error occurs during synchronization, it is reported via the callback and rethrown.
  Future<void> sync({SyncProgressCallback? progressCallback}) async {
    if (_isSyncInProgress) {
      progressCallback?.call(AlreadyInProgress());
      return;
    }
    _isSyncInProgress = true;

    try {
      // Step 1: Fetch metadata from local storage.
      progressCallback?.call(FetchingLocalMetadata());
      final localMetadataList = await fetchLocalMetadataList();
      final localMetadataMap = {
        for (var metadata in localMetadataList) metadata.id: metadata,
      };

      // Step 2: Fetch metadata from cloud storage.
      progressCallback?.call(FetchingCloudMetadata());
      final cloudMetadataList = await fetchCloudMetadataList();
      final cloudMetadataMap = {
        for (var metadata in cloudMetadataList) metadata.id: metadata,
      };

      // Step 3: Upload missing or outdated files to the cloud.
      progressCallback?.call(CheckingCloudForMissingOrOutdatedData());
      for (final localMetadata in localMetadataList) {
        final cloudMetadata = cloudMetadataMap[localMetadata.id];
        final isMissingOrOutdated = cloudMetadata == null ||
            cloudMetadata.modifiedAt.isBefore(localMetadata.modifiedAt);

        if (isMissingOrOutdated) {
          progressCallback?.call(WritingDetailToCloud(localMetadata));
          try {
            final localFile = await fetchLocalDetail(localMetadata);
            await writeDetailToCloud(localMetadata, localFile);
          } catch (e, stackTrace) {
            progressCallback?.call(SynchronizationError(e, stackTrace));
          }
        }
      }

      // Step 4: Download missing or outdated files to local storage.
      progressCallback?.call(CheckingLocalForMissingOrOutdatedData());
      for (final cloudMetadata in cloudMetadataList) {
        final localMetadata = localMetadataMap[cloudMetadata.id];
        final isMissingOrOutdated = localMetadata == null ||
            localMetadata.modifiedAt.isBefore(cloudMetadata.modifiedAt);

        if (isMissingOrOutdated) {
          progressCallback?.call(WritingDetailToLocal(cloudMetadata));
          try {
            final cloudFile = await fetchCloudDetail(cloudMetadata);
            await writeDetailToLocal(cloudMetadata, cloudFile);
          } catch (e, stackTrace) {
            progressCallback?.call(SynchronizationError(e, stackTrace));
          }
        }
      }

      // Step 5: Notify that synchronization completed successfully.
      progressCallback?.call(SynchronizationCompleted());
    } catch (error, stackTrace) {
      progressCallback?.call(SynchronizationError(error, stackTrace));
      rethrow;
    } finally {
      _isSyncInProgress = false;
    }
  }
}
