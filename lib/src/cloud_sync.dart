import 'dart:async';

import 'package:cloud_sync/src/models/sync_adapter.dart';
import 'package:cloud_sync/src/models/sync_errors.dart';
import 'package:cloud_sync/src/models/sync_exceptions.dart';
import 'package:cloud_sync/src/models/sync_metadata.dart';
import 'package:cloud_sync/src/models/sync_state.dart';

/// Fetches a list of [SyncMetadata] from a data source.
typedef FetchMetadataList<M extends SyncMetadata> = Future<List<M>> Function();

/// Fetches a data object based on [SyncMetadata].
typedef FetchDetail<M extends SyncMetadata, D> = Future<D> Function(M metadata);

/// Saves a data object to a storage location.
typedef SaveDetail<M extends SyncMetadata, D> = Future<void> Function(
  M metadata,
  D detail,
);

/// Reports synchronization progress via a [SyncState].
typedef SyncProgressCallback<M extends SyncMetadata> = void Function(
  SyncState<M> state,
);

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

  /// Completer used to handle sync cancellation.
  Completer<void>? _cancellationCompleter;

  /// Whether this instance has been disposed.
  bool get isDisposed => _isDisposed;
  bool _isDisposed = false;

  /// Starts periodic auto-sync with the given [interval].
  ///
  /// Optionally provides [progressCallback] to report sync progress.
  /// If a sync is already in progress when the timer fires, that cycle is skipped.
  void autoSync({
    required Duration interval,
    SyncProgressCallback<M>? progressCallback,
  }) {
    if (_isDisposed) {
      throw SyncDisposedError.withMethodName('autoSync()');
    }

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

    // Cancel any ongoing sync operation
    cancelSync();
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
    if (_isDisposed) {
      throw SyncDisposedError.withMethodName('sync()');
    }

    bool progress(SyncState<M> Function() state) {
      if (progressCallback != null) {
        progressCallback(state());
        return true;
      }
      return false;
    }

    if (_isSyncInProgress) {
      progress(InProgress.new);
      return;
    }
    _isSyncInProgress = true;

    // Create a new cancellation completer for this sync operation
    _cancellationCompleter = Completer<void>();

    try {
      // Check if cancellation was requested before starting
      _checkCancellation();

      progress(FetchingLocalMetadata.new);
      final localMetadataList = await fetchLocalMetadataList();

      _checkCancellation();

      final localMetadataMap = {
        for (final metadata in localMetadataList) metadata.id: metadata,
      };

      progress(FetchingCloudMetadata.new);
      final cloudMetadataList = await fetchCloudMetadataList();

      _checkCancellation();

      final cloudMetadataMap = {
        for (final metadata in cloudMetadataList) metadata.id: metadata,
      };

      Future<void> processCloudSync() async {
        progress(ScanningCloud.new);
        for (final localMetadata in localMetadataList) {
          _checkCancellation();

          final cloudMetadata = cloudMetadataMap[localMetadata.id];
          final isMissingOrOutdated = cloudMetadata == null ||
              cloudMetadata.modifiedAt.isBefore(localMetadata.modifiedAt);

          if (isMissingOrOutdated) {
            progress(() => SavingToCloud(localMetadata));
            try {
              final localFile = await fetchLocalDetail(localMetadata);

              _checkCancellation();

              await saveToCloud(localMetadata, localFile);
              progress(() => SavedToCloud(localMetadata));
            } catch (error, stackTrace) {
              if (!progress(() => SyncError(error, stackTrace))) {
                rethrow;
              }
            }
          }
        }
      }

      Future<void> processLocalSync() async {
        progress(ScanningLocal.new);
        for (final cloudMetadata in cloudMetadataList) {
          _checkCancellation();

          final localMetadata = localMetadataMap[cloudMetadata.id];
          final isMissingOrOutdated = localMetadata == null ||
              localMetadata.modifiedAt.isBefore(cloudMetadata.modifiedAt);

          if (isMissingOrOutdated) {
            progress(() => SavingToLocal(cloudMetadata));
            try {
              final cloudFile = await fetchCloudDetail(cloudMetadata);

              _checkCancellation();

              await saveToLocal(cloudMetadata, cloudFile);
              progress(() => SavedToLocal(cloudMetadata));
            } catch (error, stackTrace) {
              if (!progress(() => SyncError(error, stackTrace))) {
                rethrow;
              }
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

      progress(SyncCompleted.new);
    } on SyncCancelledException {
      progress(SyncCancelled.new);
    } catch (error, stackTrace) {
      if (!progress(() => SyncError(error, stackTrace))) {
        rethrow;
      }
    } finally {
      _isSyncInProgress = false;
      _cancellationCompleter = null;
    }
  }

  /// Checks if cancellation was requested and throws if it was.
  ///
  /// This method should be called at strategic points during sync
  /// to allow for responsive cancellation.
  void _checkCancellation() {
    if (_cancellationCompleter != null && _cancellationCompleter!.isCompleted) {
      throw const SyncCancelledException();
    }

    if (_isDisposed) {
      throw const SyncCancelledException();
    }
  }

  /// Cancels any ongoing sync operation.
  ///
  /// Returns true if there was an operation to cancel, false otherwise.
  bool cancelSync() {
    if (_cancellationCompleter != null &&
        !_cancellationCompleter!.isCompleted) {
      _cancellationCompleter!.complete();
      return true;
    }
    return false;
  }

  /// Disposes resources used by this instance.
  ///
  /// This method:
  /// 1. Stops any auto-sync processes
  /// 2. Cancels any ongoing synchronization
  /// 3. Marks the instance as disposed
  ///
  /// After calling this method, the instance should not be used anymore.
  /// Attempting to call methods on a disposed instance will result in
  /// a [SyncDisposedError] being thrown.
  void dispose() {
    if (_isDisposed) {
      return; // Already disposed
    }

    // Stop auto-sync and cancel any ongoing sync
    stopAutoSync();

    // Mark as disposed
    _isDisposed = true;
  }
}
