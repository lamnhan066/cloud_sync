import 'package:cloud_sync/cloud_sync.dart';

/// Synchronization adapter for a specific data source.
///
/// This abstract class extends [SyncAdapter] and provides default
/// implementations for some methods. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
abstract class SyncMetadataAdapter<M extends SyncMetadata, D>
    implements SyncAdapter<M, D> {
  /// Default constructor for [SyncMetadataAdapter].
  const SyncMetadataAdapter();

  @override
  String getMetadataId(M metadata) {
    return metadata.id;
  }

  @override
  bool isCurrentMetadataBeforeOther(M current, M other) {
    return current.modifiedAt.isBefore(other.modifiedAt);
  }

  /// Fetches a list of metadata items available for synchronization.
  ///
  /// Returns a [Future] that resolves to a list of metadata items of type `M`.
  @override
  Future<List<M>> fetchMetadataList();

  /// Retrieves the detailed data associated with the given [metadata].
  ///
  /// Returns a [Future] that resolves to a detail object of type `D`.
  @override
  Future<D> fetchDetail(M metadata);

  /// Saves the provided [metadata] and its associated [detail] to the data source.
  ///
  /// Returns a [Future] that completes when the save operation is finished.
  @override
  Future<void> save(M metadata, D detail);
}

/// Synchronization adapter with serialization capabilities.
///
/// This abstract class extends [SyncMetadataAdapter] and adds methods for converting
/// metadata objects to and from JSON strings. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
///
/// This class is useful for scenarios where metadata needs to be serialized
/// for storage or transmission, such as in a database or over a network.
abstract class SerializableSyncMetadataAdapter<M extends SyncMetadata, D>
    extends SyncMetadataAdapter<M, D> {
  /// Default constructor for [SerializableSyncMetadataAdapter].
  ///
  /// - [metadataToJson]: A function that converts metadata of type `M` to a JSON string.
  /// - [metadataFromJson]: A function that converts a JSON string to metadata of type `M`.
  /// These functions are used for serialization and deserialization of metadata.
  const SerializableSyncMetadataAdapter({
    required this.metadataToJson,
    required this.metadataFromJson,
  });

  /// Function to serialize metadata to a JSON string.
  final String Function(M metadata) metadataToJson;

  /// Function to deserialize metadata from a JSON string.
  final M Function(String json) metadataFromJson;
}
