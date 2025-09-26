import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums/recurrency_type.dart';
import 'task_streak_data.dart';

part 'task_template.g.dart';

/// Template for generating recurring tasks
/// Defines the pattern and rules for task creation
@JsonSerializable()
class TaskTemplate extends Equatable {
  /// Unique identifier for this template
  final String id;

  /// Display name for tasks generated from this template
  final String name;

  /// Coin reward for completing tasks from this template
  final int coins;

  /// How frequently tasks should be generated
  final RecurrencyType recurrencyType;

  /// Custom days configuration based on recurrency type:
  /// - Weekly: 1=Monday, 7=Sunday
  /// - Monthly: day of month (1-31)
  /// - Custom: interval in days
  final List<int>? customDays;

  /// Whether this template is currently active
  final bool isActive;

  /// When this template was created
  final DateTime createdAt;

  /// When this template was last modified
  final DateTime lastModified;

  /// When tasks were last generated from this template
  final DateTime? lastGenerated;

  /// Date range for task generation (inclusive)
  final DateTime? startDate;
  final DateTime? endDate;

  /// Streak tracking data for this template
  final TaskStreakData streakData;

  /// User ID this template belongs to
  final String userId;

  const TaskTemplate({
    required this.id,
    required this.name,
    required this.coins,
    required this.userId,
    this.recurrencyType = RecurrencyType.daily,
    this.customDays,
    this.isActive = true,
    required this.createdAt,
    required this.lastModified,
    this.lastGenerated,
    this.startDate,
    this.endDate,
    required this.streakData,
  });

  /// Factory constructor for JSON deserialization
  factory TaskTemplate.fromJson(Map<String, dynamic> json) =>
      _$TaskTemplateFromJson(json);

  /// Converts this template to JSON for serialization
  Map<String, dynamic> toJson() => _$TaskTemplateToJson(this);

  /// Creates a copy of this template with updated fields
  TaskTemplate copyWith({
    String? id,
    String? name,
    int? coins,
    String? userId,
    RecurrencyType? recurrencyType,
    List<int>? customDays,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastModified,
    DateTime? lastGenerated,
    DateTime? startDate,
    DateTime? endDate,
    TaskStreakData? streakData,
    bool updateModified = false,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      userId: userId ?? this.userId,
      recurrencyType: recurrencyType ?? this.recurrencyType,
      customDays: customDays ?? this.customDays,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastModified: updateModified ? DateTime.now() : (lastModified ?? this.lastModified),
      lastGenerated: lastGenerated ?? this.lastGenerated,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      streakData: streakData ?? this.streakData,
    );
  }

  /// Factory for creating a new template
  factory TaskTemplate.create({
    required String name,
    required int coins,
    required String userId,
    RecurrencyType recurrencyType = RecurrencyType.daily,
    List<int>? customDays,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    final id = '${userId}_${now.millisecondsSinceEpoch}';

    return TaskTemplate(
      id: id,
      name: name,
      coins: coins,
      userId: userId,
      recurrencyType: recurrencyType,
      customDays: customDays,
      createdAt: now,
      lastModified: now,
      startDate: startDate,
      endDate: endDate,
      streakData: TaskStreakData.initial(),
    );
  }

  /// Determines if this template should generate a task for the given day
  bool shouldGenerateForDay(DateTime day) {
    if (!isActive) return false;

    // Normalize day to date-only comparison
    final dayOnly = DateTime(day.year, day.month, day.day);

    // Check date range constraints
    if (startDate != null) {
      final startOnly = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (dayOnly.isBefore(startOnly)) return false;
    }

    if (endDate != null) {
      final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dayOnly.isAfter(endOnly)) return false;
    }

    // Check recurrency pattern
    switch (recurrencyType) {
      case RecurrencyType.daily:
        return true;

      case RecurrencyType.weekly:
        if (customDays == null || customDays!.isEmpty) return false;
        return customDays!.contains(day.weekday);

      case RecurrencyType.monthly:
        if (customDays == null || customDays!.isEmpty) return false;
        return customDays!.contains(day.day);

      case RecurrencyType.custom:
        if (customDays == null || customDays!.isEmpty) return false;
        // For custom recurrency, use interval logic
        // This could be enhanced based on specific requirements
        return true;

      case RecurrencyType.none:
        return false;
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    coins,
    userId,
    recurrencyType,
    customDays,
    isActive,
    createdAt,
    lastModified,
    lastGenerated,
    startDate,
    endDate,
    streakData,
  ];
}