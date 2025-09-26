import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'sync_data.g.dart';

/// Represents synchronization data between client and server
/// Used for conflict resolution and offline-first architecture
@JsonSerializable()
class SyncData extends Equatable {
  /// ID of the entity being synced
  final String entityId;

  /// Type of entity (user, task, task_template)
  final String entityType;

  /// Current version of this entity
  final int version;

  /// When this entity was last modified
  final DateTime lastModified;

  /// Device ID that made the last modification
  final String lastModifiedBy;

  /// Hash of entity data for integrity checking
  final String dataHash;

  /// Whether this entity was deleted
  final bool isDeleted;

  const SyncData({
    required this.entityId,
    required this.entityType,
    required this.version,
    required this.lastModified,
    required this.lastModifiedBy,
    required this.dataHash,
    this.isDeleted = false,
  });

  /// Factory constructor for JSON deserialization
  factory SyncData.fromJson(Map<String, dynamic> json) =>
      _$SyncDataFromJson(json);

  /// Converts this sync data to JSON for serialization
  Map<String, dynamic> toJson() => _$SyncDataToJson(this);

  /// Creates a copy of this sync data with updated fields
  SyncData copyWith({
    String? entityId,
    String? entityType,
    int? version,
    DateTime? lastModified,
    String? lastModifiedBy,
    String? dataHash,
    bool? isDeleted,
  }) {
    return SyncData(
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      version: version ?? this.version,
      lastModified: lastModified ?? this.lastModified,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      dataHash: dataHash ?? this.dataHash,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Factory for creating initial sync data
  factory SyncData.initial({
    required String entityId,
    required String entityType,
    required String deviceId,
    required String dataHash,
  }) {
    return SyncData(
      entityId: entityId,
      entityType: entityType,
      version: 1,
      lastModified: DateTime.now(),
      lastModifiedBy: deviceId,
      dataHash: dataHash,
    );
  }

  /// Creates next version of sync data
  SyncData nextVersion({
    required String deviceId,
    required String dataHash,
  }) {
    return copyWith(
      version: version + 1,
      lastModified: DateTime.now(),
      lastModifiedBy: deviceId,
      dataHash: dataHash,
    );
  }

  /// Marks this entity as deleted
  SyncData markDeleted({required String deviceId}) {
    return copyWith(
      version: version + 1,
      lastModified: DateTime.now(),
      lastModifiedBy: deviceId,
      isDeleted: true,
    );
  }

  @override
  List<Object?> get props => [
    entityId,
    entityType,
    version,
    lastModified,
    lastModifiedBy,
    dataHash,
    isDeleted,
  ];
}

/// Sync conflict resolution strategies
enum ConflictResolution {
  /// Server wins (default for most conflicts)
  serverWins,

  /// Client wins (user explicitly chose their version)
  clientWins,

  /// Merge data (when possible)
  merge,

  /// Manual resolution required
  manual,
}

/// Represents a sync conflict between client and server data
@JsonSerializable()
class SyncConflict extends Equatable {
  /// Entity where conflict occurred
  final String entityId;
  final String entityType;

  /// Conflicting versions
  final SyncData clientVersion;
  final SyncData serverVersion;

  /// How to resolve this conflict
  final ConflictResolution resolution;

  /// Additional context about the conflict
  final String? description;

  /// When this conflict was detected
  final DateTime detectedAt;

  const SyncConflict({
    required this.entityId,
    required this.entityType,
    required this.clientVersion,
    required this.serverVersion,
    this.resolution = ConflictResolution.serverWins,
    this.description,
    required this.detectedAt,
  });

  /// Factory constructor for JSON deserialization
  factory SyncConflict.fromJson(Map<String, dynamic> json) =>
      _$SyncConflictFromJson(json);

  /// Converts this conflict to JSON for serialization
  Map<String, dynamic> toJson() => _$SyncConflictToJson(this);

  @override
  List<Object?> get props => [
    entityId,
    entityType,
    clientVersion,
    serverVersion,
    resolution,
    description,
    detectedAt,
  ];
}