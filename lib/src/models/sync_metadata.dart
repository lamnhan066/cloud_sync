import 'dart:convert';

/// A model class representing metadata for synchronization.
///
/// This class contains information about an entity's ID, name, creation time,
/// and last modification time. It provides utility methods for copying,
/// serialization, and deserialization.
class SyncMetadata {
  /// The unique identifier for the metadata.
  final String id;

  /// The name associated with the metadata.
  final String name;

  /// The timestamp when the metadata was created.
  final DateTime createdAt;

  /// The timestamp when the metadata was last modified.
  final DateTime modifiedAt;

  /// Creates a new instance of [SyncMetadata].
  ///
  /// All fields are required.
  SyncMetadata({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
  });

  /// Creates a copy of this [SyncMetadata] with optional new values.
  ///
  /// If a value is not provided, the original value is retained.
  SyncMetadata copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return SyncMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  /// Converts this [SyncMetadata] instance into a [Map].
  ///
  /// The `createdAt` and `modifiedAt` fields are serialized as ISO 8601 strings.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  /// Creates a new [SyncMetadata] instance from a [Map].
  ///
  /// The `createdAt` and `modifiedAt` fields are parsed from ISO 8601 strings.
  /// If a field is missing, default values are used.
  factory SyncMetadata.fromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      modifiedAt: DateTime.parse(map['modifiedAt'] as String),
    );
  }

  /// Converts this [SyncMetadata] instance into a JSON string.
  String toJson() => json.encode(toMap());

  /// Creates a new [SyncMetadata] instance from a JSON string.
  ///
  /// The JSON string is decoded into a [Map] and then converted into a
  /// [SyncMetadata] instance.
  factory SyncMetadata.fromJson(String source) =>
      SyncMetadata.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Returns a string representation of this [SyncMetadata].
  @override
  String toString() {
    return 'SyncMetadata(id: $id, name: $name, createdAt: $createdAt, modifiedAt: $modifiedAt)';
  }

  /// Compares this [SyncMetadata] instance with another for equality.
  ///
  /// Two instances are considered equal if all their fields are identical.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SyncMetadata &&
        other.id == id &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.modifiedAt == modifiedAt;
  }

  /// Returns a hash code for this [SyncMetadata].
  ///
  /// The hash code is computed based on all fields of the instance.
  @override
  int get hashCode {
    return Object.hash(id, name, createdAt, modifiedAt);
  }
}
