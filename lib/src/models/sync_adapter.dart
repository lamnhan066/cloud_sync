import 'package:cloud_sync/src/models/sync_metadata.dart';

/// Base class for synchronization adapters for specific data sources.
///
/// This abstract class defines the interface for fetching and writing
/// synchronized data. It is generic over:
/// - [M]: A type representing synchronization metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
abstract class SyncAdapterBase<M, D> {
  /// Default constructor for [SyncAdapterBase].
  const SyncAdapterBase();

  /// Returns the unique identifier for the given [metadata].
  ///
  /// This identifier is used to uniquely identify metadata items
  /// during the synchronization process.
  String getMetadataId(M metadata);

  /// Compares two metadata items to determine if the current one is older.
  ///
  /// Returns `true` if [current] is older than [other], otherwise `false`.
  bool isCurrentMetadataBeforeOther(M current, M other);

  /// Fetches a list of metadata items available for synchronization.
  ///
  /// Returns a [Future] that resolves to a list of metadata items of type `M`.
  Future<List<M>> fetchMetadataList();

  /// Retrieves the detailed data associated with the given [metadata].
  ///
  /// Returns a [Future] that resolves to a detail object of type `D`.
  Future<D> fetchDetail(M metadata);

  /// Saves the provided [metadata] and its associated [detail] to the data source.
  ///
  /// Returns a [Future] that completes when the save operation is finished.
  Future<void> save(M metadata, D detail);
}

/// Synchronization adapter for a specific data source.
///
/// This abstract class extends [SyncAdapterBase] and provides default
/// implementations for some methods. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
abstract class SyncAdapter<M extends SyncMetadata, D>
    implements SyncAdapterBase<M, D> {
  /// Default constructor for [SyncAdapter].
  const SyncAdapter();

  @override
  String getMetadataId(M metadata) => metadata.id;

  @override
  bool isCurrentMetadataBeforeOther(M current, M other) =>
      current.modifiedAt.isBefore(other.modifiedAt);

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
/// This abstract class extends [SyncAdapter] and adds methods for converting
/// metadata objects to and from JSON strings. It is generic over:
/// - [M]: A type extending [SyncMetadata], representing sync metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
///
/// This class is useful for scenarios where metadata needs to be serialized
/// for storage or transmission, such as in a database or over a network.
abstract class SerializableSyncAdapter<M extends SyncMetadata, D>
    extends SyncAdapter<M, D> {
  /// Default constructor for [SerializableSyncAdapter].
  ///
  /// - [metadataToJson]: A function that converts metadata of type `M` to a JSON string.
  /// - [metadataFromJson]: A function that converts a JSON string to metadata of type `M`.
  /// These functions are used for serialization and deserialization of metadata.
  const SerializableSyncAdapter({
    required this.metadataToJson,
    required this.metadataFromJson,
  });

  /// Function to serialize metadata to a JSON string.
  final String Function(M metadata) metadataToJson;

  /// Function to deserialize metadata from a JSON string.
  final M Function(String json) metadataFromJson;
}
