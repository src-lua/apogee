import 'package:hive/hive.dart';

part 'task_streak_data.g.dart';

@HiveType(typeId: 5)
class TaskStreakData {
  @HiveField(0)
  int currentStreak;

  @HiveField(1)
  int bestStreak;

  @HiveField(2)
  DateTime? lastCompletedDate;

  @HiveField(3)
  int totalCompletions;

  @HiveField(4)
  DateTime? lastCalculated; // Quando foi calculado pela última vez

  @HiveField(5)
  DateTime? currentStreakStartDate; // Quando a streak atual começou

  @HiveField(6)
  bool needsRecalculation; // Flag para forçar recálculo completo

  TaskStreakData({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
    this.totalCompletions = 0,
    this.lastCalculated,
    this.currentStreakStartDate,
    this.needsRecalculation = false,
  });

  TaskStreakData copyWith({
    int? currentStreak,
    int? bestStreak,
    DateTime? lastCompletedDate,
    int? totalCompletions,
    DateTime? lastCalculated,
    DateTime? currentStreakStartDate,
    bool? needsRecalculation,
  }) {
    return TaskStreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      lastCalculated: lastCalculated ?? this.lastCalculated,
      currentStreakStartDate: currentStreakStartDate ?? this.currentStreakStartDate,
      needsRecalculation: needsRecalculation ?? this.needsRecalculation,
    );
  }
}