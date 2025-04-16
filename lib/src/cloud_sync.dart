import 'dart:async';

import 'package:cloud_sync/src/models/sync_adapter.dart';
import 'package:cloud_sync/src/models/sync_errors.dart';
import 'package:cloud_sync/src/models/sync_exceptions.dart';
import 'package:cloud_sync/src/models/sync_state.dart';

/// A function type that retrieves a unique identifier for a given metadata object.
typedef GetMetadataId<M> = String Function(M metadata);

/// A function type that compares two metadata objects to determine their order.
typedef MetadataComparator<M> = FutureOr<bool> Function(M current, M other);

/// A function type that fetches a list of metadata objects from a data source.
typedef FetchMetadataList<M> = FutureOr<List<M>> Function();

/// A function type that fetches a detailed data object based on metadata.
typedef FetchDetail<M, D> = FutureOr<D> Function(M metadata);

/// A function type that saves a detailed data object to a storage location.
typedef SaveDetail<M, D> = FutureOr<void> Function(M metadata, D detail);

/// A function type that reports synchronization progress via a [SyncState].
typedef SyncProgressCallback<M> = void Function(SyncState<M> state);

/// Handles synchronization between local and cloud storage.
///
/// This class facilitates the synchronization of data between local and cloud storage
/// by comparing metadata and transferring missing or outdated data in both directions.
class CloudSync<M, D> {
  /// Creates a [CloudSync] instance.
  ///
  /// Requires functions for fetching, comparing, and saving data for both local and cloud storage.
  CloudSync._({
    required this.getLocalMetadataId,
    required this.getCloudMetadataId,
    required this.isLocalMetadataBeforeCloud,
    required this.isCloudMetadataBeforeLocal,
    required this.fetchLocalMetadataList,
    required this.fetchCloudMetadataList,
    required this.fetchLocalDetail,
    required this.fetchCloudDetail,
    required this.saveToLocal,
    required this.saveToCloud,
    this.shouldThrowOnError = false,
  });

  /// Creates a [CloudSync] instance using the provided [SyncAdapter]s.
  ///
  /// This factory method simplifies the creation of a [CloudSync] instance
  /// by accepting adapters for both local and cloud storage. Each adapter
  /// provides the required fetch and save functions needed for synchronization.
  ///
  /// - [local]: The adapter for local storage.
  /// - [cloud]: The adapter for cloud storage.
  /// - [shouldThrowOnError]: If `true`, exceptions during synchronization will
  ///   be thrown to the caller. If `false`, errors will be reported via
  ///   [SyncProgressCallback] using the [SyncError] state and the sync process
  ///   will continue.
  factory CloudSync.fromAdapters({
    required SyncAdapter<M, D> local,
    required SyncAdapter<M, D> cloud,
    bool shouldThrowOnError = false,
  }) {
    return CloudSync<M, D>._(
      getLocalMetadataId: local.getMetadataId,
      getCloudMetadataId: cloud.getMetadataId,
      isLocalMetadataBeforeCloud: local.isCurrentMetadataBeforeOther,
      isCloudMetadataBeforeLocal: cloud.isCurrentMetadataBeforeOther,
      fetchLocalMetadataList: local.fetchMetadataList,
      fetchCloudMetadataList: cloud.fetchMetadataList,
      fetchLocalDetail: local.fetchDetail,
      fetchCloudDetail: cloud.fetchDetail,
      saveToLocal: local.save,
      saveToCloud: cloud.save,
      shouldThrowOnError: shouldThrowOnError,
    );
  }

  /// Function to get the unique identifier for local metadata.
  final GetMetadataId<M> getLocalMetadataId;

  /// Function to get the unique identifier for cloud metadata.
  final GetMetadataId<M> getCloudMetadataId;

  /// Function to determine if local metadata is newer than cloud metadata.
  final MetadataComparator<M> isLocalMetadataBeforeCloud;

  /// Function to determine if cloud metadata is newer than local metadata.
  final MetadataComparator<M> isCloudMetadataBeforeLocal;

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

  /// Configures the behavior for handling synchronization errors.
  ///
  /// When set to `true`, any error encountered during the synchronization process
  /// will be thrown to the caller, halting the sync operation.
  /// When set to `false`, errors will be reported via the [SyncProgressCallback]
  /// using the [SyncError] state, allowing the synchronization process to proceed
  /// despite the errors.
  final bool shouldThrowOnError;

  /// Indicates whether a synchronization process is currently in progress.
  bool _isSyncInProgress = false;

  /// Timer used to trigger auto-sync periodically.
  Timer? _autoSyncTimer;

  /// Completer used to handle sync cancellation.
  Completer<void>? _cancellationCompleter;

  /// Indicates whether the sync process should be cancelled.
  bool _needToCancel = false;

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

    // Cancel any existing auto-sync timer before starting a new one.
    _autoSyncTimer?.cancel();

