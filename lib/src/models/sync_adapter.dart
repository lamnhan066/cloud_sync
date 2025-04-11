import 'package:cloud_sync/cloud_sync.dart';

/// Defines a synchronization adapter for a specific data source.
///
/// This abstract class serves as an interface for fetching and writing
/// synchronized data. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data linked to the metadata.
abstract class SyncAdapter<M extends SyncMetadata, D> {
  /// Constructs a new instance of [SyncAdapter].
  const SyncAdapter();

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

/// Defines a synchronization adapter for a specific data source that can be serialized.
///
/// This abstract class extends [SyncAdapter] and adds methods for converting
/// metadata objects to and from JSON strings. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data linked to the metadata.
///
/// This class is useful for scenarios where the metadata need to be serialized
/// for storage or transmission, such as in a database or over a network.
abstract class SerializableSyncAdapter<M extends SyncMetadata, D>
    extends SyncAdapter<M, D> {
  /// Constructs a new instance of [SerializableSyncAdapter].
  ///
  /// - [metadataToJson]: A function that converts metadata of type `M` to a JSON string.
  /// - [metadataFromJson]: A function that converts a JSON string to metadata of type `M`.
  /// These functions are used for serialization and deserialization of metadata.
  const SerializableSyncAdapter({
    required this.metadataToJson,
    required this.metadataFromJson,
  });

  /// A function to serialize metadata to a JSON string.
  final String Function(M metadata) metadataToJson;

  /// A function to deserialize metadata from a JSON string.
  final M Function(String json) metadataFromJson;
}
