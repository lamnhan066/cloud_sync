import 'dart:convert';

import 'package:cloud_sync/cloud_sync.dart';
import 'package:test/test.dart';

import 'moks.dart';

void main() {
  group('SerializableSyncMetadata', () {
    const testId = 'abc123';
    final testDate = DateTime.parse('2024-04-10T12:00:00.000Z');
    const testIsDeleted = true;

    final testMetadata = SerializableSyncMetadata(
      id: testId,
      modifiedAt: testDate,
      isDeleted: testIsDeleted,
    );

    test('toMap should return correct map', () {
      final map = testMetadata.toMap();

      expect(map, {
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      });
    });

    test('fromMap should return equivalent instance', () {
      final map = {
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      };

      final fromMap = SerializableSyncMetadata.fromMap(map);

      expect(fromMap.id, testMetadata.id);
      expect(fromMap.modifiedAt, testMetadata.modifiedAt);
      expect(fromMap.isDeleted, testMetadata.isDeleted);
    });

    test('toJson should return valid JSON string', () {
      final jsonStr = testMetadata.toJson();

      final expectedJson = json.encode({
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      });

      expect(jsonStr, expectedJson);
    });

    test('fromJson should return equivalent instance', () {
      final jsonString = json.encode({
        'id': testId,
        'modifiedAt': testDate.toIso8601String(),
        'isDeleted': testIsDeleted,
      });

      final fromJson = SerializableSyncMetadata.fromJson(jsonString);

      expect(fromJson.id, testMetadata.id);
      expect(fromJson.modifiedAt, testMetadata.modifiedAt);
      expect(fromJson.isDeleted, testMetadata.isDeleted);
    });
  });

  group('SerializableSyncAdapter Tests', () {
    late SerializableSyncMetadataAdapter<SyncMetadata, MockData> adapter;

    setUp(() {
      adapter = MockSerializableSyncAdapter(
        metadataToJson: (metadata) => json.encode({
          'id': metadata.id,
          'modifiedAt': metadata.modifiedAt.toIso8601String(),
          'isDeleted': metadata.isDeleted,
        }),
        metadataFromJson: (jsonStr) {
          final map = json.decode(jsonStr) as Map<String, dynamic>;
          return SyncMetadata(
            id: map['id'] as String,
            modifiedAt: DateTime.parse(map['modifiedAt'] as String),
            isDeleted: map['isDeleted'] as bool? ?? false,
          );
        },
      );
    });

    test('metadataToJson serializes metadata correctly', () {
      final metadata = SyncMetadata(
        id: 'test-id',
        modifiedAt: DateTime.parse('2024-04-10T12:00:00.000Z'),
        isDeleted: true,
      );

      final jsonStr = adapter.metadataToJson(metadata);

      expect(
        jsonStr,
        json.encode({
          'id': 'test-id',
          'modifiedAt': '2024-04-10T12:00:00.000Z',
          'isDeleted': true,
        }),
      );
    });

    test('metadataFromJson deserializes metadata correctly', () {
      final jsonStr = json.encode({
        'id': 'test-id',
        'modifiedAt': '2024-04-10T12:00:00.000Z',
        'isDeleted': true,
      });

      final metadata = adapter.metadataFromJson(jsonStr);

      expect(metadata.id, 'test-id');
      expect(metadata.modifiedAt, DateTime.parse('2024-04-10T12:00:00.000Z'));
      expect(metadata.isDeleted, true);
    });

    test('metadataFromJson handles missing isDeleted field gracefully', () {
      final jsonStr = json.encode({
        'id': 'test-id',
        'modifiedAt': '2024-04-10T12:00:00.000Z',
      });

      final metadata = adapter.metadataFromJson(jsonStr);

      expect(metadata.id, 'test-id');
      expect(metadata.modifiedAt, DateTime.parse('2024-04-10T12:00:00.000Z'));
      expect(metadata.isDeleted, false);
    });

    test('metadataToJson and metadataFromJson are inverses', () {
      final originalMetadata = SyncMetadata(
        id: 'test-id',
        modifiedAt: DateTime.parse('2024-04-10T12:00:00.000Z'),
        isDeleted: true,
      );

      final jsonStr = adapter.metadataToJson(originalMetadata);
      final deserializedMetadata = adapter.metadataFromJson(jsonStr);

      expect(deserializedMetadata.id, originalMetadata.id);
      expect(deserializedMetadata.modifiedAt, originalMetadata.modifiedAt);
      expect(deserializedMetadata.isDeleted, originalMetadata.isDeleted);
    });
  });
}
