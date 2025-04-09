/// A model class representing metadata used for synchronization.
///
/// This class encapsulates information about an entity's unique identifier,
/// the timestamp of its last modification, and its deletion status. It provides
/// utility methods for creating instances, as well as for serialization and
/// deserialization.
class SyncMetadata {
  /// Constructs a new instance of [SyncMetadata].
  ///
  /// - [id]: A unique identifier for the entity.
  /// - [modifiedAt]: The timestamp indicating when the entity was last modified.
  /// - [isDeleted]: A flag indicating whether the entity has been marked as deleted.
  ///   Defaults to `false` if not specified.
  const SyncMetadata({
    required this.id,
    required this.modifiedAt,
    this.isDeleted = false,
  });

  /// A unique identifier for the entity.
  final String id;

  /// The timestamp indicating the last modification of the entity.
  final DateTime modifiedAt;

  /// A flag indicating whether the entity has been marked as deleted.
  ///
  /// If `true`, the entity is considered deleted. Defaults to `false`.
  final bool isDeleted;
}
