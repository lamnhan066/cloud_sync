import 'dart:convert';

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

  /// Indicates whether the metadata has been deleted.
  final bool isDeleted;

  /// Creates a new instance of [SyncMetadata].
  ///
  /// Both [id] and [modifiedAt] are required parameters.
  SyncMetadata({
    required this.id,
    required this.modifiedAt,
    this.isDeleted = false,
  });

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'modifiedAt': modifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory SyncMetadata.fromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      id: map['id'] ?? '',
      modifiedAt: DateTime.parse(map['modifiedAt']),
      isDeleted: map['isDeleted'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory SyncMetadata.fromJson(String source) =>
      SyncMetadata.fromMap(json.decode(source));

  @override
  String toString() =>
      'SyncMetadata(id: $id, modifiedAt: $modifiedAt, isDeleted: $isDeleted)';
}
