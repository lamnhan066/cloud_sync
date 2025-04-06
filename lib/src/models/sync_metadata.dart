/// A model class representing metadata for synchronization.
///
/// This class holds information about an entity's unique identifier and
/// the timestamp of the last modification. It includes utility methods
/// for creating instances, serialization, and deserialization.
class SyncMetadata {
  /// The unique identifier for the metadata.
  final String id;

  /// The timestamp of the last modification.
  final DateTime modifiedAt;

  /// Creates a new instance of [SyncMetadata].
  ///
  /// Both [id] and [modifiedAt] are required parameters.
  SyncMetadata({
    required this.id,
    required this.modifiedAt,
  });
}
