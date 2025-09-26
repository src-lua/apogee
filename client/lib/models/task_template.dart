import 'package:hive/hive.dart';
import 'enums/recurrency_type.dart';
import 'task_streak_data.dart';

part 'task_template.g.dart';

@HiveType(typeId: 2)
class TaskTemplate {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int coins;

  @HiveField(3)
  RecurrencyType recurrencyType;

  @HiveField(4)
  List<int>? customDays; // For weekly: 1=Monday, 7=Sunday. For monthly: day of month

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? lastGenerated; // Track when tasks were last generated

  @HiveField(8)
  DateTime? startDate; // When the task should start appearing

  @HiveField(9)
  DateTime? endDate; // When the task should stop appearing

  @HiveField(10)
  DateTime lastModified; // Track when template was last changed

  @HiveField(11)
  TaskStreakData streakData;

  TaskTemplate({
    required this.name,
    required this.coins,
    this.recurrencyType = RecurrencyType.daily,
    this.customDays,
    this.isActive = true,
    this.startDate,
    this.endDate,
    String? id,
    DateTime? createdAt,
    this.lastGenerated,
    DateTime? lastModified,
    TaskStreakData? streakData,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       lastModified = lastModified ?? DateTime.now(),
       streakData = streakData ?? TaskStreakData();

  bool shouldGenerateForDay(DateTime day) {
    if (!isActive) return false;

    // Check date range (normalize to compare dates only, not time)
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (startDate != null) {
      final startOnly = DateTime(startDate!.year, startDate!.month, startDate!.day);
      if (dayOnly.isBefore(startOnly)) return false;
    }
    if (endDate != null) {
      final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (dayOnly.isAfter(endOnly)) return false;
    }

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
        // For custom, we'll use a different logic based on interval
        return true; // Simplified for now
      case RecurrencyType.none:
        return false;
    }
  }

  TaskTemplate copyWith({
    String? name,
    int? coins,
    RecurrencyType? recurrencyType,
    List<int>? customDays,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastGenerated,
    TaskStreakData? streakData,
    bool updateModified = false,
  }) {
    return TaskTemplate(
      id: id,
      name: name ?? this.name,
      coins: coins ?? this.coins,
      recurrencyType: recurrencyType ?? this.recurrencyType,
      customDays: customDays ?? this.customDays,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt,
      lastGenerated: lastGenerated ?? this.lastGenerated,
      lastModified: updateModified ? DateTime.now() : lastModified,
      streakData: streakData ?? this.streakData,
    );
  }
}