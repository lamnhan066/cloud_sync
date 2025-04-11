import 'dart:convert';

/// A model class representing metadata used for synchronization.
///
/// This class encapsulates information about an entity's unique identifier,
/// the timestamp of its last modification, and its deletion status.
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

/// A serializable version of [SyncMetadata] for encoding/decoding purposes,
/// typically used for saving to or reading from storage like JSON or databases.
class SerializableSyncMetadata extends SyncMetadata {
  /// Constructor that initializes fields from the [SyncMetadata] superclass.
  /// [id] and [modifiedAt] are required, while [isDeleted] is optional.
  SerializableSyncMetadata({
    required super.id,
    required super.modifiedAt,
    super.isDeleted,
  });

  /// Creates an instance of [SerializableSyncMetadata] from a Map.
  factory SerializableSyncMetadata.fromMap(Map<String, dynamic> map) {
    return SerializableSyncMetadata(
      id: map['id'] as String,
      modifiedAt: DateTime.parse(map['modifiedAt'] as String),
      isDeleted: map['isDeleted'] as bool,
    );
  }

  /// Creates an instance of [SerializableSyncMetadata] from a JSON string.
  factory SerializableSyncMetadata.fromJson(String source) =>
      SerializableSyncMetadata.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// Converts the object to a Map, making it suitable for encoding or storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'modifiedAt': modifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  /// Converts the object to a JSON string using [toMap].
  String toJson() => json.encode(toMap());
}
