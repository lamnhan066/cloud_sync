/// A model class representing metadata for synchronization.
///
/// This class holds information about an entity's unique identifier,
/// the timestamp of the last modification, and whether the entity
/// has been deleted. It includes utility methods for creating instances,
/// serialization, and deserialization.
class SyncMetadata {
  /// Creates a new instance of [SyncMetadata].
  ///
  /// [id] is the unique identifier for the metadata.
  /// [modifiedAt] is the timestamp of the last modification.
  /// [isDeleted] indicates whether the metadata has been marked as deleted.
  /// By default, [isDeleted] is set to `false`.
  const SyncMetadata({
    required this.id,
    required this.modifiedAt,
    this.isDeleted = false,
  });

  /// The unique identifier for the metadata.
  final String id;

  /// The timestamp of the last modification.
  final DateTime modifiedAt;

  /// Indicates whether the metadata has been marked as deleted.
  final bool isDeleted;
}
