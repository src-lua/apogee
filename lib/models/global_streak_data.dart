import 'package:hive/hive.dart';

part 'global_streak_data.g.dart';

@HiveType(typeId: 6)
class GlobalStreakData {
  @HiveField(0)
  int currentLoggingStreak;

  @HiveField(1)
  int bestLoggingStreak;

  @HiveField(2)
  DateTime? lastLoggedDate;

  @HiveField(3)
  int totalLoggedDays;

  GlobalStreakData({
    this.currentLoggingStreak = 0,
    this.bestLoggingStreak = 0,
    this.lastLoggedDate,
    this.totalLoggedDays = 0,
  });

  GlobalStreakData copyWith({
    int? currentLoggingStreak,
    int? bestLoggingStreak,
    DateTime? lastLoggedDate,
    int? totalLoggedDays,
  }) {
    return GlobalStreakData(
      currentLoggingStreak: currentLoggingStreak ?? this.currentLoggingStreak,
      bestLoggingStreak: bestLoggingStreak ?? this.bestLoggingStreak,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      totalLoggedDays: totalLoggedDays ?? this.totalLoggedDays,
    );
  }
}