    // Start a periodic timer to trigger synchronization at the specified interval.
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      await sync(progress: progressCallback);
    });
  }

  /// Stops the auto-sync process.
  ///
  /// Cancels the timer and resets internal state.
  Future<void> stopAutoSync() async {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;

    // Cancel any ongoing sync operation.
    await cancelSync();
  }

  /// Initiates a full synchronization process between local and cloud storage.
  ///
  /// This method performs the following steps:
  /// 1. Retrieves metadata from both local and cloud storage to identify any discrepancies.
  /// 2. Compares the metadata to determine which files are missing or outdated in either location.
  /// 3. Uploads any missing or updated files from the local storage to the cloud.
  /// 4. Downloads any missing or updated files from the cloud to local storage.
  ///
  /// Optionally, progress updates can be provided via the [progress], which
  /// receives a [SyncState] representing the current synchronization state.
  /// In case of an error during synchronization, the error is reported using the
  /// [SyncError] state (if the callback is provided) or rethrown to the caller.
  ///
  /// If [useConcurrentSync] is set to `true`, the synchronization of local and cloud storage
  /// will run concurrently. Otherwise, they will be processed sequentially.
  Future<void> sync({
    SyncProgressCallback<M>? progress,
    bool useConcurrentSync = false,
  }) async {
    if (_isDisposed) {
      throw SyncDisposedError.withMethodName('sync()');
    }

    // Helper function to report progress if a callback is provided.
    bool updateProgress(SyncState<M> Function() state) {
      if (progress != null) {
        progress(state());
        return true;
      }
      return false;
    }

    try {
      // Prevent multiple sync operations from running simultaneously.
      if (_isSyncInProgress) {
        updateProgress(InProgress.new);
        return;
      }

      _isSyncInProgress = true;
      _cancellationCompleter = Completer<void>();
      _needToCancel = false;

      _checkCancellation();

      // Fetch metadata from local storage.
      updateProgress(FetchingLocalMetadata.new);
      final localMetadataList = await fetchLocalMetadataList();

      _checkCancellation();

      // Map local metadata by their unique identifiers.
      final localMetadataMap = {
        for (final metadata in localMetadataList)
          getLocalMetadataId(metadata): metadata,
      };

      // Fetch metadata from cloud storage.
      updateProgress(FetchingCloudMetadata.new);
      final cloudMetadataList = await fetchCloudMetadataList();

      _checkCancellation();

      // Map cloud metadata by their unique identifiers.
      final cloudMetadataMap = {
        for (final metadata in cloudMetadataList)
          getCloudMetadataId(metadata): metadata,
      };

      // Process synchronization from local to cloud.
      Future<void> processCloudSync() async {
        updateProgress(ScanningCloud.new);
        for (final localMetadata in localMetadataList) {
          _checkCancellation();

          final cloudMetadata =
              cloudMetadataMap[getLocalMetadataId(localMetadata)];
          final isMissingOrOutdated = cloudMetadata == null ||
              await isCloudMetadataBeforeLocal(cloudMetadata, localMetadata);

          if (isMissingOrOutdated) {
            updateProgress(() => SavingToCloud(localMetadata));
            try {
              final localFile = await fetchLocalDetail(localMetadata);

              _checkCancellation();

              await saveToCloud(localMetadata, localFile);
              updateProgress(() => SavedToCloud(localMetadata));
            } catch (error, stackTrace) {
              if (!updateProgress(() => SyncError(error, stackTrace))) {
                rethrow;
              }
            }
          }
        }
      }

      // Process synchronization from cloud to local.
      Future<void> processLocalSync() async {
        updateProgress(ScanningLocal.new);
        for (final cloudMetadata in cloudMetadataList) {
          _checkCancellation();

          final localMetadata =
              localMetadataMap[getCloudMetadataId(cloudMetadata)];
          final isMissingOrOutdated = localMetadata == null ||
              await isLocalMetadataBeforeCloud(localMetadata, cloudMetadata);

          if (isMissingOrOutdated) {
            updateProgress(() => SavingToLocal(cloudMetadata));
            try {
              final cloudFile = await fetchCloudDetail(cloudMetadata);

              _checkCancellation();

              await saveToLocal(cloudMetadata, cloudFile);
              updateProgress(() => SavedToLocal(cloudMetadata));
            } catch (error, stackTrace) {
              if (!updateProgress(() => SyncError(error, stackTrace))) {
                rethrow;
              }
            }
          }
        }
      }

      // Run synchronization tasks concurrently or sequentially based on the flag.
      if (useConcurrentSync) {
        await Future.wait([
          processLocalSync(),
          processCloudSync(),
        ]);
      } else {
        await processLocalSync();
        await processCloudSync();
      }

      updateProgress(SyncCompleted.new);
    } on SyncCancelledException {
      updateProgress(SyncCancelled.new);

      if (_cancellationCompleter != null &&
          !_cancellationCompleter!.isCompleted) {
        _cancellationCompleter!.complete();
      }
    } catch (error, stackTrace) {
      updateProgress(() => SyncError(error, stackTrace));
      if (shouldThrowOnError) rethrow;
    } finally {
      _isSyncInProgress = false;
      _cancellationCompleter = null;
      _needToCancel = false;
    }
  }

  /// Checks if cancellation was requested and throws if it was.
  ///
  /// This method should be called at strategic points during sync
  /// to allow for responsive cancellation.
  void _checkCancellation() {
    if (_needToCancel || _isDisposed) {
      throw const SyncCancelledException();
    }
  }

  /// Cancels any ongoing sync operation and waits until it's finished.
  Future<void> cancelSync() async {
    if (_needToCancel) return;
    if (_cancellationCompleter == null) return;
    if (_cancellationCompleter!.isCompleted) return;

    _needToCancel = true;
    await _cancellationCompleter!.future;
  }

  /// Disposes resources used by this instance.
  ///
  /// This method:
  /// 1. Stops any auto-sync processes.
  /// 2. Cancels any ongoing synchronization.
  /// 3. Marks the instance as disposed.
  ///
  /// After calling this method, the instance should not be used anymore.
  /// Attempting to call methods on a disposed instance will result in
  /// a [SyncDisposedError] being thrown.
  Future<void> dispose() async {
    if (_isDisposed) {
      return; // Already disposed
    }

    // Stop auto-sync and cancel any ongoing sync.
    await stopAutoSync();

    // Mark as disposed.
    _isDisposed = true;
  }
}
