import 'package:cloud_sync/cloud_sync.dart';

/// Defines a synchronization adapter for a specific data source.
///
/// This abstract class serves as an interface for fetching and writing
/// synchronized data. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data linked to the metadata.
abstract class SyncAdapter<M extends SyncMetadata, D> {
  /// Retrieves a list of metadata items available for synchronization.
  ///
  /// Returns a [Future] that resolves to a list of metadata of type `M`.
  Future<List<M>> fetchMetadataList();

  /// Fetches the detailed data associated with the given [metadata] item.
  ///
  /// Returns a [Future] that resolves to a detail object of type `D`.
  Future<D> fetchDetail(M metadata);

  /// Saves the provided [metadata] and its associated [detail] to the data source.
  ///
  /// Returns a [Future] that completes when the save operation is finished.
  Future<void> save(M metadata, D detail);
}
