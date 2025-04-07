import 'dart:convert';

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

  /// Creates a new instance of [SyncMetadata] from a [Map].
  ///
  /// The [map] must contain the keys `id` and `modifiedAt`.
  /// The `isDeleted` key is optional and defaults to `false` if not provided.
  factory SyncMetadata.fromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      id: (map['id'] ?? '') as String,
      modifiedAt: DateTime.parse(map['modifiedAt'] as String),
      isDeleted: (map['isDeleted'] as bool?) ?? false,
    );
  }

  /// Creates a new instance of [SyncMetadata] from a JSON string.
  ///
  /// The [source] string must represent a valid JSON object.
  factory SyncMetadata.fromJson(String source) =>
      SyncMetadata.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The unique identifier for the metadata.
  final String id;

  /// The timestamp of the last modification.
  final DateTime modifiedAt;

  /// Indicates whether the metadata has been marked as deleted.
  final bool isDeleted;

  /// Creates a copy of the current [SyncMetadata] instance with updated fields.
  ///
  /// Any field not provided will retain its current value.
  SyncMetadata copyWith({
    String? id,
    DateTime? modifiedAt,
    bool? isDeleted,
  }) {
    return SyncMetadata(
      id: id ?? this.id,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Converts the [SyncMetadata] instance to a [Map].
  ///
  /// The resulting map contains the keys `id`, `modifiedAt`, and `isDeleted`.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'modifiedAt': modifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  /// Converts the [SyncMetadata] instance to a JSON string.
  ///
  /// The JSON string represents the metadata as a serialized object.
  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'SyncMetadata(id: $id, modifiedAt: $modifiedAt, isDeleted: $isDeleted)';
}
