import 'package:cloud_sync/cloud_sync.dart';

/// A base class for synchronization adapters that manage metadata.
///
/// This abstract class extends [SyncAdapter] and provides default
/// implementations for some methods. It is generic over:
/// - [M]: A type that extends [SyncMetadata], representing the synchronization metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
///
/// Use this class as a foundation for implementing synchronization logic
/// for data sources that require metadata management.
abstract class SyncMetadataAdapter<M extends SyncMetadata, D>
    extends SyncAdapter<M, D> {
  /// Constructs a [SyncMetadataAdapter] with default implementations
  /// for retrieving the unique identifier of metadata and comparing metadata.
  const SyncMetadataAdapter()
      : super(
          getMetadataId: _getMetadataId,
          isCurrentMetadataBeforeOther: _isCurrentMetadataBeforeOther,
        );

  /// Retrieves the unique identifier for the given [metadata].
  ///
  /// This method is used internally to uniquely identify metadata objects.
  static String _getMetadataId(SyncMetadata metadata) => metadata.id;

  /// Compares two metadata objects to determine their order based on modification time.
  ///
  /// Returns `true` if [current] was modified before [other], otherwise `false`.
  static bool _isCurrentMetadataBeforeOther(
    SyncMetadata current,
    SyncMetadata other,
  ) {
    return current.modifiedAt.isBefore(other.modifiedAt);
  }
}

/// A synchronization adapter with support for metadata serialization.
///
/// This abstract class extends [SyncMetadataAdapter] and adds methods for
/// converting metadata objects to and from JSON strings. It is generic over:
/// - [M]: A type that extends [SyncMetadata], representing the synchronization metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
///
/// This class is particularly useful in scenarios where metadata needs to be
/// serialized for storage (e.g., in a database) or transmission (e.g., over a network).
abstract class SerializableSyncMetadataAdapter<M extends SyncMetadata, D>
    extends SyncMetadataAdapter<M, D> {
  /// Constructs a [SerializableSyncMetadataAdapter] with the provided serialization functions.
  ///
  /// - [metadataToJson]: A function that converts metadata of type [M] to a JSON string.
  /// - [metadataFromJson]: A function that converts a JSON string to metadata of type [M].
  ///
  /// These functions enable the serialization and deserialization of metadata,
  /// making it easier to store or transmit metadata in a structured format.
  const SerializableSyncMetadataAdapter({
    required this.metadataToJson,
    required this.metadataFromJson,
  });

  /// A function to serialize metadata of type [M] into a JSON string.
  ///
  /// This function is used to convert metadata into a format suitable for storage or transmission.
  final String Function(M metadata) metadataToJson;

  /// A function to deserialize a JSON string into metadata of type [M].
  ///
  /// This function is used to reconstruct metadata from its serialized JSON representation.
  final M Function(String json) metadataFromJson;
}
