import 'dart:async';

/// Base class for synchronization adapters for specific data sources.
///
/// This abstract class defines the interface for managing the synchronization
/// of data between different sources. It is generic over:
/// - [M]: The type representing synchronization metadata.
/// - [D]: The type representing the detailed data associated with the metadata.
abstract class SyncAdapter<M, D> {
  /// Constructs a [SyncAdapter] with the required functions for metadata handling.
  ///
  /// - [getMetadataId]: A function that retrieves the unique identifier for a given metadata item.
  /// - [isCurrentMetadataBeforeOther]: A function that determines the relative age of two metadata items.
  const SyncAdapter({
    required this.getMetadataId,
    required this.isCurrentMetadataBeforeOther,
  });

  /// A function that retrieves the unique identifier for the given `metadata`.
  ///
  /// This identifier is used to uniquely identify metadata items during
  /// synchronization, ensuring proper tracking and comparison.
  final String Function(M metadata) getMetadataId;

  /// Determines if the `current` metadata item is older than the `other` metadata item.
  ///
  /// Returns `true` if `current` is considered older than `other`, otherwise `false`.
  /// This is used to resolve conflicts or determine the order of updates during synchronization.
  final FutureOr<bool> Function(M current, M other)
      isCurrentMetadataBeforeOther;

  /// Fetches a list of metadata items available for synchronization.
  ///
  /// Returns a [Future] or a synchronous list of metadata items of type [M].
  /// This list represents the items that need to be synchronized.
  FutureOr<List<M>> fetchMetadataList();

  /// Retrieves the detailed data associated with the given [metadata].
  ///
  /// Returns a [Future] or a synchronous detail object of type [D].
  /// This is used to fetch the full data for a specific metadata item.
  FutureOr<D> fetchDetail(M metadata);

  /// Saves the provided [metadata] and its associated [detail] to the data source.
  ///
  /// Returns a [Future] or completes synchronously when the save operation is finished.
  /// This ensures that the data is persisted or updated in the target source.
  FutureOr<void> save(M metadata, D detail);
}

/// Abstract base class for a synchronization adapter with serialization capabilities.
///
/// This class extends [SyncAdapter] and adds functionality for serializing and
/// deserializing metadata objects to and from JSON strings. It is generic over:
/// - [M]: The type representing synchronization metadata.
/// - [D]: The type representing the detailed data associated with the metadata.
///
/// This class is particularly useful in scenarios where metadata needs to be
/// stored or transmitted in a serialized format, such as in databases or over
/// a network. It provides a foundation for implementing adapters that handle
/// serialization seamlessly.
abstract class SerializableSyncAdapter<M, D> extends SyncAdapter<M, D> {
  /// Constructs a [SerializableSyncAdapter] with the required serialization functions.
  ///
  /// - [getMetadataId]: A function that retrieves the unique identifier for a given metadata item.
  /// - [metadataToJson]: A function that serializes metadata of type [M] into a JSON string.
  /// - [metadataFromJson]: A function that deserializes a JSON string back into metadata of type [M].
  /// - [isCurrentMetadataBeforeOther]: A function that determines the relative age of two metadata items.
  ///
  /// These functions enable the serialization and deserialization of metadata,
  /// making it easier to store or transmit metadata in a structured format.
  const SerializableSyncAdapter({
    required super.getMetadataId,
    required this.metadataToJson,
    required this.metadataFromJson,
    required super.isCurrentMetadataBeforeOther,
  });

  /// A function that serializes metadata of type [M] into a JSON string.
  ///
  /// This function is used to convert metadata into a standardized format
  /// suitable for storage or transmission.
  final String Function(M metadata) metadataToJson;

  /// A function that deserializes a JSON string back into metadata of type [M].
  ///
  /// This function is used to reconstruct metadata objects from their serialized
  /// representation, enabling seamless data exchange or storage.
  final M Function(String json) metadataFromJson;
}
