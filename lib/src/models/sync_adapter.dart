import 'dart:async';

/// Base class for synchronization adapters for specific data sources.
///
/// This abstract class defines the interface for fetching and writing
/// synchronized data. It is generic over:
/// - [M]: A type representing synchronization metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
abstract class SyncAdapter<M, D> {
  /// Default constructor for [SyncAdapter].
  const SyncAdapter();

  /// Returns the unique identifier for the given [metadata].
  ///
  /// This identifier is used to uniquely identify metadata items
  /// during the synchronization process.
  String getMetadataId(M metadata);

  /// Compares two metadata items to determine if the current one is older.
  ///
  /// Returns `true` if [current] is older than [other], otherwise `false`.
  FutureOr<bool> isCurrentMetadataBeforeOther(M current, M other);

  /// Fetches a list of metadata items available for synchronization.
  ///
  /// Returns a [Future] that resolves to a list of metadata items of type `M`.
  FutureOr<List<M>> fetchMetadataList();

  /// Retrieves the detailed data associated with the given [metadata].
  ///
  /// Returns a [Future] that resolves to a detail object of type `D`.
  FutureOr<D> fetchDetail(M metadata);

  /// Saves the provided [metadata] and its associated [detail] to the data source.
  ///
  /// Returns a [Future] that completes when the save operation is finished.
  FutureOr<void> save(M metadata, D detail);
}

/// Abstract base class for a synchronization adapter with serialization capabilities.
///
/// This class extends [SyncAdapter] and introduces functionality for
/// serializing and deserializing metadata objects to and from JSON strings.
/// It is generic over:
/// - [M]: A type representing synchronization metadata.
/// - [D]: A type representing the detailed data associated with the metadata.
///
/// This class is particularly useful in scenarios where metadata needs to be
/// stored or transmitted in a serialized format, such as in databases or over
/// a network. It provides a foundation for implementing adapters that handle
/// serialization seamlessly.
abstract class SerializableSyncAdapter<M, D> extends SyncAdapter<M, D> {
  /// Creates a [SerializableSyncAdapter] with the provided serialization functions.
  ///
  /// - [metadataToJson]: A function that converts metadata of type `M` into a JSON string.
  /// - [metadataFromJson]: A function that converts a JSON string back into metadata of type `M`.
  ///
  /// These functions enable the serialization and deserialization of metadata,
  /// making it easier to store or transmit metadata in a structured format.
  const SerializableSyncAdapter({
    required this.metadataToJson,
    required this.metadataFromJson,
  });

  /// A function that converts metadata of type `M` into a JSON string.
  ///
  /// This function is used to serialize metadata for storage or transmission.
  final String Function(M metadata) metadataToJson;

  /// A function that converts a JSON string back into metadata of type `M`.
  ///
  /// This function is used to deserialize metadata from a serialized format.
  final M Function(String json) metadataFromJson;
}
