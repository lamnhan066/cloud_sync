import 'dart:convert';

import 'package:cloud_sync/cloud_sync.dart';

/// Extension to provide deserialization functionality
/// for the [SyncMetadata] class.
extension SyncMetadataDeserialization on SyncMetadata {
  /// Creates a [SyncMetadata] instance from a JSON string.
  static SyncMetadata fromJson(String json) {
    return fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Creates a [SyncMetadata] instance from a Map.
  static SyncMetadata fromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      id: map['id'] as String,
      modifiedAt: DateTime.parse(map['modifiedAt'] as String),
      isDeleted: (map['isDeleted'] as bool?) ?? false,
    );
  }
}

/// Extension to provide serialization functionality for the [SyncMetadata] class.
extension SyncMetadataSerialization on SyncMetadata {
  /// Converts the [SyncMetadata] instance to a JSON string.
  String toJson() {
    return json.encode(toMap());
  }

  /// Converts the [SyncMetadata] instance to a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'modifiedAt': modifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }
}
