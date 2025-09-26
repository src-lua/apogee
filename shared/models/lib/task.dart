import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums/task_status.dart';

part 'task.g.dart';

/// Represents a specific task instance for a particular day
/// Generated from TaskTemplate based on recurrency rules
@JsonSerializable()
class Task extends Equatable {
  /// Unique identifier for this task instance
  /// Format: {template_id}_{day_iso_string}
  final String id;

  /// Display name of the task
  final String name;

  /// Coin reward for completing this task
  final int coins;

  /// Current status of the task
  final TaskStatus status;

  /// When the task was completed (if applicable)
  final DateTime? completedAt;

  /// Whether this task was completed after the 2 AM deadline
  /// Late tasks don't award XP but still count for coins
  final bool isLate;

  /// Server-side tracking fields
  final DateTime createdAt;
  final DateTime updatedAt;

  /// ID of the template this task was generated from
  final String templateId;

  /// The day this task is scheduled for (normalized to UTC date)
  final DateTime scheduledDate;

  const Task({
    required this.id,
    required this.name,
    required this.coins,
    required this.templateId,
    required this.scheduledDate,
    this.status = TaskStatus.pending,
    this.completedAt,
    this.isLate = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor for JSON deserialization
  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);

  /// Converts this task to JSON for serialization
  Map<String, dynamic> toJson() => _$TaskToJson(this);

  /// Creates a copy of this task with updated fields
  Task copyWith({
    String? id,
    String? name,
    int? coins,
    TaskStatus? status,
    DateTime? completedAt,
    bool? isLate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? templateId,
    DateTime? scheduledDate,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      isLate: isLate ?? this.isLate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      templateId: templateId ?? this.templateId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
    );
  }

  /// Factory for creating a new task from a template
  factory Task.fromTemplate({
    required String templateId,
    required String name,
    required int coins,
    required DateTime scheduledDate,
  }) {
    final now = DateTime.now();
    final normalizedDate = DateTime.utc(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    return Task(
      id: '${templateId}_${normalizedDate.toIso8601String()}',
      name: name,
      coins: coins,
      templateId: templateId,
      scheduledDate: normalizedDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Whether this task can be modified (not in future)
  bool get isModifiable {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedScheduled = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    return !normalizedScheduled.isAfter(normalizedToday);
  }

  /// XP value this task awards based on status and timing
  int get xpValue {
    if (isLate || status == TaskStatus.pending) return 0;

    return status.isFullCompletion ? 20 :
           status.isPartialCompletion ? 10 : 0;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    coins,
    status,
    completedAt,
    isLate,
    createdAt,
    updatedAt,
    templateId,
    scheduledDate,
  ];
}