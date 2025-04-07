library;

import 'dart:async';

import 'models/sync_adapter.dart';
import 'models/sync_metadata.dart';
import 'models/sync_state.dart';

/// Fetches a list of [SyncMetadata] from a data source.
typedef FetchMetadataList<M extends SyncMetadata> = Future<List<M>> Function();

/// Fetches a data object based on [SyncMetadata].
typedef FetchDetail<M extends SyncMetadata, D> = Future<D> Function(M metadata);

/// Saves a data object to a storage location.
typedef SaveDetail<M extends SyncMetadata, D> = Future<void> Function(
    M metadata, D detail);

/// Reports synchronization progress via a [SyncState].
typedef SyncProgressCallback<M extends SyncMetadata> = void Function(
    SyncState<M> state);

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
    required this.saveToLocal,
    required this.saveToCloud,
  });

  /// Creates a [CloudSync] instance from the given [SyncAdapter]s.
  ///
  /// This factory simplifies creating a [CloudSync] by accepting adapters
  /// for local and cloud storage. Each adapter supplies the necessary
  /// fetch and save functions for synchronization.
  factory CloudSync.fromAdapters(
    SyncAdapter<M, D> localAdapter,
    SyncAdapter<M, D> cloudAdapter,
  ) {
    return CloudSync<M, D>(
      fetchLocalMetadataList: localAdapter.fetchMetadataList,
      fetchCloudMetadataList: cloudAdapter.fetchMetadataList,
      fetchLocalDetail: localAdapter.fetchDetail,
      fetchCloudDetail: cloudAdapter.fetchDetail,
      saveToLocal: localAdapter.save,
      saveToCloud: cloudAdapter.save,
    );
  }

  /// Fetches metadata from local storage.
  final FetchMetadataList<M> fetchLocalMetadataList;

  /// Fetches metadata from cloud storage.
  final FetchMetadataList<M> fetchCloudMetadataList;

  /// Fetches a data object from local storage based on metadata.
  final FetchDetail<M, D> fetchLocalDetail;

  /// Fetches a data object from cloud storage based on metadata.
  final FetchDetail<M, D> fetchCloudDetail;

  /// Saves a data object to local storage.
  final SaveDetail<M, D> saveToLocal;

  /// Saves a data object to cloud storage.
  final SaveDetail<M, D> saveToCloud;

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
    SyncProgressCallback<M>? progressCallback,
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

  /// Initiates a full synchronization process between local and cloud storage.
  ///
  /// This method performs the following steps:
  /// 1. Retrieves metadata from both local and cloud storage to identify any discrepancies.
  /// 2. Compares the metadata to determine which files are missing or outdated in either location.
  /// 3. Uploads any missing or updated files from the local storage to the cloud.
  /// 4. Downloads any missing or updated files from the cloud to local storage.
  ///
  /// Optionally, progress updates can be provided via the [progressCallback], which
  /// receives a [SyncState] representing the current synchronization state.
  /// In case of an error during synchronization, the error is reported using the
  /// [SyncError] state (if the callback is provided) or rethrown to the caller.
  ///
  /// If [useConcurrentSync] is set to `true`, the synchronization of local and cloud storage
  /// will run concurrently. Otherwise, they will be processed sequentially.
  Future<void> sync({
    SyncProgressCallback<M>? progressCallback,
    bool useConcurrentSync = false,
  }) async {
    void progress(SyncState<M> Function() state) {
      if (progressCallback != null) {
        progressCallback(state());
      }
    }

    if (_isSyncInProgress) {
      progress(() => InProgress());
      return;
    }
    _isSyncInProgress = true;

    try {
      progress(() => FetchingLocalMetadata());
      final localMetadataList = await fetchLocalMetadataList();
      final localMetadataMap = {
        for (var metadata in localMetadataList) metadata.id: metadata,
      };

      progress(() => FetchingCloudMetadata());
      final cloudMetadataList = await fetchCloudMetadataList();
      final cloudMetadataMap = {
        for (var metadata in cloudMetadataList) metadata.id: metadata,
      };

      Future<void> processCloudSync() async {
        progress(() => ScanningCloud());
        for (final localMetadata in localMetadataList) {
          final cloudMetadata = cloudMetadataMap[localMetadata.id];
          final isMissingOrOutdated = cloudMetadata == null ||
              cloudMetadata.modifiedAt.isBefore(localMetadata.modifiedAt);

          if (isMissingOrOutdated) {
            progress(() => SavingToCloud(localMetadata));
            try {
              final localFile = await fetchLocalDetail(localMetadata);
              await saveToCloud(localMetadata, localFile);
              progress(() => SavedToCloud(localMetadata));
            } catch (e, stackTrace) {
              progress(() => SyncError(e, stackTrace));
            }
          }
        }
      }

      Future<void> processLocalSync() async {
        progress(() => ScanningLocal());
        for (final cloudMetadata in cloudMetadataList) {
          final localMetadata = localMetadataMap[cloudMetadata.id];
          final isMissingOrOutdated = localMetadata == null ||
              localMetadata.modifiedAt.isBefore(cloudMetadata.modifiedAt);

          if (isMissingOrOutdated) {
            progress(() => SavingToLocal(cloudMetadata));
            try {
              final cloudFile = await fetchCloudDetail(cloudMetadata);
              await saveToLocal(cloudMetadata, cloudFile);
              progress(() => SavedToLocal(cloudMetadata));
            } catch (e, stackTrace) {
              progress(() => SyncError(e, stackTrace));
            }
          }
        }
      }

      if (useConcurrentSync) {
        await Future.wait([
          processLocalSync(),
          processCloudSync(),
        ]);
      } else {
        await processLocalSync();
        await processCloudSync();
      }

      progress(() => SyncCompleted());
    } catch (error, stackTrace) {
      if (progressCallback != null) {
        progressCallback(SyncError(error, stackTrace));
      } else {
        rethrow;
      }
    } finally {
      _isSyncInProgress = false;
    }
  }
}
